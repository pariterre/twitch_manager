import 'package:flutter/material.dart';
import 'package:twitch_manager/twitch_manager.dart';

import 'twitch_chat_bot_screen.dart';

void main() async {
  runApp(MaterialApp(
    initialRoute: TwitchAuthenticationScreen.route,
    routes: {
      TwitchAuthenticationScreen.route: (ctx) => TwitchAuthenticationScreen(
            mockOptions: const TwitchMockOptions(
              isActive: true,
            ),
            onFinishedConnexion: (manager) => Navigator.of(ctx)
                .pushReplacementNamed(TwitchChatBotScreen.route,
                    arguments: manager),
            appInfo: TwitchAppInfo(
              appName: 'My Lovely App',
              twitchAppId: 'YOUR_APP_ID_HERE',
              scope: const [
                TwitchScope.chatRead,
                TwitchScope.chatEdit,
                TwitchScope.chatters,
                TwitchScope.readFollowers,
              ],
              redirectAddress: 'http://localhost:3000',
              useAuthenticationService: false,
              // The following line must be uncommented if [useAuthenticationService] is true
              // authenticationServiceAddress: 'ws://localhost:3002',
            ),
            reload: false,
          ),
      TwitchChatBotScreen.route: (ctx) => const TwitchChatBotScreen(),
    },
  ));
}
