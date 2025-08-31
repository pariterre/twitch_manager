import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart';

final _logger = Logger('TwitchEbsCredentialsStorage');

class TwitchEbsCredentials {
  final String userId;
  final String accessToken;
  final String refreshToken;

  TwitchEbsCredentials({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });
}

abstract class TwitchEbsCredentialsStorage {
  ///
  /// Save the Twitch credentials of a user.
  /// Returns true if the credentials were saved successfully, false otherwise.
  Future<bool> save({required TwitchEbsCredentials credentials});

  ///
  /// Load the Twitch credentials of a user.
  /// Returns null if no credentials are found.
  Future<TwitchEbsCredentials?> load({required String userId});
}

class TwitchEbsCredentialsStorageInMemory
    implements TwitchEbsCredentialsStorage {
  final Map<String, TwitchEbsCredentials> _storage = {};

  @override
  Future<bool> save({required TwitchEbsCredentials credentials}) async {
    _storage[credentials.userId] = credentials;
    return true;
  }

  @override
  Future<TwitchEbsCredentials?> load({required String userId}) async {
    return _storage[userId];
  }
}

class TwitchEbsCredentialsStorageSqlite implements TwitchEbsCredentialsStorage {
  final String databasePath;

  TwitchEbsCredentialsStorageSqlite({required this.databasePath});

  @override
  Future<bool> save({required TwitchEbsCredentials credentials}) async {
    try {
      final db = sqlite3.open(databasePath);
      db.execute('''
      CREATE TABLE IF NOT EXISTS twitch_ebs_credentials (
        user_id TEXT NOT NULL PRIMARY KEY,
        access_token TEXT NOT NULL,
        refresh_token TEXT NOT NULL
      );
    ''');

      // Update the new credentials
      final stmt = db.prepare('''
      INSERT INTO twitch_ebs_credentials (user_id, access_token, refresh_token)
      VALUES (?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET
        access_token = excluded.access_token,
        refresh_token = excluded.refresh_token;
    ''');
      stmt.execute([
        credentials.userId,
        credentials.accessToken,
        credentials.refreshToken,
      ]);
      stmt.dispose();
      db.dispose();
      return true;
    } catch (e) {
      _logger.severe('Failed to save Twitch EBS credentials: $e');
      return false;
    }
  }

  @override
  Future<TwitchEbsCredentials?> load({required String userId}) async {
    try {
      final db = sqlite3.open(databasePath);
      final stmt = db.prepare('''
      SELECT access_token, refresh_token FROM twitch_ebs_credentials
      WHERE user_id = ?;
    ''');
      final result = stmt.select([userId]);
      stmt.dispose();
      db.dispose();

      if (result.isEmpty) return null;
      return TwitchEbsCredentials(
        userId: userId,
        accessToken: result.first['access_token'] as String,
        refreshToken: result.first['refresh_token'] as String,
      );
    } catch (e) {
      _logger.severe('Failed to load Twitch EBS credentials: $e');
      rethrow;
    }
  }
}
