part of 'package:twitch_manager/ebs/network/ebs_server.dart';

Future<void> _handleAppHttpGetRequest(HttpRequest request,
    {required TwitchEbsInfo ebsInfo}) async {
  if (request.uri.path.contains('/connect')) {
    await _handleConnectToWebSocketRequest(request, ebsInfo: ebsInfo);
  } else {
    throw InvalidEndpointException();
  }
}

Future<void> _handleConnectToWebSocketRequest(HttpRequest request,
    {required TwitchEbsInfo ebsInfo}) async {
  try {
    final socket = await WebSocketTransformer.upgrade(request);

    final broadcasterId =
        int.tryParse(request.uri.queryParameters['broadcasterId'] ?? '');
    if (broadcasterId == null) {
      _logger.severe('No broadcasterId found');
      socket.add(MessageProtocol(
              from: MessageFrom.generic,
              to: MessageTo.app,
              type: MessageTypes.response,
              isSuccess: false,
              data: {'error_message': NoBroadcasterIdException().toString()})
          .encode());
      socket.close();
      return;
    }

    _logger.info('New App connexion (broadcasterId: $broadcasterId)');
    await IsolatedMainManager.instance.registerNewBroadcaster(broadcasterId,
        socket: socket, ebsInfo: ebsInfo);

    // Establish a persistent communication with the App
    socket
        .listen((message) => IsolatedMainManager.instance
            .messageFromAppToIsolated(MessageProtocol.decode(message), socket))
        .onDone(
          () => _handleConnexionTerminated(broadcasterId, socket),
        );
  } catch (e) {
    throw ConnexionToWebSocketdRefusedException();
  }
}

Future<void> _handleConnexionTerminated(
    int broadcasterId, WebSocket socket) async {
  IsolatedMainManager.instance.messageFromAppToIsolated(
      MessageProtocol(
          from: MessageFrom.ebsMain,
          to: MessageTo.ebsIsolated,
          type: MessageTypes.disconnect,
          data: {'broadcaster_id': broadcasterId}),
      socket);
}
