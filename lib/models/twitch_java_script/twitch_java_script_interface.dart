import 'package:twitch_manager/models/twitch_java_script/twitch_java_script.dart';

///
/// Define an interface to call the Twitch Extension JavaScript API
abstract class TwitchJavaScriptBase {
  ///
  /// This is a callback that is called when the Twitch Extension is authorized
  void onAuthorized(Function(OnAuthorizedResponse auth) callback);

  ///
  /// This is a callback that is called when PubSub messages are received
  void listen(String target,
      Function(String target, String contentType, String message) callback);
}

TwitchJavaScriptBase get getTwitchJavaScriptInstance =>
    throw UnsupportedError('Cannot create an instance of TwitchJavaScriptBase');
