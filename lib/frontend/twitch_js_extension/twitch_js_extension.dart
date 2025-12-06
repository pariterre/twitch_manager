import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension_interface.dart'
    if (dart.library.js) 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension_web.dart'
    if (dart.library.io) 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension_desktop.dart';
import 'package:twitch_manager/twitch_utils.dart';
import 'package:twitch_manager/utils/twitch_js_extension_public_objects.dart';

class OnAuthorizedResponse {
  final String channelId;
  final String clientId;
  final String token;
  final String helixToken;
  final String userId;

  OnAuthorizedResponse({
    required this.channelId,
    required this.clientId,
    required this.token,
    required this.helixToken,
    required this.userId,
  });
}

class TwitchJsExtension {
  ///
  /// This is a callback that is called when the Twitch Extension is authorized
  static void onAuthorized(Function(OnAuthorizedResponse auth) callback) =>
      getTwitchJsExtension.onAuthorized(callback);

  ///
  /// This is a callback that is called when PubSub messages are received
  static void listen(
          String target,
          Function(String target, String contentType, String message)
              callback) =>
      getTwitchJsExtension.listen(target, callback);

  ///
  /// This is an object to call the TwitchJsExtensionActionsBase
  static final TwtichJsExtensionActions _twitchJsExtensionActionsInstance =
      TwtichJsExtensionActions();
  static TwtichJsExtensionActions get actions =>
      _twitchJsExtensionActionsInstance;

  ///
  /// This is an object to call the TwitchJsExtensionBitsBase
  static final TwitchJsExtensionBits _twitchJsExtensionBitsInstance =
      TwitchJsExtensionBits();
  static TwitchJsExtensionBits get bits => _twitchJsExtensionBitsInstance;

  ///
  /// This is an object to call the TwitchJsExtensionViewerBase
  static final TwtichJsExtensionViewer _twitchJsExtensionViewerInstance =
      TwtichJsExtensionViewer();
  static TwtichJsExtensionViewer get viewer => _twitchJsExtensionViewerInstance;
}

class TwtichJsExtensionActions {
  ///
  /// This method requests the ID share from the Twitch Extension. If this is
  /// called, it will pop up a dialog in the Twitch Extension asking the user
  /// to share their ID with the extension. If the user accepts, the extension
  /// will receive the user's ID from now on.
  void requestIdShare() => getTwitchJsExtensionActions.requestIdShare();
}

class TwitchJsExtensionBits {
  ///
  /// This method requests the products from the Twitch Extension. If this is
  /// called, it will pop up a dialog in the Twitch Extension asking the user
  /// to share their ID with the extension. If the user accepts, the extension
  /// will receive the user's ID from now on.
  Future<List<BitsProduct>> getProducts() async =>
      await getTwitchJsExtensionBits.getProducts();

  ///
  /// Listener that is called when a transaction is completed. This is the developer's
  /// responsability to listen to this event and also to cancel the listener when
  /// it is not needed anymore.
  TwitchListener<dynamic Function(BitsTransactionObject)>
      get onTransactionCompleted =>
          getTwitchJsExtensionBits.onTransactionCompleted;

  ///
  /// Listener that is called when a transaction is cancelled. This is the developer's
  /// responsability to listen to this event and also to cancel the listener when
  /// it is not needed anymore.
  TwitchListener<dynamic Function()> get onTransactionCancelled =>
      getTwitchJsExtensionBits.onTransactionCancelled;

  ///
  /// This method sets the use of the loopback for testing. It creates a false transaction
  /// that is not sent to the Twitch Extension, but it is called as if it was.
  /// This is useful for testing the bits flow without having to actually buy the bits.
  /// Unfortunately, this does not create a valid BitsTransactionObject.
  void setUseLoopback(bool useLoopBack) =>
      getTwitchJsExtensionBits.setUseLoopback(useLoopBack);

  ///
  /// This method uses bits
  void useBits(String sku) => getTwitchJsExtensionBits.useBits(sku);
}

class TwtichJsExtensionViewer {
  ///
  /// The opaque id of the viewer
  String get opaqueId => getTwitchJsExtensionViewer.opaqueId;

  ///
  /// The id of the viewer (null if the access was not granted)
  String? get id => getTwitchJsExtensionViewer.id;
}
