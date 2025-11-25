import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import 'message_bubble.dart';
import 'typing_indicator.dart';
import 'empty_state.dart';

/// Scrollable message list widget with virtualization
class MessageList extends StatefulWidget {
  final List<RecordItem> messages;
  final bool showTypingIndicator;
  final bool showTimestamps;
  final bool showAvatars;
  final Widget? emptyWidget;
  final ConferBotTheme? theme;

  const MessageList({
    super.key,
    required this.messages,
    this.showTypingIndicator = false,
    this.showTimestamps = false,
    this.showAvatars = true,
    this.emptyWidget,
    this.theme,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    if (widget.messages.isEmpty && !widget.showTypingIndicator) {
      return widget.emptyWidget ?? EmptyState(theme: effectiveTheme);
    }

    return Container(
      color: effectiveTheme.colors.background,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          vertical: effectiveTheme.spacing.md,
        ),
        itemCount: widget.messages.length + (widget.showTypingIndicator ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == widget.messages.length) {
            // Typing indicator
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: effectiveTheme.spacing.md,
                vertical: effectiveTheme.spacing.sm,
              ),
              child: Row(
                children: [
                  TypingIndicator(
                    visible: widget.showTypingIndicator,
                    theme: effectiveTheme,
                  ),
                  SizedBox(width: effectiveTheme.spacing.sm),
                  Text(
                    'Agent is typing...',
                    style: TextStyle(
                      fontSize: effectiveTheme.typography.fontSizeSm,
                      color: effectiveTheme.colors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          }

          final message = widget.messages[index];
          return MessageBubble(
            message: message,
            showAvatar: widget.showAvatars,
            showTimestamp: widget.showTimestamps,
            theme: effectiveTheme,
          );
        },
      ),
    );
  }
}
