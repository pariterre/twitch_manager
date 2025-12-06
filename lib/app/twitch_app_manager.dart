import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:twitch_manager/abstract/twitch_authenticator.dart';
import 'package:twitch_manager/abstract/twitch_manager.dart';
import 'package:twitch_manager/app/twitch_app_api.dart';
import 'package:twitch_manager/app/twitch_app_chat.dart';
import 'package:twitch_manager/app/twitch_app_info.dart';
import 'package:twitch_manager/app/twitch_events.dart';
import 'package:twitch_manager/app/twitch_mock_options.dart';
import 'package:twitch_manager/utils/twitch_listener.dart';

final _logger = Logger('TwitchAppManager');

///
/// Finalizer of the chat, so it frees the Socket
final Finalizer<TwitchAppChat> _finalizerTwitchChat =
    Finalizer((twitchChat) => twitchChat.disconnect());

class TwitchAppManager implements TwitchManager {
  final TwitchAppInfo _appInfo;
  @override
  TwitchAppInfo get appInfo => _appInfo;

  final TwitchAppAuthenticator _authenticator;
  @override
  TwitchAppAuthenticator get authenticator => _authenticator;

  ///
  /// A reference to the chat of the stream
  TwitchAppChat? _chat;
  TwitchAppChat get chat {
    if (!appInfo.needChat) {
      throw 'The app must define at least one TwitchScope with a ScopeType.chat '
          'to use the chat.';
    }

    if (!_isConnected) {
      throw 'Twitch chat necessitate the user to be connected';
    }
    return _chat!;
  }

  ///
  /// A reference to the API of the stream
  TwitchAppApi? _api;
  TwitchAppApi get api {
    if (!_isConnected) {
      throw 'api necessitate the user to be connected';
    }
    return _api!;
  }

  ///
  /// A reference to the events API
  TwitchEvents? _events;
  bool get isEventConnected => _events?.isConnected ?? false;
  TwitchEvents get events {
    if (!appInfo.hasEvents) {
      throw 'The app must define at least one TwitchScope with a ScopeType.events '
          'to use the events.';
    }

    if (!_isConnected) {
      throw 'events necessitate the user to be connected';
    }
    return _events!;
  }

  ///
  /// If the streamer is connected
  bool get isStreamerConnected => authenticator.isConnected;

  ///
  /// If the streamer is connected
  bool get isChatbotConnected => authenticator.isChatbotConnected;

  ///
  /// If all the necessary users are connected and the API and chat are initialized
  bool _isConnected = false;
  @override
  bool get isConnected => _isConnected;
  @override
  bool get isNotConnected => !_isConnected;

  ///
  /// Internal constructor of the Twitch Manager
  TwitchAppManager._(this._appInfo, this._authenticator);

  /// Main constructor for the TwitchAppManager.
  /// [appInfo] is all the required information of the current app.
  /// [reload] load (or not) a previous session.
  /// [saveKeySuffix] can be added to the reload flag so a specific user can be
  /// loaded. This can be useful if many users are registered via multiple
  /// instances of TwitchManager in a single app. If [reload] if false,
  /// this parameter has no effect, as the session is not loaded.
  static Future<TwitchAppManager> factory({
    required TwitchAppInfo appInfo,
    bool reload = true,
    String? saveKeySuffix,
  }) async {
    _logger.config('Creating the manager to the Twitch connexion...');

    final authenticator = TwitchAppAuthenticator(saveKeySuffix: saveKeySuffix);

    if (reload) {
      await authenticator.loadSession();
    }

    final manager = TwitchAppManager._(appInfo, authenticator);

    // Connect to the chat
    if (authenticator.bearerKey != null) await manager.connect();
    if (authenticator.chatbotBearerKey != null) await manager.connectChatbot();

    // Despite being called by the streamer and bot, just make sure by calling
    // it again here (mostly for connecting twitch events)
    await manager._connectToTwitchBackend();

    if (manager.isConnected) {
      manager.onHasConnected.notifyListeners((callback) => callback());
      _logger.config('Manager is ready to be used');
    }
    return manager;
  }

  ///
  /// Entry point for connecting a chatbot to Twitch
  ///
  @override
  Future<void> connect({
    Future<void> Function(String address)? onRequestBrowsing,
  }) async {
    _logger.info('Connecting streamer to Twitch...');

    await authenticator.connect(
        appInfo: appInfo, onRequestBrowsing: onRequestBrowsing);
    await _connectToTwitchBackend();

    _logger
        .info('Streamer is ${_isConnected ? '' : 'not '}connected to Twitch');
  }

