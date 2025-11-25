# Architecture Documentation

## Overview

The Conferbot Flutter SDK is built with a modular, layered architecture designed for scalability, maintainability, and ease of integration. The SDK provides a complete chatbot solution for mobile applications with real-time messaging, live agent handover, and offline support.

## Architecture Layers

```
┌─────────────────────────────────────────────────────┐
│             Application Layer (User App)             │
│  ┌─────────────────────────────────────────────┐   │
│  │    context.watch<ConferBotProvider>()        │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│              Provider Layer                          │
│  ┌─────────────────────────────────────────────┐   │
│  │     ConferBotProvider (ChangeNotifier)       │   │
│  │  • State management                          │   │
│  │  • Event coordination                        │   │
│  │  • Session management                        │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│              Service Layer                           │
│  ┌──────────────────┐  ┌──────────────────┐        │
│  │  SocketClient    │  │   ApiClient      │        │
│  │  • Real-time     │  │   • REST calls   │        │
│  │  • Events        │  │   • HTTP client  │        │
│  └──────────────────┘  └──────────────────┘        │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│             Configuration Layer                      │
│  ┌─────────────────────────────────────────────┐   │
│  │         Constants & Configuration            │   │
│  │  • API endpoints                             │   │
│  │  • Socket settings                           │   │
│  │  • Timeouts & retry logic                    │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Core Components

### 1. Provider Layer (`/lib/src/providers/`)

**conferbot_provider.dart**

The Provider layer provides centralized state management using Flutter's ChangeNotifier pattern and exposes the SDK API to consuming applications.

**Responsibilities:**
- Maintain global SDK state (connection status, messages, session)
- Initialize and manage service layer (API + Socket clients)
- Provide state via Provider pattern for easy consumption
- Handle event coordination between services
- Notify listeners on state changes

**State Management:**
```dart
{
  isInitialized: bool;           // SDK setup complete
  isConnected: bool;             // Socket connection status
  isOpen: bool;                  // Chat UI open/closed
  chatSessionId?: String;        // Active session ID
  unreadCount: int;              // Unread message count
  currentAgent?: Agent;          // Active live agent
  record: List<RecordItem>;      // Message history
}
```

**Key Methods:**
- `openChat()` - Initialize session and open chat
- `closeChat()` - Close chat interface
- `sendMessage(String text)` - Send user messages
- `registerPushToken(String token)` - Register for push notifications
- `on(String event, Function callback)` - Event listeners
- `off(String event, [Function? callback])` - Remove listeners

### 2. Service Layer (`/lib/src/services/`)

#### **Socket Client (`socket_client.dart`)**

Manages real-time bidirectional communication with the embed server using Socket.IO.

**Responsibilities:**
- Establish and maintain WebSocket connection
- Handle reconnection logic with exponential backoff
- Emit events to server (messages, typing status, etc.)
- Listen for server events (bot responses, agent messages)
- Manage socket event listeners

**Configuration:**
```dart
{
  reconnectionAttempts: 5,
  reconnectionDelay: 1000,      // 1 second
  reconnectionDelayMax: 5000,   // 5 seconds
  timeout: 20000,               // 20 seconds
  transports: ['websocket', 'polling']
}
```

**Socket Events:**
- Client → Server: `mobile-init`, `send-visitor-message`, `join-chat-room-visitor`
- Server → Client: `bot-response`, `agent-message`, `agent-accepted`, `agent-left`

#### **API Client (`api_client.dart`)**

Handles RESTful HTTP communication with the embed server.

**Responsibilities:**
- Initialize chat sessions
- Fetch session history
- Send messages (alternative to socket)
- Register push notification tokens
- Handle HTTP errors and retries

**Endpoints:**
```dart
POST   /session/init                  // Create new session
GET    /session/{chatSessionId}       // Get session history
POST   /session/{chatSessionId}/message // Send message
POST   /push/register                 // Register push token
```

**HTTP Client:**
- Uses `package:http` for HTTP requests
- Automatic timeout handling (30 seconds default)
- JSON serialization/deserialization
- Error handling with typed responses

### 3. Model Layer (`/lib/src/models/`)

#### **Type Definitions**

All models match the embed-server schema exactly for compatibility.

**Key Models:**
- `Agent` - Live agent information
- `RecordItem` - Base class for all message types (abstract)
  - `UserMessageRecord` - User messages
  - `BotMessageRecord` - Bot responses
  - `AgentMessageRecord` - Agent messages
  - `AgentMessageFileRecord` - File attachments
  - `AgentMessageAudioRecord` - Audio messages
  - `SystemMessageRecord` - System notifications
- `ChatSession` - Complete session with metadata
- `SocketEvents` - All socket event constants
- `ConferBotUser` - User identification
- `ConferBotConfig` - SDK configuration
- `ConferBotCustomization` - UI customization

**Type Safety:**
- All models are immutable classes
- Factory constructors for JSON parsing
- toJson() methods for serialization
- Null safety throughout

### 4. Theme Layer (`/lib/src/theme/`)

**Theme System:**
- `ConferBotTheme` - Complete theme definition
- `defaultTheme` - iOS-inspired light theme
- `darkTheme` - Dark mode theme

**Theme Categories:**
- Colors (22 color definitions)
- Typography (font sizes, weights, line heights)
- Spacing (6-step scale: xs → xxl)
- Border Radius (6 variants)
- Shadows (5 elevation levels)
- Animations (durations and curves)
- Layout (component dimensions)

### 5. Widget Layer (`/lib/src/widgets/`)

**9 Production-Ready Widgets:**

1. **ConferBotAvatar** - User/agent profile pictures with initials
2. **ConnectionStatus** - Online/offline indicator (3 variants)
3. **TypingIndicator** - Animated typing dots
4. **EmptyState** - Empty chat placeholder
5. **MessageBubble** - Individual message display
6. **ChatInput** - Text input with send button
7. **ChatHeader** - Header with title and close button
8. **MessageList** - Virtualized scrolling message list
9. **ChatWidget** - Complete drop-in modal widget

**Widget Features:**
- Theme-aware (respects ConferBotTheme)
- Accessibility support
- Platform-specific optimizations
- Smooth animations
- Performance optimized

## Data Flow

### Message Sending Flow

```
User taps send button
        ↓
