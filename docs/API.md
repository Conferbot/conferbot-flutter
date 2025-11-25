# API Reference

Complete API documentation for the Conferbot Flutter SDK.

## Table of Contents

- [ConferBotProvider](#conferbotprovider)
- [Provider API](#provider-api)
- [Types](#types)
- [Socket Events](#socket-events)
- [Configuration](#configuration)

---

## ConferBotProvider

The root provider that wraps your application and provides Conferbot functionality using Flutter's `ChangeNotifier` pattern.

### Constructor Parameters

#### `apiKey` (required)
- **Type:** `String`
- **Description:** Your Conferbot API key
- **Example:** `"conf_sk_abc123..."`

#### `botId` (required)
- **Type:** `String`
- **Description:** Your chatbot ID
- **Example:** `"bot_123abc..."`

#### `config` (optional)
- **Type:** `ConferBotConfig`
- **Description:** SDK configuration options
- **Default:** `ConferBotConfig(autoConnect: true)`

```dart
class ConferBotConfig {
  final bool enableNotifications;      // Default: false
  final bool enableOfflineMode;        // Default: false
  final bool autoConnect;              // Default: true
  final int? reconnectionAttempts;     // Default: 5
  final int? reconnectionDelay;        // Default: 1000 (ms)
}
```

#### `customization` (optional)
- **Type:** `ConferBotCustomization`
- **Description:** UI customization options

```dart
class ConferBotCustomization {
  final String? primaryColor;
  final String? fontFamily;
  final double? bubbleRadius;
  final String? headerTitle;
  final bool? enableAvatar;
  final String? avatarUrl;
  final String? botBubbleColor;
  final String? userBubbleColor;
}
```

#### `user` (optional)
- **Type:** `ConferBotUser`
- **Description:** User identification and metadata

```dart
class ConferBotUser {
  final String id;                      // Required: unique user ID
  final String? name;
  final String? email;
  final String? phone;
  final Map<String, dynamic>? metadata;
}
```

### Example

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ConferBotProvider(
        apiKey: 'conf_sk_abc123',
        botId: 'bot_xyz789',
        config: ConferBotConfig(
          autoConnect: true,
          enableNotifications: true,
        ),
        user: ConferBotUser(
          id: 'user_123',
          name: 'John Doe',
          email: 'john@example.com',
        ),
      ),
      child: MyApp(),
    ),
  );
}
```

---

## Provider API

Access Conferbot state and methods using Flutter's Provider pattern.

### State Properties

```dart
// Access via context.watch<ConferBotProvider>() or context.read<ConferBotProvider>()
class ConferBotProvider extends ChangeNotifier {
  // State
  bool isInitialized;
  bool isConnected;
  bool isOpen;
  String? chatSessionId;
  int unreadCount;
  Agent? currentAgent;
  List<RecordItem> record;
  ChatbotConfig? chatbotConfig;

  // Methods
  Future<void> openChat();
  void closeChat();
  Future<void> sendMessage(String text);
  Future<void> registerPushToken(String token);
  void on(String event, Function(dynamic) callback);
  void off(String event, [Function(dynamic)? callback]);
}
```

### State Properties

#### `isInitialized`
- **Type:** `bool`
- **Description:** Whether the SDK has completed initialization
- **Usage:** Check before calling SDK methods

#### `isConnected`
- **Type:** `bool`
- **Description:** Socket.IO connection status
- **Usage:** Show connection indicator in UI

#### `isOpen`
- **Type:** `bool`
- **Description:** Whether chat interface is currently open
- **Usage:** Control chat UI visibility

#### `chatSessionId`
- **Type:** `String?`
- **Description:** Current active chat session ID
- **Usage:** Track active sessions, send with analytics

#### `unreadCount`
- **Type:** `int`
- **Description:** Number of unread messages
- **Usage:** Show badge on chat button

#### `currentAgent`
- **Type:** `Agent?`
- **Description:** Currently connected live agent (if any)
- **Usage:** Display agent information

```dart
class Agent {
  final String id;
  final String name;
  final String? avatar;
  final String? email;
  final String? title;
  final String? status;
}
```

#### `record`
- **Type:** `List<RecordItem>`
- **Description:** Array of all chat messages
- **Usage:** Render chat history

```dart
// Base class
abstract class RecordItem {
  final String id;
  final MessageType type;
  final String? text;
  final DateTime time;
}

// Subclasses
class BotMessageRecord extends RecordItem { }
class UserMessageRecord extends RecordItem { }
class AgentMessageRecord extends RecordItem { }
class SystemMessageRecord extends RecordItem { }
```

#### `chatbotConfig`
- **Type:** `ChatbotConfig?`
- **Description:** Chatbot configuration from server
- **Usage:** Customize UI based on bot settings

### Methods

#### `openChat()`

Opens the chat interface and initializes a session if needed.

```dart
Future<void> openChat()
```

**Returns:** Future that completes when chat is opened

**Example:**
```dart
class ChatButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<ConferBotProvider>();

    return ElevatedButton(
      onPressed: () => provider.openChat(),
      child: Text('Open Support'),
    );
  }
}
```

---

#### `closeChat()`

Closes the chat interface (does not end session).

```dart
void closeChat()
```

**Example:**
```dart
final provider = context.read<ConferBotProvider>();

