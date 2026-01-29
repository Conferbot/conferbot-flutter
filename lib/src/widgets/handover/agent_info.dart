import 'package:flutter/material.dart';
import '../../models/agent.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';

/// Agent information display widget
/// Shows agent name, avatar, status, and typing indicator
class AgentInfoWidget extends StatelessWidget {
  /// Agent data
  final Agent agent;

  /// Whether the agent is currently typing
  final bool isTyping;

  /// Primary color for accents
  final Color primaryColor;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Size variant
  final AgentInfoSize size;

  /// Whether to show online status indicator
  final bool showOnlineStatus;

  /// Custom status text (overrides agent.status)
  final String? customStatus;

  /// Called when tapped
  final VoidCallback? onTap;

  const AgentInfoWidget({
    super.key,
    required this.agent,
    this.isTyping = false,
    required this.primaryColor,
    this.theme,
    this.size = AgentInfoSize.medium,
    this.showOnlineStatus = true,
    this.customStatus,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(_getPadding(effectiveTheme)),
        decoration: BoxDecoration(
          color: effectiveTheme.colors.surface,
          borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.lg),
          boxShadow: [effectiveTheme.shadows.sm],
        ),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(effectiveTheme),
            SizedBox(width: effectiveTheme.spacing.md),

            // Name and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  Text(
                    agent.name,
                    style: TextStyle(
                      fontSize: _getNameFontSize(effectiveTheme),
                      fontWeight: effectiveTheme.typography.fontWeightSemiBold,
                      color: effectiveTheme.colors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Status or typing indicator
                  SizedBox(height: effectiveTheme.spacing.xs / 2),
                  if (isTyping)
                    _AgentTypingIndicator(
                      theme: effectiveTheme,
                      primaryColor: primaryColor,
                    )
                  else
                    Text(
                      customStatus ?? agent.title ?? _getStatusText(),
                      style: TextStyle(
                        fontSize: _getStatusFontSize(effectiveTheme),
                        color: effectiveTheme.colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Optional right icon
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: effectiveTheme.colors.textSecondary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ConferBotTheme theme) {
    final avatarSize = _getAvatarSize();

    return Stack(
      children: [
        // Avatar image or initials
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(0.1),
            border: Border.all(
              color: primaryColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: agent.avatar != null && agent.avatar!.isNotEmpty
                ? Image.network(
                    agent.avatar!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildInitials(theme);
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildInitials(theme);
                    },
                  )
                : _buildInitials(theme),
          ),
        ),

        // Online status indicator
        if (showOnlineStatus)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: avatarSize * 0.28,
              height: avatarSize * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colors.online,
                border: Border.all(
                  color: theme.colors.surface,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colors.online.withOpacity(0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitials(ConferBotTheme theme) {
    final initials = _getInitials();
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: primaryColor,
          fontSize: _getAvatarSize() * 0.4,
          fontWeight: theme.typography.fontWeightSemiBold,
        ),
      ),
    );
  }

  String _getInitials() {
    final parts = agent.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'A';
  }

  String _getStatusText() {
    if (agent.status != null && agent.status!.isNotEmpty) {
      return agent.status!;
    }
    return 'Support Agent';
  }

  double _getAvatarSize() {
    return switch (size) {
      AgentInfoSize.small => 36.0,
      AgentInfoSize.medium => 48.0,
      AgentInfoSize.large => 64.0,
    };
  }

  double _getPadding(ConferBotTheme theme) {
    return switch (size) {
      AgentInfoSize.small => theme.spacing.sm,
      AgentInfoSize.medium => theme.spacing.md,
      AgentInfoSize.large => theme.spacing.lg,
    };
  }

  double _getNameFontSize(ConferBotTheme theme) {
    return switch (size) {
      AgentInfoSize.small => theme.typography.fontSizeSm,
      AgentInfoSize.medium => theme.typography.fontSizeMd,
      AgentInfoSize.large => theme.typography.fontSizeLg,
    };
  }

  double _getStatusFontSize(ConferBotTheme theme) {
    return switch (size) {
      AgentInfoSize.small => theme.typography.fontSizeXs,
      AgentInfoSize.medium => theme.typography.fontSizeSm,
      AgentInfoSize.large => theme.typography.fontSizeMd,
    };
  }
}

/// Size variants for AgentInfoWidget
enum AgentInfoSize {
  small,
  medium,
  large,
}

/// Animated typing indicator for agent
class _AgentTypingIndicator extends StatefulWidget {
  final ConferBotTheme theme;
  final Color primaryColor;

  const _AgentTypingIndicator({
    required this.theme,
    required this.primaryColor,
  });

  @override
  State<_AgentTypingIndicator> createState() => _AgentTypingIndicatorState();
}

class _AgentTypingIndicatorState extends State<_AgentTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'typing',
          style: TextStyle(
            fontSize: widget.theme.typography.fontSizeSm,
            color: widget.primaryColor,
            fontStyle: FontStyle.italic,
          ),
        ),
        SizedBox(width: widget.theme.spacing.xs),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final delay = index * 0.2;
                final progress = (_controller.value + delay) % 1.0;
                final opacity = 0.3 + (0.7 * (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0));

                return Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.primaryColor.withOpacity(opacity),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

/// Compact agent info for header display
class AgentInfoHeader extends StatelessWidget {
  final Agent agent;
  final bool isTyping;
  final Color primaryColor;
  final ConferBotTheme? theme;
  final VoidCallback? onClose;
  final bool showCloseButton;

  const AgentInfoHeader({
    super.key,
    required this.agent,
    this.isTyping = false,
    required this.primaryColor,
    this.theme,
    this.onClose,
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: effectiveTheme.spacing.md,
        vertical: effectiveTheme.spacing.sm,
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
            // Avatar with online indicator
            _buildCompactAvatar(effectiveTheme),
            SizedBox(width: effectiveTheme.spacing.sm),

            // Name and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    agent.name,
                    style: TextStyle(
                      fontSize: effectiveTheme.typography.fontSizeMd,
                      fontWeight: effectiveTheme.typography.fontWeightSemiBold,
                      color: effectiveTheme.colors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  if (isTyping)
                    _AgentTypingIndicator(
                      theme: effectiveTheme,
                      primaryColor: primaryColor,
                    )
                  else
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: effectiveTheme.colors.online,
                          ),
                        ),
                        SizedBox(width: effectiveTheme.spacing.xs),
                        Text(
                          'Online',
                          style: TextStyle(
                            fontSize: effectiveTheme.typography.fontSizeXs,
                            color: effectiveTheme.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Close button
            if (showCloseButton && onClose != null)
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close,
                  color: effectiveTheme.colors.textSecondary,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAvatar(ConferBotTheme theme) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(0.1),
          ),
          child: ClipOval(
            child: agent.avatar != null && agent.avatar!.isNotEmpty
                ? Image.network(
                    agent.avatar!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildInitials(theme);
                    },
                  )
                : _buildInitials(theme),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colors.online,
              border: Border.all(
                color: theme.colors.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitials(ConferBotTheme theme) {
    final parts = agent.name.trim().split(' ');
    String initials;
    if (parts.length >= 2) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      initials = parts[0][0].toUpperCase();
    } else {
      initials = 'A';
    }

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: primaryColor,
          fontSize: 16,
          fontWeight: theme.typography.fontWeightSemiBold,
        ),
      ),
    );
  }
}

/// Agent connected notification banner
class AgentConnectedBanner extends StatefulWidget {
  final Agent agent;
  final Color primaryColor;
  final ConferBotTheme? theme;
  final Duration displayDuration;
  final VoidCallback? onDismiss;

