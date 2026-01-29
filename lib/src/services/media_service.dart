import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

/// Media player types
enum MediaPlayerType {
  audio,
  video,
}

/// Represents an active media player instance
class ActiveMediaPlayer {
  final String id;
  final MediaPlayerType type;
  final dynamic controller; // AudioPlayer or VideoPlayerController
  final VoidCallback? onPause;

  ActiveMediaPlayer({
    required this.id,
    required this.type,
    required this.controller,
    this.onPause,
  });

  /// Pause the player
  Future<void> pause() async {
    if (type == MediaPlayerType.audio) {
      await (controller as AudioPlayer).pause();
    } else if (type == MediaPlayerType.video) {
      await (controller as VideoPlayerController).pause();
    }
    onPause?.call();
  }

  /// Check if currently playing
  bool get isPlaying {
    if (type == MediaPlayerType.audio) {
      return (controller as AudioPlayer).playing;
    } else if (type == MediaPlayerType.video) {
      return (controller as VideoPlayerController).value.isPlaying;
    }
    return false;
  }
}

/// Media Service for managing media playback across the chat widget
///
/// Features:
/// - Single active player management (pause others when one plays)
/// - App lifecycle handling (pause when backgrounded)
/// - Cache management
/// - Cleanup on dispose
class MediaService extends ChangeNotifier {
  static MediaService? _instance;

  /// Singleton instance
  static MediaService get instance {
    _instance ??= MediaService._();
    return _instance!;
  }

  MediaService._();

  /// Factory constructor for dependency injection
  factory MediaService() => instance;

  /// Map of active media players by ID
  final Map<String, ActiveMediaPlayer> _activePlayers = {};

  /// Currently playing player ID
  String? _currentlyPlayingId;

  /// Get the currently playing player ID
  String? get currentlyPlayingId => _currentlyPlayingId;

  /// Whether any media is currently playing
  bool get isAnyPlaying => _currentlyPlayingId != null;

  /// App lifecycle state
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  /// Image cache configuration
  int _maxCachedImages = 100;
  int _maxCacheSize = 100 * 1024 * 1024; // 100MB

  /// Get max cached images count
  int get maxCachedImages => _maxCachedImages;

  /// Get max cache size in bytes
  int get maxCacheSize => _maxCacheSize;

  /// Configure image cache settings
  void configureCacheSettings({
    int? maxCachedImages,
    int? maxCacheSizeBytes,
  }) {
    if (maxCachedImages != null) _maxCachedImages = maxCachedImages;
    if (maxCacheSizeBytes != null) _maxCacheSize = maxCacheSizeBytes;
  }

  /// Register a new media player
  ///
  /// When a player starts playing, other players are automatically paused.
  void registerPlayer(ActiveMediaPlayer player) {
    _activePlayers[player.id] = player;
    debugPrint('[MediaService] Registered player: ${player.id}');
  }

  /// Unregister a media player
  void unregisterPlayer(String playerId) {
    _activePlayers.remove(playerId);
    if (_currentlyPlayingId == playerId) {
      _currentlyPlayingId = null;
    }
    debugPrint('[MediaService] Unregistered player: $playerId');
  }

  /// Notify that a player has started playing
  ///
  /// This will pause all other players.
  Future<void> onPlayerStarted(String playerId) async {
    // Pause all other players
    for (final entry in _activePlayers.entries) {
      if (entry.key != playerId && entry.value.isPlaying) {
        await entry.value.pause();
        debugPrint('[MediaService] Paused player: ${entry.key}');
      }
    }
    _currentlyPlayingId = playerId;
    notifyListeners();
  }

  /// Notify that a player has stopped/paused
  void onPlayerStopped(String playerId) {
    if (_currentlyPlayingId == playerId) {
      _currentlyPlayingId = null;
      notifyListeners();
    }
  }

  /// Pause all active players
  Future<void> pauseAll() async {
    for (final player in _activePlayers.values) {
      if (player.isPlaying) {
        await player.pause();
      }
    }
    _currentlyPlayingId = null;
    notifyListeners();
  }

  /// Handle app lifecycle state changes
  void handleAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Pause all media when app goes to background
        pauseAll();
        debugPrint('[MediaService] App backgrounded - pausing all media');
        break;
      case AppLifecycleState.resumed:
        // Don't auto-resume - let user control playback
        debugPrint('[MediaService] App resumed');
        break;
    }
  }

  /// Check if app is in foreground
  bool get isAppInForeground => _lifecycleState == AppLifecycleState.resumed;

  /// Get a player by ID
  ActiveMediaPlayer? getPlayer(String id) => _activePlayers[id];

  /// Get all active player IDs
  List<String> get activePlayerIds => _activePlayers.keys.toList();

  /// Get count of active players
  int get activePlayerCount => _activePlayers.length;

  /// Clear all image caches
  void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugPrint('[MediaService] Image cache cleared');
  }

  /// Dispose all players and cleanup
  void disposeAll() {
    for (final player in _activePlayers.values) {
      if (player.type == MediaPlayerType.audio) {
        (player.controller as AudioPlayer).dispose();
      } else if (player.type == MediaPlayerType.video) {
        (player.controller as VideoPlayerController).dispose();
      }
    }
    _activePlayers.clear();
    _currentlyPlayingId = null;
    debugPrint('[MediaService] All players disposed');
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  /// Reset the singleton instance (for testing)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}

/// Mixin for widgets that use media players
///
/// Provides automatic lifecycle management and cleanup
mixin MediaPlayerMixin<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  late MediaService _mediaService;

  /// Get the media service instance
  MediaService get mediaService => _mediaService;

  @override
  void initState() {
    super.initState();
    _mediaService = MediaService.instance;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _mediaService.handleAppLifecycleState(state);
  }

  @override
  void didChangeAccessibilityFeatures() {}

  @override
  void didChangeLocales(List<Locale>? locales) {}

  @override
  void didChangeMetrics() {}

  @override
  void didChangePlatformBrightness() {}

  @override
  void didChangeTextScaleFactor() {}

  @override
  void didHaveMemoryPressure() {
    // Clear caches on memory pressure
    _mediaService.clearImageCache();
  }

  @override
  Future<bool> didPopRoute() => Future.value(false);

  @override
  Future<bool> didPushRoute(String route) => Future.value(false);

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) =>
      Future.value(false);

  @override
  Future<AppExitResponse> didRequestAppExit() =>
      Future.value(AppExitResponse.exit);
}

/// Provider widget for MediaService
class MediaServiceProvider extends StatefulWidget {
  final Widget child;

  const MediaServiceProvider({
    super.key,
    required this.child,
  });

  /// Get MediaService from context
  static MediaService of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<_MediaServiceInherited>();
    return provider?.service ?? MediaService.instance;
  }

  @override
  State<MediaServiceProvider> createState() => _MediaServiceProviderState();
}

class _MediaServiceProviderState extends State<MediaServiceProvider>
    with WidgetsBindingObserver {
  late final MediaService _service;

  @override
  void initState() {
    super.initState();
    _service = MediaService.instance;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _service.handleAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return _MediaServiceInherited(
      service: _service,
      child: widget.child,
    );
  }
}

class _MediaServiceInherited extends InheritedWidget {
  final MediaService service;

  const _MediaServiceInherited({
    required this.service,
    required super.child,
  });

  @override
  bool updateShouldNotify(_MediaServiceInherited oldWidget) {
    return service != oldWidget.service;
  }
}
