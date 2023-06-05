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

///
/// This is the main window to call to connect to twitch. [appId] is the id
/// provided by twitch; [scope] is a requested rights for the app;
/// [onFinishedConnexion] is the callback when connexion is done (typically, it
/// is to pop the window or push another one); [withChatbot] is typically
/// to register a chatbot (the user the app will publish on the chat), if it is
/// false, then streamer username is used; [forceNewAuthentication] is to forget
/// previous connexion and request a new OAUTH key.
class TwitchAuthenticationScreen extends StatefulWidget {
  const TwitchAuthenticationScreen({
    super.key,
    required this.appId,
    required this.scope,
    required this.onFinishedConnexion,
    required this.withChatbot,
    this.forceNewAuthentication = false,
  });
  static const route = '/twitch-authentication';
  final Function(TwitchManager) onFinishedConnexion;

  final String appId;
  final List<TwitchScope> scope;
  final bool withChatbot;
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
  String? chatbotUsername;

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
    chatbotUsername = prefs.getString('chatbot_username');

    if (oauthKey != null &&
        oauthKey!.isNotEmpty &&
        streamerUsername != null &&
        streamerUsername!.isNotEmpty &&
        chatbotUsername != null &&
        chatbotUsername!.isNotEmpty) {
      setState(() {
        _status = _ConnexionStatus.connected;
      });
      _connectToTwitch();
    }
    return true;
  }

  Future<void> _connectToTwitch({bool skipFormValidation = false}) async {
    if (!skipFormValidation && !_formKey.currentState!.validate()) return;

    // Twitch app informations
    final authentication = await TwitchAuthentication.factory(
      appId: widget.appId,
      scope: widget.scope,
      oauthKey: oauthKey,
      streamerUsername: streamerUsername!,
      chatbotUsername: chatbotUsername,
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

    widget.onFinishedConnexion(_manager!);
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
    if (mounted) {
      setState(() {
        _status = _ConnexionStatus.wrongToken;
      });
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('oauth_key');
  }

  Future<void> _saveAuthentication(
      String oauth, String streamerUsername, String chatbotUsername) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('oauth_key', oauth);
    prefs.setString('streamer_username', streamerUsername);
    prefs.setString('chatbot_username', chatbotUsername);
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
    if (widget.withChatbot) {
      throw 'withChatbot is now broken and cannot be used, if you don\'t use API, '
          'you can log only with the bot if it was given moderator access';
    }

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
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5)),
                  child: TextFormField(
                    onChanged: (newName) => streamerUsername = newName,
                    decoration:
                        const InputDecoration(labelText: 'Streamer username'),
                    style: const TextStyle(color: Colors.black),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please write a username'
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _connectToTwitch,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                child: const Text(
                  'Connect',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.withChatbot)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5)),
                    child: TextFormField(
                      onChanged: (newName) => chatbotUsername = newName,
                      decoration:
                          const InputDecoration(labelText: 'Chatbot username'),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please write a chatbot username'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 10.0),
                  child: ElevatedButton(
                    onPressed: _connectToTwitch,
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.white),
                    child: const Text(
                      'Connect',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ],
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
            padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 15),
            child: _buildLogginForms(),
          ),
        if (_status == _ConnexionStatus.waitForTwitchValidation)
          _buildNavigateTo(),
        if (_status == _ConnexionStatus.wrongToken) _buildWrongToken(),
        if (_status == _ConnexionStatus.connected)
          _buildWaitingMessage('Please wait while we are logging you'),
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
