import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConferBotProvider(
        apiKey: 'conf_sk_your_api_key_here', // Replace with your API key
        botId: 'your_bot_id_here', // Replace with your bot ID
        config: const ConferBotConfig(
          enableNotifications: true,
          enableOfflineMode: true,
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Conferbot SDK Example'),
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
              const SizedBox(height: 32),

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
                '📚 Check the docs/ folder for complete documentation',
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

// Headless Example placeholder
class HeadlessExample extends StatelessWidget {
  const HeadlessExample({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Headless Example'),
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
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        provider.sendMessage(text);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Example placeholder
class CustomExample extends StatelessWidget {
  const CustomExample({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();

    return Scaffold(
      body: Column(
        children: [
          ChatHeader(
            title: 'Support',
            subtitle: 'We typically reply in minutes',
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
