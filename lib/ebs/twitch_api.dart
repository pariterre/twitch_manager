import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:twitch_manager/ebs/twitch_ebs_info.dart';

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
      throw Exception('TwitchManagerExtension is already initialized');
    }

    _instance =
        TwitchApi._internal(broadcasterId: broadcasterId, ebsInfo: ebsInfo);
  }

  TwitchApi._internal({required this.broadcasterId, required this.ebsInfo});

  final int broadcasterId;
  final TwitchEbsInfo ebsInfo;

  Future<Uri> getAuthorizationExtensionBearerUri() async {
    // Generate a random 16-bigs hexadecimal state
    final state = List.generate(16, (index) => Random().nextInt(16))
        .map((e) => e.toRadixString(16))
        .join();

    final authorizationUrl = Uri.https('id.twitch.tv', 'oauth2/authorize', {
      'response_type': 'code',
      'client_id': ebsInfo.extensionId,
      'redirect_uri': 'https://localhost',
      'scope': 'user:write:chat user:bot',
      'state': state,
    });

    // TODO Connect to the backend to get the code using an http get request
    // This should be done in the config page of the extension
    print('Navigate to the following URL to authorize the extension:');
    print(authorizationUrl);

    return authorizationUrl;
  }

  Future<int?> userId({required String login}) async {
    final bearer = await _getExtensionBearerToken();
    final response = await _getApiRequest(
        endPoint: 'helix/users',
        bearer: bearer,
        queryParameters: {'login': login});

    try {
      return int.parse(json.decode(response.body)['data'][0]['id']);
    } catch (e) {
      return null;
    }
  }

  Future<String?> displayName({required int userId}) async {
    final bearer = await _getExtensionBearerToken();
    final response = await _getApiRequest(
        endPoint: 'helix/users',
        bearer: bearer,
        queryParameters: {'id': userId.toString()});

    try {
      return json.decode(response.body)['data'][0]['display_name'];
    } catch (e) {
      return null;
    }
  }

  Future<String?> login({required int userId}) async {
    final bearer = await _getExtensionBearerToken();
    final response = await _getApiRequest(
        endPoint: 'helix/users',
        bearer: bearer,
        queryParameters: {'id': userId.toString()});

    try {
      return json.decode(response.body)['data'][0]['login'];
    } catch (e) {
      return null;
    }
  }

  Future<http.Response> sendChatMessage(String message,
      {bool sendUnderExtensionName = true}) async {
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
  }

  Future<http.Response> sendPubsubMessage(Map<String, dynamic> message) async {
    return await _postApiRequest(
      endPoint: 'helix/extensions/pubsub',
      bearer: await _getSharedBearerToken(),
      body: {
        'message': jsonEncode(message).replaceAll('"', '\''),
        'broadcaster_id': broadcasterId.toString(),
        'target': ['broadcast']
      },
    );
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
