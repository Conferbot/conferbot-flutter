# Usage Examples

Common usage patterns and examples for the Conferbot Flutter SDK.

## Table of Contents

- [Basic Setup](#basic-setup)
- [Simple Chat Screen](#simple-chat-screen)
- [Chat with Message History](#chat-with-message-history)
- [Live Agent Handover](#live-agent-handover)
- [Push Notifications](#push-notifications)
- [Custom Event Handling](#custom-event-handling)
- [Typing Indicators](#typing-indicators)
- [Offline Support](#offline-support)
- [Error Handling](#error-handling)

---

## Basic Setup

Minimal setup to get started:

```dart
// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ConferBotProvider(
        apiKey: 'conf_sk_your_api_key',
        botId: 'your_bot_id',
      ),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conferbot Demo',
      home: HomeScreen(),
    );
  }
}
```

---

## Simple Chat Screen

Basic chat interface:

```dart
// screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

class ChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Support Chat'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Connection Status
            Text(
              'Status: ${provider.isConnected ? "🟢 Connected" : "🔴 Offline"}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),

            // Unread Badge
            if (provider.unreadCount > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '${provider.unreadCount} new messages',
                  style: TextStyle(color: Colors.white),
                ),
              ),

            SizedBox(height: 20),

            // Open Chat Button
            ElevatedButton(
              onPressed: () => provider.openChat(),
              child: Text('Open Support Chat'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Chat with Message History

Display full chat history:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:intl/intl.dart';

class FullChatScreen extends StatefulWidget {
  @override
  _FullChatScreenState createState() => _FullChatScreenState();
}

class _FullChatScreenState extends State<FullChatScreen> {
  final TextEditingController _textController = TextEditingController();

  void _handleSend(ConferBotProvider provider) async {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      await provider.sendMessage(text);
      _textController.clear();
    }
  }

  Widget _renderMessage(RecordItem item) {
    final isUser = item.type == MessageType.userMessage;
    final isBot = item.type == MessageType.botMessage;
    final isAgent = item.type == MessageType.agentMessage;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isUser ? Color(0xFF007AFF) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agent name
            if (isAgent && item is AgentMessageRecord)
              Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text(
                  item.agent.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),

            // Message text
            Text(
              item.text ?? '',
              style: TextStyle(
                fontSize: 16,
                color: isUser ? Colors.white : Colors.black,
              ),
            ),

            // Time
            SizedBox(height: 5),
            Text(
              DateFormat('HH:mm').format(item.time),
              style: TextStyle(
                fontSize: 11,
                color: isUser ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          provider.isConnected ? '🟢 Connected' : '🔴 Reconnecting...',
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(10),
              itemCount: provider.record.length,
              itemBuilder: (context, index) {
                return _renderMessage(provider.record[index]);
              },
            ),
          ),

          // Input
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: provider.isConnected
                      ? () => _handleSend(provider)
                      : null,
                  style: ElevatedButton.styleFrom(
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(12),
                    backgroundColor: Color(0xFF007AFF),
                  ),
                  child: Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
```

---

## Live Agent Handover

Handle live agent connections:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

class AgentChatScreen extends StatefulWidget {
  @override
  _AgentChatScreenState createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
  @override
  void initState() {
    super.initState();

    final provider = context.read<ConferBotProvider>();

    // Listen for agent accepted
    provider.on(SocketEvents.agentAccepted, (data) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Agent Connected'),
            content: Text('${data['agent']['name']} has joined the chat'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    });

    // Listen for agent left
    provider.on(SocketEvents.agentLeft, (data) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Agent Left'),
            content: Text(
              'The agent has left the chat. You are now chatting with the bot.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();
    final currentAgent = provider.currentAgent;

    return Scaffold(
      appBar: AppBar(
        title: currentAgent != null
            ? Row(
                children: [
                  if (currentAgent.avatar != null)
                    CircleAvatar(
                      backgroundImage: NetworkImage(currentAgent.avatar!),
                      radius: 16,
                    ),
                  SizedBox(width: 10),
                  Text('Chatting with ${currentAgent.name}'),
                ],
              )
            : Text('Chatting with AI Bot'),
      ),
      body: Column(
        children: [
          // Chat messages here
          Expanded(child: MessageList(messages: provider.record)),

          // Request agent button
          if (currentAgent == null)
            Padding(
              padding: EdgeInsets.all(10),
              child: ElevatedButton.icon(
                onPressed: () => provider.initiateHandover(
                  message: 'User requested live agent support',
                ),
                icon: Icon(Icons.support_agent),
                label: Text('Talk to Live Agent'),
              ),
            ),
        ],
      ),
    );
  }
}
```

---

## Push Notifications

Setup push notifications (Firebase):

```dart
// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ConferBotProvider(
        apiKey: 'conf_sk_your_api_key',
        botId: 'your_bot_id',
      ),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PushNotificationSetup(child: HomeScreen()),
    );
  }
}

class PushNotificationSetup extends StatefulWidget {
  final Widget child;

  const PushNotificationSetup({required this.child});

  @override
  _PushNotificationSetupState createState() => _PushNotificationSetupState();
}

class _PushNotificationSetupState extends State<PushNotificationSetup> {
  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    final provider = context.read<ConferBotProvider>();
    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Push notification permission granted');

      // Get FCM token
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await provider.registerPushToken(token);
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        provider.registerPushToken(newToken);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
```

---

## Custom Event Handling

Listen to specific events:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

class CustomEventHandler extends StatefulWidget {
  @override
  _CustomEventHandlerState createState() => _CustomEventHandlerState();
}

class _CustomEventHandlerState extends State<CustomEventHandler> {
  bool _isAgentTyping = false;

  @override
  void initState() {
    super.initState();

    final provider = context.read<ConferBotProvider>();

    // Listen for agent typing status
    provider.on(SocketEvents.agentTypingStatus, (data) {
      if (mounted) {
        setState(() {
          _isAgentTyping = data['isTyping'] ?? false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isAgentTyping)
          Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                SizedBox(width: 10),
                Text(
                  'Agent is typing...',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(width: 10),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
```

---

## Typing Indicators

Show when user is typing:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'dart:async';

class ChatInputWithTyping extends StatefulWidget {
  @override
  _ChatInputWithTypingState createState() => _ChatInputWithTypingState();
}

class _ChatInputWithTypingState extends State<ChatInputWithTyping> {
  final TextEditingController _controller = TextEditingController();
  Timer? _typingTimer;
  bool _isTyping = false;

  void _handleTextChange(String text) {
    final provider = context.read<ConferBotProvider>();
    final chatSessionId = provider.chatSessionId;

    // Cancel previous timer
    _typingTimer?.cancel();

    // Send typing started
    if (text.isNotEmpty && chatSessionId != null && !_isTyping) {
      _isTyping = true;
      // Note: You'll need to expose socket client or add method to provider
      // provider.sendVisitorTyping(true);
    }

    // Auto-stop typing after 3 seconds
    _typingTimer = Timer(Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        // provider.sendVisitorTyping(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _handleTextChange,
      decoration: InputDecoration(
        hintText: 'Type a message...',
        border: OutlineInputBorder(),
      ),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
```

---

## Offline Support

Handle offline state gracefully:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

class OfflineHandler extends StatefulWidget {
  @override
  _OfflineHandlerState createState() => _OfflineHandlerState();
}

class _OfflineHandlerState extends State<OfflineHandler> {
  bool _isOnline = true;
  List<String> _pendingMessages = [];

  @override
  void initState() {
    super.initState();
    _monitorNetworkStatus();
  }

  void _monitorNetworkStatus() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final wasOffline = !_isOnline;
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });

      // Send pending messages when back online
      if (_isOnline && wasOffline && _pendingMessages.isNotEmpty) {
        final provider = context.read<ConferBotProvider>();
        for (var msg in _pendingMessages) {
          provider.sendMessage(msg);
        }
        _pendingMessages.clear();
      }
    });
  }

  Future<void> _handleSendMessage(String text) async {
    final provider = context.read<ConferBotProvider>();

    if (!_isOnline) {
      // Queue message for later
      setState(() {
        _pendingMessages.add(text);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offline - Message will be sent when connection is restored'),
        ),
      );
    } else {
      await provider.sendMessage(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return Column(
      children: [
        // Offline warning
        if (!_isOnline)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10),
            color: Colors.orange,
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⚠️ You are offline. Messages will be sent when connection is restored.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

        // Reconnecting indicator
        if (!provider.isConnected && _isOnline)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10),
            color: Colors.blue,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  '🔄 Reconnecting to chat server...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),

        // Your chat UI here
      ],
    );
  }
}
```

---

## Error Handling

Robust error handling:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

class ErrorHandlingExample extends StatefulWidget {
  @override
  _ErrorHandlingExampleState createState() => _ErrorHandlingExampleState();
}

class _ErrorHandlingExampleState extends State<ErrorHandlingExample> {
  bool _isSending = false;

  Future<void> _handleSendWithRetry(String text, {int retries = 3}) async {
    setState(() => _isSending = true);

    final provider = context.read<ConferBotProvider>();

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        await provider.sendMessage(text);
        setState(() => _isSending = false);
        return; // Success
      } catch (error) {
        debugPrint('Send attempt $attempt failed: $error');

        if (attempt == retries) {
          // Final attempt failed
          setState(() => _isSending = false);

          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Error'),
                content: Text(
                  'Failed to send message. Please try again later.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleSendWithRetry(text);
                    },
                    child: Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                ],
              ),
            );
          }
        } else {
          // Wait before retry (exponential backoff)
          await Future.delayed(Duration(seconds: attempt));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isSending)
          Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 10),
                Text('Sending message...'),
              ],
            ),
          ),
        // Your UI here
      ],
    );
  }
}
```

---

## Complete Chat Application

Putting it all together:

```dart
// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ConferBotProvider(
        apiKey: const String.fromEnvironment('CONFERBOT_API_KEY'),
        botId: const String.fromEnvironment('CONFERBOT_BOT_ID'),
        config: ConferBotConfig(
          autoConnect: true,
          enableNotifications: true,
        ),
        user: ConferBotUser(
          id: 'user_12345',
          name: 'John Doe',
          email: 'john@example.com',
        ),
      ),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conferbot Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Conferbot Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: context.read<ConferBotProvider>(),
                      child: ChatWidget(),
                    ),
                  ),
                );
              },
              child: Text('Open Chat'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: context.read<ConferBotProvider>(),
                      child: FullChatScreen(),
                    ),
                  ),
                );
              },
              child: Text('Open Custom Chat'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

For more examples, check the `/example` directory in the repository.
