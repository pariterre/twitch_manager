enum ScopeType {
  chat,
  api,
  events;
}

///
/// The access right provided to the app by the streamer
enum TwitchScope {
  chatRead,
  chatEdit,
  chatters,

  readModerator,
  readFollowers,

  readRewardRedemption,
  manageRewardRedemption;

  @override
  String toString() {
    switch (this) {
      case TwitchScope.chatRead:
        return 'chat:read';
      case TwitchScope.chatEdit:
        return 'chat:edit';
      case TwitchScope.chatters:
        return 'moderator:read:chatters';
      case TwitchScope.readModerator:
        return 'moderation:read';
      case TwitchScope.readFollowers:
        return 'moderator:read:followers';
      case TwitchScope.readRewardRedemption:
        return 'channel:read:redemptions';
      case TwitchScope.manageRewardRedemption:
        return 'channel:manage:redemptions';
    }
  }

  ScopeType get scopeType {
    switch (this) {
      case TwitchScope.chatRead:
      case TwitchScope.chatEdit:
        return ScopeType.chat;
      case TwitchScope.chatters:
      case TwitchScope.readModerator:
      case TwitchScope.readFollowers:
      case TwitchScope.manageRewardRedemption:
        return ScopeType.api;
      case TwitchScope.readRewardRedemption:
        return ScopeType.events;
    }
  }
}
