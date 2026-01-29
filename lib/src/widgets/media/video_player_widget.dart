import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';
import '../../services/media_service.dart';

/// Video player configuration
class VideoPlayerConfig {
  /// Auto-play video
  final bool autoPlay;

  /// Loop video
  final bool loop;

  /// Show controls
  final bool showControls;

  /// Initial volume (0.0 to 1.0)
  final double initialVolume;

  /// Allow fullscreen
  final bool allowFullScreen;

  /// Show progress bar
  final bool showProgressBar;

  /// Auto-hide controls after duration
  final Duration controlsHideDelay;

  /// Aspect ratio (null for video's native ratio)
  final double? aspectRatio;

  /// Placeholder thumbnail URL
  final String? thumbnailUrl;

  const VideoPlayerConfig({
    this.autoPlay = false,
    this.loop = false,
    this.showControls = true,
    this.initialVolume = 1.0,
    this.allowFullScreen = true,
    this.showProgressBar = true,
    this.controlsHideDelay = const Duration(seconds: 3),
    this.aspectRatio,
    this.thumbnailUrl,
  });
}

/// Video player widget with full controls
///
/// Features:
/// - Play/pause controls
/// - Progress bar with seek
/// - Fullscreen toggle
/// - Volume control
/// - Loading indicator
/// - Error handling
/// - Auto-pause when not visible
class VideoPlayerWidget extends StatefulWidget {
  /// Video URL
  final String videoUrl;

  /// Optional caption
  final String? caption;

  /// Player configuration
  final VideoPlayerConfig config;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Unique ID for media service registration
  final String? playerId;

  /// Callback when video ends
  final VoidCallback? onVideoEnd;

  /// Callback when error occurs
  final ValueChanged<String>? onError;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.caption,
    this.config = const VideoPlayerConfig(),
    this.theme,
    this.playerId,
    this.onVideoEnd,
    this.onError,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  late MediaService _mediaService;
  late String _playerId;

  // State
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;
  bool _isMuted = false;
  double _volume = 1.0;
  Timer? _hideControlsTimer;

