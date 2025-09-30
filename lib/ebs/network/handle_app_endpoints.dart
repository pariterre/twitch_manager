part of 'package:twitch_manager/ebs/network/ebs_server.dart';

Future<void> _handleAppGetRequest(
  HttpRequest request, {
  required TwitchEbsInfo ebsInfo,
  required TwitchEbsCredentialsStorage credentialsStorage,
}) async {
  if (request.uri.path.contains('/connect')) {
    await _handleAppConnectToWebSocketRequest(request, ebsInfo: ebsInfo);
  } else if (request.uri.path.contains('/token')) {
    await _handleAppTokenRequest(request,
        ebsInfo: ebsInfo, credentialsStorage: credentialsStorage);
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

///
/// Handles the app request to validate an app token.
/// Please note there exists two tokens here. The app token which is used to encapsulate
/// the twitch token. And the twitch token which is used to authenticate the user
Future<void> _handleAppTokenRequest(
  HttpRequest request, {
  required TwitchEbsInfo ebsInfo,
  required TwitchEbsCredentialsStorage credentialsStorage,
}) async {
  try {
    // Get aliases from the request
    final parameters = request.uri.queryParameters;

    // Validate the client_id sent by the user
    final clientId = parameters['client_id'];
    if (clientId != ebsInfo.twitchClientId) {
      _logger.severe('Invalid clientId: $clientId');
      throw UnauthorizedException();
    }

    // If the request is to reload the token
    if (parameters['request_type'] == 'reload_app_token') {
      await _handleReloadAppTokenRequest(
          request: request,
          ebsInfo: ebsInfo,
          credentialsStorage: credentialsStorage);
    } else if (parameters['request_type'] == 'new_app_token') {
      await _handleNewAppTokenRequest(
          request: request,
          ebsInfo: ebsInfo,
          credentialsStorage: credentialsStorage);
    } else {
      _logger.severe('Invalid request_type');
      throw UnauthorizedException();
    }
  } catch (e) {
    throw UnauthorizedException();
  }
}

Future<void> _handleNewAppTokenRequest(
    {required HttpRequest request,
    required TwitchEbsInfo ebsInfo,
    required TwitchEbsCredentialsStorage credentialsStorage}) async {
  // Get aliases from the request
  final parameters = request.uri.queryParameters;

  // Make sure we have a code and a redirect_uri
  if (parameters['code'] == null || parameters['redirect_uri'] == null) {
    _logger.severe('No code or redirect_uri found in request');
    throw UnauthorizedException();
  }

  // Extract the userId from the JWT
  final clientId = parameters['client_id'];
  if (clientId == null) {
    _logger.severe('No clientId found in JWT');
    throw UnauthorizedException();
  }

  final responseTwitchToken =
      await timedHttpPost(Uri.https('id.twitch.tv', '/oauth2/token', {
    'client_id': clientId,
    'client_secret': ebsInfo.extensionApiClientSecret,
    'code': parameters['code'],
    'grant_type': 'authorization_code',
    'redirect_uri': parameters['redirect_uri'],
  }));
  if (responseTwitchToken.statusCode != 200) {
    _logger.severe(
        'Failed to get access Twitch token: ${responseTwitchToken.body}');
    throw UnauthorizedException();
  }

  await _finalizeNewTwitchToken(
      twitchRequest: request,
      response: responseTwitchToken,
      ebsInfo: ebsInfo,
      credentialsStorage: credentialsStorage);
}

Future<void> _handleReloadAppTokenRequest({
  required HttpRequest request,
  required TwitchEbsInfo ebsInfo,
  required TwitchEbsCredentialsStorage credentialsStorage,
}) async {
  // Get aliases from the request
  final parameters = request.uri.queryParameters;
  final clientId = parameters['client_id'];

  // Fetch the previous access app token to validate and renew
  final jwt = request.uri.queryParameters['previous_app_token'] as String;

  // Make sure it was issued by us and is still valid
  final appToken = JWT.verify(jwt, SecretKey(ebsInfo.privateKey));
  final userId = appToken.payload['user_id'];
  if (userId == null) {
    _logger.severe('No userId found in JWT');
    throw UnauthorizedException();
  }
  final appTokenClientId = appToken.payload['client_id'];
  if (clientId == null || clientId != appTokenClientId) {
    _logger.severe('No clientId found in JWT');
    throw UnauthorizedException();
  }

  // Load the credentials associated with this jwt
  final credentials = await credentialsStorage.load(userId: userId!);
  if (credentials == null) {
    _logger.severe('No credentials found for userId: $userId');
    throw UnauthorizedException();
  }

  // Validate the access twitch token is still valid with Twitch
  final responseIsValid = await timedHttpGet(
    Uri.https('id.twitch.tv', '/oauth2/validate'),
    headers: {'Authorization': 'Bearer ${credentials.accessToken}'},
  );
  if (responseIsValid.statusCode != 200) {
    _handleRefreshTwitchToken(
        request: request,
        ebsInfo: ebsInfo,
        clientId: clientId,
        credentials: credentials,
        credentialsStorage: credentialsStorage);
    return;
  }

  // Create a jwt to send to the client
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.add('Access-Control-Allow-Origin', '*');
  request.response.write(jsonEncode({
    'app_token': jwt.toString(),
    'state': parameters['state'],
  }));
  await request.response.close();
}

Future<void> _handleRefreshTwitchToken({
  required HttpRequest request,
  required TwitchEbsInfo ebsInfo,
  required String clientId,
  required TwitchEbsCredentials credentials,
  required TwitchEbsCredentialsStorage credentialsStorage,
}) async {
  _logger.info('Twitch token is no longer valid, need to refresh');
  final responseNewTwitchToken =
      await timedHttpPost(Uri.https('id.twitch.tv', '/oauth2/token', {
    'client_id': clientId,
    'client_secret': ebsInfo.extensionApiClientSecret,
    'grant_type': 'refresh_token',
    'refresh_token': credentials.refreshToken,
  }));
  if (responseNewTwitchToken.statusCode != 200) {
    _logger.severe(
        'Failed to refresh access token from Twitch: ${responseNewTwitchToken.body}');
    throw UnauthorizedException();
  }
  await _finalizeNewTwitchToken(
      twitchRequest: request,
      response: responseNewTwitchToken,
      ebsInfo: ebsInfo,
      credentialsStorage: credentialsStorage);
}

Future<void> _finalizeNewTwitchToken({
  required HttpRequest twitchRequest,
  required http.Response response,
  required TwitchEbsInfo ebsInfo,
  required TwitchEbsCredentialsStorage credentialsStorage,
}) async {
  // Get some aliases
  final parameters = twitchRequest.uri.queryParameters;
  final clientId = parameters['client_id']!;

  final body = jsonDecode(response.body);
  final twitchToken = body['access_token'];
  final refreshToken = body['refresh_token'];

  // Get the user id
  final userResponse = await timedHttpGet(
    Uri.https('api.twitch.tv', '/helix/users', {'access_token': twitchToken}),
    headers: {'Client-ID': clientId, 'Authorization': 'Bearer $twitchToken'},
  );
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

  // Save the new credentials to the storage
  await credentialsStorage.save(
      credentials: TwitchEbsCredentials(
    userId: userId,
    accessToken: twitchToken,
    refreshToken: refreshToken,
  ));

  // Sign the new JWT for 30 days
  final jwt = JWT({
    'user_id': userId,
    'client_id': clientId,
    'twitch_access_token': twitchToken
  });
  final token = jwt.sign(SecretKey(ebsInfo.privateKey),
      expiresIn: const Duration(days: 30));

  // Return the signed token
  twitchRequest.response
    ..statusCode = HttpStatus.ok
    ..headers.add('Access-Control-Allow-Origin', '*');
  twitchRequest.response.write(jsonEncode({
    'app_token': token,
    'state': parameters['state'],
  }));
  await twitchRequest.response.close();
}
