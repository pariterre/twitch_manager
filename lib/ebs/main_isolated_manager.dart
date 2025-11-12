import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:twitch_manager/ebs/ebs_exceptions.dart';
import 'package:twitch_manager/twitch_ebs.dart';
import 'package:twitch_manager/utils/completers.dart';

final _logger = Logger('IsolatedMainManager');

class _FrontendUser {
  final String opaqueId;
  final String? userId;
  final WebSocket socket;

  _FrontendUser({
    required this.opaqueId,
    required this.userId,
    required this.socket,
  });
}

class _IsolatedClientInterface {
  String broadcasterId;
  final Isolate isolate;
  SendPort? sendPort;
  WebSocket socket;
  final List<_FrontendUser> frontendUsers = [];

  _IsolatedClientInterface({
    required this.isolate,
    required this.broadcasterId,
    required this.socket,
  }) {
    _logger.info('IsolatedInterface created');

    // Listen to the socket
    socket.listen(
        (message) => MainIsolatedManager.instance
            .messageFromAppToIsolated(MessageProtocol.decode(message), socket),
        onDone: () => _handleClientConnexionTerminated(),
        onError: ((handleError) => _handleClientConnexionTerminated()));
  }

  void _handleClientConnexionTerminated() {
    // This will ultimately call the clear method, same as if the client was
    // asking to disconnect themselves
    MainIsolatedManager.instance.messageFromAppToIsolated(
        MessageProtocol(
            to: MessageTo.ebs,
            from: MessageFrom.ebsMain,
            type: MessageTypes.disconnect,
            data: {'broadcaster_id': broadcasterId}),
        socket);
  }

  void addFrontendUser(_FrontendUser frontendUser) {
    frontendUsers.add(frontendUser);

    frontendUser.socket.listen(
        (message) => _handleMessageFromFrontend(
            MessageProtocol.decode(message), frontendUser),
        onDone: () => _handleFrontendUserConnexionTerminated(frontendUser),
        onError: ((handleError) =>
            _handleFrontendUserConnexionTerminated(frontendUser)));
  }

  void _handleMessageFromFrontend(
      MessageProtocol message, _FrontendUser frontendUser) async {
    try {
      final response =
          await MainIsolatedManager.instance.messageFromFrontendToIsolated(
              message: message.copyWith(
                  from: message.from,
                  to: message.to,
                  type: message.type,
                  data: message.data ?? {}
                    ..addAll({
                      'broadcaster_id': broadcasterId,
                      'user_id': frontendUser.userId,
                      'opaque_id': frontendUser.opaqueId
                    })));

      frontendUser.socket.add(response.encode());
    } catch (e) {
      _logger.severe('Error while handling message from frontend: $e');
      _handleFrontendUserConnexionTerminated(frontendUser);
    }
  }

  void _handleFrontendUserConnexionTerminated(_FrontendUser user) {
    try {
      frontendUsers.remove(user);
      user.socket.close();
    } catch (e) {
      _logger.severe('Error while handling frontend user disconnection: $e');
    }
  }

  void clear() {
    try {
      isolate.kill(priority: Isolate.immediate);
      socket.close();
      for (var user in frontendUsers) {
        user.socket.close();
      }
      frontendUsers.clear();
      sendPort = null;
    } catch (e) {
      _logger.severe('Error while clearing the isolate: $e');
    }
  }
}

class MainIsolatedManager {
  final TwitchEbsManagerAbstract Function({
    required String broadcasterId,
    required TwitchEbsInfo ebsInfo,
    required SendPort sendPort,
  }) _twitchEbsManagerFactory;

  // Prepare the singleton instance
  static MainIsolatedManager? _instance;
  static MainIsolatedManager get instance {
    if (_instance == null) {
      throw Exception('IsolatedMainManager not initialized, please call, '
          'IsolatedMainManager.initialize before using it');
    }
    return _instance!;
  }

