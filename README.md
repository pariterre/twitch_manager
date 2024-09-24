# twitch_manager
This is a manager to the Twitch API

# Install

## Macos
In order to communication with Twitch API, mac uses must give permissions to network. Navigate to `<BASE_FOLDER>/macos/Runner/ReleaseProfile.entitlements` and add the two following lines:
```
<key>com.apple.security.network.server</key><true/>
<key>com.apple.security.network.client</key><true/>
```
Note: If you plan to debug your application, you should add these permission to `Runner/DebugProfile.entitlements` also.

# Run

## Web
As the API communicates with Twitch, then to run one must turn on *Cross-Origin Resource Sharing (CORS)* on the server they run the code on. 
During debug, this can be a pain though. Therefore, one can rely on disabling security from the web browser. To do so, they can run flutter as such
```bash
flutter run -d edge --web-browser-flag "--disable-web-security"
```

# Nomeclature

## EBS
EBS stands for *Extension Backend Service*. This is the service that runs on a server you own and communicates with the Twitch API. It is responsible to hold a persistent communication with the App (if there is any). It is also responsible to respond to the Frontend requests, by relaying the information to the App or to the Twitch API (using the shared secret). It communicates with the Frontend by either responding the an http request or by broadcasting using PubSub.

## Frontend
The frontend is the Flutter application that runs on the spectator screen, i.e. the main screen that the user interacts with. It is responsible to communicate with the EBS and to display the data to the user. By nature, it is a web app. 

## App
The app is the Flutter application that runs on stream computer. It can be targetting any platform. It communicates information to the Frontend via the EBS. It is responsible to display the extension that will be shown on the stream.

## Configuration
The configuration is a Flutter application that runs on the broadcaster screen when configuring the extension It communicates with the EBS to store the configuration.


# Project preparation
## Configuration

The only way to properly compile the configuration part of the extension is to use the `web` platform.

Once the flutter project is created, there is two steps to be able to properly compile the configuration part of the extension:
1. Add the following line to `web/index.html`: `<script src="https://extension-files.twitch.tv/helper/v1/twitch-ext.min.js"></script>`, to either the `<head>` or the `<body>` of the file.
2. Remove the line `<base href="$FLUTTER_BASE_HREF">` in the `<head>` of the file. The reason is that JS query won't be made from the 'self' path which will be blocked by Twitch CPS (see the Note below).

NOTE: Any JS must be in the asset folder as Twitch does not allow external JS files.

Related to this note, I was not able to compile using the canvaskit renderer so far as, it is blocked by Twitch CPS. Therefore, the only way to compile the configuration part of the extension is to use the `html` renderer. To do so, when compiling, run the following command:
```bash
flutter build web --web-renderer=html
```

Once the folder is compiled, in order to send it to Twitch, it must be zip. I suggest to rename the `build/web` folder to `config`. Then, in the Twitch `Element Hosting`, you can refer to the `config` folder using the `config/index.html` path. Note, this zip file can be joined with the App folders.

## App

The only way to properly compile the configuration part of the extension is to use the `web` platform.

Once the flutter project is created, there is two steps to be able to properly compile the configuration part of the extension:
1. Add the following line to `web/index.html`: `<script src="https://extension-files.twitch.tv/helper/v1/twitch-ext.min.js"></script>`, to either the `<head>` or the `<body>` of the file.
2. Remove the line `<base href="$FLUTTER_BASE_HREF">` in the `<head>` of the file. The reason is that JS query won't be made from the 'self' path which will be blocked by Twitch CPS (see the Note below).

NOTE: Any JS must be in the asset folder as Twitch does not allow external JS files.

Related to this note, I was not able to compile using the canvaskit renderer so far as, it is blocked by Twitch CPS. Therefore, the only way to compile the configuration part of the extension is to use the `html` renderer. To do so, when compiling, run the following command:
```bash
flutter build web --web-renderer=html
```

Once the folder is compiled, in order to send it to Twitch, it must be zip. I suggest to rename the `build/web` folder to either `video_component`, `panel`, `video_overlay` or `mobile`. Then, in the Twitch `Element Hosting`, you can refer to the respective folder using the `XXXX/index.html` path. Note, this zip file can be joined with all the App zip folders and the config folder.

Moreover, in the `Capability` section of the Twitch Developer Dashboard, you must add your EBS domain to the `“Allowlist for URL Fetching Domains”`, such as: `https://YOUR_DOMAIN/frontend` and `https://YOUR_DOMAIN/app`.