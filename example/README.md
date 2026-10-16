# Conferbot Flutter SDK - Example App

A small app that shows three ways to add the chat, using the SDK from this repository (`conferbot_flutter: path: ../`):

- **Option 1 (Drop-in Widget)**: the whole chat, `ChatWidget`, pushed as a full-screen route.
- **Option 2 (Headless SDK)**: your own UI on `ConferBotProvider`.
- **Option 3 (Mix & Match)**: the SDK's widgets (`ChatHeader`, `MessageList`, ...) in your own layout.

The home page also shows the session persistence tools: storage stats and clearing the session. Conversations resume after an app restart within the session timeout (30 minutes).

## Prerequisites

- Flutter 3.10 or later (`flutter doctor` clean for the platform you run).
- Android: an emulator or a phone, Android 7.0 (API 24) or later.
- iOS: Xcode with CocoaPods, a simulator or a phone on iOS 13 or later.

## Run it against Conferbot's cloud

This is the default: the provider talks to `https://wdt.conferbot.com`, and `lib/main.dart` ships with the public demo bot, so it runs without an account.

```bash
cd example
./setup.sh          # once: flutter create for any missing platform files, then flutter pub get
flutter run         # pick a device with -d <id>; `flutter devices` lists them
```

On iOS the first `flutter run` runs `pod install` for you. If it doesn't, run `cd ios && pod install && cd ..`.

To use your own bot, open `lib/main.dart` and change the provider:

```dart
ConferBotProvider(
  apiKey: 'test_key',     // any value: the mobile API does not check it
  botId: 'YOUR_BOT_ID',   // dashboard: your bot > Share > Mobile apps > Flutter
  ...
)
```

The bot must be **published** in the dashboard, or it serves no flow.

## Run it against a local server

Use this to try SDK changes against a local embed-server (it listens on port 8001).

1. Start the embed-server and make sure the bot you want exists in its database (a bot from a production database id won't be there).
2. Point the SDK at it. In `lib/main.dart`, in `main()`, before `runApp`:

   ```dart
   ConferBotEndpoints.configure(
     apiBaseUrl: 'http://10.0.2.2:8001/api/v1/mobile',
     socketUrl: 'http://10.0.2.2:8001',
   );
   ```

   The host depends on where the app runs:

   | Device | Host |
   |---|---|
   | Android emulator | `10.0.2.2` (the emulator's name for your computer) |
   | iOS simulator | `localhost` |
   | A real phone | your computer's LAN address (e.g. `192.168.1.20`), on the same Wi-Fi |

3. Allow plain HTTP:
   - **Android**: the example already has `android:usesCleartextTraffic="true"` in `android/app/src/main/AndroidManifest.xml`.
   - **iOS**: add an App Transport Security exception to `ios/Runner/Info.plist` (development only):

     ```xml
     <key>NSAppTransportSecurity</key>
     <dict>
       <key>NSAllowsArbitraryLoads</key>
       <true/>
     </dict>
     ```

4. `flutter run`. Remove the `ConferBotEndpoints.configure(...)` call (and the iOS exception) to go back to the cloud; `ConferBotEndpoints.reset()` does the same at run time.

## Troubleshooting

- **The chat stays empty**: the bot is not published, the bot id is wrong, or (locally) the bot is not in the local database. Try the demo bot `691c970890527a0468f9b2c9` against the cloud first.
- **Nothing connects locally**: on the Android emulator it is `10.0.2.2`, not `localhost`; on iOS check the ATS exception; on a phone check the LAN address and that the server listens on all interfaces.
- **Android build fails on `minSdk`**: the SDK's media plugins need API 24 or later. Raise `minSdk` in `android/app/build.gradle`.
- **iOS build fails on the deployment target**: set iOS 13 in `ios/Podfile` (`platform :ios, '13.0'`) and in Xcode, then `cd ios && pod install`.
- **Stale build**: `flutter clean && flutter pub get`, then run again.

More in the SDK's [README](../README.md#troubleshooting).
