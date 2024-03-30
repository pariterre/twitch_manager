import 'package:twitch_manager/models/twitch_events.dart';

class TwitchChatterMock {
  String displayName;
  bool isStreamer;
  bool isModerator;
  bool isFollower;

  TwitchChatterMock({
    required this.displayName,
    this.isModerator = false,
    this.isStreamer = false,
    this.isFollower = true,
  });
}

class TwitchEventMock extends TwitchEventResponse {
  TwitchEventMock({
    super.requestingId = '123456789',
    super.requestingUser = 'MockUser',
    required super.rewardRedemption,
    required super.cost,
    super.message = '',
  });
}

///
/// This is the main class that helps prepare the TwitchDebugPanel.
class TwitchDebugPanelOptions {
  /// A list of chatters to send messages from
  final List<TwitchChatterMock> chatters;

  /// A list of prewritten messages to send from the chatters
  final List<String> chatMessages;

  /// A list of reward redemptions that can be redeemed
  final List<TwitchEventMock> redemptionRewardEvents;

  /// A callback to the TwitchEventMock so we can simulate a reward redemption
  void Function(TwitchEventMock)? simulateRewardRedemption;

  /// Constructor, note that we make a copy of the lists to drop any const
  /// lists that may be passed in
  TwitchDebugPanelOptions({
    List<TwitchChatterMock>? chatters,
    List<String>? chatMessages,
    List<TwitchEventMock>? redemptionRewardEvents,
  })  : chatters = chatters == null ? [] : [...chatters],
        chatMessages = chatMessages == null ? [] : [...chatMessages],
        redemptionRewardEvents =
            redemptionRewardEvents == null ? [] : [...redemptionRewardEvents];
}
