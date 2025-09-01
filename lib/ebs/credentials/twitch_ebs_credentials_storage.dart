import 'dart:io';

import 'package:twitch_manager/ebs/credentials/twitch_ebs_credentials.dart';

abstract class TwitchEbsCredentialsStorage {
  TwitchEbsCredentialsStorage() {
    // Register a shutdown hook
    ProcessSignal.sigint.watch().listen((_) => dispose());
    ProcessSignal.sigterm.watch().listen((_) => dispose());
  }

  ///
  /// If the database is connected and ready to use.
  bool get isConnected;

  ///
  /// Dispose the resources used by the storage. It is automatically called
  /// when the application is terminated.
  Future<void> dispose();

  ///
  /// Save the Twitch credentials of a user.
  /// Returns true if the credentials were saved successfully, false otherwise.
  Future<bool> save({required TwitchEbsCredentials credentials});

  ///
  /// Load the Twitch credentials of a user.
  /// Returns null if no credentials are found.
  Future<TwitchEbsCredentials?> load({required String userId});
}
