import 'dart:async';

import 'package:common/communication.dart';
import 'package:common/state.dart' as state;
import 'package:extension_client_app/main.dart';
import 'package:flutter/widgets.dart';
import 'package:twitch_manager/twitch_app.dart';
import 'package:twitch_manager/twitch_ebs.dart';

///
/// This is an example of how to connect to the EBS server. You can do so by
/// extending the [TwitchAppManagerAbstract] and implementing the methods
/// to handle the requests from and to the EBS server.
class EbsServerManager extends TwitchAppManagerAbstract {
  /// The [StateManager] instance used to manage the state.
  final StateManager _stateManager;

  ///
  /// Initialize the EbsServerManager establishing a connection with the
  /// EBS server if [ebsUri] is provided.
  EbsServerManager(
    TwitchAppManager twitchManager, {
    required super.ebsUri,
    required StateManager stateManager,
  }) : _stateManager = stateManager {
    onEbsHasConnected.listen(_onEbsHasConnected);
    onEbsHasDisconnected.listen(_onEbsHasDisconnected);
    connect(twitchManager.api.streamerId);
  }

  void _onEbsHasConnected() {
    debugPrint('EBS server connected');
  }

  void _onEbsHasDisconnected() {
    debugPrint('EBS server disconnected');
  }

  ///
  /// Here is an example of how to send a message to the frontends (viewers extension)
  /// or to the EBS server. [newState] could have been fetched from the state manager
  /// but we wanted to showcase another way to send the state to the frontends.
  Future<void> sendStateToFrontends({required state.State newState}) async =>
      sendMessageToEbs(
        MessageProtocol(
          to: MessageTo.frontend,
          from: MessageFrom.app,
          type: MessageTypes.put,
          data: {
            'type': ToFrontendMessages.state.name,
            'state': newState.serialize(),
          },
        ),
      );

  ///
  /// This method must be overridden to handle the messages received from the EBS server.
  @override
  Future<void> handleGetRequest(MessageProtocol message) async {
    try {
      final messageType = ToAppMessages.values.byName(message.data!['type']);

      switch (messageType) {
        // Here is an example of how to answer a request from one of the frontends.
        // For the sake of the example, we saved the [StateManager] in the
        // [EbsServerManager], but it can obviously be using an actual state management solution
        // like Provider or Riverpod.
        case ToAppMessages.requestState:
          sendResponseToEbs(
            message.copyWith(
              to: MessageTo.frontend,
              from: MessageFrom.app,
              type: MessageTypes.response,
              isSuccess: true,
              data: {
                'type': ToFrontendMessages.state.name,
                'state': _stateManager.currentState.serialize(),
              },
            ),
          );
          break;
      }
    } catch (e) {
      debugPrint('Error while handling message from EBS: $e');
      sendResponseToEbs(
        message.copyWith(
          to: MessageTo.frontend,
          from: MessageFrom.app,
          type: MessageTypes.response,
          isSuccess: false,
        ),
      );
    }
  }

  @override
  Future<void> handlePutRequest(MessageProtocol message) {
    // There is no put request to handle in this example.
    throw UnimplementedError();
  }
}
