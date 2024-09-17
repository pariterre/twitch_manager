enum AppScopeType {
  chat,
  api,
  events;
}

///
/// The access right provided to the app by the streamer
enum TwitchAppScope {
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
      case TwitchAppScope.chatRead:
        return 'chat:read';
      case TwitchAppScope.chatEdit:
        return 'chat:edit';
      case TwitchAppScope.chatters:
        return 'moderator:read:chatters';
      case TwitchAppScope.readModerator:
        return 'moderation:read';
      case TwitchAppScope.readFollowers:
        return 'moderator:read:followers';
      case TwitchAppScope.readRewardRedemption:
        return 'channel:read:redemptions';
      case TwitchAppScope.manageRewardRedemption:
        return 'channel:manage:redemptions';
    }
  }

  AppScopeType get scopeType {
    switch (this) {
      case TwitchAppScope.chatRead:
      case TwitchAppScope.chatEdit:
        return AppScopeType.chat;
      case TwitchAppScope.chatters:
      case TwitchAppScope.readModerator:
      case TwitchAppScope.readFollowers:
      case TwitchAppScope.manageRewardRedemption:
        return AppScopeType.api;
      case TwitchAppScope.readRewardRedemption:
        return AppScopeType.events;
    }
  }
}
