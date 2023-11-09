import 'package:flutter/foundation.dart';
import 'package:twitch_manager/models/twitch_api.dart';
import 'package:twitch_manager/models/twitch_authenticator.dart';
import 'package:twitch_manager/models/twitch_events.dart';
import 'package:twitch_manager/models/twitch_irc.dart';
import 'package:twitch_manager/models/twitch_mock_options.dart';
import 'package:twitch_manager/twitch_app_info.dart';

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

  ///
  /// Get a reference to the event API
  TwitchEvent get event {
    if (!_isConnected) {
      throw 'event necessitate the user to be connected';
    }
    return _event!;
  }

  /// Main constructor for the TwitchManager.
  /// [appInfo] is all the required information of the current app.
  /// [reload] load (or not) a previous session.
  /// [saveKey] can be added to the reload flag so a specific user can be
  /// loaded. This can be useful if many users are registered via multiple
  /// instances of TwitchManager in a single app.  If [reload] if false,
  /// this parameter has no effect.
  static Future<TwitchManager> factory({
    required TwitchAppInfo appInfo,
    bool reload = true,
    String? saveKey,
  }) async {
    final authenticator = TwitchAuthenticator(saveKey: saveKey);

    if (reload) {
      await authenticator.loadSession(appInfo: appInfo);
    }

    final manager = TwitchManager._(appInfo, authenticator);

    // Connect to the irc channel
    if (authenticator.streamerOauthKey != null) {
      await manager.connectStreamer(onRequestBrowsing: null);
    }
    if (authenticator.chatbotOauthKey != null) {
      await manager.connectChatbot(onRequestBrowsing: null);
    }

    // Despite being called by the streamer and bot, just make sure by calling
    // it again here (mostly for connecting twitch events)
    await manager._connectToTwitchBackend();

    return manager;
  }

  ///
  /// Entry point for connecting a streamer to Twitch
  ///
  Future<void> connectStreamer({
    required Future<void> Function(String address)? onRequestBrowsing,
  }) async {
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
  /// Disconnect irc and clean the saved OAUTH keys
  Future<void> disconnect() async {
    await _irc?.disconnect();
    await _event?.disconnect();
    await _authenticator?.disconnect();
  }

  ///
  /// ATTRIBUTES
  final TwitchAppInfo _appInfo;
  final TwitchAuthenticator? _authenticator;
  TwitchIrc? _irc;
  TwitchApi? _api;
  TwitchEvent? _event;
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
      if (!kIsWeb) _finalizerIrc.attach(_irc!, _irc!, detach: _irc);
    }

    // Connect to the TwitchEvent
    _event ??= await TwitchEvent.factory(appInfo: _appInfo);

    // Mark the Manager as being ready
    _isConnected = true;
  }
}

class TwitchManagerMock extends TwitchManager {
  TwitchMockOptions mockOptions;

  @override
  bool get isStreamerConnected => true;

  @override
  bool get isChatbotConnected => true;

  @override
  bool get isConnected => true;

  @override
  TwitchIrcMock get irc {
    if (!_isConnected) {
      throw 'irc necessitate the user to be connected';
    }
    return _irc! as TwitchIrcMock;
  }

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
  /// It requires new credidentials otherwise.
  /// [mockOptions] is all the user defined options for the mocking
  static Future<TwitchManagerMock> factory({
    required TwitchAppInfo appInfo,
    required TwitchMockOptions mockOptions,
  }) async {
    return TwitchManagerMock._(appInfo, mockOptions);
  }

  @override
  Future<void> connectStreamer({
    required Future<void> Function(String address)? onRequestBrowsing,
    String? saveKey,
  }) async {
    await _connectToTwitchBackend();
  }

  ///
  /// Entry point for connecting a chatbot to Twitch
  ///
  @override
  Future<void> connectChatbot({
    required Future<void> Function(String address)? onRequestBrowsing,
    String? saveKey,
  }) async {
    await _connectToTwitchBackend();
  }

  ///
  /// Main constructor of the Twitch Manager
  TwitchManagerMock._(TwitchAppInfo appInfo, this.mockOptions)
      : super._(appInfo, null) {
    _connectToTwitchBackend();
  }

  ///
  /// Initialize the connexion with twitch for all the relevent users
  ///
  @override
  Future<void> _connectToTwitchBackend() async {
    // Connect the API
    _api ??= await TwitchApiMock.factory(
        appInfo: _appInfo, mockOptions: mockOptions);

    final streamerLogin = await _api!.login(_api!.streamerId);
    if (streamerLogin == null) return;

    // Connect the IRC
    _irc = await TwitchIrcMock.factory(streamerLogin: streamerLogin);
    if (!kIsWeb) {
      _finalizerIrc.attach(_irc!, _irc!, detach: _irc);
    }

    // Mark the Manager as being ready
    _isConnected = true;
  }
}
