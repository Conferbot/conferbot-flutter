import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';
import '../../services/media_service.dart';

/// Playback speed options for audio player
enum AudioPlaybackSpeed {
  slow(0.5, '0.5x'),
  normal(1.0, '1x'),
  fast(1.5, '1.5x'),
  faster(2.0, '2x');

  final double value;
  final String label;

  const AudioPlaybackSpeed(this.value, this.label);

  static AudioPlaybackSpeed fromValue(double value) {
    return AudioPlaybackSpeed.values.firstWhere(
      (s) => s.value == value,
      orElse: () => AudioPlaybackSpeed.normal,
    );
  }
}

/// Audio player configuration
class AudioPlayerConfig {
  /// Auto-play audio
  final bool autoPlay;

  /// Show playback speed control
  final bool showSpeedControl;

  /// Show waveform visualization
  final bool showWaveform;

  /// Initial playback speed
  final AudioPlaybackSpeed initialSpeed;

  /// Compact mode (smaller widget)
  final bool compactMode;

  /// Show download button
  final bool showDownload;

  const AudioPlayerConfig({
    this.autoPlay = false,
    this.showSpeedControl = true,
    this.showWaveform = true,
    this.initialSpeed = AudioPlaybackSpeed.normal,
    this.compactMode = false,
    this.showDownload = false,
  });
}

/// Audio player widget with full controls
///
/// Features:
/// - Play/pause button
/// - Progress bar with seek
/// - Duration display
/// - Playback speed control (0.5x, 1x, 1.5x, 2x)
/// - Waveform visualization
/// - Integration with MediaService for single-player management
class AudioPlayerWidget extends StatefulWidget {
  /// Audio URL
  final String audioUrl;

  /// Optional title
  final String? title;

  /// Player configuration
  final AudioPlayerConfig config;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Primary color override
  final Color? primaryColor;

  /// Whether this is a user's message (affects styling)
  final bool isUserMessage;

  /// Unique ID for media service registration
  final String? playerId;

  /// Pre-computed waveform data (if available)
  final List<double>? waveformData;

  /// Callback when audio ends
  final VoidCallback? onAudioEnd;

  /// Callback when playback starts
  final VoidCallback? onPlaybackStart;

  /// Callback when error occurs
  final ValueChanged<String>? onError;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.title,
    this.config = const AudioPlayerConfig(),
    this.theme,
    this.primaryColor,
    this.isUserMessage = false,
    this.playerId,
    this.waveformData,
    this.onAudioEnd,
    this.onPlaybackStart,
    this.onError,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AudioPlayer _audioPlayer;
  late MediaService _mediaService;
  late String _playerId;
  late AnimationController _playButtonController;

  // State
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  AudioPlaybackSpeed _playbackSpeed = AudioPlaybackSpeed.normal;

  // Subscriptions
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _mediaService = MediaService.instance;
    _playerId = widget.playerId ?? 'audio_${widget.audioUrl.hashCode}';
    _playbackSpeed = widget.config.initialSpeed;

