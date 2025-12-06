import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:twitch_manager/abstract/twitch_authenticator.dart';
import 'package:twitch_manager/app/twitch_app_info.dart';
import 'package:twitch_manager/app/twitch_events.dart';
import 'package:twitch_manager/app/twitch_mock_options.dart';
import 'package:twitch_manager/utils/http_extension.dart';
import 'package:twitch_manager/utils/twitch_authentication_flow.dart';
import 'package:twitch_manager/utils/twitch_listener.dart';
import 'package:twitch_manager/utils/twitch_mutex.dart';
import 'package:twitch_manager/utils/twitch_user.dart';

const _twitchValidateUri = 'https://id.twitch.tv/oauth2/validate';
const _twitchHelixUri = 'https://api.twitch.tv/helix';

final _logger = Logger('TwitchAppApi');

Iterable<TwitchUser> _removeBlacklisted(
    Iterable<TwitchUser> users, Iterable<String>? blacklist) {
  if (blacklist == null) return users;

  return users.where((e) =>
      !blacklist.contains(e.id) &&
      !blacklist.contains(e.login) &&
      !blacklist.contains(e.displayName));
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
  int? total;
  _TwitchResponse(
      {required this.data, required this.cursor, required this.total});
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
    _logger.config('Creating Twitch App API...');

    // Create a temporary TwitchAppApi with [streamerId] empty so we
    // can fetch it
    final api = TwitchAppApi._(appInfo, authenticator);
    api.streamerId = await api._userId(authenticator.bearerKey!);

    _logger.config('Twitch App API created');
    return api;
  }

  ////// CONNEXION RELATED API //////

  ///
  /// Validates the current OAUTH key. This is mandatory as stated here:
  /// https://dev.twitch.tv/docs/authentication/validate-tokens/
  /// This only make sense for App (as opposed to extensions)
  static Future<bool> validateOAuthToken({required AppToken token}) async {
    _logger.info('Validating OAUTH token...');

    final response = await timedHttpGet(
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
    _logger.info('Getting new OAUTH using implicit flow...');

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
      final response = await timedHttpGet(
          Uri.parse('${appInfo.authenticationServerUri}?state=$state'));
      if (response.statusCode != 200) throw 'Error while getting OAuth token';

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
      var response = await timedHttpGet(uriBackend);
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
      final response = await timedHttpGet(
          Uri.parse('${appInfo.authenticationServerUri}?state=$state'),
          duration: Duration(minutes: 1));
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
      final response = await timedHttpGet(uriBackend.replace(queryParameters: {
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
  /// Cache of users used by the user() method
  final _usersCache = <TwitchUser>[];
  final _usersCacheMutex = TwitchMutex();

  ///
  /// Get the user info, identified by either [userId] or [login].
  Future<TwitchUser?> user({String? userId, String? login}) async {
    if (userId == null && login == null) {
      throw 'Either userId or login must be provided';
    } else if (userId != null && login != null) {
      throw 'Only one of userId or login must be provided';
    }

    return await _usersCacheMutex.runGuarded(() async {
      final cachedUser = _usersCache.from(id: userId, login: login);
      if (cachedUser != null) {
        _logger.fine('User $cachedUser found in cache');
        return cachedUser;
      }

      final category = userId != null ? 'id' : 'login';
      final identifier = userId ?? login!;

      _logger.fine('Getting user info for user $identifier using $category...');

      final response = await _sendHttpRequest(HttpRequestMethod.get,
          suffix: 'users', parameters: {category: identifier});
      if (response == null) {
        _logger.warning('Error while getting user info for user $identifier');
        return null;
      }
      final data = response.data[0];

      try {
        final user = TwitchUser(
            id: data['id'],
            login: data['login'],
            displayName: data['display_name']);
        _usersCache.add(user);
        _logger.fine('Display name for user $identifier is $user');
        return user;
      } catch (e) {
        _logger
            .warning('Error while parsing user info for user $identifier: $e');
        return null;
      }
    });
  }

  ///
  /// Get the stream login of the user [userId].
  Future<String?> login(String userId) async {
    _logger.fine('Get the login for user $userId...');
    final fetchedUser = await user(userId: userId);
    return fetchedUser?.login;
  }

  ///
  /// Get the user id of the user [login].
  Future<String?> userId(String login) async {
    _logger.fine('Get the userId for login $login...');
    final fetchedUser = await user(login: login);
    return fetchedUser?.id;
  }

  ///
  /// Get the display name of the user [userId].
  Future<String?> displayName({String? userId, String? login}) async {
    _logger.fine('Get the display name for user ${userId ?? login}...');
    final fetchedUser = await user(userId: userId, login: login);
    return fetchedUser?.displayName;
  }

  ///
  /// Check if the user of [userId] is currently live. Note the method used here
  /// is kind of a hack as data is expected to be empty when the user is not
  /// live (even though, for some reason the key "type" is "live" when the user
  /// is actually live).
  Future<bool?> isUserLive(String userId) async {
    _logger.info('Checking if user $userId is live...');

    final response = await _sendHttpRequest(HttpRequestMethod.get,
        suffix: 'streams', parameters: {'user_id': userId});
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
  /// The [blacklist] ignore some chatters (ignoring bots for instance). The provided
  /// values can be login, id or display name.
  Future<Iterable<TwitchUser>?> fetchChatters(
      {Iterable<String>? blacklist}) async {
    _logger.info('Fetching current chatters...');

    final chatters = await _fetchAllUsersOf('chat/chatters',
        parameters: {'broadcaster_id': streamerId, 'moderator_id': streamerId});
    if (chatters == null) {
      _logger.warning('Error while fetching chatters');
      return null;
    }

    // Extract the usernames and removed the blacklisted
    _logger.info('Retrieved ${chatters.length} chatters');
    return _removeBlacklisted(chatters, blacklist);
  }

  ////// CHANNEL RELATED API //////

  ///
  /// Get the list of current moderators of the channel.
  /// The streamer is not included in the list of moderators. If one need them
  /// to be included, they can set [includeStreamer] to true. Alternatively,
  /// they can call `login(streamerId)`.
  /// The [blacklist] ignore moderators (ignoring bots for instance), this
  /// can be login, id or display name.
  Future<Iterable<TwitchUser>?> fetchModerators(
      {bool includeStreamer = false, Iterable<String>? blacklist}) async {
    _logger.info('Fetching moderators...');

    final moderators = (await _fetchAllUsersOf('moderation/moderators',
            parameters: {'broadcaster_id': streamerId}))
        ?.toList();
    if (moderators == null) {
      _logger.warning('Error while fetching moderators');
      return null;
    }

    if (includeStreamer) moderators.add((await user(userId: streamerId))!);

    _logger.info('Retrieved ${moderators.length} moderators');
    return _removeBlacklisted(moderators, blacklist);
  }

  ///
  /// Cache of followers used by the fetchFollowers() method
  final List<TwitchUser> _followersCache = [];
  final _followersCacheMutex = TwitchMutex();

  ///
  /// Get the list of current followers of the channel.
  /// [includeStreamer] If the streamer should be counted as follower too
  /// The [blacklist] ignore some followers (ignoring bots for instance), this
  /// can be login, id or display name.
  Future<Iterable<TwitchUser>?> fetchFollowers(
      {bool includeStreamer = false, Iterable<String>? blacklist}) async {
    return await _followersCacheMutex.runGuarded(() async {
      _logger.info('Fetching followers...');

      // Fetch the latest follower and compare them to the cache. If the total
      // (i.e. the followers count) is the same and the latest follower is in
      // the cache, then we know nothing changed
      final users = <TwitchUser>[];
      if (_followersCache.isNotEmpty) {
        final response = await _sendHttpRequest(HttpRequestMethod.get,
            suffix: 'channels/followers',
            parameters: {'broadcaster_id': streamerId, 'first': '1'});
        if (response?.data.isNotEmpty ?? false) {
          final userId = response!.data[0]['user_id'];
          if (_followersCache.length == response.total &&
              _followersCache.has(id: userId)) {
            _logger.info('No new followers since last fetch');
            users.addAll(_followersCache);
          }
        }
      }

      // If we did not use the cache, fetch all followers
      if (users.isEmpty) {
        final fetchedUsers = await _fetchAllUsersOf(
          'channels/followers',
          parameters: {'broadcaster_id': streamerId},
        );
        if (fetchedUsers == null) {
          _logger.warning('Error while fetching followers');
          return null;
        }
        users.addAll(fetchedUsers);
        _followersCache
          ..clear()
          ..addAll(users);
      }

      if (includeStreamer) users.add((await user(userId: streamerId))!);

      _logger.info('Retrieved ${users.length} followers');
      return _removeBlacklisted(users, blacklist);
    });
  }

  Future<Iterable<TwitchUser>?> _fetchAllUsersOf(String suffix,
      {Map<String, String>? parameters}) async {
    String? cursor;

    final currentParameters = {...?parameters};

    final users = <TwitchUser>[];
    currentParameters['first'] = '100';
    do {
      if (cursor != null) currentParameters['after'] = cursor;

      final response = await _sendHttpRequest(HttpRequestMethod.get,
          suffix: suffix, parameters: currentParameters);
      if (response == null) {
        _logger.warning('Error while fetching users for $suffix');
        return null;
      }

      users.addAll(response.data.map((e) => TwitchUser(
          id: e['user_id'],
          login: e['user_login'],
          displayName: e['user_name'])));

      if (response.cursor == null) break; // We are done
      cursor = response.cursor;
    } while (true);
    return users;
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
          'broadcaster_id': streamerId
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
          'broadcaster_id': streamerId
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
          'broadcaster_id': streamerId
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
          'broadcaster_id': streamerId,
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
  late final String streamerId; // It is set in the factory
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
        response = await timedHttpGet(
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
        response = await timedHttpPost(
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
        response = await timedHttpPatch(
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
        response = await timedHttpDelete(
            Uri.parse(
                '$_twitchHelixUri/$suffix${params.isEmpty ? '' : '?$params'}'),
            headers: <String, String>{
              HttpHeaders.authorizationHeader:
                  'Bearer ${_authenticator.bearerKey!.accessToken}',
              'Client-Id': _appInfo.twitchClientId,
            });
        if (response.body.contains('error')) return null;
        return _TwitchResponse(data: [], cursor: null, total: null);
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
          cursor: responseDecoded['pagination']?['cursor'],
          total: responseDecoded['total']);
    } else {
      _logger.severe(responseDecoded.toString());
      return null;
    }
  }

  ///
  /// Fetch the user id from its [accessToken]
  Future<String> _userId(AppToken accessToken) async {
    _logger.info('Fetching user id...');

    final response = await timedHttpGet(
      Uri.parse(_twitchValidateUri),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer ${accessToken.accessToken}',
      },
    );

    final userId = jsonDecode(response.body)?['user_id'] as String? ?? '';
    _logger.info(
        userId.isEmpty ? 'Error while fetching user id' : 'User id is $userId');
    return userId;
  }

  ///
  /// This method can be call by any of the user of authentication to inform
  /// that the token is now invalid.
  /// Returns true if it is, otherwise it returns false.
  static bool _checkIfResponseIsValid(http.Response response) {
    _logger.info('Checking if token is valid...');

    final responseDecoded = jsonDecode(response.body) as Map;

    if (response.statusCode == 408) {
      _logger.warning('Validation request timed out');
      return false;
    } else if (response.statusCode == 401) {
      _logger.warning('Token is invalid');
      return false;
    } else if (response.statusCode != 200) {
      _logger.warning(
          'Error while validating token, ${responseDecoded['message']}');
      return false;
    }

    if (responseDecoded.keys.contains('status') &&
        responseDecoded['status'] == 401) {
      _logger.warning('Token is invalid, ${responseDecoded['message']}');
      return false;
    }

    _logger.info('Token is valid');
    return true;
  }
}

class TwitchAppApiMock extends TwitchAppApi {
  TwitchDebugPanelOptions debugPanelOptions;

  ///
  /// The constructor for the Twitch API
  /// [appInfo] holds all the information required to run the API
  /// [debugPanelOptions] are the options to use for the mock
  static Future<TwitchAppApiMock> factory({
    required TwitchAppInfo appInfo,
    required TwitchAuthenticator authenticator,
    required TwitchDebugPanelOptions debugPanelOptions,
  }) async {
    // Create a temporary TwitchAppApi with [streamerId] empty so we
    // can fetch it
    final api = TwitchAppApiMock._(appInfo, authenticator, debugPanelOptions);
    api.streamerId = '1234567890';
    return api;
  }

  ////// CONNEXION RELATED API //////

  @override
  Future<TwitchUser?> user({String? userId, String? login}) async {
    return TwitchUser(
        id: userId ?? '1234567890',
        login: login ?? 'login_$userId',
        displayName: 'display_name_${userId ?? login}');
  }

  @override
  Future<bool?> isUserLive(String userId) async {
    return true;
  }

  ////// CHAT RELATED API //////
  @override
  Future<Iterable<TwitchUser>?> fetchChatters(
      {Iterable<String>? blacklist}) async {
    final out = debugPanelOptions.chatters.map((e) => TwitchUser(
        id: e.displayName, login: e.displayName, displayName: e.displayName));
    return _removeBlacklisted(out, blacklist);
  }

  ////// CHANNEL RELATED API //////
  @override
  Future<Iterable<TwitchUser>?> fetchModerators(
      {bool includeStreamer = false, Iterable<String>? blacklist}) async {
    final out = debugPanelOptions.chatters
        .where((chatter) => chatter.isModerator)
        .map((e) => TwitchUser(
            id: e.displayName,
            login: e.displayName,
            displayName: e.displayName))
        .toList();

    if (includeStreamer) out.add((await user(userId: streamerId))!);

    return _removeBlacklisted(out, blacklist);
  }

  @override
  Future<Iterable<TwitchUser>?> fetchFollowers(
      {bool includeStreamer = false, Iterable<String>? blacklist}) async {
    final out = debugPanelOptions.chatters
        .where((e) => e.isFollower && (includeStreamer ? true : !e.isStreamer))
        .map((e) => TwitchUser(
            id: e.displayName,
            login: e.displayName,
            displayName: e.displayName));
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
  TwitchAppApiMock._(
      super.appInfo, super.twitchAuthenticator, this.debugPanelOptions)
      : super._();
}
