import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:twitch_manager/common/communication_protocols.dart';
import 'package:twitch_manager/ebs/ebs_exceptions.dart';
import 'package:twitch_manager/ebs/twitch_ebs_info.dart';
import 'package:twitch_manager/ebs/twitch_ebs_manager_abstract.dart';
import 'package:twitch_manager/utils/completers.dart';
import 'package:twitch_manager/utils/websocket_extension.dart';

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
    socket.listen(_handleMessageFromAppToIsolated,
        onDone: () => _handleClientConnexionTerminated(),
        onError: ((handleError) => _handleClientConnexionTerminated()));
  }

  Future<void> _handleMessageFromAppToIsolated(dynamic message) async {
    try {
      final decodedMessage = MessageProtocol.decode(message);

      await MainIsolatedManager.instance
          ._messageFromAppToIsolated(decodedMessage, socket);
    } catch (e) {
      _logger.severe('Error while handling message from app to isolated', e);
    }
  }

  Future<void> _handleClientConnexionTerminated() async {
    // This will ultimately call the clear method, same as if the client was
    // asking to disconnect themselves
    try {
      await MainIsolatedManager.instance._messageFromAppToIsolated(
          MessageProtocol(
              to: MessageTo.ebs,
              from: MessageFrom.ebsMain,
              type: MessageTypes.disconnect,
              data: {'broadcaster_id': broadcasterId}),
          socket);
    } catch (e) {
      _logger.severe('Error while handling client disconnection', e);
    }
  }

  void _addFrontendUser(_FrontendUser frontendUser) {
    frontendUsers.add(frontendUser);

    frontendUser.socket.listen(
      (message) => _handleMessageFromFrontend(message, frontendUser),
      onDone: () => _handleFrontendUserConnexionTerminated(frontendUser),
      onError: ((handleError) =>
          _handleFrontendUserConnexionTerminated(frontendUser)),
    );
  }

  Future<void> _handleMessageFromFrontend(
      dynamic message, _FrontendUser frontendUser) async {
    try {
      final decodedMessage = MessageProtocol.decode(message);

      final response =
          await MainIsolatedManager.instance._messageFromFrontendToIsolated(
              message: decodedMessage.copyWith(
                  from: decodedMessage.from,
                  to: decodedMessage.to,
                  type: decodedMessage.type,
                  data: decodedMessage.data ?? {}
                    ..addAll({
                      'broadcaster_id': broadcasterId,
                      'user_id': frontendUser.userId,
                      'opaque_id': frontendUser.opaqueId
                    })));

      frontendUser.socket.safeAdd(response.encode(),
          target: 'frontend user ${frontendUser.opaqueId}');
    } catch (e) {
      _logger.severe('Error while handling message from frontend: $e');
      await _handleFrontendUserConnexionTerminated(frontendUser);
    }
  }

  Future<void> _handleFrontendUserConnexionTerminated(
      _FrontendUser user) async {
    try {
      frontendUsers.remove(user);
      await user.socket.close();
    } catch (e) {
      _logger.severe('Error while handling frontend user disconnection: $e');
    }
  }

  Future<void> _clear() async {
    try {
      isolate.kill(priority: Isolate.immediate);
      await socket.close();
      for (var user in frontendUsers) {
        await user.socket.close();
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
    mainReceivePort.listen(
        (message) => _handleMessageFromIsolated(message, broadcasterId));

    // Create a new isolated client interface if it does not exist
    if (!_isolates.containsKey(broadcasterId)) {
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

      _isolates[broadcasterId]!._addFrontendUser(
          _FrontendUser(opaqueId: opaqueId, userId: userId, socket: socket));
    } catch (e) {
      await socket.close();
      return;
    }
  }

  ///
  /// Stop all clients
  Future<void> killAllIsolates() async {
    for (var interface in _isolates.values) {
      await interface._clear();
    }
    _isolates.clear();
  }

  Future<void> _handleMessageFromIsolated(
      dynamic message, String broadcasterId) async {
    final decodedMessage = MessageProtocol.fromJson(message);

    try {
      switch (decodedMessage.to) {
        case MessageTo.ebsMain:
          await _handleMessageFromIsolatedToMain(decodedMessage, broadcasterId);
          break;
        case MessageTo.app:
          await _handleMessageFromIsolatedToApp(decodedMessage, broadcasterId);
          break;
        case MessageTo.frontend:
          await _handleMessageFromIsolatedToFrontends(
              decodedMessage, broadcasterId);
          break;
        case MessageTo.pubsub:
          await _handleMessageFromIsolatedToPubsub(
              decodedMessage, broadcasterId);
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
        await _isolates.remove(broadcasterId)?._clear();
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
    return Future.value();
  }

  Future<void> _handleMessageFromIsolatedToApp(
    MessageProtocol message,
    String broadcasterId,
  ) {
    _isolates[broadcasterId]
        ?.socket
        .safeAdd(message.encode(), target: 'app broadcaster $broadcasterId');
    return Future.value();
  }

  Future<void> _handleMessageFromIsolatedToFrontends(
    MessageProtocol message,
    String broadcasterId,
  ) {
    if (message.internalMain?['completer_id'] != null) {
      // If this message is for a specific completer, complete it and let the
      // completer send the response
      final completerId = message.internalMain!['completer_id'] as int;
      _completers.complete(completerId, data: message);
      return Future.value();
    }

    final encodedMessage = message.encode();
    for (final user in _isolates[broadcasterId]?.frontendUsers ?? const []) {
      user.socket
          .safeAdd(encodedMessage, target: 'frontend user ${user.opaqueId}');
    }
    return Future.value();
  }

  Future<void> _handleMessageFromIsolatedToPubsub(
      MessageProtocol message, String broadcasterId) {
    _logger
        .severe('Message to pubsub are supposed to be sent from the isolated');
    return Future.value();
  }

  Future<void> _messageFromAppToIsolated(
      MessageProtocol message, WebSocket socket) {
    try {
      late final String? broadcasterId;
      if (message.data?['broadcaster_id'] is int) {
        broadcasterId = (message.data?['broadcaster_id'] as int).toString();
      } else {
        broadcasterId = message.data?['broadcaster_id'] as String?;
      }

      if (broadcasterId == null) {
        _logger
            .severe('No broadcasterId found in message from app to isolated');
        throw NoBroadcasterIdException();
      }

      final sendPort = _isolates[broadcasterId]?.sendPort;
      if (sendPort == null) {
        _logger.info('No active client with id: $broadcasterId');
        return Future.value();
      }

      // Relay the message to the worker isolate
      sendPort.send(message.encode());
    } catch (e, st) {
      _logger.severe('Error processing message from app to isolated', e, st);
    }
    return Future.value();
  }

  Future<MessageProtocol> _messageFromFrontendToIsolated(
      {required MessageProtocol message}) async {
    late final String? broadcasterId;
    try {
      if (message.data?['broadcaster_id'] is int) {
        broadcasterId = (message.data?['broadcaster_id'] as int).toString();
      } else {
        broadcasterId = message.data?['broadcaster_id'] as String?;
      }

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
            data: {
              'error_message': 'No active client with id: $broadcasterId'
            });
      }

      // Relay the message to the worker isolate
      final completerId = _completers.spawn();
      sendPort.send(message.copyWith(
          from: message.from,
          to: message.to,
          type: message.type,
          internalMain: {'completer_id': completerId}).encode());

      return await _completers.get(completerId)!.future;
    } catch (e, st) {
      _logger.severe(
          'Error processing message from frontend to isolated', e, st);
      return MessageProtocol(
          to: MessageTo.frontend,
          from: MessageFrom.ebs,
          type: MessageTypes.response,
          isSuccess: false,
          data: {'error_message': 'Error processing message: $e'});
    }
  }
}

///
/// Start a new instance of the isolated, this is the entry point for the worker isolate
void twitchEbsManagerSpawner(Map<String, dynamic> data) {
  try {
    late final String? broadcasterId;
    if (data['broadcaster_id'] is int) {
      broadcasterId = (data['broadcaster_id'] as int).toString();
    } else {
      broadcasterId = data['broadcaster_id'] as String;
    }

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
  } catch (e, st) {
    _logger.severe('Error while spawning Twitch EBS Manager isolate', e, st);
  }
}
