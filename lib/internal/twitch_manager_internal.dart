import 'twitch_api.dart';
import '../twitch_app_info.dart';
import 'twitch_authenticator.dart';
import 'twitch_irc.dart';

///
/// Finalizer of the IRC, so it frees the Socket
final Finalizer<TwitchIrc> _finalizerIrc = Finalizer((irc) => irc.disconnect());

class TwitchManager {
  ///
  /// If the streamer is connected
  bool get isStreamerConnected => _authenticator!.isStreamerConnected;

  ///
  /// If the streamer is connected
  bool get isChatbotConnected => _authenticator!.isChatbotConnected;

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
    await _authenticator!.connectStreamer(
        appInfo: _appInfo, onRequestBrowsing: onRequestBrowsing);
    await _connectToTwitchBackend();
  }

  ///
  /// Entry point for connecting a chatbot to Twitch
  ///
  Future<void> connectChatbot({
    required Future<void> Function(String address)? onRequestBrowsing,
  }) async {
    await _authenticator!.connectChatbot(
        appInfo: _appInfo, onRequestBrowsing: onRequestBrowsing);
    await _connectToTwitchBackend();
  }

  ///
  /// ATTRIBUTES
  final TwitchAppInfo _appInfo;
  final TwitchAuthenticator? _authenticator;
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
    if (!_authenticator!.isStreamerConnected) return;
    // Connect the API
    _api ??= await TwitchApi.factory(
        appInfo: _appInfo, authenticator: _authenticator!);

    final streamerLogin = await _api!.login(_api!.streamerId);
    if (streamerLogin == null) return;

    // Connect the IRC
    if (_appInfo.hasChatbot) {
      if (!_authenticator!.isChatbotConnected) return; // Failed
      _irc = await TwitchIrc.factory(
          streamerLogin: streamerLogin, authenticator: _authenticator!);
      _finalizerIrc.attach(_irc!, _irc!, detach: _irc);
    }

    // Mark the Manager as being ready
    _isConnected = true;
  }
}

class TwitchManagerMock extends TwitchManager {
  ///
  /// If the streamer is connected
  @override
  bool get isStreamerConnected => true;

  ///
  /// If the streamer is connected
  @override
  bool get isChatbotConnected => true;

  ///
  /// If all the necessary users are connected and the API and IRC are initialized
  @override
  bool get isConnected => true;

  ///
  /// Get a reference to the twitch IRC
  @override
  TwitchIrcMock get irc {
    if (!_isConnected) {
      throw 'irc necessitate the user to be connected';
    }
    return _irc! as TwitchIrcMock;
  }

  ///
  /// Get a reference to the twitch API
  @override
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
  static Future<TwitchManagerMock> factory({
    required TwitchAppInfo appInfo,
    bool loadPreviousSession = true,
  }) async {
    return TwitchManagerMock._(appInfo);
  }

  @override
  Future<void> connectStreamer(
      {required Future<void> Function(String address)?
          onRequestBrowsing}) async {
    await _connectToTwitchBackend();
  }

  ///
  /// Entry point for connecting a chatbot to Twitch
  ///
  @override
  Future<void> connectChatbot({
    required Future<void> Function(String address)? onRequestBrowsing,
  }) async {
    await _connectToTwitchBackend();
  }

  ///
  /// Main constructor of the Twitch Manager
  TwitchManagerMock._(TwitchAppInfo appInfo) : super._(appInfo, null) {
    _connectToTwitchBackend();
  }

  ///
  /// Initialize the connexion with twitch for all the relevent users
  ///
  @override
  Future<void> _connectToTwitchBackend() async {
    // Connect the API
    _api ??= await TwitchApiMock.factory(appInfo: _appInfo);

    final streamerLogin = await _api!.login(_api!.streamerId);
    if (streamerLogin == null) return;

    // Connect the IRC
    _irc = await TwitchIrcMock.factory(streamerLogin: streamerLogin);
    _finalizerIrc.attach(_irc!, _irc!, detach: _irc);

    // Mark the Manager as being ready
    _isConnected = true;
  }
}
