import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:twitch_manager/common/twitch_user.dart';
import 'package:twitch_manager/ebs/twitch_ebs_info.dart';
import 'package:twitch_manager/utils/http_extension.dart';
import 'package:twitch_manager/utils/twitch_mutex.dart';

final _logger = Logger('TwitchEbsApi');

class _Bearer {
  final String token;
  final DateTime expiration;

  _Bearer(this.token, {required this.expiration});

  bool get isExpired => DateTime.now().isAfter(expiration);
}

class TwitchEbsApi {
  // Prepare the singleton instance
  static TwitchEbsApi? _instance;
  static TwitchEbsApi get instance {
    if (_instance == null) {
      _logger.severe(
          'TwitchManagerExtension is not initialized, call initialize() first');
      throw Exception(
          'TwitchManagerExtension is not initialized, call initialize() first');
    }
    return _instance!;
  }

  static Future<void> initialize({
    required String broadcasterId,
    required TwitchEbsInfo ebsInfo,
  }) async {
    if (_instance != null) {
      _logger.severe('TwitchManagerExtension is already initialized');
      throw Exception('TwitchManagerExtension is already initialized');
    }

    _instance = TwitchEbsApi._(broadcasterId: broadcasterId, ebsInfo: ebsInfo);
  }

  static Future<void> initializeMocker({
    required String broadcasterId,
    required TwitchEbsInfo ebsInfo,
    required TwitchEbsApi twitchEbsApi,
  }) async {
    if (TwitchEbsApi._instance != null) {
      _logger.severe('TwitchManagerExtension is already initialized');
      throw Exception('TwitchManagerExtension is already initialized');
    }

    TwitchEbsApi._instance = twitchEbsApi;
  }

  TwitchEbsApi._({required this.broadcasterId, required this.ebsInfo});

  final String broadcasterId;
  final TwitchEbsInfo ebsInfo;

  ///
  /// Cache of users used by the user() method
  final _usersCache = <TwitchUser>[];
  final _usersCacheMutex = TwitchMutex<TwitchUser?>();

  ///
  /// Get the user info, identified by either [userId] or [login].
  Future<TwitchUser?> user({String? userId, String? login}) async {
    if (userId == null && login == null) {
      throw 'Either userId or login must be provided';
    } else if (userId != null && login != null) {
      throw 'Only one of userId or login must be provided';
    }

    return await _usersCacheMutex.runGuarded(() async {
      final cachedUser = _usersCache.from(userId: userId, login: login);
      if (cachedUser != null) {
        _logger.fine('User $cachedUser found in cache');
        return cachedUser;
      }

      final category = userId != null ? 'id' : 'login';
      final identifier = userId ?? login!;

      _logger.fine('Getting user info for user $identifier using $category...');

      final bearer = await _getExtensionBearerToken();
      final response = await _getApiRequest(
          endPoint: 'helix/users',
          bearer: bearer,
          queryParameters: {category: identifier});
      if (response.statusCode != 200) throw 'Error: ${response.statusCode}';

      final data = json.decode(response.body)['data'][0];
      try {
        final user = TwitchUser(
            userId: data['id'],
            login: data['login'],
            displayName: data['display_name']);
        _usersCache.add(user);
        _logger.fine('Display name for user $identifier is $user');
        return user;
      } catch (e) {
        _logger
            .warning('Error while parsing user info for user $identifier: $e');
        return null;
      }
    });
  }

  ///
  /// Get the login for a given [userId].
  Future<String?> login({required String userId}) async {
    _logger.fine('Getting login for user $userId...');
    final fetchedUser = await user(userId: userId);
    return fetchedUser?.login;
  }

  ///
  /// Get the user id for a given [login].
  Future<String?> userId({required String login}) async {
    _logger.fine('Getting user id for login $login...');
    final fetchedUser = await user(login: login);
    return fetchedUser?.userId;
  }

  ///
  /// Get the display name for a given [userId] or [login].
  Future<String?> displayName({String? userId, String? login}) async {
    _logger.fine('Getting display name for user $userId...');
    final fetchedUser = await user(userId: userId, login: login);
    return fetchedUser?.displayName;
  }

  ///
  /// Return the current extension version that the streamer is using. If the
  /// extension is not active, return `null`.
  Future<String?> activeExtensionVersion() async {
    try {
      final bearer = await _getExtensionBearerToken();
      final response = await _getApiRequest(
          endPoint: 'helix/users/extensions',
          bearer: bearer,
          queryParameters: {'user_id': broadcasterId});
      if (response.statusCode != 200) throw 'Error: ${response.statusCode}';

      final body = json.decode(response.body);
      final data =
          (body as Map<String, dynamic>?)?['data'] as Map<String, dynamic>?;
      if (data?.isEmpty ?? true) return null;

      for (final key in ['panel', 'overlay', 'component']) {
        final positions = data![key] as Map<String, dynamic>?;
        for (final item in positions?.values ?? []) {
          if (item['active'] == true && item['id'] == ebsInfo.extensionId) {
            return item['version'];
          }
        }
      }

      return null;
    } catch (e) {
      _logger.severe('Error checking if extension is active: $e');
      return null;
    }
  }

  Future<http.Response> sendChatMessage(String message,
      {bool sendUnderExtensionName = true}) async {
    try {
      if (ebsInfo.extensionVersion == null) {
        throw ArgumentError('Extension version is required to send chat '
            'messages, please provide one in the TwitchEbsInfo');
      }

      return await _postApiRequest(
        endPoint: sendUnderExtensionName
            ? 'helix/extensions/chat'
            : 'helix/chat/messages',
        bearer: sendUnderExtensionName
            ? await _getSharedBearerToken()
            : await _getExtensionBearerToken(),
        queryParameters: {'broadcaster_id': broadcasterId},
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
          'broadcaster_id': broadcasterId,
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
    final response = await timedHttpGet(
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
    final response = await timedHttpPost(
        Uri.https('api.twitch.tv', endPoint, queryParameters),
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
    if (ebsInfo.extensionApiClientSecret == null) {
      throw ArgumentError('Extension secret is required, please generate one '
          'from the Twitch developer console');
    }

    if (_extensionBearer == null) {
      final response =
          await timedHttpPost(Uri.https('id.twitch.tv', 'oauth2/token'), body: {
        'client_id': ebsInfo.extensionId,
        'client_secret': ebsInfo.extensionApiClientSecret,
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
        'user_id': broadcasterId,
        'role': 'external',
        'exp': (DateTime.now().add(const Duration(days: 1)))
            .millisecondsSinceEpoch,
        'channel_id': broadcasterId,
        'pubsub_perms': {
          'send': ['broadcast']
        }
      });
      _sharedBearerToken = _Bearer(
          jwt.sign(
              SecretKey(ebsInfo.extensionSharedSecret!, isBase64Encoded: true),
              expiresIn: const Duration(days: 1)),
          expiration: DateTime.now().add(const Duration(days: 1)));
    }
    return _sharedBearerToken!.token;
  }
}

class TwitchEbsApiMockerTemplate extends TwitchEbsApi {
  TwitchEbsApiMockerTemplate(
      {required super.broadcasterId, required super.ebsInfo})
      : super._();
}
