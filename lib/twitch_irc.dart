import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';

import 'twitch_manager.dart';

// Define some constant from Twitch itself
const _ircServerAddress = 'irc.chat.twitch.tv';
const _ircPort = 6667;
const _regexpMessage = r'^:(.*)!.*@.*PRIVMSG.*#.*:(.*)$';

class TwitchIrc {
  String get moderatorUsername => _authentication.moderatorUsername;
  final TwitchAuthentication _authentication;

  final Socket _socket;
  bool isConnected = false;

  Function(String sender, String message)? messageCallback;
  Function(String message)? twitchCallback;

  ///
  /// Main constructor
  ///
  static Future<TwitchIrc> factory(TwitchAuthentication authentication) async {
    return TwitchIrc._(
        await Socket.connect(_ircServerAddress, _ircPort), authentication);
  }

  ///
  /// Private constructor
  ///
  TwitchIrc._(this._socket, this._authentication) {
    _connect(_authentication);
  }

  ///
  /// Send a [message] to the chat of the channel
  ///
  void send(String message) {
    _send('PRIVMSG #${_authentication.streamerUsername} :$message');
  }

  ///
  /// Send a message to Twitch IRC
  ///
  void _send(String command) {
    _socket.write('$command\n');
  }

  ///
  /// Connect to Twitch IRC
  void _connect(TwitchAuthentication authenticator) {
    _socket.listen(_messageReceived);
    isConnected = true;

    _send('PASS oauth:${authenticator.oauthKey}');
    _send('NICK ${_authentication.moderatorUsername}');
    _send('JOIN #${_authentication.streamerUsername}');
  }

  ///
  /// Disconnect to Twitch IRC
  Future<void> disconnect() async {
    _send('PART ${_authentication.streamerUsername}');

    await _socket.close();
    isConnected = false;
  }

  ///
  /// This method is called each time a new message is sent
  ///
  void _messageReceived(Uint8List data) {
    var fullMessage = String.fromCharCodes(data);
    // Remove the line returns
    if (fullMessage[fullMessage.length - 1] == '\n') {
      fullMessage = fullMessage.substring(0, fullMessage.length - 1);
    }
    if (fullMessage[fullMessage.length - 1] == '\r') {
      fullMessage = fullMessage.substring(0, fullMessage.length - 1);
    }

    if (fullMessage == 'PING :tmi.twitch.tv') {
      // Keep connexion alive
      log(fullMessage);
      _send('PONG :tmi.twitch.tv');
      log('PONG');
      return;
    }

    final re = RegExp(_regexpMessage);
    final match = re.firstMatch(fullMessage);
    // If this is an unrecognized format, log and call fallback
    if (match == null || match.groupCount != 2) {
      log(fullMessage);
      if (twitchCallback != null) twitchCallback!(fullMessage);
      return;
    }

    // If this is a message from the chat
    final sender = match.group(1)!;
    final message = match.group(2)!;
    log('Message received:\n$sender: $message');
    if (messageCallback != null) messageCallback!(sender, message);
  }
}
