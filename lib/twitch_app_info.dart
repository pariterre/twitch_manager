import 'twitch_manager.dart';

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
  /// The scope of the rights required for the app to work
  final List<TwitchScope> scope;

  ///
  /// This is the same as scope, but only for chat related scope.
  List<TwitchScope> get chatScope {
    List<TwitchScope> out = [];
    for (final s in scope) {
      if (s == TwitchScope.chatEdit || s == TwitchScope.chatRead) out.add(s);
    }
    return out;
  }

  ///
  /// If the app needs a chat bot. This is automatically set to true as soon as
  /// TwitchScope.chatEdit is required
  final bool hasChatbot;

  ///
  /// Main constructor
  TwitchAppInfo({
    required this.appName,
    required this.twitchAppId,
    required this.redirectAddress,
    required this.scope,
  }) : hasChatbot = scope.contains(TwitchScope.chatEdit);
}
