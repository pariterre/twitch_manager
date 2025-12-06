part of 'package:twitch_manager/common/twitch_authenticator.dart';

///
/// The OAuth key is for the "Authorization code grant flow":
/// https://dev.twitch.tv/docs/authentication/getting-tokens-oauth
///
/// As requested by Twitch, the OAuth key is validated every hour.
class TwitchAppAuthenticator extends TwitchAuthenticator {
  ///
  /// Constructor of the Authenticator
  TwitchAppAuthenticator({super.saveKeySuffix = ''});

  ///
  /// The chatbot bearer key
  AppToken? _chatbotBearerKey;
  AppToken? get chatbotBearerKey => _chatbotBearerKey;

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
      getPreviousAccessToken: () => bearerKey,
      setAccessToken: (value) => _bearerKey = value,
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
      getPreviousAccessToken: () => chatbotBearerKey,
      setAccessToken: (value) => _chatbotBearerKey = value,
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
  /// [getPreviousAccessToken] Callback to the current OAuth key of the user.
  /// [setAccessToken] Callback to set the OAuth key of the user.
  Future<bool> _connectUserUsingOAuth({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String address)? onRequestBrowsing,
    required AppToken? Function() getPreviousAccessToken,
    required void Function(AppToken oAuthKey) setAccessToken,
  }) async {
    _logger.info('Connecting user to Twitch...');

    // Get an access token
    final token = await TwitchAppApi.getAppToken(
      appInfo: appInfo,
      onRequestBrowsing: onRequestBrowsing,
      previousAppToken: getPreviousAccessToken(),
    );
    if (token == null) return false;
    setAccessToken(token);

    // If we are indeed connected, we have to validate the OAuth key every hour
    Timer.periodic(const Duration(hours: 1), (timer) async {
      _logger.info('Validating OAuth key...');

      final currentToken = getPreviousAccessToken();
      if (currentToken == null) {
        _logger.warning('User has disconnected, stop validating the OAuth key');
        timer.cancel();
        return;
      }
      if (!await TwitchAppApi.validateOAuthToken(token: currentToken)) {
        // If it fails, restart the connecting process
        _logger.warning('OAuth key is not valid, requesting new OAuth key');
        timer.cancel();
        _connectUserUsingOAuth(
          appInfo: appInfo,
          onRequestBrowsing: onRequestBrowsing,
          getPreviousAccessToken: getPreviousAccessToken,
          setAccessToken: setAccessToken,
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
    storage.write(
        key: 'chatbot$saveKeySuffix', value: chatbotBearerKey?.serialize());
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

class TwitchAppAuthenticatorMock extends TwitchAppAuthenticator {
  TwitchAppAuthenticatorMock({super.saveKeySuffix});

  @override
  Future<bool> connect({
    required covariant TwitchAppInfo appInfo,
    Future<void> Function(String address)? onRequestBrowsing,
    bool tryNewOAuthKey = true,
  }) async {
    _bearerKey =
        AppToken.fromJwt(jwt: JWT({'twitch_access_token': 'streamerOAuthKey'}));
    _isConnected = true;
    return true;
  }

  @override
  Future<bool> connectChatbot({
    required TwitchAppInfo appInfo,
    Future<void> Function(String address)? onRequestBrowsing,
    bool tryNewOAuthKey = false,
  }) async {
    _chatbotBearerKey =
        AppToken.fromJwt(jwt: JWT({'twitch_access_token': 'chatbotOAuthKey'}));
    _isChatbotConnected = true;
    return true;
  }
}
