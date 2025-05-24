part of 'package:twitch_manager/ebs/network/ebs_server.dart';

Future<void> _handleFrontendGetRequest(HttpRequest request,
    {required TwitchEbsInfo ebsInfo}) async {
  if (request.uri.path.contains('/connect')) {
    await _handleFrontendConnectToWebSocketRequest(request, ebsInfo: ebsInfo);
  } else {
    throw InvalidEndpointException();
  }
}

Future<void> _handleFrontendConnectToWebSocketRequest(HttpRequest request,
    {required TwitchEbsInfo ebsInfo}) async {
  _logger.info('Answering GET request to ${request.uri.path}');

  // Extract the payload from the JWT, if it succeeds, the user is authorized,
  // otherwise an exception is thrown
  final payload = _extractJwtPayload(request, ebsInfo: ebsInfo);

  final broadcasterId = int.tryParse(payload?['channel_id']);
  final opaqueId = payload?['opaque_user_id'] as String?;
  final userId = int.tryParse(payload?['user_id']);
  if (broadcasterId == null) {
    _logger.severe('No broadcasterId found');
    throw UnauthorizedException();
  }
  if (opaqueId == null) {
    _logger.severe('No opaqueId found');
    throw UnauthorizedException();
  }

  // Upgrade the request to a WebSocket connection
  late final WebSocket socket;
  try {
    // We must "choose" the Sec-WebSocket-Protocol here, otherwise the
    // connection will be disconnected by some web browsers. Note this response
    // is encrypted by the fact that https is used. It is therefore correct to
    // send the shared secret in the response.
    socket = await WebSocketTransformer.upgrade(request,
        protocolSelector: (protocols) {
      for (final protocol in protocols) {
        if (protocol.startsWith('Bearer-')) return protocol;
      }
      throw ConnexionToWebSocketdRefusedException();
    });
  } catch (e) {
    throw ConnexionToWebSocketdRefusedException();
  }

  _logger.info('New frontend connexion (broadcasterId: $broadcasterId)');
  MainIsolatedManager.instance.registerNewFrontendUser(
      broadcasterId: broadcasterId,
      socket: socket,
      opaqueId: opaqueId,
      userId: userId);
}

Map<String, dynamic>? _extractJwtPayload(HttpRequest request,
    {required TwitchEbsInfo ebsInfo}) {
  // For some reason, it is not possible to pass headers to the WebSocket. So
  // we hack it by passing the token in the protocols field. This will be
  // stored in the Sec-WebSocket-Protocol header.
  final authHeader = request.headers['sec-websocket-protocol']?.first;
  if (authHeader == null || !authHeader.startsWith('Bearer-')) {
    throw UnauthorizedException();
  }
  // Extract the Bearer token by removing 'Bearer ' from the start
  final bearer = authHeader.substring(7);
  try {
    final decodedJwt = JWT.verify(
        bearer, SecretKey(ebsInfo.sharedSecret!, isBase64Encoded: true));
    return decodedJwt.payload;
  } on JWTExpiredException {
    // If the problem is only that JWT is expired, we log it, but we still accept
    _logger.warning('JWT token is expired, but we still accept it...');
    final decodedJwt = JWT.decode(bearer);
    return decodedJwt.payload;
  } catch (e) {
    // If the token is invalid, an exception is thrown
    _logger.severe('JWT token is invalid: $e');
    throw UnauthorizedException();
  }
}