  const AgentConnectedBanner({
    super.key,
    required this.agent,
    required this.primaryColor,
    this.theme,
    this.displayDuration = const Duration(seconds: 5),
    this.onDismiss,
  });

  @override
  State<AgentConnectedBanner> createState() => _AgentConnectedBannerState();
}

class _AgentConnectedBannerState extends State<AgentConnectedBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto dismiss after duration
    Future.delayed(widget.displayDuration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.all(effectiveTheme.spacing.md),
        padding: EdgeInsets.all(effectiveTheme.spacing.md),
        decoration: BoxDecoration(
          color: effectiveTheme.colors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.md),
          border: Border.all(
            color: effectiveTheme.colors.success.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Success icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: effectiveTheme.colors.success,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: effectiveTheme.spacing.md),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Agent Connected',
                    style: TextStyle(
                      fontSize: effectiveTheme.typography.fontSizeMd,
                      fontWeight: effectiveTheme.typography.fontWeightSemiBold,
                      color: effectiveTheme.colors.text,
                    ),
                  ),
                  SizedBox(height: effectiveTheme.spacing.xs / 2),
                  Text(
                    '${widget.agent.name} has joined the chat',
                    style: TextStyle(
                      fontSize: effectiveTheme.typography.fontSizeSm,
                      color: effectiveTheme.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Close button
            IconButton(
              onPressed: _dismiss,
              icon: Icon(
                Icons.close,
                color: effectiveTheme.colors.textSecondary,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple avatar with typing indicator
class AgentAvatarWithTyping extends StatelessWidget {
  final Agent agent;
  final bool isTyping;
  final Color primaryColor;
  final double size;

  const AgentAvatarWithTyping({
    super.key,
    required this.agent,
    this.isTyping = false,
    required this.primaryColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Avatar
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(0.1),
          ),
          child: ClipOval(
            child: agent.avatar != null && agent.avatar!.isNotEmpty
                ? Image.network(
                    agent.avatar!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildInitials();
                    },
                  )
                : _buildInitials(),
          ),
        ),

        // Typing indicator overlay
        if (isTyping)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.8),
              ),
              child: const _TypingDotsAnimation(),
            ),
          ),
      ],
    );
  }

  Widget _buildInitials() {
    final parts = agent.name.trim().split(' ');
    String initials;
    if (parts.length >= 2) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      initials = parts[0][0].toUpperCase();
    } else {
      initials = 'A';
    }

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: primaryColor,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Typing dots animation
class _TypingDotsAnimation extends StatefulWidget {
  const _TypingDotsAnimation();

  @override
  State<_TypingDotsAnimation> createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<_TypingDotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_controller.value + delay) % 1.0;
            final scale = 0.6 + (0.4 * (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0));

            return Transform.scale(
              scale: scale,
              child: Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
