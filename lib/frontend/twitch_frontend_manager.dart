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
  /// [onConnectedToTwitchService] is the callback to be called when the frontend has connected.
  /// This is useful to perform actions when the frontend is ready to be used.
  /// [pubSubCallback] is the callback to be called when the frontend has received a PubSub message.
  /// If not provided, the manager will not listen to PubSub messages.
  static Future<TwitchFrontendManager> factory({
    required TwitchFrontendInfo appInfo,
    bool isTwitchUserIdRequired = false,
    Function()? onConnectedToTwitchService,
    Function(MessageProtocol message)? pubSubCallback,
  }) async {
    _logger.config('Creating the manager to the Twitch connexion...');

    final authenticator = TwitchJwtAuthenticator();
    final apiToEbs =
        TwitchEbsApi(appInfo: appInfo, authenticator: authenticator);
    final manager = TwitchFrontendManager._(appInfo, authenticator, apiToEbs);

    // Connect to the EBS and relay the onHasConnected event to the manager listeners
    if (onConnectedToTwitchService != null) {
      authenticator.onHasConnected.listen(onConnectedToTwitchService);
    }
    authenticator.listenToPubSub('broadcast', manager._pubSubCallback);
    if (pubSubCallback != null) {
      authenticator.listenToPubSub('broadcast', pubSubCallback);
    }
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
  final onHasConnected = TwitchListener();

  @override
  TwitchListener<Function> get onHasDisconnected =>
      throw 'It is not possible to listen to the disconnection of the frontend';

  ///
  /// Intercept internal messages from the PubSub and behave accordingly
  Future<void> _pubSubCallback(MessageProtocol message) async {
    _logger.info('Received PubSub message: ${message.toString()}');

    try {
      switch (message.type) {
        case MessageTypes.handShake:
          _logger.info('Streamer connected to the extension');
          await _registerToExtension();
          break;
        case MessageTypes.disconnect:
        case MessageTypes.ping:
        case MessageTypes.pong:
        case MessageTypes.get:
        case MessageTypes.put:
        case MessageTypes.response:
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
