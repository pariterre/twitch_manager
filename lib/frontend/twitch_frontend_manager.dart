import 'package:logging/logging.dart';
import 'package:twitch_manager/abstract/twitch_authenticator.dart';
import 'package:twitch_manager/abstract/twitch_manager.dart';
import 'package:twitch_manager/frontend/twitch_ebs_api.dart';
import 'package:twitch_manager/frontend/twitch_frontend_info.dart';
import 'package:twitch_manager/twitch_ebs.dart';
import 'package:twitch_manager/utils/twitch_listener.dart';

final _logger = Logger('TwitchFrontendManager');

class TwitchFrontendManager implements TwitchManager {
  final TwitchFrontendInfo _appInfo;
  @override
  TwitchFrontendInfo get appInfo => _appInfo;

  final TwitchJwtAuthenticator _authenticator;
  @override
  TwitchJwtAuthenticator get authenticator => _authenticator;

  final TwitchEbsApi _apiToEbs;
  TwitchEbsApi get apiToEbs => _apiToEbs;

  @override
  bool get isConnected => authenticator.isConnected;

  ///
  /// Internal constructor of the Twitch Manager
  TwitchFrontendManager._(this._appInfo, this._authenticator, this._apiToEbs);

  /// Main constructor for the TwitchFrontendManager.
  /// [appInfo] is all the required information of the current extension.
  /// [isTwitchUserIdRequired] is a flag to indicate if the Twitch user ID is required.
  /// If it is required, the user will be prompted to log in to Twitch.
  /// [onHasConnected] is a callback to be called when the connection is established.
  /// It is basically the same as the [onHasConnected] listener, but is added
  /// before the connection is established. While the [onHasConnected] listener
  /// is added after the connection is established (therefore, never called)
  static Future<TwitchFrontendManager> factory({
    required TwitchFrontendInfo appInfo,
    bool isTwitchUserIdRequired = false,
    Function()? onHasConnected,
  }) async {
    _logger.config('Creating the manager to the Twitch connexion...');

    final authenticator = TwitchJwtAuthenticator();
    final apiToEbs =
        TwitchEbsApi(appInfo: appInfo, authenticator: authenticator);
    final manager = TwitchFrontendManager._(appInfo, authenticator, apiToEbs);

    // Connect to the EBS and relay the onHasConnected event to the manager listeners
    if (onHasConnected != null) manager.onHasConnected.listen(onHasConnected);
    authenticator.onHasConnected.listen(manager._notifyOnHasConnected);
    authenticator.listenToPubSub('broadcast', manager._pubSubCallback);
    manager.connect(isTwitchUserIdRequired: isTwitchUserIdRequired);

    _logger.config('Manager is ready to be used');

    // Try to register to the extension. This will fail if the streamer did not
    // start the extension yet, just ignore it. When the streamer is ready, the
    // extension will send a handshake message to the frontend which will also
    // register it to the extension.
    await manager._registerToExtension();
    return manager;
  }

  @override
  Future<void> connect({bool isTwitchUserIdRequired = false}) async {
    await authenticator.connect(
        appInfo: appInfo, isTwitchUserIdRequired: isTwitchUserIdRequired);
  }

  @override
  final onHasConnected = TwitchListener<Function()>();

  final onStreamerHasConnected = TwitchListener<Function()>();
  final onStreamerHasDisconnected = TwitchListener<Function()>();

  void _notifyOnHasConnected() {
    onHasConnected.notifyListeners((callback) => callback());
  }

  @override
  Future<void> disconnect() =>
      throw 'It is not possible to disconnect from the frontend, it is automatically '
          'done by the browser when the page is closed';

  ///
  /// Send a message to the App based on the [type] of message.
  Future<MessageProtocol> sendMessageToApp(MessageProtocol message) async {
    try {
      final response = await apiToEbs.postRequest(
          message.type,
          message
              .copyWith(
                  from: MessageFrom.frontend,
                  to: MessageTo.app,
                  type: message.type)
              .toJson());
      _logger.info('Response from App: $response');
      return MessageProtocol.fromJson(response);
    } catch (e) {
      _logger.severe('Failed to send message to EBS: $e');
      return MessageProtocol(
          from: MessageFrom.app,
          to: MessageTo.frontend,
          type: MessageTypes.response,
          isSuccess: false);
    }
  }

  ///
  /// Send a message to the EBS based on the [type] of message.
  /// This is mostly for internal stuff. Usually, you will want to send a message
  /// to the App instead using [sendMessageToApp].
  Future<MessageProtocol> sendMessageToEbs(MessageProtocol message) async {
    if (message.type == MessageTypes.get || message.type == MessageTypes.put) {
      _logger
          .severe('Cannot send a message of type ${message.type} to the EBS');
      throw Exception(
          'Cannot send a message of type ${message.type} to the EBS');
    }

    try {
      final response = await apiToEbs.postRequest(
          message.type,
          MessageProtocol(
                  from: MessageFrom.frontend,
                  to: MessageTo.ebsIsolated,
                  type: message.type)
              .toJson());
      _logger.info('Reponse from EBS: $response');
      return MessageProtocol.fromJson(response);
    } catch (e) {
      _logger.severe('Failed to send message to EBS: $e');
      return MessageProtocol(
          from: MessageFrom.ebsMain,
          to: MessageTo.frontend,
          type: MessageTypes.response,
          isSuccess: false);
    }
  }

  @override
  TwitchListener<Function> get onHasDisconnected =>
      throw 'It is not possible to listen to the disconnection of the frontend';

  ///
  /// This provides a way to listen to messages received from the PubSub.
  final onMessageReceived = TwitchListener<Function(MessageProtocol)>();

  ///
  /// Intercept internal messages from the PubSub and behave accordingly
  Future<void> _pubSubCallback(MessageProtocol message) async {
    _logger.fine('Received PubSub message: ${message.type.toString()}');

    try {
      switch (message.type) {
        case MessageTypes.handShake:
          _logger.info('Streamer connected to the extension');
          await _registerToExtension();
          onStreamerHasConnected.notifyListeners((callback) => callback());
          return;
        case MessageTypes.disconnect:
          _logger.info('Streamer disconnected from the extension');
          onStreamerHasDisconnected.notifyListeners((callback) => callback());
          return;
        case MessageTypes.ping:
        case MessageTypes.pong:
          // These should not be received by the frontend
          return;
        case MessageTypes.get:
        case MessageTypes.put:
        case MessageTypes.response:
          // Pass these to the listeners
          onMessageReceived.notifyListeners((callback) => callback(message));
          break;
      }
    } catch (e) {
      _logger.severe('Error while handling PubSub message: $e');
    }
  }

  Future<void> _registerToExtension() async {
    final response = await sendMessageToEbs(MessageProtocol(
        from: MessageFrom.frontend,
        to: MessageTo.ebsMain,
        type: MessageTypes.handShake));
    final isSuccess = response.isSuccess ?? false;
    if (!isSuccess) {
      _logger.info(
          'Cannot register to extension, as the streamer did not started it yet');
      return;
    }

    _logger.info('Registered to extension');
  }
}
