import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart';

import 'twitch_manager.dart';

const _twitchUri = 'https://api.twitch.tv/helix';

class TwitchApi {
  final int streamerId;
  final int moderatorId;
  final TwitchAuthentication _authentication;

  ///
  /// Private constructor
  ///
  TwitchApi._(this._authentication, this.streamerId, this.moderatorId);

  ///
  /// The constructor for the Twitch API, [streamerName] is the of the streamer,
  /// [moderatorName] is the name of the current poster. If [moderatorName] is
  /// left empty, then [streamerName] is used.
  ///
  static Future<TwitchApi> factory(TwitchAuthentication authenticator) async {
    // Create a temporary TwitchApi with [streamerId] and [botId] empty so we
    // can fetch them
    final api = TwitchApi._(authenticator, -1, -1);
    final streamerId = (await api.fetchStreamerId(authenticator.streamerName))!;
    final moderatorId =
        (await api.fetchStreamerId(authenticator.moderatorName))!;

    return TwitchApi._(authenticator, streamerId, moderatorId);
  }

  ///
  /// Get the stream ID of [username].
  ///
  Future<int?> fetchStreamerId(String username) async {
    final response = await _sendGetRequest(
        requestType: 'users', parameters: {'login': username});
    if (response.isEmpty) return null; // username not found

    return int.parse(response[0]['id']);
  }

  ///
  /// Get the list of current chatters.
  /// The [blacklist] ignore some chatters (ignoring bots for instance)
  ///
  Future<List<String>?> fetchChatters({List<String>? blacklist}) async {
    final response = await _sendGetRequest(
        requestType: 'chat/chatters',
        parameters: {
          'broadcaster_id': streamerId.toString(),
          'moderator_id': moderatorId.toString()
        });
    if (response.isEmpty) return null; // username not found

    // Extract the usernames and removed the blacklisted
    return response
        .map<String?>((e) {
          final username = e['user_name'];
          return blacklist != null && blacklist.contains(username)
              ? null
              : username;
        })
        .where((e) => e != null)
        .toList()
        .cast<String>();
  }

  ///
  /// Post an actual request to Twitch
  ///
  Future<List> _sendGetRequest(
      {required String requestType,
      required Map<String, String?> parameters}) async {
    var params = '';
    parameters.forEach(
        (key, value) => params += '$key${value == null ? '' : '=$value'}&');
    params = params.substring(0, params.length - 1); // Remove to final '&'

    final response = await get(
      Uri.parse('$_twitchUri/$requestType?$params'),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer ${_authentication.oauthKey}',
        'Client-Id': _authentication.appId,
      },
    );

    // Make sure the token is still valid before continuing
    if (!await _authentication.checkIfTokenIsValid(response)) return [];

    final responseDecoded = await jsonDecode(response.body) as Map;
    if (responseDecoded.containsKey('data')) {
      return responseDecoded['data'];
    } else {
      log(responseDecoded.toString());
      return [];
    }
  }
}
