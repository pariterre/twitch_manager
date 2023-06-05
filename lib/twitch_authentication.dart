import 'dart:async';
import 'dart:convert';
import 'dart:developer' as devel;
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart';

import 'twitch_manager.dart';

const String _redirectAddress = 'http://localhost:3000';

///
/// Get a new OAUTH for the user
/// [appId] is the twitch app id; [scope] are the requested rights for the app;
/// [requestUserToBrowse] is the callback to show which address the user must
/// browse;
///
Future<String> _getNewOauth({
  required String appId,
  required List<TwitchScope> scope,
  required Future<void> Function(String) requestUserToBrowse,
}) async {
  // Create the authentication link
  String stateToken = Random().nextInt(0x7fffffff).toString();
  final address = 'https://id.twitch.tv/oauth2/authorize?'
      'response_type=token'
      '&client_id=$appId'
      '&redirect_uri=$_redirectAddress'
      '&scope=${scope.map<String>((e) => e.text()).join('+')}'
      '&state=$stateToken';

  // Send link to user and wait for the user to accept
  requestUserToBrowse(address);
  final response = await _waitForTwitchResponse();

  // Parse the answer
  final re = RegExp(r'^' +
      _redirectAddress +
      r'/#access_token=([a-zA-Z0-9]*)&.*state=([0-9]*).*$');
  final match = re.firstMatch(response);

  if (match!.group(2)! != stateToken) {
    throw 'State token not equal, this connexion may be compromised';
  }
  return match.group(1)!;
}

Future<String> _waitForTwitchResponse() async {
  // In the success page, we have to fetch the address and POST it to ourselves
  // since it is not possible otherwise to get it
  const successWebsite = '<!DOCTYPE html>'
      '<html><body>'
      'You can close this page'
      '<script>'
      'var xhr = new XMLHttpRequest();'
      'xhr.open("POST", \'$_redirectAddress\', true);'
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

// TODO separate Authentication of chatbot (Now deactivated)
class TwitchAuthentication {
  ///
  /// [oauthKey] is the OAUTH key. If none is provided, the process to generate
  /// one is launched.
  /// [streamerUsername] is the name of the channel to connect
  /// [chatbotUsername] is the name of the current logged in chat bot. If it is
  /// left empty [streamerUsername] is used.
  /// [scope] is the required scope of the current app. Comes into play if
  /// generate OAUTH is launched.
  ///
  TwitchAuthentication._({
    required this.oauthKey,
    required this.appId,
    required this.scope,
    required this.streamerUsername,
    String? chatbotUsername,
  }) : chatbotUsername = chatbotUsername ?? streamerUsername;

  static Future<TwitchAuthentication> factory({
    required String appId,
    required List<TwitchScope> scope,
    required String? oauthKey,
    required String streamerUsername,
    String? chatbotUsername,
  }) async {
    return TwitchAuthentication._(
        oauthKey: oauthKey,
        appId: appId,
        scope: scope,
        streamerUsername: streamerUsername,
        chatbotUsername: chatbotUsername);
  }

  String? oauthKey;
  final String appId;
  final List<TwitchScope> scope;
  final String streamerUsername;
  final String chatbotUsername;

  /// Provide a callback to react if at any point the token is found invalid.
  /// This is mandatory when connect is called
  Future<void> Function()? _onInvalidTokenCallback;

  ///
  /// Prepare everything which is required when connecting with Twitch API
  /// [requestUserToBrowse] provides a website that the user must navigate to in
  /// order to authenticate; [onInvalidToken] is the callback if token is found
  /// to be invalid; [onSuccess] is the callback if everything went well; if
  /// [retry] is set to true, the connexion will retry if it fails.
  Future<bool> connect({
    required Future<void> Function(String address) requestUserToBrowse,
    Future<void> Function()? onInvalidToken,
    required Future<void> Function(
            String oauth, String streamerUsername, String chatbotUsername)
        onSuccess,
    bool retry = true,
  }) async {
    _onInvalidTokenCallback = onInvalidToken;
    oauthKey ??= await _getNewOauth(
      appId: appId,
      scope: scope,
      requestUserToBrowse: requestUserToBrowse,
    );

    final success = await _validateToken();
    if (success) {
      onSuccess(oauthKey!, streamerUsername, chatbotUsername);

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
        onSuccess: onSuccess,
        retry: false,
      );
    }

    // If we get here, we are abording connecting
    return false;
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
