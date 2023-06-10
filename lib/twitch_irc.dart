import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';

import 'twitch_manager.dart';

// Define some constant from Twitch itself
const _ircServerAddress = 'irc.chat.twitch.tv';
const _ircPort = 6667;
const _regexpMessage = r'^:(.*)!.*@.*PRIVMSG.*#.*:(.*)$';

class TwitchIrc {
  ///
  /// Callback to register to which is called when a message is received.
  Function(String sender, String message)? messageCallback;

  ///
  /// Callback to register to which is called when any communication which is
  /// not a message from a user to the chat is received
  Function(String message)? twitchCommunicationCallback;

  ///
  /// Send a [message] to the chat
  void send(String message) {
    _send('PRIVMSG #$_username :$message');
  }

  ///
  /// Disconnect to Twitch IRC
  Future<void> disconnect() async {
    _send('PART $_username');

    await _socket.close();
  }

  /// ATTRIBUTES
  final TwitchAuthenticator _authenticator;
  String get _username => _authenticator.streamer!;
  String get _oauthKey =>
      _authenticator.chatbotOauthKey ?? _authenticator.streamerOauthKey!;
  Socket _socket;

  ///
  /// Main constructor
  ///
  static Future<TwitchIrc> factory(TwitchAuthenticator authenticator) async {
    return TwitchIrc._(await _getConnectedSocket(), authenticator);
  }

  ///
  /// Private constructor
  ///
  TwitchIrc._(this._socket, this._authenticator) {
    _connect(_authenticator);
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
  /// Establish a connexion with the Twitch IRC channel
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
  /// Connect to Twitch IRC channel.
  void _connect(TwitchAuthenticator authenticator) async {
    try {
      _socket.listen(_messageReceived);
    } on SocketException {
      // Wait for some time and reconnect
      _socket = await _getConnectedSocket();
      _connect(authenticator);
      return;
    }

    _send('PASS oauth:$_oauthKey');
    _send('NICK $_username');
    _send('JOIN #${authenticator.streamer}');
  }

  ///
  /// This method is called each time a new message is received
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
      if (twitchCommunicationCallback != null) {
        twitchCommunicationCallback!(fullMessage);
      }
      return;
    }

    // If this is a message from the chat
    final sender = match.group(1)!;
    final message = match.group(2)!;
    log('Message received:\n$sender: $message');
    if (messageCallback != null) messageCallback!(sender, message);
  }
}
