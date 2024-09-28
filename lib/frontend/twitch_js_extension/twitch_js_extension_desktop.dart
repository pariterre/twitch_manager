import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension.dart';
import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension_interface.dart';
import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension_public_objects.dart';
import 'package:twitch_manager/utils/twitch_listener.dart';

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

// These methods should never be called in the desktop version
class TwitchJsExtensionBitsDesktop implements TwitchJsExtensionBitsBase {
  @override
  Future<List<BitsProduct>> getProducts() async => throw UnimplementedError();

  @override
  TwitchListener<Function(BitsTransactionObject p1)>
      get onTransactionCompleted => throw UnimplementedError();

  @override
  TwitchListener<Function()> get onTransactionCancelled =>
      throw UnimplementedError();

  @override
  void setUseLoopback(bool useLoopBack) => throw UnimplementedError();

  @override
  void useBits(String sku) => throw UnimplementedError();
}

final TwitchJsExtensionBitsBase _bitsInstance = TwitchJsExtensionBitsDesktop();
TwitchJsExtensionBitsBase get getTwitchJsExtensionBits => _bitsInstance;
