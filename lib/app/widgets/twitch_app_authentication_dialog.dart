import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twitch_manager/app/twitch_app_info.dart';
import 'package:twitch_manager/app/twitch_app_manager.dart';
import 'package:twitch_manager/app/twitch_mock_options.dart';
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
/// [onConnexionEstablished] is the callback when connexion is done (typically, it
/// is to pop the window or push another one);
/// [reload] is directly passed to [TwitchManager.factory];
/// [saveKey] is directly passed to [TwitchManager.factory];
/// [isMockActive] determines if the mock is active or not;
/// [debugPanelOptions] is used to prefill the debug panel if it is activated;
class TwitchAppAuthenticationDialog extends StatefulWidget {
  const TwitchAppAuthenticationDialog({
    super.key,
    required this.appInfo,
    required this.onConnexionEstablished,
    this.reload = true,
    this.saveKey,
    this.isMockActive = false,
    this.debugPanelOptions,
  });

  final TwitchDebugPanelOptions? debugPanelOptions;
  final bool isMockActive;

  static const route = '/twitch-authentication';
  final Function(TwitchAppManager) onConnexionEstablished;

  final TwitchAppInfo appInfo;
  final bool reload;
  final String? saveKey;

  @override
  State<TwitchAppAuthenticationDialog> createState() =>
      _TwitchAppAuthenticationDialogState();
}

class _TwitchAppAuthenticationDialogState
    extends State<TwitchAppAuthenticationDialog> {
  var _status = _ConnexionStatus.waitForUser;
  String? _redirectAddress;
  TwitchAppManager? _manager;
  late Future<TwitchAppManager> factoryManager = widget.isMockActive
      ? TwitchManagerMock.factory(
          appInfo: widget.appInfo, debugPanelOptions: widget.debugPanelOptions)
      : TwitchAppManager.factory(
          appInfo: widget.appInfo,
          reload: widget.reload,
          saveKeySuffix: widget.saveKey);

  Future<void> _connectStreamer() async {
    if (_manager == null) return;

    await _manager!.connect(onRequestBrowsing: _onRequestBrowsing);
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
      widget.onConnexionEstablished(_manager!);
    });
  }

  Future<void> _onRequestBrowsing(String address) async {
    _redirectAddress = address;
    _status = _ConnexionStatus.waitForTwitchValidation;
    setState(() {});

    await launchUrl(Uri.parse(_redirectAddress!),
        mode: LaunchMode.inAppWebView);
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: _redirectAddress!));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Copied to your clipboard !')));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Copy to clipboard',
                    style: TextStyle(color: Colors.black, fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () async => await launchUrl(
                  Uri.parse(_redirectAddress!),
                  mode: LaunchMode.inAppWebView,
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Open in browser',
                    style: TextStyle(color: Colors.black, fontSize: 28),
                  ),
                ),
              ),
            ],
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
