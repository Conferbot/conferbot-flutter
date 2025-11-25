# UI Components Guide

Complete guide to using Conferbot's pre-built UI widgets.

## Quick Start

### Option 1: Drop-in Widget (Easiest)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ConferBotProvider(
        apiKey: 'your-api-key',
        botId: 'your-bot-id',
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
      body: Center(
        child: ElevatedButton(
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
      ),
    );
  }
}
```

That's it! Full chat in minimal code.

### Option 2: Build Custom UI (Headless)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

class CustomChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: provider.record.length,
            itemBuilder: (context, index) {
              final msg = provider.record[index];
              return Text(msg.text ?? '');
            },
          ),
        ),
      ],
    );
  }
}
```

Use provider, build your own UI.

### Option 3: Mix & Match

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

class CustomChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return Column(
      children: [
        MessageList(messages: provider.record),
        MyCustomInput(onSend: provider.sendMessage),
      ],
    );
  }
}
```

Use our widgets where you want, custom where you need.

---

## Widgets

### ChatWidget

Complete chat interface in a modal.

```dart
ChatWidget(
  title: 'Support',
  placeholder: 'Type a message...',
)
```

**Props:**
- `title` - Header title
- `placeholder` - Input placeholder
- `showTimestamps` - Show message times
- `onClose` - Close callback
- `theme` - Custom theme (optional)

### MessageList

Scrollable list of messages.

```dart
MessageList(
  messages: record,
  showTimestamps: true,
)
```

**Props:**
- `messages` - List of messages
- `showTypingIndicator` - Show "typing..."
- `showTimestamps` - Show times
- `showAvatars` - Show avatars
- `emptyComponent` - Custom empty state widget

### MessageBubble

Individual message display.

```dart
MessageBubble(
  message: msg,
  showAvatar: true,
  onLongPress: () => copyMessage(msg),
)
```

**Props:**
- `message` - Message object
- `showAvatar` - Show avatar
- `showTimestamp` - Show time
- `onTap` - Tap handler
- `onLongPress` - Long press handler

### ChatInput

Message input with send button.

```dart
ChatInput(
  onSend: (text) => sendMessage(text),
  placeholder: 'Type...',
)
```

**Props:**
- `onSend` - Send callback (Function(String))
- `placeholder` - Placeholder text
- `enabled` - Enable/disable input
- `maxLength` - Max characters
- `controller` - TextEditingController (optional)

### ChatHeader

Header with title and close button.

```dart
ChatHeader(
  title: 'Support Chat',
  subtitle: 'Online',
  agent: currentAgent,
  onClose: closeChat,
)
```

**Props:**
- `title` - Header title
- `subtitle` - Subtitle text
- `agent` - Current agent
- `onClose` - Close callback
- `showConnectionStatus` - Show online/offline

### ConferBotAvatar

User/agent avatar with initials fallback.

```dart
ConferBotAvatar(
  imageUrl: agent.avatar,
  name: agent.name,
  size: 40,
)
```

**Props:**
- `imageUrl` - Image URL
- `name` - Name for initials
- `size` - Size in pixels
- `shape` - AvatarShape.circle | square | rounded

### TypingIndicator

Animated typing dots.

```dart
TypingIndicator(visible: isAgentTyping)
```

**Props:**
- `visible` - Show/hide
- `dotColor` - Dot color
- `dotSize` - Dot size

### ConnectionStatus

Online/offline indicator.

```dart
ConnectionStatus(
  variant: ConnectionVariant.badge,
  showWhenOnline: false,
)
```

**Props:**
- `variant` - ConnectionVariant.dot | badge | text
- `onlineLabel` - Online text
- `offlineLabel` - Offline text
- `showWhenOnline` - Show when connected

### EmptyState

Empty chat placeholder.

```dart
EmptyState(
  title: 'No messages yet',
  message: 'Start a conversation',
)
```

**Props:**
- `title` - Title text
- `message` - Subtitle text
- `icon` - Custom icon widget
- `action` - Custom action button widget

---

## Theming

### Use Default Themes

```dart
import 'package:conferbot_flutter/conferbot_flutter.dart';

