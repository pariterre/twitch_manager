import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:twitch_manager/twitch_ebs.dart';

///
/// This is an example of how to muck Twitch API calls so you can test your
/// extension without having to send actual http requests to Twitch.
class MockedTwitchApi extends MockedTwitchApiTemplate {
  static Future<void> initialize({
    required int broadcasterId,
    required TwitchEbsInfo ebsInfo,
  }) async => TwitchApi.initializeMocker(
    broadcasterId: broadcasterId,
    ebsInfo: ebsInfo,
    mockedTwitchApi: MockedTwitchApi(
      broadcasterId: broadcasterId,
      ebsInfo: ebsInfo,
    ),
  );

  MockedTwitchApi({required super.broadcasterId, required super.ebsInfo});

  final _random = Random();
  final _players = <Map<String, dynamic>>[];

  Map<String, dynamic> _addRandomUser({
    int? userId,
    String? login,
    String? displayName,
  }) {
    final id = userId ?? _random.nextInt(1000000) + 1000000;
    final name = login ?? 'user$id';
    final display = displayName ?? 'User $id';

    final newUser = {'id': id, 'login': name, 'display_name': display};
    _players.add(newUser);
    return newUser;
  }

  @override
  Future<int?> userId({required String login}) async => _players.firstWhere(
    (player) => player['login'] == login,
    orElse: () => _addRandomUser(login: login),
  )['id'];

  @override
  Future<String?> login({required int userId}) async => _players.firstWhere(
    (player) => player['id'] == userId,
    orElse: () => _addRandomUser(userId: userId),
  )['login'];

  @override
  Future<String?> displayName({required int userId}) async =>
      _players.firstWhere(
        (player) => player['id'] == userId,
        orElse: () => _addRandomUser(userId: userId),
      )['display_name'];

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
