import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:twitch_manager/abstract/twitch_authenticator.dart';
import 'package:twitch_manager/app/twitch_app_info.dart';
import 'package:twitch_manager/app/twitch_events.dart';
import 'package:twitch_manager/app/twitch_mock_options.dart';
import 'package:twitch_manager/utils/twitch_authentication_flow.dart';
import 'package:twitch_manager/utils/twitch_listener.dart';

const _twitchValidateUri = 'https://id.twitch.tv/oauth2/validate';
const _twitchHelixUri = 'https://api.twitch.tv/helix';

final _logger = Logger('TwitchAppApi');

List<String> _removeBlacklisted(
    Iterable<String> names, List<String>? blacklist) {
  return names
      .where((e) => blacklist == null || !blacklist.contains(e))
      .toList();
}

///
/// Generate a safe state for the OAuth request. This is to prevent CSRF attacks.
/// The state is a string of 25 digits. The 4th character is 6 and the 12th
/// character is 2. The sum of all the digits is calculated and the last digit
/// is adjusted to make the sum 9.
String _generateSafeState() {
  // Initialize random number generator
  final random = Random();

  // Generate a list of random digits
  List<int> digits = List.generate(25, (_) => random.nextInt(10));

  // Set the required digits
  digits[3] = 6; // 4th character (index 3)
  digits[11] = 2; // 12th character (index 11)
  digits[24] = 0; // Last character (index 24)

  // Calculate the sum of the digits
  int sum = digits.reduce((a, b) => a + b);

  // Adjust the last digit to make the checksum 9
  digits[24] = (9 - sum % 10) % 10;

  // Convert the list of digits to a string
  return digits.join();
}

///
/// Class that holds a response from Twitch API, this is to easy the communication
/// between internal parts of the API
class _TwitchResponse {
  List<dynamic> data;
  String? cursor;
  _TwitchResponse({required this.data, required this.cursor});
}

enum HttpRequestMethod { get, post, patch, delete }

class TwitchAppApi {
  ///
  /// The constructor for the Twitch API
  /// [appInfo] holds all the information required to run the API
  /// [authenticator] holds the OAuth key to communicate with the API
  static Future<TwitchAppApi> factory({
    required TwitchAppInfo appInfo,
    required TwitchAuthenticator authenticator,
  }) async {
    _logger.config('Creating Twitch API...');

    // Create a temporary TwitchApi with [streamerId] empty so we
    // can fetch it
    final api = TwitchAppApi._(appInfo, authenticator);
    api.streamerId = await api._userId(authenticator.bearerKey!);

    _logger.config('Twitch API created');
    return api;
  }

  ////// CONNEXION RELATED API //////

  ///
  /// Validates the current OAUTH key. This is mandatory as stated here:
  /// https://dev.twitch.tv/docs/authentication/validate-tokens/
  /// This only make sense for App (as opposed to extensions)
  static Future<bool> validateOAuthToken({required AppToken token}) async {
    _logger.info('Validating OAUTH token...');

    final response = await http.get(
      Uri.parse(_twitchValidateUri),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer ${token.accessToken}',
      },
    );

