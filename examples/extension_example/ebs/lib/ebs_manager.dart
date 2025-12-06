import 'dart:async';

import 'package:common/communication.dart';
import 'package:common/state.dart';
import 'package:extension_ebs/mocked_twitch_api.dart';
import 'package:logging/logging.dart';
import 'package:twitch_manager/twitch_ebs.dart';

final _logger = Logger('EbsManager');

///
/// This class is the actual implementation of the EBS manager for the extension.
/// It must extend the [TwitchEbsManagerAbstract] class and implement the methods
/// to handle the requests from the app and the frontend.
class EbsManager extends TwitchEbsManagerAbstract {
  ///
  /// Create a new EbsManager. This method automatically starts a keep alive
  /// mechanism to keep the connexion alive. If it fails, the extension is ended.
  /// [broadcasterId] the id of the broadcaster.
  /// [ebsInfo] the configuration of the EBS.
  EbsManager.spawn({
    required String broadcasterId,
    required super.ebsInfo,
    required super.sendPort,
    bool useMockedTwitchEbsApi = false,
  }) : super(
         broadcasterId: broadcasterId,
         twitchEbsApiInitializer: useMockedTwitchEbsApi
             ? MockedTwitchEbsApi.initialize
             : TwitchEbsApi.initialize,
       ) {
    // Set up the logger
    Logger.root.onRecord.listen(
      (record) => print(
        '${record.time} - BroadcasterId: $broadcasterId - ${record.message}',
      ),
    );

    // Example of how sending a welcome message to the Twitch chat. This requires the send message
    // permission to be set in the Twitch Developer Console.
    // _logger.info('Sending welcome message');
    // TwitchEbsApi.instance.sendChatMessage('Welcome to the my extension!');
  }

  ///
  /// Holds the current state of the extension
  State currentState = State(sharedMessage: '');

  ///
  /// This shows how to send a message all frontends (all viewers extension).
  Future<void> _sendStateToFrontend() async {
    _logger.info('Sending state to frontend');

    communicator.sendMessage(
      MessageProtocol(
        to: MessageTo.frontend,
        from: MessageFrom.ebs,
        type: MessageTypes.put,
        data: {
          'type': ToFrontendMessages.state.name,
          'state': currentState.serialize(),
        },
      ),
    );
  }

  ///
  /// This shows case how to send a request something and wait for the response
  /// from the app client.
  Future<MessageProtocol> _requestStateToApp() async {
    _logger.info('Resquesting state');
    return await communicator.sendQuestion(
      MessageProtocol(
        to: MessageTo.app,
        from: MessageFrom.ebs,
        type: MessageTypes.get,
        data: {'type': ToAppMessages.requestState.name},
      ),
    );
  }

  ///
  /// Since we currently don't have a difference between put and get, we funnel
  /// all requests to this method, in a real case, you may want to separate
  /// the requests to handle them differently.
  @override
  Future<void> handlePutRequest(MessageProtocol message) async =>
      await _handleRequest(message);

  @override
  Future<void> handleGetRequest(MessageProtocol message) async =>
      await _handleRequest(message);

  @override
  Future<void> handleBitsTransaction(
    MessageProtocol message,
    ExtractedTransactionReceipt transactionReceipt,
  ) async {
    await _handleRequest(message, transactionReceipt);
  }

  Future<void> _handleRequest(
    MessageProtocol message, [
    ExtractedTransactionReceipt? transactionReceipt,
  ]) async {
    switch (message.from) {
      case MessageFrom.app:
        await _handleMessageFromApp(message);
        break;
      case MessageFrom.frontend:
        await _handleMessageFromFrontend(message, transactionReceipt);
        break;
      case MessageFrom.ebsMain:
      case MessageFrom.ebs:
      case MessageFrom.generic:
        throw 'Request not supported';
    }
  }

  ///
  /// This is the main method to handle messages from the app.
  /// It is called when the app sends a message to the EBS.
  /// It handles the messages and is expected to funnel the requests (after being
  /// treated) to whatever the [MessageTo] is set to.
  Future<void> _handleMessageFromApp(MessageProtocol message) async {
    print(
      'Received message from app: ${message.data?['state']['sharedMessage']}',
    );

    try {
      switch (message.to) {
        case MessageTo.ebs:
          // Put all the logic for handling messages from the app targeting the EBS here
          break;
        case MessageTo.frontend:
          // Put all the logic for handling messages from the app targeting the frontend here
          // Here we handle the sending of the state as an example. Please remember
          // that [message.data] is not part of the actual protocol, but controlled
          // by the developer (you!).
          final messageType = ToFrontendMessages.values.byName(
            message.data!['type'],
          );
          switch (messageType) {
            case ToFrontendMessages.state:
              // Store the current just because we can
              currentState = State.deserialize(message.data!['state']);
              _sendStateToFrontend();
              break;
          }
          break;
        case MessageTo.pubsub:
          // Put all the logic for handling messages from the app targeting the pubsub here

          // This is not used in this example, but you can use it to send messages to the pubsub
          // channel, you would simply use the [communicator] with [to] set to [MessageTo.pubsub].
          break;
        case MessageTo.app:
          // Put all the logic for handling messages from the app targeting the app here
          // This is probably useless as the app speaking to itself does not make much sense
          break;
        case MessageTo.generic:
        case MessageTo.ebsMain:
          // [generic] and [ebsMain] are internal components of the EBS.
          // This case is added for completeness, but should always throw an error.
          throw 'Request not supported';
      }
    } catch (e) {
      communicator.sendErrorReponse(
        message.copyWith(
          to: MessageTo.app,
          from: MessageFrom.ebs,
          type: MessageTypes.response,
        ),
        e.toString(),
      );
    }
  }

  ///
  /// This is the main method to handle messages from the frontend.
  /// It is called when any of the viewers (using the frontend extension) sends
  /// a message to the EBS.
  /// It handles the messages and is expected to funnel the requests (after being
  /// treated) to whatever the [MessageTo] is set to.
  Future<void> _handleMessageFromFrontend(
    MessageProtocol message,
    ExtractedTransactionReceipt? transactionReceipt,
  ) async {
    try {
      // In this example, we only allows the frontend to request something to the app client
      if (message.to != MessageTo.app) throw 'Request not supported';

      final messageType = ToAppMessages.values.byName(message.data!['type']);
      switch (messageType) {
        case ToAppMessages.requestState:
          // In this example, the frontend asks the app client to return the current
          // state (this is kind of stupid as the EBS already knows it, but
          // this is to showcase the request and response flow). Then the EBS
          // get the response and sends it back to the frontend.
          final response = await _requestStateToApp();
          communicator.sendReponse(
            response.copyWith(
              to: MessageTo.frontend,
              from: MessageFrom.ebs,
              type: MessageTypes.response,
              isSuccess: true,
            ),
          );
          break;

        case ToAppMessages.pressButtonPlease:
          // Simply relay the message
          await communicator.sendMessage(message);
      }
    } catch (e) {
      return communicator.sendErrorReponse(message, e.toString());
    }
  }
}
