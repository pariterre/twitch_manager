import 'package:twitch_manager/models/twitch_scope.dart';

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

class TwitchAppInfo extends TwitchInfo {
  @override
  String get twitchClientId => super.twitchClientId!;

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
    required super.appName,
    required super.twitchClientId,
    required this.twitchRedirectUri,
    required this.authenticationServerUri,
    required this.scope,
  })  : hasChatbot = scope.any((e) => e == TwitchScope.chatEdit),
        needChat = scope.any((e) => e.scopeType == ScopeType.chat),
        hasEvents = scope.any((e) => e.scopeType == ScopeType.events);
}

class TwitchFrontendInfo extends TwitchInfo {
  ///
  /// The URI of the EBS server. This is the server that handles the requests
  /// from the frontend. It is used to initialize and communicate information from
  /// the frontend to the backend.
  final Uri ebsUri;

  ///
  /// Main constructor
  /// [appName] is the name of the app. It is mainly for reference as it is not used
  /// [ebsUri] is the URI of the EBS server.
  /// [twitchClientId] is not used in the frontend, so it is set to an empty string.
  TwitchFrontendInfo({
    required super.appName,
    required this.ebsUri,
  }) : super(twitchClientId: null);
}

class TwitchEbsInfo extends TwitchInfo {
  ///
  /// The current version of the extension
  final String extensionVersion;

  ///
  /// The secret key of the extension. This is used to communicate with the
  /// Twitch API. It is secret and should never be shared, nor should it be
  /// stored in the code. It should be stored in the environment variables.
  final String extensionSecret;

  ///
  /// The shared secret key of the extension. This is used to communicate with
  /// the frontend. It is secret and should never be shared, nor should it be
  /// stored in the code. It should be stored in the environment variables.
  final String? sharedSecret;

  ///
  /// If the app needs the Twitch user ID. This is used to identify the user
  /// from the frontend. If this is set to true, the user ID is required in the
  /// JWT token. To do so, the developer must add the corresponding field in the
  /// dev panel of the extension.
  final bool needTwitchUserId;

  ///
  /// Main constructor
  /// [appName] is the name of the app. It is mainly for reference as it is not used
  /// [twitchClientId] the client ID of the app.
  /// [extensionVersion] the version of the extension.
  /// [extensionSecret] the secret key of the extension.
  TwitchEbsInfo({
    required super.appName,
    required super.twitchClientId,
    required this.extensionVersion,
    required this.extensionSecret,
    this.sharedSecret,
    this.needTwitchUserId = false,
  });
}
