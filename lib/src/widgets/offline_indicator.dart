import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../services/message_queue_service.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';

/// Widget that displays offline status and pending message count
/// Shows a banner when device is offline or has pending messages
class OfflineIndicator extends StatefulWidget {
  /// Theme for styling
  final ConferBotTheme? theme;

  /// Whether to show pending message count
  final bool showPendingCount;

  /// Whether to auto-hide when online and no pending
  final bool autoHide;

  /// Callback when retry all is tapped
  final VoidCallback? onRetryAll;

  /// Custom offline message
  final String? offlineMessage;

  /// Custom pending message
  final String? pendingMessage;

  const OfflineIndicator({
    super.key,
    this.theme,
    this.showPendingCount = true,
    this.autoHide = true,
    this.onRetryAll,
    this.offlineMessage,
    this.pendingMessage,
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator>
    with SingleTickerProviderStateMixin {
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final MessageQueueService _messageQueue = MessageQueueService.instance;

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _connectivity.addListener(_updateVisibility);
    _messageQueue.addListener(_updateVisibility);

    _updateVisibility();
  }

  @override
  void dispose() {
    _connectivity.removeListener(_updateVisibility);
    _messageQueue.removeListener(_updateVisibility);
    _animationController.dispose();
    super.dispose();
  }

  void _updateVisibility() {
    final shouldShow = !_connectivity.isOnline ||
        (!widget.autoHide && _messageQueue.pendingCount > 0);

    if (shouldShow != _isVisible) {
      setState(() {
        _isVisible = shouldShow;
      });

      if (shouldShow) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    } else {
      // Force rebuild for pending count changes
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final isOffline = !_connectivity.isOnline;
    final pendingCount = _messageQueue.pendingCount;

    // Don't render anything if hidden and animation complete
    if (!_isVisible && !_animationController.isAnimating) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 50),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: effectiveTheme.spacing.md,
          vertical: effectiveTheme.spacing.sm,
        ),
        decoration: BoxDecoration(
          color: isOffline
              ? effectiveTheme.colors.warning.withOpacity(0.95)
              : effectiveTheme.colors.info.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Icon(
                isOffline ? Icons.cloud_off : Icons.schedule,
                size: 18,
                color: isOffline ? Colors.white : effectiveTheme.colors.text,
              ),
              SizedBox(width: effectiveTheme.spacing.sm),
              Expanded(
                child: Text(
                  _getMessage(isOffline, pendingCount),
                  style: TextStyle(
                    fontSize: effectiveTheme.typography.fontSizeSm,
                    fontWeight: effectiveTheme.typography.fontWeightMedium,
                    color: isOffline ? Colors.white : effectiveTheme.colors.text,
                  ),
                ),
              ),
              if (!isOffline && pendingCount > 0 && widget.onRetryAll != null)
                TextButton(
                  onPressed: widget.onRetryAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: effectiveTheme.spacing.sm,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Send Now',
                    style: TextStyle(
                      fontSize: effectiveTheme.typography.fontSizeSm,
                      fontWeight: effectiveTheme.typography.fontWeightBold,
                      color: effectiveTheme.colors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMessage(bool isOffline, int pendingCount) {
    if (isOffline) {
      if (pendingCount > 0 && widget.showPendingCount) {
        return widget.offlineMessage ??
            'You\'re offline. $pendingCount message${pendingCount > 1 ? 's' : ''} will be sent when connected.';
      }
      return widget.offlineMessage ?? 'You\'re offline. Messages will be queued.';
    }

    if (pendingCount > 0 && widget.showPendingCount) {
      return widget.pendingMessage ??
          'Sending $pendingCount queued message${pendingCount > 1 ? 's' : ''}...';
    }

    return '';
  }
}

/// Compact offline badge for use in headers
class OfflineBadge extends StatelessWidget {
  final ConferBotTheme? theme;
  final bool showWhenOnline;

  const OfflineBadge({
    super.key,
    this.theme,
    this.showWhenOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;
    final connectivity = ConnectivityService.instance;

    return ListenableBuilder(
      listenable: connectivity,
      builder: (context, child) {
        final isOnline = connectivity.isOnline;

        if (isOnline && !showWhenOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: effectiveTheme.spacing.sm,
            vertical: effectiveTheme.spacing.xs,
          ),
          decoration: BoxDecoration(
            color: isOnline
                ? effectiveTheme.colors.online.withOpacity(0.1)
                : effectiveTheme.colors.offline.withOpacity(0.1),
            borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color:
                      isOnline ? effectiveTheme.colors.online : effectiveTheme.colors.offline,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: effectiveTheme.spacing.xs),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: effectiveTheme.typography.fontSizeXs,
                  color:
                      isOnline ? effectiveTheme.colors.online : effectiveTheme.colors.offline,
                  fontWeight: effectiveTheme.typography.fontWeightMedium,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pending messages indicator showing count
class PendingMessagesIndicator extends StatelessWidget {
  final ConferBotTheme? theme;
  final VoidCallback? onTap;

  const PendingMessagesIndicator({
    super.key,
    this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;
    final messageQueue = MessageQueueService.instance;

    return ListenableBuilder(
      listenable: messageQueue,
      builder: (context, child) {
        final pendingCount = messageQueue.pendingCount;

        if (pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: effectiveTheme.spacing.sm,
              vertical: effectiveTheme.spacing.xs,
            ),
            decoration: BoxDecoration(
              color: effectiveTheme.colors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: 12,
                  color: effectiveTheme.colors.warning,
                ),
                SizedBox(width: effectiveTheme.spacing.xs),
                Text(
                  '$pendingCount pending',
                  style: TextStyle(
                    fontSize: effectiveTheme.typography.fontSizeXs,
                    color: effectiveTheme.colors.warning,
                    fontWeight: effectiveTheme.typography.fontWeightMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
