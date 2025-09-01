import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:twitch_manager/ebs/credentials/twitch_ebs_credentials.dart';
import 'package:twitch_manager/ebs/credentials/twitch_ebs_credentials_storage.dart';

final _logger = Logger('TwitchEbsCredentialsStorage');

class TwitchEbsCredentialsStorageSqlite extends TwitchEbsCredentialsStorage {
  late final Database _db;

  TwitchEbsCredentialsStorageSqlite({
    required String databasePath,
    String? pragmaKey,
  }) {
    _db = sqlite3.open(databasePath);
    if (pragmaKey != null) _db.execute('PRAGMA key = "$pragmaKey";');

    _isConnected = true;
  }

  bool _isConnected = false;
  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> dispose() async {
    if (_isConnected) {
      _db.dispose();
      _isConnected = false;
    }
  }

  @override
  Future<bool> save({required TwitchEbsCredentials credentials}) async {
    try {
      if (!_isConnected) {
        _logger.severe('Database is not connected');
        throw Exception('Database is not connected');
      }

      _db.execute('''
        CREATE TABLE IF NOT EXISTS twitch_ebs_credentials (
          user_id TEXT NOT NULL PRIMARY KEY,
          access_token TEXT NOT NULL,
          refresh_token TEXT NOT NULL
        );
        ''');

      // Update the new credentials
      final stmt = _db.prepare('''
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
      return true;
    } catch (e) {
      _logger.severe('Failed to save Twitch EBS credentials: $e');
      return false;
    }
  }

  @override
  Future<TwitchEbsCredentials?> load({required String userId}) async {
    try {
      if (!_isConnected) {
        _logger.severe('Database is not connected');
        throw Exception('Database is not connected');
      }

      final stmt = _db.prepare('''
        SELECT access_token, refresh_token 
        FROM twitch_ebs_credentials
        WHERE user_id = ?;
      ''');
      final result = stmt.select([userId]);
      stmt.dispose();

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
