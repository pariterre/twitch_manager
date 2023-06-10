///
/// The access right provided to the app by the streamer
enum TwitchScope {
  chatRead,
  chatEdit,
  chatters,

  readFollowers,
  readSubscribers
}

extension TwitchScopeStringify on TwitchScope {
  String text() {
    switch (this) {
      case TwitchScope.chatRead:
        return 'chat:read';
      case TwitchScope.chatEdit:
        return 'chat:edit';
      case TwitchScope.chatters:
        return 'moderator:read:chatters';
      case TwitchScope.readFollowers:
        return 'moderator:read:followers';
      case TwitchScope.readSubscribers:
        return 'channel:read:subscriptions';
    }
  }
}