    final isValid = _checkIfResponseIsValid(response);
    _logger.info('OAUTH token is ${isValid ? 'valid' : 'invalid'}');
    return isValid;
  }

  ///
  /// Get a new OAUTH for the user
  /// [appInfo] holds all the necessary information to connect.
  /// [onRequestBrowsing] is the callback to show which address the user must
  /// browse.
  static Future<AppToken?> getAppToken({
    required TwitchAppInfo appInfo,
    Future<void> Function(String)? onRequestBrowsing,
    required AppToken? previousAppToken,
  }) async {
    switch (appInfo.authenticationFlow) {
      case TwitchAuthenticationFlow.implicit:
        return await _getAppTokenImplicitFlow(
          appInfo: appInfo,
          onRequestBrowsing: onRequestBrowsing,
          previousAppToken: previousAppToken,
        );
      case TwitchAuthenticationFlow.authorizationCode:
        return await _getAppTokenAuthorizationCodeFlow(
          appInfo: appInfo,
          onRequestBrowsing: onRequestBrowsing,
          previousAppToken: previousAppToken,
        );
      case TwitchAuthenticationFlow.notApplicable:
        throw 'A method of authentication must be chosen to get a new OAuth token';
    }
  }

  ///
  /// Get a new OAUTH for the user using the implicit flow.
  /// [appInfo] holds all the necessary information to connect.
  /// [onRequestBrowsing] is the callback to show which address the user must
  /// browse. If none is provided, only the validation step is performed.
  static Future<AppToken?> _getAppTokenImplicitFlow({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String)? onRequestBrowsing,
    required AppToken? previousAppToken,
  }) async {
    // Try to validate a previous JWT
    if (previousAppToken != null &&
        await validateOAuthToken(token: previousAppToken)) {
      _logger.info('Previous JWT is still valid');
      return previousAppToken;
    }
    if (onRequestBrowsing == null) return null;

    // Generate a state so both Twitch and the Server knows the request is valid
    // and made by me
    _logger.info('Getting new OAUTH using implicit flow...');
    final state = _generateSafeState();

    // Prepare the address the user should browse to.
    String browsingUri = Uri.https('id.twitch.tv', '/oauth2/authorize', {
      'response_type': 'token',
      'client_id': appInfo.twitchClientId,
      'redirect_uri': appInfo.twitchRedirectUri.toString(),
      'state': state,
    }).toString();
    // We have to add scope by hand, otherwise the '+' is encoded
    browsingUri +=
        '&scope=${appInfo.scope.map<String>((e) => e.toString()).join('+')}';

    onRequestBrowsing(browsingUri);

    // While they are browsing, we are waiting for the answer that will be sent
    // to the server, by doing an HTTP get request with the state as query
    Map<String, dynamic> body;
    try {
      final response = await http
          .get(Uri.parse('${appInfo.authenticationServerUri}?state=$state'));
      if (response.statusCode != 200) {
        return null;
      }
      body = json.decode(response.body);
    } on Exception {
      return null;
    }

    // Parse the response to get the state and the OAuth key
    final responseState = body['state'];
    if (responseState != state) {
      return null;
    }
    final oAuthKey = body['access_token'];
    if (oAuthKey == null) {
      return null;
    }

    _logger.info('OAUTH received');
    // Convert the OAuth key to a JWT
    return AppToken.fromJwt(jwt: JWT({'twitch_access_token': oAuthKey}));
  }

  ///
  /// Get a new OAUTH for the user using the authorization code flow.
  /// [appInfo] holds all the necessary information to connect.
  /// [onRequestBrowsing] is the callback to show which address the user must
  /// browse. If none is provided, only the validation step is performed.
  static Future<AppToken?> _getAppTokenAuthorizationCodeFlow({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String)? onRequestBrowsing,
    required AppToken? previousAppToken,
  }) async {
    // Generate a state so both Twitch and the Server knows the request is valid
    // and made by me
    _logger.info('Getting new OAUTH using authorization code flow...');

    if (appInfo.ebsUri == null) {
      throw 'Authorization code flow necessitates an EBS URI. Please set it in the TwitchAppInfo.';
    }

    final state = _generateSafeState();

    // Call the EBS to get the a OAuth token for the current session
    var uriBackend = appInfo.ebsUri!.replace(
        scheme: appInfo.ebsUri!.scheme == 'wss' ? 'https' : 'http',
        path: '/app/token',
        queryParameters: {
          'request_type': 'reload_app_token',
          'previous_app_token': previousAppToken?.serialize(),
          'client_id': appInfo.twitchClientId,
          'state': state,
          'redirect_uri': appInfo.twitchRedirectUri.toString(),
        });
    try {
      _logger.info('Try to fetch a previous access token...');
      var response = await http.get(uriBackend);
      if (response.statusCode == 200) {
        final decodedBody = json.decode(response.body);
        final token = decodedBody['app_token'];
        if (token != null && state == decodedBody['state']) {
          _logger.info('Received a token from EBS');
          final appToken = AppToken.fromSerialized(token);
          if (await validateOAuthToken(token: appToken)) {
            // If it is not valid, simply continue the normal flow
            return appToken;
          }
        }
      }
    } catch (e) {
      // Continue normal execution (i.e. get a new access token)
    }

    if (onRequestBrowsing == null) {
      _logger.warning('No browsing request provided, cannot proceed');
      return null;
    }

    // Prepare the address the user should browse to.
    String browsingUri = Uri.https('id.twitch.tv', '/oauth2/authorize', {
      'client_id': appInfo.twitchClientId,
      'redirect_uri': appInfo.twitchRedirectUri.toString(),
      'response_type': 'code',
      'state': state
    }).toString();
    // We have to add scope by hand, otherwise the '+' is encoded
    browsingUri +=
        '&scope=${appInfo.scope.map<String>((e) => e.toString()).join('+')}';

    onRequestBrowsing(browsingUri);

    // While they are browsing, we are waiting for the answer that will be sent
    // to the server, by doing an HTTP get request with the state as query
    Map<String, dynamic> body;
    try {
      final response = await http
          .get(Uri.parse('${appInfo.authenticationServerUri}?state=$state'));
      if (response.statusCode != 200) {
        return null;
      }
      body = json.decode(response.body);
    } on Exception {
      return null;
    }

    // Parse the response to get the state and the OAuth key
    final responseState = body['state'];
    if (responseState != state) {
      return null;
    }
    final code = body['code'];
    if (code == null) {
      return null;
    }

    // Call the EBS to get the a OAuth token for the current session
    _logger.info('Exchanging code for access token...');
    try {
      final response = await http.get(uriBackend.replace(queryParameters: {
        'request_type': 'new_app_token',
        'client_id': appInfo.twitchClientId,
        'state': state,
        'code': code,
        'redirect_uri': appInfo.twitchRedirectUri.toString(),
      }));

      if (response.statusCode != 200) {
        _logger.warning('Error while exchanging code for access token');
        return null;
      }
      final token = json.decode(response.body)['app_token'];
      if (token == null || state != (body['state'])) {
        _logger.warning('Error while exchanging code for access token');
        return null;
      }
      _logger.info('OAUTH received');

      final appToken = AppToken.fromSerialized(token);
      if (!await validateOAuthToken(token: appToken)) {
        throw 'Received token is not valid';
      }
      return appToken;
    } catch (e) {
      _logger.warning('Error while exchanging code for access token');
      return null;
    }
  }

  ///
  /// Get the stream login of the user [userId].
  Future<String?> login(int userId) async {
    _logger.info('Get the login for user $userId...');

    final response = await _sendHttpRequest(HttpRequestMethod.get,
        suffix: 'users', parameters: {'id': userId.toString()});
    if (response == null) {
      _logger.warning('Error while getting login for user $userId');
      return null;
    }

    final login = response.data[0]['login'];
    _logger.info('Login for user $userId is $login');
    return login;
  }

  ///
  /// Get the display name of the user [userId].
  Future<String?> displayName(int userId) async {
    _logger.info('Getting display name for user $userId...');

    final response = await _sendHttpRequest(HttpRequestMethod.get,
        suffix: 'users', parameters: {'id': userId.toString()});
    if (response == null) {
      _logger.warning('Error while getting display name for user $userId');
      return null;
    }

    final displayName = response.data[0]['display_name'];
    _logger.info('Display name for user $userId is $displayName');
    return displayName;
  }

  ///
  /// Check if the user of [userId] is currently live. Note the method used here
  /// is kind of a hack as data is expected to be empty when the user is not
  /// live (even though, for some reason the key "type" is "live" when the user
  /// is actually live).
  Future<bool?> isUserLive(int userId) async {
    _logger.info('Checking if user $userId is live...');

    final response = await _sendHttpRequest(HttpRequestMethod.get,
        suffix: 'streams', parameters: {'user_id': userId.toString()});
    if (response == null) {
      _logger.warning('Error while checking if user $userId is live');
      return null;
    }

    // Extract the islive information
    final isLive =
        response.data.isNotEmpty && response.data[0]['type'] == 'live';
    _logger.info('User $userId is ${isLive ? 'live' : 'not live'}');
    return isLive;
  }

  ////// CHAT RELATED API //////

  ///
  /// Get the list of current chatters.
  /// The [blacklist] ignore some chatters (ignoring bots for instance).
  Future<List<String>?> fetchChatters({List<String>? blacklist}) async {
    _logger.info('Fetching current chatters...');

    final response = await _sendHttpRequest(HttpRequestMethod.get,
        suffix: 'chat/chatters',
        parameters: {
          'broadcaster_id': streamerId.toString(),
          'moderator_id': streamerId.toString()
        });
    if (response == null) {
      _logger.warning('Error while fetching current chatters');
      return null;
    }

    // Extract the usernames and removed the blacklisted
    final chatters = _removeBlacklisted(
        response.data.map<String>((e) => e['user_name']), blacklist);
    _logger.info('Retrieved ${chatters.length} chatters');
    return chatters;
  }

  ////// CHANNEL RELATED API //////

  ///
  /// Get the list of moderators of the channel.
  /// The streamer is not included in the list of moderators. If one need them
  /// to be included, they can set [includeStreamer] to true. Alternatively,
  /// they can call `login(streamerId)`.
  Future<List<String>?> fetchModerators({bool includeStreamer = false}) async {
    _logger.info('Fetching moderators...');

    final List<String> moderators = [];
    String? cursor;
    do {
      final parameters = {
        'broadcaster_id': streamerId.toString(),
        'first': '100',
      };
      if (cursor != null) parameters['after'] = cursor;

      final response = await _sendHttpRequest(HttpRequestMethod.get,
          suffix: 'moderation/moderators', parameters: parameters);
      if (response == null) {
        _logger.warning('Error while fetching moderators');
        return null;
      }

      // Copy answer to the output variable
      moderators
          .addAll(response.data.map<String>((e) => e['user_login']).toList());

      if (response.cursor == null) break; // We are done
      cursor = response.cursor;
    } while (true);

    if (includeStreamer) moderators.add((await login(streamerId))!);

    _logger.info('Retrieved ${moderators.length} moderators');
    return moderators;
  }

  ///
  /// Get the list of current followers of the channel.
  /// [includeStreamer] If the streamer should be counted as follower too
  /// The [blacklist] ignore some followers (ignoring bots for instance).
  Future<List<String>?> fetchFollowers(
      {bool includeStreamer = false, List<String>? blacklist}) async {
    _logger.info('Fetching followers...');

    final List<String> users = [];
    String? cursor;
    do {
      final parameters = {
        'broadcaster_id': streamerId.toString(),
        'first': '100',
      };
      if (cursor != null) parameters['after'] = cursor;

      final response = await _sendHttpRequest(HttpRequestMethod.get,
          suffix: 'channels/followers', parameters: parameters);
      if (response == null) {
        _logger.warning('Error while fetching followers');
        return null;
      }

      // Copy answer to the output variable
      users.addAll(response.data.map<String>((e) => e['user_name']).toList());

      if (response.cursor == null) break; // We are done
      cursor = response.cursor;
    } while (true);

    if (includeStreamer) users.add((await displayName(streamerId))!);

    _logger.info('Retrieved ${users.length} followers');
    return _removeBlacklisted(users, blacklist);
  }

  ////// REWARD REDEMPTION RELATED API //////

  ///
  /// Create a new reward redemption for the streamer. The [reward] should
  /// contain the title of the reward and the cost in channel points.
  /// Returns the id of the reward redemption.
  Future<String?> createRewardRedemption(
      {required TwitchRewardRedemption reward}) async {
    _logger.info('Creating reward redemption...');

    final response = await _sendHttpRequest(HttpRequestMethod.post,
        suffix: 'channel_points/custom_rewards',
        parameters: {
          'broadcaster_id': streamerId.toString()
        },
        body: {
          'title': reward.rewardRedemption,
          'cost': reward.cost.toString(),
        });
    if (response == null) {
      _logger.warning('Error while creating reward redemption');
      return null;
    }

    final awardId = response.data[0]['id'];
    _logger.info('Reward redemption created with id $awardId');
    return awardId;
  }

  ///
  /// Updates the reward redemption [reward] with the new information.
  /// The [reward] should contain the [rewardRedemptionId],
  /// the new title and cost.
  /// Returns true if the update was successful.
  Future<bool> updateRewardRedemption(
      {required TwitchRewardRedemption reward}) async {
    _logger.info('Updating reward redemption...');

    final response = await _sendHttpRequest(HttpRequestMethod.patch,
        suffix: 'channel_points/custom_rewards',
        parameters: {
          'id': reward.rewardRedemptionId,
          'broadcaster_id': streamerId.toString(),
        },
        body: {
          'title': reward.rewardRedemption,
          'cost': reward.cost.toString(),
        });

    final isSuccessful = response != null;
    _logger
        .info('Reward redemption ${isSuccessful ? 'updated' : 'not updated'}');
    return isSuccessful;
  }

  ///
  /// Delete the reward redemption [reward].
  /// The [reward] should contain the [rewardRedemptionId],
  /// Returns true if the update was successful.
  Future<bool> deleteRewardRedemption(
      {required TwitchRewardRedemption reward}) async {
    _logger.info('Deleting reward redemption...');

    final response = await _sendHttpRequest(HttpRequestMethod.delete,
        suffix: 'channel_points/custom_rewards',
        parameters: {
          'id': reward.rewardRedemptionId,
          'broadcaster_id': streamerId.toString(),
        });

    final isSuccessful = response != null;
    _logger
        .info('Reward redemption ${isSuccessful ? 'deleted' : 'not deleted'}');
    return isSuccessful;
  }

  ///
  /// Fulfills or cancels the reward redemption [reward] with the new status.
  /// The [reward] should contain the [rewardRedemptionId].
  /// The [status] should be either FULFILLED or CANCELED.
  /// Returns true if the update was successful.
  Future<bool> updateRewardRedemptionStatus({
    required TwitchRewardRedemption reward,
    required TwitchRewardRedemptionStatus status,
  }) async {
    _logger.info('Updating reward redemption status...');

    final response = await _sendHttpRequest(HttpRequestMethod.patch,
        suffix: 'channel_points/custom_rewards/redemptions',
        parameters: {
          'id': reward.eventId,
          'broadcaster_id': streamerId.toString(),
          'reward_id': reward.rewardRedemptionId,
        },
        body: {
          'status': status.toString()
        });

    final isSuccessful = response != null;
    _logger.info(
        'Reward redemption status ${isSuccessful ? 'updated' : 'not updated'}');
    return isSuccessful;
  }

  ////// INTERNAL //////

  ///
  /// ATTRIBUTES
  final TwitchAppInfo _appInfo;
  late final int streamerId; // It is set in the factory
  final TwitchAuthenticator _authenticator;

  ///
  /// Private constructor
  TwitchAppApi._(this._appInfo, this._authenticator);

  ///
  /// Send an actual HTTP request to Twitch
  Future<_TwitchResponse?> _sendHttpRequest(HttpRequestMethod method,
      {required String suffix,
      Map<String, String?>? parameters,
      Map<String, String>? body}) async {
    // Stop now if we are disconnected
    if (_authenticator.bearerKey == null) {
      _logger
          .warning('Could not send request as the streamer is not connected');
      return null;
    }

    var params = '';

    if (parameters != null) {
      parameters.forEach(
          (key, value) => params += '$key${value == null ? '' : '=$value'}&');
      params = params.substring(0, params.length - 1); // Remove to final '&'
    }

    http.Response response;
    switch (method) {
      case HttpRequestMethod.get:
        // Get request
        response = await http.get(
            Uri.parse(
                '$_twitchHelixUri/$suffix${params.isEmpty ? '' : '?$params'}'),
            headers: <String, String>{
              HttpHeaders.authorizationHeader:
                  'Bearer ${_authenticator.bearerKey!.accessToken}',
              'Client-Id': _appInfo.twitchClientId,
              HttpHeaders.contentTypeHeader: 'application/json',
            });
        break;
      case HttpRequestMethod.post:
        // Post request
        response = await http.post(
            Uri.parse(
                '$_twitchHelixUri/$suffix${params.isEmpty ? '' : '?$params'}'),
            headers: <String, String>{
              HttpHeaders.authorizationHeader:
                  'Bearer ${_authenticator.bearerKey!.accessToken}',
              'Client-Id': _appInfo.twitchClientId,
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(body));
        break;
      case HttpRequestMethod.patch:
        // Patch request
        response = await http.patch(
            Uri.parse(
                '$_twitchHelixUri/$suffix${params.isEmpty ? '' : '?$params'}'),
            headers: <String, String>{
              HttpHeaders.authorizationHeader:
                  'Bearer ${_authenticator.bearerKey!.accessToken}',
              'Client-Id': _appInfo.twitchClientId,
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(body));
        break;
      case HttpRequestMethod.delete:
        // Delete request
        response = await http.delete(
            Uri.parse(
                '$_twitchHelixUri/$suffix${params.isEmpty ? '' : '?$params'}'),
            headers: <String, String>{
              HttpHeaders.authorizationHeader:
                  'Bearer ${_authenticator.bearerKey!.accessToken}',
              'Client-Id': _appInfo.twitchClientId,
            });
        if (response.body.contains('error')) return null;
        return _TwitchResponse(data: [], cursor: null);
    }

    // Make sure the token is still valid before continuing
    if (!_checkIfResponseIsValid(response)) {
      _logger.warning('Request failed as the token is invalid');
      return null;
    }

    // Prepare the answer to be returned
    final responseDecoded = await jsonDecode(response.body) as Map;
    if (responseDecoded.containsKey('data')) {
      return _TwitchResponse(
          data: responseDecoded['data'],
          cursor: responseDecoded['pagination']?['cursor']);
    } else {
      dev.log(responseDecoded.toString());
      return null;
    }
  }

  ///
  /// Fetch the user id from its [accessToken]
  Future<int> _userId(AppToken accessToken) async {
    _logger.info('Fetching user id...');

    final response = await http.get(
      Uri.parse(_twitchValidateUri),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer ${accessToken.accessToken}',
      },
    );

    final userId = int.tryParse(jsonDecode(response.body)?['user_id']) ?? -1;
    _logger.info(
        userId == -1 ? 'Error while fetching user id' : 'User id is $userId');
    return userId;
  }

  ///
  /// This method can be call by any of the user of authentication to inform
  /// that the token is now invalid.
  /// Returns true if it is, otherwise it returns false.
  static bool _checkIfResponseIsValid(http.Response response) {
    _logger.info('Checking if token is valid...');

    final responseDecoded = jsonDecode(response.body) as Map;
    if (responseDecoded.keys.contains('status') &&
        responseDecoded['status'] == 401) {
      dev.log('ERROR: ${responseDecoded['message']}');
      _logger.warning('Token is invalid');
      return false;
    }

    _logger.info('Token is valid');
    return true;
  }
}