if (provider.isOpen) {
  provider.closeChat();
}
```

---

#### `sendMessage()`

Sends a message to the chatbot or live agent.

```dart
Future<void> sendMessage(String text)
```

**Parameters:**
- `text` - Message text content (required)

**Returns:** Future that completes when message is sent

**Example:**
```dart
final provider = context.read<ConferBotProvider>();

// Send text message
await provider.sendMessage('Hello!');
```

---

#### `registerPushToken()`

Registers a device token for push notifications.

```dart
Future<void> registerPushToken(String token)
```

**Parameters:**
- `token` - FCM (Android) or APNS (iOS) device token

**Returns:** Future that completes when token is registered

**Example:**
```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _registerPushNotifications();
  }

  Future<void> _registerPushNotifications() async {
    final provider = context.read<ConferBotProvider>();

    // Get FCM token
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await provider.registerPushToken(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomeScreen());
  }
}
```

---

#### `on()`

Subscribe to socket events.

```dart
void on(String event, Function(dynamic) callback)
```

**Parameters:**
- `event` - Socket event name (use `SocketEvents` constants)
- `callback` - Function to call when event fires

**Example:**
```dart
class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();

    final provider = context.read<ConferBotProvider>();

    provider.on(SocketEvents.botResponse, (data) {
      debugPrint('Bot replied: $data');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Container());
  }
}
```

---

#### `off()`

Unsubscribe from socket events.

```dart
void off(String event, [Function(dynamic)? callback])
```

**Parameters:**
- `event` - Socket event name
- `callback` - Previously registered callback function (optional)

**Example:**
```dart
final provider = context.read<ConferBotProvider>();

void handleBotResponse(dynamic data) {
  debugPrint('$data');
}

// Subscribe
provider.on(SocketEvents.botResponse, handleBotResponse);

// Later, unsubscribe
provider.off(SocketEvents.botResponse, handleBotResponse);

// Or unsubscribe all listeners for an event
provider.off(SocketEvents.botResponse);
```

---

#### `initiateHandover()`

Request handover to a live agent.

```dart
void initiateHandover({String? message})
```

**Parameters:**
- `message` - Optional message to send with handover request

**Example:**
```dart
final provider = context.read<ConferBotProvider>();

ElevatedButton(
  onPressed: () => provider.initiateHandover(
    message: 'User requested live agent support',
  ),
  child: Text('Talk to Agent'),
)
```

---

## Types

### RecordItem Types

```dart
// Bot message
class BotMessageRecord extends RecordItem {
  final String id;
  final MessageType type = MessageType.botMessage;
  final String? text;
  final DateTime time;
  final Map<String, dynamic>? metadata;
}

// User message
class UserMessageRecord extends RecordItem {
  final String id;
  final MessageType type = MessageType.userMessage;
  final String text;
  final DateTime time;
}

// Agent message
class AgentMessageRecord extends RecordItem {
  final String id;
  final MessageType type = MessageType.agentMessage;
  final String text;
  final DateTime time;
  final AgentDetails agent;
}

