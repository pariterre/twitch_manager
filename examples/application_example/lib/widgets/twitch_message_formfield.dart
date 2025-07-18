import 'package:application_example/models/instant_message_controller.dart';
import 'package:flutter/material.dart';

class TwitchMessageFormField extends StatefulWidget {
  const TwitchMessageFormField(
      {super.key, required this.controller, required this.hint});

  final String hint;
  final InstantMessageController controller;

  @override
  State<TwitchMessageFormField> createState() => _TwitchMessageFormFieldState();
}

class _TwitchMessageFormFieldState extends State<TwitchMessageFormField> {
  final _textController = TextEditingController();

  void _sendMessage() {
    widget.controller.sendText();
    widget.controller.message = '';
    _textController.clear();
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
                onChanged: (value) =>
                    setState(() => widget.controller.message = value),
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                    border: const OutlineInputBorder(), labelText: widget.hint),
              )),
        ),
        ElevatedButton(
            onPressed: widget.controller.isReadyToSend ? _sendMessage : null,
            child: const Text('Send now')),
      ],
    );
  }
}
