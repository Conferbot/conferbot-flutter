import 'package:flutter/material.dart';
import '../models/agent.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import 'avatar.dart';
import 'connection_status.dart';

/// Chat header widget with title, agent info, and close button
class ChatHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Agent? agent;
  final VoidCallback? onClose;
  final bool showConnectionStatus;
  final ConferBotTheme? theme;

  const ChatHeader({
    super.key,
    this.title,
    this.subtitle,
    this.agent,
    this.onClose,
    this.showConnectionStatus = true,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;
    final displayTitle = agent?.name ?? title ?? 'Chat';
    final displaySubtitle = agent?.email ?? subtitle;

    return Container(
      height: effectiveTheme.layout.headerHeight,
      padding: EdgeInsets.symmetric(
        horizontal: effectiveTheme.spacing.md,
      ),
      decoration: BoxDecoration(
        color: effectiveTheme.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: effectiveTheme.colors.border,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (agent != null) ...[
              ConferBotAvatar(
                imageUrl: agent!.avatar,
                name: agent!.name,
                size: 40,
                theme: effectiveTheme,
              ),
              SizedBox(width: effectiveTheme.spacing.md),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: effectiveTheme.typography.fontSizeLg,
                      fontWeight: effectiveTheme.typography.fontWeightSemiBold,
                      color: effectiveTheme.colors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (displaySubtitle != null) ...[
                    SizedBox(height: 2),
                    Text(
                      displaySubtitle,
                      style: TextStyle(
                        fontSize: effectiveTheme.typography.fontSizeXs,
                        color: effectiveTheme.colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (showConnectionStatus && displaySubtitle == null) ...[
                    SizedBox(height: 2),
                    ConnectionStatus(
                      variant: ConnectionStatusVariant.text,
                      theme: effectiveTheme,
                    ),
                  ],
                ],
              ),
            ),
            if (onClose != null) ...[
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close,
                  color: effectiveTheme.colors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
