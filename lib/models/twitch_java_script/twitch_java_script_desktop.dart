import 'package:twitch_manager/models/twitch_java_script/twitch_java_script.dart';
import 'package:twitch_manager/models/twitch_java_script/twitch_java_script_interface.dart';

///
/// Define an interface to call the Twitch Extension JavaScript API
class TwitchJavaScriptDesktop implements TwitchJavaScriptBase {
  @override
  void onAuthorized(Function(OnAuthorizedResponse auth) callback) {
    callback(OnAuthorizedResponse(
      channelId: '123456',
      clientId: 'client-id',
      token: 'token',
      helixToken: 'helix-token',
      userId: 'user-id',
    ));
  }
}

final TwitchJavaScriptDesktop _instance = TwitchJavaScriptDesktop();
TwitchJavaScriptBase get getTwitchJavaScriptInstance => _instance;
