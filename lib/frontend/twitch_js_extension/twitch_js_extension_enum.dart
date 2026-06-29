enum TwitchAnchor {
  panel,
  overlay,
  component,
  unknown;

  String get name {
    switch (this) {
      case TwitchAnchor.panel:
        return 'panel';
      case TwitchAnchor.overlay:
        return 'video_overlay';
      case TwitchAnchor.component:
        return 'component';
      case TwitchAnchor.unknown:
        return 'unknown';
    }
  }
}

enum TwitchPlatform {
  web,
  mobile,
  unknown;

  String get name {
    switch (this) {
      case TwitchPlatform.web:
        return 'web';
      case TwitchPlatform.mobile:
        return 'mobile';
      case TwitchPlatform.unknown:
        return 'unknown';
    }
  }
}

enum TwitchMode {
  viewer,
  dashboard,
  config,
  unknown;

  String get name {
    switch (this) {
      case TwitchMode.viewer:
        return 'viewer';
      case TwitchMode.dashboard:
        return 'dashboard';
      case TwitchMode.config:
        return 'config';
      case TwitchMode.unknown:
        return 'unknown';
    }
  }
}
