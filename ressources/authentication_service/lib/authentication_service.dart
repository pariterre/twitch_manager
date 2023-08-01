import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:authentication_service/models/twitch_client.dart';
import 'package:authentication_service/models/twitch_responses.dart';

final _twitchResponses = TwitchResponses();
final Map<int, TwitchClient> clients = {};

final redirectAddress = 'http://localhost:3000';
final successWebsite = '<!DOCTYPE html>'
    '<html><body>'
    'You can close this page'
    '<script>'
    'var xhr = new XMLHttpRequest();'
    'xhr.open("POST", \'$redirectAddress\', true);'
    'xhr.setRequestHeader(\'Content-Type\', \'application/json\');'
    'xhr.send(JSON.stringify({\'token\': window.location.href}));'
    '</script>'
    '</body></html>';

void twitchResponseCallback(Socket client) {
  client.listen((data) async {
    // Parse the twitch answer

    final answerAsString = String.fromCharCodes(data).trim().split('\r\n');
    if (answerAsString.first == 'GET / HTTP/1.1') {
      print('Message from Twitch received, sending the token to next page...');
      // Send the success page to browser (allowing ourselves to fetch the
      // token in the address bar)
      client.write('HTTP/1.1 200 OK\nContent-Type: text\n'
          'Content-Length: ${successWebsite.length}\n'
          '\n'
          '$successWebsite');
      client.close();
    } else if (answerAsString.last.contains('token')) {
      print('Message from previous received, fetching token');
      // Otherwise it is a POST we sent ourselves in the success page
      // For some reason, this function is call sometimes more than once
      _twitchResponses.add(jsonDecode(answerAsString.last)['token']!);
      return;
    }
  });
}

int _maximumDowntime = 15; // seconds

void _terminateConnexion(int id, {required bool isSuccess}) {
  if (!clients.containsKey(id)) return;

  clients[id]!.terminateConnexion();
  clients.remove(id);
  print('Client $id was drop (${isSuccess ? 'sucess' : 'downtime'})');
}

void clientHandShake(WebSocket socket) {
  final client =
      TwitchClient(socket, onRequestTermination: _terminateConnexion);
  final id = client.id;
  print('Client $id has connected');
  clients[id] = client;

  Timer.periodic(Duration(seconds: 1), (timer) async {
    int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now - client.createTime > _maximumDowntime) {
      timer.cancel();
      _terminateConnexion(id, isSuccess: false);
      return;
    }

    // Check if the stateToken corresponds to any responses from Twitch so far
    if (_twitchResponses.containStateToken(client.stateToken)) {
      client.sendTwitchAnswer(await _twitchResponses.pop(client.stateToken!));
    }
  });
}
