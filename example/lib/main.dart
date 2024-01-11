import 'package:flutter/material.dart';
import 'package:twitch_manager/twitch_manager.dart';

import 'twitch_chat_bot_screen.dart';

void main() async {
  runApp(MaterialApp(
    initialRoute: TwitchAuthenticationScreen.route,
    routes: {
      TwitchAuthenticationScreen.route: (ctx) => TwitchAuthenticationScreen(
            isMockActive: true,
            debugPanelOptions: TwitchDebugPanelOptions(
              chatters: [
                TwitchChatterMock(displayName: 'Streamer', isModerator: true),
                TwitchChatterMock(displayName: 'Moderator', isModerator: true),
                TwitchChatterMock(displayName: 'Viewer'),
              ],
              chatMessages: [
                'Hello World!',
                'This is a test message',
                'This is a test message 2',
              ],
            ),
            onFinishedConnexion: (manager) => Navigator.of(ctx)
                .pushReplacementNamed(TwitchChatBotScreen.route,
                    arguments: manager),
            appInfo: TwitchAppInfo(
              appName: 'My Lovely App',
              twitchAppId: 'YOUR_APP_ID_HERE',
              redirectDomain: 'YOUR_REDIRECT_DOMAIN_HERE',
              scope: const [
                TwitchScope.chatRead,
                TwitchScope.chatEdit,
                TwitchScope.chatters,
                TwitchScope.readFollowers,
              ],
            ),
            reload: false,
          ),
      TwitchChatBotScreen.route: (ctx) => const TwitchChatBotScreen(),
    },
  ));
}
