import 'dart:async';

import 'package:logging/logging.dart';
import 'package:twitch_manager/abstract/twitch_authenticator.dart';
import 'package:twitch_manager/ebs/network/communication_protocols.dart';
import 'package:twitch_manager/frontend/twitch_frontend_info.dart';
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
  final List<Completer<MessageProtocol>> _pendingRequests = [];

  Function(MessageProtocol)? _onMessageReceivedCallback;

  TwitchEbsApi({required this.appInfo, required this.authenticator});

  bool get isConnected =>
      _socket?.connection.state is Connected ||
      _socket?.connection.state is Reconnected;

  ///
  /// Connect a WebSocket to the EBS server
  Future<void> connect(
      {required Function(MessageProtocol) onMessageReceived}) async {
    _logger.info('Connecting to EBS server');

    _onMessageReceivedCallback = onMessageReceived;

    // Connect to EBS server
    // For no reason, it is not possible to pass Headers to the WebSocket. So
    // we hack it by passing the token in the protocols field. This will be
    // stored in the Sec-WebSocket-Protocol header.
    _socket = WebSocket(
      Uri.parse('${appInfo.ebsUri}/frontend/connect'),
      backoff: const ConstantBackoff(Duration(seconds: 10)),
      protocols: ['Bearer-${authenticator.ebsToken}'],
    );

    // Handle connection state changes
    _socket!.connection.listen((state) {
      if (state is Connected || state is Reconnected) {
        _logger.info('Connected to the EBS server');
      } else if (state is Disconnected) {
        // TODO Send a message to the frontend to inform that the connection is lost
        _logger.severe('Disconnected from EBS');
      } else if (state is Reconnecting) {
        _logger.warning('Reconnecting to EBS...');
      }
    });

    // Listen for messages from the EBS server
    _socket!.messages.listen((message) async {
      try {
        final decodedMessage = MessageProtocol.decode(message);

        if (decodedMessage.type == MessageTypes.response &&
            _pendingRequests
                .contains(decodedMessage.internalFrontend?['completer_id'])) {
          final completer = _pendingRequests
              .removeAt(decodedMessage.internalFrontend?['completer_id']);
          completer.complete(decodedMessage);
        } else {
          _onMessageReceivedCallback!(decodedMessage);
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
  Future<MessageProtocol> send(MessageProtocol message) async {
    if (_socket == null) {
      throw Exception('Socket is not connected');
    }

    final completer = Completer<MessageProtocol>();
    _socket!.send(message.copyWith(
        from: MessageFrom.frontend,
        to: message.to,
        type: message.type,
        internalFrontend: {'completer_id': _pendingRequests.length}).encode());

    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      throw TimeoutException('Request to EBS timed out');
    });
  }
}
