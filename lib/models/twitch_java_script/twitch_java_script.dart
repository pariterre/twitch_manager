import 'package:twitch_manager/models/twitch_java_script/twitch_java_script_interface.dart'
    if (dart.library.js) 'package:twitch_manager/models/twitch_java_script/twitch_java_script_web.dart'
    if (dart.library.io) 'package:twitch_manager/models/twitch_java_script/twitch_java_script_desktop.dart';

class OnAuthorizedResponse {
  final String channelId;
  final String clientId;
  final String token;
  final String helixToken;
  final String userId;

  OnAuthorizedResponse({
    required this.channelId,
    required this.clientId,
    required this.token,
    required this.helixToken,
    required this.userId,
  });
}

class TwitchJavaScript {
  ///
  /// This is a callback that is called when the Twitch Extension is authorized
  static void onAuthorized(Function(OnAuthorizedResponse auth) callback) {
    getTwitchJavaScriptInstance.onAuthorized(callback);
  }

  ///
  /// This is a callback that is called when PubSub messages are received
  static void listen(String target,
      Function(String target, String contentType, String message) callback) {
    getTwitchJavaScriptInstance.listen(target, callback);
  }
}
