# Conferbot Flutter SDK

[![pub package](https://img.shields.io/pub/v/conferbot_flutter.svg)](https://pub.dev/packages/conferbot_flutter)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.10-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.0-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/license-proprietary-lightgrey.svg)](https://conferbot.com/terms)

Native Flutter SDK for embedding Conferbot AI chatbots into iOS and Android applications.

---

## Features

- **Drop-in Chat Widget** -- Full-featured chat UI in a single widget
- **Headless SDK** -- Provider-based state management for fully custom UIs
- **Real-time Messaging** -- Socket.IO powered communication
- **Live Agent Handover** -- Seamless transition to human agents with queue status and pre-chat forms
- **Offline Support** -- Message queuing and automatic retry when connectivity returns
- **Voice Messages** -- Record, send, and play back voice messages
- **Rich Media** -- Image viewer, video player, audio player, and file attachments
- **Markdown Rendering** -- Full markdown support with syntax-highlighted code blocks
- **Knowledge Base** -- Searchable help center with categories and article detail views
- **Analytics** -- Session and event tracking with automatic batched uploads
- **Theming** -- Light and dark themes out of the box, fully customizable
- **51 Node Types** -- Complete node flow engine matching the Conferbot web widget
- **Session Persistence** -- Chat history survives app restarts via Hive storage
- **Message Pagination** -- Efficient loading of large conversation histories

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| Flutter  | 3.10           |
| Dart     | 3.0            |
| iOS      | 12.0           |
| Android  | API 21         |

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  conferbot_flutter: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Drop-in ChatWidget

The fastest way to get started. Wrap your app with `ConferBotProvider` and push the `ChatWidget`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ConferBotProvider(
        apiKey: 'YOUR_API_KEY',
        botId: 'YOUR_BOT_ID',
      ),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: context.read<ConferBotProvider>(),
                child: ChatWidget(
                  title: 'Support',
                  placeholder: 'Type your message...',
                  showTimestamps: true,
                ),
              ),
            ),
          );
        },
        child: Icon(Icons.chat),
      ),
    );
  }
}
```

### 2. Headless SDK (Custom UI)

Use `ConferBotProvider` directly to build your own chat interface:

```dart
final provider = context.watch<ConferBotProvider>();

// Read state
final messages = provider.record;
final isConnected = provider.isConnected;
final agent = provider.currentAgent;

// Send a message
await provider.sendMessage('Hello!');

// Request live agent handover
provider.initiateHandover(message: 'I need help with billing');

// Listen to events
provider.on(SocketEvents.botResponse, (data) {
  // Handle bot response
});
```

### 3. Mix and Match

Combine pre-built widgets with your own components:

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

Individual widgets available: `ChatHeader`, `MessageList`, `MessageBubble`, `ChatInput`, `TypingIndicator`, `ConnectionStatus`, `OfflineIndicator`, `Avatar`, and more.

## Configuration

### ConferBotConfig

Pass a `ConferBotConfig` to customize SDK behavior:

```dart
ConferBotProvider(
  apiKey: 'YOUR_API_KEY',
  botId: 'YOUR_BOT_ID',
  config: ConferBotConfig(
    enableNotifications: true,
    enableOfflineMode: true,
    enablePersistence: true,
    enablePagination: true,
    enableAnalytics: true,
    autoConnect: true,
    reconnectionAttempts: 5,
    reconnectionDelay: 1000,
    analyticsFlushInterval: Duration(seconds: 30),
  ),
)
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enableNotifications` | `bool` | `false` | Enable push notification support |
| `enableOfflineMode` | `bool` | `false` | Queue messages when offline |
| `enablePersistence` | `bool` | `false` | Persist chat history across app restarts |
| `enablePagination` | `bool` | `false` | Paginate large message histories |
| `enableAnalytics` | `bool` | `false` | Track session and event analytics |
| `autoConnect` | `bool` | `true` | Connect to socket automatically |
| `reconnectionAttempts` | `int?` | `5` | Max socket reconnection attempts |
| `reconnectionDelay` | `int?` | `1000` | Delay between reconnection attempts (ms) |

## Theming

### Built-in Themes

```dart
// Light theme (default)
ChatWidget(theme: defaultTheme);

// Dark theme
ChatWidget(theme: darkTheme);
```

### Custom Theme

```dart
final customTheme = ConferBotTheme(
  brightness: Brightness.light,
  colors: ConferBotColors(
    primary: Color(0xFF6366F1),
    userBubble: Color(0xFF6366F1),
    botBubble: Color(0xFFF3F4F6),
    background: Color(0xFFFFFFFF),
    text: Color(0xFF111827),
  ),
);

ChatWidget(theme: customTheme);
```

## Push Notifications

Register a device token (from Firebase, APNs, or any provider) to receive messages when the app is in the background:

```dart
final provider = context.read<ConferBotProvider>();
await provider.registerPushToken(deviceToken);
```

## Offline Support

When `enableOfflineMode` is set to `true`, the SDK automatically queues outgoing messages during network interruptions and delivers them when connectivity is restored. The `OfflineIndicator` widget provides visual feedback to users.

## Knowledge Base

Display a searchable help center within your app:

```dart
KnowledgeBaseScreen()
```

The knowledge base supports category filtering, full-text search, and article detail views.

## Voice Messages

Voice recording and playback are built in. The `VoiceInputWidget` handles microphone permissions, recording, and sending. The `VoicePlayer` widget renders playback controls for received voice messages.

```dart
VoiceInputWidget(onSend: (audioPath) {
  // Send voice message
})
```

## Analytics

When `enableAnalytics` is `true`, the SDK tracks session events and batches them for upload at configurable intervals. Access analytics data through the `AnalyticsProvider`.

## Socket Events

Subscribe to real-time events for fine-grained control:

```dart
final provider = context.read<ConferBotProvider>();

provider.on(SocketEvents.botResponse, (data) { /* ... */ });
provider.on(SocketEvents.agentAccepted, (data) { /* ... */ });
provider.on(SocketEvents.agentMessage, (data) { /* ... */ });
provider.on(SocketEvents.agentLeft, (data) { /* ... */ });
provider.on(SocketEvents.agentTypingStatus, (data) { /* ... */ });
provider.on(SocketEvents.chatEnded, (data) { /* ... */ });
```

## API Reference

Full API documentation is available in the [docs/](docs/) directory:

- [API Reference](docs/API.md) -- Provider methods, models, and services
- [Architecture](docs/ARCHITECTURE.md) -- SDK internals and design decisions
- [Components](docs/COMPONENTS.md) -- Widget catalog and usage
- [Examples](docs/EXAMPLES.md) -- Additional integration patterns
- [Changelog](docs/CHANGELOG.md) -- Version history

## Example App

A complete example application is included in the [example/](example/) directory demonstrating all three usage patterns:

```bash
cd example
flutter run
```

## Documentation

For full documentation, guides, and platform setup instructions, visit:

**[https://docs.conferbot.com/mobile/flutter](https://docs.conferbot.com/mobile/flutter)**

## Contributing

We welcome contributions. Please open an issue first to discuss proposed changes before submitting a pull request.

1. Fork the repository
2. Create a feature branch
3. Run `flutter test` and `flutter analyze` before submitting
4. Open a pull request against `main`

## License

This SDK is proprietary software. See [LICENSE](LICENSE) for details.

## Support

- GitHub Issues: [https://github.com/conferbot/flutter-sdk/issues](https://github.com/conferbot/flutter-sdk/issues)
- Email: support@conferbot.com
- Documentation: [https://docs.conferbot.com](https://docs.conferbot.com)
