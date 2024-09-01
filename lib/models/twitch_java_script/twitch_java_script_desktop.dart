import 'package:twitch_manager/models/twitch_java_script/twitch_java_script.dart';
import 'package:twitch_manager/models/twitch_java_script/twitch_java_script_interface.dart';

///
/// Define an interface to call the Twitch Extension JavaScript API
class TwitchJavaScriptDesktop implements TwitchJavaScriptBase {
  @override
  void onAuthorized(Function(OnAuthorizedResponse auth) callback) {
    // This method will never be called in the desktop version
  }

  @override
  void listen(String target,
      Function(String target, String contentType, String message) callback) {
    // This method will never be called in the desktop version
  }
}

final TwitchJavaScriptDesktop _instance = TwitchJavaScriptDesktop();
TwitchJavaScriptBase get getTwitchJavaScriptInstance => _instance;
