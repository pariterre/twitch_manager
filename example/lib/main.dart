import 'package:flutter/material.dart';
import 'package:twitch_manager/twitch_manager.dart';

import 'twitch_chat_bot.dart';

void main() async {
  runApp(MaterialApp(
    initialRoute: TwitchAuthenticationScreen.route,
    routes: {
      TwitchAuthenticationScreen.route: (ctx) =>
          const TwitchAuthenticationScreen(
            nextRoute: TwitchChatBot.route,
            appId: 'YOUR_APP_ID',
            scope: [
              TwitchScope.chatRead,
              TwitchScope.chatEdit,
              TwitchScope.chatters,
              TwitchScope.readFollowers,
              TwitchScope.readSubscribers,
            ],
            withModerator: false,
            forceNewAuthentication: true,
          ),
      TwitchChatBot.route: (ctx) => const TwitchChatBot(),
    },
  ));
}
