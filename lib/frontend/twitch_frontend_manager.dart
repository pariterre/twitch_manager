import 'package:logging/logging.dart';
import 'package:twitch_manager/abstract/twitch_authenticator.dart';
import 'package:twitch_manager/abstract/twitch_manager.dart';
import 'package:twitch_manager/frontend/twitch_ebs_api.dart';
import 'package:twitch_manager/frontend/twitch_frontend_info.dart';
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
    Function(String message)? pubSubCallback,
  }) async {
    _logger.config('Creating the manager to the Twitch connexion...');

    final authenticator = TwitchJwtAuthenticator();
    final apiToEbs =
        TwitchEbsApi(appInfo: appInfo, authenticator: authenticator);
    final manager = TwitchFrontendManager._(appInfo, authenticator, apiToEbs);

    // Connect to the EBS and relay the onHasConnected event to the manager listeners
    if (onConnectedToTwitchService != null) {
      authenticator.onHasConnected.startListening(onConnectedToTwitchService);
    }
    if (pubSubCallback != null) {
      authenticator.listenToPubSub('broadcast', pubSubCallback);
    }
    manager.connect(isTwitchUserIdRequired: isTwitchUserIdRequired);

    _logger.config('Manager is ready to be used');
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

  @override
  final onHasConnected = TwitchListener();

  @override
  TwitchListener<Function> get onHasDisconnected =>
      throw 'It is not possible to listen to the disconnection of the frontend';
}
