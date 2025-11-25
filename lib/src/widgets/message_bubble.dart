import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import 'avatar.dart';

/// Message bubble widget displaying individual messages
class MessageBubble extends StatelessWidget {
  final RecordItem message;
  final bool showAvatar;
  final bool showTimestamp;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ConferBotTheme? theme;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.showTimestamp = false,
    this.onTap,
    this.onLongPress,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;
    final isUser = message.type == MessageType.userMessage;
    final isAgent = message.type == MessageType.agentMessage;
    final isSystem = message.type == MessageType.systemMessage;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: effectiveTheme.spacing.md,
          vertical: effectiveTheme.spacing.xs,
        ),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser && !isSystem && showAvatar) ...[
              _buildAvatar(effectiveTheme),
              SizedBox(width: effectiveTheme.spacing.sm),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: effectiveTheme.layout.maxBubbleWidth,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: effectiveTheme.spacing.md,
                  vertical: effectiveTheme.spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: _getBubbleColor(effectiveTheme),
                  borderRadius: BorderRadius.circular(
                    effectiveTheme.borderRadius.lg,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAgent && message is AgentMessageRecord) ...[
                      Text(
                        (message as AgentMessageRecord).agentDetails.name,
                        style: TextStyle(
                          fontSize: effectiveTheme.typography.fontSizeXs,
                          fontWeight: effectiveTheme.typography.fontWeightBold,
                          color: _getTextColor(effectiveTheme).withOpacity(0.8),
                        ),
                      ),
                      SizedBox(height: effectiveTheme.spacing.xs),
                    ],
                    _buildMessageContent(effectiveTheme),
                    if (showTimestamp) ...[
                      SizedBox(height: effectiveTheme.spacing.xs),
                      Text(
                        _formatTime(message.time),
                        style: TextStyle(
                          fontSize: effectiveTheme.typography.fontSizeXs,
                          color: _getTextColor(effectiveTheme).withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isUser && showAvatar) ...[
              SizedBox(width: effectiveTheme.spacing.sm),
              SizedBox(width: effectiveTheme.layout.avatarSize),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ConferBotTheme theme) {
    String? avatarUrl;
    String? name;

    if (message is AgentMessageRecord) {
      final agentMessage = message as AgentMessageRecord;
      avatarUrl = agentMessage.agentDetails.avatar;
      name = agentMessage.agentDetails.name;
    }

    return ConferBotAvatar(
      imageUrl: avatarUrl,
      name: name ?? 'Bot',
      size: theme.layout.avatarSize,
      theme: theme,
    );
  }

  Widget _buildMessageContent(ConferBotTheme theme) {
    String? text;

    if (message is UserMessageRecord) {
      text = (message as UserMessageRecord).text;
    } else if (message is BotMessageRecord) {
      text = (message as BotMessageRecord).text;
    } else if (message is AgentMessageRecord) {
      text = (message as AgentMessageRecord).text;
    } else if (message is SystemMessageRecord) {
      text = (message as SystemMessageRecord).text;
    }

    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: theme.typography.fontSizeMd,
        color: _getTextColor(theme),
        height: theme.typography.lineHeightNormal,
      ),
    );
  }

  Color _getBubbleColor(ConferBotTheme theme) {
    switch (message.type) {
      case MessageType.userMessage:
        return theme.colors.userBubble;
      case MessageType.agentMessage:
      case MessageType.agentMessageFile:
      case MessageType.agentMessageAudio:
        return theme.colors.agentBubble;
      case MessageType.systemMessage:
        return theme.colors.systemBubble;
      default:
        return theme.colors.botBubble;
    }
  }

  Color _getTextColor(ConferBotTheme theme) {
    switch (message.type) {
      case MessageType.userMessage:
        return theme.colors.userBubbleText;
      case MessageType.agentMessage:
      case MessageType.agentMessageFile:
      case MessageType.agentMessageAudio:
        return theme.colors.agentBubbleText;
      case MessageType.systemMessage:
        return theme.colors.systemBubbleText;
      default:
        return theme.colors.botBubbleText;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return DateFormat.jm().format(time);
    }
    return DateFormat.MMMd().add_jm().format(time);
  }
}
