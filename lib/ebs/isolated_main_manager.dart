import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:twitch_manager/ebs/ebs_exceptions.dart';
import 'package:twitch_manager/twitch_ebs.dart';
import 'package:twitch_manager/utils/completers.dart';

final _logger = Logger('IsolatedMainManager');

class _IsolatedInterface {
  final Isolate isolate;
  SendPort? sendPort;
  WebSocket? socket;

  void clear() {
    isolate.kill(priority: Isolate.immediate);
    socket?.close();
    sendPort = null;
  }

  _IsolatedInterface({required this.isolate});
}

class IsolatedMainManager {
  final TwitchEbsManagerAbstract Function({
    required int broadcasterId,
    required TwitchEbsInfo ebsInfo,
    required SendPort sendPort,
  }) _twitchEbsManagerFactory;

  // Prepare the singleton instance
  static IsolatedMainManager? _instance;
  static IsolatedMainManager get instance {
    if (_instance == null) {
      throw Exception('IsolatedMainManager not initialized, please call, '
          'IsolatedMainManager.initialize before using it');
    }
    return _instance!;
  }

  static void initialize(
    TwitchEbsManagerAbstract Function({
      required int broadcasterId,
      required TwitchEbsInfo ebsInfo,
      required SendPort sendPort,
    }) twitchEbsManagerFactory,
  ) {
    if (_instance != null) {
      throw Exception('IsolatedMainManager already initialized');
    }

    _instance =
        IsolatedMainManager._(twitchEbsManagerFactory: twitchEbsManagerFactory);
  }

  IsolatedMainManager._(
      {required TwitchEbsManagerAbstract Function({
        required int broadcasterId,
        required TwitchEbsInfo ebsInfo,
        required SendPort sendPort,
      }) twitchEbsManagerFactory})
      : _twitchEbsManagerFactory = twitchEbsManagerFactory;

  final _completers = Completers();
  final Map<int, _IsolatedInterface> _isolates = {};

  ///
  /// Launch a new game
  /// Returns if a new game was indeed created. If false, it means we should not
  /// listen to the websocket anymore as it is already connected to a game.
  Future<void> registerNewBroadcaster(int broadcasterId,
      {required WebSocket socket, required TwitchEbsInfo ebsInfo}) async {
    final mainReceivePort = ReceivePort();

    // Establish communication with the worker isolate
    mainReceivePort.listen((message) => _handleMessageFromIsolated(
        MessageProtocol.fromJson(message), socket, broadcasterId));

    // Create a new game
    if (!_isolates.containsKey(broadcasterId)) {
      _logger.info('Starting a new connexion (broadcasterId: $broadcasterId)');
      _isolates[broadcasterId] = _IsolatedInterface(
          isolate: await Isolate.spawn(twitchEbsManagerSpawner, {
        'broadcaster_id': broadcasterId,
        'ebs_info': ebsInfo,
        'send_port': mainReceivePort.sendPort,
        'ebs_manager_factory': _twitchEbsManagerFactory,
      }));
    }
  }

  ///
  /// Stop all games
  void killAllIsolates() {
    for (var interface in _isolates.values) {
      interface.clear();
    }
    _isolates.clear();
  }

  Future<void> _handleMessageFromIsolated(
      MessageProtocol message, WebSocket socket, int broadcasterId) async {
    try {
      switch (message.to) {
        case MessageTo.ebsMain:
          await _handleMessageFromIsolatedToMain(
              message, socket, broadcasterId);
          break;
        case MessageTo.app:
          await _handleMessageFromIsolatedToApp(message, socket);
          break;
        case MessageTo.frontend:
          await _handleMessageFromIsolatedToFrontends(message, socket);
          break;
        case MessageTo.ebsIsolated:
        case MessageTo.generic:
          throw InvalidTargetException();
      }
    } catch (e) {
      _logger.severe('Error while handling message from isolated: $e');
    }
  }

  Future<void> _handleMessageFromIsolatedToMain(
      MessageProtocol message, WebSocket socket, int broadcasterId) async {
    switch (message.type) {
      case MessageTypes.handShake:
        final isolate = _isolates[broadcasterId]!;

        isolate.sendPort = message.data!['send_port'];
        isolate.socket = socket;
        break;

      case MessageTypes.response:
        final completerId = message.internalMain!['completer_id'] as int;
        _completers.complete(completerId, data: message);
        break;

      case MessageTypes.disconnect:
        _isolates.remove(broadcasterId)?.clear();
        break;

      case MessageTypes.ping:
      case MessageTypes.pong:
      case MessageTypes.get:
      case MessageTypes.put:
        _logger.severe('Message type not handled: ${message.type}');
        // Do nothing
        break;
    }
  }

  Future<void> _handleMessageFromIsolatedToApp(
      MessageProtocol message, WebSocket socket) async {
    socket.add(message.encode());
  }

  Future<void> _handleMessageFromIsolatedToFrontends(
      MessageProtocol message, WebSocket socket) async {
    _logger.severe(
        'Message to frontend are supposed to be sent from the isolated');
  }

  Future<void> messageFromAppToIsolated(
      MessageProtocol message, WebSocket socket) async {
    final broadcasterId = message.data?['broadcaster_id'];

    final sendPort = _isolates[broadcasterId]?.sendPort;
    if (sendPort == null) {
      _logger.info('No active game with id: $broadcasterId');
      return;
    }

    // Relay the message to the worker isolate
    sendPort.send(message.encode());
  }

  Future<MessageProtocol> messageFromFrontendToIsolated(
      {required MessageProtocol message}) async {
    final broadcasterId = message.data?['broadcaster_id'];

    final sendPort = _isolates[broadcasterId]?.sendPort;
    if (sendPort == null) {
      _logger.info('No active game with id: $broadcasterId');
      return MessageProtocol(
          from: MessageFrom.ebsIsolated,
          to: MessageTo.frontend,
          type: MessageTypes.response,
          isSuccess: false,
          data: {'error_message': 'No active game with id: $broadcasterId'});
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
    required int broadcasterId,
    required MessageProtocol message,
  }) async {
    final sendPort = _isolates[broadcasterId]?.sendPort;
    if (sendPort == null) {
      _logger.info('No active game with id: $broadcasterId');
      return;
    }

    sendPort.send(message.encode());
  }
}

///
/// Start a new instance of the isolated, this is the entry point for the worker isolate
void twitchEbsManagerSpawner(Map<String, dynamic> data) async {
  final broadcasterId = data['broadcaster_id'] as int;
  final ebsInfo = data['ebs_info'] as TwitchEbsInfo;
  final sendPort = data['send_port'] as SendPort;
  final ebsManagerfactory = data['ebs_manager_factory']
      as TwitchEbsManagerAbstract Function(
          {required int broadcasterId,
          required TwitchEbsInfo ebsInfo,
          required SendPort sendPort});

  ebsManagerfactory(
      broadcasterId: broadcasterId, ebsInfo: ebsInfo, sendPort: sendPort);
}
