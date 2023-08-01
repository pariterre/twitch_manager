import 'dart:io';

import 'package:authentication_service/authentication_service.dart';

void main(List<String> arguments) async {
  print('Preparing for connexion from Twitch');
  final serverToTwitch = await ServerSocket.bind('localhost', 3000);
  serverToTwitch.listen(twitchResponseCallback);

  print('Preparing connexion from software');
  HttpServer server = await HttpServer.bind(InternetAddress.anyIPv6, 3002);
  server.transform(WebSocketTransformer()).listen(clientHandShake);

  print('Server ready');
}
