import 'package:twitch_manager/abstract/twitch_info.dart';

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
