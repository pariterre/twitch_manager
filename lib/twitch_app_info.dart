import 'package:twitch_manager/twitch_scope.dart';

class TwitchAppInfo {
  ///
  /// The name of the app. It is mainly user to create a save folder with a
  /// relevent name.
  final String appName;

  ///
  /// The App ID provided by Twitch. See the extension parameters in dev.twitch.tv
  final String twitchAppId;

  ///
  /// The domain to which the user will be redirected after
  /// accepting the connection on Twitch. This should match the one configured
  /// in the extension dev panel of dev.twitch.tv and all the files from
  /// ressources/authentication_website should be available at that domain.
  /// [redirectUri] should not contain any protocol (i.e. https://). https is
  /// automatically added.
  /// The URI is expected to points to the following address:
  /// https://${redirectUri}/twitch_redirect.html.
  /// This page will be used by Twitch to send the 'state' and 'access_token'.
  /// In the meantime, the app will constantly call the:
  /// https://${redirectUri}/get_access_token.php?${state}
  /// website, where ${state} will match the 'state' sent from Twitch.
  /// This website is expected ot return a simple JSON object with the
  /// following structure:
  /// {"token" : access_token_from_twitch}
  /// An example of the full process can be found in the
  /// [ressources/authentication_website] folder. This example uses a database
  /// to store the access token in [twitch_redirect.html] which can be then be
  /// read back and deleted from the database by [get_access_token.php].
  /// This is a bit convoluted but it is the only way to make TwitchManager
  /// working with web apps.
  final String redirectUri;

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
    required this.twitchAppId,
    required this.redirectUri,
    required this.scope,
  })  : hasChatbot = scope.any((e) => e == TwitchScope.chatEdit),
        needChat = scope.any((e) => e.scopeType == ScopeType.chat),
        hasEvents = scope.any((e) => e.scopeType == ScopeType.events);
}
