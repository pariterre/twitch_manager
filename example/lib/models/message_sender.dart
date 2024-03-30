import 'package:example/main.dart';

class MessageSender {
  MessageSender();

  String message = '';
  bool get isReadyToSend => TwitchManagerSingleton.isConnected && message != '';

  void sendText() => TwitchManagerSingleton.send(message);
}
