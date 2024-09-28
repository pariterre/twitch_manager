import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension.dart';
import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension_public_objects.dart';
import 'package:twitch_manager/twitch_utils.dart';

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

abstract class TwitchJsExtensionBitsBase {
  Future<List<BitsProduct>> getProducts();
  TwitchListener<Function(BitsTransactionObject)> get onTransactionCompleted;
  TwitchListener<Function()> get onTransactionCancelled;
  void setUseLoopback(bool useLoopBack);
  void useBits(String sku);
}

TwitchJsExtensionBitsBase get getTwitchJsExtensionBits =>
    throw UnsupportedError(
        'Cannot create an instance of TwitchJsExtenionsBitsBase');