class TwitchApiMock extends TwitchAppApi {
  TwitchDebugPanelOptions debugPanelOptions;

  ///
  /// The constructor for the Twitch API
  /// [appInfo] holds all the information required to run the API
  /// [debugPanelOptions] are the options to use for the mock
  static Future<TwitchApiMock> factory({
    required TwitchAppInfo appInfo,
    required TwitchAuthenticator authenticator,
    required TwitchDebugPanelOptions debugPanelOptions,
  }) async {
    // Create a temporary TwitchApi with [streamerId] empty so we
    // can fetch it
    final api = TwitchApiMock._(appInfo, authenticator, debugPanelOptions);
    api.streamerId = 1234567890;
    return api;
  }

  ////// CONNEXION RELATED API //////

  @override
  Future<String?> login(int userId) async {
    return 'login_$userId';
  }

  @override
  Future<String?> displayName(int userId) async {
    return 'display_name_$userId';
  }

  @override
  Future<bool?> isUserLive(int userId) async {
    return true;
  }

  ////// CHAT RELATED API //////
  @override
  Future<List<String>?> fetchChatters({List<String>? blacklist}) async {
    final List<String> out =
        debugPanelOptions.chatters.map((e) => e.displayName).toList();
    return _removeBlacklisted(out, blacklist);
  }