  ///
  /// Entry point for connecting a chatbot to Twitch
  ///
  Future<void> connectChatbot({
    Future<void> Function(String address)? onRequestBrowsing,
  }) async {
    _logger.info('Connecting chatbot to Twitch...');

    await _authenticator.connectChatbot(
        appInfo: appInfo, onRequestBrowsing: onRequestBrowsing);
    await _connectToTwitchBackend();

    _logger.info('Chatbot is connected to Twitch');
  }

  @override
  final onHasConnected = TwitchListener<Function()>();

  ///
  /// Disconnect and clean the saved OAUTH keys
  @override
  Future<void> disconnect() async {
    _logger.info('Disconnecting from Twitch...');

    await _chat?.disconnect();
    await _events?.disconnect();
    await _authenticator.disconnect();
    _isConnected = false;

    // Notify the user that the manager has disconnected
    onHasDisconnected.notifyListeners((callback) => callback());

    _logger.info('Disconnected from Twitch');
  }

  @override
  final onHasDisconnected = TwitchListener<Function()>();

  ///
  /// Formally initialize the connexion with Twitch for all the relevent services
  ///
  Future<void> _connectToTwitchBackend() async {
    _logger.config('Connecting to Twitch backend...');

    if (!_authenticator.isConnected) {
      _logger.warning('Streamer is not connected, cannot proceed');
      return;
    }

    // Connect the API
    _api ??= await TwitchAppApi.factory(
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

      _chat = await TwitchAppChat.factory(
          streamerLogin: streamerLogin, authenticator: _authenticator);

      if (!kIsWeb) _finalizerTwitchChat.attach(this, _chat!, detach: this);
    }

    // Mark the Manager as being fully ready
    _isConnected = true;

    _logger.config('Connected to Twitch backend');
  }
}

class TwitchAppManagerMock extends TwitchAppManager {
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
  TwitchAppApiMock get api {
    if (!_isConnected) {
      throw 'api necessitate the user to be connected';
    }
    return _api! as TwitchAppApiMock;
  }

  @override
  TwitchEventsMock get events {
    if (!_isConnected) {
      throw 'events necessitate the user to be connected';
    }
    return _events! as TwitchEventsMock;
  }

  ///
  /// Main constructor of the Twitch Manager
  TwitchAppManagerMock._(TwitchAppInfo appInfo, this.debugPanelOptions)
      : super._(appInfo, TwitchAppAuthenticatorMock());

  /// Main constructor for the TwitchManager.
  /// [appInfo] is all the required information of the current app
  /// [loadPreviousSession] uses credidential from previous session if set to true.
  /// It requires new credidentials otherwise.
  /// [debugPanelOptions] is all the user defined options for the mocking
  static Future<TwitchAppManagerMock> factory({
    required TwitchAppInfo appInfo,
    TwitchDebugPanelOptions? debugPanelOptions,
  }) async {
    final instance = TwitchAppManagerMock._(
        appInfo, debugPanelOptions ?? TwitchDebugPanelOptions());
    await instance._connectToTwitchBackend();
    return instance;
  }

  @override
  Future<void> connect({
    Future<void> Function(String address)? onRequestBrowsing,
  }) async {
    await _connectToTwitchBackend();
  }

  ///
  /// Entry point for connecting a chatbot to Twitch
  ///
  @override
  Future<void> connectChatbot({
    Future<void> Function(String address)? onRequestBrowsing,
  }) async {
    await _connectToTwitchBackend();
  }

  ///
  /// Initialize the connexion with twitch for all the relevent users
  ///
  @override
  Future<void> _connectToTwitchBackend() async {
    // Connect the API
    _api ??= await TwitchAppApiMock.factory(
        appInfo: _appInfo,
        authenticator: _authenticator,
        debugPanelOptions: debugPanelOptions);

    final streamerLogin = await _api!.login(_api!.streamerId);
    if (streamerLogin == null) return;

    // Connect to the chat
    _chat = await TwitchChatMock.factory(
      streamerLogin: streamerLogin,
      authenticator: _authenticator as TwitchAppAuthenticatorMock,
    );
    if (!kIsWeb) {
      _finalizerTwitchChat.attach(this, _chat!, detach: this);
    }

    // Connect to the TwitchEvents
    if (_appInfo.hasEvents) {
      _events ??= await TwitchEventsMock.factory(
          appInfo: _appInfo,
          authenticator: _authenticator,
          api: _api as TwitchAppApiMock,
          debugPanelOptions: debugPanelOptions);
    }

    // Mark the Manager as being ready
    _isConnected = true;
  }
}
