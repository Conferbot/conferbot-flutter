import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/widgets/media/image_viewer.dart';

void main() {
  group('ImageViewerConfig', () {
    test('has default values', () {
      const config = ImageViewerConfig();

      expect(config.minScale, equals(0.5));
      expect(config.maxScale, equals(4.0));
      expect(config.initialScale, equals(1.0));
      expect(config.enableDoubleTapZoom, isTrue);
      expect(config.enableSwipeToDismiss, isTrue);
      expect(config.backgroundColor, equals(Colors.black));
    });

    test('accepts custom values', () {
      const config = ImageViewerConfig(
        minScale: 0.25,
        maxScale: 8.0,
        initialScale: 2.0,
        enableDoubleTapZoom: false,
        enableSwipeToDismiss: false,
        backgroundColor: Colors.white,
        animationDuration: Duration(milliseconds: 500),
      );

      expect(config.minScale, equals(0.25));
      expect(config.maxScale, equals(8.0));
      expect(config.initialScale, equals(2.0));
      expect(config.enableDoubleTapZoom, isFalse);
      expect(config.enableSwipeToDismiss, isFalse);
      expect(config.backgroundColor, equals(Colors.white));
      expect(config.animationDuration, equals(const Duration(milliseconds: 500)));
    });
  });

  group('ImageItem', () {
    test('creates from constructor', () {
      const item = ImageItem(
        url: 'https://example.com/image.png',
        caption: 'Test caption',
        heroTag: 'hero-1',
      );

      expect(item.url, equals('https://example.com/image.png'));
      expect(item.caption, equals('Test caption'));
      expect(item.heroTag, equals('hero-1'));
    });

    test('optional fields are nullable', () {
      const item = ImageItem(
        url: 'https://example.com/image.png',
      );

      expect(item.url, equals('https://example.com/image.png'));
      expect(item.caption, isNull);
      expect(item.heroTag, isNull);
    });
  });

  group('ImageThumbnail', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageThumbnail(
              imageUrl: 'https://example.com/image.png',
            ),
          ),
        ),
      );

      expect(find.byType(ImageThumbnail), findsOneWidget);
    });

    testWidgets('renders caption when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageThumbnail(
              imageUrl: 'https://example.com/image.png',
              caption: 'Image caption',
            ),
          ),
        ),
      );

      expect(find.text('Image caption'), findsOneWidget);
    });

    testWidgets('uses GestureDetector for tap handling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageThumbnail(
              imageUrl: 'https://example.com/image.png',
            ),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageThumbnail(
              imageUrl: 'https://example.com/image.png',
              openFullScreenOnTap: false,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('respects maxHeight constraint', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageThumbnail(
              imageUrl: 'https://example.com/image.png',
              maxHeight: 200,
            ),
          ),
        ),
      );

      expect(find.byType(ConstrainedBox), findsWidgets);
    });

    testWidgets('uses Hero widget for transitions', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageThumbnail(
              imageUrl: 'https://example.com/image.png',
            ),
          ),
        ),
      );

      expect(find.byType(Hero), findsOneWidget);
    });

    testWidgets('uses custom heroTag when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageThumbnail(
              imageUrl: 'https://example.com/image.png',
              heroTag: 'custom-hero',
            ),
          ),
        ),
      );

      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, equals('custom-hero'));
    });

    testWidgets('uses default theme when no theme provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageThumbnail(
              imageUrl: 'https://example.com/image.png',
            ),
          ),
        ),
      );

      expect(find.byType(ImageThumbnail), findsOneWidget);
    });

    testWidgets('uses custom theme when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageThumbnail(
              imageUrl: 'https://example.com/image.png',
              theme: defaultTheme,
            ),
          ),
        ),
      );

      expect(find.byType(ImageThumbnail), findsOneWidget);
    });

    testWidgets('uses custom borderRadius', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageThumbnail(
              imageUrl: 'https://example.com/image.png',
              borderRadius: 20,
            ),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });
}
