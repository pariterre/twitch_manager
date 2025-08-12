import 'package:flutter/material.dart';

enum AvailableLocales { en, fr }

class LocalizedTexts {
  // Create a singleton
  LocalizedTexts._();
  static final LocalizedTexts _instance = LocalizedTexts._();
  static LocalizedTexts get instance => _instance;

  void findLocale(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'fr') {
      _currentLocale = AvailableLocales.fr;
    } else {
      _currentLocale = AvailableLocales.en;
    }
  }

  AvailableLocales _currentLocale = AvailableLocales.en;

  String get mainText {
    switch (_currentLocale) {
      case AvailableLocales.en:
        return 'Please connect to your streamer account on Twitch on '
            'your default browser, then click on "Connect streamer". '
            'Afterwards, connect to your chatbot account on Twitch, '
            'then click on "Connect chatbot". If you don\'t have a '
            'chatbot, you can use your streamer account.\n';
      case AvailableLocales.fr:
        return 'Pour utiliser les fonctionnalités de Twitch, vous devez vous '
            'authentifier avec votre compte Twitch, puis cliquer sur "Connecter le streamer". '
            'Ensuite, connectez-vous à votre compte de chatbot sur Twitch, '
            'puis cliquez sur "Connecter le chatbot". Si vous n\'avez pas de '
            'chatbot, vous pouvez utiliser votre compte de streamer.\n';
    }
  }

  String get connectStreamer {
    switch (_currentLocale) {
      case AvailableLocales.en:
        return 'Connect streamer';
      case AvailableLocales.fr:
        return 'Connecter le streamer';
    }
  }

  String get connectChatbot {
    switch (_currentLocale) {
      case AvailableLocales.en:
        return 'Connect chatbot';
      case AvailableLocales.fr:
        return 'Connecter le chatbot';
    }
  }

  String get redirectText {
    switch (_currentLocale) {
      case AvailableLocales.en:
        return 'You will be redirected to the Twitch logging page. '
            'If it does not happen automatically, please navigate to:';
      case AvailableLocales.fr:
        return 'Vous allez être redirigé vers la page de connexion de Twitch. '
            'Si cela ne se fait pas automatiquement, veuillez vous rendre à l\'adresse suivante :';
    }
  }

  String get copyToClipboard {
    switch (_currentLocale) {
      case AvailableLocales.en:
        return 'Copy to clipboard';
      case AvailableLocales.fr:
        return 'Copier dans le presse-papier';
    }
  }

  String get openInBrowser {
    switch (_currentLocale) {
      case AvailableLocales.en:
        return 'Open in browser';
      case AvailableLocales.fr:
        return 'Ouvrir dans le navigateur';
    }
  }

  String get copiedToClipboard {
    switch (_currentLocale) {
      case AvailableLocales.en:
        return 'Copied to your clipboard!';
      case AvailableLocales.fr:
        return 'Copié dans votre presse-papier !';
    }
  }

  String get waitingForRedirect {
    switch (_currentLocale) {
      case AvailableLocales.en:
        return 'Connexion established, redirecting...';
      case AvailableLocales.fr:
        return 'Connexion établie, redirection...';
    }
  }
}
