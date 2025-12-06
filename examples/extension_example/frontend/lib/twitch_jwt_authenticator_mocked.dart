import 'dart:async';
import 'dart:math';

import 'package:common/common.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:twitch_manager/common/communication_protocols.dart';
import 'package:twitch_manager/common/twitch_authenticator.dart';
import 'package:twitch_manager/frontend/twitch_frontend_info.dart';

///
/// The JWT key is for the Frontend of a Twitch extension.
class TwitchJwtAuthenticatorMocked extends TwitchJwtAuthenticator {
  TwitchJwtAuthenticatorMocked();

  ///
  /// The [ebsToken] is a token that is used to authenticate that the user is
  /// an authenticated Twitch user when communicating with the EBS to the Twitch API.
  /// This is normally automatically fetched by the TwitchManager, but in case
  /// of a mock, it cannot be retrieved.
  @override
  AppToken? get ebsToken {
    return AppToken.fromSerialized(
      JWT({
        'channel_id': channelId,
        'opaque_user_id': opaqueUserId,
        'user_id': userId,
      }).sign(
        SecretKey(ConfigService.mockedSharedSecret, isBase64Encoded: true),
      ),
    );
  }

  ///
  /// The id of the channel that the frontend is connected to
  @override
  String get channelId => '1234567890';

  ///
  /// The obfuscted user id of the frontend
  @override
  String get opaqueUserId => 'MyMockedOpaqueUserId';

  ///
  /// The non-obfuscated user id of the frontend. This required [isTwitchUserIdRequired]
  /// to be true when calling the [connect] method
  final _userId = (Random().nextInt(8000000) + 1000000000).toString();
  @override
  String? get userId => _userId;

  @override
  void requestIdShare() {
    // Do nothing
  }

  bool _isConnected = false;
  @override
  bool get isConnected => _isConnected;
  @override
  Future<void> connect({
    required TwitchFrontendInfo appInfo,
    bool isTwitchUserIdRequired = false,
  }) async {
    // Do nothing, as this is a mock
    _isConnected = true;
    // But still notify the listeners that connection to Twitch is done
    onHasConnected.notifyListeners((callback) => callback());
  }

  @override
  Future<void> listenToPubSub(
    String target,
    Function(MessageProtocol message) callback,
  ) async {
    // Do nothing, as this is a mock
  }
}
