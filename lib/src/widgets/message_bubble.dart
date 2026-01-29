import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../models/queued_message.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import 'avatar.dart';
import 'markdown/markdown_message.dart';
import 'markdown/markdown_theme.dart';
import 'markdown/link_handler.dart';

/// Message bubble widget displaying individual messages
/// with delivery status indicator for offline support
/// and automatic markdown rendering detection
class MessageBubble extends StatelessWidget {
  final RecordItem message;
  final bool showAvatar;
  final bool showTimestamp;
  final bool showDeliveryStatus;
  final MessageDeliveryStatus? deliveryStatus;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;
  final ConferBotTheme? theme;

  /// Whether to enable markdown rendering
  final bool enableMarkdown;

  /// Whether to auto-detect markdown content (only render as markdown if detected)
  final bool autoDetectMarkdown;

  /// Custom link handler for markdown links
  final MarkdownLinkHandler? linkHandler;

  /// Callback when a link in the message is tapped
  final void Function(String url)? onLinkTap;

  /// Callback when code is copied from a code block
  final void Function(String code)? onCodeCopied;

  /// Whether to show copy button on code blocks
  final bool showCodeCopyButton;

  /// Whether to enable text selection
  final bool selectable;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.showTimestamp = false,
    this.showDeliveryStatus = true,
    this.deliveryStatus,
    this.onTap,
    this.onLongPress,
    this.onRetry,
    this.theme,
    this.enableMarkdown = true,
    this.autoDetectMarkdown = true,
    this.linkHandler,
    this.onLinkTap,
    this.onCodeCopied,
    this.showCodeCopyButton = true,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;
    // Include both user-message and user-input-response as user messages
    final isUser = message.type == MessageType.userMessage ||
        message.type == MessageType.userInputResponse;
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
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
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
                              fontWeight:
                                  effectiveTheme.typography.fontWeightBold,
                              color:
                                  _getTextColor(effectiveTheme).withOpacity(0.8),
                            ),
                          ),
                          SizedBox(height: effectiveTheme.spacing.xs),
                        ],
                        _buildMessageContent(context, effectiveTheme),
                      ],
                    ),
                  ),
                  // Timestamp and delivery status row
                  if (showTimestamp || (isUser && showDeliveryStatus)) ...[
                    SizedBox(height: effectiveTheme.spacing.xs / 2),
                    _buildStatusRow(effectiveTheme, isUser),
                  ],
                ],
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

  Widget _buildStatusRow(ConferBotTheme theme, bool isUser) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (showTimestamp) ...[
            Text(
              _formatTime(message.time),
              style: TextStyle(
                fontSize: theme.typography.fontSizeXs,
                color: theme.colors.textSecondary,
              ),
            ),
          ],
          if (showTimestamp && isUser && showDeliveryStatus)
            SizedBox(width: theme.spacing.xs),
          if (isUser && showDeliveryStatus)
            _buildDeliveryStatusIndicator(theme),
        ],
      ),
    );
  }

  Widget _buildDeliveryStatusIndicator(ConferBotTheme theme) {
    final status = deliveryStatus ?? MessageDeliveryStatus.delivered;

    switch (status) {
      case MessageDeliveryStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: theme.colors.textSecondary,
          ),
        );

      case MessageDeliveryStatus.queued:
        return Tooltip(
          message: 'Waiting to send',
          child: Icon(
            Icons.schedule,
            size: 14,
            color: theme.colors.warning,
          ),
        );

      case MessageDeliveryStatus.sent:
        return Icon(
          Icons.check,
          size: 14,
          color: theme.colors.textSecondary,
        );

      case MessageDeliveryStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: theme.colors.success,
        );

      case MessageDeliveryStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 14,
                color: theme.colors.error,
              ),
              if (onRetry != null) ...[
                SizedBox(width: theme.spacing.xs / 2),
                Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: theme.typography.fontSizeXs,
                    color: theme.colors.error,
                    fontWeight: theme.typography.fontWeightMedium,
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }

  Widget _buildAvatar(ConferBotTheme theme) {
    String? name;

    if (message is AgentMessageRecord) {
      final agentMessage = message as AgentMessageRecord;
      // AgentDetails from embed-server doesn't include avatar
      name = agentMessage.agentDetails.name;
    }

    return ConferBotAvatar(
      imageUrl: null, // Avatar not available from agentDetails
      name: name ?? 'Bot',
      size: theme.layout.avatarSize,
      theme: theme,
    );
  }

  Widget _buildMessageContent(BuildContext context, ConferBotTheme theme) {
    String? text;

    if (message is UserMessageRecord) {
      text = (message as UserMessageRecord).text;
    } else if (message is UserInputResponseRecord) {
      text = (message as UserInputResponseRecord).text;
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

    // Determine if markdown rendering should be used
    final shouldRenderMarkdown = enableMarkdown &&
        (!autoDetectMarkdown || MarkdownDetector.containsMarkdown(text));

    if (shouldRenderMarkdown) {
      return _buildMarkdownContent(context, theme, text);
    }

    // Plain text rendering
    return Text(
      text,
      style: TextStyle(
        fontSize: theme.typography.fontSizeMd,
        color: _getTextColor(theme),
        height: theme.typography.lineHeightNormal,
      ),
    );
  }

  Widget _buildMarkdownContent(
    BuildContext context,
    ConferBotTheme theme,
    String text,
  ) {
    // Get appropriate markdown theme based on message type
    final markdownTheme = _getMarkdownTheme(theme);

    // Create effective link handler
    final effectiveLinkHandler = linkHandler ?? MarkdownLinkHandler(
      onLinkTapped: onLinkTap != null
          ? (url, type) => onLinkTap!(url)
          : null,
    );

    if (selectable) {
      return SelectableMarkdownMessage(
        content: text,
        theme: theme,
        markdownTheme: markdownTheme,
        linkHandler: effectiveLinkHandler,
      );
    }

    return MarkdownMessage(
      content: text,
      theme: theme,
      markdownTheme: markdownTheme,
      linkHandler: effectiveLinkHandler,
      showCodeCopyButton: showCodeCopyButton,
      onCodeCopied: onCodeCopied,
      selectable: selectable,
    );
  }

  MarkdownThemeConfig _getMarkdownTheme(ConferBotTheme theme) {
    switch (message.type) {
      case MessageType.userMessage:
      case MessageType.userInputResponse:
        return MarkdownThemeConfig.fromUserTheme(theme);
      case MessageType.agentMessage:
      case MessageType.agentMessageFile:
      case MessageType.agentMessageAudio:
        return MarkdownThemeConfig.fromAgentTheme(theme);
      case MessageType.systemMessage:
        return MarkdownThemeConfig.fromSystemTheme(theme);
      default:
        return MarkdownThemeConfig.fromBotTheme(theme);
    }
  }

  Color _getBubbleColor(ConferBotTheme theme) {
    // Dim bubble color for pending messages
    final baseColor = _getBaseBubbleColor(theme);
    final status = deliveryStatus ?? MessageDeliveryStatus.delivered;

    if (status == MessageDeliveryStatus.queued ||
        status == MessageDeliveryStatus.sending) {
      return baseColor.withOpacity(0.7);
    }

    if (status == MessageDeliveryStatus.failed) {
      return baseColor.withOpacity(0.5);
    }

    return baseColor;
  }

  Color _getBaseBubbleColor(ConferBotTheme theme) {
    switch (message.type) {
      case MessageType.userMessage:
      case MessageType.userInputResponse:
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
      case MessageType.userInputResponse:
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

/// Compact delivery status indicator for use in message lists
class DeliveryStatusIndicator extends StatelessWidget {
  final MessageDeliveryStatus status;
  final VoidCallback? onRetry;
  final ConferBotTheme? theme;
  final double size;

  const DeliveryStatusIndicator({
    super.key,
    required this.status,
    this.onRetry,
    this.theme,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    switch (status) {
      case MessageDeliveryStatus.sending:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: effectiveTheme.colors.textSecondary,
          ),
        );

      case MessageDeliveryStatus.queued:
        return Icon(
          Icons.schedule,
          size: size,
          color: effectiveTheme.colors.warning,
        );

      case MessageDeliveryStatus.sent:
        return Icon(
          Icons.check,
          size: size,
          color: effectiveTheme.colors.textSecondary,
        );

      case MessageDeliveryStatus.delivered:
        return Icon(
          Icons.done_all,
          size: size,
          color: effectiveTheme.colors.success,
        );

      case MessageDeliveryStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: Icon(
            Icons.error_outline,
            size: size,
            color: effectiveTheme.colors.error,
          ),
        );
    }
  }
}

/// A standalone rich text message widget that can be used independently
/// of the message bubble for custom layouts
class RichTextMessage extends StatelessWidget {
  /// The text content to render
  final String text;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Custom markdown theme
  final MarkdownThemeConfig? markdownTheme;

  /// Whether to enable markdown rendering
  final bool enableMarkdown;

  /// Whether to auto-detect markdown content
  final bool autoDetectMarkdown;

  /// Custom link handler
  final MarkdownLinkHandler? linkHandler;

  /// Text style for plain text rendering
  final TextStyle? textStyle;

  /// Whether text should be selectable
  final bool selectable;

  /// Callback when a link is tapped
  final void Function(String url)? onLinkTap;

  /// Callback when code is copied
  final void Function(String code)? onCodeCopied;

  const RichTextMessage({
    super.key,
    required this.text,
    this.theme,
    this.markdownTheme,
    this.enableMarkdown = true,
    this.autoDetectMarkdown = true,
    this.linkHandler,
    this.textStyle,
    this.selectable = false,
    this.onLinkTap,
    this.onCodeCopied,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine if markdown rendering should be used
    final shouldRenderMarkdown = enableMarkdown &&
        (!autoDetectMarkdown || MarkdownDetector.containsMarkdown(text));

    if (shouldRenderMarkdown) {
      final effectiveMarkdownTheme = markdownTheme ??
          MarkdownThemeConfig.fromBotTheme(effectiveTheme);

      final effectiveLinkHandler = linkHandler ?? MarkdownLinkHandler(
        onLinkTapped: onLinkTap != null
            ? (url, type) => onLinkTap!(url)
            : null,
      );

      return MarkdownMessage(
        content: text,
        theme: effectiveTheme,
        markdownTheme: effectiveMarkdownTheme,
        linkHandler: effectiveLinkHandler,
        selectable: selectable,
        onCodeCopied: onCodeCopied,
      );
    }

    // Plain text rendering
    final effectiveTextStyle = textStyle ?? TextStyle(
      fontSize: effectiveTheme.typography.fontSizeMd,
      color: effectiveTheme.colors.text,
      height: effectiveTheme.typography.lineHeightNormal,
    );

    if (selectable) {
      return SelectableText(
        text,
        style: effectiveTextStyle,
      );
    }

    return Text(
      text,
      style: effectiveTextStyle,
    );
  }
}
