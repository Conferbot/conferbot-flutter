import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/voice_recording_service.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';

/// Voice recorder widget with hold-to-record functionality
/// Features:
/// - Hold button to record
/// - Amplitude visualizer (waveform)
/// - Duration display
/// - Slide left to cancel
/// - Release to send
class VoiceRecorderWidget extends StatefulWidget {
  /// Callback when recording is completed and should be sent
  final Function(String filePath, Duration duration) onRecordingComplete;

  /// Callback when recording is cancelled
  final VoidCallback? onRecordingCancelled;

  /// Callback when recording starts
  final VoidCallback? onRecordingStart;

  /// Callback when permission is denied
  final VoidCallback? onPermissionDenied;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Primary color override
  final Color? primaryColor;

  /// Recording service (optional, creates one if not provided)
  final VoiceRecordingService? recordingService;

  /// Minimum recording duration to send
  final Duration minRecordingDuration;

  /// Cancel slide threshold (in pixels)
  final double cancelSlideThreshold;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    this.onRecordingCancelled,
    this.onRecordingStart,
    this.onPermissionDenied,
    this.theme,
    this.primaryColor,
    this.recordingService,
    this.minRecordingDuration = const Duration(milliseconds: 500),
    this.cancelSlideThreshold = 100.0,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  late VoiceRecordingService _recordingService;
  bool _ownsRecordingService = false;

  // Recording state
  bool _isRecording = false;
  bool _isCancelling = false;
  Duration _duration = Duration.zero;
  double _amplitude = 0.0;

  // Gesture state
  double _slideOffset = 0.0;
  Offset? _startPosition;

  // Waveform data
  final List<double> _waveformData = [];
  static const int _maxWaveformPoints = 50;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Subscriptions
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<RecordingState>? _stateSubscription;

