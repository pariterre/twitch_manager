import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';

import 'twitch_manager.dart';

// Define some constant from Twitch itself
const _ircServerAddress = 'irc.chat.twitch.tv';
const _ircPort = 6667;
const _regexpMessage = r'^:(.*)!.*@.*PRIVMSG.*#.*:(.*)$';

class TwitchIrc {
  String get chatbotUsername => _chatbot?.username ?? _streamer.username;
  final TwitchUser _streamer;
  final TwitchUser? _chatbot;

  Socket _socket;
  bool isConnected = false;

  Function(String sender, String message)? messageCallback;
  Function(String message)? twitchCallback;

  ///
  /// Main constructor
  ///
  static Future<TwitchIrc> factory(
      {required TwitchUser streamer, TwitchUser? chatbot}) async {
    return TwitchIrc._(await _getConnectedSocket(), streamer, chatbot);
  }

  static Future<Socket> _getConnectedSocket() async {
    bool socketIsConnected = false;
    late Socket socket;
    int retryCounter = 0;
    while (!socketIsConnected) {
      try {
        socket = await Socket.connect(_ircServerAddress, _ircPort);
        socketIsConnected = true;
      } on SocketException {
        // Retry after some time
        log('Connection reset by peer, retry attempt $retryCounter');
        await Future.delayed(const Duration(seconds: 5));
        if (retryCounter > 5) throw 'Cannot connect to socket';
        retryCounter++;
      }
    }
    return socket;
  }

  ///
  /// Private constructor
  ///
  TwitchIrc._(this._socket, this._streamer, this._chatbot) {
    _connect(_chatbot ?? _streamer);
  }

  ///
  /// Send a [message] to the chat of the channel
  ///
  void send(String message) {
    _send('PRIVMSG #$chatbotUsername :$message');
  }

  ///
  /// Send a message to Twitch IRC. If connection failed it tries another time.
  ///
  void _send(String command) async {
    try {
      _socket.write('$command\n');
    } on SocketException {
      _socket = await _getConnectedSocket();
      _send(command);
      return;
    }
  }

  ///
  /// Connect to Twitch IRC. If a socket exception is raised try another time.
  void _connect(TwitchUser user) async {
    try {
      _socket.listen(_messageReceived);
    } on SocketException {
      // Wait for some time and reconnect
      _socket = await _getConnectedSocket();
      _connect(user);
      return;
    }
    isConnected = true;

    _send('PASS oauth:${user.oauthKey}');
    _send('NICK $chatbotUsername');
    _send('JOIN #${_streamer.username}');
  }

  ///
  /// Disconnect to Twitch IRC
  Future<void> disconnect() async {
    _send('PART $chatbotUsername');

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