ChatInput.onSend(text)
        ↓
ConferBotProvider.sendMessage(text)
        ↓
1. Create UserMessageRecord
2. Add to record[] (optimistic update)
3. notifyListeners()
        ↓
SocketClient.sendVisitorMessage()
        ↓
Emit to embed-server
        ↓
Server processes
        ↓
Server emits bot-response
        ↓
SocketClient receives event
        ↓
ConferBotProvider handles bot-response
        ↓
Add BotMessageRecord to record[]
        ↓
notifyListeners()
        ↓
MessageList rebuilds with new message
```

### Session Initialization Flow

```
User opens chat
        ↓
ConferBotProvider.openChat()
        ↓
Check if chatSessionId exists
        ↓
If null: ApiClient.initSession()
        ↓
POST /session/init
        ↓
Server creates session
        ↓
Returns { chatSessionId, record[] }
        ↓
Store chatSessionId
        ↓
SocketClient.joinChatRoom(chatSessionId)
        ↓
SocketClient.mobileInit(chatSessionId)
        ↓
Set isOpen = true
        ↓
notifyListeners()
        ↓
ChatWidget displays with message history
```

### Live Agent Handover Flow

```
User requests live agent
        ↓
ConferBotProvider.initiateHandover()
        ↓
SocketClient.emit('initiate-handover')
        ↓
Server notifies agents
        ↓
Agent accepts
        ↓
Server emits 'agent-accepted'
        ↓
SocketClient receives event
        ↓
ConferBotProvider updates currentAgent
        ↓
notifyListeners()
        ↓
ChatHeader updates to show agent info
        ↓
Future messages go to agent
        ↓
