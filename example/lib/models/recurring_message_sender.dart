import 'dart:async';

import 'package:example/main.dart';

class ReccurringMessageSender {
  ReccurringMessageSender();

  String message = '';

  bool _isStarted = false;
  bool get isStarted => _isStarted;

  Duration _interval = Duration.zero;
  set interval(Duration value) =>
      _interval = value.inSeconds > 0 ? value : Duration.zero;

  Duration _delay = Duration.zero;
  set delay(Duration value) =>
      _delay = value.inSeconds > 0 ? value : Duration.zero;

  Timer? _timer;

  bool get isReadyToSend =>
      _interval != Duration.zero &&
      !isStarted &&
      TwitchManagerSingleton.isConnected &&
      message != '';

  void sendText() => TwitchManagerSingleton.send(message);

  void startStreamingText() {
    if (isStarted || _interval == Duration.zero) return;

    _isStarted = true;
    Future.delayed(_delay, () {
      if (!_isStarted) return;
      sendText();
      _timer = Timer.periodic(_interval, (timer) async => sendText());
    });
  }

  void stopStreamingText() {
    _isStarted = false;

    if (_timer == null) return;
    _timer!.cancel();
  }
}