  ////// CHANNEL RELATED API //////
  @override
  Future<List<String>?> fetchModerators({bool includeStreamer = false}) async {
    final List<String> out = debugPanelOptions.chatters
        .where((chatter) => chatter.isModerator)
        .map((e) => e.displayName)
        .toList();

    if (includeStreamer) out.add((await login(streamerId))!);

    return out;
  }

  @override
  Future<List<String>?> fetchFollowers(
      {bool includeStreamer = false, List<String>? blacklist}) async {
    final List<String> out = debugPanelOptions.chatters
        .where((e) => e.isFollower && (includeStreamer ? true : !e.isStreamer))
        .map((e) => e.displayName)
        .toList();
    return _removeBlacklisted(out, blacklist);
  }

  ////// REWARD REDEMPTION RELATED API //////
  final List<TwitchRewardRedemption> _rewardRedemptions = [];
  List<TwitchRewardRedemption> get rewardRedemptions => _rewardRedemptions;

  ///
  /// The listener for the reward redemptions. This is for debugging purposes
  /// only. This method is not part of the Twitch API.
  final onRewardRedemptionsChanged = TwitchListener<
      Function(
          {required TwitchRewardRedemption reward,
          required bool wasDeleted})>();

  @override
  Future<String?> createRewardRedemption(
      {required TwitchRewardRedemption reward}) async {
    if (reward.cost < 1) return null;
    if (reward.rewardRedemption.isEmpty) return null;
    if (_rewardRedemptions
        .any((e) => e.rewardRedemption == reward.rewardRedemption)) {
      return null;
    }

    final id = 'reward_id_${reward.hashCode}';
    _rewardRedemptions.add(reward.copyWith(rewardRedemptionId: id));

    onRewardRedemptionsChanged.notifyListeners(
        (listener) => listener(reward: reward, wasDeleted: false));
    return id;
  }

