import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:twitch_manager/models/twitch_api.dart';
import 'package:twitch_manager/models/twitch_ebs_api.dart';
import 'package:twitch_manager/models/twitch_info.dart';
import 'package:twitch_manager/models/twitch_java_script/twitch_java_script.dart';
import 'package:twitch_manager/models/twitch_listener.dart';
import 'package:twitch_manager/twitch_manager.dart';

final _logger = Logger('TwitchAuthenticator');

abstract class TwitchAuthenticator {
  ///
  /// The key to save the session
  final String? saveKeySuffix;

  ///
  /// Constructor of the Authenticator
  TwitchAuthenticator({this.saveKeySuffix = ''});

  ///
  /// The user bearer key
  String? _bearerKey;
  String? get bearerKey => _bearerKey;

  ///
  /// If the user is connected
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  ///
  /// Connect user to Twitch
  Future<void> connect({required TwitchInfo appInfo});

  ///
  /// Disconnect user from Twitch and clear the reload history
  Future<void> disconnect() async {
    _logger.info('Disconnecting from Twitch');
    _bearerKey = null;
    _isConnected = false;
    // Prevent from being able to reload
    await clearSession();
  }

  ///
  /// Save a session for further reloading.
  /// It is saved with the specified [saveKeySuffix] suffix which can be used to
  /// reload a specific session.
  Future<void> _saveSessions() async {
    _logger.config('Saving key');
    const storage = FlutterSecureStorage();
    storage.write(key: 'bearer$saveKeySuffix', value: bearerKey);
  }

  ///
  /// Helper to load a saved file.
  /// It is saved with the specified [saveKeySuffix] suffix so it can be later
  /// reloaded. If none is provided, then it is saved in a generic fashion.
  Future<void> loadSession() async {
    _logger.config('Loading session');
    _bearerKey = await _loadSession(key: 'bearer$saveKeySuffix');
  }

  ///
  /// Clear the keys of the saved sessions
  Future<void> clearSession() async {
    _logger.info('Clearing key');
    await _clearSession(key: 'bearer$saveKeySuffix');
  }
}

///
/// The OAuth key is for the "Authorization code grant flow":
/// https://dev.twitch.tv/docs/authentication/getting-tokens-oauth
///
/// As requested by Twitch, the OAuth key is validated every hour.
class TwitchClientAuthenticator extends TwitchAuthenticator {
  ///
  /// Constructor of the Authenticator
  TwitchClientAuthenticator({super.saveKeySuffix = ''});

  ///
  /// The chatbot bearer key
  String? _chatbotBearerKey;
  String? get chatbotBearerKey => _chatbotBearerKey;

  ///
  /// If the chatbot is connected
  bool _isChatbotConnected = false;
  bool get isChatbotConnected => _isChatbotConnected;

  @override
  Future<bool> connect({
    required covariant TwitchAppInfo appInfo,
    Future<void> Function(String address)? onRequestBrowsing,
    bool tryNewOAuthKey = true,
  }) async {
    _logger.info('Connecting streamer to Twitch');

    // if it is already connected, we are already done
    if (_isConnected) {
      _logger.warning('Streamer is already connected');
      return true;
    }

    _isConnected = await _connectUserUsingOAuth(
      appInfo: appInfo,
      onRequestBrowsing: onRequestBrowsing,
      getOAuthKey: () => bearerKey,
      setOAuthKey: (value) => _bearerKey = value,
    );

    if (appInfo.needChat && !appInfo.hasChatbot) {
      // If we need the chat, but not the chatbot, then we connect the streamer
      // to the chat
      _isChatbotConnected = true;
    }

    _saveSessions();

    _logger.info('Streamer is ${_isConnected ? '' : 'not'} connected');
    return _isConnected;
  }

