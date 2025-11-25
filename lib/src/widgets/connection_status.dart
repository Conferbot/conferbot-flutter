import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conferbot_provider.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';

/// Connection status indicator widget
class ConnectionStatus extends StatelessWidget {
  final ConnectionStatusVariant variant;
  final String? onlineLabel;
  final String? offlineLabel;
  final bool showWhenOnline;
  final ConferBotTheme? theme;

  const ConnectionStatus({
    super.key,
    this.variant = ConnectionStatusVariant.badge,
    this.onlineLabel,
    this.offlineLabel,
    this.showWhenOnline = false,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;
    final provider = context.watch<ConferBotProvider>();
    final isConnected = provider.isConnected;

    if (isConnected && !showWhenOnline) {
      return const SizedBox.shrink();
    }

    switch (variant) {
      case ConnectionStatusVariant.dot:
        return _buildDot(effectiveTheme, isConnected);
      case ConnectionStatusVariant.badge:
        return _buildBadge(effectiveTheme, isConnected);
      case ConnectionStatusVariant.text:
        return _buildText(effectiveTheme, isConnected);
    }
  }

  Widget _buildDot(ConferBotTheme theme, bool isConnected) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isConnected ? theme.colors.online : theme.colors.offline,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildBadge(ConferBotTheme theme, bool isConnected) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: isConnected
            ? theme.colors.online.withOpacity(0.1)
            : theme.colors.offline.withOpacity(0.1),
        borderRadius: BorderRadius.circular(theme.borderRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isConnected ? theme.colors.online : theme.colors.offline,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: theme.spacing.xs),
          Text(
            isConnected
                ? (onlineLabel ?? 'Online')
                : (offlineLabel ?? 'Offline'),
            style: TextStyle(
              fontSize: theme.typography.fontSizeXs,
              color: isConnected ? theme.colors.online : theme.colors.offline,
              fontWeight: theme.typography.fontWeightMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildText(ConferBotTheme theme, bool isConnected) {
    return Text(
      isConnected ? (onlineLabel ?? 'Online') : (offlineLabel ?? 'Offline'),
      style: TextStyle(
        fontSize: theme.typography.fontSizeXs,
        color: theme.colors.textSecondary,
      ),
    );
  }
}

enum ConnectionStatusVariant {
  dot,
  badge,
  text,
}
