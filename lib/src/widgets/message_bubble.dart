import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'agent_reply.dart';
import 'media/audio_player_widget.dart';
import 'media/video_player_widget.dart';
import 'package:flutter_html/flutter_html.dart';
import '../core/live_chat/live_chat.dart';
import '../core/customization/customizations.dart';
import 'bubble_outline.dart';
import '../config/constants.dart';
import '../models/message.dart';
import '../models/queued_message.dart';
import '../providers/conferbot_provider.dart';
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

    // Standalone image message (welcome GIF, image-node) - rendered as a
    // rounded image below the text bubble like the web widget, indented
    // past the avatar column
    if (message is BotMessageRecord) {
      final imageUrl =
          (message as BotMessageRecord).nodeData?['imageUrl']?.toString();
      if (imageUrl != null && imageUrl.isNotEmpty) {
        return Padding(
          padding: EdgeInsets.only(
            left: effectiveTheme.spacing.chatContentPadding +
                effectiveTheme.layout.avatarSize +
                10,
            right: effectiveTheme.spacing.chatContentPadding,
            top: effectiveTheme.spacing.xs,
            bottom: effectiveTheme.spacing.xs,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: effectiveTheme.layout.maxBubbleWidth * 0.75,
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.fitWidth,
                  // The image step moves on once its picture is in (or failed),
                  // as the web does, rather than at the 4 s cap.
                  frameBuilder: (context, child, frame, _) {
                    if (frame != null) _mediaSettled(context);
                    return child;
                  },
                  errorBuilder: (context, __, ___) {
                    _mediaSettled(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
      }
    }

    // A flow step's video, audio, file, HTML or link line (video-node,
    // audio-node, file-node, html-node, user-redirect-node).
    if (message is BotMessageRecord) {
      final media = _buildFlowMedia(context, effectiveTheme, (message as BotMessageRecord).nodeData);
      if (media != null) return media;
    }

    // A file in a live chat, from the agent or the visitor: the image itself,
    // or a row with its name; an agent's voice note plays here.
    if (message is AgentMessageFileRecord || message is UserLiveMessageFileRecord || message is AgentMessageAudioRecord) {
      return _buildFileMessage(context, effectiveTheme);
    }

    // A live chat's own line, centred as on the web (cb-sys): "<name>
    // joined the chat", "Connecting you with the team…" with its dots until
    // it settles, "You left the queue", and the note after an AI handover.
    final system = message;
    if (system is SystemMessageRecord && system.kind != null) {
      return LiveChatLine(line: system, theme: effectiveTheme);
    }

    // An agent's article, quick replies or card (agent_reply.dart)
    if (message is AgentRichMessageRecord) {
      return RichAgentMessage(
        message: message as AgentRichMessageRecord,
        theme: effectiveTheme,
        avatar: _buildAvatar(context, effectiveTheme),
      );
    }

    // Include both user-message and user-input-response as user messages
    final isUser = message.type == MessageType.userMessage ||
        message.type == MessageType.userInputResponse;
    final isAgent = message.type == MessageType.agentMessage;
    final isSystem = message.type == MessageType.systemMessage;

    // The web's bubble corners (18/18/18 with a 6 tail, or the owner's
    // radius) once the bot's settings arrived; the theme's before that.
    final look = _look(context);
    final r = effectiveTheme.borderRadius.bubble;
    final rSmall = effectiveTheme.borderRadius.bubbleSmall;
    final corners = look == null ? null : (isUser ? look.userBubble : look.botBubble);
    final bubbleRadius = corners != null
        ? BorderRadius.only(
            topLeft: Radius.circular(corners.topLeft),
            topRight: Radius.circular(corners.topRight),
            bottomLeft: Radius.circular(corners.bottomLeft),
            bottomRight: Radius.circular(corners.bottomRight),
          )
        : isUser
        ? BorderRadius.only(
            topLeft: Radius.circular(r),
            topRight: Radius.circular(r),
            bottomLeft: Radius.circular(r),
            bottomRight: Radius.circular(rSmall),
          )
        : BorderRadius.only(
            topLeft: Radius.circular(r),
            topRight: Radius.circular(r),
            bottomLeft: Radius.circular(rSmall),
            bottomRight: Radius.circular(r),
          );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: effectiveTheme.spacing.chatContentPadding,
          vertical: effectiveTheme.spacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser && !isSystem && showAvatar && look?.hideAvatar != true) ...[
              _buildAvatar(context, effectiveTheme),
              const SizedBox(width: 10),
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
                      horizontal: effectiveTheme.spacing.bubblePaddingH,
                      vertical: effectiveTheme.spacing.bubblePaddingV,
                    ),
                    decoration: BoxDecoration(
                      color: _getBubbleColor(effectiveTheme),
                      borderRadius: bubbleRadius,
                      border: bubbleOutline(look),
                      boxShadow: [effectiveTheme.shadows.sm],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isAgent && message is AgentMessageRecord) ...[
                          Text(
                            (message as AgentMessageRecord).edited
                                ? '${(message as AgentMessageRecord).agentDetails.name} \u00b7 Edited'
                                : (message as AgentMessageRecord).agentDetails.name,
                            style: TextStyle(
                              fontSize: effectiveTheme.typography.fontSizeXs,
                              fontWeight:
                                  effectiveTheme.typography.fontWeightBold,
                              // The bubble's own text colour: the primary
                              // colour is often the bubble's, and vanished.
                              color: _getTextColor(effectiveTheme).withOpacity(0.85),
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
            // Web widget parity: user messages sit flush right, no
            // phantom avatar slot is reserved on the visitor side.
          ],
        ),
            // An AI reply's sources, buttons, cards and "Helpful?" - below
            // the bubble, past the avatar, so the avatar stays by the bubble.
            if (message is AgentMessageRecord)
              Padding(
                padding: EdgeInsets.only(left: showAvatar ? effectiveTheme.layout.avatarSize + 10 : 0),
                child: AgentReplyExtras(message: message as AgentMessageRecord, theme: effectiveTheme),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileMessage(BuildContext context, ConferBotTheme theme) {
    final m = message;
    final isUser = m is UserLiveMessageFileRecord;
    final origin = Uri.tryParse(ConferBotEndpoints.apiBaseUrl)?.origin ?? '';
    final raw = m is AgentMessageFileRecord
        ? m.file
        : m is UserLiveMessageFileRecord
            ? m.url
            : (m as AgentMessageAudioRecord).url;
    final url = LiveChat.resolveMediaUrl(raw, origin);
    if (url == null) return const SizedBox.shrink();
    final mime = m is UserLiveMessageFileRecord ? m.mimeType : null;
    final name = LiveChat.fileNameOf(m is UserLiveMessageFileRecord ? m.fileName : null, url);
    final textColor = _getTextColor(theme);
    void open() => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

    final Widget content;
    if (m is AgentMessageAudioRecord) {
      content = SizedBox(
        width: theme.layout.maxBubbleWidth,
        child: AudioPlayerWidget(audioUrl: url, theme: theme, config: const AudioPlayerConfig(compactMode: true)),
      );
    } else if (LiveChat.isImageUrl(url, mime)) {
      content = GestureDetector(
        onTap: open,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: theme.layout.maxBubbleWidth * 0.8, maxHeight: 240),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              semanticLabel: name,
              errorBuilder: (_, __, ___) => _fileRow(theme, name, textColor, open),
            ),
          ),
        ),
      );
    } else {
      content = _fileRow(theme, name, textColor, open);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.chatContentPadding, vertical: theme.spacing.xs),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser && showAvatar) ...[_buildAvatar(context, theme), const SizedBox(width: 10)],
          Flexible(child: content),
        ],
      ),
    );
  }

  /// The step whose media this is tells the flow it settled.
  void _mediaSettled(BuildContext context) {
    final nodeId = (message as BotMessageRecord).nodeData?['mediaNodeId']?.toString();
    if (nodeId == null) return;
    try {
      Provider.of<ConferBotProvider>(context, listen: false).flowEngine.mediaSettled(nodeId);
    } catch (_) {
      // No provider above (a bubble drawn on its own).
    }
  }

  /// A flow step's media line, indented past the avatar like the image.
  Widget? _buildFlowMedia(BuildContext context, ConferBotTheme theme, Map<String, dynamic>? data) {
    if (data == null) return null;
    final video = data['videoUrl']?.toString() ?? '';
    final audio = data['audioUrl']?.toString() ?? '';
    final file = data['fileUrl']?.toString() ?? '';
    final html = data['html']?.toString() ?? '';
    final link = data['linkUrl']?.toString() ?? '';
    Widget? content;
    if (video.isNotEmpty) {
      content = SizedBox(
        width: theme.layout.maxBubbleWidth,
        child: VideoPlayerWidget(
          videoUrl: video,
          theme: theme,
          onError: (_) => _mediaSettled(context),
        ),
      );
      // The player is up: the step need not wait for the whole video.
      WidgetsBinding.instance.addPostFrameCallback((_) => _mediaSettled(context));
    } else if (audio.isNotEmpty) {
      content = SizedBox(
        width: theme.layout.maxBubbleWidth,
        child: AudioPlayerWidget(audioUrl: audio, theme: theme, config: const AudioPlayerConfig(compactMode: true)),
      );
    } else if (file.isNotEmpty) {
      final name = data['fileName']?.toString() ?? LiveChat.fileNameOf(null, file);
      content = _fileRow(theme, name, _getTextColor(theme), () => launchUrl(Uri.parse(file), mode: LaunchMode.externalApplication));
    } else if (html.isNotEmpty) {
      content = Container(
        constraints: BoxConstraints(maxWidth: theme.layout.maxBubbleWidth),
        padding: EdgeInsets.all(theme.spacing.md),
        decoration: BoxDecoration(
          color: _getBaseBubbleColor(theme),
          borderRadius: BorderRadius.circular(theme.borderRadius.bubble),
        ),
        child: Html(
          data: html,
          onLinkTap: (url, _, __) {
            if (url != null) launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          },
          style: {
            'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero, color: _getTextColor(theme)),
          },
        ),
      );
    } else if (link.isNotEmpty) {
      final label = data['linkLabel']?.toString() ?? '';
      content = Material(
        color: _getBaseBubbleColor(theme),
        borderRadius: BorderRadius.circular(theme.borderRadius.bubble),
        child: InkWell(
          borderRadius: BorderRadius.circular(theme.borderRadius.bubble),
          onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new, size: 18, color: _getTextColor(theme)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label.isNotEmpty ? label : link,
                    style: TextStyle(color: _getTextColor(theme), decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (content == null) return null;
    return Padding(
      padding: EdgeInsets.only(
        left: theme.spacing.chatContentPadding + theme.layout.avatarSize + 10,
        right: theme.spacing.chatContentPadding,
        top: theme.spacing.xs,
        bottom: theme.spacing.xs,
      ),
      child: Align(alignment: Alignment.centerLeft, child: content),
    );
  }

  Widget _fileRow(ConferBotTheme theme, String name, Color textColor, VoidCallback onTap) {
    return Material(
      color: _getBaseBubbleColor(theme),
      borderRadius: BorderRadius.circular(theme.borderRadius.bubble),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.borderRadius.bubble),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.bubblePaddingH, vertical: theme.spacing.bubblePaddingV),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file_outlined, size: 20, color: textColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textColor, fontSize: theme.typography.messageSize, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
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
                fontSize: theme.typography.timestampSize,
                color: theme.colors.textSecondary.withOpacity(0.6),
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

  Widget _buildAvatar(BuildContext context, ConferBotTheme theme) {
    String? imageUrl;
    String? name;

    if (message is AgentMessageRecord ||
        message is AgentRichMessageRecord ||
        message is AgentMessageFileRecord ||
        message is AgentMessageAudioRecord) {
      final m = message;
      final AgentDetails? details = m is AgentMessageRecord
          ? m.agentDetails
          : m is AgentRichMessageRecord
              ? m.agentDetails
              : m is AgentMessageFileRecord
                  ? m.agentDetails
                  : (m as AgentMessageAudioRecord).agentDetails;
      name = details?.name;
      imageUrl = details?.avatar;
      // The AI agent is the bot itself: its avatar when it has none.
      if (imageUrl == null && (details?.isAIAgent ?? false)) {
        try {
          imageUrl = Provider.of<ConferBotProvider>(context, listen: false).botAvatarUrl;
        } catch (_) {}
      }
    } else {
      // Bot message — use avatar from server customizations
      try {
        final provider = Provider.of<ConferBotProvider>(context, listen: false);
        imageUrl = provider.serverCustomizations != null ? provider.customizations.avatar : provider.botAvatarUrl;
        name = provider.botName;
      } catch (_) {
        // Provider not available (e.g. standalone usage)
      }
    }

    final look = _look(context);
    return ConferBotAvatar(
      imageUrl: imageUrl,
      name: name ?? 'Bot',
      size: look?.avatarSize ?? theme.layout.avatarSize,
      shape: switch (look?.avatarShape) {
        'square' => AvatarShape.square,
        'rounded' => AvatarShape.rounded,
        _ => AvatarShape.circle,
      },
      theme: theme,
    );
  }

  /// The bot's settings as the web applies them, once they arrived (core/customization).
  ResolvedCustomizations? _look(BuildContext context) {
    try {
      final provider = Provider.of<ConferBotProvider>(context, listen: false);
      return provider.serverCustomizations != null ? provider.customizations : null;
    } catch (_) {
      return null;
    }
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
      final agentMessage = message as AgentMessageRecord;
      if (agentMessage.deleted) {
        return Text(
          'This message was deleted',
          style: TextStyle(
            fontSize: theme.typography.messageSize,
            fontStyle: FontStyle.italic,
            color: _getTextColor(theme).withOpacity(0.7),
          ),
        );
      }
      if (agentMessage.translation != null) {
        return _TranslatedText(
          message: agentMessage,
          textColor: _getTextColor(theme),
          builder: (t) => MarkdownDetector.containsMarkdown(t) && enableMarkdown
              ? _buildMarkdownContent(context, theme, t)
              : Text(t, style: TextStyle(fontSize: theme.typography.messageSize, color: _getTextColor(theme), height: theme.typography.lineHeightNormal)),
        );
      }
      text = agentMessage.text;
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
        fontSize: theme.typography.messageSize,
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

/// An agent's message translated for the visitor: "See original" shows what
/// the agent wrote, in the visitor's language.
class _TranslatedText extends StatefulWidget {
  final AgentMessageRecord message;
  final Color textColor;
  final Widget Function(String text) builder;
  const _TranslatedText({
    required this.message,
    required this.textColor,
    required this.builder,
  });

  @override
  State<_TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<_TranslatedText> {
  bool _original = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.message.translation!;
    final labels = LiveChat.translationLabels(t.to);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.builder(_original ? t.original : widget.message.text),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _original = !_original),
          child: Text(
            _original ? labels[1] : labels[0],
            style: TextStyle(
              fontSize: 12,
              color: widget.textColor.withOpacity(0.75),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

/// A live chat line in the conversation (web cb-sys): centred quiet text,
/// the typing dots while a Connecting line waits (they stop once it
/// settles), and a smaller note under a join after an AI handover.
class LiveChatLine extends StatelessWidget {
  final SystemMessageRecord line;
  final ConferBotTheme theme;
  const LiveChatLine({super.key, required this.line, required this.theme});

  @override
  Widget build(BuildContext context) {
    final color = theme.colors.textSecondary;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.chatContentPadding + 12, vertical: 8),
      child: Semantics(
        liveRegion: line.handover,
        label: line.text,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (line.handoverPending) _PendingDots(color: color),
              Text(
                line.text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w500),
              ),
              if (line.note != null && line.note!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    line.note!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: color.withOpacity(0.8)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three dots of a pending Connecting line (the web's .cb-sys__typing),
/// fading in turn on one loop.
class _PendingDots extends StatefulWidget {
  final Color color;
  const _PendingDots({required this.color});

  @override
  State<_PendingDots> createState() => _PendingDotsState();
}

class _PendingDotsState extends State<_PendingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  double _opacity(int i, double v) {
    final peak = (i + 1) / 4;
    final d = (v - peak).abs() * 4;
    return d >= 1 ? 0.3 : 1 - 0.7 * d;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('cb-handover-dots'),
      padding: const EdgeInsets.only(bottom: 4),
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(color: widget.color.withOpacity(_opacity(i, _t.value)), shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
