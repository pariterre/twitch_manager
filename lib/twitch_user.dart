import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:twitch_manager/twitch_app_info.dart';

import 'twitch_manager.dart';

class TwitchAuthenticator {
  String? streamer;
  String? streamerOauthKey;
  bool hasChatbot;
  String? chatbot;
  String? chatbotOauthKey;

  bool _isStreamerConnected = false;
  bool get isStreamerConnected => _isStreamerConnected;
  bool _isChatbotConnected = false;
  bool get isChatbotConnected => _isChatbotConnected;

  ///
  /// [oauthKey] is the OAUTH key. If none is provided, the process to generate
  /// one is launched.
  /// [streamerUsername] is the name of the channel to connect
  /// [chatbotUsername] is the name of the current logged in chat bot. If it is
  /// left empty [streamerUsername] is used.
  /// [scope] is the required scope of the current app. Comes into play if
  /// generate OAUTH is launched.
  ///
  TwitchAuthenticator({
    required TwitchAppInfo appInfo,
    required this.hasChatbot,
    this.streamer,
    this.streamerOauthKey,
    this.chatbot,
    this.chatbotOauthKey,
    required Future<void> Function(String address) onRequestBrowsing,
  }) {
    _connectAll(
        appInfo: appInfo,
        onRequestBrowsing: (_) async {
          return;
        });
  }

  ///
  /// Helpers for saving to a Json file
  Map<String, dynamic> _serialize() => {
        'hasChatbot': hasChatbot,
        'streamerOauthKey': streamerOauthKey,
        'chatbotOauthKey': chatbotOauthKey,
      };

  Future<void> loadPreviousSession({required TwitchAppInfo appInfo}) async {
    final savePath = await getApplicationDocumentsDirectory();
    final credentialFile = File('$savePath/.credentials.json');

    if (!await credentialFile.exists()) return;

    late final dynamic usersMap;
    try {
      usersMap = jsonDecode(await credentialFile.readAsString())
          as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    hasChatbot = usersMap['hasChatbot'];
    streamerOauthKey = usersMap['streamerOauthKey'];
    chatbotOauthKey = usersMap['chatbotOauthKey'];
    _connectAll(appInfo: appInfo, onRequestBrowsing: (_) async {});
  }

  ///
  /// Prepare everything which is required when connecting with Twitch API
  /// [onRequestBrowsing] provides a website that the user must navigate to in
  /// order to authenticate; [onInvalidToken] is the callback if token is found
  /// to be invalid; [onSuccess] is the callback if everything went well; if
  /// [retry] is set to true, the connexion will retry if it fails.
  Future<bool> connectStreamer({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String address) onRequestBrowsing,
    bool retry = true,
  }) async {
    if (_isStreamerConnected) return true;

    streamerOauthKey ??= await TwitchApi.getNewOauth(
        appInfo: appInfo, onRequestBrowsing: onRequestBrowsing);

    _isStreamerConnected = await TwitchApi.validateToken(
        appInfo: appInfo, oauthKey: streamerOauthKey!);
    if (!_isStreamerConnected) {
      if (!retry) return false;

      // If we can't validate, we should drop the oauth key and generate a new one
      streamerOauthKey = null;
      return connectStreamer(
        appInfo: appInfo,
        onRequestBrowsing: onRequestBrowsing,
        retry: false,
      );
    }

    // If everything goes as planned, set a validation every hours and exit
    Timer.periodic(
        const Duration(hours: 1),
        (timer) => TwitchApi.validateToken(
            appInfo: appInfo, oauthKey: streamerOauthKey!));

    return _isStreamerConnected;
  }

  Future<bool> connectChatbot({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String address) onRequestBrowsing,
    bool retry = true,
  }) async {
    _isChatbotConnected = true;
    return true;
  }

  void _connectAll({
    required TwitchAppInfo appInfo,
    required Future<void> Function(String address) onRequestBrowsing,
  }) {
    if (streamerOauthKey != null) {
      connectStreamer(appInfo: appInfo, onRequestBrowsing: onRequestBrowsing);
    }
    if (hasChatbot && chatbotOauthKey != null) {
      connectChatbot(appInfo: appInfo, onRequestBrowsing: onRequestBrowsing);
    }
  }
}
