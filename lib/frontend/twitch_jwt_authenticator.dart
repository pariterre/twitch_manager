part of 'package:twitch_manager/abstract/twitch_authenticator.dart';

///
/// The JWT key is for the Frontend of a Twitch extension.
class TwitchJwtAuthenticator extends TwitchAuthenticator {
  TwitchJwtAuthenticator();

  ///
  /// ebsToken is the token that is used to authenticate the EBS to the Twitch API
  String? _ebsToken;
  String? get ebsToken {
    if (!isConnected) {
      _logger.severe('EBS Server not connected');
      throw Exception('EBS Server not connected');
    }
    return _ebsToken;
  }

  ///
  /// The id of the channel that the frontend is connected to
  int? _channelId;
  int get channelId {
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

  void requestIdShare() {
    TwitchJsExtension.actions.requestIdShare();
  }

  ///
  /// Provide a callback when the connection is established
  final onHasConnected = TwitchListener<Function()>();

  @override
  Future<void> connect({
    required covariant TwitchFrontendInfo appInfo,
    bool isTwitchUserIdRequired = false,
  }) async {
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
  }

  Future<void> listenToPubSub(
      String target, Function(MessageProtocol message) callback) async {
    TwitchJsExtension.listen(target,
        (String target, String contentType, String raw) {
      _logger.fine('Message from Pubsub: $raw');
      try {
        callback(MessageProtocol.decode(raw.replaceAll('\'', '"')));
      } catch (e) {
        _logger.info('Message from PubSub: $raw');
      }
    });
  }

  // Define the onAuthorized callback function
  void _onAuthorizedCallback(OnAuthorizedResponse reponse) {
    _logger.info('Received auth token');

    try {
      _ebsToken = reponse.token;
      _bearerKey = reponse.helixToken;
      _channelId = int.parse(reponse.channelId);
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
  Future<void> loadSession() async {
    throw 'JWT Authenticator does not support loading sessions';
  }

  @override
  Future<void> _saveSessions() async {
    throw 'JWT Authenticator does not support saving sessions';
  }
}
