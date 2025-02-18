part of 'package:twitch_manager/ebs/network/ebs_server.dart';

Future<void> _handleAppGetRequest(HttpRequest request,
    {required TwitchEbsInfo ebsInfo}) async {
  if (request.uri.path.contains('/connect')) {
    await _handleAppConnectToWebSocketRequest(request, ebsInfo: ebsInfo);
  } else {
    throw InvalidEndpointException();
  }
}

Future<void> _handleAppConnectToWebSocketRequest(HttpRequest request,
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
    await MainIsolatedManager.instance.registerNewBroadcaster(
        broadcasterId: broadcasterId, socket: socket, ebsInfo: ebsInfo);
  } catch (e) {
    throw ConnexionToWebSocketdRefusedException();
  }
}
