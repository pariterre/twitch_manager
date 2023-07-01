class TwitchMockOptions {
  final bool isActive;

  final List<String> moderators;
  final List<String> messagesModerators;

  final List<String> followers;
  final List<String> messagesFollowers;

  const TwitchMockOptions(
      {required this.isActive,
      this.moderators = const ['moderator1'],
      this.messagesModerators = const ['Hello, I\'m a moderator'],
      this.followers = const ['chatter1', 'chatter2'],
      this.messagesFollowers = const ['Hello, I\'m a follower']});
}
