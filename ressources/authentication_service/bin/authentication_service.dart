import 'dart:io';

import 'package:authentication_service/authentication_service.dart';
import 'package:authentication_service/twitch_config.dart';

void main(List<String> arguments) async {
  // This is the forward port that connect to Twitch (i.e. the website Twitch calls
  // after the user authenticates)
  print('Preparing for connexion with Twitch');
  final serverToTwitch = await ServerSocket.bind('localhost', twitchPortLocal);
  serverToTwitch.listen(twitchResponseCallback);

  // This is the port that communicates with the application
  // from the user. It is used to return the token to the app.
  print('Preparing connexion with the software');
  HttpServer server =
      await HttpServer.bind(InternetAddress.anyIPv6, appPortLocal);
  server.transform(WebSocketTransformer()).listen(clientHandShake);

  print('Server ready');
}
