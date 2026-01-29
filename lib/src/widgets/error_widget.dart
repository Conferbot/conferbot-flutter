import 'package:flutter/material.dart';
import '../core/errors/conferbot_exceptions.dart';
import '../core/errors/error_handler.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';

// ============================================
// CONFERBOT ERROR WIDGET
// ============================================

/// A comprehensive error display widget for ConferBot errors.
/// Supports different display variants and actions based on error type.
class ConferBotErrorWidget extends StatelessWidget {
  /// The error to display
  final ConferBotException error;

  /// Callback when retry is requested
  final VoidCallback? onRetry;

  /// Callback when dismiss is requested
  final VoidCallback? onDismiss;

  /// Callback for contact support action
  final VoidCallback? onContactSupport;

  /// Callback for opening settings
  final VoidCallback? onOpenSettings;

  /// Display variant
  final ErrorWidgetVariant variant;

  /// Custom theme
  final ConferBotTheme? theme;

  /// Whether to show the error code (for debugging)
  final bool showErrorCode;

  /// Whether to auto-hide after delay (for banner variant)
  final Duration? autoHideDuration;

  /// Custom message override
  final String? customMessage;

  const ConferBotErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.onContactSupport,
    this.onOpenSettings,
    this.variant = ErrorWidgetVariant.inline,
    this.theme,
    this.showErrorCode = false,
    this.autoHideDuration,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    switch (variant) {
      case ErrorWidgetVariant.banner:
        return _buildBanner(context, effectiveTheme);
      case ErrorWidgetVariant.inline:
        return _buildInline(context, effectiveTheme);
      case ErrorWidgetVariant.card:
        return _buildCard(context, effectiveTheme);
      case ErrorWidgetVariant.fullscreen:
        return _buildFullscreen(context, effectiveTheme);
      case ErrorWidgetVariant.snackbar:
        return _buildSnackbarContent(context, effectiveTheme);
    }
  }

  // ========== Banner Variant ==========

  Widget _buildBanner(BuildContext context, ConferBotTheme theme) {
    final severity = ErrorHandler.getSeverity(error);
    final color = _getSeverityColor(severity, theme);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: color.withOpacity(0.3), width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            _buildIcon(severity, color, size: 20),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    customMessage ?? error.userMessage,
                    style: TextStyle(
                      color: color,
                      fontSize: theme.typography.fontSizeSm,
                      fontWeight: theme.typography.fontWeightMedium,
                    ),
                  ),
                  if (showErrorCode)
                    Text(
                      'Code: ${error.code}',
                      style: TextStyle(
                        color: color.withOpacity(0.7),
                        fontSize: theme.typography.fontSizeXs,
                      ),
                    ),
                ],
              ),
            ),
            if (error.isRetryable && onRetry != null)
              _buildActionButton(
                label: 'Retry',
                onPressed: onRetry!,
                color: color,
                theme: theme,
              ),
            if (onDismiss != null)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: color),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
      ),
    );
  }

  // ========== Inline Variant ==========

  Widget _buildInline(BuildContext context, ConferBotTheme theme) {
    final severity = ErrorHandler.getSeverity(error);
    final color = _getSeverityColor(severity, theme);

    return Container(
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(theme.borderRadius.md),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(severity, color),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  customMessage ?? error.userMessage,
                  style: TextStyle(
                    color: color,
                    fontSize: theme.typography.fontSizeSm,
                  ),
                ),
                if (showErrorCode) ...[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    'Error code: ${error.code}',
                    style: TextStyle(
                      color: color.withOpacity(0.7),
                      fontSize: theme.typography.fontSizeXs,
                    ),
                  ),
                ],
                if (_hasActions) ...[
                  SizedBox(height: theme.spacing.sm),
                  _buildInlineActions(color, theme),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, size: 16, color: color),
            ),
        ],
      ),
    );
  }

  // ========== Card Variant ==========

  Widget _buildCard(BuildContext context, ConferBotTheme theme) {
    final severity = ErrorHandler.getSeverity(error);
    final color = _getSeverityColor(severity, theme);
    final action = ErrorHandler.getSuggestedAction(error);

    return Card(
      margin: EdgeInsets.all(theme.spacing.md),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(severity, color, size: 48),
            SizedBox(height: theme.spacing.md),
            Text(
              _getSeverityTitle(severity),
              style: TextStyle(
                fontSize: theme.typography.fontSizeLg,
                fontWeight: theme.typography.fontWeightSemiBold,
                color: theme.colors.text,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              customMessage ?? error.userMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
                color: theme.colors.textSecondary,
              ),
            ),
            if (showErrorCode) ...[
              SizedBox(height: theme.spacing.sm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.sm,
                  vertical: theme.spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: theme.colors.surface,
                  borderRadius: BorderRadius.circular(theme.borderRadius.sm),
                ),
                child: Text(
                  error.code,
                  style: TextStyle(
                    fontSize: theme.typography.fontSizeXs,
                    color: theme.colors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            SizedBox(height: theme.spacing.lg),
            _buildCardActions(action, color, theme),
          ],
        ),
      ),
    );
  }

  // ========== Fullscreen Variant ==========

  Widget _buildFullscreen(BuildContext context, ConferBotTheme theme) {
    final severity = ErrorHandler.getSeverity(error);
    final color = _getSeverityColor(severity, theme);
    final action = ErrorHandler.getSuggestedAction(error);

    return Container(
      color: theme.colors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: _buildIcon(severity, color, size: 40),
                ),
                SizedBox(height: theme.spacing.xl),
                Text(
                  _getSeverityTitle(severity),
                  style: TextStyle(
                    fontSize: theme.typography.fontSizeXxl,
                    fontWeight: theme.typography.fontWeightBold,
                    color: theme.colors.text,
                  ),
                ),
                SizedBox(height: theme.spacing.md),
                Text(
                  customMessage ?? error.userMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: theme.typography.fontSizeMd,
                    color: theme.colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (showErrorCode) ...[
                  SizedBox(height: theme.spacing.lg),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.spacing.md,
                      vertical: theme.spacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colors.surface,
                      borderRadius: BorderRadius.circular(theme.borderRadius.md),
                    ),
                    child: Text(
                      'Error Code: ${error.code}',
                      style: TextStyle(
                        fontSize: theme.typography.fontSizeSm,
                        color: theme.colors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                SizedBox(height: theme.spacing.xxl),
                _buildFullscreenActions(action, color, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== Snackbar Content Variant ==========

  Widget _buildSnackbarContent(BuildContext context, ConferBotTheme theme) {
    final severity = ErrorHandler.getSeverity(error);
    final color = _getSeverityColor(severity, theme);

    return Row(
      children: [
        _buildIcon(severity, Colors.white, size: 20),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Text(
            customMessage ?? error.userMessage,
            style: TextStyle(
              color: Colors.white,
              fontSize: theme.typography.fontSizeSm,
            ),
          ),
        ),
        if (error.isRetryable && onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: Text(
              'RETRY',
              style: TextStyle(
                color: Colors.white,
                fontWeight: theme.typography.fontWeightSemiBold,
              ),
            ),
          ),
      ],
    );
  }

  // ========== Helper Methods ==========

  Widget _buildIcon(ErrorSeverity severity, Color color, {double size = 24}) {
    IconData icon;
    switch (severity) {
      case ErrorSeverity.info:
        icon = Icons.info_outline;
        break;
      case ErrorSeverity.warning:
        icon = Icons.warning_amber_outlined;
        break;
      case ErrorSeverity.error:
        icon = Icons.error_outline;
        break;
      case ErrorSeverity.critical:
        icon = Icons.dangerous_outlined;
        break;
    }

    return Icon(icon, color: color, size: size);
  }

  Color _getSeverityColor(ErrorSeverity severity, ConferBotTheme theme) {
    switch (severity) {
      case ErrorSeverity.info:
        return theme.colors.info;
      case ErrorSeverity.warning:
        return theme.colors.warning;
      case ErrorSeverity.error:
        return theme.colors.error;
      case ErrorSeverity.critical:
        return theme.colors.error;
    }
  }

  String _getSeverityTitle(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return 'Notice';
      case ErrorSeverity.warning:
        return 'Warning';
      case ErrorSeverity.error:
        return 'Error';
      case ErrorSeverity.critical:
        return 'Critical Error';
    }
  }

  bool get _hasActions =>
      (error.isRetryable && onRetry != null) ||
      onContactSupport != null ||
      onOpenSettings != null;

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
    required ConferBotTheme theme,
    bool filled = false,
  }) {
    if (filled) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.borderRadius.md),
          ),
        ),
        child: Text(label),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: theme.typography.fontWeightMedium,
        ),
      ),
    );
  }

  Widget _buildInlineActions(Color color, ConferBotTheme theme) {
    return Wrap(
      spacing: theme.spacing.sm,
      children: [
        if (error.isRetryable && onRetry != null)
          _buildActionButton(
            label: 'Retry',
            onPressed: onRetry!,
            color: color,
            theme: theme,
          ),
        if (onContactSupport != null)
          _buildActionButton(
            label: 'Contact Support',
            onPressed: onContactSupport!,
            color: theme.colors.primary,
            theme: theme,
          ),
      ],
    );
  }

  Widget _buildCardActions(
    ErrorAction action,
    Color color,
    ConferBotTheme theme,
  ) {
    final List<Widget> actions = [];

    // Primary action based on suggested action
    switch (action) {
      case ErrorAction.retry:
        if (onRetry != null) {
          actions.add(_buildActionButton(
            label: 'Try Again',
            onPressed: onRetry!,
            color: theme.colors.primary,
            theme: theme,
            filled: true,
          ));
        }
        break;
      case ErrorAction.openSettings:
        if (onOpenSettings != null) {
          actions.add(_buildActionButton(
            label: 'Open Settings',
            onPressed: onOpenSettings!,
            color: theme.colors.primary,
            theme: theme,
            filled: true,
          ));
        }
        break;
      case ErrorAction.contactSupport:
        if (onContactSupport != null) {
          actions.add(_buildActionButton(
            label: 'Contact Support',
            onPressed: onContactSupport!,
            color: theme.colors.primary,
            theme: theme,
            filled: true,
          ));
        }
        break;
      default:
        if (error.isRetryable && onRetry != null) {
          actions.add(_buildActionButton(
            label: 'Try Again',
            onPressed: onRetry!,
            color: theme.colors.primary,
            theme: theme,
            filled: true,
          ));
        }
    }

    // Secondary dismiss action
    if (onDismiss != null) {
      actions.add(_buildActionButton(
        label: 'Dismiss',
        onPressed: onDismiss!,
        color: theme.colors.textSecondary,
        theme: theme,
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: actions.map((action) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
          child: action,
        );
      }).toList(),
    );
  }

  Widget _buildFullscreenActions(
    ErrorAction action,
    Color color,
    ConferBotTheme theme,
  ) {
    return Column(
      children: [
        if (error.isRetryable && onRetry != null)
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.borderRadius.md),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ),
        if (error.isRetryable && onRetry != null)
          SizedBox(height: theme.spacing.md),
        if (onContactSupport != null)
          TextButton(
            onPressed: onContactSupport,
            child: Text(
              'Contact Support',
              style: TextStyle(
                color: theme.colors.primary,
                fontWeight: theme.typography.fontWeightMedium,
              ),
            ),
          ),
        if (onDismiss != null && !error.isRetryable)
          SizedBox(
            width: 200,
            child: OutlinedButton(
              onPressed: onDismiss,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.borderRadius.md),
                ),
              ),
              child: const Text('Dismiss'),
            ),
          ),
      ],
    );
  }
}

