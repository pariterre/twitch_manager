import 'dart:convert';
import 'dart:developer' as dev;

import 'package:twitch_manager/twitch_app_info.dart';
import 'package:web_socket_client/web_socket_client.dart' as ws;

const _twitchEventUri = 'wss://eventsub.wss.twitch.tv/ws';

class TwitchEvent {
  ///
  /// The constructor for the Twitch Event
  /// [appInfo] holds all the information required to subscribe to the event
  static Future<TwitchEvent> factory({required TwitchAppInfo appInfo}) async {
    await _subscribeToEvent();
    return TwitchEvent._();
  }

  Future<void> disconnect() async {
    // TODO: implement disconnect
  }

  ////// INTERNAL //////

  ///
  /// ATTRIBUTES

  ///
  /// Private constructor
  TwitchEvent._();

  ///
  /// Subscribe to the Twitch event to receive the events
  static Future<void> _subscribeToEvent() async {
    bool responseReceived = false;
    void responseFromTwitch(ws.WebSocket socket, message) {
      final map = jsonDecode(message);
      dev.log(map);
      responseReceived = true;
    }

    // Communication procedure
    final channel = ws.WebSocket(Uri.parse(_twitchEventUri));
    channel.messages.listen((message) => responseFromTwitch(channel, message));

    // Wait until response is received
    while (!responseReceived) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    channel.send(json.encode({'status': 'thanks'}));
    channel.close();
  }
}

class TwitchEventMock extends TwitchEvent {
  ///
  /// The constructor for the Twitch API
  /// [appInfo] holds all the information required to run the API
  /// [authenticator] holds the OAuth key to communicate with the API
  static Future<TwitchEventMock> factory() async => TwitchEventMock._();

  ////// INTERNAL //////

  ///
  /// Private constructor
  TwitchEventMock._() : super._();
}
