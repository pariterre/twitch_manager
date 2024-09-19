import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:twitch_manager/twitch_ebs.dart';
import 'package:twitch_manager/utils/completers.dart';

final _logger = Logger('TwitchEbsManagerAbstract');

abstract class TwitchEbsManagerAbstract {
  ///
  /// Necessary information to communicate with the Twitch API

  final TwitchEbsInfo ebsInfo;

  ///
  /// [OpaqueId] is the id of each user of the frontends. If the app does not request
  /// the permission for the user id, this will be the only way to identify the user.
  /// Note this identifier is unique, but cannot be used to identify the user by
  /// login or display name.
  /// [UserId] is the id of the user on Twitch. This is unique and can be used to
  /// identify the user by login or display name. The app must request the permission
  /// to be able to "convert" the opaque id to the user id.
  /// [Login] is the login of the user on Twitch. This is unique and can be used to
  /// identify the user by display name. The app must request the permission to
  /// be able to "convert" the opaque id to the login.
  final Map<int, String> _userIdToOpaqueId = {};
  Map<int, String> get userIdToOpaqueId => Map.unmodifiable(_userIdToOpaqueId);

  final Map<int, String> _userIdToLogin = {};
  Map<int, String> get userIdToLogin => Map.unmodifiable(_userIdToLogin);

  final Map<String, int> _opaqueIdToUserId = {};
  Map<String, int> get opaqueIdToUserId => Map.unmodifiable(_opaqueIdToUserId);

  final Map<String, int> _loginToUserId = {};
  Map<String, int> get loginToUserId => Map.unmodifiable(_loginToUserId);

  ///
  /// The communicator handle communicaition with the main
  late final Communicator communicator;

  ///
  /// Constructor for the IsolatedInstanceManagerAbstract. This must be called
  /// by the inherited class.
  TwitchEbsManagerAbstract(
      {required int broadcasterId,
      required this.ebsInfo,
      required SendPort sendPort}) {
    _logger.info('Isolated created for streamer: $broadcasterId');

    communicator = Communicator(manager: this, sendPort: sendPort);

    TwitchApi.initialize(broadcasterId: broadcasterId, ebsInfo: ebsInfo);

    // Inform the frontend that the streamer has connected
    communicator.sendMessage(MessageProtocol(
        from: MessageFrom.app,
        to: MessageTo.frontend,
        type: MessageTypes.handShake));

    // Keep the connexion alive
    Timer.periodic(const Duration(minutes: 5), _keepAlive);
  }

  Future<void> _handleIncomingMessage(MessageProtocol message) async {
    switch (message.type) {
      case MessageTypes.handShake:
        switch (message.from) {
          case MessageFrom.app:
            // Do nothing, the handshake is handled by creating the current instance
            break;
          case MessageFrom.frontend:
            final isSuccess = await _frontendHasRegistered(
                userId: message.data!['user_id'],
                opaqueId: message.data!['opaque_id']);
            communicator.sendReponse(message.copyWith(
                from: MessageFrom.ebsIsolated,
                to: MessageTo.ebsMain,
                type: MessageTypes.response,
                isSuccess: isSuccess));
            break;
          case MessageFrom.ebsMain:
          case MessageFrom.ebsIsolated:
          case MessageFrom.generic:
            throw Exception('Invalid handshake');
        }
        break;
      case MessageTypes.disconnect:
        // This is probably overkill, but we want to make sure the game is ended
        // So send back to the main a message to disconnect
        await communicator.sendMessage(MessageProtocol(
            from: MessageFrom.ebsIsolated,
            to: MessageTo.frontend,
            type: MessageTypes.disconnect));
        communicator.sendMessage(MessageProtocol(
            from: MessageFrom.ebsIsolated,
            to: MessageTo.ebsMain,
            type: MessageTypes.disconnect));
        break;
      case MessageTypes.get:
        return handleGetRequest(message);
      case MessageTypes.put:
        return handlePutRequest(message);
      case MessageTypes.response:
      case MessageTypes.pong:
        return communicator.completers
            .complete(message.internalIsolate?['completer_id'], data: message);
      case MessageTypes.ping:
        return;
    }
  }

  ///
  /// Handle a message from the app. This must be implemented by the inherited class.
  /// This actually implements the logic of the communication between the app and the isolated.
  Future<void> handleGetRequest(MessageProtocol message);

  ///
  /// Handle a message from the frontend. This must be implemented by the inherited class.
  /// This actually implements the logic of the communication between the frontend and the isolated.
  Future<void> handlePutRequest(MessageProtocol message);

