import 'package:example/models/command_controller.dart';
import 'package:flutter/material.dart';

class TwitchCommandFormField extends StatefulWidget {
  const TwitchCommandFormField({
    super.key,
    required this.controller,
    required this.hintCommand,
    required this.hintAnswer,
    required this.onDelete,
  });

  final CommandController controller;
  final String hintCommand;
  final String hintAnswer;
  final void Function() onDelete;

  @override
  State<TwitchCommandFormField> createState() => _TwitchCommandFormFieldState();
}

class _TwitchCommandFormFieldState extends State<TwitchCommandFormField> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: SizedBox(
              width: 300,
              child: TextFormField(
                initialValue: widget.controller.command,
                enabled: true,
                onChanged: (value) =>
                    setState(() => widget.controller.command = value),
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.hintCommand),
              )),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: SizedBox(
              width: 300,
              child: TextFormField(
                initialValue: widget.controller.answer,
                enabled: true,
                onChanged: (value) =>
                    setState(() => widget.controller.answer = value),
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.hintAnswer),
              )),
        ),
        IconButton(
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete, color: Colors.red))
      ],
    );
  }
}