  @override
  void initState() {
    super.initState();

    // Initialize recording service
    if (widget.recordingService != null) {
      _recordingService = widget.recordingService!;
    } else {
      _recordingService = VoiceRecordingService();
      _ownsRecordingService = true;
    }

    // Initialize pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    _durationSubscription = _recordingService.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    _amplitudeSubscription = _recordingService.amplitudeStream.listen((amplitude) {
      if (mounted) {
        setState(() {
          _amplitude = amplitude;
          // Add to waveform data
          _waveformData.add(amplitude);
          if (_waveformData.length > _maxWaveformPoints) {
            _waveformData.removeAt(0);
          }
        });
      }
    });

    _stateSubscription = _recordingService.stateStream.listen((state) {
      if (mounted) {
        if (state == RecordingState.permissionDenied) {
          widget.onPermissionDenied?.call();
        }
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    _stateSubscription?.cancel();
    _pulseController.dispose();

    if (_ownsRecordingService) {
      _recordingService.dispose();
    }

    super.dispose();
  }

  Future<void> _startRecording() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    final started = await _recordingService.startRecording();
    if (started && mounted) {
      setState(() {
        _isRecording = true;
        _isCancelling = false;
        _waveformData.clear();
      });
      _pulseController.repeat(reverse: true);
      widget.onRecordingStart?.call();
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    if (!_isRecording) return;

    // Stop pulse animation
    _pulseController.stop();
    _pulseController.reset();

    if (cancel || _isCancelling) {
      // Cancel recording
      await _recordingService.cancelRecording();
      setState(() {
        _isRecording = false;
        _isCancelling = false;
        _slideOffset = 0.0;
      });
      widget.onRecordingCancelled?.call();
      HapticFeedback.lightImpact();
    } else {
      // Check minimum duration
      if (_duration < widget.minRecordingDuration) {
        await _recordingService.cancelRecording();
        setState(() {
          _isRecording = false;
          _slideOffset = 0.0;
        });
        // Show toast or feedback about minimum duration
        return;
      }

      // Complete recording
      final filePath = await _recordingService.stopRecording();
      if (filePath != null && mounted) {
        widget.onRecordingComplete(filePath, _duration);
        HapticFeedback.mediumImpact();
      }
      setState(() {
        _isRecording = false;
        _slideOffset = 0.0;
      });
    }

    // Reset waveform
    _waveformData.clear();
    _duration = Duration.zero;
  }

  void _handlePanStart(DragStartDetails details) {
    _startPosition = details.globalPosition;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isRecording || _startPosition == null) return;

    final delta = details.globalPosition.dx - _startPosition!.dx;

    // Only allow sliding left (negative delta)
    if (delta < 0) {
      setState(() {
        _slideOffset = delta.abs();
        _isCancelling = _slideOffset > widget.cancelSlideThreshold;
      });

      // Haptic feedback when crossing threshold
      if (_isCancelling && _slideOffset > widget.cancelSlideThreshold &&
          _slideOffset < widget.cancelSlideThreshold + 5) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _startPosition = null;
    _stopRecording(cancel: _isCancelling);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final effectivePrimaryColor = widget.primaryColor ?? effectiveTheme.colors.primary;

    if (_isRecording) {
      return _buildRecordingUI(effectiveTheme, effectivePrimaryColor);
    }

    return _buildIdleUI(effectiveTheme, effectivePrimaryColor);
  }

  Widget _buildIdleUI(ConferBotTheme theme, Color primaryColor) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
          boxShadow: [theme.shadows.sm],
        ),
        child: Icon(
          Icons.mic,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildRecordingUI(ConferBotTheme theme, Color primaryColor) {
    final cancelProgress = (_slideOffset / widget.cancelSlideThreshold).clamp(0.0, 1.0);
    final recordColor = _isCancelling ? theme.colors.error : primaryColor;

    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onLongPressEnd: (_) => _stopRecording(),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: theme.colors.surface,
          borderRadius: BorderRadius.circular(theme.borderRadius.full),
          boxShadow: [theme.shadows.md],
          border: Border.all(
            color: recordColor.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Cancel indicator
            AnimatedOpacity(
              opacity: _slideOffset > 10 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 48,
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(-_slideOffset * 0.3, 0),
                  child: Icon(
                    _isCancelling ? Icons.delete : Icons.arrow_back,
                    color: _isCancelling ? theme.colors.error : theme.colors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),

            // Waveform visualizer
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
                child: CustomPaint(
                  painter: WaveformPainter(
                    waveformData: _waveformData,
                    color: recordColor,
                    amplitude: _amplitude,
                  ),
                  size: const Size(double.infinity, 32),
                ),
              ),
            ),

            // Duration display
            Padding(
              padding: EdgeInsets.only(right: theme.spacing.sm),
              child: Text(
                VoiceRecordingService.formatDuration(_duration),
                style: TextStyle(
                  fontSize: theme.typography.fontSizeSm,
                  fontWeight: theme.typography.fontWeightMedium,
                  color: theme.colors.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),

            // Recording indicator button
            Transform.translate(
              offset: Offset(-_slideOffset * 0.2, 0),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 48,
                      height: 48,
                      margin: EdgeInsets.only(right: theme.spacing.xs),
                      decoration: BoxDecoration(
                        color: recordColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: recordColor.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isCancelling ? Icons.close : Icons.mic,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for waveform visualization
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color color;
  final double amplitude;

  WaveformPainter({
    required this.waveformData,
    required this.color,
    required this.amplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) {
      _drawIdleWaveform(canvas, size);
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    final barWidth = size.width / waveformData.length;

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final amplitude = waveformData[i];
      final barHeight = (amplitude * size.height * 0.8).clamp(4.0, size.height * 0.9);

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  void _drawIdleWaveform(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final barCount = 30;
    final barWidth = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final barHeight = 4.0 + math.sin(i * 0.5) * 4;

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.color != color;
  }
}

/// Compact voice recorder button that expands when recording
class VoiceRecorderButton extends StatefulWidget {
  /// Callback when recording is completed
  final Function(String filePath, Duration duration) onRecordingComplete;

  /// Callback when recording is cancelled
  final VoidCallback? onRecordingCancelled;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Primary color
  final Color? primaryColor;

  /// Whether the button is disabled
  final bool disabled;

  const VoiceRecorderButton({
    super.key,
    required this.onRecordingComplete,
    this.onRecordingCancelled,
    this.theme,
    this.primaryColor,
    this.disabled = false,
  });

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton> {
  bool _isRecording = false;
  final VoiceRecordingService _recordingService = VoiceRecordingService();

  @override
  void dispose() {
    _recordingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final effectivePrimaryColor = widget.primaryColor ?? effectiveTheme.colors.primary;

    if (_isRecording) {
      return VoiceRecorderWidget(
        onRecordingComplete: (path, duration) {
          setState(() => _isRecording = false);
          widget.onRecordingComplete(path, duration);
        },
        onRecordingCancelled: () {
          setState(() => _isRecording = false);
          widget.onRecordingCancelled?.call();
        },
        theme: widget.theme,
        primaryColor: widget.primaryColor,
        recordingService: _recordingService,
      );
    }

    return GestureDetector(
      onLongPressStart: widget.disabled ? null : (_) async {
        final started = await _recordingService.startRecording();
        if (started && mounted) {
          setState(() => _isRecording = true);
        }
      },
      onTap: widget.disabled ? null : () async {
        // Single tap - check permission first
        final hasPermission = await _recordingService.requestPermission();
        if (!hasPermission && mounted) {
          _showPermissionDialog(context, effectiveTheme);
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: widget.disabled
              ? effectiveTheme.colors.textDisabled
              : effectivePrimaryColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mic,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  void _showPermissionDialog(BuildContext context, ConferBotTheme theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Microphone Permission',
          style: TextStyle(
            fontSize: theme.typography.fontSizeLg,
            fontWeight: theme.typography.fontWeightBold,
          ),
        ),
        content: Text(
          'Microphone permission is required to record voice messages. Please enable it in your device settings.',
          style: TextStyle(
            fontSize: theme.typography.fontSizeMd,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _recordingService.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
