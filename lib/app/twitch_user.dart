class TwitchUser {
  final String id;
  final String login;
  final String displayName;

  const TwitchUser({
    required this.id,
    required this.login,
    required this.displayName,
  });

  bool contains(String query) {
    return id.contains(query) ||
        login.contains(query) ||
        displayName.contains(query);
  }

  @override
  String toString() {
    return 'TwitchUser{id: $id, login: $login, displayName: $displayName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TwitchUser) return false;
    return id == other.id &&
        login == other.login &&
        displayName == other.displayName;
  }

  @override
  int get hashCode => id.hashCode ^ login.hashCode ^ displayName.hashCode;
}

extension TwitchUsersExtension on Iterable<TwitchUser> {
  TwitchUser? from({String? id, String? login}) {
    if (id == null && login == null) {
      throw 'Either id or login must be provided';
    } else if (id != null && login != null) {
      throw 'Only one of id or login must be provided';
    }

    for (final user in this) {
      if ((id != null && user.id == id) ||
          (login != null && user.login == login)) {
        return user;
      }
    }
    return null;
  }

  bool has({String? id, String? login, TwitchUser? user}) {
    if (id == null && login == null && user == null) {
      throw 'Either id, login or user must be provided';
    } else if ((id != null && (login != null || user != null)) ||
        (login != null && (id != null || user != null)) ||
        (user != null && (id != null || login != null))) {
      throw 'Only one of id, login or user must be provided';
    }
    final identifier = id ?? login ?? user!.id;

    for (final user in this) {
      if (user.id == identifier || user.login == identifier) {
        return true;
      }
    }
    return false;
  }
}

extension TwitchUserStringListExtension on Iterable<String> {
  bool has(TwitchUser user) {
    for (final identifier in this) {
      if (identifier == user.id || identifier == user.login) {
        return true;
      }
    }
    return false;
  }
}