  static void initialize(
    TwitchEbsManagerAbstract Function({
      required String broadcasterId,
      required TwitchEbsInfo ebsInfo,
      required SendPort sendPort,
    }) twitchEbsManagerFactory,
  ) {
    if (_instance != null) {
      throw Exception('IsolatedMainManager already initialized');
    }

    _instance =
        MainIsolatedManager._(twitchEbsManagerFactory: twitchEbsManagerFactory);
  }

  MainIsolatedManager._({
    required TwitchEbsManagerAbstract Function({
      required String broadcasterId,
      required TwitchEbsInfo ebsInfo,
      required SendPort sendPort,
    }) twitchEbsManagerFactory,
  }) : _twitchEbsManagerFactory = twitchEbsManagerFactory;

  final _completers = Completers<MessageProtocol>();
  final Map<String, _IsolatedClientInterface> _isolates = {};

  ///
  /// Launch a new isolated if needed
  Future<void> registerNewBroadcaster({
    required String broadcasterId,
    required WebSocket socket,
    required TwitchEbsInfo ebsInfo,
  }) async {
    final mainReceivePort = ReceivePort();

    // Establish communication with the worker isolate
    mainReceivePort.listen((message) => _handleMessageFromIsolated(
        MessageProtocol.fromJson(message), broadcasterId));

    // Create a new isolated client interface if it does not exist
    if (!_isolates.containsKey(broadcasterId)) {
      _logger.info('Starting a new connexion (broadcasterId: $broadcasterId)');
      _isolates[broadcasterId] = _IsolatedClientInterface(
          broadcasterId: broadcasterId,
          isolate: await Isolate.spawn(twitchEbsManagerSpawner, {
            'broadcaster_id': broadcasterId,
            'ebs_info': ebsInfo,
            'send_port': mainReceivePort.sendPort,
            'ebs_manager_factory': _twitchEbsManagerFactory,
          }),
          socket: socket);
    }
  }

  Future<void> registerNewFrontendUser({
    required String broadcasterId,
    required String opaqueId,
    required String? userId,
    required WebSocket socket,
  }) async {
    try {
      // Wait for the main client to be created
      while (!_isolates.containsKey(broadcasterId)) {
        if (socket.closeCode != null) {
          return;
        }

        _logger.fine('No active client with id: $broadcasterId');
        await Future.delayed(const Duration(seconds: 10));
      }

      _isolates[broadcasterId]!.addFrontendUser(
          _FrontendUser(opaqueId: opaqueId, userId: userId, socket: socket));
    } catch (e) {
      socket.close();
      return;
    }
  }

  ///
  /// Stop all clients
  void killAllIsolates() {
    for (var interface in _isolates.values) {
      interface.clear();
    }
    _isolates.clear();
  }

  Future<void> _handleMessageFromIsolated(
      MessageProtocol message, String broadcasterId) async {
    try {
      switch (message.to) {
        case MessageTo.ebsMain:
          await _handleMessageFromIsolatedToMain(message, broadcasterId);
          break;
        case MessageTo.app:
          await _handleMessageFromIsolatedToApp(message, broadcasterId);
          break;
        case MessageTo.frontend:
          await _handleMessageFromIsolatedToFrontends(message, broadcasterId);
          break;
        case MessageTo.pubsub:
          await _handleMessageFromIsolatedToPubsub(message, broadcasterId);
          break;
        case MessageTo.ebs:
        case MessageTo.generic:
          throw InvalidTargetException();
      }
    } catch (e) {
      _logger.severe('Error while handling message from isolated: $e');
    }
  }

  Future<void> _handleMessageFromIsolatedToMain(
    MessageProtocol message,
    String broadcasterId,
  ) async {
    switch (message.type) {
      case MessageTypes.handShake:
        _logger.info('Isolated client with id: $broadcasterId has connected');
        final isolate = _isolates[broadcasterId]!;

        isolate.sendPort = message.data!['send_port'];
        break;

      case MessageTypes.response:
        final completerId = message.internalMain!['completer_id'] as int;
        _completers.complete(completerId, data: message);
        break;

      case MessageTypes.disconnect:
        _logger.info('Disconnecting client with id: $broadcasterId');
        _isolates.remove(broadcasterId)?.clear();
        break;

      case MessageTypes.ping:
      case MessageTypes.pong:
      case MessageTypes.get:
      case MessageTypes.put:
      case MessageTypes.bitTransaction:
        _logger.severe('Message type not handled: ${message.type}');
        // Do nothing
        break;
    }
  }