  ///
  /// Entry point to connect the chatbot to the twitch API.
  /// [appInfo] holds all the necessary information on the stream.
  /// [onRequestBrowsing] is the callback that authenticate through web browers.
  /// If it is not provided, then connectStreamer only tries to validate the current
  /// OAuth key. If there is none, it simply returns.
  /// If [tryNewOAuthKey] is false, then only the validation is performed, otherwise
  /// a new OAuth key can be generated
  ///
  /// This method only make sense for App (as opposed to extensions)
  Future<bool> connectChatbot({
    required TwitchAppInfo appInfo,
    Future<void> Function(String address)? onRequestBrowsing,
    bool tryNewOAuthKey = true,
  }) async {
    _logger.info('Connecting chatbot to Twitch');

    // if it is already connected, we are already done
    if (_isChatbotConnected) {
      _logger.warning('Chatbot is already connected');
      return true;
    }

    _isChatbotConnected = await _connectUserUsingOAuth(
      appInfo: appInfo,
      onRequestBrowsing: onRequestBrowsing,
      getOAuthKey: () => chatbotBearerKey,
      setOAuthKey: (value) => _chatbotBearerKey = value,
    );

    _saveSessions();

    _logger.info('Chatbot is ${_isChatbotConnected ? '' : 'not'} connected');
    return _isChatbotConnected;
  }

  ///
  /// Main method that connect a user to the twitch API.
  /// [appInfo] holds all the necessary information on the stream.
  /// [onRequestBrowsing] is the callback that authenticate through web browers.
  /// If it is not provided, then _connectUser only tries to validate the current
  /// OAuth key. If there is none, it simply returns.
  /// [getOAuthKey] Callback to the current OAuth key of the user.
  /// [setOAuthKey] Callback to set the OAuth key of the user.
  /// If [tryNewOAuthKey] is false, then only the validation is performed, otherwise
  /// a new OAuth key can generated
  Future<bool> _connectUserUsingOAuth({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String address)? onRequestBrowsing,
    required String? Function() getOAuthKey,
    required void Function(String oAuthKey) setOAuthKey,
    bool tryNewOAuthKey = true,
  }) async {
    _logger.info('Connecting user to Twitch...');

    bool isConnected = false;

    // Try to validate the current OAuth key
    if (getOAuthKey() != null) {
      isConnected =
          await TwitchClientApi.validateOAuthToken(oAuthKey: getOAuthKey()!);
      _logger.info('OAuth key is ${isConnected ? '' : 'not'} valid');
    }

    if (!isConnected) {
      if (!tryNewOAuthKey || onRequestBrowsing == null) {
        _logger.severe('Could not connect to Twitch');
        return false;
      }

      _logger.info('Requesting new OAuth key');
      // Get a new OAuth key
      final oauthKey = await TwitchClientApi.getNewOAuth(
          appInfo: appInfo, onRequestBrowsing: onRequestBrowsing);
      if (oauthKey == null) return false;
      setOAuthKey(oauthKey);

      // Try to reconnect, but only once [retry = false]
      return _connectUserUsingOAuth(
        appInfo: appInfo,
        onRequestBrowsing: onRequestBrowsing,
        getOAuthKey: getOAuthKey,
        setOAuthKey: setOAuthKey,
        tryNewOAuthKey: false,
      );
    }

    // If we are indeed connected, we have to validate the OAuth key every hour
    Timer.periodic(const Duration(hours: 1), (timer) async {
      _logger.info('Validating OAuth key...');

      final key = getOAuthKey();
      if (key == null) {
        _logger.warning('User has disconnected, stop validating the OAuth key');
        timer.cancel();
        return;
      }
      if (!await TwitchClientApi.validateOAuthToken(oAuthKey: key)) {
        // If it fails, restart the connecting process
        _logger.warning('OAuth key is not valid, requesting new OAuth key');
        timer.cancel();
        _connectUserUsingOAuth(
          appInfo: appInfo,
          onRequestBrowsing: onRequestBrowsing,
          getOAuthKey: getOAuthKey,
          setOAuthKey: setOAuthKey,
        );
      }

      _logger.info('OAuth key is valid');
    });

    _logger.info('User is connected to Twitch');
    return true;
  }

  @override
  Future<void> disconnect() async {
    _chatbotBearerKey = null;
    _isChatbotConnected = false;
    await super.disconnect();
  }

  @override
  Future<void> _saveSessions() async {
    super._saveSessions();
    const storage = FlutterSecureStorage();
    storage.write(key: 'chatbot$saveKeySuffix', value: chatbotBearerKey);
  }

  @override
  Future<void> loadSession() async {
    await super.loadSession();
    _chatbotBearerKey = await _loadSession(key: 'chatbot$saveKeySuffix');
  }

  @override
  Future<void> clearSession() async {
    await super.clearSession();
    await _clearSession(key: 'chatbot$saveKeySuffix');
  }
}

