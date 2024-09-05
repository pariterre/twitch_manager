import 'package:twitch_manager/models/twitch_js_extension/twitch_js_extension.dart';

///
/// Define an interface to call the Twitch Extension JavaScript API
abstract class TwitchJsExtensionBase {
  ///
  /// This is a callback that is called when the Twitch Extension is authorized
  void onAuthorized(Function(OnAuthorizedResponse auth) callback);

  ///
  /// This is a callback that is called when PubSub messages are received
  void listen(String target,
      Function(String target, String contentType, String message) callback);
}

TwitchJsExtensionBase get getTwitchJsExtension => throw UnsupportedError(
    'Cannot create an instance of TwitchJsExtenionsBase');

abstract class TwitchJsExtensionActionsBase {
  void requestIdShare();
}

TwitchJsExtensionActionsBase get getTwitchJsExtensionActions =>
    throw UnsupportedError(
        'Cannot create an instance of TwitchJsExtenionsActionsBase');