  // For visibility detection
  final GlobalKey _videoKey = GlobalKey();
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _mediaService = MediaService.instance;
    _playerId = widget.playerId ?? 'video_${widget.videoUrl.hashCode}';
    _volume = widget.config.initialVolume;
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _mediaService.unregisterPlayer(_playerId);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pause();
    }
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _controller!.initialize();

      _controller!.addListener(_videoListener);

      // Set initial volume
      await _controller!.setVolume(_volume);

      // Set looping
      await _controller!.setLooping(widget.config.loop);

      // Register with media service
      _mediaService.registerPlayer(
        ActiveMediaPlayer(
          id: _playerId,
          type: MediaPlayerType.video,
          controller: _controller!,
          onPause: () {
            if (mounted) {
              setState(() => _isPlaying = false);
            }
          },
        ),
      );

      if (mounted) {
        setState(() => _isInitialized = true);

        // Auto-play if configured
        if (widget.config.autoPlay) {
          _play();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load video';
        });
        widget.onError?.call(e.toString());
      }
      debugPrint('[VideoPlayerWidget] Error initializing: $e');
    }
  }

  void _videoListener() {
    if (!mounted) return;

    final controller = _controller;
    if (controller == null) return;

    // Update playing state
    final isPlaying = controller.value.isPlaying;
    if (_isPlaying != isPlaying) {
      setState(() => _isPlaying = isPlaying);
      if (isPlaying) {
        _mediaService.onPlayerStarted(_playerId);
        _startHideControlsTimer();
      } else {
        _mediaService.onPlayerStopped(_playerId);
      }
    }

    // Update buffering state
    final isBuffering = controller.value.isBuffering;
    if (_isBuffering != isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }

    // Check for completion
    if (controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      widget.onVideoEnd?.call();
    }

    // Check for errors
    if (controller.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = controller.value.errorDescription;
      });
      widget.onError?.call(controller.value.errorDescription ?? 'Unknown error');
    }
  }

  void _play() {
    if (_controller == null || !_isInitialized) return;
    _controller!.play();
  }

  void _pause() {
    if (_controller == null) return;
    _controller!.pause();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
    _showControlsTemporarily();
  }

  void _seek(Duration position) {
    _controller?.seekTo(position);
    _showControlsTemporarily();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller?.setVolume(_isMuted ? 0 : _volume);
    });
    _showControlsTemporarily();
  }

  void _setVolume(double volume) {
    setState(() {
      _volume = volume;
      _isMuted = volume == 0;
      _controller?.setVolume(volume);
    });
  }

  void _showControlsTemporarily() {
    setState(() => _showControls = true);
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(widget.config.controlsHideDelay, () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenVideoPlayer(
          controller: _controller!,
          config: widget.config,
          theme: widget.theme,
          playerId: _playerId,
          mediaService: _mediaService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.lg),
          child: AspectRatio(
            aspectRatio: widget.config.aspectRatio ??
                (_isInitialized
                    ? _controller!.value.aspectRatio
                    : 16 / 9),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video or thumbnail
                if (_isInitialized && _controller != null)
                  GestureDetector(
                    key: _videoKey,
                    onTap: _showControlsTemporarily,
                    child: VideoPlayer(_controller!),
                  )
                else if (widget.config.thumbnailUrl != null)
                  CachedNetworkImage(
                    imageUrl: widget.config.thumbnailUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                else
                  Container(color: Colors.black),

                // Loading indicator
                if (!_isInitialized && !_hasError)
                  _buildLoadingOverlay(effectiveTheme),

                // Buffering indicator
                if (_isBuffering && _isInitialized)
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(
                      effectiveTheme.colors.primary,
                    ),
                  ),

                // Error overlay
                if (_hasError)
                  _buildErrorOverlay(effectiveTheme),

                // Controls overlay
                if (_isInitialized &&
                    widget.config.showControls &&
                    !_hasError)
                  _buildControlsOverlay(effectiveTheme),

                // Big play button when paused
                if (_isInitialized &&
                    !_isPlaying &&
                    !_hasError &&
                    !_showControls)
                  _buildBigPlayButton(effectiveTheme),
              ],
            ),
          ),
        ),
        if (widget.caption != null && widget.caption!.isNotEmpty) ...[
          SizedBox(height: effectiveTheme.spacing.xs),
          Text(
            widget.caption!,
            style: TextStyle(
              fontSize: effectiveTheme.typography.fontSizeSm,
              color: effectiveTheme.colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingOverlay(ConferBotTheme theme) {
    return Container(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation(theme.colors.primary),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(ConferBotTheme theme) {
    return Container(
      color: Colors.black87,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colors.error,
          ),
          SizedBox(height: theme.spacing.sm),
          Text(
            _errorMessage ?? 'Failed to load video',
            style: TextStyle(
              fontSize: theme.typography.fontSizeSm,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.spacing.md),
          TextButton(
            onPressed: () {
              setState(() {
                _hasError = false;
                _errorMessage = null;
              });
              _initializePlayer();
            },
            child: Text(
              'Retry',
              style: TextStyle(color: theme.colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay(ConferBotTheme theme) {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: theme.animations.fast,
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: Container(
          color: Colors.black38,
          child: Column(
            children: [
              // Top bar (fullscreen button)
              if (widget.config.allowFullScreen)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(theme.spacing.sm),
                    child: _buildFullScreenButton(theme),
                  ),
                ),

              // Center play/pause
              Expanded(
                child: Center(
                  child: _buildCenterPlayButton(theme),
                ),
              ),

              // Bottom controls
              _buildBottomControls(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigPlayButton(ConferBotTheme theme) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.play_arrow,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCenterPlayButton(ConferBotTheme theme) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isPlaying ? Icons.pause : Icons.play_arrow,
          size: 32,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFullScreenButton(ConferBotTheme theme) {
    return GestureDetector(
      onTap: _toggleFullScreen,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(theme.borderRadius.sm),
        ),
        child: const Icon(
          Icons.fullscreen,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBottomControls(ConferBotTheme theme) {
    final position = _controller?.value.position ?? Duration.zero;
    final duration = _controller?.value.duration ?? Duration.zero;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          if (widget.config.showProgressBar)
            _buildProgressBar(theme, position, duration),

          SizedBox(height: theme.spacing.xs),

          // Time and volume
          Row(
            children: [
              // Time display
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: TextStyle(
                  fontSize: theme.typography.fontSizeXs,
                  color: Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),

              const Spacer(),

              // Volume button
              GestureDetector(
                onTap: _toggleMute,
                child: Icon(
                  _isMuted
                      ? Icons.volume_off
                      : (_volume > 0.5
                          ? Icons.volume_up
                          : Icons.volume_down),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    ConferBotTheme theme,
    Duration position,
    Duration duration,
  ) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: theme.colors.primary,
        inactiveTrackColor: Colors.white38,
        thumbColor: theme.colors.primary,
        overlayColor: theme.colors.primary.withOpacity(0.2),
      ),
      child: Slider(
        value: progress.clamp(0.0, 1.0),
        onChanged: (value) {
          final newPosition = Duration(
            milliseconds: (value * duration.inMilliseconds).round(),
          );
          _seek(newPosition);
        },
      ),
    );
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

/// Full screen video player
class _FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final VideoPlayerConfig config;
  final ConferBotTheme? theme;
  final String playerId;
  final MediaService mediaService;

  const _FullScreenVideoPlayer({
    required this.controller,
    required this.config,
    this.theme,
    required this.playerId,
    required this.mediaService,
  });

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();

    // Force landscape and hide system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();

    // Restore orientation and system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  void _showControlsTemporarily() {
    setState(() => _showControls = true);
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(widget.config.controlsHideDelay, () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlayPause() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    _showControlsTemporarily();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _showControlsTemporarily,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),

            // Controls overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: effectiveTheme.animations.fast,
              child: Container(
                color: Colors.black38,
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top bar with close button
                      Padding(
                        padding: EdgeInsets.all(effectiveTheme.spacing.sm),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: EdgeInsets.all(
                                    effectiveTheme.spacing.sm),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(
                                    effectiveTheme.borderRadius.sm,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.fullscreen_exit,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Center play button
                      Expanded(
                        child: GestureDetector(
                          onTap: _togglePlayPause,
                          child: Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.controller.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Bottom progress bar
                      Padding(
                        padding: EdgeInsets.all(effectiveTheme.spacing.md),
                        child: _buildProgressBar(effectiveTheme),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(ConferBotTheme theme) {
    final position = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: theme.colors.primary,
            inactiveTrackColor: Colors.white38,
            thumbColor: theme.colors.primary,
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (value) {
              final newPosition = Duration(
                milliseconds: (value * duration.inMilliseconds).round(),
              );
              widget.controller.seekTo(newPosition);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(position),
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                color: Colors.white,
              ),
            ),
            Text(
              _formatDuration(duration),
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
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
