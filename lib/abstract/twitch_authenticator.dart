import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:twitch_manager/abstract/twitch_info.dart';
import 'package:twitch_manager/app/twitch_app_api.dart';
import 'package:twitch_manager/app/twitch_app_info.dart';
import 'package:twitch_manager/frontend/twitch_frontend_info.dart';
import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension.dart';
import 'package:twitch_manager/twitch_utils.dart';

part 'package:twitch_manager/app/twitch_app_authenticator.dart';
part 'package:twitch_manager/frontend/twitch_jwt_authenticator.dart';

final _logger = Logger('TwitchAuthenticator');

abstract class TwitchAuthenticator {
  ///
  /// The key to save the session
  final String? saveKeySuffix;

  ///
  /// Constructor of the Authenticator
  TwitchAuthenticator({this.saveKeySuffix = ''});

  ///
  /// The user bearer key
  String? _bearerKey;
  String? get bearerKey => _bearerKey;

  ///
  /// If the user is connected
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  ///
  /// Connect user to Twitch
  Future<void> connect({required TwitchInfo appInfo});

  ///
  /// Disconnect user from Twitch and clear the reload history
  Future<void> disconnect() async {
    _logger.info('Disconnecting from Twitch');
    _bearerKey = null;
    _isConnected = false;
    // Prevent from being able to reload
    await clearSession();
  }

  ///
  /// Save a session for further reloading.
  /// It is saved with the specified [saveKeySuffix] suffix which can be used to
  /// reload a specific session.
  Future<void> _saveSessions() async {
    _logger.config('Saving key');
    const storage = FlutterSecureStorage();
    storage.write(key: 'bearer$saveKeySuffix', value: bearerKey);
  }

  ///
  /// Helper to load a saved file.
  /// It is saved with the specified [saveKeySuffix] suffix so it can be later
  /// reloaded. If none is provided, then it is saved in a generic fashion.
  Future<void> loadSession() async {
    _logger.config('Loading session');
    _bearerKey = await _loadSession(key: 'bearer$saveKeySuffix');
  }

  ///
  /// Clear the keys of the saved sessions
  Future<void> clearSession() async {
    _logger.info('Clearing key');
    await _clearSession(key: 'bearer$saveKeySuffix');
  }
}

Future<String?> _loadSession({required String key}) async {
  const storage = FlutterSecureStorage();
  final bearerKey = await storage.read(key: key);
  return bearerKey != null && bearerKey.isNotEmpty ? bearerKey : null;
}

Future<void> _clearSession({required String key}) async {
  const storage = FlutterSecureStorage();
  await storage.write(key: key, value: '');
}
