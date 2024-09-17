import 'dart:async';

import 'package:logging/logging.dart';
import 'package:twitch_manager/ebs/network/communication_protocols.dart';
import 'package:twitch_manager/twitch_utils.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final _logger = Logger('TwitchAppManagerAbstract');

abstract class TwitchAppManagerAbstract {
  WebSocketChannel? _socket;
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
  final _completers = Completers();

  /// Setup a method to wait for the TwitchManager
  TwitchAppManagerAbstract({required this.ebsUri});

  ///
  /// Connect to the EBS server
  bool _isConnectedToEbs = false;
  bool get isConnectedToEbs => _isConnectedToEbs;
  Completer<bool>? _hasConnectedToEbsCompleter;
  StreamSubscription? _ebsStreamSubscription;
  final onEbsHasConnected = TwitchListener();
  final onEbsHasDisconnected = TwitchListener();

  ///
  /// Connect to the EBS server, to get the [broadcasterId] the developer can
  /// use the relevant info gathered from the TwitchAppManager
  Future<void> connect(int broadcasterId) async {
    _logger.info('Connecting to EBS server');
    _broadcasterId = broadcasterId;

    Future<void> retry(String errorMessage) async {
      if (_hasConnectedToEbsCompleter != null) return;
      // TODO Fix only trying to reconnect once
      _logger.severe(errorMessage);
      // Do some clean up
      _isConnectedToEbs = false;
      _ebsStreamSubscription?.cancel();
      _logger.severe('Reconnecting to EBS in 10 seconds');
      await Future.delayed(const Duration(seconds: 10));
      connect(broadcasterId);
    }

    if (ebsUri == null) return;

    // If we already are connecting, return the future
    if (_hasConnectedToEbsCompleter != null) return;
    _hasConnectedToEbsCompleter = Completer();

    // Connect to EBS server
    try {
      _socket = WebSocketChannel.connect(
          Uri.parse('$ebsUri/app/connect?broadcasterId=$broadcasterId'));
      await _socket!.ready;
    } catch (e) {
      retry('Could not connect to EBS');
      return;
    }

    // Listen to the messages from the EBS server
    _ebsStreamSubscription = _socket!.stream.listen(
      (message) async {
        try {
          await _handleMessageFromEbs(MessageProtocol.decode(message));
        } catch (e) {
          // Do nothing, this is to prevent the program from crashing
          // When ill-formatted messages are received
          _logger.severe('Error while handling message from EBS: $e');
        }
      },
      onDone: () {
        _socket?.sink.close();
        onEbsHasDisconnected.notifyListeners((callback) => callback());
        retry('Connection closed by the EBS server');
      },
      onError: (error) {
        _socket?.sink.close();
        onEbsHasDisconnected.notifyListeners((callback) => callback());
        retry('Error with communicating to the EBS server: $error');
      },
    );

    try {
      final isConnected = await _hasConnectedToEbsCompleter!.future
          .timeout(const Duration(seconds: 30), onTimeout: () => false);
      if (!isConnected) throw Exception('Timeout');
    } catch (e) {
      _hasConnectedToEbsCompleter = null;
      return retry('Error while connecting to EBS: $e');
    }

    _logger.info('Connected to the EBS server');
    _hasConnectedToEbsCompleter = null;
    _isConnectedToEbs = true;
    onEbsHasConnected.notifyListeners((callback) => callback());
    return;
  }

  ///
  /// Send a message to the EBS server
  Future<dynamic> sendQuestionToEbs(MessageProtocol message) {
    try {
      final completerId = _completers.spawn();

      final augmentedMessage = message.copyWith(
          from: message.from,
          to: message.to,
          type: message.type,
          data: (message.data ?? {})..addAll({'broadcaster_id': broadcasterId}),
          internalClient: {'completer_id': completerId});
      _socket!.sink.add(augmentedMessage.encode());

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
      _socket!.sink.add(augmentedMessage.encode());
    } catch (e) {
      _logger.severe('Error while sending message to EBS: $e');
    }
  }

  void sendResponseToEbs(MessageProtocol message) {
    sendMessageToEbs(message.copyWith(
      from: MessageFrom.app,
      to: MessageTo.ebsIsolated,
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
    final messageType = message.type;

    switch (messageType) {
      case MessageTypes.handShake:
        _logger.info('EBS server has connected');
        _hasConnectedToEbsCompleter?.complete(true);
        return;
      case MessageTypes.ping:
        _logger.info('Ping received, sending pong');
        sendMessageToEbs(message.copyWith(
            from: MessageFrom.app,
            to: MessageTo.ebsIsolated,
            type: MessageTypes.pong));
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
    }
  }
}
