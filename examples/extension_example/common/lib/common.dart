class ConfigService {
  ///
  /// The name of the extension that matches the one in the Twitch Developer Console.
  static const String extensionName = 'twitch_extension_example';

  ///
  /// The Twitch client ID for the extension.
  static const String twitchClientId = 'abcdefghijklmnopqrstuvwxyz1234567890';

  ///
  /// The version of the extension that matches the one in the Twitch Developer Console.
  static const String extensionVersion = '0.3.0';

  ///
  /// If your extension requires a user ID, set this to `true`.
  /// Please note you will have to set the proper scopes in the Twitch Developer Console.
  /// If your extension does not require a user ID, set this to `false`.
  static const bool userIdIsRequired = false;

  ///
  /// Whether to use mockers for debug purposes. This should be set to `false` in production.
  static const useMockers = true;

  ///
  /// The mocked Twitch shared secret
  static const mockedSharedSecret = 'abcdefghijklmnopqrstuvwxyz1234567890';

  ///
  /// The URI of the EBS server. If you are running the EBS server locally,
  /// set this to `ws://localhost:3010`.
  static const ebsPort = 3010;
  static final ebsUri = Uri.parse('ws://localhost:$ebsPort');
}