  @override
  Future<bool> updateRewardRedemption(
      {required TwitchRewardRedemption reward}) async {
    if (!_rewardRedemptions
        .any((e) => e.rewardRedemptionId == reward.rewardRedemptionId)) {
      return false;
    }
    if (reward.cost < 1) return false;
    if (reward.rewardRedemption.isEmpty) return false;
    if (_rewardRedemptions.any((e) =>
        e.rewardRedemptionId != reward.rewardRedemptionId &&
        e.rewardRedemption == reward.rewardRedemption)) {
      return false;
    }

    _rewardRedemptions
        .removeWhere((e) => e.rewardRedemptionId == reward.rewardRedemptionId);
    _rewardRedemptions
        .add(reward.copyWith(rewardRedemptionId: reward.rewardRedemptionId));

    onRewardRedemptionsChanged.notifyListeners(
        (listener) => listener(reward: reward, wasDeleted: false));
    return true;
  }

  @override
  Future<bool> deleteRewardRedemption(
      {required TwitchRewardRedemption reward}) async {
    if (!_rewardRedemptions
        .any((e) => e.rewardRedemptionId == reward.rewardRedemptionId)) {
      return false;
    }

    _rewardRedemptions
        .removeWhere((e) => e.rewardRedemptionId == reward.rewardRedemptionId);

    onRewardRedemptionsChanged.notifyListeners(
        (listener) => listener(reward: reward, wasDeleted: true));
    return true;
  }

  @override
  Future<bool> updateRewardRedemptionStatus({
    required TwitchRewardRedemption reward,
    required TwitchRewardRedemptionStatus status,
  }) async {
    if (!_rewardRedemptions
        .any((e) => e.rewardRedemptionId == reward.rewardRedemptionId)) {
      return false;
    }

    return true;
  }

  ////// INTERNAL //////

  ///
  /// Private constructor
  TwitchApiMock._(
      super.appInfo, super.twitchAuthenticator, this.debugPanelOptions)
      : super._();
}
