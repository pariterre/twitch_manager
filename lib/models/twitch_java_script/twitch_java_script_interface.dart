import 'package:twitch_manager/models/twitch_java_script/twitch_java_script.dart';

///
/// Define an interface to call the Twitch Extension JavaScript API
abstract class TwitchJavaScriptBase {
  void onAuthorized(Function(OnAuthorizedResponse auth) callback);
}

TwitchJavaScriptBase get getTwitchJavaScriptInstance =>
    throw UnsupportedError('Cannot create an instance of TwitchJavaScriptBase');
