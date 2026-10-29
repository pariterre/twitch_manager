part of 'package:twitch_manager/common/twitch_authenticator.dart';

///
/// The JWT key is for the Frontend of a Twitch extension.
class TwitchJwtAuthenticator extends TwitchAuthenticator {
  TwitchJwtAuthenticator();

  ///
  /// The [ebsToken] is a token that is used to authenticate that the user is
  /// an authenticated Twitch user when communicating with the EBS to the Twitch API.
  AppToken? _ebsToken;
  AppToken? get ebsToken {
    if (!isConnected) {
      _logger.severe('EBS Server not connected');
      throw Exception('EBS Server not connected');
    }
    return _ebsToken;
  }

  ///
  /// The id of the channel that the frontend is connected to
  String? _channelId;
  String get channelId {
    if (!isConnected) {
      _logger.severe('EBS Server not connected');
      throw Exception('EBS Server not connected');
    }
    return _channelId!;
  }

  ///
  /// The obfuscted user id of the frontend
  String? _opaqueUserId;
  String get opaqueUserId {
    if (!isConnected) {
      _logger.severe('EBS Server not connected');
      throw Exception('EBS Server not connected');
    }
    return _opaqueUserId!;
  }

  ///
  /// The non-obfuscated user id of the frontend. This required [isTwitchUserIdRequired]
  /// to be true when calling the [connect] method
  String? get userId => TwitchJsExtension.viewer.id;

  ///
  /// Request the real user id from Twitch. This prompts a popup to the user
  /// to authorize the extension to access their Twitch ID.
  void requestIdShare() {
    TwitchJsExtension.actions.requestIdShare();
  }

  ///
  /// Provide a callback when the connection is established
  final onHasConnected = TwitchListener<Function()>();

  ///
  /// Connect to the Twitch EBS server.
  /// This method must be called before any other method.
  /// [appInfo] is the information of the Twitch app.
  /// [isTwitchUserIdRequired] is true if the app needs the real user id.
  /// If true, the extension must be setup properly in the Twitch Developer Console
  /// to allow the extension to request the user id.
  @override
  Future<void> connect({
    required covariant TwitchFrontendInfo appInfo,
    bool isTwitchUserIdRequired = false,
  }) {
    // Register the onAuthorized callback
    TwitchJsExtension.onAuthorized((OnAuthorizedResponse response) {
      // Request the authorization of the real user id, if the app needs it
      if (isTwitchUserIdRequired) {
        if (TwitchJsExtension.viewer.id == null) {
          _logger.info(
              'Requesting the real user id (current user id: ${response.userId})');
          requestIdShare();
          // Do not call the onAuthorizedCallback just yet as when the id will
          // be shared, the onAuthorized callback will be called again
          return;
        }
        _logger.info('Real user id is authorized');
      } else {
        _logger.info('Real user id is not required');
      }
      _onAuthorizedCallback(response);
    });

    return Future.value();
  }

  ///
  /// Listen to the PubSub messages from Twitch. PubSub messages are used
  /// to a way to communicate with the Twitch API that will automatically
  /// sends a message to all connected frontends.
  Future<void> listenToPubSub(
      String target, Function(MessageProtocol message) callback) {
    TwitchJsExtension.listen(target,
        (String target, String contentType, String raw) {
      _logger.fine('Message from Pubsub: $raw');
      try {
        callback(MessageProtocol.decode(raw.replaceAll('\'', '"')));
      } catch (e) {
        _logger.info('Message from PubSub: $raw');
      }
    });
    return Future.value();
  }

  ///
  /// Define the onAuthorized callback function
  void _onAuthorizedCallback(OnAuthorizedResponse reponse) {
    _logger.info('Received auth token');

    try {
      _ebsToken =
          AppToken.fromJwt(jwt: JWT({'twitch_access_token': reponse.token}));
      _bearerKey = AppToken.fromJwt(
          jwt: JWT({'twitch_access_token': reponse.helixToken}));
      _channelId = reponse.channelId;
      _opaqueUserId = reponse.userId;

      _isConnected = true;
      onHasConnected.notifyListeners((callback) => callback());
      _logger.info('Successully connected to the Twitch backend');
    } catch (e) {
      _logger.severe('Error registering to the Twitch backend: $e');
      _ebsToken = null;
      _bearerKey = null;

      _channelId = null;
      _opaqueUserId = null;

      _isConnected = false;
    }
  }

  @override
  Future<void> dispose() async {
    onHasConnected.cancelAll();

    _ebsToken = null;
    _bearerKey = null;
    _channelId = null;
    _opaqueUserId = null;
    _isConnected = false;
  }

  @override
  Future<void> loadSession() {
    throw 'JWT Authenticator does not support loading sessions';
  }

  @override
  Future<void> _saveSessions() {
    throw 'JWT Authenticator does not support saving sessions';
  }
}

///
/// This NoIntegration allows for using the TwitchManager in a non-Twitch settings
class NoIntegrationJwtAuthenticator extends TwitchJwtAuthenticator {
  static Future<NoIntegrationJwtAuthenticator> factory({
    required String login,
    required String channelId,
    required TwitchFrontendInfo appInfo,
  }) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    String? userId = sharedPreferences.getString('userId');
    if (userId == null) {
      userId = const Uuid().v4();
      await sharedPreferences.setString('userId', userId);
      _logger.info('Generated new userId: $userId');
    }

    return NoIntegrationJwtAuthenticator._(
      userId: userId,
      login: login,
      channelId: channelId,
      appInfo: appInfo,
    );
  }

  NoIntegrationJwtAuthenticator._({
    required String userId,
    required this.login,
    required String channelId,
    required this.appInfo,
  }) : _userId = userId {
    _channelId = channelId;
  }

  final TwitchFrontendInfo appInfo;

  Future<void> initialize() async {
    final signedInnerToken =
        await TwitchFrontendHelpers.getSelfSignedJwt(appInfo: appInfo, data: {
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
      'channel_id': channelId,
      'user_id': userId,
      'login': login,
      'opaque_user_id': opaqueUserId,
      'role': 'external',
      'is_unlinked': false,
    });
    final signedOuterToken =
        await TwitchFrontendHelpers.getSelfSignedJwt(appInfo: appInfo, data: {
      'twitch_access_token': signedInnerToken,
      'channel_id': channelId,
      'opaque_user_id': opaqueUserId,
      'user_id': userId
    });
    _ebsTokenString = signedOuterToken;
  }

  ///
  /// The login and displayName
  final String login;

  ///
  /// ebsToken is the token that is used to authenticate the EBS to the Twitch API
  String? _ebsTokenString;
  @override
  AppToken? get ebsToken {
    return AppToken.fromSerialized(_ebsTokenString!);
  }

  @override
  String get channelId => _channelId!;

  ///
  /// The obfuscted user id of the frontend
  @override
  String get opaqueUserId => userId;

  ///
  /// The non-obfuscated user id of the frontend. This required [isTwitchUserIdRequired]
  /// to be true when calling the [connect] method
  final String _userId;
  @override
  String get userId => _userId;

  @override
  void requestIdShare() {
    // Do nothing
  }

  @override
  Future<void> connect({
    required TwitchFrontendInfo appInfo,
    bool isTwitchUserIdRequired = false,
  }) async {
    // Do nothing as there is no third party to connect to
    _isConnected = true;
    onHasConnected.notifyListeners((callback) => callback());
  }

  @override
  Future<void> listenToPubSub(
      String target, Function(MessageProtocol message) callback) async {
    // There is no PubSub
  }
}
