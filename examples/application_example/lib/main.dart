import 'package:application_example/models/command_controller.dart';
import 'package:application_example/models/instant_message_controller.dart';
import 'package:application_example/models/recurring_message_controller.dart';
import 'package:application_example/widgets/twitch_command_formfield.dart';
import 'package:application_example/widgets/twitch_message_formfield.dart';
import 'package:application_example/widgets/twitch_recurring_message_formfield.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:twitch_manager/twitch_app.dart';

void main() async {
  Logger.root.onRecord.listen((record) {
    debugPrint(record.message);
  });

  runApp(const MaterialApp(home: TwitchChatBotScreen()));
}

class TwitchChatBotScreen extends StatefulWidget {
  const TwitchChatBotScreen({super.key});

  @override
  State<TwitchChatBotScreen> createState() => _TwitchChatBotScreenState();
}

class _TwitchChatBotScreenState extends State<TwitchChatBotScreen> {
  final InstantMessageController _instantMessageController =
      InstantMessageController();
  final List<ReccurringMessageController> _recurringMessageControllers = [];
  final List<CommandController> _commandControllers = [];

  final List<String> _followers = [];

  ///
  /// This sends a message to the chat greating everyone in the chat except for
  /// StreamElements which was blacklisted. This can be used as an example on
  /// how to get information from the API and send a message to the chat.
  ///
  void _greatingChatters() async {
    // Fetch the chatters currenlty in the chat
    final chatters = await TwitchManagerSingleton.fetchChatters(
        blacklist: ['StreamElements']);

    // Send a welcome message to the chat with the chatter names
    final message = 'It’s great to see ${chatters!.map((e) => '@$e')}';
    TwitchManagerSingleton.send(message);
  }

