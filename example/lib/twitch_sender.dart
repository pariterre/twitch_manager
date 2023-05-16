import 'dart:async';

import 'package:twitch_manager/twitch_manager.dart';

class TwitchSender {
  TwitchSender({required this.twitchManager, this.message = ''});

  final TwitchManager twitchManager;
  String message;
  bool get isReadyToSend => message != '';

  void sendText() => twitchManager.irc!.send(message);
}

class ReoccurringTwitchSender extends TwitchSender {
  ReoccurringTwitchSender({
    required super.twitchManager,
    super.message = '',
    this.interval,
  });

  bool isStreaming = false;
  Duration? interval;
  Timer? _timer;

  @override
  bool get isReadyToSend =>
      interval != null && !isStreaming && super.isReadyToSend;

  @override
  void sendText() {
    if (isStreaming || interval == null) return;

    _timer = Timer.periodic(interval!, (timer) async {
      super.sendText();
    });
    isStreaming = true;
  }

  void stopSending() {
    if (_timer == null) return;

    _timer!.cancel();
    isStreaming = false;
  }
}
