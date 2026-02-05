import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/widgets/media/audio_player_widget.dart';

void main() {
  group('AudioPlaybackSpeed', () {
    test('has correct values', () {
      expect(AudioPlaybackSpeed.slow.value, equals(0.5));
      expect(AudioPlaybackSpeed.slow.label, equals('0.5x'));

      expect(AudioPlaybackSpeed.normal.value, equals(1.0));
      expect(AudioPlaybackSpeed.normal.label, equals('1x'));

      expect(AudioPlaybackSpeed.fast.value, equals(1.5));
      expect(AudioPlaybackSpeed.fast.label, equals('1.5x'));

      expect(AudioPlaybackSpeed.faster.value, equals(2.0));
      expect(AudioPlaybackSpeed.faster.label, equals('2x'));
    });

    test('fromValue returns correct enum', () {
      expect(AudioPlaybackSpeed.fromValue(0.5), equals(AudioPlaybackSpeed.slow));
      expect(AudioPlaybackSpeed.fromValue(1.0), equals(AudioPlaybackSpeed.normal));
      expect(AudioPlaybackSpeed.fromValue(1.5), equals(AudioPlaybackSpeed.fast));
      expect(AudioPlaybackSpeed.fromValue(2.0), equals(AudioPlaybackSpeed.faster));
    });

    test('fromValue returns normal for unknown value', () {
      expect(AudioPlaybackSpeed.fromValue(0.75), equals(AudioPlaybackSpeed.normal));
      expect(AudioPlaybackSpeed.fromValue(3.0), equals(AudioPlaybackSpeed.normal));
    });
  });

  group('AudioPlayerConfig', () {
    test('has default values', () {
      const config = AudioPlayerConfig();

      expect(config.autoPlay, isFalse);
      expect(config.showSpeedControl, isTrue);
      expect(config.showWaveform, isTrue);
      expect(config.initialSpeed, equals(AudioPlaybackSpeed.normal));
      expect(config.compactMode, isFalse);
      expect(config.showDownload, isFalse);
    });

    test('accepts custom values', () {
      const config = AudioPlayerConfig(
        autoPlay: true,
        showSpeedControl: false,
        showWaveform: false,
        initialSpeed: AudioPlaybackSpeed.fast,
        compactMode: true,
        showDownload: true,
      );

      expect(config.autoPlay, isTrue);
      expect(config.showSpeedControl, isFalse);
      expect(config.showWaveform, isFalse);
      expect(config.initialSpeed, equals(AudioPlaybackSpeed.fast));
      expect(config.compactMode, isTrue);
      expect(config.showDownload, isTrue);
    });
  });

  group('AudioPlayerWidget', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              audioUrl: 'https://example.com/audio.mp3',
            ),
          ),
        ),
      );

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('renders title when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              audioUrl: 'https://example.com/audio.mp3',
              title: 'Audio Title',
            ),
          ),
        ),
      );

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('uses default config when no config provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              audioUrl: 'https://example.com/audio.mp3',
            ),
          ),
        ),
      );

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('uses custom config when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              audioUrl: 'https://example.com/audio.mp3',
              config: const AudioPlayerConfig(
                showSpeedControl: false,
                compactMode: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('uses default theme when no theme provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              audioUrl: 'https://example.com/audio.mp3',
            ),
          ),
        ),
      );

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('uses custom theme when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              audioUrl: 'https://example.com/audio.mp3',
              theme: defaultTheme,
            ),
          ),
        ),
      );

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('accepts custom primaryColor', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              audioUrl: 'https://example.com/audio.mp3',
              primaryColor: Colors.red,
            ),
          ),
        ),
      );

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('accepts isUserMessage styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              audioUrl: 'https://example.com/audio.mp3',
              isUserMessage: true,
            ),
          ),
        ),
      );

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('accepts custom playerId', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              audioUrl: 'https://example.com/audio.mp3',
              playerId: 'custom-audio-player',
            ),
          ),
        ),
      );

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('accepts waveformData', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              audioUrl: 'https://example.com/audio.mp3',
              waveformData: [0.1, 0.5, 0.8, 0.3, 0.6, 0.2],
            ),
          ),
        ),
      );

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('disposes properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              audioUrl: 'https://example.com/audio.mp3',
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
