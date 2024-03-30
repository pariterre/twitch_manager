import 'package:example/widgets/twitch_message_formfield.dart';
import 'package:example/widgets/twitch_recurring_message_formfield.dart';
import 'package:flutter/material.dart';
import 'package:twitch_manager/twitch_manager.dart';

void main() async {
  runApp(const MaterialApp(home: TwitchChatBotScreen()));
}

class TwitchChatBotScreen extends StatefulWidget {
  const TwitchChatBotScreen({super.key});

  @override
  State<TwitchChatBotScreen> createState() => _TwitchChatBotScreenState();
}

class _TwitchChatBotScreenState extends State<TwitchChatBotScreen> {
  int _lastMessageId = 0;
  final List<int> _recurringMessageIds = [];

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
        builder: (ctx) => TwitchAuthenticationDialog(
              // Use a mocker to simulate the connexion, this is useful for testing
              isMockActive: true,
              onConnexionEstablished: (manager) =>
                  Navigator.of(context).pop(manager),
              appInfo: TwitchAppInfo(
                appName: 'My Lovely App',
                twitchAppId: 'YOUR_APP_ID_HERE',
                redirectUri: 'YOUR_REDIRECT_DOMAIN_HERE',
                // Requested scopes for the connexion
                scope: const [
                  TwitchScope.chatRead,
                  TwitchScope.chatEdit,
                  TwitchScope.chatters,
                  TwitchScope.readFollowers,
                ],
              ),
              reload: true, // Use previous connexion if available
              // Display the debug panel, only available if isMockActive is true
              debugPanelOptions: TwitchDebugPanelOptions(
                // Which chatters are currently in the chat
                chatters: [
                  TwitchChatterMock(displayName: 'Streamer', isModerator: true),
                  TwitchChatterMock(
                      displayName: 'Moderator', isModerator: true),
                  TwitchChatterMock(displayName: 'Viewer'),
                ],
                // Prewritten message to send to the chat
                chatMessages: [
                  'Hello World!',
                  'This is a test message',
                  'This is a test message 2',
                ],
              ),
            )));

    _greatingChatters();
    setState(() {});
  }

  void _addReccurringMessage() {
    _recurringMessageIds.add(_lastMessageId + 1);
    _lastMessageId++;
    setState(() {});
  }

  void _removeReccurringMessage(int id) {
    _recurringMessageIds.remove(id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TwitchDebugOverlay(
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
                const SizedBox(height: 12),
                Text('Connexion',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (TwitchManagerSingleton.instance == null)
                  TwitchConnectButton(
                    twitchManager: TwitchManagerSingleton.instance,
                    onPressed: _connectToTwitch,
                  ),
                if (TwitchManagerSingleton.instance != null)
                  const Text('Connected to Twitch'),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Text('Send an instant message',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const TwitchMessageFormField(
                  message: 'The message to send',
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Text('Send recurring messages',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ..._recurringMessageIds.map(
                  (id) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TwitchRecurringMessageFormField(
                        key: ValueKey(id),
                        message: 'The recurring message to send',
                        onDelete: () => _removeReccurringMessage(id)),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _addReccurringMessage,
                  child: const Text('Add message'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
  /// Send a message to the chat
  static Future<void> send(String message) async =>
      instance?.chat.send(message);

  ///
  /// Check if the TwitchManager is connected
  static bool get isConnected => _singleton._manager?.isConnected ?? false;

  ///
  /// Setup a singleton for the TwitchManager
  static TwitchManager? get instance => _singleton._manager;

  static void initialize(TwitchManager manager) =>
      _singleton._manager = manager;

  ///
  /// Internal
  static final TwitchManagerSingleton _singleton = TwitchManagerSingleton._();
  TwitchManagerSingleton._();
  TwitchManager? _manager;
}
