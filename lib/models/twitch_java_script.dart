import 'package:js/js.dart';

///
/// Declare external JavaScript function and objects
@JS('Twitch.ext')
external _TwitchExtension get _twitchExtension;

///
/// Define the Twitch Extension JavaScript API
@JS()
@anonymous
class _TwitchExtension {
  external void onAuthorized(Function(OnAuthorizedResponse auth) callback);
}

///
/// Define the response from the Twitch Extension onAuthorized callback
@JS()
@anonymous
class OnAuthorizedResponse {
  external String get channelId;
  external String get clientId;
  external String get token;
  external String get helixToken;
  external String get userId;
}

///
/// Define an interface to call the Twitch Extension JavaScript API
class TwitchJavaScript {
  static void onAuthorized(Function(OnAuthorizedResponse auth) callback) {
    _twitchExtension.onAuthorized(allowInterop(callback));
  }
}
