import 'dart:developer';
import 'dart:io';

import 'package:twitch_manager/models/twitch_authenticator.dart';
import 'package:web_socket_client/web_socket_client.dart' as ws;

// Define some constant from Twitch itself
const _ircWebSocketServerAddress = 'wss://irc-ws.chat.twitch.tv:443';
const _regexpMessage = r'^:(.*)!.*@.*PRIVMSG.*#.*:(.*)$';

class TwitchIrc {
  bool _isConnected = false;

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
    _send('PRIVMSG #$streamerLogin :$message');
  }

  ///
  /// Disconnect to Twitch IRC
  Future<void> disconnect() async {
    if (!_isConnected) return;

    await _send('PART $streamerLogin');

    if (_socket == null) return;
    _socket!.close();
    _isConnected = false;
  }

  /// ATTRIBUTES
  final TwitchAuthenticator? _authenticator;
  final String streamerLogin;
  String get _oauthKey =>
      _authenticator!.chatbotOauthKey ?? _authenticator!.streamerOauthKey!;
  ws.WebSocket? _socket;

  ///
  /// Main constructor
  ///
  static Future<TwitchIrc> factory(
      {required String streamerLogin,
      required TwitchAuthenticator authenticator}) async {
    return TwitchIrc._(
        streamerLogin, await _getConnectedSocket(), authenticator);
  }

  ///
  /// Private constructor
  ///
  TwitchIrc._(this.streamerLogin, this._socket, this._authenticator) {
    _connect();
  }

  ///
  /// Send a message to Twitch IRC. If connection failed it tries another time.
  ///
  Future<void> _send(String command) async {
    if (!_isConnected) return;

    try {
      _socket!.send('$command\n');
    } on SocketException {
      _socket = await _getConnectedSocket();
      _send(command);
      return;
    }
  }

  ///
  /// Establish a connexion with the Twitch IRC channel
  static Future<ws.WebSocket> _getConnectedSocket() async {
    bool socketIsConnected = false;
    late ws.WebSocket socket;
    int retryCounter = 0;
    while (!socketIsConnected) {
      try {
        socket = ws.WebSocket(Uri.parse(_ircWebSocketServerAddress));
        await socket.connection.firstWhere((state) => state is ws.Connected);
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
  /// Connect to Twitch websocket.
  void _connect() async {
    try {
      _socket!.messages.listen(_messageReceived);
    } on SocketException {
      // Wait for some time and reconnect
      _socket = await _getConnectedSocket();
      _connect();
      return;
    }
    _connectToTwitchIrc();
  }

  ///
  /// Connect to the actual IRC channel
  void _connectToTwitchIrc() {
    _isConnected = true;
    _send('PASS oauth:$_oauthKey');
    _send('NICK $streamerLogin');
    _send('JOIN #$streamerLogin');
  }

  ///
  /// This method is called each time a new message is received
  void _messageReceived(event) {
    var fullMessage = event; //String.fromCharCodes(event);
    // Remove the line returns
    if (fullMessage[fullMessage.length - 1] == '\n') {
      fullMessage = fullMessage.substring(0, fullMessage.length - 1);
    }
    if (fullMessage[fullMessage.length - 1] == '\r') {
      fullMessage = fullMessage.substring(0, fullMessage.length - 1);
    }

    if (fullMessage == 'PING :tmi.twitch.tv') {
      if (!_isConnected) return;
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

class TwitchIrcMock extends TwitchIrc {
  @override
  String get _oauthKey => 'chatbotOauthKey';

  ///
  /// Main constructor
  ///
  static Future<TwitchIrcMock> factory({required String streamerLogin}) async =>
      TwitchIrcMock._(streamerLogin);

  ///
  /// Private constructor
  ///
  TwitchIrcMock._(String streamerLogin) : super._(streamerLogin, null, null);

  @override
  void _connect() async {
    _connectToTwitchIrc();
  }

  @override
  void send(String message, {String? username}) {
    // Normal behavior is that streamer sends a message, specifying a username
    // overrides this and mock a sent message from that user name
    final sender = username ?? streamerLogin;
    _send('PRIVMSG #$sender :$message');
  }

  @override
  Future<void> _send(String command) async {
    log(command);
    await Future.delayed(const Duration(seconds: 1));

    final re = RegExp(r'^PRIVMSG #(.*) :(.*)$');
    final match = re.firstMatch(command);
    if (match == null || match.groupCount != 2) return;

    final user = match.group(1);
    final message = match.group(2);

    _messageReceived(':$user!$user@PRIVMSG #$user:$message');
  }
}
