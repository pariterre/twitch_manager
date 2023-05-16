import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:twitch_manager/twitch_manager.dart';

class TwitchAuthenticationScreen extends StatefulWidget {
  const TwitchAuthenticationScreen({
    super.key,
    required this.nextRoute,
    required this.appId,
    required this.scope,
    required this.streamerName,
    required this.moderatorName,
  });
  static const route = '/authentication';
  final String nextRoute;

  final String appId;
  final List<TwitchScope> scope;
  final String streamerName;
  final String moderatorName;

  @override
  State<TwitchAuthenticationScreen> createState() =>
      _TwitchAuthenticationScreenState();
}

class _TwitchAuthenticationScreenState
    extends State<TwitchAuthenticationScreen> {
  String? _textToShow;
  TwitchManager? _manager;

  @override
  void initState() {
    super.initState();
    _connectToTwitch();
  }

  Future<void> _connectToTwitch() async {
    final navigator = Navigator.of(context);

    // Twitch app informations
    const oauthJsonPath = 'oauth.json';
    String? oauthKey = await File(oauthJsonPath).exists()
        ? jsonDecode(File(oauthJsonPath).readAsStringSync())['oauthKey']
        : null;

    final authentication = TwitchAuthentication(
      oauthKey: oauthKey,
      appId: widget.appId,
      scope: widget.scope,
      streamerName: widget.streamerName,
      moderatorName: widget.moderatorName,
    );

    _manager = await TwitchManager.factory(
        authentication: authentication,
        onAuthenticationRequest: _manageRequestUserToBrowse,
        onAuthenticationSuccess: (address) async =>
            _saveOauthKey(address, oauthJsonPath),
        onInvalidToken: _manageInvalidToken);
    navigator.pushReplacementNamed(widget.nextRoute, arguments: _manager);
  }

  Future<void> _manageRequestUserToBrowse(String address) async {
    _textToShow = 'Please navigate to\n$address';
    setState(() {});
  }

  Future<void> _manageInvalidToken() async {
    _textToShow = 'Invalid token, please renew the OAUTH authentication';
  }

  @override
  Widget build(BuildContext context) {
    late Widget widgetToShow;
    if (_textToShow == null) {
      widgetToShow = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Center(child: Text('Please wait while we are logging you')),
          Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          )
        ],
      );
    } else {
      widgetToShow = Center(child: SelectableText(_textToShow!));
    }

    return Scaffold(
      body: widgetToShow,
    );
  }
}

Future<void> _saveOauthKey(String oauthKey, String oauthJsonPath) async {
  final file = File(oauthJsonPath);
  await file.writeAsString(json.encode({'oauthKey': oauthKey}));
}
