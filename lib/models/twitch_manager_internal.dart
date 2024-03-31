import 'package:flutter/foundation.dart';
import 'package:twitch_manager/models/twitch_api.dart';
import 'package:twitch_manager/models/twitch_authenticator.dart';
import 'package:twitch_manager/models/twitch_events.dart';
import 'package:twitch_manager/models/twitch_chat.dart';
import 'package:twitch_manager/models/twitch_listener.dart';
import 'package:twitch_manager/models/twitch_mock_options.dart';
import 'package:twitch_manager/twitch_app_info.dart';

///
/// Finalizer of the chat, so it frees the Socket
final Finalizer<TwitchChat> _finalizerTwitchChat =
    Finalizer((twitchChat) => twitchChat.disconnect());

class TwitchManager {
  ///
  /// If the streamer is connected
  bool get isStreamerConnected => _authenticator.isStreamerConnected;

  ///
  /// If the streamer is connected
  bool get isChatbotConnected => _authenticator.isChatbotConnected;

  ///
  /// If all the necessary users are connected and the API and chat are initialized
  bool get isConnected => _isConnected;

  ///
  /// If the events are connected
  bool get isEventConnected => _events?.isConnected ?? false;

  ///
  /// Get a reference to the twitch chat
  TwitchChat get chat {
    if (!_appInfo.needChat) {
      throw 'The app must define at least one TwitchScope with a ScopeType.chat '
          'to use the chat.';
    }

    if (!_isConnected) {
      throw 'Twitch chat necessitate the user to be connected';
    }
    return _chat!;
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
  /// Get a reference to the events API
  TwitchEvents get events {
    if (!_appInfo.hasEvents) {
      throw 'The app must define at least one TwitchScope with a ScopeType.events '
          'to use the events.';
    }

    if (!_isConnected) {
      throw 'events necessitate the user to be connected';
    }
    return _events!;
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

    // Connect to the chat
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
  /// Disconnect and clean the saved OAUTH keys
  Future<void> disconnect() async {
    await _chat?.disconnect();
    await _events?.disconnect();
    await _authenticator.disconnect();

    // Notify the user that the manager has disconnected
    onHasDisconnected.forEach((callback) => callback());
  }

  ///
  /// Callbacks to inform the user when something changes internally
  ///
  final onHasDisconnected = TwitchGenericListener();

  ///
  /// ATTRIBUTES
  final TwitchAppInfo _appInfo;
  final TwitchAuthenticator _authenticator;
  TwitchChat? _chat;
  TwitchApi? _api;
  TwitchEvents? _events;
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

    final streamerLogin = await _api!.login(_api!.streamerId);
    if (streamerLogin == null) return;

    // Connect to the TwitchEvent
    if (_appInfo.hasEvents) {
      // Define the _events only once
      _events ??= await TwitchEvents.factory(
          appInfo: _appInfo, authenticator: _authenticator, api: _api!);
    }

    // Connect the TwitchChat
    if (_appInfo.needChat) {
      // If we are not ready yet, just return now
      if (!_authenticator.isChatbotConnected) return;

      _chat = await TwitchChat.factory(
          streamerLogin: streamerLogin, authenticator: _authenticator);

      if (!kIsWeb) _finalizerTwitchChat.attach(this, _chat!, detach: this);
    }

    // Mark the Manager as being fully ready
    _isConnected = true;
  }
}

class TwitchManagerMock extends TwitchManager {
  TwitchDebugPanelOptions debugPanelOptions;

  @override
  bool get isStreamerConnected => true;

  @override
  bool get isChatbotConnected => true;

  @override
  TwitchChatMock get chat {
    if (!_isConnected) {
      throw 'Twitch chat necessitate the user to be connected';
    }
    return _chat! as TwitchChatMock;
  }

  @override
  TwitchApiMock get api {
    if (!_isConnected) {
      throw 'api necessitate the user to be connected';
    }
    return _api! as TwitchApiMock;
  }

  @override
  TwitchEventsMock get events {
    if (!_isConnected) {
      throw 'events necessitate the user to be connected';
    }
    return _events! as TwitchEventsMock;
  }

  /// Main constructor for the TwitchManager.
  /// [appInfo] is all the required information of the current app
  /// [loadPreviousSession] uses credidential from previous session if set to true.
  /// It requires new credidentials otherwise.
  /// [debugPanelOptions] is all the user defined options for the mocking
  static Future<TwitchManagerMock> factory({
    required TwitchAppInfo appInfo,
    TwitchDebugPanelOptions? debugPanelOptions,
  }) async {
    return TwitchManagerMock._(
        appInfo, debugPanelOptions ?? TwitchDebugPanelOptions());
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
  TwitchManagerMock._(TwitchAppInfo appInfo, this.debugPanelOptions)
      : super._(appInfo, TwitchAuthenticatorMock()) {
    _connectToTwitchBackend();
  }

  ///
  /// Initialize the connexion with twitch for all the relevent users
  ///
  @override
  Future<void> _connectToTwitchBackend() async {
    // Connect the API
    _api ??= await TwitchApiMock.factory(
        appInfo: _appInfo,
        authenticator: _authenticator as TwitchAuthenticatorMock,
        debugPanelOptions: debugPanelOptions);

    final streamerLogin = await _api!.login(_api!.streamerId);
    if (streamerLogin == null) return;

    // Connect to the chat
    _chat = await TwitchChatMock.factory(
        streamerLogin: streamerLogin,
        authenticator: _authenticator as TwitchAuthenticatorMock);
    if (!kIsWeb) {
      _finalizerTwitchChat.attach(this, _chat!, detach: this);
    }

    // Connect to the TwitchEvents
    _events ??= await TwitchEventsMock.factory(
        appInfo: _appInfo,
        authenticator: _authenticator as TwitchAuthenticatorMock,
        api: _api as TwitchApiMock,
        debugPanelOptions: debugPanelOptions);

    // Mark the Manager as being ready
    _isConnected = true;
  }
}
