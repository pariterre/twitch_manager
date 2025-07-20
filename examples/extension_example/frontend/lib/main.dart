import 'package:common/common.dart';
import 'package:common/communication.dart';
import 'package:common/state.dart' as state;
import 'package:extension_frontend/mocked_twitch_jwt_authenticator.dart';
import 'package:flutter/material.dart';
import 'package:twitch_manager/twitch_ebs.dart';
import 'package:twitch_manager/twitch_frontend.dart';

const _useMocker = true;

void main() async {
  final frontendManager = await TwitchFrontendManager.factory(
    appInfo: TwitchFrontendInfo(
      appName: 'Train de mots',
      ebsUri: ConfigService.ebsUri,
    ),
    isTwitchUserIdRequired: ConfigService.userIdIsRequired,
    mockedAuthenticatorInitializer: _useMocker
        ? () => MockedTwitchJwtAuthenticator()
        : null,
  );

  runApp(MainExtension(frontendManager: frontendManager));
}

class MainExtension extends StatefulWidget {
  const MainExtension({super.key, required this.frontendManager});

  final TwitchFrontendManager frontendManager;

  @override
  State<MainExtension> createState() => _MainExtensionState();
}

class _MainExtensionState extends State<MainExtension> {
  var _state = state.State(sharedMessage: 'Initial State');

  @override
  void initState() {
    super.initState();
    widget.frontendManager.onHasConnected.listen(_onConnected);
    widget.frontendManager.onMessageReceived.listen(_onMessageReceived);
    widget.frontendManager.onStreamerHasConnected.listen(_onConnected);
    widget.frontendManager.onStreamerHasDisconnected.listen(_onDisconnected);
  }

  @override
  void dispose() {
    widget.frontendManager.onHasConnected.cancel(_onConnected);
    widget.frontendManager.onMessageReceived.cancel(_onMessageReceived);
    widget.frontendManager.onStreamerHasConnected.cancel(_onConnected);
    widget.frontendManager.onStreamerHasDisconnected.cancel(_onDisconnected);
    super.dispose();
  }

  ///
  /// Handle connection events from the Twitch API (both connected and streamer
  /// connected).
  void _onConnected() {
    setState(() {});

    if (widget.frontendManager.isStreamerConnected) {
      // This is to showcase how the EBS can transfer a request and wait for the
      // response from the App (without sending to all the frontends).
      widget.frontendManager.sendMessageToApp(
        MessageProtocol(
          to: MessageTo.app,
          from: MessageFrom.frontend,
          type: MessageTypes.get,
          data: {'type': ToAppMessages.requestState.name},
        ),
      );
    }
  }

  ///
  /// Handle disconnection events from the Twitch API (both disconnected and
  /// streamer disconnected).
  void _onDisconnected() {
    setState(() {});
  }

  ///
  /// Handle messages received from the EBS.
  void _onMessageReceived(MessageProtocol message) {
    setState(() {
      _state = state.State.deserialize(message.data?['state']);
    });
  }

  ///
  /// This is to showcase how to send a message to the App from one of the frontends
  Future<void> _sendPressButtonToo() async {
    await widget.frontendManager.sendMessageToApp(
      MessageProtocol(
        type: MessageTypes.get,
        to: MessageTo.app,
        from: MessageFrom.frontend,
        data: {'type': ToAppMessages.pressButtonPlease.name},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 20.0, top: 30.0, right: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.frontendManager.isNotConnected
                    ? Text('Waiting for connection with the backend...')
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Streamer is '),
                          if (widget
                              .frontendManager
                              .apiToEbs
                              .isStreamerNotConnected)
                            Text(
                              'not connected',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            )
                          else
                            Text(
                              'connected',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                const SizedBox(height: 20),
                Text(
                  'State: ${_state.sharedMessage}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: _sendPressButtonToo,
                  child: Text('Please press button for me'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
