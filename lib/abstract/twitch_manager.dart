import 'package:twitch_manager/abstract/twitch_authenticator.dart';
import 'package:twitch_manager/abstract/twitch_info.dart';
import 'package:twitch_manager/utils/twitch_listener.dart';

mixin TwitchManager {
  ///
  /// Get the app information
  TwitchInfo get appInfo;

  ///
  /// Get the authenticator
  TwitchAuthenticator get authenticator;

  ///
  /// Connecting a user to Twitch
  Future<void> connect();

  ///
  /// Callback to inform the user when the manager has connected
  TwitchListener get onHasConnected;

  ///
  /// Disconnect and clean the saved bearer token
  Future<void> disconnect();

  ///
  /// Callback to inform the user when the manager has disconnected
  TwitchListener get onHasDisconnected;

  ///
  /// If the streamer is connected
  bool get isConnected;
}
