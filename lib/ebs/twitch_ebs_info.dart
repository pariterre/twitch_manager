import 'package:twitch_manager/abstract/twitch_info.dart';

class TwitchEbsInfo extends TwitchInfo {
  ///
  /// Sometime the client ID is referred as the extension ID.
  String get extensionId => twitchClientId!;

  ///
  /// The current version of the extension
  final String extensionVersion;

  ///
  /// The secret key of the extension. This is used to communicate with the
  /// Twitch API. It is secret and should never be shared, nor should it be
  /// stored in the code. It should be stored in the environment variables.
  final String? extensionApiClientSecret;

  ///
  /// The extension secret key of the extension. This is used to communicate with
  /// the frontend. It is secret and should never be shared, nor should it be
  /// stored in the code. It should be stored in the environment variables.
  final String? extensionSharedSecret;

  ///
  /// If the app needs the Twitch user ID. This is used to identify the user
  /// from the frontend. If this is set to true, the user ID is required in the
  /// JWT token. To do so, the developer must add the corresponding field in the
  /// dev panel of the extension.
  final bool isTwitchUserIdRequired;

  ///
  /// A random string used to sign the JWT tokens that is used to verify the token's
  /// authenticity when using the Authentication code flow.
  final String privateKey;

  ///
  /// Main constructor
  /// [appName] is the name of the app. It is mainly for reference as it is not used
  /// [twitchClientId] the client ID of the app.
  /// [extensionVersion] the version of the extension.
  /// [extensionSharedSecret] the secret key of the extension.
  TwitchEbsInfo({
    required super.appName,
    required super.twitchClientId,
    required this.extensionVersion,
    required this.extensionApiClientSecret,
    required super.authenticationFlow,
    required this.privateKey,
    this.extensionSharedSecret,
    this.isTwitchUserIdRequired = false,
  });
}
