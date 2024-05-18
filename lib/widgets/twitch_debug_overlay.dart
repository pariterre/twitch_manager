import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twitch_manager/models/twitch_events.dart';
import 'package:twitch_manager/models/twitch_manager_internal.dart';
import 'package:twitch_manager/models/twitch_mock_options.dart';
import 'package:twitch_manager/widgets/animated_expanding_card.dart';

///
/// This is a debug panel, it must be placed in a Stack on the top Screen.
/// It creates a draggable panel.
class TwitchDebugOverlay extends StatefulWidget {
  const TwitchDebugOverlay({
    super.key,
    required this.manager,
    this.maxHeight = 500,
    this.width = 350,
    this.startingPosition = const Offset(0, 0),
    required this.child,
  });

  final double maxHeight;
  final double width;
  final TwitchManager? manager;
  final Offset startingPosition;
  final Widget child;

  @override
  State<TwitchDebugOverlay> createState() => _TwitchDebugOverlayState();
}

class _TwitchDebugOverlayState extends State<TwitchDebugOverlay> {
  var _twitchDragOffset = const Offset(0, 0);
  late var _currentTwitchPosition = widget.startingPosition;

  @override
  Widget build(BuildContext context) {
    final debugPanelOptions = widget.manager.runtimeType == TwitchManagerMock
        ? (widget.manager as TwitchManagerMock).debugPanelOptions
        : null;

    return Stack(
      children: [
        widget.child,
        if (debugPanelOptions != null)
          Positioned(
            left: _currentTwitchPosition.dx,
            top: _currentTwitchPosition.dy,
            child: GestureDetector(
              onPanStart: (details) => _twitchDragOffset =
                  details.globalPosition - _currentTwitchPosition,
              onPanUpdate: (details) => setState(() => _currentTwitchPosition =
                  details.globalPosition - _twitchDragOffset),
              child: Card(
                color: Colors.transparent,
                elevation: 10,
                child: Container(
                  width: widget.width,
                  constraints: BoxConstraints(maxHeight: widget.maxHeight),
                  decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    child: AnimatedExpandingCard(
                      initialExpandedState: true,
                      header: const _Header(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.manager!.isChatbotConnected)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ChatterBox(
                                      manager:
                                          widget.manager as TwitchManagerMock,
                                      debugPanelOptions: debugPanelOptions,
                                      maxWidth: widget.width,
                                      onChanged: () => setState(() {})),
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  _ChatBox(
                                      manager:
                                          widget.manager as TwitchManagerMock,
                                      debugPanelOptions: debugPanelOptions,
                                      maxWidth: widget.width),
                                ],
                              ),
                            ),
                          if (widget.manager!.isEventConnected)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: _RedemptionRedeemBox(
                                manager: widget.manager as TwitchManagerMock,
                                debugPanelOptions: debugPanelOptions,
                                maxWidth: widget.width,
                              ),
                            )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Twitch Debug Panel',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

class _ChatterBox extends StatefulWidget {
  const _ChatterBox({
    required this.manager,
    required this.debugPanelOptions,
    required this.maxWidth,
    required this.onChanged,
  });

  final TwitchManagerMock manager;
  final TwitchDebugPanelOptions debugPanelOptions;
  final double maxWidth;
  final Function onChanged;

  @override
  State<_ChatterBox> createState() => _ChatterBoxState();
}

class _ChatterBoxState extends State<_ChatterBox> {
  @override
  Widget build(BuildContext context) {
    // Add a text field with a white color
    return AnimatedExpandingCard(
      header: const Text('Chatters',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      child: SizedBox(
        height: 200,
        child: ListView(
          children: [
            ...widget.debugPanelOptions.chatters.map(
              (e) => Column(children: [
                TextFormField(
                  initialValue: e.displayName,
                  decoration: const InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    e.displayName = value;
                    widget.onChanged();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      children: [
                        const Text('Streamer',
                            style: TextStyle(color: Colors.white)),
                        Checkbox(
                            value: e.isStreamer,
                            onChanged: (value) {
                              e.isStreamer = value ?? false;
                              widget.onChanged();
                            }),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Moderator',
                            style: TextStyle(color: Colors.white)),
                        Checkbox(
                            value: e.isModerator,
                            onChanged: (value) {
                              e.isModerator = value ?? false;
                              widget.onChanged();
                            }),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ]),
            ),
            Center(
              child: ElevatedButton(
                  onPressed: () {
                    widget.debugPanelOptions.chatters.add(TwitchChatterMock(
                        displayName: 'New chatter', isModerator: false));
                    widget.onChanged();
                    setState(() {});
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  child: const Text(
                    'Add chatter',
                    style: TextStyle(color: Colors.black),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBox extends StatefulWidget {
  const _ChatBox({
    required this.manager,
    required this.debugPanelOptions,
    required this.maxWidth,
  });

  final TwitchManagerMock manager;
  final TwitchDebugPanelOptions debugPanelOptions;
  final double maxWidth;

  @override
  State<_ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends State<_ChatBox> {
  int _currentSender = 0;
  final _senderFocus = FocusNode();
  final _messageController = TextEditingController();

  bool _isSending = false;

  String get _currentChatterName =>
      widget.debugPanelOptions.chatters[_currentSender].displayName;

  void _sendMessage(String message) {
    if (message == '') return;

    // Send the message
    widget.manager.chat.send(message, username: _currentChatterName);

    // Do some internal work with it
    if (!widget.debugPanelOptions.chatMessages.contains(message)) {
      widget.debugPanelOptions.chatMessages.add(message);
    }

    _isSending = true;
    Future.delayed(const Duration(seconds: 1, milliseconds: 500)).then((_) {
      _messageController.text = '';
      _isSending = false;
      if (mounted) setState(() {});
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedExpandingCard(
      header: const Text('Chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      initialExpandedState: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Wrap(
                  children: [
                    Text('Send message as $_currentChatterName ',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    if (widget
                        .debugPanelOptions.chatters[_currentSender].isModerator)
                      const Text('(moderator)',
                          style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              SizedBox(
                width: 40,
                child: SubmenuButton(
                  focusNode: _senderFocus,
                  menuChildren: widget.debugPanelOptions.chatters
                      .asMap()
                      .keys
                      .map((index) => InkWell(
                            onTap: () {
                              _currentSender = index;
                              if (_senderFocus.hasFocus) {
                                _senderFocus.nextFocus();
                              }
                              setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(widget.debugPanelOptions
                                  .chatters[index].displayName),
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
                    color: _isSending
                        ? const Color.fromARGB(255, 222, 222, 222)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(5)),
                child: DropdownMenu(
                  enabled: !_isSending,
                  width: widget.maxWidth - 3 * 8 - 90,
                  controller: _messageController,
                  dropdownMenuEntries: widget.debugPanelOptions.chatMessages
                      .map((e) => DropdownMenuEntry(label: e, value: e))
                      .toList(),
                  onSelected: (value) =>
                      _sendMessage(value ?? _messageController.text),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: ElevatedButton(
                    onPressed: _isSending
                        ? () {}
                        : () => _sendMessage(_messageController.text),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _isSending
                            ? const Color.fromARGB(255, 222, 222, 222)
                            : Colors.white),
                    child: Text(
                      _isSending ? 'Done!' : 'Send',
                      style: const TextStyle(color: Colors.black),
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RedemptionRedeemBox extends StatefulWidget {
  const _RedemptionRedeemBox({
    required this.manager,
    required this.debugPanelOptions,
    required this.maxWidth,
  });

  final TwitchManagerMock manager;
  final TwitchDebugPanelOptions debugPanelOptions;
  final double maxWidth;

  @override
  State<_RedemptionRedeemBox> createState() => _RedemptionRedeemBoxState();
}

class _RedemptionRedeemBoxState extends State<_RedemptionRedeemBox> {
  @override
  void initState() {
    super.initState();
    widget.manager.api.onRewardRedemptionsChanged.startListening(refresh);
  }

  @override
  void dispose() {
    widget.manager.api.onRewardRedemptionsChanged.stopListening(refresh);
    super.dispose();
  }

  void refresh(
          {required TwitchRewardRedemption reward, required bool wasDeleted}) =>
      setState(() {});

  int _currentRedempter = 0;
  TwitchRewardRedemption? _isRedempting;
  final _focusNode = FocusNode();

  void _redeemReward(TwitchRewardRedemption reward) {
    if (widget.debugPanelOptions.simulateRewardRedemption == null) return;

    // Simulate the reward redemption
    final redeemed = reward.copyWith(
        requestingUser:
            widget.debugPanelOptions.chatters[_currentRedempter].displayName);
    widget.debugPanelOptions.simulateRewardRedemption!(redeemed);

    _isRedempting = reward;
    setState(() {});

    Future.delayed(const Duration(seconds: 1, milliseconds: 500))
        .then((_) => setState(() => _isRedempting = null));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedExpandingCard(
      header: const Text('Redemption',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  '    Redeem a reward as ${widget.debugPanelOptions.chatters[_currentRedempter].displayName} ',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(
                width: 40,
                child: SubmenuButton(
                  focusNode: _focusNode,
                  menuChildren: widget.debugPanelOptions.chatters
                      .asMap()
                      .keys
                      .map((index) => InkWell(
                            onTap: () {
                              _currentRedempter = index;
                              if (_focusNode.hasFocus) _focusNode.nextFocus();
                              setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(widget.debugPanelOptions
                                  .chatters[index].displayName),
                            ),
                          ))
                      .toList(),
                  child: const Icon(Icons.arrow_drop_down),
                ),
              )
            ],
          ),
          AnimatedExpandingCard(
            header: const Text('    Defined in the app',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.manager.api.rewardRedemptions.isEmpty)
                    const Text('No rewards defined',
                        style: TextStyle(color: Colors.white)),
                  if (widget.manager.api.rewardRedemptions.isNotEmpty)
                    ...widget.manager.api.rewardRedemptions
                        .asMap()
                        .keys
                        .map((index) {
                      final reward =
                          widget.manager.api.rewardRedemptions[index];

                      return Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Column(children: [
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(reward.rewardRedemption,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ),
                                Text(reward.cost.toString(),
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Add a textformfield to edit the cost
                            Row(children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: _isRedempting == reward
                                          ? const Color.fromARGB(
                                              255, 222, 222, 222)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(5)),
                                  child: TextFormField(
                                    decoration: const InputDecoration(
                                        labelText: 'Message',
                                        labelStyle:
                                            TextStyle(color: Colors.black)),
                                    initialValue: reward.message.toString(),
                                    onChanged: (value) => widget.manager.api
                                            .rewardRedemptions[index] =
                                        reward.copyWith(message: value),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                  onPressed: _isRedempting == reward
                                      ? () {}
                                      : () => _redeemReward(reward),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: _isRedempting == reward
                                          ? const Color.fromARGB(
                                              255, 222, 222, 222)
                                          : Colors.white),
                                  child: Text(
                                    _isRedempting == reward
                                        ? 'Done!'
                                        : 'Redempt',
                                    style: const TextStyle(color: Colors.black),
                                  )),
                            ]),
                          ]));
                    }),
                ],
              ),
            ),
          ),
          const Divider(),
          AnimatedExpandingCard(
            header: const Text('    Defined in Twitch',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: widget.debugPanelOptions.redemptionRewardEvents
                        .asMap()
                        .keys
                        .map((index) {
                      final reward = widget
                          .debugPanelOptions.redemptionRewardEvents[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: _isRedempting == reward
                                            ? const Color.fromARGB(
                                                255, 222, 222, 222)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(5)),
                                    child: TextFormField(
                                      initialValue: reward.rewardRedemption,
                                      onChanged: (value) => widget
                                              .debugPanelOptions
                                              .redemptionRewardEvents[index] =
                                          reward.copyWith(
                                              rewardRedemption: value),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 90,
                                  decoration: BoxDecoration(
                                      color: _isRedempting == reward
                                          ? const Color.fromARGB(
                                              255, 222, 222, 222)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(5)),
                                  child: TextFormField(
                                    decoration: const InputDecoration(
                                        labelText: 'Cost',
                                        labelStyle:
                                            TextStyle(color: Colors.black)),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    initialValue: reward.cost.toString(),
                                    onChanged: (value) => widget
                                            .debugPanelOptions
                                            .redemptionRewardEvents[index] =
                                        reward.copyWith(cost: int.parse(value)),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Add a textformfield to edit the cost
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: _isRedempting == reward
                                            ? const Color.fromARGB(
                                                255, 222, 222, 222)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(5)),
                                    child: TextFormField(
                                      decoration: const InputDecoration(
                                          labelText: 'Message',
                                          labelStyle:
                                              TextStyle(color: Colors.black)),
                                      initialValue: reward.message.toString(),
                                      onChanged: (value) => widget
                                              .debugPanelOptions
                                              .redemptionRewardEvents[index] =
                                          reward.copyWith(message: value),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                    onPressed: _isRedempting == reward
                                        ? () {}
                                        : () => _redeemReward(reward),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: _isRedempting == reward
                                            ? const Color.fromARGB(
                                                255, 222, 222, 222)
                                            : Colors.white),
                                    child: Text(
                                      _isRedempting == reward
                                          ? 'Done!'
                                          : 'Redempt',
                                      style:
                                          const TextStyle(color: Colors.black),
                                    )),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  Center(
                    child: ElevatedButton(
                        onPressed: () {
                          widget.debugPanelOptions.redemptionRewardEvents.add(
                              TwitchRewardRedemptionMock(
                                  rewardRedemptionId: '12345',
                                  rewardRedemption: 'New reward',
                                  cost: 0));
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white),
                        child: const Text(
                          'Add reward',
                          style: TextStyle(color: Colors.black),
                        )),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
