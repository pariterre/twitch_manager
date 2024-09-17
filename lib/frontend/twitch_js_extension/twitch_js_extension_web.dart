import 'package:js/js.dart';
import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension.dart';
import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension_interface.dart';

///
/// Reference for the Twitch Extension JavaScript API
/// https://dev.twitch.tv/docs/extensions/reference/

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

  // Listen to PubSub messages
  external void listen(
    String target,
    Function(String target, String contentType, String message) callback,
  );
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

OnAuthorizedResponse _fromReponseJsToReponse(
    _OnAuthorizedResponseJs responseJs) {
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
class TwitchJsExtensionWeb implements TwitchJsExtensionBase {
  @override
  void onAuthorized(Function(OnAuthorizedResponse auth) callback) {
    _twitchExtension.onAuthorized(allowInterop(
        (responseJs) => callback(_fromReponseJsToReponse(responseJs))));
  }

  @override
  void listen(String target,
      Function(String target, String contentType, String message) callback) {
    _twitchExtension.listen(target, allowInterop(callback));
  }
}

// @JS('Twitch.ext.actions')
// external _TwitchActions get _twitchActions;

// @JS()
// @anonymous
// class _TwitchActions {
//   external void requestIdShare();
// }

class TwitchJsExtensionActionWeb implements TwitchJsExtensionActionsBase {
  @override
  void requestIdShare() {
    //_twitchActions.requestIdShare();
  }
}

final TwitchJsExtensionWeb _instance = TwitchJsExtensionWeb();
TwitchJsExtensionBase get getTwitchJsExtension => _instance;

final TwitchJsExtensionActionsBase _actionsInstance =
    TwitchJsExtensionActionWeb();
TwitchJsExtensionActionsBase get getTwitchJsExtensionActions =>
    _actionsInstance;
