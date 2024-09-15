import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:twitch_manager/models/ebs/completers.dart';
import 'package:twitch_manager/twitch_manager.dart';

final _logger = Logger('IsolatedInstance');

////////////////
abstract class IsolatedInstanceManagerAbstract {
  ///
  /// Necessary information to communicate with the Twitch API
  final int broadcasterId;
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
  final communicator =
      IsolatedManagerCommunicator(sendPort: Isolate.current.controlPort);

  ///
  /// Constructor for the IsolatedInstanceManagerAbstract. This must be called
  /// by the inherited class.
  IsolatedInstanceManagerAbstract(
      {required this.broadcasterId, required this.ebsInfo}) {
    _logger.info('Isolated created for streamer: $broadcasterId');

    // Keep the connexion alive
    _keepAlive(null);
    Timer.periodic(const Duration(minutes: 5), _keepAlive);
  }

  Future<void> _handleIncommingMessage(MessageProtocol message) async {
    switch (message.type) {
      case MessageTypes.handShake:
        switch (message.from) {
          case MessageFrom.app:
            // Do nothing, the handshake is handled by the main and the constructor
            break;
          case MessageFrom.frontend:
            _frontendHasRegistered(
                userId: message.data!['user_id'],
                opaqueId: message.data!['opaque_id']);
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
        communicator.sendMessageViaMain(MessageProtocol(
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
        return communicator.completers.complete(
            message.internalIsolate?['completer_id'],
            data: message.data);
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
      {required int userId, required String opaqueId}) async {
    _logger.info('Registering to game');

    // Do not lose time if the user is already registered
    if (userIdToOpaqueId.containsKey(userId)) return true;

    // If we do not need any information from Twitch, we are done
    if (!ebsInfo.needTwitchUserId) return true;

    // Get the login of the user
    // TODO: Get the login from Twitch
    final String? login = null;
    if (login == null) {
      _logger.severe(
          'Could not get login for user $userId or the app does not have the '
          'required permission to fetch the login');
      return false;
    }

    // Register the user
    userIdToOpaqueId[userId] = opaqueId;
    opaqueIdToUserId[opaqueId] = userId;
    userIdToLogin[userId] = login;
    loginToUserId[login] = userId;

    return true;
  }

  ///
  /// Keep the connexion alive. If it fails, the game is ended.
  Future<void> _keepAlive(Timer? keepGameManagerAlive) async {
    try {
      _logger.info('PING');
      final response = await communicator
          .sendQuestionViaMain(MessageProtocol(
              from: MessageFrom.ebsIsolated,
              to: MessageTo.app,
              type: MessageTypes.ping))
          .timeout(const Duration(seconds: 30),
              onTimeout: () => {'response': 'NOT PONG'});
      if (response?['response'] != 'PONG') {
        throw Exception('No pong');
      }
      _logger.info('PONG');
    } catch (e) {
      _logger.severe('App missed the ping, closing connexion');
      keepGameManagerAlive?.cancel();
      kill();
    }
  }

  void kill() {
    _logger.info('Killing the isolated instance');
    communicator.sendMessageViaMain(MessageProtocol(
        from: MessageFrom.ebsIsolated,
        to: MessageTo.ebsMain,
        type: MessageTypes.disconnect));
  }
}

class IsolatedManagerCommunicator {
  final SendPort sendPort;
  final completers = Completers();
  Future<void> complete(
      {required int? completerId, required dynamic data}) async {
    if (completerId == null) return;
    completers.get(completerId)?.complete(data);
  }

  IsolatedManagerCommunicator({required this.sendPort});

  ///
  /// Helper method to send a response via the main. The [message] is the message
  /// to respond with the fields [to], [isSuccess] and [data] filled.
  Future<void> sendReponse(MessageProtocol message) async {
    sendMessageViaMain(message.copyWith(
        from: MessageFrom.ebsIsolated,
        to: message.to,
        type: MessageTypes.response));
  }

  ///
  /// Helper method to send an error response via the main. The [message] is the message
  /// to respond with the fields [to] and [data] filled. The error message is added
  /// to the data field with the key 'error_message' and the [isSuccess] field is set to false.
  Future<void> sendErrorReponse(
          MessageProtocol message, String errorMessage) async =>
      sendMessageViaMain(message.copyWith(
          from: MessageFrom.ebsIsolated,
          to: message.to,
          type: MessageTypes.response,
          isSuccess: false,
          data: (message.data ?? {})..addAll({'error_message': errorMessage})));

  ///
  /// Send a message to main. The message will be redirected based on the
  /// target field of the message.
  /// [message] the message to send
  void sendMessageViaMain(MessageProtocol message) => sendPort.send(message);

  ///
  /// Send a message to main while expecting an actual response. This is
  /// useful we needs to wait for a response from the main.
  /// [message] the message to send
  /// returns a future that will be completed when the main responds
  Future<dynamic> sendQuestionViaMain(MessageProtocol message) {
    final completerId = completers.spawn();
    final completer = completers.get(completerId)!;

    sendPort.send(message.copyWith(
        from: MessageFrom.ebsIsolated,
        to: MessageTo.ebsMain,
        type: MessageTypes.get,
        internalIsolate: {'completer_id': completerId}));

    return completer.future.timeout(const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout'));
  }
}
////////////////

abstract class IsolatedInstance {
  ///
  /// Start a new instance of the isolated, this is the entry point for the worker isolate
  static void spawn(Map<String, dynamic> data) async {
    final broadcasterId = data['broadcaster_id'] as int;
    final ebsInfo = data['ebs_info'] as TwitchEbsInfo;
    final isolateManagerFactory = data['isolate_manager_factory']
        as IsolatedInstanceManagerAbstract Function(
            {required int broadcasterId, required TwitchEbsInfo ebsInfo});

    final manager =
        isolateManagerFactory(broadcasterId: broadcasterId, ebsInfo: ebsInfo);

    final receivePort = ReceivePort();
    // Send the SendPort to the main isolate, so it can communicate back to the isolate
    manager.communicator.sendMessageViaMain(MessageProtocol(
        from: MessageFrom.ebsIsolated,
        to: MessageTo.ebsMain,
        type: MessageTypes.handShake,
        data: {'send_port': receivePort.sendPort}));

    // Handle the messages from the main, app or frontends
    receivePort.listen((message) async =>
        manager._handleIncommingMessage(MessageProtocol.decode(message)));
  }

  ///
  /// Call the internal state of the isolated instance. This method should
  /// return an InstanceManager so the IsolatedInstance can communicate with
  /// the instance
  static IsolatedInstanceManagerAbstract initializeManager(
      {required int broadcasterId, required TwitchEbsInfo ebsInfo}) {
    throw UnimplementedError();
  }

  // TODO Add the ebs api
  //   case FromEbsToMainMessages.getUserId:
  //   final response = <String, dynamic>{};
  //   try {
  //     response['user_id'] = await tm.userId(login: message.raw!['login']);
  //   } catch (e) {
  //     response['user_id'] = null;
  //   }
  //   messageFromMainToIsolated(
  //       broadcasterId: isolateData.twitchBroadcasterId,
  //       message: message.copyWith(data: response));
  //   break;

  // case FromEbsToMainMessages.getDisplayName:
  //   final response = <String, dynamic>{};
  //   try {
  //     response['display_name'] =
  //         await tm.displayName(userId: message.raw!['user_id']);
  //   } catch (e) {
  //     response['display_name'] = null;
  //   }
  //   messageFromMainToIsolated(
  //       broadcasterId: isolateData.twitchBroadcasterId,
  //       message: message.copyWith(data: response));
  //   break;

  // case FromEbsToMainMessages.getLogin:
  //   final response = <String, dynamic>{};
  //   try {
  //     response['login'] = await tm.login(userId: message.raw!['user_id']);
  //   } catch (e) {
  //     response['login'] = null;
  //   }
  //   messageFromMainToIsolated(
  //       broadcasterId: isolateData.twitchBroadcasterId,
  //       message: message.copyWith(
  //           fromTo: FromMainToEbsMessages.getLogin, data: response));
  //   break;
}
