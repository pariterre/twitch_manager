import 'package:twitch_manager/models/twitch_js_extension/twitch_js_extension.dart';
import 'package:twitch_manager/models/twitch_js_extension/twitch_js_extension_interface.dart';

///
/// Define an interface to call the Twitch Extension JavaScript API
class TwitchJsExtensionDesktop implements TwitchJsExtensionBase {
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

final TwitchJsExtensionDesktop _instance = TwitchJsExtensionDesktop();
TwitchJsExtensionBase get getTwitchJsExtension => _instance;

class TwitchJsExtensionActionDesktop implements TwitchJsExtensionActionsBase {
  @override
  void requestIdShare() {
    // This method will never be called in the desktop version
  }
}

final TwitchJsExtensionActionsBase _actionsInstance =
    TwitchJsExtensionActionDesktop();
TwitchJsExtensionActionsBase get getTwitchJsExtensionActions =>
    _actionsInstance;
