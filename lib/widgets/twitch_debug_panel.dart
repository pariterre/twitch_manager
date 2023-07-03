import 'package:flutter/material.dart';
import 'package:twitch_manager/models/twitch_manager_internal.dart';

class TwitchDebugPanel extends StatelessWidget {
  const TwitchDebugPanel(
      {super.key, required this.manager, this.height = 400, this.width = 300});

  final double height;
  final double width;
  final TwitchManager manager;

  @override
  Widget build(BuildContext context) {
    if (manager.runtimeType != TwitchManagerMock) return Container();
    final mockOptions = (manager as TwitchManagerMock).mockOptions;

    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(color: Colors.purple),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mockOptions.moderators.isNotEmpty)
            _ChatterBox(
                manager: manager as TwitchManagerMock,
                senderType: _SenderType.moderator,
                usernames: mockOptions.moderators,
                messages: mockOptions.messagesModerators,
                maxWidth: width),
          const SizedBox(height: 8),
          if (mockOptions.followers.isNotEmpty)
            _ChatterBox(
                manager: manager as TwitchManagerMock,
                senderType: _SenderType.follower,
                usernames: mockOptions.followers,
                messages: mockOptions.messagesFollowers,
                maxWidth: width),
        ],
      ),
    );
  }
}

enum _SenderType {
  moderator,
  follower,
}

class _ChatterBox extends StatefulWidget {
  const _ChatterBox({
    required this.manager,
    required this.senderType,
    required this.usernames,
    required this.messages,
    required this.maxWidth,
  });

  final TwitchManagerMock manager;
  final _SenderType senderType;
  final List<String> usernames;
  final List<String> messages;
  final double maxWidth;

  @override
  State<_ChatterBox> createState() => _ChatterBoxState();
}

class _ChatterBoxState extends State<_ChatterBox> {
  int _currentSender = 0;
  final _senderFocus = FocusNode();
  final _messageController = TextEditingController();

  void _sendMessage(TextEditingController controller) {
    if (controller.text == '') return;
    widget.manager.irc
        .send(controller.text, username: widget.usernames[_currentSender]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Wrap(
                children: [
                  Text('Send as ${widget.usernames[_currentSender]} ',
                      style: const TextStyle(color: Colors.white)),
                  Text('(${widget.senderType.name})',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            SizedBox(
              width: 40,
              child: SubmenuButton(
                focusNode: _senderFocus,
                menuChildren: widget.usernames
                    .asMap()
                    .keys
                    .map((index) => InkWell(
                          onTap: () {
                            _currentSender = index;
                            if (_senderFocus.hasFocus) _senderFocus.nextFocus();
                            setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(widget.usernames[index]),
                          ),
                        ))
                    .toList(),
                child: const Icon(Icons.arrow_drop_down),
              ),
            )
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(5)),
              child: DropdownMenu(
                width: widget.maxWidth - 3 * 8 - 70,
                controller: _messageController,
                dropdownMenuEntries: widget.messages
                    .map((e) => DropdownMenuEntry(label: e, value: e))
                    .toList(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: ElevatedButton(
                  onPressed: () => _sendMessage(_messageController),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  child: const Text(
                    'Send',
                    style: TextStyle(color: Colors.black),
                  )),
            ),
          ],
        ),
      ],
    );
  }
}
