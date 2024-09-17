abstract class TwitchInfo {
  ///
  /// The name of the app. It is mainly user to create a save folder with a
  /// relevent name.
  final String appName;

  ///
  /// The Client ID provided by Twitch. See the extension parameters in dev.twitch.tv.
  /// This is public information, so there is no need to hide it (therefore it can
  /// be versioned in the code). Do not confuse with the "client secret" key which
  /// is secret and should never be shared. However, the client secret is not used
  /// by the TwitchManager.
  final String? twitchClientId;

  ///
  /// Main constructor
  ///
  TwitchInfo({
    required this.appName,
    required this.twitchClientId,
  });
}
