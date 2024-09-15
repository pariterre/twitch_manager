import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:twitch_manager/models/twitch_info.dart';

class TwitchEbsManager {
  final TwitchEbsInfo ebsInfo;

  ///
  /// Prepare the singleton instance
  static TwitchEbsManager? _instance;
  TwitchEbsManager._({required this.ebsInfo});
  static TwitchEbsManager get instance {
    if (_instance == null) {
      throw Exception(
          'TwitchExtensionManager is not initialized, call TwitchExtensionManager.initialize() first');
    }
    return _instance!;
  }

  ///
  /// Main initialization method. This must be called before using the [instance]
  static Future<void> initialize({required TwitchEbsInfo ebsInfo}) async {
    if (_instance != null) {
      throw Exception('TwitchExtensionManager is already initialized');
    }
    _instance = TwitchEbsManager._(ebsInfo: ebsInfo);
  }

  ///
  /// Verify and decode a JWT token
  JWT verifyAndDecode(String jwt) {
    return JWT.verify(
        jwt, SecretKey(ebsInfo.extensionSecret, isBase64Encoded: true));
  }
}
