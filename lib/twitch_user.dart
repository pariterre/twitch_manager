import 'dart:async';
import 'dart:convert';
import 'dart:developer' as devel;
import 'dart:io';

import 'package:http/http.dart';
import 'package:twitch_manager/twitch_app_info.dart';

import 'twitch_manager.dart';

class TwitchUser {
  ///
  /// [oauthKey] is the OAUTH key. If none is provided, the process to generate
  /// one is launched.
  /// [streamerUsername] is the name of the channel to connect
  /// [chatbotUsername] is the name of the current logged in chat bot. If it is
  /// left empty [streamerUsername] is used.
  /// [scope] is the required scope of the current app. Comes into play if
  /// generate OAUTH is launched.
  ///
  TwitchUser._({
    required this.username,
    required this.appInfo,
  });

  static Future<TwitchUser> factory({
    required String username,
    required TwitchAppInfo appInfo,
  }) async {
    return TwitchUser._(
      username: username,
      appInfo: appInfo,
    );
  }

  final String username;
  String? oauthKey;
  final TwitchAppInfo appInfo;

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
    bool retry = true,
  }) async {
    _onInvalidTokenCallback = onInvalidToken;

    oauthKey ??= await TwitchApi.getNewOauth(
        appInfo: appInfo, requestUserToBrowse: requestUserToBrowse);

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
        'Client-Id': appInfo.twitchId,
      },
    );

    return await checkIfTokenIsValid(response);
  }
}
