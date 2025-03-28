import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:twitch_manager/ebs/twitch_ebs_info.dart';

final _logger = Logger('TwitchApi');

class _Bearer {
  final String token;
  final DateTime expiration;

  _Bearer(this.token, {required this.expiration});

  bool get isExpired => DateTime.now().isAfter(expiration);
}

class TwitchApi {
  // Prepare the singleton instance
  static TwitchApi? _instance;
  static TwitchApi get instance {
    if (_instance == null) {
      _logger.severe(
          'TwitchManagerExtension is not initialized, call initialize() first');
      throw Exception(
          'TwitchManagerExtension is not initialized, call initialize() first');
    }
    return _instance!;
  }

  static Future<void> initialize({
    required int broadcasterId,
    required TwitchEbsInfo ebsInfo,
  }) async {
    if (_instance != null) {
      _logger.severe('TwitchManagerExtension is already initialized');
      throw Exception('TwitchManagerExtension is already initialized');
    }

    _instance = TwitchApi._(broadcasterId: broadcasterId, ebsInfo: ebsInfo);
  }

  TwitchApi._({required this.broadcasterId, required this.ebsInfo});

  final int broadcasterId;
  final TwitchEbsInfo ebsInfo;

  Future<int?> userId({required String login}) async {
    try {
      final bearer = await _getExtensionBearerToken();
      final response = await _getApiRequest(
          endPoint: 'helix/users',
          bearer: bearer,
          queryParameters: {'login': login});

      return int.parse(json.decode(response.body)['data'][0]['id']);
    } catch (e) {
      _logger.severe('Error getting user id: $e');
      return null;
    }
  }

  Future<String?> displayName({required int userId}) async {
    try {
      final bearer = await _getExtensionBearerToken();
      final response = await _getApiRequest(
          endPoint: 'helix/users',
          bearer: bearer,
          queryParameters: {'id': userId.toString()});

      return json.decode(response.body)['data'][0]['display_name'];
    } catch (e) {
      _logger.severe('Error getting display name: $e');
      return null;
    }
  }

  Future<String?> login({required int userId}) async {
    try {
      final bearer = await _getExtensionBearerToken();
      final response = await _getApiRequest(
          endPoint: 'helix/users',
          bearer: bearer,
          queryParameters: {'id': userId.toString()});

      return json.decode(response.body)['data'][0]['login'];
    } catch (e) {
      _logger.severe('Error getting login: $e');
      return null;
    }
  }

  Future<http.Response> sendChatMessage(String message,
      {bool sendUnderExtensionName = true}) async {
    try {
      return await _postApiRequest(
        endPoint: sendUnderExtensionName
            ? 'helix/extensions/chat'
            : 'helix/chat/messages',
        bearer: sendUnderExtensionName
            ? await _getSharedBearerToken()
            : await _getExtensionBearerToken(),
        queryParameters: {'broadcaster_id': broadcasterId.toString()},
        body: {
          'text': message,
          'extension_id': ebsInfo.extensionId,
          'extension_version': ebsInfo.extensionVersion,
        },
      );
    } catch (e) {
      _logger.severe('Error sending chat message: $e');
      return http.Response('Error', 500);
    }
  }

  Future<http.Response> sendPubsubMessage(Map<String, dynamic> message) async {
    try {
      return await _postApiRequest(
        endPoint: 'helix/extensions/pubsub',
        bearer: await _getSharedBearerToken(),
        body: {
          'message': jsonEncode(message).replaceAll('"', '\''),
          'broadcaster_id': broadcasterId.toString(),
          'target': ['broadcast']
        },
      );
    } catch (e) {
      _logger.severe('Error sending pubsub message: $e');
      return http.Response('Error', 500);
    }
  }

  Future<http.Response> _getApiRequest({
    required String endPoint,
    required String bearer,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await http.get(
        Uri.https('api.twitch.tv', endPoint, queryParameters),
        headers: <String, String>{
          HttpHeaders.authorizationHeader: 'Bearer $bearer',
          'Client-Id': ebsInfo.extensionId,
          HttpHeaders.contentTypeHeader: 'application/json',
        });

    return response;
  }

  Future<http.Response> _postApiRequest({
    required String endPoint,
    required String bearer,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final response =
        await http.post(Uri.https('api.twitch.tv', endPoint, queryParameters),
            headers: <String, String>{
              HttpHeaders.authorizationHeader: 'Bearer $bearer',
              'Client-Id': ebsInfo.extensionId,
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: json.encode(body));

    return response;
  }

  _Bearer? _extensionBearer;
  Future<String> _getExtensionBearerToken() async {
    if (ebsInfo.extensionSecret == null) {
      throw ArgumentError('Extension secret is required, please generate one '
          'from the Twitch developer console');
    }

    if (_extensionBearer == null) {
      final response =
          await http.post(Uri.https('id.twitch.tv', 'oauth2/token'), body: {
        'client_id': ebsInfo.extensionId,
        'client_secret': ebsInfo.extensionSecret,
        'grant_type': 'client_credentials',
      });
      final data = json.decode(response.body);
      if (data['access_token'] == null) {
        throw Exception('Error getting extension bearer token ($data)');
      }
      _extensionBearer = _Bearer(data['access_token'],
          expiration:
              DateTime.now().add(Duration(seconds: data['expires_in'])));
    }
    return _extensionBearer!.token;
  }

  _Bearer? _sharedBearerToken;
  Future<String> _getSharedBearerToken() async {
    if (_sharedBearerToken == null || _sharedBearerToken!.isExpired) {
      final jwt = JWT({
        'user_id': broadcasterId.toString(),
        'role': 'external',
        'exp': (DateTime.now().add(const Duration(days: 1)))
            .millisecondsSinceEpoch,
        'channel_id': broadcasterId.toString(),
        'pubsub_perms': {
          'send': ['broadcast']
        }
      });
      _sharedBearerToken = _Bearer(
          jwt.sign(SecretKey(ebsInfo.sharedSecret!, isBase64Encoded: true),
              expiresIn: const Duration(days: 1)),
          expiration: DateTime.now().add(const Duration(days: 1)));
    }
    return _sharedBearerToken!.token;
  }
}
