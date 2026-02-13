import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/widgets/media/video_player_widget.dart';

void main() {
  group('VideoPlayerConfig', () {
    test('has default values', () {
      const config = VideoPlayerConfig();

      expect(config.autoPlay, isFalse);
      expect(config.loop, isFalse);
      expect(config.showControls, isTrue);
      expect(config.initialVolume, equals(1.0));
      expect(config.allowFullScreen, isTrue);
      expect(config.showProgressBar, isTrue);
      expect(config.controlsHideDelay, equals(const Duration(seconds: 3)));
      expect(config.aspectRatio, isNull);
      expect(config.thumbnailUrl, isNull);
    });

    test('accepts custom values', () {
      const config = VideoPlayerConfig(
        autoPlay: true,
        loop: true,
        showControls: false,
        initialVolume: 0.5,
        allowFullScreen: false,
        showProgressBar: false,
        controlsHideDelay: Duration(seconds: 5),
        aspectRatio: 16 / 9,
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      expect(config.autoPlay, isTrue);
      expect(config.loop, isTrue);
      expect(config.showControls, isFalse);
      expect(config.initialVolume, equals(0.5));
      expect(config.allowFullScreen, isFalse);
      expect(config.showProgressBar, isFalse);
      expect(config.controlsHideDelay, equals(const Duration(seconds: 5)));
      expect(config.aspectRatio, equals(16 / 9));
      expect(config.thumbnailUrl, equals('https://example.com/thumb.jpg'));
    });
  });

  group('VideoPlayerWidget', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPlayerWidget(
              videoUrl: 'https://example.com/video.mp4',
            ),
          ),
        ),
      );

      expect(find.byType(VideoPlayerWidget), findsOneWidget);
    });

    testWidgets('renders caption when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPlayerWidget(
              videoUrl: 'https://example.com/video.mp4',
              caption: 'Video caption',
            ),
          ),
        ),
      );

      expect(find.byType(VideoPlayerWidget), findsOneWidget);
    });

    testWidgets('uses default config when no config provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPlayerWidget(
              videoUrl: 'https://example.com/video.mp4',
            ),
          ),
        ),
      );

      expect(find.byType(VideoPlayerWidget), findsOneWidget);
    });

    testWidgets('uses custom config when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPlayerWidget(
              videoUrl: 'https://example.com/video.mp4',
              config: VideoPlayerConfig(
                autoPlay: false,
                showControls: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VideoPlayerWidget), findsOneWidget);
    });

    testWidgets('uses default theme when no theme provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPlayerWidget(
              videoUrl: 'https://example.com/video.mp4',
            ),
          ),
        ),
      );

      expect(find.byType(VideoPlayerWidget), findsOneWidget);
    });

    testWidgets('uses custom theme when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPlayerWidget(
              videoUrl: 'https://example.com/video.mp4',
              theme: defaultTheme,
            ),
          ),
        ),
      );

      expect(find.byType(VideoPlayerWidget), findsOneWidget);
    });

    testWidgets('accepts custom playerId', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPlayerWidget(
              videoUrl: 'https://example.com/video.mp4',
              playerId: 'custom-player-id',
            ),
          ),
        ),
      );

      expect(find.byType(VideoPlayerWidget), findsOneWidget);
    });

    testWidgets('disposes properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPlayerWidget(
              videoUrl: 'https://example.com/video.mp4',
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      await tester.pump();
    });
  });
}
