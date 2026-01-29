import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';

/// Playback speed options
enum PlaybackSpeed {
  slow(0.5, '0.5x'),
  normal(1.0, '1x'),
  fast(1.5, '1.5x'),
  faster(2.0, '2x');

  final double value;
  final String label;

  const PlaybackSpeed(this.value, this.label);
}

/// Voice player widget for audio message playback
/// Features:
/// - Play/pause button
/// - Waveform visualization
/// - Progress indicator
/// - Duration display
/// - Playback speed control
class VoicePlayerWidget extends StatefulWidget {
  /// Audio source URL or local file path
  final String audioSource;

  /// Whether the source is a local file
  final bool isLocalFile;

  /// Duration of the audio (if known)
  final Duration? duration;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Primary color override
  final Color? primaryColor;

  /// Whether this is a user's message (for styling)
  final bool isUserMessage;

  /// Waveform data (optional, for visualization)
  final List<double>? waveformData;

  /// Callback when playback completes
  final VoidCallback? onPlaybackComplete;

  /// Callback when playback starts
  final VoidCallback? onPlaybackStart;

  const VoicePlayerWidget({
    super.key,
    required this.audioSource,
    this.isLocalFile = false,
    this.duration,
    this.theme,
    this.primaryColor,
    this.isUserMessage = false,
    this.waveformData,
    this.onPlaybackComplete,
    this.onPlaybackStart,
  });

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlaybackSpeed _playbackSpeed = PlaybackSpeed.normal;
  bool _isLoading = false;
  String? _errorMessage;

  // Subscriptions
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  // Animation
  late AnimationController _playButtonController;

  @override
  void initState() {
    super.initState();

    _playButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _setupAudioPlayer();

    if (widget.duration != null) {
      _duration = widget.duration!;
    }
  }

  void _setupAudioPlayer() {
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _playerState = state);

        if (state == PlayerState.playing) {
          _playButtonController.forward();
          widget.onPlaybackStart?.call();
        } else {
          _playButtonController.reverse();
        }