  Future<void> _handleMessageFromIsolatedToApp(
    MessageProtocol message,
    String broadcasterId,
  ) async {
    _isolates[broadcasterId]?.socket.add(message.encode());
  }

  Future<void> _handleMessageFromIsolatedToFrontends(
    MessageProtocol message,
    String broadcasterId,
  ) async {
    if (message.internalMain?['completer_id'] != null) {
      // If this message is for a specific completer, complete it and let the
      // completer send the response
      final completerId = message.internalMain!['completer_id'] as int;
      _completers.complete(completerId, data: message);
      return;
    }

    final encodedMessage = message.encode();
    _isolates[broadcasterId]
        ?.frontendUsers
        .forEach((user) => user.socket.add(encodedMessage));
  }

  Future<void> _handleMessageFromIsolatedToPubsub(
      MessageProtocol message, String broadcasterId) async {
    _logger
        .severe('Message to pubsub are supposed to be sent from the isolated');
  }

  Future<void> messageFromAppToIsolated(
      MessageProtocol message, WebSocket socket) async {
    final broadcasterId = message.data?['broadcaster_id'] as String?;
    if (broadcasterId == null) {
      _logger.severe('No broadcasterId found in message from app to isolated');
      throw NoBroadcasterIdException();
    }

    final sendPort = _isolates[broadcasterId]?.sendPort;
    if (sendPort == null) {
      _logger.info('No active client with id: $broadcasterId');
      return;
    }

    // Relay the message to the worker isolate
    sendPort.send(message.encode());
  }

  Future<MessageProtocol> messageFromFrontendToIsolated(
      {required MessageProtocol message}) async {
    final broadcasterId = message.data?['broadcaster_id'] as String?;
    if (broadcasterId == null) {
      _logger.severe(
          'No broadcasterId found in message from frontend to isolated');
      throw NoBroadcasterIdException();
    }

    final sendPort = _isolates[broadcasterId]?.sendPort;
    if (sendPort == null) {
      _logger.info('No active client with id: $broadcasterId');
      return MessageProtocol(
          to: MessageTo.frontend,
          from: MessageFrom.ebs,
          type: MessageTypes.response,
          isSuccess: false,
          data: {'error_message': 'No active client with id: $broadcasterId'});
    }

    // Relay the message to the worker isolate
    final completerId = _completers.spawn();
    sendPort.send(message.copyWith(
        from: message.from,
        to: message.to,
        type: message.type,
        internalMain: {'completer_id': completerId}).encode());

    return await _completers.get(completerId)!.future;
  }

  Future<void> messageFromMainToIsolated({
    required String broadcasterId,
    required MessageProtocol message,
  }) async {
    final sendPort = _isolates[broadcasterId]?.sendPort;
    if (sendPort == null) {
      _logger.info('No active client with id: $broadcasterId');
      return;
    }

    sendPort.send(message.encode());
  }
}

///
/// Start a new instance of the isolated, this is the entry point for the worker isolate
void twitchEbsManagerSpawner(Map<String, dynamic> data) async {
  final broadcasterId = data['broadcaster_id'] as String;
  final ebsInfo = data['ebs_info'] as TwitchEbsInfo;
  final sendPort = data['send_port'] as SendPort;
  final ebsManagerfactory =
      data['ebs_manager_factory'] as TwitchEbsManagerAbstract Function({
    required String broadcasterId,
    required TwitchEbsInfo ebsInfo,
    required SendPort sendPort,
  });

  ebsManagerfactory(
      broadcasterId: broadcasterId, ebsInfo: ebsInfo, sendPort: sendPort);
}
