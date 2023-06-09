import 'package:twitch_manager/twitch_manager.dart';

class TwitchAppInfo {
  String twitchId;
  String redirectAddress;
  List<TwitchScope> scope;

  TwitchAppInfo({
    required this.twitchId,
    required this.redirectAddress,
    required this.scope,
  });
}