ChatWidget(theme: darkTheme)
```

### Custom Theme

```dart
import 'package:conferbot_flutter/conferbot_flutter.dart';

final myTheme = ConferBotTheme(
  brightness: Brightness.light,
  colors: ConferBotColors(
    primary: Color(0xFFFF6B6B),
    userBubble: Color(0xFFFF6B6B),
    // ... other colors
  ),
  // ... other settings
);

ChatWidget(theme: myTheme)
```

### Theme Properties

```dart
ConferBotTheme {
  brightness: Brightness.light | dark,
  colors: ConferBotColors {
    primary, secondary, background, surface,
    userBubble, botBubble, agentBubble, systemBubble,
    text, textSecondary, textDisabled,
    border, divider,
    success, error, warning, info,
    online, offline
  },
  typography: ConferBotTypography {
    fontSize: { xs, sm, md, lg, xl, xxl },
    fontWeight: { light, regular, medium, semibold, bold }
  },
  spacing: ConferBotSpacing { xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48 },
  borderRadius: ConferBotBorderRadius { none, sm, md, lg, xl, full },
  shadows: ConferBotShadows { none, sm, md, lg, xl }
}
```

---

## Common Patterns

### Basic Chat Screen

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

class ChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return Scaffold(
      body: Column(
        children: [
          ChatHeader(
            title: 'Support',
            agent: provider.currentAgent,
            onClose: () => Navigator.pop(context),
          ),
          Expanded(
            child: MessageList(messages: provider.record),
          ),
          ChatInput(onSend: provider.sendMessage),
        ],
      ),
    );
  }
}
```

### With Typing Indicator

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ConferBotProvider>();

    provider.on(SocketEvents.agentTypingStatus, (data) {
      if (mounted) {
        setState(() {
          _typing = data['isTyping'] ?? false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return MessageList(
      messages: provider.record,
      showTypingIndicator: _typing,
    );
  }
}
```

### With Custom Empty State

```dart
MessageList(
  messages: record,
  emptyComponent: EmptyState(
    title: 'Welcome!',
    message: 'How can we help you today?',
    action: ElevatedButton(
      onPressed: showQuickHelp,
      child: Text('Quick Help'),
    ),
  ),
)
```

### Handle Message Actions

```dart
MessageBubble(
  message: msg,
  onLongPress: () {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.copy),
            title: Text('Copy'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: msg.text));
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete'),
            onTap: () {
              deleteMessage(msg);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  },
)
```

---

## Type Safety

All widgets are fully typed:

```dart
import 'package:conferbot_flutter/conferbot_flutter.dart';

// Types available
ConferBotTheme
ConferBotColors
MessageList
MessageBubble
ChatInput
ChatWidget
// ... and more
```

---

## Performance Tips

### MessageList Optimization

- Uses ListView.builder virtualization
- Only renders visible messages
- Auto-scrolls to new messages
- Handles thousands of messages efficiently

### Best Practices

```dart
// ✅ Good - Let MessageList handle rendering
MessageList(messages: record)

// ❌ Bad - Manual loop kills performance
Column(
  children: record.map((msg) => MessageBubble(message: msg)).toList(),
)
```

---

## Accessibility

All widgets have built-in accessibility:

- Semantic labels
- Keyboard navigation support
- High contrast support
- Focus management

Test with:
```bash
# iOS
Settings > Accessibility > VoiceOver

# Android
Settings > Accessibility > TalkBack
```

---

## Need Help?

- **Documentation**: [docs.conferbot.com](https://docs.conferbot.com)
- **Examples**: See `/example` directory
- **Issues**: [GitHub Issues](https://github.com/conferbot/flutter-sdk/issues)
- **Email**: support@conferbot.com
