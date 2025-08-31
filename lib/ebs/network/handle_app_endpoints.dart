part of 'package:twitch_manager/ebs/network/ebs_server.dart';

Future<void> _handleAppGetRequest(
  HttpRequest request, {
  required TwitchEbsInfo ebsInfo,
}) async {
  if (request.uri.path.contains('/connect')) {
    await _handleAppConnectToWebSocketRequest(request, ebsInfo: ebsInfo);
  } else if (request.uri.path.contains('/token')) {
    await _handleAppTokenRequest(request, ebsInfo: ebsInfo);
  } else {
    throw InvalidEndpointException();
  }
}

Future<void> _handleAppConnectToWebSocketRequest(HttpRequest request,
    {required TwitchEbsInfo ebsInfo}) async {
  try {
    final socket = await WebSocketTransformer.upgrade(request);

    final broadcasterId =
        int.tryParse(request.uri.queryParameters['broadcaster_id'] ?? '');
    if (broadcasterId == null) {
      _logger.severe('No broadcasterId found');
      socket.add(MessageProtocol(
              to: MessageTo.app,
              from: MessageFrom.generic,
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

Future<void> _handleAppTokenRequest(
  HttpRequest request, {
  required TwitchEbsInfo ebsInfo,
}) async {
  try {
    final parameters = request.uri.queryParameters;
    final clientId = parameters['client_id'];
    if (clientId != ebsInfo.twitchClientId) {
      _logger.severe('Invalid clientId: $clientId');
      throw UnauthorizedException();
    }

    if (parameters['request_type'] == 'reload_token') {
      final jwt =
          request.uri.queryParameters['previous_access_token'] as String;
      final verifiedJwt = JWT.verify(jwt, SecretKey(ebsInfo.privateKey));

      final userId = verifiedJwt.payload['user_id'];
      if (userId == null) {
        _logger.severe('No userId found in JWT');
        throw UnauthorizedException();
      }

      final accessTokenClientId = verifiedJwt.payload['client_id'];
      if (clientId == null || clientId != accessTokenClientId) {
        _logger.severe('No clientId found in JWT');
        throw UnauthorizedException();
      }

      final credentials =
          await ebsInfo.credentialsStorage.load(userId: userId!);
      if (credentials == null) {
        _logger.severe('No credentials found for userId: $userId');
        throw UnauthorizedException();
      }

      final responseIsValid = await http
          .get(Uri.https('id.twitch.tv', '/oauth2/validate'), headers: {
        'Authorization': 'Bearer ${credentials.accessToken}',
      });
      if (responseIsValid.statusCode != 200) {
        _logger.info('Access token is no longer valid, need to refresh');
        final responseNewToken =
            await http.post(Uri.https('id.twitch.tv', '/oauth2/token', {
          'client_id': clientId,
          'client_secret': ebsInfo.extensionApiClientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': credentials.refreshToken,
        }));
        if (responseNewToken.statusCode == 200) {
          await _finalizeNewTokenResponse(
              request: request, response: responseNewToken, ebsInfo: ebsInfo);
          return;
        }
      }

      // Respond by sending back the jwt if it was valid, or the renewed one otherwise
      request.response.statusCode = HttpStatus.ok;
      request.response.write(jsonEncode({
        'access_token': jwt.toString(),
        'state': parameters['state'],
      }));
      await request.response.close();
      return;
    } else if (parameters['request_type'] == 'new_token') {
      // Extract the userId from the JWT
      final clientId = parameters['client_id'];
      if (clientId == null) {
        _logger.severe('No clientId found in JWT');
        throw UnauthorizedException();
      }

      final response =
          await http.post(Uri.https('id.twitch.tv', '/oauth2/token', {
        'client_id': clientId,
        'client_secret': ebsInfo.extensionApiClientSecret,
        'code': parameters['code'],
        'grant_type': 'authorization_code',
        'redirect_uri': parameters['redirect_uri'],
      }));
      if (response.statusCode != 200) {
        _logger
            .severe('Failed to get access token from Twitch: ${response.body}');
        throw UnauthorizedException();
      }

      await _finalizeNewTokenResponse(
          request: request, response: response, ebsInfo: ebsInfo);

      return;
    } else {
      _logger.severe('Invalid request_type');
      throw UnauthorizedException();
    }
  } catch (e) {
    throw UnauthorizedException();
  }
}

Future<void> _finalizeNewTokenResponse(
    {required HttpRequest request,
    required http.Response response,
    required TwitchEbsInfo ebsInfo}) async {
  final parameters = request.uri.queryParameters;
  final clientId = parameters['client_id']!;

  final body = jsonDecode(response.body);
  final accessToken = body['access_token'];
  final refreshToken = body['refresh_token'];

  // Get the user id
  final userResponse = await http.get(
      Uri.https('api.twitch.tv', '/helix/users', {'access_token': accessToken}),
      headers: {
        'Client-ID': clientId,
        'Authorization': 'Bearer $accessToken',
      });
  if (userResponse.statusCode != 200) {
    _logger.severe('Failed to get user info from Twitch: ${userResponse.body}');
    throw UnauthorizedException();
  }

  final userBody = jsonDecode(userResponse.body);
  final userId = userBody['data'][0]['id'];
  if (userId == null) {
    _logger.severe('No userId found in Twitch response');
    throw UnauthorizedException();
  }

  await ebsInfo.credentialsStorage.save(
      credentials: TwitchEbsCredentials(
    userId: userId,
    accessToken: accessToken,
    refreshToken: refreshToken,
  ));

  // Sign the new JWT
  final jwt = JWT(
      {'user_id': userId, 'client_id': clientId, 'access_token': accessToken});
  final token = jwt.sign(SecretKey(ebsInfo.privateKey));

  // Return the signed token
  request.response.statusCode = HttpStatus.ok;
  request.response.write(jsonEncode({
    'access_token': token,
    'state': parameters['state'],
  }));
  await request.response.close();
}
