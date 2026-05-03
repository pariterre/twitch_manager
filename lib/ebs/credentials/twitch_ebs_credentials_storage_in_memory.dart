import 'package:twitch_manager/ebs/credentials/twitch_ebs_credentials.dart';
import 'package:twitch_manager/ebs/credentials/twitch_ebs_credentials_storage.dart';

class TwitchEbsCredentialsStorageInMemory
    implements TwitchEbsCredentialsStorage {
  final Map<String, TwitchEbsCredentials> _storage = {};

  @override
  bool get isConnected => true;

  @override
  Future<void> dispose() {
    _storage.clear();
    return Future.value();
  }

  @override
  Future<bool> save({required TwitchEbsCredentials credentials}) {
    _storage[credentials.userId] = credentials;
    return Future.value(true);
  }

  @override
  Future<TwitchEbsCredentials?> load({required String userId}) {
    return Future.value(_storage[userId]);
  }
}
