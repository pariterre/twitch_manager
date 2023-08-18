import 'package:flutter/material.dart';
import 'package:twitch_manager/twitch_manager.dart';

import 'twitch_sender.dart';

class TwitchChatBotScreen extends StatelessWidget {
  static const route = '/twitch-chat-bot';

  const TwitchChatBotScreen({super.key});

  final nbReoccurringRow = 10;

  ///
  /// This sends a message to the chat greating everyone in the chat except for
  /// StreamElements which was blacklisted. This can be used as an example on
  /// how to get information from the API and send a message to the chat.
  ///
  void greatings(TwitchManager twitchManager) async {
    final chatters =
        await twitchManager.api.fetchChatters(blacklist: ['StreamElements']);
    final message = 'Bonjour à tous ${chatters!.map((e) => '@$e')}';
    twitchManager.irc.send(message);
  }

  @override
  Widget build(BuildContext context) {
    final twitchManager =
        ModalRoute.of(context)!.settings.arguments as TwitchManager;

    greatings(twitchManager);

    final reoccurringSender = <Widget>[];
    for (var i = 0; i < nbReoccurringRow; i++) {
      reoccurringSender.add(Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextSender(twitchManager,
              labelText: 'Recurrent message', hasTimer: true)));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Chatting interface')),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chat API',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      )),
                  TextSender(twitchManager, labelText: 'Send a message'),
                  const Divider(),
                  ...reoccurringSender
                ],
              ),
            ),
            TwitchDebugPanel(manager: twitchManager)
          ],
        ),
      ),
    );
  }
}

class TextSender extends StatefulWidget {
  const TextSender(
    this.twitchManager, {
    super.key,
    this.hasTimer = false,
    required this.labelText,
  });

  final TwitchManager twitchManager;
  final String labelText;
  final bool hasTimer;

  @override
  State<TextSender> createState() => _TextSenderState();
}

class _TextSenderState extends State<TextSender> {
  late final TwitchSender _sender = widget.hasTimer
      ? ReoccurringTwitchSender(twitchManager: widget.twitchManager)
      : TwitchSender(twitchManager: widget.twitchManager);

  final _textController = TextEditingController();
  final _timeController = TextEditingController();

  void _validateInterval(value) {
    final sender = (_sender as ReoccurringTwitchSender);

    if (value == '') {
      sender.interval = null;
      setState(() {});
      return;
    }

    int? time = int.tryParse(value);
    if (time == null) {
      _timeController.text =
          sender.interval == null ? '' : sender.interval!.inMinutes.toString();
      setState(() {});
      return;
    }

    sender.interval = value == '' ? null : Duration(minutes: time);
    setState(() {});
  }

  void _sendMessage() {
    _sender.sendText();
    if (!widget.hasTimer) _textController.text = '';

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.hasTimer
        ? !(_sender as ReoccurringTwitchSender).isStreaming
        : true;

    late Widget sendButton;
    if (widget.hasTimer && (_sender as ReoccurringTwitchSender).isStreaming) {
      sendButton = ElevatedButton(
          onPressed: () => setState(
              () => (_sender as ReoccurringTwitchSender).stopSending()),
          child: const Text('Stop streaming'));
    } else {
      sendButton = ElevatedButton(
          onPressed: _sender.isReadyToSend ? _sendMessage : null,
          child: Text(widget.hasTimer ? 'Start streaming' : 'Send now'));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.hasTimer)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SizedBox(
                width: 50,
                child: TextField(
                  controller: _timeController,
                  enabled: canEdit,
                  style: TextStyle(color: canEdit ? Colors.black : Colors.grey),
                  onChanged: _validateInterval,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), labelText: 'time'),
                )),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: SizedBox(
              width: 300,
              child: TextField(
                enabled: canEdit,
                controller: _textController,
                onChanged: (value) => setState(() => _sender.message = value),
                style: TextStyle(color: canEdit ? Colors.black : Colors.grey),
                decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.labelText),
              )),
        ),
        sendButton,
      ],
    );
  }
}
