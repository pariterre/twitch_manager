import 'package:twitch_manager/models/twitch_js_extension/twitch_js_extension_interface.dart'
    if (dart.library.js) 'package:twitch_manager/models/twitch_js_extension/twitch_js_extension_web.dart'
    if (dart.library.io) 'package:twitch_manager/models/twitch_js_extension/twitch_js_extension_desktop.dart';

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
}

class TwtichJsExtensionActions {
  ///
  /// This method requests the ID share from the Twitch Extension. If this is
  /// called, it will pop up a dialog in the Twitch Extension asking the user
  /// to share their ID with the extension. If the user accepts, the extension
  /// will receive the user's ID from now on.
  void requestIdShare() => getTwitchJsExtensionActions.requestIdShare();
}
