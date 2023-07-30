import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../twitch_app_info.dart';
import 'twitch_api.dart';

class TwitchAuthenticator {
  ///
  /// If the streamer is connected
  bool get isStreamerConnected => _isStreamerConnected;

  ///
  /// If the chatbot is connected
  bool get isChatbotConnected => _isChatbotConnected;

  ///
  /// Helper to load a saved file
  Future<void> loadPreviousSession({required TwitchAppInfo appInfo}) async {
    const storage = FlutterSecureStorage();
    streamerOauthKey = await storage.read(key: 'streamerOauthKey');
    chatbotOauthKey = await storage.read(key: 'chatbotOauthKey');
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
    // if it is already connected, we are already done
    if (_isStreamerConnected) return true;

    _isStreamerConnected = await _connectUser(
      appInfo: appInfo,
      onRequestBrowsing: onRequestBrowsing,
      getOauthKey: () => streamerOauthKey,
      setOauthKey: (value) => streamerOauthKey = value,
      chatOnly: false,
    );

    _saveSessions(appInfo: appInfo);
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
    if (_isChatbotConnected) return true;

    _isChatbotConnected = await _connectUser(
      appInfo: appInfo,
      onRequestBrowsing: onRequestBrowsing,
      getOauthKey: () => chatbotOauthKey,
      setOauthKey: (value) => chatbotOauthKey = value,
      chatOnly: true,
    );

    _saveSessions(appInfo: appInfo);
    return _isChatbotConnected;
  }

  /// ATTRIBUTES
  String? streamerOauthKey; // Streamer OAuth key
  String? chatbotOauthKey; // Chatbot OAuth key

  bool _isStreamerConnected = false;
  bool _isChatbotConnected = false;

  ///
  /// Constructor of the Authenticator
  TwitchAuthenticator();

  Future<void> _saveSessions({required TwitchAppInfo appInfo}) async {
    const storage = FlutterSecureStorage();
    storage.write(key: 'streamerOauthKey', value: streamerOauthKey);
    storage.write(key: 'chatbotOauthKey', value: chatbotOauthKey);
  }

  ///
  /// Main method that connect a user to the twitch API.
  /// [appInfo] holds all the necessary information on the stream.
  /// [onRequestBrowsing] is the callback that authenticate through web browers.
  /// If it is not provided, then _connectUser only tries to validate the current
  /// OAuth key. If there is none, it simply returns.
  /// [getOauthKey] Callback to the current OAuth key of the user.
  /// [setOauthKey] Callback to set the OAuth key of the user.
  /// [chatOnly] if the user is the chatbot.
  /// If [tryNewOauthKey] is false, then only the validation is performed, otherwise
  /// a new Oauth key is generated
  Future<bool> _connectUser({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String address)? onRequestBrowsing,
    required String? Function() getOauthKey,
    required void Function(String oauthKey) setOauthKey,
    required bool chatOnly,
    bool tryNewOauthKey = true,
  }) async {
    bool isConnected = false;

    // Try to validate the current OAuth key
    if (getOauthKey() != null) {
      isConnected = await TwitchApi.validateOauthToken(
          appInfo: appInfo, oauthKey: getOauthKey()!);
    }

    if (!isConnected) {
      if (!tryNewOauthKey || onRequestBrowsing == null) return false;

      // Get a new OAuth key
      setOauthKey(await TwitchApi.getNewOauth(
          appInfo: appInfo,
          onRequestBrowsing: onRequestBrowsing,
          chatOnly: chatOnly));

      // Try to reconnect, but only once [retry = false]
      return _connectUser(
        appInfo: appInfo,
        onRequestBrowsing: onRequestBrowsing,
        getOauthKey: getOauthKey,
        setOauthKey: setOauthKey,
        chatOnly: chatOnly,
        tryNewOauthKey: false,
      );
    }

    // If we are indeed connected, we have to validate the OAuth key every hour
    Timer.periodic(const Duration(hours: 1), (timer) async {
      if (!await TwitchApi.validateOauthToken(
          appInfo: appInfo, oauthKey: getOauthKey()!)) {
        // If it fails, restart the connecting process
        timer.cancel();
        _connectUser(
          appInfo: appInfo,
          onRequestBrowsing: onRequestBrowsing,
          getOauthKey: getOauthKey,
          setOauthKey: setOauthKey,
          chatOnly: chatOnly,
        );
      }
    });

    return true;
  }
}