Agent messages arrive via 'agent-message'
        ↓
Added to record[] as AgentMessageRecord
```

## State Management Pattern

The SDK uses Flutter's **ChangeNotifier** pattern with the **Provider** package:

```dart
// Provider setup
ChangeNotifierProvider(
  create: (_) => ConferBotProvider(
    apiKey: apiKey,
    botId: botId,
  ),
  child: MyApp(),
)

// Consuming state
final provider = context.watch<ConferBotProvider>();
final messages = provider.record;
final isConnected = provider.isConnected;

// Calling methods
context.read<ConferBotProvider>().sendMessage('Hello');
```

**Benefits:**
- Centralized state
- Automatic UI updates via notifyListeners()
- Easy to test
- Type-safe
- No boilerplate

## Configuration Management

All configuration is centralized in `/lib/src/config/constants.dart`:

```dart
class ConferBotConstants {
  static const String defaultApiBaseUrl = '...';
  static const String defaultSocketUrl = '...';
  static const int apiTimeout = 30000;
  static const int socketTimeout = 20000;
  static const int socketReconnectionAttempts = 5;
  // ... more constants
}
```

**Benefits:**
- Single source of truth
- Easy to modify
- Environment-specific overrides
- Type-safe constants

## Error Handling

### API Errors
```dart
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? message;
}
```

All API methods return `ApiResponse<T>` with success/error states.

### Socket Errors
```dart
socket.on('connect_error', (error) {
  debugPrint('Connection error: $error');
  _isConnected = false;
  notifyListeners();
});
```

Automatic reconnection with exponential backoff.

### Widget Error Boundaries
Widgets handle errors gracefully:
- Show empty states when no data
- Display error messages for failures
- Disable inputs when disconnected

## Performance Optimizations

### Message List Virtualization
```dart
ListView.builder(
  itemCount: messages.length,
  itemBuilder: (context, index) => MessageBubble(...),
)
```
Only renders visible messages, handles 10,000+ messages efficiently.

### Optimistic Updates
Messages added to UI immediately before server confirmation for instant feedback.

### State Notifications
Only calls `notifyListeners()` when state actually changes to minimize rebuilds.

### Widget Rebuild Optimization
Uses `const` constructors where possible to prevent unnecessary rebuilds.

## Testing Strategy

### Unit Tests
- Model serialization/deserialization
- API client methods
- Socket client events
- Provider state changes

### Widget Tests
- Component rendering
- User interactions
- State updates
- Accessibility

### Integration Tests
- Full flow testing
- Socket connection
- Message sending/receiving
- Session management

## Security Considerations

### API Key Protection
- API keys passed via headers
- Never logged in production
- Validated on server

### Socket Authentication
- Extra headers with API key and bot ID
- Server validates on connection
- Automatic disconnection on auth failure

### Data Validation
- All incoming data validated
- Type checking on deserialization
- Sanitization of user input

## Scalability

### Message History
- Paginated loading support ready
- Efficient rendering with virtualization
- Memory-efficient storage

### Multiple Sessions
- Can manage multiple chat sessions
- Session isolation
- Independent socket connections if needed

### High Message Volume
- Optimized rendering
- Automatic cleanup of old messages
- Efficient state updates

## Platform Support

- **iOS**: >= 12.0
- **Android**: >= API 21
- **Flutter**: >= 3.10.0
- **Dart**: >= 3.0.0

## Dependencies

**Core:**
- `provider: ^6.1.1` - State management
- `socket_io_client: ^2.0.3+1` - Real-time communication
- `http: ^1.1.2` - HTTP requests
- `intl: ^0.18.1` - Date formatting

**Dev:**
- `flutter_test` - Testing framework
- `flutter_lints: ^3.0.1` - Code quality

## Next Steps

See also:
- [Components Guide](COMPONENTS.md) - Widget documentation
- [API Reference](API.md) - Complete API docs
- [Examples](EXAMPLES.md) - Usage examples
- [Publishing](PUBLISHING.md) - Deployment guide
