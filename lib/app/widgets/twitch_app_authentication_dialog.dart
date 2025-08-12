import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:twitch_manager/app/twitch_app_info.dart';
import 'package:twitch_manager/app/twitch_app_manager.dart';
import 'package:twitch_manager/app/twitch_mock_options.dart';
import 'package:twitch_manager/app/widgets/localized_texts.dart';
import 'package:url_launcher/url_launcher.dart';

///
/// A helper to follow the current status of connexion
enum _ConnexionStatus {
  waitForUser,
  waitForTwitchValidation,
  connected,
}

const _twitchColor = Color.fromARGB(255, 119, 35, 215);

Future<TwitchAppManager?> showTwitchAppAuthenticationDialog(
  BuildContext context, {
  required TwitchAppInfo appInfo,
  required Function(TwitchAppManager) onConnexionEstablished,
  required Function() onCancelConnexion,
  bool reload = true,
  String? saveKey,
  bool useMocker = false,
  TwitchDebugPanelOptions? debugPanelOptions,
}) async {
  return await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.height * 0.8,
              child: TwitchAppAuthenticationDialog(
                saveKey: saveKey,
                useMocker: useMocker,
                debugPanelOptions: debugPanelOptions,
                onConnexionEstablished: (manager) {
                  if (context.mounted) Navigator.of(context).pop(manager);
                },
                onCancelConnexion: () => Navigator.of(context).pop(),
                appInfo: appInfo,
                reload: reload,
              ),
            ),
          ));
}

///
/// This is the main window to call to connect to twitch. [appInfo] is all the
/// information to connect to  twitch;
/// [onConnexionEstablished] is the callback when connexion is done (typically, it
/// is to pop the window or push another one);
/// [reload] is directly passed to [TwitchManager.factory];
/// [saveKey] is directly passed to [TwitchManager.factory];
/// [useMocker] determines if the mock is active or not;
/// [debugPanelOptions] is used to prefill the debug panel if it is activated;
class TwitchAppAuthenticationDialog extends StatefulWidget {
  const TwitchAppAuthenticationDialog({
    super.key,
    required this.appInfo,
    required this.onConnexionEstablished,
    required this.onCancelConnexion,
    this.reload = true,
    this.saveKey,
    this.useMocker = false,
    this.debugPanelOptions,
  });

  final TwitchDebugPanelOptions? debugPanelOptions;
  final bool useMocker;

  static const route = '/twitch-authentication';
  final Function(TwitchAppManager) onConnexionEstablished;
  final Function() onCancelConnexion;

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
  late Future<TwitchAppManager> factoryManager = widget.useMocker
      ? TwitchManagerMock.factory(
          appInfo: widget.appInfo, debugPanelOptions: widget.debugPanelOptions)
      : TwitchAppManager.factory(
          appInfo: widget.appInfo,
          reload: widget.reload,
          saveKeySuffix: widget.saveKey);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    LocalizedTexts.instance.findLocale(context);
  }

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
      if (mounted) setState(() {});
    }

    // If we get here, we are done authenticating
    Future.delayed(const Duration(milliseconds: 50)).then((_) {
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
          style: const TextStyle(color: _twitchColor, fontSize: 20),
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
          Text(
            LocalizedTexts.instance.redirectText,
            textAlign: TextAlign.justify,
            style: const TextStyle(color: _twitchColor, fontSize: 20),
          ),
          const SizedBox(height: 24),
          SelectableText(
            _redirectAddress!,
            textAlign: TextAlign.justify,
            style: const TextStyle(
                color: _twitchColor,
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(LocalizedTexts.instance.copiedToClipboard)));
                },
                style: ElevatedButton.styleFrom(backgroundColor: _twitchColor),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    LocalizedTexts.instance.copyToClipboard,
                    style: const TextStyle(color: Colors.white, fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () async => await launchUrl(
                  Uri.parse(_redirectAddress!),
                  mode: LaunchMode.inAppWebView,
                ),
                style: ElevatedButton.styleFrom(backgroundColor: _twitchColor),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    LocalizedTexts.instance.openInBrowser,
                    style: const TextStyle(color: Colors.white, fontSize: 28),
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
          style: ElevatedButton.styleFrom(backgroundColor: _twitchColor),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              LocalizedTexts.instance.connectStreamer,
              style: const TextStyle(color: Colors.white, fontSize: 28),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.appInfo.hasChatbot)
          ElevatedButton(
            onPressed: _manager == null || !_manager!.isStreamerConnected
                ? null
                : _connectChatbot,
            style: ElevatedButton.styleFrom(backgroundColor: _twitchColor),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                LocalizedTexts.instance.connectChatbot,
                style: const TextStyle(color: Colors.white, fontSize: 28),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
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

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        color: Colors.white,
                        child: Container(
                            color: _twitchColor.withAlpha(10),
                            width: 1080,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 30),
                                    Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SvgPicture.asset(
                                            'assets/twitch_name.svg',
                                            height: 100,
                                            package: 'twitch_manager',
                                          ),
                                          const SizedBox(width: 20),
                                          SvgPicture.asset(
                                            'assets/twitch_logo.svg',
                                            height: 100,
                                            package: 'twitch_manager',
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 850,
                                      child: Column(
                                        children: [
                                          Text(
                                            LocalizedTexts.instance.mainText,
                                            textAlign: TextAlign.justify,
                                            style: const TextStyle(
                                                fontSize: 28,
                                                color: _twitchColor),
                                          ),
                                          if (_status ==
                                              _ConnexionStatus.waitForUser)
                                            _buildButtons(),
                                          if (_status ==
                                              _ConnexionStatus
                                                  .waitForTwitchValidation)
                                            _buildBrowseTo(),
                                          if (_status ==
                                              _ConnexionStatus.connected)
                                            _buildWaitingMessage(LocalizedTexts
                                                .instance.waitingForRedirect),
                                          const SizedBox(height: 30),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: IconButton(
                                    onPressed: () => widget.onCancelConnexion(),
                                    icon: const Icon(
                                      Icons.close,
                                      color: _twitchColor,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ],
                            )),
                      ),
                    ),
                  ),
                );
              }),
        ));
  }
}
