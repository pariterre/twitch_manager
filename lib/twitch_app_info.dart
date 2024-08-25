import 'package:twitch_manager/twitch_scope.dart';

class TwitchAppInfo {
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
  final String twitchClientId;

  ///
  /// The URI that Twitch should redirect to after the user has logged in. This
  /// URI should be the same as the one defined in the Twitch extension parameters
  /// in dev.twitch.tv. It is expected to post the authentication token to the
  /// [authenticationServerUri] so that the app can get the token.
  final Uri twitchRedirectUri;

  ///
  /// The URI that points to a server that handles the response from Twitch.
  /// The server is implemented in [ressources/authentication_server]. This is the
  /// backend called by the [twitchRedirectUri] to get the authentication token from
  /// Twitch and redirect it to the app.
  final Uri authenticationServerUri;

  ///
  /// The scope of the rights required for the app to work
  final List<TwitchScope> scope;

  ///
  /// If the app needs a chat bot. This is automatically set to true as soon as
  /// there is any TwitchScope that is [TwitchScope.chatEdit] defined
  final bool hasChatbot;

  ///
  /// If the app needs to read the chat. This is automatically set to true as
  /// soon as there is any TwitchScope that has a TwitchType.chat. This is
  /// required to use the chat. [hasChatbot] is always true if this is true.
  /// The reason hasChatbot is separated from hasChatRead is because [needChat]
  /// does not necessarily imply edit rights to the chat
  final bool needChat;

  ///
  /// If the app needs to subscribe to Twitch events. This is automatically set
  /// to true as soon as there is any TwitchScope that has a TwitchType.event
  final bool hasEvents;

  ///
  /// Main constructor
  TwitchAppInfo({
    required this.appName,
    required this.twitchClientId,
    required this.twitchRedirectUri,
    required this.authenticationServerUri,
    required this.scope,
  })  : hasChatbot = scope.any((e) => e == TwitchScope.chatEdit),
        needChat = scope.any((e) => e.scopeType == ScopeType.chat),
        hasEvents = scope.any((e) => e.scopeType == ScopeType.events);
}
