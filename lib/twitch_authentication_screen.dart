import 'package:flutter/material.dart';
import 'package:twitch_manager/twitch_app_info.dart';
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
/// is to pop the window or push another one); [hasChatbot] is typically
/// to register a chatbot (the user the app will publish on the chat), if it is
/// false, then streamer username is used; [forceNewAuthentication] is to forget
/// previous connexion and request a new OAUTH key.
class TwitchAuthenticationScreen extends StatefulWidget {
  const TwitchAuthenticationScreen({
    super.key,
    required this.appInfo,
    required this.onFinishedConnexion,
    required this.hasChatbot,
    this.forceNewAuthentication = false,
  });
  static const route = '/twitch-authentication';
  final Function(TwitchManager) onFinishedConnexion;

  final TwitchAppInfo appInfo;
  final bool hasChatbot;
  final bool forceNewAuthentication;

  @override
  State<TwitchAuthenticationScreen> createState() =>
      _TwitchAuthenticationScreenState();
}

class _TwitchAuthenticationScreenState
    extends State<TwitchAuthenticationScreen> {
  _ConnexionStatus _status = _ConnexionStatus.waitToEstablishConnexion;
  String? _redirectAddress;
  late final _manager = TwitchManager.factory(
      appInfo: widget.appInfo, hasChatbot: widget.hasChatbot);
  final _formKey = GlobalKey<FormState>();

  String? oauthKey;

  Future<void> _connectStreamer({bool skipFormValidation = false}) async {
    if (!skipFormValidation && !_formKey.currentState!.validate()) return;

    // Twitch app informations
    final manager = await _manager;

    await manager.connectStreamer(onRequestBrowsing: _onRequestBrowsing);
    if (!manager.isInitialized) {
      return;
    }

    setState(() {
      _status = _ConnexionStatus.connected;
    });
    widget.onFinishedConnexion(manager);
  }

  Future<void> _onRequestBrowsing(String address) async {
    _redirectAddress = address;
    setState(() {
      _status = _ConnexionStatus.waitForTwitchValidation;
    });

    await launchUrl(
      Uri.parse(_redirectAddress!),
      mode: LaunchMode.inAppWebView,
    );
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
          ElevatedButton(
            onPressed: _connectStreamer,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: const Text(
              'Connect streamer',
              style: TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.hasChatbot)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 10.0),
              child: ElevatedButton(
                onPressed: _connectStreamer,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                child: const Text(
                  'Connect chatbot',
                  style: TextStyle(color: Colors.black),
                ),
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
                _buildConnexionGui(),
              ],
            )),
      )),
    );
  }
}
