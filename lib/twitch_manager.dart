import 'package:twitch_manager/twitch_app_info.dart';

import 'twitch_api.dart';
import 'twitch_irc.dart';
import 'twitch_user.dart';

export 'twitch_api.dart';
export 'twitch_authentication_screen.dart';
export 'twitch_irc.dart';
export 'twitch_manager.dart';
export 'twitch_scope.dart';
export 'twitch_user.dart';

class TwitchManager {
  late final TwitchIrc? irc;
  late final TwitchApi api;

  static final Finalizer<TwitchIrc> _finalizerIrc =
      Finalizer((irc) => irc.disconnect());

  ///
  /// Main constructor
  /// [onAuthenticationRequest] is called if the Authentication needs to create a
  /// new OAUTH key. Adress is the address to browse.
  /// [onSuccess] This callback is called after the success of authentication
  /// [onInvalidToken] is called if the Token is found invalid.
  ///
  static Future<TwitchManager> factory({
    required TwitchUser user,
    required TwitchAppInfo appInfo,
    required Future<void> Function(String address) onAuthenticationRequest,
    Future<void> Function()? onInvalidToken,
  }) async {
    final success = await user.connect(
      requestUserToBrowse: onAuthenticationRequest,
      onInvalidToken: onInvalidToken,
    );
    if (!success) throw 'Failed to connect';

    final api = await TwitchApi.factory(user, appInfo);
    final irc = await TwitchIrc.factory(streamer: user);
    _finalizerIrc.attach(irc, irc, detach: irc);

    return TwitchManager._(irc, api);
  }

  ///
  /// Private constructor
  ///
  TwitchManager._(this.irc, this.api);
}
