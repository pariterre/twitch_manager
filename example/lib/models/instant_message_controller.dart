import 'package:example/main.dart';

class InstantMessageController {
  InstantMessageController();

  String message = '';
  bool get isReadyToSend => TwitchManagerSingleton.isConnected && message != '';

  void sendText() => TwitchManagerSingleton.send(message);
}