// ============================================
// ERROR WIDGET VARIANTS
// ============================================

/// Display variants for the error widget
enum ErrorWidgetVariant {
  /// Small banner at top/bottom of screen
  banner,

  /// Inline error display within content
  inline,

  /// Card-style popup
  card,

  /// Fullscreen error overlay
  fullscreen,

  /// Content for snackbar display
  snackbar,
}

// ============================================
// ERROR BOUNDARY WIDGET
// ============================================

/// Error boundary widget that catches errors in its child tree
/// and displays an error widget instead.
class ConferBotErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(ConferBotException error, VoidCallback retry)?
      errorBuilder;
  final void Function(ConferBotException error)? onError;
  final ConferBotTheme? theme;

  const ConferBotErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
    this.theme,
  });

  @override
  State<ConferBotErrorBoundary> createState() => _ConferBotErrorBoundaryState();
}

class _ConferBotErrorBoundaryState extends State<ConferBotErrorBoundary> {
  ConferBotException? _error;

  @override
  void initState() {
    super.initState();
  }

  void _handleError(Object error, StackTrace stackTrace) {
    final conferBotError = ErrorHandler.fromException(error, stackTrace: stackTrace);

    setState(() {
      _error = conferBotError;
    });

    widget.onError?.call(conferBotError);
  }

