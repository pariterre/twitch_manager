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
  static void onAuthorized(Function(OnAuthorizedResponse auth) callback) {
    getTwitchJavaScriptInstance.onAuthorized(callback);
  }
}
