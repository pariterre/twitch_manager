import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart';

import 'twitch_manager.dart';

const _twitchUri = 'https://api.twitch.tv/helix';

class _TwitchResponse {
  List<dynamic> data;
  String? cursor;
  _TwitchResponse({required this.data, required this.cursor});
}

class TwitchApi {
  String get streamerUsername => _authentication.streamerUsername;
  final int streamerId;
  final TwitchAuthentication _authentication;

  ///
  /// Private constructor
  ///
  TwitchApi._(
    this._authentication, [
    this.streamerId = -1,
  ]);

  ///
  /// The constructor for the Twitch API, [streamerUsername] is the of the streamer
  ///
  static Future<TwitchApi> factory(TwitchAuthentication authenticator) async {
    // Create a temporary TwitchApi with [streamerId] and [botId] empty so we
    // can fetch them
    final api = TwitchApi._(authenticator);
    final streamerId =
        (await api.fetchStreamerId(authenticator.streamerUsername))!;

    return TwitchApi._(authenticator, streamerId);
  }

  ///
  /// Get the stream ID of [username].
  ///
  Future<int?> fetchStreamerId(String username) async {
    final response = await _sendGetRequest(
        requestType: 'users', parameters: {'login': username});
    if (response == null) return null; // There was an error

    return int.parse(response.data[0]['id']);
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
          'moderator_id': streamerId.toString()
        });
    if (response == null) return null; // There was an error

    // Extract the usernames and removed the blacklisted
    return response.data
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
  /// Get the list of current followers of the channel.
  ///
  Future<List<String>?> fetchFollowers() async {
    final List<String> users = [];
    String? cursor;
    do {
      final parameters = {
        'broadcaster_id': streamerId.toString(),
        'first': '100',
      };
      if (cursor != null) parameters['after'] = cursor;

      final response = await _sendGetRequest(
          requestType: 'channels/followers', parameters: parameters);
      if (response == null) return null; // There was an error

      // Copy answer to the output variable
      users.addAll(response.data.map<String>((e) => e['user_name']).toList());

      if (response.cursor == null) break; // We are done
      cursor = response.cursor;
    } while (true);

    // Extract the usernames and removed the blacklisted
    return users;
  }

  ///
  /// Post an actual request to Twitch
  ///
  Future<_TwitchResponse?> _sendGetRequest(
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
    if (!await _authentication.checkIfTokenIsValid(response)) return null;

    final responseDecoded = await jsonDecode(response.body) as Map;
    if (responseDecoded.containsKey('data')) {
      return _TwitchResponse(
          data: responseDecoded['data'],
          cursor: responseDecoded['pagination']?['cursor']);
    } else {
      log(responseDecoded.toString());
      return null;
    }
  }
}