        if (state == PlayerState.completed) {
          widget.onPlaybackComplete?.call();
          setState(() => _position = Duration.zero);
        }
      }
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playButtonController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_playerState == PlayerState.playing) {
        await _audioPlayer.pause();
      } else {
        setState(() => _isLoading = true);

        if (_playerState == PlayerState.stopped ||
            _playerState == PlayerState.completed) {
          // Set source and play
          if (widget.isLocalFile) {
            await _audioPlayer.setSourceDeviceFile(widget.audioSource);
          } else {
            await _audioPlayer.setSourceUrl(widget.audioSource);
          }
          await _audioPlayer.setPlaybackRate(_playbackSpeed.value);
        }

        await _audioPlayer.resume();
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to play audio';
      });
      debugPrint('[VoicePlayerWidget] Error playing audio: $e');
    }
  }

  Future<void> _seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void _cyclePlaybackSpeed() {
    final speeds = PlaybackSpeed.values;
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;

    setState(() => _playbackSpeed = speeds[nextIndex]);
    _audioPlayer.setPlaybackRate(_playbackSpeed.value);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final effectivePrimaryColor = widget.primaryColor ?? effectiveTheme.colors.primary;

    final backgroundColor = widget.isUserMessage
        ? effectivePrimaryColor.withOpacity(0.1)
        : effectiveTheme.colors.surface;

    final foregroundColor = widget.isUserMessage
        ? effectivePrimaryColor
        : effectiveTheme.colors.text;

    final progressColor = widget.isUserMessage
        ? effectivePrimaryColor
        : effectiveTheme.colors.primary;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: EdgeInsets.all(effectiveTheme.spacing.sm),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.lg),
        border: Border.all(
          color: effectiveTheme.colors.border.withOpacity(0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Play/Pause button
              _buildPlayButton(effectiveTheme, progressColor),

              SizedBox(width: effectiveTheme.spacing.sm),

              // Waveform and progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waveform visualizer
                    SizedBox(
                      height: 32,
                      child: CustomPaint(
                        painter: VoiceWaveformPainter(
                          waveformData: widget.waveformData ?? _generateDefaultWaveform(),
                          progress: _duration.inMilliseconds > 0
                              ? _position.inMilliseconds / _duration.inMilliseconds
                              : 0.0,
                          activeColor: progressColor,
                          inactiveColor: progressColor.withOpacity(0.3),
                          isPlaying: _playerState == PlayerState.playing,
                        ),
                        size: const Size(double.infinity, 32),
                      ),
                    ),

                    SizedBox(height: effectiveTheme.spacing.xs),

                    // Progress slider (invisible but interactive)
                    SliderTheme(
                      data: SliderThemeData(
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                        trackHeight: 0,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                      ),
                      child: Slider(
                        value: _duration.inMilliseconds > 0
                            ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                            : 0.0,
                        onChanged: (value) {
                          final position = Duration(
                            milliseconds: (value * _duration.inMilliseconds).round(),
                          );
                          _seek(position);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: effectiveTheme.spacing.sm),

              // Duration and speed
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Duration
                  Text(
                    _formatDuration(_playerState == PlayerState.playing
                        ? _position
                        : _duration),
                    style: TextStyle(
                      fontSize: effectiveTheme.typography.fontSizeXs,
                      color: foregroundColor.withOpacity(0.7),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),

                  SizedBox(height: effectiveTheme.spacing.xs),

                  // Playback speed button
                  GestureDetector(
                    onTap: _cyclePlaybackSpeed,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: effectiveTheme.spacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: progressColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _playbackSpeed.label,
                        style: TextStyle(
                          fontSize: effectiveTheme.typography.fontSizeXs,
                          fontWeight: effectiveTheme.typography.fontWeightMedium,
                          color: progressColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Error message
          if (_errorMessage != null) ...[
            SizedBox(height: effectiveTheme.spacing.xs),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: effectiveTheme.typography.fontSizeXs,
                color: effectiveTheme.colors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayButton(ConferBotTheme theme, Color color) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: _isLoading
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : AnimatedIcon(
                icon: AnimatedIcons.play_pause,
                progress: _playButtonController,
                color: Colors.white,
                size: 24,
              ),
      ),
    );
  }

  List<double> _generateDefaultWaveform() {
    // Generate a random but consistent waveform based on source hash
    final hash = widget.audioSource.hashCode;
    final random = math.Random(hash);
    return List.generate(40, (_) => 0.2 + random.nextDouble() * 0.6);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Custom painter for voice waveform visualization
class VoiceWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final bool isPlaying;

  VoiceWaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    this.isPlaying = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final barWidth = size.width / waveformData.length;
    final centerY = size.height / 2;
    final progressPosition = progress * size.width;

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final amplitude = waveformData[i];
      final barHeight = (amplitude * size.height * 0.8).clamp(4.0, size.height * 0.9);

      final isActive = x <= progressPosition;

      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(VoiceWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.activeColor != activeColor;
  }
}

/// Mini voice player for compact display
class MiniVoicePlayer extends StatefulWidget {
  /// Audio source URL or local file path
  final String audioSource;

  /// Whether the source is a local file
  final bool isLocalFile;

  /// Duration of the audio
  final Duration? duration;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Primary color
  final Color? primaryColor;

  const MiniVoicePlayer({
    super.key,
    required this.audioSource,
    this.isLocalFile = false,
    this.duration,
    this.theme,
    this.primaryColor,
  });

  @override
  State<MiniVoicePlayer> createState() => _MiniVoicePlayerState();
}

class _MiniVoicePlayerState extends State<MiniVoicePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _setupPlayer();
    if (widget.duration != null) {
      _duration = widget.duration!;
    }
  }

  void _setupPlayer() {
    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      if (_playerState == PlayerState.stopped ||
          _playerState == PlayerState.completed) {
        if (widget.isLocalFile) {
          await _audioPlayer.setSourceDeviceFile(widget.audioSource);
        } else {
          await _audioPlayer.setSourceUrl(widget.audioSource);
        }
      }
      await _audioPlayer.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final effectivePrimaryColor = widget.primaryColor ?? effectiveTheme.colors.primary;

    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play button
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: effectivePrimaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _playerState == PlayerState.playing
                  ? Icons.pause
                  : Icons.play_arrow,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),

        SizedBox(width: effectiveTheme.spacing.sm),

        // Progress bar
        Expanded(
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: effectivePrimaryColor.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(effectivePrimaryColor),
          ),
        ),

        SizedBox(width: effectiveTheme.spacing.sm),

        // Duration
        Text(
          _formatDuration(_playerState == PlayerState.playing
              ? _position
              : _duration),
          style: TextStyle(
            fontSize: effectiveTheme.typography.fontSizeXs,
            color: effectiveTheme.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
