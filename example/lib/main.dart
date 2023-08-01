import 'package:flutter/material.dart';
import 'package:twitch_manager/twitch_manager.dart';

import 'twitch_chat_bot.dart';

void main() async {
  runApp(MaterialApp(
    initialRoute: TwitchAuthenticationScreen.route,
    routes: {
      TwitchAuthenticationScreen.route: (ctx) => TwitchAuthenticationScreen(
            mockOptions: const TwitchMockOptions(
              isActive: true,
            ),
            onFinishedConnexion: (manager) => Navigator.of(ctx)
                .pushReplacementNamed(TwitchChatBot.route, arguments: manager),
            appInfo: TwitchAppInfo(
              appName: 'My Lovely App',
              twitchAppId: 'YOUR_APP_ID_HERE',
              scope: const [
                TwitchScope.chatRead,
                TwitchScope.chatEdit,
                TwitchScope.chatters,
                TwitchScope.readFollowers,
                TwitchScope.readSubscribers,
              ],
              redirectAddress: 'http://localhost:3000',
              useLocalAuthenticationServer: true,
            ),
            loadPreviousSession: false,
          ),
      TwitchChatBot.route: (ctx) => const TwitchChatBot(),
    },
  ));
}
