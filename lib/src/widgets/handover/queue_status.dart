import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';

/// Queue status information
class QueueInfo {
  /// Position in the queue (1-based)
  final int position;

  /// Estimated wait time in seconds
  final int estimatedWaitSeconds;

  /// Whether any agents are available
  final bool agentsAvailable;

  /// Number of available agents
  final int availableAgentCount;

  /// Custom status message from server
  final String? statusMessage;

  /// Whether currently connecting to an agent
  final bool isConnecting;

  const QueueInfo({
    required this.position,
    required this.estimatedWaitSeconds,
    this.agentsAvailable = true,
    this.availableAgentCount = 0,
    this.statusMessage,
    this.isConnecting = false,
  });

  factory QueueInfo.fromJson(Map<String, dynamic> json) {
    return QueueInfo(
      position: json['position'] as int? ?? 1,
      estimatedWaitSeconds: json['estimatedWaitSeconds'] as int? ??
          (json['estimatedWait'] as int? ?? 60),
      agentsAvailable: json['agentsAvailable'] as bool? ?? true,
      availableAgentCount: json['availableAgentCount'] as int? ?? 0,
      statusMessage: json['statusMessage']?.toString(),
      isConnecting: json['isConnecting'] as bool? ?? false,
    );
  }

  QueueInfo copyWith({
    int? position,
    int? estimatedWaitSeconds,
    bool? agentsAvailable,
    int? availableAgentCount,
    String? statusMessage,
    bool? isConnecting,
  }) {
    return QueueInfo(
      position: position ?? this.position,
      estimatedWaitSeconds: estimatedWaitSeconds ?? this.estimatedWaitSeconds,
      agentsAvailable: agentsAvailable ?? this.agentsAvailable,
      availableAgentCount: availableAgentCount ?? this.availableAgentCount,
      statusMessage: statusMessage ?? this.statusMessage,
      isConnecting: isConnecting ?? this.isConnecting,
    );
  }
}

/// Queue status widget showing position, wait time, and animations
class QueueStatusWidget extends StatefulWidget {
  /// Current queue information
  final QueueInfo? queueInfo;

  /// Maximum wait time in minutes (from node config)
  final int maxWaitMinutes;

  /// Called when user cancels the queue
  final VoidCallback? onCancel;

  /// Custom handover message
  final String? handoverMessage;

  /// Primary color for accents
  final Color primaryColor;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Whether to show the timer countdown
  final bool showTimer;

  /// Whether to show agent availability
  final bool showAgentAvailability;

  /// Whether to show position in queue
  final bool showPosition;

  /// Custom connecting message
  final String? connectingMessage;

  /// Called when timeout is reached
  final VoidCallback? onTimeout;

  const QueueStatusWidget({
    super.key,
    this.queueInfo,
    required this.maxWaitMinutes,
    this.onCancel,
    this.handoverMessage,
    required this.primaryColor,
    this.theme,
    this.showTimer = true,
    this.showAgentAvailability = true,
    this.showPosition = true,
    this.connectingMessage,
    this.onTimeout,
  });

  @override
  State<QueueStatusWidget> createState() => _QueueStatusWidgetState();
}