  void _retry() {
    setState(() {
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!, _retry);
      }

      return ConferBotErrorWidget(
        error: _error!,
        variant: ErrorWidgetVariant.card,
        onRetry: _error!.isRetryable ? _retry : null,
        theme: widget.theme,
      );
    }

    return widget.child;
  }
}

// ============================================
// CONNECTION ERROR OVERLAY
// ============================================

/// Overlay widget for displaying connection errors with reconnection status.
class ConnectionErrorOverlay extends StatefulWidget {
  final ConferBotException? error;
  final bool isReconnecting;
  final int? reconnectionAttempt;
  final int? maxReconnectionAttempts;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final ConferBotTheme? theme;

  const ConnectionErrorOverlay({
    super.key,
    this.error,
    this.isReconnecting = false,
    this.reconnectionAttempt,
    this.maxReconnectionAttempts,
    this.onRetry,
    this.onDismiss,
    this.theme,
  });

  @override
  State<ConnectionErrorOverlay> createState() => _ConnectionErrorOverlayState();
}

class _ConnectionErrorOverlayState extends State<ConnectionErrorOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (widget.error != null || widget.isReconnecting) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(ConnectionErrorOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if ((widget.error != null || widget.isReconnecting) &&
        oldWidget.error == null &&
        !oldWidget.isReconnecting) {
      _animationController.forward();
    } else if (widget.error == null &&
        !widget.isReconnecting &&
        (oldWidget.error != null || oldWidget.isReconnecting)) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        if (_animation.value == 0) {
          return const SizedBox.shrink();
        }

        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(effectiveTheme.spacing.md),
            decoration: BoxDecoration(
              color: widget.isReconnecting
                  ? effectiveTheme.colors.warning.withOpacity(0.1)
                  : effectiveTheme.colors.error.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: widget.isReconnecting
                      ? effectiveTheme.colors.warning.withOpacity(0.3)
                      : effectiveTheme.colors.error.withOpacity(0.3),
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  if (widget.isReconnecting)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          effectiveTheme.colors.warning,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.cloud_off,
                      size: 20,
                      color: effectiveTheme.colors.error,
                    ),
                  SizedBox(width: effectiveTheme.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isReconnecting
                              ? 'Reconnecting...'
                              : widget.error?.userMessage ?? 'Connection lost',
                          style: TextStyle(
                            color: widget.isReconnecting
                                ? effectiveTheme.colors.warning
                                : effectiveTheme.colors.error,
                            fontSize: effectiveTheme.typography.fontSizeSm,
                            fontWeight:
                                effectiveTheme.typography.fontWeightMedium,
                          ),
                        ),
                        if (widget.isReconnecting &&
                            widget.reconnectionAttempt != null)
                          Text(
                            'Attempt ${widget.reconnectionAttempt}${widget.maxReconnectionAttempts != null ? ' of ${widget.maxReconnectionAttempts}' : ''}',
                            style: TextStyle(
                              color: effectiveTheme.colors.warning
                                  .withOpacity(0.8),
                              fontSize: effectiveTheme.typography.fontSizeXs,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!widget.isReconnecting && widget.onRetry != null)
                    TextButton(
                      onPressed: widget.onRetry,
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          color: effectiveTheme.colors.primary,
                          fontWeight:
                              effectiveTheme.typography.fontWeightMedium,
                        ),
                      ),
                    ),
                  if (widget.onDismiss != null)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: widget.isReconnecting
                            ? effectiveTheme.colors.warning
                            : effectiveTheme.colors.error,
                      ),
                      onPressed: widget.onDismiss,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================
// HELPER EXTENSIONS
// ============================================

/// Extension to show error as snackbar
extension ErrorSnackbarExtension on BuildContext {
  /// Show a ConferBot error as a snackbar
  void showErrorSnackbar(
    ConferBotException error, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    final severity = ErrorHandler.getSeverity(error);
    Color backgroundColor;

    switch (severity) {
      case ErrorSeverity.info:
        backgroundColor = Colors.blue.shade700;
        break;
      case ErrorSeverity.warning:
        backgroundColor = Colors.orange.shade700;
        break;
      case ErrorSeverity.error:
      case ErrorSeverity.critical:
        backgroundColor = Colors.red.shade700;
        break;
    }

    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: ConferBotErrorWidget(
          error: error,
          variant: ErrorWidgetVariant.snackbar,
          onRetry: onRetry,
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: error.isRetryable && onRetry != null
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
