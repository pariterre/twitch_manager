import 'package:twitch_manager/ebs/credentials/twitch_ebs_credentials.dart';
import 'package:twitch_manager/ebs/credentials/twitch_ebs_credentials_storage.dart';

class TwitchEbsCredentialsStorageInMemory
    implements TwitchEbsCredentialsStorage {
  final Map<String, TwitchEbsCredentials> _storage = {};

  @override
  bool get isConnected => true;

  @override
  Future<void> dispose() async {
    _storage.clear();
  }

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
