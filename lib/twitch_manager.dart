import 'package:twitch_manager/twitch_app_info.dart';

import 'twitch_api.dart';
import 'twitch_irc.dart';
import 'twitch_user.dart';

export 'twitch_api.dart';
export 'twitch_authentication_screen.dart';
export 'twitch_irc.dart';
export 'twitch_manager.dart';
export 'twitch_scope.dart';
export 'twitch_user.dart';

class TwitchManager {
  final TwitchAppInfo appInfo;
  final TwitchAuthenticator _user;

  bool _isInitialized = false;
  TwitchIrc? _irc;
  TwitchApi? _api;

  bool get isInitialized => _isInitialized;
  TwitchIrc get irc {
    if (!_isInitialized) {
      throw 'irc necessitate the user to be connected';
    }
    return _irc!;
  }

  TwitchApi get api {
    if (!_isInitialized) {
      throw 'api necessitate the user to be connected';
    }
    return _api!;
  }

  TwitchManager._(this.appInfo, this._user);

  static Future<TwitchManager> factory(
      {required TwitchAppInfo appInfo, required bool hasChatbot}) async {
    final user = TwitchAuthenticator(
        appInfo: appInfo,
        hasChatbot: hasChatbot,
        onRequestBrowsing: (_) async {});
    await user.loadPreviousSession(appInfo: appInfo);

    return TwitchManager._(appInfo, user);
  }

  Future<void> connectStreamer(
      {required Future<void> Function(String address)
          onRequestBrowsing}) async {
    await _user.connectStreamer(
        appInfo: appInfo, onRequestBrowsing: onRequestBrowsing);
    await connectToTwitchBackend();
  }

  Future<void> connectChatbot({
    required Future<void> Function(String address) onAuthenticationRequest,
    required Future<void> Function(String address) onRequestBrowsing,
  }) async {
    await _user.connectChatbot(
        appInfo: appInfo, onRequestBrowsing: onRequestBrowsing);
    await connectToTwitchBackend();
  }

  ///
  /// Main constructor
  /// [onAuthenticationRequest] is called if the Authentication needs to create a
  /// new OAUTH key. Adress is the address to browse.
  ///
  Future<void> connectToTwitchBackend() async {
    if (!_user.isStreamerConnected) return;
    _api ??= await TwitchApi.factory(appInfo: appInfo, user: _user);

    if (_user.hasChatbot && !_user.isChatbotConnected) return;
    _irc = await TwitchIrc.factory(_user);
    _finalizerIrc.attach(_irc!, _irc!, detach: _irc);

    _isInitialized = true;
  }

  static final Finalizer<TwitchIrc> _finalizerIrc =
      Finalizer((irc) => irc.disconnect());
}
