import 'package:extension_client_app/ebs_server_manager.dart';
import 'package:flutter/material.dart';
import 'package:common/state.dart' as state;
import 'package:twitch_manager/twitch_app.dart';
import 'package:common/common.dart';

const _useMocker = true;

class StateManager {
  state.State currentState = state.State(sharedMessage: 'Initial State');
}

///
/// The options for the Twitch debug panel uses. You can mock here chatters,
/// prewritten message, events, admin messages, viewers messeges, etc.
/// Here we simply define four chatters with different names.
TwitchDebugPanelOptions get _twitchDebugPanelOptions => TwitchDebugPanelOptions(
  chatters: [
    TwitchChatterMock(displayName: 'Viewer1'),
    TwitchChatterMock(displayName: 'Viewer2'),
    TwitchChatterMock(displayName: 'Viewer3'),
    TwitchChatterMock(displayName: 'ViewerWithAVeryVeryVeryLongName'),
  ],
);

void main() {
  ///
  /// The information about the Twitch app used in this example. Most of the
  /// fields are described in [TwitchAppInfo]. For [twitchRedirectUri] and
  /// [authenticationServerUri], a template is provided in [twitch_manager/resources/authentication_server].
  final appInfo = TwitchAppInfo(
    appName: ConfigService.extensionName,
    twitchClientId: ConfigService.twitchClientId,
    scope: const [TwitchAppScope.chatRead, TwitchAppScope.readFollowers],
    twitchRedirectUri: Uri.https(
      'twitchauthentication.pariterre.net',
      'twitch_redirect_example.html',
    ),
    authenticationServerUri: Uri.https(
      'twitchserver.pariterre.net:3000',
      'token',
    ),
  );

  final stateManager = StateManager();

  runApp(MyApp(appInfo: appInfo, stateManager: stateManager));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.appInfo, required this.stateManager});

  final TwitchAppInfo appInfo;
  final StateManager stateManager;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Extension Client App',
      home: MainScreen(
        title: 'Extension Client App',
        appInfo: appInfo,
        stateManager: stateManager,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.title,
    required this.appInfo,
    required this.stateManager,
  });

  final String title;
  final TwitchAppInfo appInfo;
  final StateManager stateManager;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _counter = 0;

  // The TwitchAppManager is the same used for applications and therefore does not
  // need an EBS. It is not necessary to connect it, but it is often useful to perform
  // client side actions like sending messages to the chat, listening to chat messages, etc.
  // Also, to connect to the EBS, one must know the broadcasterId, which is
  // easily fetched by the TwitchAppManager.
  TwitchAppManager? _twitchManager;
  EbsServerManager? _ebsServerManager;

  void _incrementCounter() => setState(() {
    widget.stateManager.currentState = widget.stateManager.currentState
        .copyWith(sharedMessage: 'Button pressed $_counter times');
    _ebsServerManager?.sendStateToFrontends(
      newState: widget.stateManager.currentState,
    );
    _counter++;
  });

  @override
  Widget build(BuildContext context) {
    final isTwitchManagerConnected = _twitchManager?.isConnected ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: TwitchAppDebugOverlay(
        // The [TwitchAppDebugOverlay] shows a panel that the user can interact with
        // to simulate Twitch events, chat messages, etc. Please note it puts the
        // [child] into a Stack, which may or may not be a problem
        manager: _twitchManager,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Column(
                children: [
                  Text(
                    isTwitchManagerConnected
                        ? 'You are connected to Twitch.'
                        : 'You are not connected to Twitch.',
                  ),
                  const SizedBox(height: 8),
                  if (isTwitchManagerConnected)
                    ElevatedButton(
                      onPressed: disconnect,
                      child: const Text('Disconnect from Twitch'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _showConnectManagerDialog,
                      child: const Text('Connect to Twitch'),
                    ),
                ],
              ),
              const SizedBox(height: 36),
              const Text(
                'You and the viewers have pushed the button this many times:',
              ),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }

  ///
  /// Provide an easy access to the TwitchManager connect dialog
  Future<bool> _showConnectManagerDialog({bool reloadIfPossible = true}) async {
    if (_twitchManager != null) return true;

    _twitchManager = await showDialog<TwitchAppManager>(
      context: context,
      builder: (context) => TwitchAppAuthenticationDialog(
        useMocker: _useMocker,
        debugPanelOptions: _twitchDebugPanelOptions,
        onConnexionEstablished: (manager) {
          if (context.mounted) Navigator.of(context).pop(manager);
        },
        appInfo: widget.appInfo,
        reload: reloadIfPossible,
      ),
    );

    if (_twitchManager == null) {
      setState(() {});
      return false;
    }

    // Start listening to twitch chat messages
    _twitchManager!.chat.onMessageReceived.listen(_onMessageReceived);

    // Information can be retrieved from the TwitchManager
    debugPrint(
      'A list of followers: ${await _twitchManager!.api.fetchFollowers(includeStreamer: true)}',
    );

    // And we can send a message to the chat (assuming the chat scope was added)
    _twitchManager!.chat.send(
      'Hello everyone! This is a message from the client app.',
    );

    _ebsServerManager = EbsServerManager(
      _twitchManager!,
      ebsUri: ConfigService.ebsUri,
      stateManager: widget.stateManager,
    );

    setState(() {});
    return true;
  }

  ///
  /// Showcase how to disconnect from Twitch. This will remove the
  /// TwitchManager and stop listening to chat messages.
  Future<bool> disconnect() async {
    if (_twitchManager == null) return true;

    await _twitchManager!.chat.onMessageReceived.cancel(_onMessageReceived);
    await _twitchManager!.disconnect();
    _twitchManager = null;
    setState(() {});
    return true;
  }

  ///
  /// This is an example of how to deal with an incoming message from the Twitch chat.
  /// For now, we only print the message to the console.
  void _onMessageReceived(String sender, String message) =>
      debugPrint('Message from $sender: $message');
}
