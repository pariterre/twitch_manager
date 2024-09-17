import 'package:twitch_manager/app/twitch_events.dart';

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

class TwitchEventMock extends TwitchEvent {
  TwitchEventMock({
    super.eventId = '0987654321',
    super.requestingUserId = '123456789',
    super.requestingUser = 'MockUser',
    super.message = '',
  });
}

class TwitchRewardRedemptionMock extends TwitchRewardRedemption {
  TwitchRewardRedemptionMock({
    super.eventId = '0987654321',
    super.requestingUserId = '123456789',
    super.requestingUser = 'MockUser',
    super.message = '',
    required super.rewardRedemptionId,
    required super.rewardRedemption,
    required super.cost,
  });

  @override
  TwitchRewardRedemptionMock copyWith({
    String? eventId,
    String? requestingUserId,
    String? requestingUser,
    int? cost,
    String? message,
    String? rewardRedemptionId,
    String? rewardRedemption,
  }) {
    return TwitchRewardRedemptionMock(
      eventId: eventId ?? this.eventId,
      requestingUserId: requestingUserId ?? this.requestingUserId,
      requestingUser: requestingUser ?? this.requestingUser,
      cost: cost ?? this.cost,
      message: message ?? this.message,
      rewardRedemptionId: rewardRedemptionId ?? this.rewardRedemptionId,
      rewardRedemption: rewardRedemption ?? this.rewardRedemption,
    );
  }
}

///
/// This is the main class that helps prepare the TwitchDebugPanel.
class TwitchDebugPanelOptions {
  /// A list of chatters to send messages from
  final List<TwitchChatterMock> chatters;

  /// A list of prewritten messages to send from the chatters
  final List<String> chatMessages;

  /// A list of reward redemptions that can be redeemed
  final List<TwitchRewardRedemption> redemptionRewardEvents;

  /// A callback to the TwitchEventMock so we can simulate a reward redemption
  void Function(TwitchRewardRedemption)? simulateRewardRedemption;

  /// Constructor, note that we make a copy of the lists to drop any const
  /// lists that may be passed in
  TwitchDebugPanelOptions({
    List<TwitchChatterMock>? chatters,
    List<String>? chatMessages,
    List<TwitchRewardRedemption>? redemptionRewardEvents,
  })  : chatters = chatters == null ? [] : [...chatters],
        chatMessages = chatMessages == null ? [] : [...chatMessages],
        redemptionRewardEvents =
            redemptionRewardEvents == null ? [] : [...redemptionRewardEvents];
}