  ///
  /// Initialize the connexion to Twitch by invoking the TwitchAuthenticationDialog
  /// then great the chatters in the chat.
  Future<void> _connectToTwitch() async {
    if (TwitchManagerSingleton.isConnected) return;

    // Invoke the TwitchAuthenticationDialog Widget which will handle the connexion
    // to Twitch. It is not necessary to use this widget to connect to Twitch, but
    // it is a convenient way to handle the connexion.
    TwitchManagerSingleton.initialize(await showDialog(
        context: context,
        builder: (ctx) => TwitchAppAuthenticationDialog(
              // Use a mocker to simulate the connexion, this is useful for testing
              useMocker: true,
              onConnexionEstablished: (manager) =>
                  Navigator.of(context).pop(manager),
              onCancelConnexion: () {}, // Prevent from closing the dialog
              appInfo: TwitchAppInfo(
                appName: 'My Lovely App',
                twitchClientId: 'YOUR_CLIENT_ID_HERE',
                twitchRedirectUri: Uri.parse(
                    'https://REDIRECT_URI_HERE/twitch_redirect_example.html'),
                authenticationServerUri:
                    Uri.parse('https://SERVER_URI_HERE/token'),
                // Requested scopes for the connexion
                scope: const [
                  TwitchAppScope.chatRead,
                  TwitchAppScope.chatEdit,
                  TwitchAppScope.chatters,
                  TwitchAppScope.readFollowers,
                ],
                authenticationFlow: TwitchAuthenticationFlow.implicit,
              ),
              reload: true, // Use previous connexion if available
              // Display the debug panel, only available if isMockActive is true
              debugPanelOptions: TwitchDebugPanelOptions(
                // Which chatters are currently in the chat
                chatters: [
                  TwitchChatterMock(displayName: 'Streamer', isModerator: true),
                  TwitchChatterMock(
                      displayName: 'Moderator', isModerator: true),
                  TwitchChatterMock(displayName: 'Follower'),
                  TwitchChatterMock(displayName: 'Viewer', isFollower: false),
                ],
                // Prewritten message to send to the chat
                chatMessages: [
                  'Hello World!',
                  'This is a test message',
                  'This is a test message 2',
                ],
              ),
            )));

    TwitchManagerSingleton.onMessageReceived = _onMessageReceived;

    _followers.addAll(
        (await TwitchManagerSingleton.fetchFollowers(includeStreamer: true))
                ?.toList() ??
            []);

    _greatingChatters();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TwitchAppDebugOverlay(
      manager: TwitchManagerSingleton.instance,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chatbot example'),
          backgroundColor: const Color(0xFF6441a5),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ..._buildConnexion(),
                const Divider(),
                ..._buildInstantMessage(),
                const Divider(),
                ..._buildRecurringMessage(),
                const Divider(),
                ..._buildCommand(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildConnexion() {
    return [
      const SizedBox(height: 12),
      Text('Connexion', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (TwitchManagerSingleton.instance == null)
        ElevatedButton(
          onPressed: _connectToTwitch,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6441a5),
              foregroundColor: Colors.white),
          child: Text(TwitchManagerSingleton.isConnected
              ? 'Disconnect from twitch'
              : 'Connect to Twitch'),
        ),
      if (TwitchManagerSingleton.instance != null)
        const Text('Connected to Twitch'),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildInstantMessage() {
    return [
      const SizedBox(height: 12),
      Text('Send an instant message',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      TwitchMessageFormField(
          controller: _instantMessageController, hint: 'The message to send'),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildRecurringMessage() {
    return [
      const SizedBox(height: 12),
      Text('Recurring messages', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      ..._recurringMessageControllers.map(
        (controller) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: TwitchRecurringMessageFormField(
              controller: controller,
              key: ObjectKey(controller),
              hint: 'The recurring message to send',
              onDelete: () => setState(
                  () => _recurringMessageControllers.remove(controller))),
        ),
      ),
      const SizedBox(height: 8),
      ElevatedButton(
        onPressed: () => setState(() =>
            _recurringMessageControllers.add(ReccurringMessageController())),
        child: const Text('Add message'),
      ),
      const SizedBox(height: 12),
    ];
  }

  void _onMessageReceived(String sender, String message) {
    if (!_followers.contains(sender)) return;

    for (final controller in _commandControllers) {
      if (controller.command == message) {
        TwitchManagerSingleton.send(controller.answer);
      }
    }
  }

  List<Widget> _buildCommand() {
    return [
      const SizedBox(height: 12),
      Text('Chatbot commands', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      ..._commandControllers.map(
        (controller) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: TwitchCommandFormField(
              controller: controller,
              key: ObjectKey(controller),
              hintCommand: 'The command to listen to',
              hintAnswer: 'The message to answer',
              onDelete: () =>
                  setState(() => _commandControllers.remove(controller))),
        ),
      ),
      const SizedBox(height: 8),
      ElevatedButton(
        onPressed: () =>
            setState(() => _commandControllers.add(CommandController())),
        child: const Text('Add command'),
      ),
      const SizedBox(height: 12),
    ];
  }
}

///
/// This singleton interface is used to showcase some of the features of
/// [TwitchManager] in the [main.dart] page. While this is convenient here,
/// it would be slightly overkill to interface all the calls to TwitchManager
/// in a real app setting. One could simply use [TwitchManagerSingleton.instance]
/// and directly call the methods on the [TwitchManager] instance.
class TwitchManagerSingleton {
  ///
  /// Fetch the chatters currently in the chat
  static Future<List<String>?> fetchChatters(
          {required List<String> blacklist}) async =>
      await instance?.api.fetchChatters(blacklist: blacklist);

  ///
  /// Fetch the followers of the streamer
  static Future<List<String>?> fetchFollowers(
          {required bool includeStreamer}) async =>
      await instance?.api.fetchFollowers(includeStreamer: includeStreamer);

  ///
  /// Send a message to the chat
  static Future<void> send(String message) async =>
      instance?.chat.send(message);

  ///
  /// Callback for when a message is received
  Function(String sender, String message)? _onMessageReceivedCallback;
  static set onMessageReceived(
          Function(String sender, String message) callback) =>
      _singleton._onMessageReceivedCallback = callback;

  ///
  /// Check if the TwitchManager is connected
  static bool get isConnected => _singleton._manager?.isConnected ?? false;

  ///
  /// Setup a singleton for the TwitchManager
  static TwitchAppManager? get instance => _singleton._manager;

  static void initialize(TwitchAppManager manager) {
    _singleton._manager = manager;
    _singleton._manager!.chat.onMessageReceived
        .listen((String sender, String message) {
      if (_singleton._onMessageReceivedCallback != null) {
        _singleton._onMessageReceivedCallback!(sender, message);
      }
    });
  }

  ///
  /// Internal
  static final TwitchManagerSingleton _singleton = TwitchManagerSingleton._();
  TwitchManagerSingleton._();
  TwitchAppManager? _manager;
}
