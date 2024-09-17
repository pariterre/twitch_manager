part of 'package:twitch_manager/abstract/twitch_authenticator.dart';

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
          await TwitchAppApi.validateOAuthToken(oAuthKey: getOAuthKey()!);
      _logger.info('OAuth key is ${isConnected ? '' : 'not'} valid');
    }

    if (!isConnected) {
      if (!tryNewOAuthKey || onRequestBrowsing == null) {
        _logger.severe('Could not connect to Twitch');
        return false;
      }

      _logger.info('Requesting new OAuth key');
      // Get a new OAuth key
      final oauthKey = await TwitchAppApi.getNewOAuth(
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
      if (!await TwitchAppApi.validateOAuthToken(oAuthKey: key)) {
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

class TwitchAppAuthenticatorMock extends TwitchAppAuthenticator {
  TwitchAppAuthenticatorMock({super.saveKeySuffix});

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