  ///
  /// Handle a message from the frontend to register to the game
  /// [userId] the twitch id of the user
  /// [opaqueId] the opaque id of the user (provided by the frontend)
  Future<bool> _frontendHasRegistered(
      {required int? userId, required String opaqueId}) async {
    _logger.info('Registering to game');

    // Do not lose time if the user is already registered
    if (userIdToOpaqueId.containsKey(userId)) return true;

    // If we do not need any information from Twitch, we are done
    if (!ebsInfo.isTwitchUserIdRequired) {
      _logger.info(
          'No need to register UserID as [isTwitchUserIdRequired] is false');
      return true;
    }

    if (userId == null) {
      _logger.severe('User id is required to register this extension');
      return false;
    }

    // Get the login of the user
    final login = await TwitchApi.instance.login(userId: userId);
    if (login == null) {
      _logger.severe(
          'Could not get login for user $userId or the app does not have the '
          'required permission to fetch the login');
      return false;
    }

    // Register the user
    _userIdToOpaqueId[userId] = opaqueId;
    _opaqueIdToUserId[opaqueId] = userId;
    _userIdToLogin[userId] = login;
    _loginToUserId[login] = userId;

    return true;
  }

  ///
  /// Keep the connexion alive. If it fails, the game is ended.
  Future<void> _keepAlive(Timer keepGameManagerAlive) async {
    try {
      _logger.info('PING');
      final response = (await communicator
          .sendQuestion(MessageProtocol(
            from: MessageFrom.ebsIsolated,
            to: MessageTo.app,
            type: MessageTypes.ping,
          ))
          .timeout(const Duration(seconds: 30),
              onTimeout: () => MessageProtocol(
                  from: MessageFrom.app,
                  to: MessageTo.ebsIsolated,
                  type: MessageTypes.response,
                  isSuccess: false)));
      if (response.type != MessageTypes.pong) {
        throw Exception('No pong');
      }
      _logger.info('PONG');
    } catch (e) {
      _logger.severe('App missed the ping, closing connexion');
      keepGameManagerAlive.cancel();
      kill();
    }
  }

  void kill() {
    _logger.info('Killing the isolated instance');
    communicator.sendMessage(MessageProtocol(
        from: MessageFrom.ebsIsolated,
        to: MessageTo.ebsMain,
        type: MessageTypes.disconnect));
  }
}

class Communicator {
  final _receivePort = ReceivePort();
  final SendPort _sendPort;
  final completers = Completers();
  Future<void> complete(
      {required int? completerId, required dynamic data}) async {
    if (completerId == null) return;
    completers.get(completerId)?.complete(data);
  }

  Communicator(
      {required TwitchEbsManagerAbstract manager, required SendPort sendPort})
      : _sendPort = sendPort {
    // Send the SendPort to the main isolate, so it can communicate back to the isolate
    sendMessage(MessageProtocol(
        from: MessageFrom.ebsIsolated,
        to: MessageTo.ebsMain,
        type: MessageTypes.handShake,
        data: {'send_port': _receivePort.sendPort}));

    sendMessage(MessageProtocol(
      from: MessageFrom.ebsIsolated,
      to: MessageTo.app,
      type: MessageTypes.handShake,
      isSuccess: true,
    ));

    // Handle the messages from the main, app or frontends
    _receivePort.listen((message) async =>
        manager._handleIncomingMessage(MessageProtocol.decode(message)));
  }

  ///
  /// Helper method to send a response via the main. The [message] is the message
  /// to respond with the fields [to], [isSuccess] and [data] filled.
  Future<void> sendReponse(MessageProtocol message) async {
    sendMessage(message.copyWith(
        from: MessageFrom.ebsIsolated,
        to: message.to == MessageTo.frontend ? MessageTo.ebsMain : message.to,
        type: MessageTypes.response));
  }

  ///
  /// Helper method to send an error response via the main. The [message] is the message
  /// to respond with the fields [to] and [data] filled. The error message is added
  /// to the data field with the key 'error_message' and the [isSuccess] field is set to false.
  Future<void> sendErrorReponse(
          MessageProtocol message, String errorMessage) async =>
      sendMessage(message.copyWith(
          from: MessageFrom.ebsIsolated,
          to: message.to,
          type: MessageTypes.response,
          isSuccess: false,
          data: (message.data ?? {})..addAll({'error_message': errorMessage})));

  ///
  /// Send a message to main. The message will be redirected based on the
  /// target field of the message.
  /// [message] the message to send
  Future<void> sendMessage(MessageProtocol message) async {
    try {
      await _sendMessage(message);
    } catch (e) {
      // Do nothing
    }
  }

  ///
  /// Send a message to main while expecting an actual response. This is
  /// useful we needs to wait for a response from the main.
  /// [message] the message to send
  /// returns a future that will be completed when the main responds
  Future<MessageProtocol> sendQuestion(MessageProtocol message) async {
    final completerId = completers.spawn();
    final completer = completers.get(completerId)!;

    if (message.to == MessageTo.frontend) {
      await _sendMessage(message);
    } else {
      await _sendMessage(message.copyWith(
          from: message.from,
          to: message.to,
          type: message.type,
          internalIsolate: {'completer_id': completerId}));
    }

    final response = await completer.future.timeout(const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout'));
    return response as MessageProtocol;
  }

  Future<void> _sendMessage(MessageProtocol message) async {
    if (message.to == MessageTo.frontend) {
      final response =
          await TwitchApi.instance.sendPubsubMessage(message.toJson());
      if (response.statusCode != 204) {
        _logger.severe('Could not send message to frontends');
        throw Exception('Could not send message to frontends');
      }
    } else {
      _sendPort.send(message.toJson());
    }
  }
}
