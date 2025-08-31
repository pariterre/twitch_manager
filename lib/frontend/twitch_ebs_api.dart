import 'dart:async';

import 'package:logging/logging.dart';
import 'package:twitch_manager/abstract/twitch_authenticator.dart';
import 'package:twitch_manager/ebs/network/communication_protocols.dart';
import 'package:twitch_manager/frontend/twitch_frontend_info.dart';
import 'package:twitch_manager/twitch_utils.dart';
import 'package:web_socket_client/web_socket_client.dart';

final _logger = Logger('TwitchEbsApi');

///
/// This is the frontend implementation of the Twitch EBS API. The EBS side
/// must be implemented in a separate project, and there is unfortunately no
/// way to provide a complete example of the EBS side in this project, as it
/// can be implemented in any language or framework.
class TwitchEbsApi {
  final TwitchFrontendInfo appInfo;
  final TwitchJwtAuthenticator authenticator;
  WebSocket? _socket;
  final _completers = Completers<MessageProtocol>();

  Function(MessageProtocol)? _onMessageReceivedCallback;

  TwitchEbsApi({required this.appInfo, required this.authenticator});

  ///
  /// If the EBS server is connected, this returns true.
  bool get isConnected =>
      _socket?.connection.state is Connected ||
      _socket?.connection.state is Reconnected;

  ///
  /// If the streamer is connected to the EBS server
  bool _isStreamerConnected = false;
  bool get isStreamerConnected => _isStreamerConnected;
  bool get isStreamerNotConnected => !_isStreamerConnected;

  ///
  /// Connect to a listener to get notified when the streamer has connected
  final onStreamerHasConnected = TwitchListener<Function()>();

  ///
  /// Connect to a listener to get notified when the streamer has disconnected
  final onStreamerHasDisconnected = TwitchListener<Function()>();

  ///
  /// Connect a WebSocket to the EBS server
  Future<void> connect(
      {required Function(MessageProtocol) onResponseFromEbs}) async {
    _logger.info('Connecting to EBS server');

    _onMessageReceivedCallback = onResponseFromEbs;

    // Connect to EBS server
    // For no reason, it is not possible to pass Headers to the WebSocket. So
    // we hack it by passing the token in the protocols field. This will be
    // stored in the Sec-WebSocket-Protocol header.
    _socket = WebSocket(
      Uri.parse('${appInfo.ebsUri}/frontend/connect'),
      backoff: const ConstantBackoff(Duration(seconds: 10)),
      protocols: ['Bearer-${authenticator.ebsToken!.accessToken}'],
    );

    // Handle connection state changes
    _socket!.connection.listen((state) async {
      if (state is Connected || state is Reconnected) {
        _logger.info('Connected to the EBS server');
        try {
          // This handshake completes only when the EBS server connects with the streamer
          await send(MessageProtocol(
              to: MessageTo.ebs,
              from: MessageFrom.frontend,
              type: MessageTypes.handShake));

          _isStreamerConnected = true;
          onStreamerHasConnected.notifyListeners((callback) => callback());
        } catch (e) {
          _isStreamerConnected = false;
          onStreamerHasDisconnected.notifyListeners((callback) => callback());
          _logger.severe('Error while sending handshake to EBS: $e');
        }
      } else if (state is Disconnected) {
        _logger.severe('Disconnected from EBS');

        _isStreamerConnected = false;
        onStreamerHasDisconnected.notifyListeners((callback) => callback());
      } else if (state is Reconnecting) {
        _logger.warning('Reconnecting to EBS...');
      }
    });

    // Listen for messages from the EBS server
    _socket!.messages.listen((raw) async {
      try {
        final message = MessageProtocol.decode(raw);
        final completer = _completers
            .get(message.internalFrontend?['completer_id'] as int? ?? -1);
        if (message.type == MessageTypes.response && completer != null) {
          completer.complete(message);
        } else {
          _onMessageReceivedCallback!(message);
        }
      } catch (e) {
        // Do nothing, this is to prevent the program from crashing
        // When ill-formatted messages are received
        _logger.severe('Error while handling message from EBS: $e');
      }
    });
  }

  ///
  /// This method sends request to the EBS server via the websocket.
  /// The method returns a Map<String, dynamic> with the response from the EBS server.
  /// If the socket is not connected, an exception is thrown.
  Future<MessageProtocol> send(MessageProtocol message,
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_socket == null) {
      throw Exception('Socket is not connected');
    }

    final completerId = _completers.spawn();
    _socket!.send(message.copyWith(
        from: MessageFrom.frontend,
        to: message.to,
        type: message.type,
        internalFrontend: {'completer_id': completerId}).encode());
    return await _completers.get(completerId)!.future.timeout(timeout,
        onTimeout: () {
      throw TimeoutException('Request to EBS timed out');
    });
  }
}
