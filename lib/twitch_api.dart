import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart';

import 'twitch_app_info.dart';
import 'twitch_authenticator.dart';
import 'twitch_manager.dart';

const _twitchValidateUri = 'https://id.twitch.tv/oauth2/validate';
const _twitchHelixUri = 'https://api.twitch.tv/helix';

///
/// Class that holds a response from Twitch API, this is to easy the communication
/// between internal parts of the API
class _TwitchResponse {
  List<dynamic> data;
  String? cursor;
  _TwitchResponse({required this.data, required this.cursor});
}

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
    final response = await get(
      Uri.parse(_twitchValidateUri),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer $oauthKey',
        'Client-Id': appInfo.twitchAppId,
      },
    );

    return _checkIfTokenIsValid(response);
  }

  ///
  /// Get a new OAUTH for the user
  /// [appInfo] holds all the necessary information to connect.
  /// [onRequestBrowsing] is the callback to show which address the user must
  /// browse.
  ///
  static Future<String> getNewOauth({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String) onRequestBrowsing,
    bool chatOnly = false,
  }) async {
    // Create the authentication link
    String stateToken = Random().nextInt(0x7fffffff).toString();

    final scope = chatOnly ? appInfo.chatScope : appInfo.scope;
    final address = 'https://id.twitch.tv/oauth2/authorize?'
        'response_type=token'
        '&client_id=${appInfo.twitchAppId}'
        '&redirect_uri=${appInfo.redirectAddress}'
        '&scope=${scope.map<String>((e) => e.text()).join('+')}'
        '&state=$stateToken';

    // Send link to user and wait for the user to accept
    onRequestBrowsing(address);
    final response = await _authenticate(appInfo.redirectAddress);

    // Parse the answer
    final re = RegExp(r'^' +
        appInfo.redirectAddress +
        r'/#access_token=([a-zA-Z0-9]*)&.*state=([0-9]*).*$');
    final match = re.firstMatch(response);

    if (match!.group(2)! != stateToken) {
      throw 'State token not equal, this connexion may be compromised';
    }
    return match.group(1)!;
  }

  ///
  /// Get the stream login of the user [userId].
  Future<String?> login(int userId) async {
    final response = await _sendGetRequest(
        requestType: 'users', parameters: {'id': userId.toString()});
    if (response == null) return null; // There was an error

    // Extract the usernames and removed the blacklisted
    return response.data[0]["login"];
  }

  ///
  /// Get the display name of the user [userId].
  Future<String?> displayName(int userId) async {
    final response = await _sendGetRequest(
        requestType: 'users', parameters: {'id': userId.toString()});
    if (response == null) return null; // There was an error

    // Extract the usernames and removed the blacklisted
    return response.data[0]["display_name"];
  }

  ////// CHAT RELATED API //////

  ///
  /// Get the list of current chatters.
  /// The [blacklist] ignore some chatters (ignoring bots for instance).
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

  ////// CHANNEL RELATED API //////

  ///
  /// Get the list of moderators of the channel.
  Future<List<String>?> fetchModerators() async {
    final List<String> moderators = [];
    String? cursor;
    do {
      final parameters = {
        'broadcaster_id': streamerId.toString(),
        'first': '100',
      };
      if (cursor != null) parameters['after'] = cursor;

      final response = await _sendGetRequest(
          requestType: 'moderation/moderators', parameters: parameters);
      if (response == null) return null; // There was an error

      // Copy answer to the output variable
      moderators
          .addAll(response.data.map<String>((e) => e['user_login']).toList());

      if (response.cursor == null) break; // We are done
      cursor = response.cursor;
    } while (true);

    return moderators;
  }

  ///
  /// Get the list of current followers of the channel.
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
  /// Post an actual GET request to Twitch
  Future<_TwitchResponse?> _sendGetRequest(
      {required String requestType, Map<String, String?>? parameters}) async {
    var params = '';

    if (parameters != null) {
      parameters.forEach(
          (key, value) => params += '$key${value == null ? '' : '=$value'}&');
      params = params.substring(0, params.length - 1); // Remove to final '&'
    }

    final response = await get(
      Uri.parse(
          '$_twitchHelixUri/$requestType${params.isEmpty ? '' : '?$params'}'),
      headers: <String, String>{
        HttpHeaders.authorizationHeader:
            'Bearer ${_authenticator.streamerOauthKey}',
        'Client-Id': _appInfo.twitchAppId,
      },
    );

    // Make sure the token is still valid before continuing
    if (!await _checkIfTokenIsValid(response)) return null;

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
    final response = await get(
      Uri.parse(_twitchValidateUri),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer $oauthKey',
      },
    );

    return int.tryParse(jsonDecode(response.body)?['user_id']) ?? -1;
  }

  ///
  /// Call the Twitch API to Authenticate the user.
  /// The [redirectAddress] should match the configured one in the extension
  /// dev panel of dev.twitch.tv.
  static Future<String> _authenticate(String redirectAddress) async {
    // In the success page, we have to fetch the address and POST it to ourselves
    // since it is not possible otherwise to get it
    final successWebsite = '<!DOCTYPE html>'
        '<html><body>'
        'You can close this page'
        '<script>'
        'var xhr = new XMLHttpRequest();'
        'xhr.open("POST", \'$redirectAddress\', true);'
        'xhr.setRequestHeader(\'Content-Type\', \'application/json\');'
        'xhr.send(JSON.stringify({\'token\': window.location.href}));'
        '</script>'
        '</body></html>';

    // Communication procedure
    String? twitchResponse;
    void twitchResponseCallback(Socket client) {
      client.listen((data) async {
        // Parse the twitch answer
        final answerAsString = String.fromCharCodes(data).trim().split('\r\n');

        if (answerAsString.first == 'GET / HTTP/1.1') {
          // Send the success page to browser
          client.write('HTTP/1.1 200 OK\nContent-Type: text\n'
              'Content-Length: ${successWebsite.length}\n'
              '\n'
              '$successWebsite');
          return;
        } else {
          // Otherwise it is a POST we sent ourselves in the success page
          // For some reason, this function is call sometimes more than once
          twitchResponse ??= jsonDecode(answerAsString.last)['token']!;
        }

        client.close();
        return;
      });
    }

    final server = await ServerSocket.bind('localhost', 3000);
    server.listen(twitchResponseCallback);
    while (twitchResponse == null) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    server.close();
    return twitchResponse!;
  }

  ///
  /// This method can be call by any of the user of authentication to inform
  /// that the token is now invalid.
  /// Returns true if it is, otherwise it returns false.
  ///
  static Future<bool> _checkIfTokenIsValid(Response response) async {
    final responseDecoded = await jsonDecode(response.body) as Map;
    if (responseDecoded.keys.contains('status') &&
        responseDecoded['status'] == 401) {
      dev.log('ERROR: ${responseDecoded['message']}');
      return false;
    }
    return true;
  }
}
