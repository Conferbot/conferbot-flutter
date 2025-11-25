import 'package:flutter/material.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';

/// Empty state widget for when there are no messages
class EmptyState extends StatelessWidget {
  final String? title;
  final String? message;
  final Widget? icon;
  final Widget? action;
  final ConferBotTheme? theme;

  const EmptyState({
    super.key,
    this.title,
    this.message,
    this.icon,
    this.action,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(effectiveTheme.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              SizedBox(height: effectiveTheme.spacing.lg),
            ] else ...[
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: effectiveTheme.colors.textSecondary.withOpacity(0.5),
              ),
              SizedBox(height: effectiveTheme.spacing.lg),
            ],
            Text(
              title ?? 'No messages yet',
              style: TextStyle(
                fontSize: effectiveTheme.typography.fontSizeLg,
                fontWeight: effectiveTheme.typography.fontWeightSemiBold,
                color: effectiveTheme.colors.text,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              SizedBox(height: effectiveTheme.spacing.sm),
              Text(
                message!,
                style: TextStyle(
                  fontSize: effectiveTheme.typography.fontSizeMd,
                  color: effectiveTheme.colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: effectiveTheme.spacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
