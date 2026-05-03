class TwitchUser {
  final String userId;
  final String login;
  final String displayName;

  const TwitchUser({
    required this.userId,
    required this.login,
    required this.displayName,
  });

  bool contains(String query) {
    return userId.contains(query) ||
        login.contains(query) ||
        displayName.contains(query);
  }

  @override
  String toString() {
    return 'TwitchUser{userId: $userId, login: $login, displayName: $displayName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TwitchUser) return false;
    return userId == other.userId &&
        login == other.login &&
        displayName == other.displayName;
  }

  @override
  int get hashCode => userId.hashCode ^ login.hashCode ^ displayName.hashCode;
}

extension TwitchUsersExtension on Iterable<TwitchUser> {
  TwitchUser? from({String? userId, String? login, String? displayName}) {
    if (userId == null && login == null && displayName == null) {
      throw 'Either userId, login or displayName must be provided';
    } else if ((userId != null && (login != null || displayName != null)) ||
        (login != null && (userId != null || displayName != null)) ||
        (displayName != null && (userId != null || login != null))) {
      throw 'Only one of userId, login or displayName must be provided';
    }

    for (final user in this) {
      if ((userId != null && user.userId == userId) ||
          (login != null && user.login == login) ||
          (displayName != null && user.displayName == displayName)) {
        return user;
      }
    }
    return null;
  }

  bool has({String? userId, String? login, TwitchUser? user}) {
    if (userId == null && login == null && user == null) {
      throw 'Either userId, login or user must be provided';
    } else if ((userId != null && (login != null || user != null)) ||
        (login != null && (userId != null || user != null)) ||
        (user != null && (userId != null || login != null))) {
      throw 'Only one of userId, login or user must be provided';
    }

    final identifier = userId ?? login ?? user!.userId;
    for (final user in this) {
      if (user.userId == identifier || user.login == identifier) {
        return true;
      }
    }
    return false;
  }
}

extension TwitchUserStringListExtension on Iterable<String> {
  bool has(TwitchUser user) {
    for (final identifier in this) {
      if (identifier == user.userId || identifier == user.login) {
        return true;
      }
    }
    return false;
  }
}

class TwitchFrontendUser extends TwitchUser {
  String opaqueId;

  TwitchFrontendUser({
    required super.userId,
    required this.opaqueId,
    required super.login,
    required super.displayName,
  });
}

extension TwitchFrontendUsersExtension on Iterable<TwitchFrontendUser> {
  TwitchFrontendUser? from(
      {String? userId, String? login, String? opaqueId, String? displayName}) {
    if (userId == null &&
        login == null &&
        opaqueId == null &&
        displayName == null) {
      throw 'Either userId, login, opaqueId or displayName must be provided';
    } else if ((userId != null &&
            (login != null || opaqueId != null || displayName != null)) ||
        (login != null &&
            (userId != null || opaqueId != null || displayName != null)) ||
        (opaqueId != null &&
            (userId != null || login != null || displayName != null)) ||
        (displayName != null &&
            (userId != null || login != null || opaqueId != null))) {
      throw 'Only one of userId, login, opaqueId or displayName must be provided';
    }

    for (final user in this) {
      if ((userId != null && user.userId == userId) ||
          (login != null && user.login == login) ||
          (opaqueId != null && user.opaqueId == opaqueId) ||
          (displayName != null && user.displayName == displayName)) {
        return user;
      }
    }
    return null;
  }
}
