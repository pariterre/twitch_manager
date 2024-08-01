import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:twitch_manager/models/twitch_api.dart';
import 'package:twitch_manager/twitch_app_info.dart';

final _logger = Logger('TwitchAuthenticator');

class TwitchAuthenticator {
  ///
  /// If the streamer is connected
  bool get isStreamerConnected => _isStreamerConnected;

  ///
  /// If the chatbot is connected
  bool get isChatbotConnected => _isChatbotConnected;

  ///
  /// Helper to load a saved file.
  /// It is saved with the specified [saveKey] suffix so it can be later
  /// reloaded. If none is provided, then it is saved in a generic fashion.
  Future<void> loadSession({required TwitchAppInfo appInfo}) async {
    _logger.config('Loading session with saveKey: $saveKey');

    const storage = FlutterSecureStorage();
    streamerOauthKey = await storage.read(key: 'streamerOauthKey$saveKey');
    chatbotOauthKey = await storage.read(key: 'chatbotOauthKey$saveKey');

    streamerOauthKey = streamerOauthKey != null && streamerOauthKey!.isEmpty
        ? null
        : streamerOauthKey;
    chatbotOauthKey = chatbotOauthKey != null && chatbotOauthKey!.isEmpty
        ? null
        : chatbotOauthKey;

    _logger.config(
        'Streamer OAuth key could {${streamerOauthKey != null ? '' : 'not'}} be loaded');
    _logger.config(
        'Chatbot OAuth key could {${chatbotOauthKey != null ? '' : 'not'}} be loaded');
  }

  Future<void> clearHistory() async {
    _logger.info('Clearing OAuth keys');
    const storage = FlutterSecureStorage();
    await storage.write(key: 'streamerOauthKey$saveKey', value: '');
    await storage.write(key: 'chatbotOauthKey$saveKey', value: '');
  }

