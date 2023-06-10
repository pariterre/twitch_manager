import 'package:twitch_manager/twitch_manager.dart';

class TwitchAppInfo {
  String twitchAppId;
  String redirectAddress;
  List<TwitchScope> scope;

  TwitchAppInfo({
    required this.twitchAppId,
    required this.redirectAddress,
    required this.scope,
  });
}
