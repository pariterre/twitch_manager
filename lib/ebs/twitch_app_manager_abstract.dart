import 'dart:async';

import 'package:logging/logging.dart';
import 'package:twitch_manager/ebs/network/communication_protocols.dart';
import 'package:twitch_manager/twitch_utils.dart';
import 'package:web_socket_client/web_socket_client.dart';

final _logger = Logger('TwitchAppManagerAbstract');

abstract class TwitchAppManagerAbstract {
  WebSocket? _socket;
  final Uri? ebsUri;

  int? _broadcasterId;
  int get broadcasterId {
    if (_broadcasterId == null) {
      throw Exception(
          'The TwitchAppManagerAbstract has not been connected. Please call connect() first');
    }
    return _broadcasterId!;
  }

  ///
  /// Add a way to complete requests
  final _completers = Completers<MessageProtocol>();

  /// Setup a method to wait for the TwitchManager
  TwitchAppManagerAbstract({required this.ebsUri});

  ///
  /// Connect to the EBS server
  bool get isConnectedToEbs =>
      _socket?.connection.state is Connected ||
      _socket?.connection.state is Reconnected;
  final onEbsHasConnected = TwitchListener<Function()>();
  final onEbsHasDisconnected = TwitchListener<Function()>();

  ///
  /// Connect to the EBS server.
  /// To get the [broadcasterId] one should use [TwitchAppManager.api.streamerId].
  Future<void> connect(int broadcasterId) async {
    _logger.info('Connecting to EBS server');
    _broadcasterId = broadcasterId;

    if (ebsUri == null) return;

    // Connect to EBS server
    _socket = WebSocket(
        Uri.parse('$ebsUri/app/connect?broadcasterId=$broadcasterId'),
        backoff: const ConstantBackoff(Duration(seconds: 10)));

    // Handle connection state changes
    _socket!.connection.listen((state) {
      if (state is Connected || state is Reconnected) {
        _logger.info('Connected to the EBS server');
        onEbsHasConnected.notifyListeners((callback) => callback());
      } else if (state is Disconnected) {
        _logger.severe('Disconnected from EBS');
        onEbsHasDisconnected.notifyListeners((callback) => callback());
      } else if (state is Reconnecting) {
        _logger.warning('Reconnecting to EBS...');
      }
    });

    // Listen for messages from the EBS server
    _socket!.messages.listen((message) async {
      try {
        await _handleMessageFromEbs(MessageProtocol.decode(message));
      } catch (e) {
        // Do nothing, this is to prevent the program from crashing
        // When ill-formatted messages are received
        _logger.severe('Error while handling message from EBS: $e');
      }
    });
  }

  ///
  /// Disconnect from the EBS server
  // TODO to implement a proper disconnect method

  ///
  /// Send a message to the EBS server
  Future<MessageProtocol> sendQuestionToEbs(MessageProtocol message) {
    try {
      final completerId = _completers.spawn();

      final augmentedMessage = message.copyWith(
          from: message.from,
          to: message.to,
          type: message.type,
          data: (message.data ?? {})..addAll({'broadcaster_id': broadcasterId}),
          internalClient: {'completer_id': completerId});
      _socket!.send(augmentedMessage.encode());

      return _completers.get(completerId)!.future;
    } catch (e) {
      _logger.severe('Error while sending message to EBS: $e');
      rethrow;
    }
  }

  ///
  /// Send a message to the EBS server
  void sendMessageToEbs(MessageProtocol message) {
    try {
      final augmentedMessage = message.copyWith(
          from: message.from,
          to: message.to,
          type: message.type,
          data: (message.data ?? {})
            ..addAll({'broadcaster_id': broadcasterId}));
      _socket!.send(augmentedMessage.encode());
    } catch (e) {
      _logger.severe('Error while sending message to EBS: $e');
    }
  }

  void sendResponseToEbs(MessageProtocol message) {
    sendMessageToEbs(message.copyWith(
      to: MessageTo.ebs,
      from: MessageFrom.app,
      type: MessageTypes.response,
    ));
  }

  ///
  /// Handle the messages received from the EBS server. This method should be
  /// overridden by the child class to handle the messages.
  Future<void> handleGetRequest(MessageProtocol message);

  ///
  /// Handle the messages received from the EBS server. This method should be
  /// overridden by the child class to handle the messages.
  Future<void> handlePutRequest(MessageProtocol message);

  ///
  /// Handle the messages received from the EBS server
  Future<void> _handleMessageFromEbs(MessageProtocol message) async {
    switch (message.type) {
      case MessageTypes.handShake:
        _logger.info('EBS server has connected');
        return;
      case MessageTypes.ping:
        _logger.info('Ping received, sending pong');
        sendMessageToEbs(message.copyWith(
          to: MessageTo.ebs,
          from: MessageFrom.app,
          type: MessageTypes.pong,
        ));
        return;
      case MessageTypes.pong:
      case MessageTypes.response:
        final completerId = message.internalClient!['completer_id'] as int;
        _completers.get(completerId)!.complete(message);
        return;
      case MessageTypes.disconnect:
        _logger
            .severe('EBS server has disconnected, reconnecting in 10 seconds');
        Future.delayed(const Duration(seconds: 10))
            .then((_) => connect(broadcasterId));
        break;
      case MessageTypes.get:
        await handleGetRequest(message);
        break;
      case MessageTypes.put:
        await handlePutRequest(message);
        break;
      case MessageTypes.bitTransaction:
        throw Exception(
            'Bit transactions message are supposed to be handled by the EBS');
    }
  }
}
