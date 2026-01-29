import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conferbot_provider.dart';
import '../models/socket_events.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import '../ui/widgets/node_widgets.dart';
import 'chat_header.dart';
import 'message_list.dart';
import 'chat_input.dart';
import 'typing_indicator.dart';

/// Complete drop-in chat widget with node rendering support
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
            child: _buildChatContent(provider, effectiveTheme),
          ),
          _buildInputArea(provider, effectiveTheme),
        ],
      ),
    );
  }

  Widget _buildChatContent(ConferBotProvider provider, ConferBotTheme theme) {
    return Stack(
      children: [
        // Message history list
        MessageList(
          messages: provider.record,
          showTypingIndicator: _isAgentTyping || provider.isProcessing,
          showTimestamps: widget.showTimestamps,
          theme: theme,
        ),
        // Current interactive node overlay (if any)
        if (provider.currentUIState != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildCurrentNode(provider, theme),
          ),
        // Error message overlay
        if (provider.errorMessage != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildErrorBanner(provider, theme),
          ),
      ],
    );
  }

  Widget _buildCurrentNode(ConferBotProvider provider, ConferBotTheme theme) {
    final uiState = provider.currentUIState;
    if (uiState == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: theme.colors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.all(theme.spacing.md),
      child: SafeArea(
        top: false,
        child: NodeRenderer(
          uiState: uiState,
          onResponse: (response) {
            provider.submitResponse(response);
          },
          theme: theme,
          primaryColor: theme.colors.primary,
        ),
      ),
    );
  }

  Widget _buildErrorBanner(ConferBotProvider provider, ConferBotTheme theme) {
    return Material(
      borderRadius: BorderRadius.circular(theme.borderRadius.md),
      color: theme.colors.error.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colors.error,
              size: 20,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                provider.errorMessage!,
                style: TextStyle(
                  color: theme.colors.error,
                  fontSize: theme.typography.fontSizeSm,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: theme.colors.error,
              onPressed: () => provider.clearError(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ConferBotProvider provider, ConferBotTheme theme) {
    // Hide input when flow is complete or when interactive node is showing
    if (provider.isFlowComplete || _isInteractiveNodeShowing(provider)) {
      return const SizedBox.shrink();
    }

    return ChatInput(
      onSend: (text) async {
        await provider.sendMessage(text);
      },
      placeholder: widget.placeholder ?? 'Type a message...',
      disabled: !provider.isConnected || provider.isProcessing,
      enableAttachments: widget.enableAttachments,
      theme: theme,
    );
  }

  bool _isInteractiveNodeShowing(ConferBotProvider provider) {
    final uiState = provider.currentUIState;
    if (uiState == null) return false;

    // These node types show their own input UI
    return uiState is TextInputUIState ||
        uiState is FileUploadUIState ||
        uiState is SingleChoiceUIState ||
        uiState is MultipleChoiceUIState ||
        uiState is ImageChoiceUIState ||
        uiState is RatingUIState ||
        uiState is DropdownUIState ||
        uiState is RangeUIState ||
        uiState is CalendarUIState ||
        uiState is QuizUIState ||
        uiState is MultipleQuestionsUIState ||
        uiState is HumanHandoverUIState;
  }

  String? _getSubtitle(ConferBotProvider provider) {
    if (provider.currentAgent != null) {
      return provider.currentAgent!.email ?? 'Live Agent';
    }
    if (!provider.isConnected) {
      return 'Reconnecting...';
    }
    if (provider.isFlowComplete) {
      return 'Conversation complete';
    }
    return null;
  }
}

// Re-export NodeUIState types for convenience
export '../core/nodes/node_ui_state.dart';
