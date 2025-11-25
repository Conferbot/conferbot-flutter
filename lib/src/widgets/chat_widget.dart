import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conferbot_provider.dart';
import '../models/socket_events.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import 'chat_header.dart';
import 'message_list.dart';
import 'chat_input.dart';

/// Complete drop-in chat widget
class ChatWidget extends StatefulWidget {
  final String? title;
  final String? placeholder;
  final bool showTimestamps;
  final bool enableAttachments;
  final ConferBotTheme? theme;

  const ChatWidget({
    super.key,
    this.title,
    this.placeholder,
    this.showTimestamps = false,
    this.enableAttachments = false,
    this.theme,
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  bool _isAgentTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupListeners();
      context.read<ConferBotProvider>().openChat();
    });
  }

  void _setupListeners() {
    final provider = context.read<ConferBotProvider>();

    provider.on(SocketEvents.agentTypingStatus, (data) {
      if (data != null && data is Map<String, dynamic>) {
        setState(() {
          _isAgentTyping = data['isTyping'] as bool? ?? false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final provider = context.watch<ConferBotProvider>();

    return Scaffold(
      backgroundColor: effectiveTheme.colors.background,
      body: Column(
        children: [
          ChatHeader(
            title: widget.title ?? 'Support Chat',
            subtitle: _getSubtitle(provider),
            agent: provider.currentAgent,
            onClose: () {
              provider.closeChat();
              Navigator.of(context).pop();
            },
            showConnectionStatus: true,
            theme: effectiveTheme,
          ),
          Expanded(
            child: MessageList(
              messages: provider.record,
              showTypingIndicator: _isAgentTyping,
              showTimestamps: widget.showTimestamps,
              theme: effectiveTheme,
            ),
          ),
          ChatInput(
            onSend: (text) async {
              await provider.sendMessage(text);
            },
            placeholder: widget.placeholder ?? 'Type a message...',
            disabled: !provider.isConnected,
            enableAttachments: widget.enableAttachments,
            theme: effectiveTheme,
          ),
        ],
      ),
    );
  }

  String? _getSubtitle(ConferBotProvider provider) {
    if (provider.currentAgent != null) {
      return provider.currentAgent!.email ?? 'Live Agent';
    }
    if (!provider.isConnected) {
      return 'Reconnecting...';
    }
    return null;
  }
}
