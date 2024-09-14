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