class _QueueStatusWidgetState extends State<QueueStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rotateController;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the connecting indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotation animation for the loading ring
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Initialize countdown
    _remainingSeconds = widget.queueInfo?.estimatedWaitSeconds ??
        widget.maxWaitMinutes * 60;
    _startCountdown();
  }

  @override
  void didUpdateWidget(QueueStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update remaining time if queue info changes
    if (widget.queueInfo != oldWidget.queueInfo && widget.queueInfo != null) {
      setState(() {
        _remainingSeconds = widget.queueInfo!.estimatedWaitSeconds;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          _elapsedSeconds++;
        });
      } else {
        _countdownTimer?.cancel();
        widget.onTimeout?.call();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatWaitTime(int seconds) {
    if (seconds < 60) {
      return 'Less than a minute';
    } else if (seconds < 120) {
      return 'About 1 minute';
    } else {
      final minutes = seconds ~/ 60;
      return 'About $minutes minutes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    return Container(
      decoration: BoxDecoration(
        color: effectiveTheme.colors.surface,
        borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.lg),
        boxShadow: [effectiveTheme.shadows.md],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with gradient
          Container(
            padding: EdgeInsets.all(effectiveTheme.spacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.primaryColor.withOpacity(0.1),
                  widget.primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(effectiveTheme.borderRadius.lg),
                topRight: Radius.circular(effectiveTheme.borderRadius.lg),
              ),
            ),
            child: Column(
              children: [
                // Animated connecting indicator
                _buildConnectingIndicator(effectiveTheme),
                SizedBox(height: effectiveTheme.spacing.lg),

                // Status message
                Text(
                  widget.handoverMessage ??
                      widget.connectingMessage ??
                      'Connecting you to an agent...',
                  style: TextStyle(
                    fontSize: effectiveTheme.typography.fontSizeLg,
                    fontWeight: effectiveTheme.typography.fontWeightSemiBold,
                    color: effectiveTheme.colors.text,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Sub message
                if (widget.queueInfo?.statusMessage != null) ...[
                  SizedBox(height: effectiveTheme.spacing.xs),
                  Text(
                    widget.queueInfo!.statusMessage!,
                    style: TextStyle(
                      fontSize: effectiveTheme.typography.fontSizeSm,
                      color: effectiveTheme.colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          // Body
          Padding(
            padding: EdgeInsets.all(effectiveTheme.spacing.lg),
            child: Column(
              children: [
                // Queue info cards
                if (widget.showPosition || widget.showTimer)
                  _buildInfoCards(effectiveTheme),

                // Agent availability
                if (widget.showAgentAvailability) ...[
                  SizedBox(height: effectiveTheme.spacing.md),
                  _buildAgentAvailability(effectiveTheme),
                ],

                // Progress bar
                SizedBox(height: effectiveTheme.spacing.lg),
                _buildProgressBar(effectiveTheme),

                // Cancel button
                if (widget.onCancel != null) ...[
                  SizedBox(height: effectiveTheme.spacing.lg),
                  _buildCancelButton(effectiveTheme),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingIndicator(ConferBotTheme theme) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring
          AnimatedBuilder(
            animation: _rotateController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateController.value * 2 * math.pi,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.primaryColor.withOpacity(0.2),
                      width: 3,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _ArcPainter(
                      color: widget.primaryColor,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              );
            },
          ),

          // Middle pulsing circle
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 70 * _pulseAnimation.value,
                height: 70 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.primaryColor.withOpacity(0.1),
                ),
              );
            },
          ),

          // Inner circle with icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.primaryColor,
              boxShadow: [
                BoxShadow(
                  color: widget.primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.headset_mic_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards(ConferBotTheme theme) {
    return Row(
      children: [
        // Queue position card
        if (widget.showPosition &&
            widget.queueInfo != null &&
            widget.queueInfo!.position > 0)
          Expanded(
            child: _buildInfoCard(
              theme,
              icon: Icons.people_outline,
              label: 'Position',
              value: '#${widget.queueInfo!.position}',
              color: widget.primaryColor,
            ),
          ),

        if (widget.showPosition &&
            widget.showTimer &&
            widget.queueInfo != null &&
            widget.queueInfo!.position > 0)
          SizedBox(width: theme.spacing.md),

        // Wait time card
        if (widget.showTimer)
          Expanded(
            child: _buildInfoCard(
              theme,
              icon: Icons.access_time,
              label: 'Est. Wait',
              value: _formatWaitTime(_remainingSeconds),
              color: _remainingSeconds < 60 ? theme.colors.warning : theme.colors.info,
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard(
    ConferBotTheme theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(theme.borderRadius.md),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              SizedBox(width: theme.spacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: theme.typography.fontSizeXs,
                  color: theme.colors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            value,
            style: TextStyle(
              fontSize: theme.typography.fontSizeMd,
              fontWeight: theme.typography.fontWeightSemiBold,
              color: theme.colors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentAvailability(ConferBotTheme theme) {
    final isAvailable = widget.queueInfo?.agentsAvailable ?? true;
    final agentCount = widget.queueInfo?.availableAgentCount ?? 0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: isAvailable
            ? theme.colors.success.withOpacity(0.1)
            : theme.colors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(theme.borderRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAvailable ? theme.colors.success : theme.colors.warning,
              boxShadow: [
                BoxShadow(
                  color: (isAvailable ? theme.colors.success : theme.colors.warning)
                      .withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Text(
            isAvailable
                ? (agentCount > 0
                    ? '$agentCount agent${agentCount > 1 ? 's' : ''} available'
                    : 'Agents available')
                : 'All agents busy',
            style: TextStyle(
              fontSize: theme.typography.fontSizeSm,
              color: isAvailable ? theme.colors.success : theme.colors.warning,
              fontWeight: theme.typography.fontWeightMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ConferBotTheme theme) {
    final totalSeconds = widget.maxWaitMinutes * 60;
    final progress = totalSeconds > 0
        ? (_elapsedSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Time elapsed',
              style: TextStyle(
                fontSize: theme.typography.fontSizeXs,
                color: theme.colors.textSecondary,
              ),
            ),
            Text(
              _formatTime(_elapsedSeconds),
              style: TextStyle(
                fontSize: theme.typography.fontSizeXs,
                color: theme.colors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(theme.borderRadius.sm),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colors.border.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress > 0.8 ? theme.colors.warning : widget.primaryColor,
            ),
            minHeight: 6,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Max wait: ${widget.maxWaitMinutes} min',
              style: TextStyle(
                fontSize: theme.typography.fontSizeXs,
                color: theme.colors.textSecondary,
              ),
            ),
            Text(
              _formatTime(_remainingSeconds),
              style: TextStyle(
                fontSize: theme.typography.fontSizeXs,
                color: _remainingSeconds < 60
                    ? theme.colors.warning
                    : theme.colors.textSecondary,
                fontWeight: _remainingSeconds < 60
                    ? theme.typography.fontWeightSemiBold
                    : theme.typography.fontWeightRegular,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCancelButton(ConferBotTheme theme) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: widget.onCancel,
        icon: const Icon(Icons.close, size: 18),
        label: const Text('Leave Queue'),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colors.textSecondary,
          side: BorderSide(color: theme.colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.borderRadius.md),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the rotating arc
class _ArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ArcPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, 0, math.pi / 2, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Compact queue status indicator for inline display
class CompactQueueStatus extends StatefulWidget {
  final int maxWaitMinutes;
  final QueueInfo? queueInfo;
  final Color primaryColor;
  final ConferBotTheme? theme;
  final VoidCallback? onTap;

  const CompactQueueStatus({
    super.key,
    required this.maxWaitMinutes,
    this.queueInfo,
    required this.primaryColor,
    this.theme,
    this.onTap,
  });

  @override
  State<CompactQueueStatus> createState() => _CompactQueueStatusState();
}

class _CompactQueueStatusState extends State<CompactQueueStatus>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    _remainingSeconds = widget.queueInfo?.estimatedWaitSeconds ??
        widget.maxWaitMinutes * 60;
    _startCountdown();
  }

  @override
  void dispose() {
    _dotController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(CompactQueueStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.queueInfo != oldWidget.queueInfo && widget.queueInfo != null) {
      setState(() {
        _remainingSeconds = widget.queueInfo!.estimatedWaitSeconds;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final position = widget.queueInfo?.position;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: effectiveTheme.spacing.md,
          vertical: effectiveTheme.spacing.sm,
        ),
        decoration: BoxDecoration(
          color: widget.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.full),
          border: Border.all(
            color: widget.primaryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated dots
            AnimatedBuilder(
              animation: _dotController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final delay = index * 0.2;
                    final progress = (_dotController.value + delay) % 1.0;
                    final opacity =
                        0.3 + (0.7 * (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0));

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
            SizedBox(width: effectiveTheme.spacing.sm),

            // Position if available
            if (position != null && position > 0) ...[
              Text(
                '#$position',
                style: TextStyle(
                  fontSize: effectiveTheme.typography.fontSizeSm,
                  fontWeight: effectiveTheme.typography.fontWeightSemiBold,
                  color: widget.primaryColor,
                ),
              ),
              Container(
                width: 1,
                height: 12,
                margin: EdgeInsets.symmetric(horizontal: effectiveTheme.spacing.xs),
                color: widget.primaryColor.withOpacity(0.3),
              ),
            ],

            // Time remaining
            Icon(
              Icons.access_time,
              size: 14,
              color: widget.primaryColor,
            ),
            SizedBox(width: effectiveTheme.spacing.xs),
            Text(
              _formatTime(_remainingSeconds),
              style: TextStyle(
                fontSize: effectiveTheme.typography.fontSizeSm,
                fontWeight: effectiveTheme.typography.fontWeightMedium,
                color: widget.primaryColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal waiting indicator (just the animated icon)
class WaitingIndicator extends StatefulWidget {
  final Color primaryColor;
  final double size;

  const WaitingIndicator({
    super.key,
    required this.primaryColor,
    this.size = 48,
  });

  @override
  State<WaitingIndicator> createState() => _WaitingIndicatorState();
}

class _WaitingIndicatorState extends State<WaitingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _WaitingPainter(
                color: widget.primaryColor,
                progress: _controller.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaitingPainter extends CustomPainter {
  final Color color;
  final double progress;

  _WaitingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Draw background circle
    paint.color = color.withOpacity(0.2);
    canvas.drawCircle(center, radius, paint);

    // Draw progress arc
    paint.color = color;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.5 * progress, false, paint);
  }

  @override
  bool shouldRepaint(_WaitingPainter oldDelegate) => oldDelegate.progress != progress;
}
