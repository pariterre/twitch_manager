import 'package:example/models/recurring_message_sender.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TwitchRecurringMessageFormField extends StatefulWidget {
  const TwitchRecurringMessageFormField(
      {super.key, required this.message, required this.onDelete});

  final String message;
  final void Function() onDelete;

  @override
  State<TwitchRecurringMessageFormField> createState() =>
      _TwitchRecurringMessageFormFieldState();
}

class _TwitchRecurringMessageFormFieldState
    extends State<TwitchRecurringMessageFormField> {
  final _sender = ReccurringMessageSender();

  void _setInterval(String value) {
    int? time = int.tryParse(value);
    _sender.interval = time == null ? Duration.zero : Duration(seconds: time);
    setState(() {});
  }

  void _setDelay(String value) {
    int? time = int.tryParse(value);
    _sender.delay = time == null ? Duration.zero : Duration(seconds: time);
  }

  ElevatedButton _buildStartButton() {
    if (_sender.isStarted) {
      return ElevatedButton(
          onPressed: () => setState(() => _sender.stopStreamingText()),
          child: const Text('Stop'));
    } else {
      return ElevatedButton(
          onPressed: _sender.isReadyToSend
              ? () => setState(() => _sender.startStreamingText())
              : null,
          child: const Text('Start'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = !_sender.isStarted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: SizedBox(
              width: 300,
              child: TextField(
                enabled: canEdit,
                onChanged: (value) => setState(() => _sender.message = value),
                style: TextStyle(color: canEdit ? Colors.black : Colors.grey),
                decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.message),
              )),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: SizedBox(
              width: 70,
              child: TextField(
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
              child: TextField(
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
            onPressed: _sender.isStarted ? null : widget.onDelete,
            icon: Icon(
              Icons.delete,
              color: _sender.isStarted ? Colors.grey : Colors.red,
            ))
      ],
    );
  }
}
