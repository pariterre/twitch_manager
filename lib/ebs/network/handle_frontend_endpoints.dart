part of 'package:twitch_manager/ebs/network/ebs_server.dart';

Future<void> _handleFrontendHttpRequest(HttpRequest request,
    {required TwitchEbsInfo ebsInfo}) async {
  _logger.info('Answering GET request to ${request.uri.path}');

  // Extract the payload from the JWT, if it succeeds, the user is authorized,
  // otherwise an exception is thrown
  final payload = _extractJwtPayload(request, ebsInfo: ebsInfo);

  final broadcasterId = int.parse(payload?['channel_id']);
  final userId = int.tryParse(payload?['user_id']);
  final opaqueUserId = payload?['opaque_user_id'];

  // Parse the body of the POST request
  final body = await utf8.decoder.bind(request).join();
  final message = MessageProtocol.decode(body);
  final data = message.data ?? {};

  // Get the message of the POST request
  final response = await IsolatedMainManager.instance
      .messageFromFrontendToIsolated(
          message: message.copyWith(
              from: message.from,
              to: message.to,
              type: message.type,
              data: data
                ..addAll({
                  'broadcaster_id': broadcasterId,
                  'user_id': userId,
                  'opaque_id': opaqueUserId
                })));

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

Map<String, dynamic>? _extractJwtPayload(HttpRequest request,
    {required TwitchEbsInfo ebsInfo}) {
  // Extract the Authorization header
  final authHeader = request.headers['Authorization']?.first;
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    throw UnauthorizedException();
  }
// Extract the Bearer token by removing 'Bearer ' from the start
  final bearer = authHeader.substring(7);
  // If the token is invalid, an exception is thrown
  final decodedJwt = JWT.verify(
      bearer, SecretKey(ebsInfo.sharedSecret!, isBase64Encoded: true));

  return decodedJwt.payload;
}
