import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart';
import 'package:twitch_manager/twitch_app_info.dart';

import 'twitch_manager.dart';

const _twitchUri = 'https://api.twitch.tv/helix';

class _TwitchResponse {
  List<dynamic> data;
  String? cursor;
  _TwitchResponse({required this.data, required this.cursor});
}

class TwitchApi {
  String get streamerUsername => _streamer.username;
  final TwitchAppInfo appInfo;
  late final int streamerId; // It is set in the factory
  final TwitchUser _streamer;

  ///
  /// Private constructor
  ///
  TwitchApi._(this._streamer, {required this.appInfo});

  ///
  /// The constructor for the Twitch API, [streamerUsername] is the of the streamer
  ///
  static Future<TwitchApi> factory(
      TwitchUser streamer, TwitchAppInfo appInfo) async {
    // Create a temporary TwitchApi with [streamerId] empty so we
    // can fetch it
    final api = TwitchApi._(streamer, appInfo: appInfo);
    api.streamerId = (await api.fetchStreamerId(streamer.username))!;
    return api;
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
        HttpHeaders.authorizationHeader: 'Bearer ${_streamer.oauthKey}',
        'Client-Id': appInfo.twitchId,
      },
    );

    // Make sure the token is still valid before continuing
    if (!await _streamer.checkIfTokenIsValid(response)) return null;

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
  /// Get a new OAUTH for the user
  /// [appId] is the twitch app id; [scope] are the requested rights for the app;
  /// [requestUserToBrowse] is the callback to show which address the user must
  /// browse;
  ///
  static Future<String> getNewOauth({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String) requestUserToBrowse,
  }) async {
    // Create the authentication link
    String stateToken = Random().nextInt(0x7fffffff).toString();
    final address = 'https://id.twitch.tv/oauth2/authorize?'
        'response_type=token'
        '&client_id=${appInfo.twitchId}'
        '&redirect_uri=${appInfo.redirectAddress}'
        '&scope=${appInfo.scope.map<String>((e) => e.text()).join('+')}'
        '&state=$stateToken';

    // Send link to user and wait for the user to accept
    requestUserToBrowse(address);
    final response = await _waitForTwitchResponse(appInfo.redirectAddress);

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

  static Future<String> _waitForTwitchResponse(String redirectAddress) async {
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

    return twitchResponse!;
  }
}
