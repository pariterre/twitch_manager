import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:twitch_manager/twitch_ebs.dart';

///
/// This is an example of how to muck Twitch API calls so you can test your
/// extension without having to send actual http requests to Twitch.
class TwitchEbsApiMocked extends TwitchEbsApiMockerTemplate {
  static Future<void> initialize({
    required String broadcasterId,
    required TwitchEbsInfo ebsInfo,
  }) async => TwitchEbsApi.initializeMocker(
    broadcasterId: broadcasterId,
    ebsInfo: ebsInfo,
    twitchEbsApi: TwitchEbsApiMocked(
      broadcasterId: broadcasterId,
      ebsInfo: ebsInfo,
    ),
  );

  TwitchEbsApiMocked({required super.broadcasterId, required super.ebsInfo});

  final _random = Random();
  final _users = <TwitchUser>[];

  @override
  Future<TwitchUser?> user({String? userId, String? login}) async =>
      _users.firstWhere(
        (player) =>
            (userId != null && player.userId == userId) ||
            (login != null && player.login == login),
        orElse: () => _addRandomUser(userId: userId, login: login),
      );

  TwitchUser _addRandomUser({
    String? userId,
    String? login,
    String? displayName,
  }) {
    userId ??= '${_random.nextInt(1000000) + 1000000}';
    login ??= 'user$userId';
    displayName ??= 'User $userId';

    final newUser = TwitchUser(
      userId: userId,
      login: login,
      displayName: displayName,
    );
    _users.add(newUser);
    return newUser;
  }

  ///
  /// Fake a successful API request
  @override
  Future<http.Response> sendPubsubMessage(Map<String, dynamic> message) async =>
      http.Response(
        '{"success": true, "message": "Pubsub message sent successfully"}',
        204,
        headers: {'Content-Type': 'application/json'},
      );
}
