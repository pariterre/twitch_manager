import 'package:flutter/material.dart';
import 'package:twitch_manager/models/twitch_manager_internal.dart';

class TwitchConnectButton extends StatelessWidget {
  const TwitchConnectButton({
    super.key,
    required this.twitchManager,
    required this.onPressed,
  });

  final TwitchManager? twitchManager;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    bool isConnected = twitchManager != null && twitchManager!.isConnected;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6441a5),
          foregroundColor: Colors.white),
      child: Text(isConnected ? 'Reconnect to twitch' : 'Connect to Twitch'),
    );
  }
}
