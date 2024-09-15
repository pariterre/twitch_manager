part of 'package:twitch_manager/models/ebs/network/http_server.dart';

Future<void> _handleFrontendHttpRequest(HttpRequest request) async {
  _logger.info('Answering GET request to ${request.uri.path}');

  // Extract the payload from the JWT, if it succeeds, the user is authorized,
  // otherwise an exception is thrown
  final payload = _extractJwtPayload(request);

  final broadcasterId = int.parse(payload?['channel_id']);
  final userId = int.tryParse(payload?['user_id']);
  final opaqueUserId = payload?['opaque_user_id'];

  // Get the message of the POST request
  final response = await IsolatedMainManager.instance
      .messageFromFrontendToIsolated(
          message: MessageProtocol(
              from: MessageFrom.frontend,
              to: MessageTo.ebsIsolated,
              type: MessageTypes.get,
              data: {
        'type': request.uri.path,
        'broadcaster_id': broadcasterId,
        'user_id': userId,
        'opaque_id': opaqueUserId
      }));

  final isSuccess = response.isSuccess ?? false;
  if (!isSuccess) {
    try {
      final errorMessage = response.data!['error_message'] as String;
      if (errorMessage == UnauthorizedException().toString()) {
        throw UnauthorizedException();
      } else if (errorMessage == InvalidEndpointException().toString()) {
        throw InvalidEndpointException();
      } else {
        throw Exception();
      }
    } catch (e) {
      throw Exception();
    }
  }

  _sendSuccessResponse(request, response);
}

Map<String, dynamic>? _extractJwtPayload(HttpRequest request) {
  // Extract the Authorization header
  final authHeader = request.headers['Authorization']?.first;
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    throw UnauthorizedException();
  }
// Extract the Bearer token by removing 'Bearer ' from the start
  final bearer = authHeader.substring(7);
  // If the token is invalid, an exception is thrown
  final decodedJwt = TwitchEbsManager.instance.verifyAndDecode(bearer);

  return decodedJwt.payload;
}
