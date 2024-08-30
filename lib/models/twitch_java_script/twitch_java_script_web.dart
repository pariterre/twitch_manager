import 'package:js/js.dart';
import 'package:twitch_manager/models/twitch_java_script/twitch_java_script.dart';
import 'package:twitch_manager/models/twitch_java_script/twitch_java_script_interface.dart';

///
/// Declare external JavaScript function and objects
@JS('Twitch.ext')
external _TwitchExtension get _twitchExtension;

///
/// Define the Twitch Extension JavaScript API
@JS()
@anonymous
class _TwitchExtension {
  external void onAuthorized(Function(_OnAuthorizedResponseJs auth) callback);
}

///
/// Define the response from the Twitch Extension onAuthorized callback
@JS()
@anonymous
class _OnAuthorizedResponseJs {
  external String get channelId;
  external String get clientId;
  external String get token;
  external String get helixToken;
  external String get userId;
}

OnAuthorizedResponse _fromJsToReponse(_OnAuthorizedResponseJs responseJs) {
  return OnAuthorizedResponse(
    channelId: responseJs.channelId,
    clientId: responseJs.clientId,
    token: responseJs.token,
    helixToken: responseJs.helixToken,
    userId: responseJs.userId,
  );
}

///
/// Define an interface to call the Twitch Extension JavaScript API
class TwitchJavaScriptWeb implements TwitchJavaScriptBase {
  @override
  void onAuthorized(Function(OnAuthorizedResponse auth) callback) {
    _twitchExtension.onAuthorized(
        allowInterop((responseJs) => callback(_fromJsToReponse(responseJs))));
  }
}

final TwitchJavaScriptWeb _instance = TwitchJavaScriptWeb();
TwitchJavaScriptBase get getTwitchJavaScriptInstance => _instance;
