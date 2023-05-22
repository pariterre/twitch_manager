import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twitch_manager/twitch_manager.dart';
import 'package:url_launcher/url_launcher.dart';

enum _ConnexionStatus {
  waitToEstablishConnexion,
  waitForTwitchValidation,
  wrongToken,
  connected,
}

class TwitchAuthenticationScreen extends StatefulWidget {
  const TwitchAuthenticationScreen({
    super.key,
    required this.nextRoute,
    required this.appId,
    required this.scope,
    required this.withModerator,
    this.forceNewAuthentication = false,
  });
  static const route = '/twitch-authentication';
  final String nextRoute;

  final String appId;
  final List<TwitchScope> scope;
  final bool withModerator;
  final bool forceNewAuthentication;

  @override
  State<TwitchAuthenticationScreen> createState() =>
      _TwitchAuthenticationScreenState();
}

class _TwitchAuthenticationScreenState
    extends State<TwitchAuthenticationScreen> {
  _ConnexionStatus _status = _ConnexionStatus.waitToEstablishConnexion;
  late Future<bool> _isLoading;
  String? _redirectAddress;
  TwitchManager? _manager;
  final _formKey = GlobalKey<FormState>();

  String? oauthKey;
  String? streamerUsername;
  String? moderatorUsername;

  @override
  void initState() {
    super.initState();

    _isLoading = _getAuthenticationFromSharedPreferences();
  }

  Future<bool> _getAuthenticationFromSharedPreferences() async {
    if (widget.forceNewAuthentication) return true;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    oauthKey = prefs.getString('oauth_key');
    streamerUsername = prefs.getString('streamer_username');
    moderatorUsername = prefs.getString('moderator_username');

    if (oauthKey != null &&
        oauthKey!.isNotEmpty &&
        streamerUsername != null &&
        streamerUsername!.isNotEmpty &&
        moderatorUsername != null &&
        moderatorUsername!.isNotEmpty) {
      _connectToTwitch();
    }
    return true;
  }

  Future<void> _connectToTwitch({bool skipFormValidation = false}) async {
    if (!skipFormValidation && !_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    if (!mounted) return;

    // Twitch app informations
    final authentication = await TwitchAuthentication.factory(
      appId: widget.appId,
      scope: widget.scope,
      oauthKey: oauthKey,
      streamerName: streamerUsername!,
      moderatorName: moderatorUsername,
    );

    _manager = await TwitchManager.factory(
      authentication: authentication,
      onAuthenticationRequest: _manageRequestUserToBrowse,
      onInvalidToken: _manageInvalidToken,
      onSuccess: _saveAuthentication,
    );

    if (!mounted) return;

    setState(() {
      _status = _ConnexionStatus.connected;
    });

    navigator.pushReplacementNamed(widget.nextRoute, arguments: _manager);
  }

  Future<void> _manageRequestUserToBrowse(String address) async {
    _redirectAddress = address;
    setState(() {
      _status = _ConnexionStatus.waitForTwitchValidation;
    });

    await launchUrl(
      Uri.parse(_redirectAddress!),
      mode: LaunchMode.inAppWebView,
    );
  }

  Future<void> _manageInvalidToken() async {
    setState(() {
      _status = _ConnexionStatus.wrongToken;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('oauth_key');
  }

  Future<void> _saveAuthentication(
      String oauth, String streamerUsername, String moderatorUsername) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('oauth_key', oauth);
    prefs.setString('streamer_username', streamerUsername);
    prefs.setString('moderator_username', moderatorUsername);
  }

  Widget _buildWaitingMessage(String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
            child: Text(
          message,
          style: const TextStyle(color: Colors.white),
        )),
        const Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      ],
    );
  }

  Widget _buildNavigateTo() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.only(left: 18.0, right: 18.0, top: 12, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You will be redirected to the Twitch logging page. '
              'If it does not happen automatically, please navigate to:',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            SelectableText(
              _redirectAddress!,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () async => await launchUrl(
                Uri.parse(_redirectAddress!),
                mode: LaunchMode.inAppWebView,
              ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text(
                'Or click here',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWrongToken() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(left: 18.0, right: 18.0, top: 12, bottom: 20),
        child: Text(
          'Invalid token, please wait while we renew your OAUTH authentication',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildLogginForms() {
    return Theme(
      data: ThemeData(
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.black),
          hintStyle: TextStyle(color: Colors.black),
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          enabledBorder:
              OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          focusedBorder:
              OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(5)),
            child: TextFormField(
              onChanged: (newName) => streamerUsername = newName,
              decoration: const InputDecoration(labelText: 'Streamer username'),
              style: const TextStyle(color: Colors.black),
              validator: (value) => value == null || value.isEmpty
                  ? 'Please write a username'
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.withModerator)
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(5)),
              child: TextFormField(
                onChanged: (newName) => moderatorUsername = newName,
                decoration:
                    const InputDecoration(labelText: 'Moderator username'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please write a moderator username'
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnexionGui() {
    return Column(
      children: [
        if (_status == _ConnexionStatus.waitToEstablishConnexion)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _buildLogginForms(),
          ),
        if (_status == _ConnexionStatus.waitForTwitchValidation)
          _buildNavigateTo(),
        if (_status == _ConnexionStatus.wrongToken) _buildWrongToken(),
        if (_status == _ConnexionStatus.connected)
          _buildWaitingMessage('Please wait while we are logging you'),
        if (_status == _ConnexionStatus.waitToEstablishConnexion)
          Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 10.0),
            child: ElevatedButton(
              onPressed: _connectToTwitch,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text(
                'Connect',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _isLoading,
        builder: (context, snapshot) {
          return Form(
            key: _formKey,
            child: Scaffold(
                body: Center(
              child: Container(
                  color: const Color.fromARGB(255, 119, 35, 215),
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Text(
                          'TWITCH AUTHENTICATION',
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ),
                      if (!snapshot.hasData)
                        _buildWaitingMessage('Please wait'),
                      if (snapshot.hasData) _buildConnexionGui(),
                    ],
                  )),
            )),
          );
        });
  }
}
