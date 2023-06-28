import 'package:flutter/material.dart';
import 'package:twitch_manager/twitch_manager.dart';
import 'package:url_launcher/url_launcher.dart';

///
/// A helper to follow the current status of connexion
enum _ConnexionStatus {
  waitForUser,
  waitForTwitchValidation,
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
    this.loadPreviousSession = true,
    this.useMock = false,
  });

  final bool useMock;

  static const route = '/twitch-authentication';
  final Function(TwitchManager) onFinishedConnexion;

  final TwitchAppInfo appInfo;
  final bool loadPreviousSession;

  @override
  State<TwitchAuthenticationScreen> createState() =>
      _TwitchAuthenticationScreenState();
}

class _TwitchAuthenticationScreenState
    extends State<TwitchAuthenticationScreen> {
  var _status = _ConnexionStatus.waitForUser;
  String? _redirectAddress;
  TwitchManager? _manager;
  late Future<TwitchManager> factoryManager = widget.useMock
      ? TwitchManagerMock.factory(
          appInfo: widget.appInfo,
          loadPreviousSession: widget.loadPreviousSession)
      : TwitchManager.factory(
          appInfo: widget.appInfo,
          loadPreviousSession: widget.loadPreviousSession);

  Future<void> _connectStreamer() async {
    if (_manager == null) return;

    await _manager!.connectStreamer(onRequestBrowsing: _onRequestBrowsing);
    _checkForConnexionDone();
  }

  Future<void> _connectChatbot() async {
    if (_manager == null) return;

    await _manager!.connectChatbot(onRequestBrowsing: _onRequestBrowsing);
    _checkForConnexionDone();
  }

  _checkForConnexionDone({bool skipSetState = false}) {
    // This will be false if chatbot should be initialized
    if (!_manager!.isConnected) {
      _status = _ConnexionStatus.waitForUser;
      if (!skipSetState) {
        setState(() {});
      }
      return;
    }

    _status = _ConnexionStatus.connected;
    if (!skipSetState) {
      setState(() {});
    }

    // If we get here, we are done authenticating
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      widget.onFinishedConnexion(_manager!);
    });
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

  Widget _buildBrowseTo() {
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

  Widget _buildButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _manager != null && _manager!.isStreamerConnected
              ? null
              : _connectStreamer,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
          child: const Text(
            'Connect streamer',
            style: TextStyle(color: Colors.black),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.appInfo.hasChatbot)
          ElevatedButton(
            onPressed: _manager == null || !_manager!.isStreamerConnected
                ? null
                : _connectChatbot,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: const Text(
              'Connect chatbot',
              style: TextStyle(color: Colors.black),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: FutureBuilder(
          future: factoryManager,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_manager == null && snapshot.hasData) {
              _manager = snapshot.data;
              _checkForConnexionDone(skipSetState: true);
            }

            return Container(
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
                    Column(
                      children: [
                        if (_status == _ConnexionStatus.waitForUser)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 20.0, right: 20.0, bottom: 15),
                            child: _buildButtons(),
                          ),
                        if (_status == _ConnexionStatus.waitForTwitchValidation)
                          _buildBrowseTo(),
                        if (_status == _ConnexionStatus.connected)
                          _buildWaitingMessage(
                              'Please wait while we are logging you'),
                      ],
                    ),
                  ],
                ));
          }),
    ));
  }
}
