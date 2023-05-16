import 'dart:async';
import 'dart:developer' as devel;
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart';

import 'twitch_manager.dart';

class TwitchAuthentication {
  ///
  /// [oauthKey] is the OAUTH key. If none is provided, the process to generate
  /// one is launched.
  /// [streamerName] is the name of the channel to connect
  /// [moderatorName] is the name of the current logged in moderator. If it is
  /// left empty [streamerName] is used.
  /// [scope] is the required scope of the current app. Comes into play if
  /// generate OAUTH is launched.
  ///
  TwitchAuthentication({
    this.oauthKey,
    required this.appId,
    required this.scope,
    required this.streamerName,
    String? moderatorName,
  }) : moderatorName = moderatorName ?? streamerName;

  String? oauthKey;
  final String appId;
  final List<TwitchScope> scope;
  final String streamerName;
  final String moderatorName;

  /// Provide a callback to react if at any point the token is found invalid.
  /// This is mandatory when connect is called
  Future<void> Function()? _onInvalidTokenCallback;

  ///
  /// Prepare everything which is required when connecting with Twitch API
  /// [requestUserToBrowse] provides a website that the user must navigate to in
  /// order to authenticate.
  ///
  Future<bool> connect({
    required Future<void> Function(String address) requestUserToBrowse,
    required Future<void> Function() onInvalidToken,
    bool retry = true,
  }) async {
    _onInvalidTokenCallback = onInvalidToken;
    oauthKey ??= await _generateOauthKey(requestUserToBrowse);

    final success = await _validateToken();
    if (success) {
      // If everything goes as planned, set a validation every hours and exit
      Timer.periodic(const Duration(hours: 1), (timer) => _validateToken());
      return true;
    }

    // If we can't validate, we should drop the oauth key and generate a new one
    if (retry) {
      oauthKey = null;
      return connect(
        requestUserToBrowse: requestUserToBrowse,
        onInvalidToken: onInvalidToken,
        retry: false,
      );
    }

    // If we get here, we are abording connecting
    return false;
  }

  ///
  /// Get a new OAUTH for the user
  ///
  Future<String> _generateOauthKey(
    Future<void> Function(String) requestUserToBrowse,
  ) async {
    String stateToken = Random().nextInt(0x7fffffff).toString();

    final address = 'https://id.twitch.tv/oauth2/authorize?'
        'response_type=token'
        '&client_id=$appId'
        '&redirect_uri=http://localhost:3000'
        '&scope=${scope.map<String>((e) => e.text()).join('+')}'
        '&state=$stateToken';
    requestUserToBrowse(address);

    // Wait for the user to navigate
    final response = await _waitForAuthentication();

    final re = RegExp(
        r'^http://localhost:3000/#access_token=([a-zA-Z0-9]*)&.*state=([0-9]*).*$');
    final match = re.firstMatch(response);

    if (match!.group(2)! != stateToken) {
      throw 'State token not equal, this connexion may be compromised';
    }
    return match.group(1)!;
  }

  Future<String> _waitForAuthentication() async {
    const postingKeyWebsite = '<!DOCTYPE html>'
        '<html><body>'
        'You can close this page'
        '<script>'
        'var xhr = new XMLHttpRequest();'
        'xhr.open("POST", \'http://localhost:3000\', true);'
        'xhr.setRequestHeader(\'Content-Type\', \'application/json\');'
        'xhr.send(JSON.stringify({\'token\': window.location.href}));'
        '</script>'
        '</body></html>';

    bool hasRequestedWebsite = false;
    bool hasSentKey = false;
    String answer = '';

    void waitingForAnswer(Socket client) {
      // The first answer is to post the validation key
      if (!hasRequestedWebsite) {
        client.listen((data) async {
          hasRequestedWebsite = true;
          client.write('HTTP/1.1 200 OK\nContent-Type: text\n'
              'Content-Length: ${postingKeyWebsite.length}\n'
              '\n'
              '$postingKeyWebsite');
          client.close();
          return;
        });
      } else {
        client.listen((data) async {
          client.close();

          final answerAsString = String.fromCharCodes(data).trim();
          answer = jsonDecode(answerAsString.split('\n').last)['token']!;
          hasSentKey = true;
          return;
        });
      }
    }

    final server = await ServerSocket.bind('localhost', 3000);
    server.listen(waitingForAnswer);
    while (!hasSentKey) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return answer;
  }

  ///
  /// This method can be call by any of the user of authentication to inform
  /// that the token is now invalid.
  /// Returns true if it is, otherwise it returns false.
  ///
  Future<bool> checkIfTokenIsValid(Response response) async {
    final responseDecoded = await jsonDecode(response.body) as Map;
    if (responseDecoded.keys.contains('status') &&
        responseDecoded['status'] == 401) {
      if (_onInvalidTokenCallback != null) _onInvalidTokenCallback!();

      devel.log('Token invalid, please refresh your authentication');
      return false;
    }
    return true;
  }

  ///
  /// Validates the current token. This is mandatory as stated here:
  /// https://dev.twitch.tv/docs/authentication/validate-tokens/
  ///
  Future<bool> _validateToken() async {
    final response = await get(
      Uri.parse('https://id.twitch.tv/oauth2/validate'),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer $oauthKey',
        'Client-Id': appId,
      },
    );

    return await checkIfTokenIsValid(response);
  }
}
