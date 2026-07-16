import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

/// Main entry point with proper Hive initialization for session persistence
void main() async {
  // Ensure Flutter bindings are initialized before Hive
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize StorageService (Hive) before running the app
  // This is REQUIRED for session persistence to work
  await StorageService.init();

  // Configure to use local embed-server (10.0.2.2 = host localhost from Android emulator)
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConferBotProvider(
        apiKey: 'test_key', // Replace with your API key
        botId: '691c970890527a0468f9b2c9', // Replace with your bot ID
        config: const ConferBotConfig(
          enableNotifications: true,
          enableOfflineMode: true,
          // Session persistence configuration
          enablePersistence: true, // Enable session persistence (default: true)
          sessionTimeout: Duration(minutes: 30), // Session timeout like web widget
        ),
      ),
      child: MaterialApp(
        title: 'Conferbot Flutter Example',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007AFF)),
          useMaterial3: true,
        ),
        home: const ExampleHomePage(),
      ),
    );
  }
}

class ExampleHomePage extends StatelessWidget {
  const ExampleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // ConferBotFAB overlays the floating chat bubble (bottom-right, server
    // customized icon, color and CTA tooltip) over the page - same
    // experience as the web widget embed.
    return ConferBotFAB(
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Conferbot SDK Example'),
        actions: [
          // Debug button to show storage stats
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'stats',
                child: Text('View Storage Stats'),
              ),
              const PopupMenuItem(
                value: 'clear_session',
                child: Text('Clear Current Session'),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Text('Clear All Data'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Conferbot Flutter SDK',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap an option below to see different usage patterns',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Session Restored Indicator
              Consumer<ConferBotProvider>(
                builder: (context, provider, child) {
                  if (provider.sessionRestored) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.restore, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Previous session restored! Your conversation will continue where you left off.',
                              style: TextStyle(color: Colors.green[700]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              const SizedBox(height: 16),

              // Option 1: Drop-in Widget
              _buildOptionCard(
                context,
                icon: Icons.chat_bubble,
                title: 'Option 1: Drop-in Widget',
                description: 'Full-featured chat in a modal. Easiest integration.',
                buttonText: 'Open Chat Widget',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: context.read<ConferBotProvider>(),
                        child: const ChatWidget(
                          title: 'Support Chat',
                          placeholder: 'Type your message...',
                          showTimestamps: true,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Option 2: Headless SDK
              _buildOptionCard(
                context,
                icon: Icons.code,
                title: 'Option 2: Headless SDK',
                description: 'Use the SDK context to build your own UI.',
                buttonText: 'View Headless Example',
                isSecondary: true,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: context.read<ConferBotProvider>(),
                        child: const HeadlessExample(),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Option 3: Mix & Match
              _buildOptionCard(
                context,
                icon: Icons.widgets,
                title: 'Option 3: Mix & Match',
                description: 'Use our widgets where you want, custom where you need.',
                buttonText: 'View Custom Example',
                isSecondary: true,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: context.read<ConferBotProvider>(),
                        child: const CustomExample(),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              Text(
                'Session persistence is enabled by default.\nConversations will resume after app restart (within 30 min).',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) async {
    final provider = context.read<ConferBotProvider>();

    switch (action) {
      case 'stats':
        final stats = provider.getStorageStats();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Storage Stats'),
            content: SingleChildScrollView(
              child: Text(
                stats.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('\n'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        break;

      case 'clear_session':
        await provider.clearCurrentSession();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current session cleared')),
        );
        break;

      case 'clear_all':
        await provider.clearAllPersistedData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All persisted data cleared')),
        );
        break;
    }
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
    bool isSecondary = false,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 32, color: const Color(0xFF007AFF)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSecondary ? Colors.grey[200] : const Color(0xFF007AFF),
                  foregroundColor: isSecondary ? const Color(0xFF007AFF) : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Headless Example with session restoration awareness
class HeadlessExample extends StatefulWidget {
  const HeadlessExample({super.key});

  @override
  State<HeadlessExample> createState() => _HeadlessExampleState();
}

class _HeadlessExampleState extends State<HeadlessExample> with WidgetsBindingObserver {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    super.dispose();
  }

  /// Handle app lifecycle for session persistence
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = context.read<ConferBotProvider>();

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Persist state when app goes to background
      provider.persistState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Headless Example'),
        actions: [
          if (provider.sessionRestored)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Restored', style: TextStyle(fontSize: 12)),
                backgroundColor: Colors.green[100],
                avatar: Icon(Icons.restore, size: 16, color: Colors.green[700]),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  provider.currentAgent?.name ?? 'Support Chat',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    if (provider.isPersistenceReady)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.save,
                          size: 18,
                          color: Colors.green[600],
                        ),
                      ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: provider.isConnected ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.record.length,
              itemBuilder: (context, index) {
                final message = provider.record[index];
                final isUser = message.type == MessageType.userMessage;

                String? text;
                if (message is UserMessageRecord) {
                  text = message.text;
                } else if (message is BotMessageRecord) {
                  text = message.text;
                } else if (message is AgentMessageRecord) {
                  text = message.text;
                }

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF007AFF) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      text ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
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
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: const Color(0xFF007AFF),
                  onPressed: () => _sendMessage(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isNotEmpty) {
      context.read<ConferBotProvider>().sendMessage(text);
      _textController.clear();
    }
  }
}

// Custom Example with session persistence awareness
class CustomExample extends StatefulWidget {
  const CustomExample({super.key});

  @override
  State<CustomExample> createState() => _CustomExampleState();
}

class _CustomExampleState extends State<CustomExample> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Handle app lifecycle for session persistence
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = context.read<ConferBotProvider>();

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Persist state when app goes to background
      provider.persistState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return Scaffold(
      body: Column(
        children: [
          ChatHeader(
            title: 'Support',
            subtitle: provider.sessionRestored
                ? 'Conversation restored'
                : 'We typically reply in minutes',
            agent: provider.currentAgent,
            onClose: () => Navigator.pop(context),
            showConnectionStatus: true,
          ),
          Expanded(
            child: MessageList(
              messages: provider.record,
              showTimestamps: true,
              showAvatars: true,
            ),
          ),
          ChatInput(
            onSend: (text) async {
              await provider.sendMessage(text);
            },
            placeholder: 'Ask us anything...',
          ),
        ],
      ),
    );
  }
}