  ///
  /// Entry point to connect the streamer to the twitch API.
  /// [appInfo] holds all the necessary information on the stream.
  /// [onRequestBrowsing] is the callback that authenticate through web browers.
  /// If it is not provided, then connectStreamer only tries to validate the current
  /// OAuth key. If there is none, it simply returns.
  /// If [tryNewOauthKey] is false, then only the validation is performed, otherwise
  /// a new Oauth key is generated
  Future<bool> connectStreamer({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String address)? onRequestBrowsing,
    bool tryNewOauthKey = true,
  }) async {
    _logger.info('Connecting streamer to Twitch');

    // if it is already connected, we are already done
    if (_isStreamerConnected) {
      _logger.warning('Streamer is already connected');
      return true;
    }

    _isStreamerConnected = await _connectUser(
      appInfo: appInfo,
      onRequestBrowsing: onRequestBrowsing,
      getOauthKey: () => streamerOauthKey,
      setOauthKey: (value) => streamerOauthKey = value,
    );

    if (appInfo.needChat && !appInfo.hasChatbot) {
      // If we need the chat, but not the chatbot, then we connect the streamer
      // to the chat
      _isChatbotConnected = true;
    }

    _saveSessions(appInfo: appInfo);

    _logger.info('Streamer is ${_isStreamerConnected ? '' : 'not'} connected');
    return _isStreamerConnected;
  }

  ///
  /// Entry point to connect the chatbot to the twitch API.
  /// [appInfo] holds all the necessary information on the stream.
  /// [onRequestBrowsing] is the callback that authenticate through web browers.
  /// If it is not provided, then connectStreamer only tries to validate the current
  /// OAuth key. If there is none, it simply returns.
  /// If [tryNewOauthKey] is false, then only the validation is performed, otherwise
  /// a new Oauth key is generated
  Future<bool> connectChatbot({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String address)? onRequestBrowsing,
    bool tryNewOauthKey = true,
  }) async {
    _logger.info('Connecting chatbot to Twitch');

    // if it is already connected, we are already done
    if (_isChatbotConnected) {
      _logger.warning('Chatbot is already connected');
      return true;
    }

    _isChatbotConnected = await _connectUser(
      appInfo: appInfo,
      onRequestBrowsing: onRequestBrowsing,
      getOauthKey: () => chatbotOauthKey,
      setOauthKey: (value) => chatbotOauthKey = value,
    );

    _saveSessions(appInfo: appInfo);

    _logger.info('Chatbot is ${_isChatbotConnected ? '' : 'not'} connected');
    return _isChatbotConnected;
  }

  ///
  /// Disconnect user from Twitch and clear the reload history
  Future<void> disconnect() async {
    _logger.info('Disconnecting from Twitch');
    streamerOauthKey = null;
    chatbotOauthKey = null;
    _isStreamerConnected = false;
    _isChatbotConnected = false;
    // Prevent from being able to reload
    await clearHistory();
  }

  /// ATTRIBUTES
  final String? saveKey;

  String? streamerOauthKey; // Streamer OAuth key
  String? chatbotOauthKey; // Chatbot OAuth key

  bool _isStreamerConnected = false;
  bool _isChatbotConnected = false;

  ///
  /// Constructor of the Authenticator
  TwitchAuthenticator({this.saveKey = ''});

  ///
  /// Save a session for further reloading.
  /// It is saved with the specified [saveKey] suffix which can be used to
  /// reload a specific session.
  Future<void> _saveSessions({required TwitchAppInfo appInfo}) async {
    _logger.config('Saving OAuth keys');
    const storage = FlutterSecureStorage();
    storage.write(key: 'streamerOauthKey$saveKey', value: streamerOauthKey);
    storage.write(key: 'chatbotOauthKey$saveKey', value: chatbotOauthKey);
  }

  ///
  /// Main method that connect a user to the twitch API.
  /// [appInfo] holds all the necessary information on the stream.
  /// [onRequestBrowsing] is the callback that authenticate through web browers.
  /// If it is not provided, then _connectUser only tries to validate the current
  /// OAuth key. If there is none, it simply returns.
  /// [getOauthKey] Callback to the current OAuth key of the user.
  /// [setOauthKey] Callback to set the OAuth key of the user.
  /// If [tryNewOauthKey] is false, then only the validation is performed, otherwise
  /// a new Oauth key is generated
  Future<bool> _connectUser({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String address)? onRequestBrowsing,
    required String? Function() getOauthKey,
    required void Function(String oauthKey) setOauthKey,
    bool tryNewOauthKey = true,
  }) async {
    _logger.info('Connecting user to Twitch...');

    bool isConnected = false;

    // Try to validate the current OAuth key
    if (getOauthKey() != null) {
      isConnected = await TwitchApi.validateOauthToken(
          appInfo: appInfo, oauthKey: getOauthKey()!);
      _logger.info('OAuth key is ${isConnected ? '' : 'not'} valid');
    }

    if (!isConnected) {
      if (!tryNewOauthKey || onRequestBrowsing == null) {
        _logger.severe('Could not connect to Twitch');
        return false;
      }

      _logger.info('Requesting new OAuth key');
      // Get a new OAuth key
      final oauthKey = await TwitchApi.getNewOauth(
          appInfo: appInfo, onRequestBrowsing: onRequestBrowsing);
      if (oauthKey == null) return false;
      setOauthKey(oauthKey);

      // Try to reconnect, but only once [retry = false]
      return _connectUser(
        appInfo: appInfo,
        onRequestBrowsing: onRequestBrowsing,
        getOauthKey: getOauthKey,
        setOauthKey: setOauthKey,
        tryNewOauthKey: false,
      );
    }

    // If we are indeed connected, we have to validate the OAuth key every hour
    Timer.periodic(const Duration(hours: 1), (timer) async {
      _logger.info('Validating OAuth key...');

      final key = getOauthKey();
      if (key == null) {
        _logger.warning('User has disconnected, stop validating the OAuth key');
        timer.cancel();
        return;
      }
      if (!await TwitchApi.validateOauthToken(
          appInfo: appInfo, oauthKey: key)) {
        // If it fails, restart the connecting process
        _logger.warning('OAuth key is not valid, requesting new OAuth key');
        timer.cancel();
        _connectUser(
          appInfo: appInfo,
          onRequestBrowsing: onRequestBrowsing,
          getOauthKey: getOauthKey,
          setOauthKey: setOauthKey,
        );
      }

      _logger.info('OAuth key is valid');
    });

    _logger.info('User is connected to Twitch');
    return true;
  }
}

class TwitchAuthenticatorMock extends TwitchAuthenticator {
  TwitchAuthenticatorMock({super.saveKey = null});

  @override
  Future<bool> connectStreamer({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String address)? onRequestBrowsing,
    bool tryNewOauthKey = true,
  }) async {
    streamerOauthKey = 'streamerOauthKey';
    _isStreamerConnected = true;
    return true;
  }

  @override
  Future<bool> connectChatbot({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String address)? onRequestBrowsing,
    bool tryNewOauthKey = true,
  }) async {
    chatbotOauthKey = 'chatbotOauthKey';
    _isChatbotConnected = true;
    return true;
  }
}
