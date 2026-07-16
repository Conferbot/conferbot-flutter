# Conferbot Flutter SDK - Usage Guide

A step-by-step walkthrough from zero to a fully themed, identified, event-aware chat integration. For the condensed version see the [README](../README.md); for signatures see [API.md](API.md).

What you will build:

<p align="center">
  <img src="screenshots/chat-widget.png" width="260" alt="Chat Widget" />
  <img src="screenshots/choice-node.png" width="260" alt="Choice Node" />
  <img src="screenshots/themed-chat.png" width="260" alt="Themed Chat" />
</p>

## Contents

1. [Step 1 - Get a bot](#step-1---get-a-bot)
2. [Step 2 - Add the dependency](#step-2---add-the-dependency)
3. [Step 3 - Initialize the SDK](#step-3---initialize-the-sdk)
4. [Step 4 - Wire the floating bubble (FAB)](#step-4---wire-the-floating-bubble-fab)
5. [Step 5 - Identify your user](#step-5---identify-your-user)
6. [Step 6 - Theming](#step-6---theming)
7. [Step 7 - Listening to events](#step-7---listening-to-events)
8. [Step 8 - Advanced topics](#step-8---advanced-topics)
9. [Running the example app](#running-the-example-app)
10. [Troubleshooting](#troubleshooting)

---

## Step 1 - Get a bot

Two options:

**Option A - use the public demo bot (no account needed).** Bot ID `691c970890527a0468f9b2c9` is live in production and accepts any API key string (the example app uses `'test_key'`). Perfect for evaluating the SDK before signing up.

**Option B - create your own bot:**

1. Sign in at [app.conferbot.com](https://app.conferbot.com).
2. Create a bot and design its conversation in the flow builder (welcome message, questions, choices, handover, ...).
3. **Publish** the bot. This matters: an unpublished bot serves no flow, and the mobile widget will connect but show nothing.
4. Copy the bot ID from the bot settings (a 24-character hex string, the same one used in the web embed snippet).

Optionally style the bot under the widget appearance settings (colors, avatar, bot name, bubble icon, CTA text). Everything you set there is applied automatically by the Flutter SDK - see [Step 6](#step-6---theming).

## Step 2 - Add the dependency

`pubspec.yaml`:

```yaml
dependencies:
  conferbot_flutter: ^1.0.0
```

```bash
flutter pub get
```

Requirements: Flutter `>=3.10.0`, Dart `>=3.0.0 <4.0.0`. The SDK pulls in provider, socket_io_client, Hive, connectivity_plus, and media/voice packages; no manual platform setup is needed for the basic chat. (Voice recording uses `permission_handler` - if you enable voice input, declare the microphone permission in your Android manifest and iOS Info.plist as that plugin documents.)

## Step 3 - Initialize the SDK

Two things happen at startup:

1. `StorageService.init()` opens the Hive boxes used for session persistence (chat survives app restarts, 30-minute session timeout like the web widget).
2. A single `ConferBotProvider` is created and shared through the widget tree with `provider`.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init(); // required for persistence (on by default)

  runApp(
    ChangeNotifierProvider(
      create: (_) => ConferBotProvider(
        apiKey: 'test_key',
        botId: '691c970890527a0468f9b2c9', // demo bot - swap for yours
        config: const ConferBotConfig(
          enablePersistence: true,
          sessionTimeout: Duration(minutes: 30),
        ),
      ),
      child: const MyApp(),
    ),
  );
}
```

The provider connects to `https://wdt.conferbot.com` over Socket.IO as soon as it is created (`autoConnect: true`), fetches the bot's flow and customizations, and restores any previous session. Creating it once at the app root is the recommended pattern - it keeps one socket and one session for the whole app.

At this point you can already open a full chat screen anywhere:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<ConferBotProvider>(),
      child: const ChatWidget(title: 'Support Chat'),
    ),
  ),
);
```

Note the `ChangeNotifierProvider.value` wrapper: a pushed route is a new subtree, so the provider must be re-exposed to it.

## Step 4 - Wire the floating bubble (FAB)

To match the web widget experience - a chat bubble floating bottom-right that opens the chat - wrap your app content in `ConferBotFAB`:

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => ConferBotProvider(
          apiKey: 'test_key',
          botId: '691c970890527a0468f9b2c9',
        ),
        child: ConferBotFAB(
          // Optional local fallbacks; dashboard settings always win
          config: const ConferBotFABConfig(
            size: 50.0,
            position: FabPosition.right,
            offsetX: 10.0,
            offsetBottom: 10.0,
          ),
          child: Scaffold(
            appBar: AppBar(title: const Text('My Store')),
            body: const ProductList(),
          ),
        ),
      ),
    );
  }
}
```

Or skip the manual provider entirely with `ConferBotFABScope`:

```dart
ConferBotFABScope(
  apiKey: 'test_key',
  botId: '691c970890527a0468f9b2c9',
  user: const ConferBotUser(id: 'user-42'),
  child: MaterialApp(home: HomePage()),
)
```

Behavior you get for free:

- Tap opens the chat in a draggable modal bottom sheet (92% height); the bubble icon animates to an X while open.
- An unread badge appears on the bubble when bot/agent messages arrive while the chat is closed.
- If the dashboard sets a CTA text (`chatIconCtaText`), an animated tooltip slides in next to the bubble after 2 seconds; the user can dismiss it.
- The bubble's color, size, position (left/right), offsets, corner radius, and icon (the same 15-icon set as the web widget) all follow the dashboard's widget settings, overriding your `ConferBotFABConfig` fallbacks.

Placement tip: `ConferBotFAB` positions itself with a `Stack`, so wrap the widget that fills the screen (typically the `Scaffold` or your `MaterialApp`'s home). Everything in `child` renders beneath the bubble.

## Step 5 - Identify your user

Pass a `ConferBotUser` when creating the provider so conversations are attributed to your logged-in user instead of an anonymous visitor:

```dart
ConferBotProvider(
  apiKey: 'YOUR_API_KEY',
  botId: 'YOUR_BOT_ID',
  user: const ConferBotUser(
    id: 'user-42',              // required - your stable user ID
    name: 'Jane Doe',
    email: 'jane@example.com',
    phone: '+15551234567',
    metadata: {'plan': 'pro', 'signupDate': '2026-01-15'},
  ),
)
```

What actually happens: on session start the SDK calls `POST /session/init` with `userId` set to `user.id` (or the generated visitor ID if no user was given). That is the identity link. **Honest limitation:** in this SDK version `name`, `email`, `phone`, and `metadata` are accepted by the model but not yet sent to the server - if you need those attributes on the dashboard, capture them in the conversation itself (ask-question nodes or the handover pre-chat form).

Anonymous users get a persistent visitor ID stored in Hive, so returning visitors keep their history even without login.

Because `user` is a constructor parameter, switch identities (login/logout) by recreating the provider, typically by keying the `ChangeNotifierProvider` on your auth state. Call `clearCurrentSession()` first if you want the old conversation dropped.

## Step 6 - Theming

### The golden rule: server wins

When the widget connects, the server sends the flow builder's appearance settings and the SDK applies them automatically - header colors, bubble colors, chat background, font size, bubble radius, bot name, and avatar. The exact merge in `ChatWidget`:

```dart
final effectiveTheme = provider.serverCustomizations != null
    ? provider.serverTheme          // server settings present: they win
    : (widget.theme ?? defaultTheme); // otherwise your theme, then default
```

`provider.serverTheme` is built by overlaying the dashboard values on `defaultTheme`; any color the dashboard leaves empty falls back to the web widget defaults (`#1B55F3` bubbles with white text). So:

- Dashboard-styled bot: your local `theme:` is ignored for the chat UI. Style the bot in the dashboard.
- Unstyled bot / no server data yet: your local `theme:` applies.

Dashboard keys the SDK understands: `headerBgColor`, `headerTextColor`, `botMsgColor`, `botTextColor`, `userMsgColor`, `userTextColor`, `optionBubbleMsgColor`, `optionBubbleTextColor`, `chatBgColor`, `fontSize`, `bubbleBorderRadius`, `botName`/`logoText`, `avatar`/`logo`, plus the FAB keys (`widgetIconBgColor`, `widgetSize`, `widgetPosition`, `widgetOffsetLeft/Right/Bottom`, `widgetBorderRadius`, `widgetIconSVG`, `chatIconCtaText`).

### Local themes

```dart
// Built-ins
ChatWidget(theme: defaultTheme);
ChatWidget(theme: darkTheme);

// Brand theme
final brand = defaultTheme.copyWith(
  colors: defaultTheme.colors.copyWith(
    primary: const Color(0xFF6366F1),
    headerBg: const Color(0xFF6366F1),
    headerText: Colors.white,
    userBubble: const Color(0xFF6366F1),
    userBubbleText: Colors.white,
    botBubble: const Color(0xFFF3F4F6),
    botBubbleText: const Color(0xFF111827),
  ),
  typography: const ConferBotTypography(messageSize: 16.0),
  borderRadius: const ConferBotBorderRadius(bubble: 20.0),
);

ConferBotFAB(theme: brand, child: ...); // forwarded to the ChatWidget it opens
```

`ConferBotTheme` bundles `ConferBotColors` (26 slots), `ConferBotTypography`, `ConferBotSpacing`, `ConferBotBorderRadius`, `ConferBotShadows`, `ConferBotAnimations`, and `ConferBotLayout`.

One caveat: the provider's `customization:` parameter (`ConferBotCustomization`) is currently stored but not applied to rendering. Use `ConferBotTheme` for local styling.

## Step 7 - Listening to events

`ConferBotProvider` is a `ChangeNotifier` - `context.watch<ConferBotProvider>()` rebuilds on any state change (new messages, connection, agent status, node changes). For discrete real-time events, subscribe to the socket layer:

```dart
final provider = context.read<ConferBotProvider>();

provider.on(SocketEvents.botResponse, (data) {
  debugPrint('Bot node arrived: $data');
});

provider.on(SocketEvents.agentAccepted, (data) {
  // A human agent joined the conversation
});

provider.on(SocketEvents.agentMessage, (data) {
  // Live agent sent a message
});

provider.on(SocketEvents.agentTypingStatus, (data) {
  final typing = (data as Map<String, dynamic>)['isTyping'] as bool? ?? false;
});

provider.on(SocketEvents.chatEnded, (_) {
  // Conversation was ended by the agent/dashboard
});
```

Unsubscribe with `provider.off(event)` and emit raw events with `provider.emit(event, data)`. Useful constants on `SocketEvents`: `botResponse`, `agentMessage`, `agentAccepted`, `agentLeft`, `agentTypingStatus`, `chatEnded`, `noAgentsAvailable`, `queueStatusUpdate`, `fetchedChatbotData`, `connect`, `disconnect`.

Derived state is also exposed directly: `provider.currentAgent`, `provider.agentTyping`, `provider.isLiveChatMode`, `provider.unreadCount`, `provider.isFlowComplete`, `provider.errorMessage`.

## Step 8 - Advanced topics

### Headless / fully custom UI

Skip `ChatWidget` entirely and drive everything from the provider:

```dart
class MyChatScreen extends StatelessWidget {
  const MyChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: provider.record.length,
            itemBuilder: (context, i) {
              final m = provider.record[i];
              String? text;
              if (m is UserMessageRecord) text = m.text;
              if (m is BotMessageRecord) text = m.text;
              if (m is AgentMessageRecord) text = m.text;
              return Text(text ?? '');
            },
          ),
        ),
        // Render the current interactive node with the SDK's renderer,
        // or inspect provider.currentUIState and build your own controls.
        if (provider.currentUIState != null)
          NodeRenderer(
            uiState: provider.currentUIState,
            onResponse: provider.submitResponse,
            theme: provider.serverTheme,
            primaryColor: provider.serverTheme.colors.primary,
          ),
        TextField(onSubmitted: provider.sendMessage),
      ],
    );
  }
}
```

Remember to call `provider.openChat()` once (e.g. in `initState`) - `ChatWidget` does this for you, a custom UI must do it itself. Mid-level building blocks (`ChatHeader`, `MessageList`, `ChatInput`, `MessageBubble`, `TypingIndicator`, `OfflineIndicator`, ...) are all exported for mix-and-match layouts.

### Offline behavior

On by default. When connectivity drops (`ConnectivityService`), outgoing messages are queued by `MessageQueueService` and auto-retried on reconnect; `ChatWidget` shows the offline banner and switches the input placeholder to "Offline - messages will be queued". Delivery ticks on user messages are controlled by `ChatWidget(showDeliveryStatus:)`.

### Session persistence

Sessions (messages, flow position, variables) persist via Hive and resume within `sessionTimeout` (default 30 minutes). The visitor ID persists indefinitely. Hooks:

```dart
provider.sessionRestored;            // true if a previous session resumed
await provider.persistState();       // call on AppLifecycleState.paused
await provider.clearCurrentSession(); // drop session, keep visitor ID
await provider.clearAllPersistedData();
provider.getStorageStats();          // debug info
```

### Live agent handover

Triggered by a handover node in the flow, or programmatically:

```dart
provider.initiateHandover(message: 'Customer needs billing help');
```

`ChatWidget` handles the whole lifecycle: optional pre-chat form (`showHandoverPreChatForm`), queue status with max wait (`handoverMaxWaitMinutes`), agent header with typing indicator, and an optional post-chat survey (`showHandoverPostChatSurvey`, results via `onHandoverSurveySubmit`).

### Push notifications

The SDK registers a token you obtain from your own push stack (e.g. FCM):

```dart
final token = await FirebaseMessaging.instance.getToken(); // your code
if (token != null) {
  await provider.registerPushToken(token);
}
```

`registerPushToken(String token)` posts to `/push/register` with the current chat session ID; it silently no-ops until a session exists, so call it after the chat has been opened. Displaying incoming notifications is your app's responsibility - the SDK only registers the token.

### Knowledge base

Reachable from the chat header (help icon) out of the box, or embeddable standalone:

```dart
ChangeNotifierProvider(
  create: (_) => KnowledgeBaseProvider(
    apiKey: 'YOUR_API_KEY',
    botId: 'YOUR_BOT_ID',
  ),
  child: const KnowledgeBaseScreen(
    title: 'Help Center',
    searchPlaceholder: 'Search articles...',
    showCategories: true,
    showSearch: true,
  ),
)
```

Categories, debounced full-text search, article detail with ratings, and insert-into-chat (`ChatWidget.onArticleInsert`) are included. Lower level, `KnowledgeBaseService` exposes `fetchArticles(...)` and `searchArticles(...)` returning typed `KBApiResponse` results.

### Analytics

Enabled by default and flushed every 30 seconds (configurable via `ConferBotConfig.analyticsFlushInterval`). Sessions, messages, node interactions, and drop-offs are tracked automatically; add your own signals:

```dart
provider.trackInteraction(type: 'promo_banner_tap', data: {'campaign': 'q3'});
provider.trackGoalCompletion(goalId: 'demo_booked', conversionValue: 49.0);
provider.submitChatRating(csatScore: 5, feedback: 'Great bot!');
await provider.flushAnalytics(); // force upload
```

### Custom endpoints (self-hosted / staging)

```dart
ConferBotEndpoints.configure(
  apiBaseUrl: 'https://embed.example.com/api/v1/mobile',
  socketUrl: 'https://embed.example.com',
);
ConferBotNetworkConfig.configure(
  apiTimeout: const Duration(seconds: 15),
  reconnectionAttempts: 10,
  reconnectionDelay: const Duration(seconds: 1),
);
```

Call before creating the provider, or pass `baseUrl:` / `socketUrl:` per provider. Defaults: `https://wdt.conferbot.com/api/v1/mobile` and `https://wdt.conferbot.com`.

## Running the example app

```bash
git clone https://github.com/conferbot/flutter-sdk.git
cd flutter-sdk
flutter pub get

cd example
flutter pub get
flutter run          # on a connected device or emulator
```

The example runs against the public demo bot out of the box (`botId: '691c970890527a0468f9b2c9'`, `apiKey: 'test_key'`) and demonstrates three patterns from one home screen: the drop-in `ChatWidget`, a headless custom UI, and a mix-and-match layout using `ChatHeader` + `MessageList` + `ChatInput`. The overflow menu exposes persistence debugging (storage stats, clear session, clear all). To point it at your own bot, edit the `ConferBotProvider` constructor in `example/lib/main.dart`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Chat opens but stays empty | Bot not published, wrong `botId`, or `https://wdt.conferbot.com` unreachable from the device. Verify with the demo bot `691c970890527a0468f9b2c9`, which needs no account. |
| `HiveError` on startup | Call `await StorageService.init()` before `runApp`, or set `enablePersistence: false`. |
| `ProviderNotFoundException` | `ChatWidget` / `ConferBotFAB` must be under a `ChangeNotifierProvider<ConferBotProvider>`; re-provide with `.value` on pushed routes. |
| My theme colors do not apply | The bot has dashboard customizations - server settings override local themes by design. |
| Old conversation keeps resuming | That is session persistence (30 min window). Call `clearCurrentSession()` or `resetConversation()`. |
| Messages "stuck" with clock icon | Device is offline; the queue delivers them automatically on reconnect. |
