import 'package:example/models/message_sender.dart';
import 'package:flutter/material.dart';

class TwitchMessageFormField extends StatefulWidget {
  const TwitchMessageFormField({super.key, required this.message});

  final String message;

  @override
  State<TwitchMessageFormField> createState() => _TwitchMessageFormFieldState();
}

class _TwitchMessageFormFieldState extends State<TwitchMessageFormField> {
  final _sender = MessageSender();
  final _textController = TextEditingController();

  void _sendMessage() {
    _sender.sendText();
    _textController.text = '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: SizedBox(
              width: 300,
              child: TextField(
                enabled: true,
                controller: _textController,
                onChanged: (value) => setState(() => _sender.message = value),
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.message),
              )),
        ),
        ElevatedButton(
            onPressed: _sender.isReadyToSend ? _sendMessage : null,
            child: const Text('Send now')),
      ],
    );
  }
}
