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
/// This is the main window to call to connect to twitch. [appInfo] is all the
/// information to connect to  twitch;
/// [onFinishedConnexion] is the callback when connexion is done (typically, it
/// is to pop the window or push another one);
/// [reload] is directly passed to [TwitchManager.factory];
/// [saveKey] is directly passed to [TwitchManager.factory];
/// [mockOptions] is all the confirmation for TwitchMocker if it should be used;
class TwitchAuthenticationScreen extends StatefulWidget {
  const TwitchAuthenticationScreen({
    super.key,
    required this.appInfo,
    required this.onFinishedConnexion,
    this.reload = true,
    this.saveKey,
    this.mockOptions,
  });

  final TwitchMockOptions? mockOptions;

  static const route = '/twitch-authentication';
  final Function(TwitchManager) onFinishedConnexion;

  final TwitchAppInfo appInfo;
  final bool reload;
  final String? saveKey;

  @override
  State<TwitchAuthenticationScreen> createState() =>
      _TwitchAuthenticationScreenState();
}

class _TwitchAuthenticationScreenState
    extends State<TwitchAuthenticationScreen> {
  var _status = _ConnexionStatus.waitForUser;
  String? _redirectAddress;
  TwitchManager? _manager;
  late Future<TwitchManager> factoryManager =
      widget.mockOptions != null && widget.mockOptions!.isActive
          ? TwitchManagerMock.factory(
              appInfo: widget.appInfo, mockOptions: widget.mockOptions!)
          : TwitchManager.factory(
              appInfo: widget.appInfo,
              reload: widget.reload,
              saveKey: widget.saveKey);

  Future<void> _connectStreamer() async {
    if (_manager == null) return;

    await _manager!.connectStreamer(
        onRequestBrowsing: _onRequestBrowsing, saveKey: widget.saveKey);
    _checkForConnexionDone();
  }

  Future<void> _connectChatbot() async {
    if (_manager == null) return;

    await _manager!.connectChatbot(
        onRequestBrowsing: _onRequestBrowsing, saveKey: widget.saveKey);
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
          textAlign: TextAlign.justify,
          style: const TextStyle(color: Colors.white, fontSize: 20),
        )),
        const Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      ],
    );
  }

  Widget _buildBrowseTo() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'You will be redirected to the Twitch logging page. '
            'If it does not happen automatically, please navigate to:',
            textAlign: TextAlign.justify,
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 24),
          SelectableText(
            _redirectAddress!,
            textAlign: TextAlign.justify,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline),
          ),
          const SizedBox(height: 36),
          ElevatedButton(
            onPressed: () async => await launchUrl(
              Uri.parse(_redirectAddress!),
              mode: LaunchMode.inAppWebView,
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Or click here',
                style: TextStyle(color: Colors.black, fontSize: 28),
              ),
            ),
          ),
        ],
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
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Connect streamer',
              style: TextStyle(color: Colors.black, fontSize: 28),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.appInfo.hasChatbot)
          ElevatedButton(
            onPressed: _manager == null || !_manager!.isStreamerConnected
                ? null
                : _connectChatbot,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Connect chatbot',
                style: TextStyle(color: Colors.black, fontSize: 28),
              ),
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

            return Transform.scale(
              scale: 1080 / MediaQuery.of(context).size.width,
              child: SingleChildScrollView(
                child: Container(
                    color: const Color.fromARGB(255, 119, 35, 215),
                    width: 1080,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 40.0, bottom: 8),
                          child: Text(
                            'TWITCH AUTHENTICATION',
                            style: TextStyle(fontSize: 40, color: Colors.white),
                          ),
                        ),
                        SizedBox(
                          width: 700,
                          child: Column(
                            children: [
                              const Text(
                                'Please connect to your streamer account on Twitch on '
                                'your default browser, then click on "Connect streamer". '
                                'Afterwards, connect to your chatbot account on Twitch, '
                                'then click on "Connect chatbot". If you don\'t have a '
                                'chatbot, you can use your streamer account.\n',
                                textAlign: TextAlign.justify,
                                style: TextStyle(
                                    fontSize: 28, color: Colors.white),
                              ),
                              if (_status == _ConnexionStatus.waitForUser)
                                _buildButtons(),
                              if (_status ==
                                  _ConnexionStatus.waitForTwitchValidation)
                                _buildBrowseTo(),
                              if (_status == _ConnexionStatus.connected)
                                _buildWaitingMessage(
                                    'Please wait while we are logging you'),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ],
                    )),
              ),
            );
          }),
    ));
  }
}
