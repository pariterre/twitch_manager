import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:twitch_manager/ebs/ebs_exceptions.dart';
import 'package:twitch_manager/twitch_ebs.dart';
import 'package:twitch_manager/utils/completers.dart';

final _logger = Logger('IsolatedMainManagers');

class _IsolatedInterface {
  final Isolate isolate;
  SendPort? sendPort;

  void clear() {
    isolate.kill(priority: Isolate.immediate);
    sendPort = null;
  }

  _IsolatedInterface({required this.isolate});
}

class IsolatedMainManager {
  final TwitchEbsManagerAbstract Function({
    required int broadcasterId,
    required TwitchEbsInfo ebsInfo,
    required SendPort sendPort,
  }) _isolatedFactory;

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
    }) isolatedFactory,
  ) {
    if (_instance != null) {
      throw Exception('IsolatedMainManager already initialized');
    }

    _instance = IsolatedMainManager._(isolatedFactory: isolatedFactory);
  }

  IsolatedMainManager._(
      {required TwitchEbsManagerAbstract Function({
        required int broadcasterId,
        required TwitchEbsInfo ebsInfo,
        required SendPort sendPort,
      }) isolatedFactory})
      : _isolatedFactory = isolatedFactory;

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
      // TODO Check why this does not return (compare with the original code?)
      final isolate = await Isolate.spawn(twitchEbsManagerSpawner, {
        'broadcaster_id': broadcasterId,
        'ebs_info': ebsInfo,
        'send_port': mainReceivePort.sendPort,
        'isolate_factory': _isolatedFactory,
      });
      _isolates[broadcasterId] = _IsolatedInterface(isolate: isolate);
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
        break;

      case MessageTypes.response:
        final completerId = message.internalMain!['completer_id'] as int;
        _completers.complete(completerId, data: message);
        break;

      case MessageTypes.disconnect:
        _handleMessageFromIsolatedToFrontends(
            MessageProtocol(
                from: MessageFrom.ebsMain,
                to: MessageTo.frontend,
                type: MessageTypes.disconnect),
            socket);
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
    // TODO Instanciate the TwitchApi
    _logger.info('Sending message to the frontend: ${message.toJson()}');
    //TwitchApi.instance.sendPubsubMessage(message.toJson());
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
        from: MessageFrom.frontend,
        to: MessageTo.ebsIsolated,
        type: MessageTypes.get,
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
  final factory = data['isolate_factory'] as TwitchEbsManagerAbstract Function(
      {required int broadcasterId,
      required TwitchEbsInfo ebsInfo,
      required SendPort sendPort});

  factory(broadcasterId: broadcasterId, ebsInfo: ebsInfo, sendPort: sendPort);
}

class IsolatedInstance {
  // TODO Add the ebs api
  //   case FromEbsToMainMessages.getUserId:
  //   final response = <String, dynamic>{};
  //   try {
  //     response['user_id'] = await tm.userId(login: message.raw!['login']);
  //   } catch (e) {
  //     response['user_id'] = null;
  //   }
  //   messageFromMainToIsolated(
  //       broadcasterId: isolateData.twitchBroadcasterId,
  //       message: message.copyWith(data: response));
  //   break;

  // case FromEbsToMainMessages.getDisplayName:
  //   final response = <String, dynamic>{};
  //   try {
  //     response['display_name'] =
  //         await tm.displayName(userId: message.raw!['user_id']);
  //   } catch (e) {
  //     response['display_name'] = null;
  //   }
  //   messageFromMainToIsolated(
  //       broadcasterId: isolateData.twitchBroadcasterId,
  //       message: message.copyWith(data: response));
  //   break;

  // case FromEbsToMainMessages.getLogin:
  //   final response = <String, dynamic>{};
  //   try {
  //     response['login'] = await tm.login(userId: message.raw!['user_id']);
  //   } catch (e) {
  //     response['login'] = null;
  //   }
  //   messageFromMainToIsolated(
  //       broadcasterId: isolateData.twitchBroadcasterId,
  //       message: message.copyWith(
  //           fromTo: FromMainToEbsMessages.getLogin, data: response));
  //   break;
}
