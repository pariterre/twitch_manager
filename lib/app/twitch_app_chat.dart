import 'dart:io';

import 'package:logging/logging.dart';
import 'package:twitch_manager/abstract/twitch_authenticator.dart';
import 'package:twitch_manager/utils/twitch_listener.dart';
import 'package:web_socket_client/web_socket_client.dart' as ws;

// Define some constant from Twitch itself
const _ircWebSocketServerAddress = 'wss://irc-ws.chat.twitch.tv:443';
const _regexpMessage = r'^:(.*)!.*@.*PRIVMSG.*#.*:(.*)$';

final _logger = Logger('TwitchAppChat');

class TwitchAppChat {
  bool _isConnected = false;

  ///
  /// Access the listener to the chat messages.
  final onMessageReceived =
      TwitchListener<void Function(String sender, String message)>();

  ///
  /// List of active listeners to notify if a communication is received which is
  /// not a chat message (probably an error message from Twitch)
  final onInternalMessageReceived = TwitchListener<Function(String message)>();

  ///
  /// Send a [message] to the chat
  Future<void> send(String message) async =>
      await _send('PRIVMSG #$streamerLogin :$message');

  ///
  /// Disconnect to Twitch IRC channel
  Future<void> disconnect() async {
    _logger.info('Disconnecting from Twitch IRC channel...');

    // Remove the active listeners
    onMessageReceived.cancelAll();
    onInternalMessageReceived.cancelAll();

    if (!_isConnected) return;

    await _send('PART $streamerLogin');
    if (_socket != null) _socket!.close();

    _isConnected = false;

    _logger.info('Disconnected from Twitch IRC channel');
  }

  /// ATTRIBUTES
  final TwitchAppAuthenticator _authenticator;
  final String streamerLogin;
  String get _oauthKey =>
      _authenticator.chatbotBearerKey ?? _authenticator.bearerKey!;
  ws.WebSocket? _socket;

  ///
  /// Main constructor
  ///
  static Future<TwitchAppChat> factory(
      {required String streamerLogin,
      required TwitchAppAuthenticator authenticator}) async {
    _logger.config('Connecting to Twitch chat');
    return TwitchAppChat._(
        streamerLogin, await _getConnectedSocket(), authenticator);
  }

  ///
  /// Private constructor
  TwitchAppChat._(this.streamerLogin, this._socket, this._authenticator) {
    _connect();
  }

  ///
  /// Send a message to the Twitch IRC. If connection failed it tries another time.
  Future<void> _send(String command) async {
    _logger.info('Sending command: $command');

    if (!_isConnected) {
      _logger.warning('Cannot send message as we are not connected to Twitch');
      return;
    }

    try {
      _socket!.send('$command\n');
    } on SocketException {
      _logger.warning(
          'Connection reset by peer, trying to reconnect and to send again');
      _socket = await _getConnectedSocket();
      await _send(command);
      return;
    }
  }

  ///
  /// Establish a connexion with the Twitch IRC channel
  static Future<ws.WebSocket> _getConnectedSocket() async {
    _logger.info('Connecting to Twitch socket...');

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
        _logger
            .warning('Connection reset by peer, retry attempt $retryCounter');
        await Future.delayed(const Duration(seconds: 5));
        if (retryCounter > 5) throw 'Cannot connect to socket';
        retryCounter++;
      }
    }

    _logger.info('Connected to Twitch socket');
    return socket;
  }

  ///
  /// Connect to Twitch websocket.
  void _connect() async {
    _logger.info('Connecting to Twitch websocket...');
    try {
      _socket!.messages.listen(_messageReceived);
    } on SocketException {
      // Wait for some time and reconnect
      _logger.warning('Connection failed, retrying...');
      _socket = await _getConnectedSocket();
      _connect();
      return;
    }

    await _connectToTwitchIrc();
    _logger.info('Connected to Twitch websocket');
  }

  ///
  /// Connect to the actual IRC channel
  Future<void> _connectToTwitchIrc() async {
    _logger.info('Connecting to Twitch IRC channel...');
    _isConnected = true;
    await _send('PASS oauth:$_oauthKey');
    await _send('NICK $streamerLogin');
    await _send('JOIN #$streamerLogin');
    _logger.info('Connected to Twitch IRC channel');
  }

  ///
  /// This method is called each time a new message is received
  void _messageReceived(event) {
    _logger.info('New message received: $event');

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
      _logger.info('Received PING, sending PONG');
      _send('PONG :tmi.twitch.tv');
      return;
    }

    final re = RegExp(_regexpMessage);
    final match = re.firstMatch(fullMessage);
    // If this is an unrecognized format, log and call fallback
    if (match == null || match.groupCount != 2) {
      _logger.warning('Unrecognized message format');
      onInternalMessageReceived
          .notifyListeners((callback) => callback(fullMessage));
      return;
    }

    // If this is a message from the chat
    final sender = match.group(1)!;
    final message = match.group(2)!;
    onMessageReceived.notifyListeners((callback) => callback(sender, message));
    _logger.info('Message parsed');
  }
}

class TwitchChatMock extends TwitchAppChat {
  @override
  String get _oauthKey => 'chatbotOAuthKey';

  ///
  /// Main constructor
  ///
  static Future<TwitchChatMock> factory({
    required String streamerLogin,
    required TwitchAppAuthenticator authenticator,
  }) async =>
      TwitchChatMock._(streamerLogin, authenticator);

  ///
  /// Private constructor
  ///
  TwitchChatMock._(String streamerLogin, TwitchAppAuthenticator authenticator)
      : super._(streamerLogin, null, authenticator);

  @override
  void _connect() async {
    _connectToTwitchIrc();
  }

  @override
  Future<void> send(String message, {String? username}) async {
    // Normal behavior is that streamer sends a message, specifying a username
    // overrides this and mock a sent message from that user name
    final sender = username ?? streamerLogin;
    await _send('PRIVMSG #$sender :$message');
  }

  @override
  Future<void> _send(String command) async {
    _logger.info('Sending command: $command');
    await Future.delayed(const Duration(seconds: 1));

    final re = RegExp(r'^PRIVMSG #(.*) :(.*)$');
    final match = re.firstMatch(command);
    if (match == null || match.groupCount != 2) return;

    final user = match.group(1);
    final message = match.group(2);

    _messageReceived(':$user!$user@PRIVMSG #$user:$message');
  }
}
