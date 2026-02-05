import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/services/media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MediaService mediaService;

  setUp(() {
    MediaService.reset();
    mediaService = MediaService.instance;
  });

  tearDown(() {
    mediaService.disposeAll();
  });

  group('MediaService Construction', () {
    test('should create singleton instance', () {
      final instance1 = MediaService.instance;
      final instance2 = MediaService.instance;

      expect(identical(instance1, instance2), true);
    });

    test('should start with no active players', () {
      expect(mediaService.activePlayerCount, 0);
      expect(mediaService.activePlayerIds, isEmpty);
      expect(mediaService.currentlyPlayingId, isNull);
      expect(mediaService.isAnyPlaying, false);
    });

    test('should have default cache settings', () {
      expect(mediaService.maxCachedImages, 100);
      expect(mediaService.maxCacheSize, 100 * 1024 * 1024);
    });
  });

  group('MediaService.configureCacheSettings', () {
    test('should update max cached images', () {
      mediaService.configureCacheSettings(maxCachedImages: 50);

      expect(mediaService.maxCachedImages, 50);
    });

    test('should update max cache size', () {
      mediaService.configureCacheSettings(maxCacheSizeBytes: 50 * 1024 * 1024);

      expect(mediaService.maxCacheSize, 50 * 1024 * 1024);
    });

    test('should update both settings', () {
      mediaService.configureCacheSettings(
        maxCachedImages: 200,
        maxCacheSizeBytes: 200 * 1024 * 1024,
      );

      expect(mediaService.maxCachedImages, 200);
      expect(mediaService.maxCacheSize, 200 * 1024 * 1024);
    });
  });

  group('MediaService.registerPlayer', () {
    test('should register audio player', () {
      final player = MockActiveMediaPlayer(
        id: 'audio_1',
        type: MediaPlayerType.audio,
      );

      mediaService.registerPlayer(player);

      expect(mediaService.activePlayerCount, 1);
      expect(mediaService.activePlayerIds, contains('audio_1'));
    });

    test('should register video player', () {
      final player = MockActiveMediaPlayer(
        id: 'video_1',
        type: MediaPlayerType.video,
      );

      mediaService.registerPlayer(player);

      expect(mediaService.activePlayerCount, 1);
      expect(mediaService.activePlayerIds, contains('video_1'));
    });

    test('should register multiple players', () {
      final player1 = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      final player2 = MockActiveMediaPlayer(id: 'video_1', type: MediaPlayerType.video);
      final player3 = MockActiveMediaPlayer(id: 'audio_2', type: MediaPlayerType.audio);

      mediaService.registerPlayer(player1);
      mediaService.registerPlayer(player2);
      mediaService.registerPlayer(player3);

      expect(mediaService.activePlayerCount, 3);
    });
  });

  group('MediaService.unregisterPlayer', () {
    test('should unregister player by ID', () {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      mediaService.registerPlayer(player);

      mediaService.unregisterPlayer('audio_1');

      expect(mediaService.activePlayerCount, 0);
      expect(mediaService.activePlayerIds, isEmpty);
    });

    test('should clear currently playing if unregistered player was playing', () async {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      player.mockIsPlaying = true;
      mediaService.registerPlayer(player);
      await mediaService.onPlayerStarted('audio_1');

      expect(mediaService.currentlyPlayingId, 'audio_1');

      mediaService.unregisterPlayer('audio_1');

      expect(mediaService.currentlyPlayingId, isNull);
    });

    test('should handle unregistering non-existent player', () {
      expect(() => mediaService.unregisterPlayer('non_existent'), returnsNormally);
    });
  });

  group('MediaService.getPlayer', () {
    test('should return registered player', () {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      mediaService.registerPlayer(player);

      final retrieved = mediaService.getPlayer('audio_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'audio_1');
    });

    test('should return null for unregistered player', () {
      final retrieved = mediaService.getPlayer('non_existent');

      expect(retrieved, isNull);
    });
  });

  group('MediaService.onPlayerStarted', () {
    test('should set currently playing player', () async {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      mediaService.registerPlayer(player);

      await mediaService.onPlayerStarted('audio_1');

      expect(mediaService.currentlyPlayingId, 'audio_1');
      expect(mediaService.isAnyPlaying, true);
    });

    test('should pause other playing players', () async {
      final player1 = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      final player2 = MockActiveMediaPlayer(id: 'audio_2', type: MediaPlayerType.audio);
      player1.mockIsPlaying = true;
      player2.mockIsPlaying = false;

      mediaService.registerPlayer(player1);
      mediaService.registerPlayer(player2);
      await mediaService.onPlayerStarted('audio_1');

      player2.mockIsPlaying = true;
      await mediaService.onPlayerStarted('audio_2');

      expect(player1.pauseCallCount, 1);
      expect(mediaService.currentlyPlayingId, 'audio_2');
    });

    test('should notify listeners', () async {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      mediaService.registerPlayer(player);

      var notified = false;
      mediaService.addListener(() => notified = true);

      await mediaService.onPlayerStarted('audio_1');

      expect(notified, true);
    });
  });

  group('MediaService.onPlayerStopped', () {
    test('should clear currently playing if same player', () async {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      mediaService.registerPlayer(player);
      await mediaService.onPlayerStarted('audio_1');

      mediaService.onPlayerStopped('audio_1');

      expect(mediaService.currentlyPlayingId, isNull);
      expect(mediaService.isAnyPlaying, false);
    });

    test('should not clear if different player stopped', () async {
      final player1 = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      final player2 = MockActiveMediaPlayer(id: 'audio_2', type: MediaPlayerType.audio);
      mediaService.registerPlayer(player1);
      mediaService.registerPlayer(player2);
      await mediaService.onPlayerStarted('audio_1');

      mediaService.onPlayerStopped('audio_2');

      expect(mediaService.currentlyPlayingId, 'audio_1');
    });

    test('should notify listeners', () async {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      mediaService.registerPlayer(player);
      await mediaService.onPlayerStarted('audio_1');

      var notified = false;
      mediaService.addListener(() => notified = true);

      mediaService.onPlayerStopped('audio_1');

      expect(notified, true);
    });
  });

  group('MediaService.pauseAll', () {
    test('should pause all playing players', () async {
      final player1 = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      final player2 = MockActiveMediaPlayer(id: 'video_1', type: MediaPlayerType.video);
      player1.mockIsPlaying = true;
      player2.mockIsPlaying = true;

      mediaService.registerPlayer(player1);
      mediaService.registerPlayer(player2);

      await mediaService.pauseAll();

      expect(player1.pauseCallCount, 1);
      expect(player2.pauseCallCount, 1);
      expect(mediaService.currentlyPlayingId, isNull);
    });

    test('should not pause already paused players', () async {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      player.mockIsPlaying = false;
      mediaService.registerPlayer(player);

      await mediaService.pauseAll();

      expect(player.pauseCallCount, 0);
    });

    test('should notify listeners', () async {
      var notified = false;
      mediaService.addListener(() => notified = true);

      await mediaService.pauseAll();

      expect(notified, true);
    });
  });

  group('MediaService.handleAppLifecycleState', () {
    test('should pause all when app goes to background (paused)', () async {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      player.mockIsPlaying = true;
      mediaService.registerPlayer(player);

      mediaService.handleAppLifecycleState(AppLifecycleState.paused);

      expect(player.pauseCallCount, 1);
    });

    test('should pause all when app is inactive', () async {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      player.mockIsPlaying = true;
      mediaService.registerPlayer(player);

      mediaService.handleAppLifecycleState(AppLifecycleState.inactive);

      expect(player.pauseCallCount, 1);
    });

    test('should pause all when app is detached', () async {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      player.mockIsPlaying = true;
      mediaService.registerPlayer(player);

      mediaService.handleAppLifecycleState(AppLifecycleState.detached);

      expect(player.pauseCallCount, 1);
    });

    test('should not auto-resume when app resumes', () async {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      player.mockIsPlaying = true;
      mediaService.registerPlayer(player);

      mediaService.handleAppLifecycleState(AppLifecycleState.paused);
      mediaService.handleAppLifecycleState(AppLifecycleState.resumed);

      // Player should have been paused once, not resumed
      expect(player.pauseCallCount, 1);
    });

    test('should report foreground status correctly', () {
      expect(mediaService.isAppInForeground, true); // Default is resumed

      mediaService.handleAppLifecycleState(AppLifecycleState.paused);
      expect(mediaService.isAppInForeground, false);

      mediaService.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(mediaService.isAppInForeground, true);
    });
  });

  group('MediaService.clearImageCache', () {
    test('should clear image cache without error', () {
      expect(() => mediaService.clearImageCache(), returnsNormally);
    });
  });

  group('MediaService.disposeAll', () {
    test('should dispose all players and clear state', () {
      final player1 = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      final player2 = MockActiveMediaPlayer(id: 'video_1', type: MediaPlayerType.video);
      mediaService.registerPlayer(player1);
      mediaService.registerPlayer(player2);

      mediaService.disposeAll();

      expect(player1.disposeCallCount, 1);
      expect(player2.disposeCallCount, 1);
      expect(mediaService.activePlayerCount, 0);
      expect(mediaService.currentlyPlayingId, isNull);
    });
  });

  group('MediaService.reset', () {
    test('should reset singleton instance', () {
      final instance1 = MediaService.instance;

      MediaService.reset();

      final instance2 = MediaService.instance;

      expect(identical(instance1, instance2), false);
    });
  });

  group('MediaService ChangeNotifier', () {
    test('should notify listeners on state changes', () async {
      var notificationCount = 0;
      mediaService.addListener(() => notificationCount++);

      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      mediaService.registerPlayer(player);

      await mediaService.onPlayerStarted('audio_1');
      mediaService.onPlayerStopped('audio_1');
      await mediaService.pauseAll();

      expect(notificationCount, 3);
    });
  });

  group('ActiveMediaPlayer', () {
    test('should report playing status for audio', () {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);
      player.mockIsPlaying = true;

      expect(player.isPlaying, true);

      player.mockIsPlaying = false;

      expect(player.isPlaying, false);
    });

    test('should report playing status for video', () {
      final player = MockActiveMediaPlayer(id: 'video_1', type: MediaPlayerType.video);
      player.mockIsPlaying = true;

      expect(player.isPlaying, true);
    });

    test('should pause audio player', () async {
      final player = MockActiveMediaPlayer(id: 'audio_1', type: MediaPlayerType.audio);

      await player.pause();

      expect(player.pauseCallCount, 1);
    });

    test('should pause video player', () async {
      final player = MockActiveMediaPlayer(id: 'video_1', type: MediaPlayerType.video);

      await player.pause();

      expect(player.pauseCallCount, 1);
    });

    test('should call onPause callback when pausing', () async {
      var callbackCalled = false;
      final player = MockActiveMediaPlayer(
        id: 'audio_1',
        type: MediaPlayerType.audio,
        onPause: () => callbackCalled = true,
      );

      await player.pause();

      expect(callbackCalled, true);
    });
  });
}

/// Mock implementation of ActiveMediaPlayer for testing
class MockActiveMediaPlayer extends ActiveMediaPlayer {
  bool mockIsPlaying = false;
  int pauseCallCount = 0;
  int disposeCallCount = 0;

  MockActiveMediaPlayer({
    required super.id,
    required super.type,
    super.onPause,
  }) : super(
          controller: MockController(),
        );

  @override
  bool get isPlaying => mockIsPlaying;

  @override
  Future<void> pause() async {
    pauseCallCount++;
    mockIsPlaying = false;
    onPause?.call();
  }
}

/// Mock controller for testing
class MockController {
  bool playing = false;
  int disposeCallCount = 0;

  void pause() {
    playing = false;
  }

  void dispose() {
    disposeCallCount++;
  }
}
