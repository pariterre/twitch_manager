import 'package:example/models/recurring_message_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TwitchRecurringMessageFormField extends StatefulWidget {
  const TwitchRecurringMessageFormField(
      {super.key,
      required this.controller,
      required this.hint,
      required this.onDelete});

  final ReccurringMessageController controller;
  final String hint;
  final void Function() onDelete;

  @override
  State<TwitchRecurringMessageFormField> createState() =>
      _TwitchRecurringMessageFormFieldState();
}

class _TwitchRecurringMessageFormFieldState
    extends State<TwitchRecurringMessageFormField> {
  void _setInterval(String value) {
    int? time = int.tryParse(value);
    widget.controller.interval =
        time == null ? Duration.zero : Duration(minutes: time);
    setState(() {});
  }

  void _setDelay(String value) {
    int? time = int.tryParse(value);
    widget.controller.delay =
        time == null ? Duration.zero : Duration(minutes: time);
  }

  ElevatedButton _buildStartButton() {
    if (widget.controller.isStarted) {
      return ElevatedButton(
          onPressed: () =>
              setState(() => widget.controller.stopStreamingText()),
          child: const Text('Stop'));
    } else {
      return ElevatedButton(
          onPressed: widget.controller.isReadyToSend
              ? () => setState(() => widget.controller.startStreamingText())
              : null,
          child: const Text('Start'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = !widget.controller.isStarted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: SizedBox(
              width: 300,
              child: TextFormField(
                initialValue: widget.controller.message,
                enabled: canEdit,
                onChanged: (value) =>
                    setState(() => widget.controller.message = value),
                style: TextStyle(color: canEdit ? Colors.black : Colors.grey),
                decoration: InputDecoration(
                    border: const OutlineInputBorder(), labelText: widget.hint),
              )),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: SizedBox(
              width: 70,
              child: TextFormField(
                initialValue: widget.controller.interval.inMinutes.toString(),
                enabled: canEdit,
                style: TextStyle(color: canEdit ? Colors.black : Colors.grey),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly
                ],
                onChanged: _setInterval,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), labelText: 'Time'),
              )),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: SizedBox(
              width: 70,
              child: TextFormField(
                initialValue: widget.controller.delay.inMinutes.toString(),
                enabled: canEdit,
                style: TextStyle(color: canEdit ? Colors.black : Colors.grey),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly
                ],
                onChanged: _setDelay,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), labelText: 'Delay'),
              )),
        ),
        _buildStartButton(),
        IconButton(
            onPressed: widget.controller.isStarted ? null : widget.onDelete,
            icon: Icon(
              Icons.delete,
              color: widget.controller.isStarted ? Colors.grey : Colors.red,
            ))
      ],
    );
  }
}
