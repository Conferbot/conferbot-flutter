# Conferbot Flutter SDK

Official Flutter SDK for integrating Conferbot chatbot into your iOS and Android mobile applications.

## Features

- 🚀 **Easy Integration** - Drop-in chat widget with Provider state management
- 💬 **Real-time Messaging** - Socket.IO based real-time communication
- 📱 **Cross-Platform** - Works on both iOS and Android
- 🎨 **Customizable** - Fully customizable UI widgets and theming
- 🤖 **AI-Powered** - Connect to Conferbot's AI chatbot engine
- 👤 **Live Agent Handover** - Seamless handover to human agents
- 💾 **Offline Support** - Queue messages when offline
- 🎯 **Type Safe** - Full Dart type safety with null safety

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  conferbot_flutter: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Wrap your app with ConferBotProvider

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ConferBotProvider(
        apiKey: 'conf_sk_your_api_key_here',
        botId: 'your_bot_id_here',
        config: ConferBotConfig(
          enableNotifications: true,
          enableOfflineMode: true,
        ),
      ),
      child: MyApp(),
    ),
  );
}
```

### 2. Use the ChatWidget

```dart
// Open chat widget
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<ConferBotProvider>(),
      child: ChatWidget(
        title: 'Support Chat',
        placeholder: 'Type your message...',
        showTimestamps: true,
      ),
    ),
  ),
);
```

## Example App

Want to see it in action? Check out the **example app** in the `/example` directory.

```bash
cd example
flutter run
```

The example demonstrates:
- ✅ Drop-in widget (easiest integration)
- ✅ Headless SDK (custom UI)
- ✅ Mix & match (pre-built + custom components)

## Three Usage Patterns

### 1. Drop-in Widget (Easiest)

```dart
ChatWidget(
  title: 'Support Chat',
  showTimestamps: true,
)
```

Full-featured chat in one widget!

### 2. Headless SDK (Custom UI)

```dart
final provider = context.watch<ConferBotProvider>();

// Access state
final messages = provider.record;
final isConnected = provider.isConnected;

// Send messages
provider.sendMessage('Hello!');
```

Build your own UI from scratch.

### 3. Mix & Match

```dart
Column(
  children: [
    ChatHeader(
      agent: provider.currentAgent,
      onClose: () => Navigator.pop(context),
    ),
    Expanded(
      child: MessageList(messages: provider.record),
    ),
    ChatInput(onSend: provider.sendMessage),
  ],
)
```

Use our widgets where you want, custom where you need.

## Theming

### Use Default Themes

```dart
import 'package:conferbot_flutter/conferbot_flutter.dart';

// Use default light theme
ChatWidget(theme: defaultTheme);

// Use dark theme
ChatWidget(theme: darkTheme);
```

### Custom Theme

```dart
final myTheme = ConferBotTheme(
  brightness: Brightness.light,
  colors: ConferBotColors(
    primary: Color(0xFFFF6B6B),
    userBubble: Color(0xFFFF6B6B),
    // ... other colors
  ),
  // ... other settings
);

ChatWidget(theme: myTheme);
```

## API Reference

### ConferBotProvider

#### State Properties

- `isInitialized: bool` - SDK initialization status
- `isConnected: bool` - Socket connection status
- `isOpen: bool` - Chat widget open/closed state
- `chatSessionId: String?` - Current chat session ID
- `record: List<RecordItem>` - Array of chat messages
- `currentAgent: Agent?` - Current live agent (if in handover)
- `unreadCount: int` - Number of unread messages

#### Methods

##### `openChat(): Future<void>`
Opens the chat and initializes a new session if needed.

##### `closeChat(): void`
Closes the chat interface.

##### `sendMessage(String text): Future<void>`
Sends a message to the chatbot or live agent.

##### `registerPushToken(String token): Future<void>`
Registers a push notification token.

##### `initiateHandover({String? message}): void`
Requests handover to a live agent.

##### `on(String event, Function(dynamic) callback): void`
Subscribe to socket events.

## Socket Events

```dart
import 'package:conferbot_flutter/conferbot_flutter.dart';

final provider = context.read<ConferBotProvider>();

provider.on(SocketEvents.botResponse, (data) {
  print('Bot response: $data');
});

provider.on(SocketEvents.agentAccepted, (data) {
  print('Agent joined: ${data['agent']['name']}');
});
```

### Available Events

- `SocketEvents.botResponse` - Bot sent a message
- `SocketEvents.agentMessage` - Live agent sent a message
- `SocketEvents.agentAccepted` - Live agent accepted handover
- `SocketEvents.agentLeft` - Live agent left the chat
- `SocketEvents.agentTypingStatus` - Agent typing status changed
- `SocketEvents.chatEnded` - Chat session ended

## Requirements

- Flutter >= 3.10.0
- Dart >= 3.0.0
- iOS >= 12.0
- Android API Level >= 21

## Documentation

- **API Reference**: See inline documentation
- **Examples**: `/example` directory
- **Architecture**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## Publishing to pub.dev

```bash
# 1. Ensure all tests pass
flutter test

# 2. Analyze code
flutter analyze

# 3. Format code
dart format .

# 4. Publish (dry run first)
flutter pub publish --dry-run

# 5. Publish
flutter pub publish
```

## Support

- **GitHub Issues**: https://github.com/conferbot/flutter-sdk/issues
- **Email**: support@conferbot.com
- **Docs**: https://docs.conferbot.com
