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
