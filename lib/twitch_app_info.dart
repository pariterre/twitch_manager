import 'twitch_scope.dart';

class TwitchAppInfo {
  ///
  /// The name of the app. It is mainly user to create a save folder with a
  /// relevent name.
  final String appName;

  ///
  /// The App ID provided by Twitch. See the extension parameters in dev.twitch.tv
  final String twitchAppId;

  ///
  /// The redirect address specified to Twitch. See the extension parameters
  /// in dev.twitch.tv
  final String redirectAddress;

  ///
  /// If the authentication should be done via a service [false] or a
  /// local server [true]. Local server is incompatible with web apps, on the
  /// other hand, it does not require any service to authenticate.
  /// The code for the service sits at
  /// `$TWITCH_MANAGER_ROOT/ressources/authentication_service`
  final bool useAuthenticationService;

  ///
  /// If [useAuthenticationService], then this address must be provided.
  final String? authenticationServiceAddress;

  ///
  /// The scope of the rights required for the app to work
  final List<TwitchScope> scope;

  ///
  /// If the app needs a chat bot. This is automatically set to true as soon as
  /// TwitchScope.chatEdit is required
  final bool hasChatbot;

  ///
  /// Main constructor
  TwitchAppInfo(
      {required this.appName,
      required this.twitchAppId,
      required this.redirectAddress,
      required this.scope,
      this.useAuthenticationService = false,
      this.authenticationServiceAddress})
      : hasChatbot = scope.contains(TwitchScope.chatEdit) ||
            scope.contains(TwitchScope.chatRead) {
    if (useAuthenticationService) {
      if (authenticationServiceAddress == null) {
        throw 'If [useAuthenticationService] is set to true, then [authenticationServiceAddress] must be set.';
      }
    }
  }
}