    _playButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    WidgetsBinding.instance.addObserver(this);
    _setupPlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playButtonController.dispose();
    _mediaService.unregisterPlayer(_playerId);
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _audioPlayer.pause();
    }
  }

  void _setupPlayer() {
    // Listen to player state changes
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;

      final isPlaying = state.playing;
      if (_isPlaying != isPlaying) {
        setState(() => _isPlaying = isPlaying);

        if (isPlaying) {
          _playButtonController.forward();
          _mediaService.onPlayerStarted(_playerId);
          widget.onPlaybackStart?.call();
        } else {
          _playButtonController.reverse();
          _mediaService.onPlayerStopped(_playerId);
        }
      }

      // Handle completion
      if (state.processingState == ProcessingState.completed) {
        widget.onAudioEnd?.call();
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
      }
    });

    // Listen to position changes
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    // Listen to duration changes
    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
          _isInitialized = true;
        });
      }
    });

    // Register with media service
    _mediaService.registerPlayer(
      ActiveMediaPlayer(
        id: _playerId,
        type: MediaPlayerType.audio,
        controller: _audioPlayer,
        onPause: () {
          if (mounted) {
            setState(() => _isPlaying = false);
          }
        },
      ),
    );
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        setState(() => _isLoading = true);

        // Load audio if not loaded
        if (!_isInitialized) {
          await _audioPlayer.setUrl(widget.audioUrl);
          await _audioPlayer.setSpeed(_playbackSpeed.value);
        }

        await _audioPlayer.play();

        setState(() {
          _isLoading = false;
          _hasError = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to play audio';
      });
      widget.onError?.call(e.toString());
      debugPrint('[AudioPlayerWidget] Error playing audio: $e');
    }
  }

  Future<void> _seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void _cyclePlaybackSpeed() {
    final speeds = AudioPlaybackSpeed.values;
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    final newSpeed = speeds[nextIndex];

    setState(() => _playbackSpeed = newSpeed);
    _audioPlayer.setSpeed(newSpeed.value);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final effectivePrimaryColor =
        widget.primaryColor ?? effectiveTheme.colors.primary;

    if (widget.config.compactMode) {
      return _buildCompactPlayer(effectiveTheme, effectivePrimaryColor);
    }

    return _buildFullPlayer(effectiveTheme, effectivePrimaryColor);
  }

  Widget _buildFullPlayer(ConferBotTheme theme, Color primaryColor) {
    final backgroundColor = widget.isUserMessage
        ? primaryColor.withOpacity(0.1)
        : theme.colors.surface;

    final foregroundColor = widget.isUserMessage
        ? primaryColor
        : theme.colors.text;

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: EdgeInsets.all(theme.spacing.sm),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
        border: Border.all(
          color: theme.colors.border.withOpacity(0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title if provided
          if (widget.title != null && widget.title!.isNotEmpty) ...[
            Text(
              widget.title!,
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                fontWeight: theme.typography.fontWeightMedium,
                color: foregroundColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: theme.spacing.sm),
          ],

          Row(
            children: [
              // Play/Pause button
              _buildPlayButton(theme, primaryColor),

              SizedBox(width: theme.spacing.sm),

              // Waveform and progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waveform visualizer
                    if (widget.config.showWaveform)
                      SizedBox(
                        height: 32,
                        child: CustomPaint(
                          painter: AudioWaveformPainter(
                            waveformData: widget.waveformData ??
                                _generateDefaultWaveform(),
                            progress: _duration.inMilliseconds > 0
                                ? _position.inMilliseconds /
                                    _duration.inMilliseconds
                                : 0.0,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.3),
                            isPlaying: _isPlaying,
                          ),
                          size: const Size(double.infinity, 32),
                        ),
                      ),

                    SizedBox(height: theme.spacing.xs),

                    // Progress slider
                    _buildProgressSlider(theme, primaryColor),
                  ],
                ),
              ),

              SizedBox(width: theme.spacing.sm),

              // Duration and speed
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Duration display
                  Text(
                    _isPlaying
                        ? _formatDuration(_position)
                        : _formatDuration(_duration),
                    style: TextStyle(
                      fontSize: theme.typography.fontSizeXs,
                      color: foregroundColor.withOpacity(0.7),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),

                  if (widget.config.showSpeedControl) ...[
                    SizedBox(height: theme.spacing.xs),
                    // Playback speed button
                    _buildSpeedButton(theme, primaryColor),
                  ],
                ],
              ),
            ],
          ),

          // Error message
          if (_hasError) ...[
            SizedBox(height: theme.spacing.xs),
            Text(
              _errorMessage ?? 'Playback error',
              style: TextStyle(
                fontSize: theme.typography.fontSizeXs,
                color: theme.colors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactPlayer(ConferBotTheme theme, Color primaryColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play button
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 18,
                  ),
          ),
        ),

        SizedBox(width: theme.spacing.sm),

        // Progress bar
        Expanded(
          child: LinearProgressIndicator(
            value: _duration.inMilliseconds > 0
                ? (_position.inMilliseconds / _duration.inMilliseconds)
                    .clamp(0.0, 1.0)
                : 0.0,
            backgroundColor: primaryColor.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(primaryColor),
          ),
        ),

        SizedBox(width: theme.spacing.sm),

        // Duration
        Text(
          _formatDuration(_isPlaying ? _position : _duration),
          style: TextStyle(
            fontSize: theme.typography.fontSizeXs,
            color: theme.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton(ConferBotTheme theme, Color color) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: _isLoading
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
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

  Widget _buildProgressSlider(ConferBotTheme theme, Color color) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
        activeTrackColor: color,
        inactiveTrackColor: color.withOpacity(0.3),
        thumbColor: color,
        overlayColor: color.withOpacity(0.2),
      ),
      child: Slider(
        value: _duration.inMilliseconds > 0
            ? (_position.inMilliseconds / _duration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0,
        onChanged: (value) {
          final position = Duration(
            milliseconds: (value * _duration.inMilliseconds).round(),
          );
          _seek(position);
        },
      ),
    );
  }

  Widget _buildSpeedButton(ConferBotTheme theme, Color color) {
    return GestureDetector(
      onTap: _cyclePlaybackSpeed,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.xs,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _playbackSpeed.label,
          style: TextStyle(
            fontSize: theme.typography.fontSizeXs,
            fontWeight: theme.typography.fontWeightMedium,
            color: color,
          ),
        ),
      ),
    );
  }

  List<double> _generateDefaultWaveform() {
    // Generate a random but consistent waveform based on URL hash
    final hash = widget.audioUrl.hashCode;
    final random = math.Random(hash);
    return List.generate(40, (_) => 0.2 + random.nextDouble() * 0.6);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

/// Custom painter for audio waveform visualization
class AudioWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final bool isPlaying;

  AudioWaveformPainter({
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
      final barHeight =
          (amplitude * size.height * 0.8).clamp(4.0, size.height * 0.9);

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
  bool shouldRepaint(AudioWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.activeColor != activeColor;
  }
}

/// Mini audio player for compact inline display
class MiniAudioPlayer extends StatefulWidget {
  /// Audio source URL
  final String audioUrl;

  /// Duration of the audio (if known)
  final Duration? duration;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Primary color
  final Color? primaryColor;

  const MiniAudioPlayer({
    super.key,
    required this.audioUrl,
    this.duration,
    this.theme,
    this.primaryColor,
  });

  @override
  State<MiniAudioPlayer> createState() => _MiniAudioPlayerState();
}

class _MiniAudioPlayerState extends State<MiniAudioPlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupPlayer();
    if (widget.duration != null) {
      _duration = widget.duration!;
    }
  }

  void _setupPlayer() {
    _stateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });

    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() => _duration = duration);
      }
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
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.setUrl(widget.audioUrl);
      await _audioPlayer.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final effectivePrimaryColor =
        widget.primaryColor ?? effectiveTheme.colors.primary;

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
              _isPlaying ? Icons.pause : Icons.play_arrow,
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
          _formatDuration(_isPlaying ? _position : _duration),
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
