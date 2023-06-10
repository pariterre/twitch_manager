import 'twitch_api.dart';
import 'twitch_app_info.dart';
import 'twitch_authenticator.dart';
import 'twitch_irc.dart';

export 'twitch_authentication_screen.dart';
export 'twitch_scope.dart';

class TwitchManager {
  ///
  /// If the streamer is connected
  bool get isStreamerConnected => _authenticator.isStreamerConnected;

  ///
  /// If the streamer is connected
  bool get isChatbotConnected => _authenticator.isChatbotConnected;

  ///
  /// If all the necessary users are connected and the API and IRC are initialized
  bool get isConnected => _isConnected;

  ///
  /// Get a reference to the twitch IRC
  TwitchIrc get irc {
    if (!_isConnected) {
      throw 'irc necessitate the user to be connected';
    }
    return _irc!;
  }

  ///
  /// Get a reference to the twitch API
  TwitchApi get api {
    if (!_isConnected) {
      throw 'api necessitate the user to be connected';
    }
    return _api!;
  }

  /// Main constructor for the TwitchManager.
  /// [appInfo] is all the required information of the current app
  /// [loadPreviousSession] uses credidential from previous session if set to true.
  /// It requires new credidentials otherwise
  static Future<TwitchManager> factory({
    required TwitchAppInfo appInfo,
    bool loadPreviousSession = true,
  }) async {
    final authenticator = TwitchAuthenticator();

    if (loadPreviousSession) {
      await authenticator.loadPreviousSession(appInfo: appInfo);
    }

    final manager = TwitchManager._(appInfo, authenticator);
    if (authenticator.streamerOauthKey != null) {
      await manager.connectStreamer(onRequestBrowsing: null);
    }
    if (authenticator.chatbotOauthKey != null) {
      await manager.connectChatbot(onRequestBrowsing: null);
    }

    return manager;
  }

  ///
  /// Entry point for connecting a streamer to Twitch
  ///
  Future<void> connectStreamer(
      {required Future<void> Function(String address)?
          onRequestBrowsing}) async {
    await _authenticator.connectStreamer(
        appInfo: _appInfo, onRequestBrowsing: onRequestBrowsing);
    await _connectToTwitchBackend();
  }

  ///
  /// Entry point for connecting a chatbot to Twitch
  ///
  Future<void> connectChatbot({
    required Future<void> Function(String address)? onRequestBrowsing,
  }) async {
    await _authenticator.connectChatbot(
        appInfo: _appInfo, onRequestBrowsing: onRequestBrowsing);
    await _connectToTwitchBackend();
  }

  ///
  /// ATTRIBUTES
  final TwitchAppInfo _appInfo;
  final TwitchAuthenticator _authenticator;
  TwitchIrc? _irc;
  TwitchApi? _api;
  bool _isConnected = false;

  ///
  /// Main constructor of the Twitch Manager
  TwitchManager._(this._appInfo, this._authenticator);

  ///
  /// Initialize the connexion with twitch for all the relevent users
  ///
  Future<void> _connectToTwitchBackend() async {
    if (!_authenticator.isStreamerConnected) return;
    // Connect the API
    _api ??= await TwitchApi.factory(
        appInfo: _appInfo, authenticator: _authenticator);

    // Connect the IRC
    if (_appInfo.hasChatbot && !_authenticator.isChatbotConnected) return;
    _irc = await TwitchIrc.factory(
        streamerLogin: (await _api!.login(_api!.streamerId))!,
        authenticator: _authenticator);
    _finalizerIrc.attach(_irc!, _irc!, detach: _irc);

    // Mark the Manager as being ready
    _isConnected = true;
  }

  ///
  /// Finalizer of the IRC, so it frees the Socket
  static final Finalizer<TwitchIrc> _finalizerIrc =
      Finalizer((irc) => irc.disconnect());
}