// System message
class SystemMessageRecord extends RecordItem {
  final String id;
  final MessageType type = MessageType.systemMessage;
  final String text;
  final DateTime time;
}
```

### MessageType Enum

```dart
enum MessageType {
  userMessage,          // 'user-message'
  botMessage,           // 'bot-message'
  agentMessage,         // 'agent-message'
  agentMessageFile,     // 'agent-message-file'
  agentMessageAudio,    // 'agent-message-audio'
  systemMessage,        // 'system-message'
}
```

---

## Socket Events

### Client Events (emit to server)

```dart
class SocketEvents {
  static const String getChatbotData = 'get-chatbot-data';
  static const String responseRecord = 'response-record';
  static const String joinChatRoom = 'join-chat-room-visitor';
  static const String leaveChatRoom = 'leave-chat-room';
  static const String visitorTyping = 'visitor-typing';
  static const String initiateHandover = 'initiate-handover';
  static const String toggleVisitorInput = 'toggle-visitor-input';
  static const String emailNodeTrigger = 'email-node-trigger';
  static const String zapierNodeTrigger = 'zapier-node-trigger';
  static const String calendarSlotSelection = 'calendar-slot-selection-record';
  static const String sendVisitorMessage = 'send-visitor-message';
  static const String mobileInit = 'mobile-init';
}
```

### Server Events (listen from server)

```dart
class SocketEvents {
  static const String fetchedChatbotData = 'fetched-chatbot-data';
  static const String botResponse = 'bot-response';
  static const String agentMessage = 'agent-message';
  static const String agentAccepted = 'agent-accepted';
  static const String agentLeft = 'agent-left';
  static const String agentTypingStatus = 'agent-typing-status';
  static const String visitorTypingStatus = 'visitor-typing-status';
  static const String chatEnded = 'chat-ended';
  static const String visitorDisconnected = 'visitor-disconnected';
  static const String visitorInputToggled = 'visitor-input-toggled';
  static const String destroyNotification = 'destroy-notification';
  static const String connectionError = 'connection_error';
}
```

### Event Payloads

#### BOT_RESPONSE
```dart
{
  'record': List<RecordItem>,       // Updated message array
  'chatSessionId': String,
}
```

#### AGENT_ACCEPTED
```dart
{
  'agent': Agent,                   // Agent details
  'chatSessionId': String,
}
```

#### AGENT_MESSAGE
```dart
{
  'record': List<RecordItem>,
  'message': String,
  'agent': Agent,
}
```

---

## Configuration

### Default Configuration

All default values from `/lib/src/config/constants.dart`:

```dart
class ConferBotConstants {
  // API
  static const String defaultApiBaseUrl = 'https://embed.conferbot.com/api/v1/mobile';
  static const int apiTimeout = 30000; // 30 seconds

  // Socket
  static const String defaultSocketUrl = 'https://embed.conferbot.com';
  static const int socketTimeout = 20000; // 20 seconds
  static const int socketReconnectionAttempts = 5;
  static const int socketReconnectionDelay = 1000; // 1 second
  static const int socketReconnectionDelayMax = 5000; // 5 seconds

  // Platform
  static const String platformIdentifier = 'flutter';

  // Headers
  static const String headerApiKey = 'X-API-Key';
  static const String headerBotId = 'X-Bot-ID';
  static const String headerPlatform = 'X-Platform';
}
```

### Custom Server URLs

To use a custom embed server:

```dart
ChangeNotifierProvider(
  create: (_) => ConferBotProvider(
    apiKey: 'your-key',
    botId: 'your-bot-id',
    config: ConferBotConfig(
      socketUrl: 'https://your-server.com',
      baseURL: 'https://your-server.com/api/v1/mobile',
    ),
  ),
  child: MyApp(),
)
```

---

## Error Handling

All async methods may throw errors. Wrap in try/catch:

```dart
final provider = context.read<ConferBotProvider>();

try {
  await provider.sendMessage('Hello');
} catch (error) {
  debugPrint('Failed to send: $error');
  // Show error to user
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed to send message')),
  );
}
```

## Type Safety

All types are exported from the main package:

```dart
import 'package:conferbot_flutter/conferbot_flutter.dart';

// All types available:
// - ConferBotProvider
// - ConferBotConfig
// - ConferBotUser
// - ConferBotCustomization
// - Agent
// - RecordItem (and all subclasses)
// - MessageType
// - SocketEvents
// - ChatSession
```

---

## Provider Pattern Usage

### Watch for State Changes

Use `context.watch<ConferBotProvider>()` in build methods to rebuild when state changes:

```dart
class ChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return Column(
      children: [
        Text('Connected: ${provider.isConnected}'),
        Text('Messages: ${provider.record.length}'),
      ],
    );
  }
}
```

### Read Without Watching

Use `context.read<ConferBotProvider>()` to call methods without rebuilding:

```dart
ElevatedButton(
  onPressed: () {
    context.read<ConferBotProvider>().sendMessage('Hello');
  },
  child: Text('Send'),
)
```

### Select Specific State

Use `context.select()` to rebuild only when specific values change:

```dart
class UnreadBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final unreadCount = context.select<ConferBotProvider, int>(
      (provider) => provider.unreadCount,
    );

    return Badge(
      label: Text('$unreadCount'),
      child: Icon(Icons.chat),
    );
  }
}
```