///
/// The JWT key is for the Frontend of a Twitch extension.
class TwitchJwtAuthenticator extends TwitchAuthenticator {
  TwitchJwtAuthenticator();

  ///
  /// ebsToken is the token that is used to authenticate the EBS to the Twitch API
  String? _ebsToken;
  String? get ebsToken => _ebsToken;

  ///
  /// The id of the channel that the frontend is connected to
  String? _channelId;
  String get channelId => _channelId!;

  ///
  /// The client id of the frontend
  String? _userId;
  String get userId => _userId!;

  ///
  /// Provide a callback when the connection is established
  final onHasConnected = TwitchGenericListener();

  @override
  Future<void> connect({required covariant TwitchFrontendInfo appInfo}) async {
    // Register the onAuthorized callback
    TwitchJavaScript.onAuthorized((OnAuthorizedResponse response) =>
        _onAuthorizedCallback(response, appInfo));
  }

  // Define the callback function
  void _onAuthorizedCallback(
      OnAuthorizedResponse reponse, TwitchFrontendInfo appInfo) {
    _logger.info('Received auth token');
    _ebsToken = reponse.token;
    _bearerKey = reponse.helixToken;

    _channelId = reponse.channelId;
    _userId = reponse.userId;

    try {
      TwitchEbsApi.registerToEbs(appInfo, this);
      _isConnected = true;
      onHasConnected.notifyListeners((callback) => callback());
      _logger.info('Successully connected to the server');
    } catch (e) {
      _logger.severe('Error registering to EBS: $e');
      _ebsToken = null;
      _bearerKey = null;

      _channelId = null;
      _userId = null;

      _isConnected = false;
    }
  }

  @override
  Future<void> loadSession() async {
    throw 'JWT Authenticator does not support loading sessions';
  }

  @override
  Future<void> _saveSessions() async {
    throw 'JWT Authenticator does not support saving sessions';
  }
}

Future<String?> _loadSession({required String key}) async {
  const storage = FlutterSecureStorage();
  final bearerKey = await storage.read(key: key);
  return bearerKey != null && bearerKey.isNotEmpty ? bearerKey : null;
}

Future<void> _clearSession({required String key}) async {
  const storage = FlutterSecureStorage();
  await storage.write(key: key, value: '');
}

class TwitchClientAuthenticatorMock extends TwitchClientAuthenticator {
  TwitchClientAuthenticatorMock({super.saveKeySuffix});

  @override
  Future<bool> connect({
    required covariant TwitchAppInfo appInfo,
    Future<void> Function(String address)? onRequestBrowsing,
    bool tryNewOAuthKey = true,
  }) async {
    _bearerKey = 'streamerOAuthKey';
    _isConnected = true;
    return true;
  }

  @override
  Future<bool> connectChatbot({
    required TwitchAppInfo appInfo,
    Future<void> Function(String address)? onRequestBrowsing,
    bool tryNewOAuthKey = false,
  }) async {
    _chatbotBearerKey = 'chatbotOAuthKey';
    _isChatbotConnected = true;
    return true;
  }
}
