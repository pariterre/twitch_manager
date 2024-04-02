import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:twitch_manager/models/twitch_authenticator.dart';
import 'package:twitch_manager/models/twitch_events.dart';
import 'package:twitch_manager/models/twitch_mock_options.dart';
import 'package:twitch_manager/twitch_app_info.dart';

const _twitchValidateUri = 'https://id.twitch.tv/oauth2/validate';
const _twitchHelixUri = 'https://api.twitch.tv/helix';

List<String> _removeBlacklisted(
    Iterable<String> names, List<String>? blacklist) {
  return names
      .where((e) => blacklist == null || !blacklist.contains(e))
      .toList();
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

class TwitchApi {
  ///
  /// The constructor for the Twitch API
  /// [appInfo] holds all the information required to run the API
  /// [authenticator] holds the OAuth key to communicate with the API
  static Future<TwitchApi> factory({
    required TwitchAppInfo appInfo,
    required TwitchAuthenticator authenticator,
  }) async {
    // Create a temporary TwitchApi with [streamerId] empty so we
    // can fetch it
    final api = TwitchApi._(appInfo, authenticator);
    api.streamerId = await api._userId(authenticator.streamerOauthKey!);
    return api;
  }

  ////// CONNEXION RELATED API //////

  ///
  /// Validates the current OAUTH key. This is mandatory as stated here:
  /// https://dev.twitch.tv/docs/authentication/validate-tokens/
  static Future<bool> validateOauthToken(
      {required TwitchAppInfo appInfo, required String oauthKey}) async {
    final response = await http.get(
      Uri.parse(_twitchValidateUri),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer $oauthKey',
      },
    );

    return _checkIfTokenIsValid(response);
  }

  ///
  /// Generate a random state token that is 16 digits long with some constraints
  static String _generateStateToken() {
    String stateToken = '';
    for (var i = 0; i < 15; i++) {
      stateToken += Random().nextInt(10).toString();
    }

    // Change the 6th digit to a 4 and the 12th to a 2
    stateToken = stateToken.replaceRange(5, 6, '4');
    stateToken = stateToken.replaceRange(11, 12, '2');

    // Add a final number checksum that makes the sum of all the digits is 8
    final sum =
        stateToken.split('').map((e) => int.parse(e)).reduce((a, b) => a + b);
    stateToken += ((1 - sum % 7) % 7).toString();

    return stateToken;
  }

  ///
  /// Get a new OAUTH for the user
  /// [appInfo] holds all the necessary information to connect.
  /// [onRequestBrowsing] is the callback to show which address the user must
  /// browse.
  static Future<String> getNewOauth({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String) onRequestBrowsing,
  }) async {
    final stateToken = _generateStateToken();

    final scope = appInfo.scope;
    final address = 'https://id.twitch.tv/oauth2/authorize?'
        'response_type=token'
        '&client_id=${appInfo.twitchAppId}'
        '&redirect_uri=https://${appInfo.redirectUri}/twitch_redirect.html'
        '&scope=${scope.map<String>((e) => e.toString()).join('+')}'
        '&state=$stateToken';
    onRequestBrowsing(address);

    // Send link to user and wait for the user to accept
    return await _getAuthenticationToken(
        stateToken: stateToken, redirectUri: appInfo.redirectUri);
  }

  ///
  /// Get the stream login of the user [userId].
  Future<String?> login(int userId) async {
    final response = await _sendHttpRequest(HttpRequestMethod.get,
        suffix: 'users', parameters: {'id': userId.toString()});
    if (response == null) return null; // There was an error

    return response.data[0]['login'];
  }

  ///
  /// Get the display name of the user [userId].
  Future<String?> displayName(int userId) async {
    final response = await _sendHttpRequest(HttpRequestMethod.get,
        suffix: 'users', parameters: {'id': userId.toString()});
    if (response == null) return null; // There was an error

    return response.data[0]['display_name'];
  }

  ///
  /// Check if the user of [userId] is currently live. Note the method used here
  /// is kind of a hack as data is expected to be empty when the user is not
  /// live (even though, for some reason the key "type" is "live" when the user
  /// is actually live).
  Future<bool?> isUserLive(int userId) async {
    final response = await _sendHttpRequest(HttpRequestMethod.get,
        suffix: 'streams', parameters: {'user_id': userId.toString()});
    if (response == null) {
      return null; // There was an error
    }

    // Extract the islive information
    return response.data.isNotEmpty && response.data[0]['type'] == 'live';
  }

  ////// CHAT RELATED API //////

  ///
  /// Get the list of current chatters.
  /// The [blacklist] ignore some chatters (ignoring bots for instance).
  Future<List<String>?> fetchChatters({List<String>? blacklist}) async {
    final response = await _sendHttpRequest(HttpRequestMethod.get,
        suffix: 'chat/chatters',
        parameters: {
          'broadcaster_id': streamerId.toString(),
          'moderator_id': streamerId.toString()
        });
    if (response == null) return null; // There was an error

    // Extract the usernames and removed the blacklisted
    return _removeBlacklisted(
        response.data.map<String>((e) => e['user_name']), blacklist);
  }

  ////// CHANNEL RELATED API //////

  ///
  /// Get the list of moderators of the channel.
  /// The streamer is not included in the list of moderators. If one need them
  /// to be included, they can set [includeStreamer] to true. Alternatively,
  /// they can call `login(streamerId)`.
  Future<List<String>?> fetchModerators({bool includeStreamer = false}) async {
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
      if (response == null) return null; // There was an error

      // Copy answer to the output variable
      moderators
          .addAll(response.data.map<String>((e) => e['user_login']).toList());

      if (response.cursor == null) break; // We are done
      cursor = response.cursor;
    } while (true);

    if (includeStreamer) moderators.add((await login(streamerId))!);

    return moderators;
  }

  ///
  /// Get the list of current followers of the channel.
  /// [includeStreamer] If the streamer should be counted as follower too
  /// The [blacklist] ignore some followers (ignoring bots for instance).
  Future<List<String>?> fetchFollowers(
      {bool includeStreamer = false, List<String>? blacklist}) async {
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
      if (response == null) return null; // There was an error

      // Copy answer to the output variable
      users.addAll(response.data.map<String>((e) => e['user_name']).toList());

      if (response.cursor == null) break; // We are done
      cursor = response.cursor;
    } while (true);

    if (includeStreamer) users.add((await displayName(streamerId))!);

    return _removeBlacklisted(users, blacklist);
  }

  ////// REWARD REDEMPTION RELATED API //////

  ///
  /// Create a new reward redemption for the streamer. The [reward] should
  /// contain the title of the reward and the cost in channel points.
  /// Returns the id of the reward redemption.
  Future<String?> createRewardRedemption(
      {required TwitchRewardRedemption reward}) async {
    // TODO: Create the mock for createRewardRedemption
    final response = await _sendHttpRequest(HttpRequestMethod.post,
        suffix: 'channel_points/custom_rewards',
        parameters: {
          'broadcaster_id': streamerId.toString()
        },
        body: {
          'title': reward.rewardRedemption,
          'cost': reward.cost.toString(),
        });
    if (response == null) return null; // There was an error

    return response.data[0]['id'];
  }

  ///
  /// Updates the reward redemption [reward] with the new information.
  /// The [reward] should contain the [rewardRedemptionId],
  /// the new title and cost.
  /// Returns true if the update was successful.
  Future<bool> updateRewardRedemption(
      {required TwitchRewardRedemption reward}) async {
    // TODO: Create the mock for updateRewardRedemption
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
    return response != null;
  }

  ///
  /// Delete the reward redemption [reward].
  /// The [reward] should contain the [rewardRedemptionId],
  /// Returns true if the update was successful.
  Future<bool> deleteRewardRedemption(
      {required TwitchRewardRedemption reward}) async {
    // TODO: Create the mock for deleteRewardRedemption
    final response = await _sendHttpRequest(HttpRequestMethod.delete,
        suffix: 'channel_points/custom_rewards',
        parameters: {
          'id': reward.rewardRedemptionId,
          'broadcaster_id': streamerId.toString(),
        });
    return response != null;
  }

  ///
  /// Fulfills or cancels the reward redemption [reward] with the new status.
  void updateRewardRedemptionStatus({
    required TwitchRewardRedemption reward,
    required TwitchRewardRedemptionStatus status,
  }) async {
    // TODO: Create the mock for updateRewardRedemptionStatus
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
    if (response == null) return null; // There was an error
  }

  ////// INTERNAL //////

  ///
  /// ATTRIBUTES
  final TwitchAppInfo _appInfo;
  late final int streamerId; // It is set in the factory
  final TwitchAuthenticator _authenticator;

  ///
  /// Private constructor
  TwitchApi._(this._appInfo, this._authenticator);

  ///
  /// Send an actual HTTP request to Twitch
  Future<_TwitchResponse?> _sendHttpRequest(HttpRequestMethod method,
      {required String suffix,
      Map<String, String?>? parameters,
      Map<String, String>? body}) async {
    // Stop now if we are disconnected
    if (_authenticator.streamerOauthKey == null) return null;

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
                  'Bearer ${_authenticator.streamerOauthKey}',
              'Client-Id': _appInfo.twitchAppId,
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
                  'Bearer ${_authenticator.streamerOauthKey}',
              'Client-Id': _appInfo.twitchAppId,
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
                  'Bearer ${_authenticator.streamerOauthKey}',
              'Client-Id': _appInfo.twitchAppId,
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
                  'Bearer ${_authenticator.streamerOauthKey}',
              'Client-Id': _appInfo.twitchAppId,
            });
        if (response.body.contains('error')) return null;
        return _TwitchResponse(data: [], cursor: null);
    }

    // Make sure the token is still valid before continuing
    if (!_checkIfTokenIsValid(response)) return null;

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
  /// Fetch the user id from its [oauthKey]
  Future<int> _userId(String oauthKey) async {
    final response = await http.get(
      Uri.parse(_twitchValidateUri),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer $oauthKey',
      },
    );

    return int.tryParse(jsonDecode(response.body)?['user_id']) ?? -1;
  }

  ///
  /// Call the Twitch API to Authenticate the user.
  /// The [redirectUri] should match the configured one in the extension
  /// dev panel of dev.twitch.tv.
  /// This method has the same purpose of _authenticate but is targetted to use
  /// the service. Doing so, we don't need Socket anymore, but only
  /// websockets, allowing for web interface to be used
  static Future<String> _getAuthenticationToken(
      {required String stateToken, required String redirectUri}) async {
    while (true) {
      final response = await http.get(Uri.https(
          redirectUri, '/get_access_token.php', {'state': stateToken}));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('token') && data['token'] != 'error') {
          return data['token'];
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  ///
  /// This method can be call by any of the user of authentication to inform
  /// that the token is now invalid.
  /// Returns true if it is, otherwise it returns false.
  ///
  static bool _checkIfTokenIsValid(http.Response response) {
    final responseDecoded = jsonDecode(response.body) as Map;
    if (responseDecoded.keys.contains('status') &&
        responseDecoded['status'] == 401) {
      dev.log('ERROR: ${responseDecoded['message']}');
      return false;
    }
    return true;
  }
}

class TwitchApiMock extends TwitchApi {
  TwitchDebugPanelOptions debugPanelOptions;

  ///
  /// The constructor for the Twitch API
  /// [appInfo] holds all the information required to run the API
  /// [debugPanelOptions] are the options to use for the mock
  static Future<TwitchApiMock> factory({
    required TwitchAppInfo appInfo,
    required TwitchAuthenticatorMock authenticator,
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

  ////// INTERNAL //////

  ///
  /// Private constructor
  TwitchApiMock._(super.appInfo,
      TwitchAuthenticatorMock super.twitchAuthenticator, this.debugPanelOptions)
      : super._();
}
