import 'twitch_api.dart';
import 'twitch_authentication.dart';
import 'twitch_irc.dart';

export 'twitch_api.dart';
export 'twitch_authentication.dart';
export 'twitch_irc.dart';
export 'twitch_manager.dart';
export 'twitch_scope.dart';
export 'twitch_authentication_screen.dart';

class TwitchManager {
  late final TwitchIrc? irc;
  late final TwitchApi api;

  static final Finalizer<TwitchIrc> _finalizerIrc =
      Finalizer((irc) => irc.disconnect());

  ///
  /// Main constructor
  /// [streamerName] is the name of the stream. [moderatorName] is the current
  /// logged id used with authenticator. If it is left empty, [streamerName]
  /// is used.
  /// [onAuthenticationRequest] is called if the Authentication needs to create a
  /// new OAUTH key. Adress is the address to browse.
  /// [onAuthenticationSuccess] This callback is called after the success of authentication
  /// [onInvalidToken] is called if the Token is found invalid.
  ///
  static Future<TwitchManager> factory({
    required TwitchAuthentication authentication,
    required Future<void> Function(String address) onAuthenticationRequest,
    required Future<void> Function(
            String oauth, String streamerUsername, String moderatorUsername)
        onSuccess,
    Future<void> Function()? onInvalidToken,
  }) async {
    final success = await authentication.connect(
      requestUserToBrowse: onAuthenticationRequest,
      onInvalidToken: onInvalidToken,
      onSuccess: onSuccess,
    );
    if (!success) throw 'Failed to connect';

    final api = await TwitchApi.factory(authentication);
    final irc = await TwitchIrc.factory(authentication);
    _finalizerIrc.attach(irc, irc, detach: irc);

    return TwitchManager._(irc, api);
  }

  ///
  /// Private constructor
  ///
  TwitchManager._(this.irc, this.api);
}
