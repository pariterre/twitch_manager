import 'package:flutter/material.dart';
import 'package:twitch_manager/models/twitch_manager_internal.dart';

///
/// This is a debug panel, it must be placed in a Stack on the top Screen.
/// It creates a draggable panel.
class TwitchDebugPanel extends StatefulWidget {
  const TwitchDebugPanel({
    super.key,
    required this.manager,
    this.maxHeight = 400,
    this.width = 300,
    this.startingPosition = const Offset(0, 0),
  });

  final double maxHeight;
  final double width;
  final TwitchManager manager;
  final Offset startingPosition;

  @override
  State<TwitchDebugPanel> createState() => _TwitchDebugPanelState();
}

class _TwitchDebugPanelState extends State<TwitchDebugPanel> {
  var _twitchDragOffset = const Offset(0, 0);
  late var _currentTwitchPosition = widget.startingPosition;
  @override
  Widget build(BuildContext context) {
    if (widget.manager.runtimeType != TwitchManagerMock) return Container();
    final mockOptions = (widget.manager as TwitchManagerMock).mockOptions;

    return Positioned(
      left: _currentTwitchPosition.dx,
      top: _currentTwitchPosition.dy,
      child: GestureDetector(
        onPanStart: (details) =>
            _twitchDragOffset = details.globalPosition - _currentTwitchPosition,
        onPanUpdate: (details) => setState(() => _currentTwitchPosition =
            details.globalPosition - _twitchDragOffset),
        child: Container(
          width: widget.width,
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          decoration: const BoxDecoration(color: Colors.purple),
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mockOptions.moderators.isNotEmpty)
                  _ChatterBox(
                      manager: widget.manager as TwitchManagerMock,
                      senderType: _SenderType.moderator,
                      usernames: mockOptions.moderators,
                      messages: mockOptions.messagesModerators,
                      maxWidth: widget.width),
                const SizedBox(height: 8),
                if (mockOptions.followers.isNotEmpty)
                  _ChatterBox(
                      manager: widget.manager as TwitchManagerMock,
                      senderType: _SenderType.follower,
                      usernames: mockOptions.followers,
                      messages: mockOptions.messagesFollowers,
                      maxWidth: widget.width),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
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
