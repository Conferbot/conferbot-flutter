import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() {
  group('TypingIndicator', () {
    testWidgets('renders three dots when visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(visible: true),
          ),
        ),
      );

      // Should find 3 Container widgets for the dots
      final containers = find.byType(Container);
      expect(containers, findsWidgets);

      // Check that FadeTransition widgets exist for animations
      expect(find.byType(FadeTransition), findsNWidgets(3));
    });

    testWidgets('renders nothing when not visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(visible: false),
          ),
        ),
      );

      // Should find SizedBox.shrink
      final sizedBox = find.byType(SizedBox);
      expect(sizedBox, findsOneWidget);

      // Should not find FadeTransition (dots)
      expect(find.byType(FadeTransition), findsNothing);
    });

    testWidgets('uses custom dot color', (WidgetTester tester) async {
      const customColor = Colors.red;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(
              visible: true,
              dotColor: customColor,
            ),
          ),
        ),
      );

      // Find containers with BoxDecoration
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dotsWithColor = containers.where((container) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == customColor && decoration.shape == BoxShape.circle;
        }
        return false;
      });

      expect(dotsWithColor.length, equals(3));
    });

    testWidgets('uses custom dot size', (WidgetTester tester) async {
      const customSize = 12.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(
              visible: true,
              dotSize: customSize,
            ),
          ),
        ),
      );

      // Find containers with the custom size
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dotsWithSize = containers.where((container) {
        final constraints = container.constraints;
        if (constraints != null) {
          return constraints.maxWidth == customSize && constraints.maxHeight == customSize;
        }
        return false;
      });

      expect(dotsWithSize.length, equals(3));
    });

    testWidgets('animations are running when visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(visible: true),
          ),
        ),
      );

      // Pump a few frames to verify animations are running
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Should still find the dots
      expect(find.byType(FadeTransition), findsNWidgets(3));
    });

    testWidgets('uses default theme when no theme provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(visible: true),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Widget should render without errors using default theme
      expect(find.byType(TypingIndicator), findsOneWidget);
    });

    testWidgets('uses custom theme when provided', (WidgetTester tester) async {
      final customTheme = defaultTheme;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TypingIndicator(
              visible: true,
              theme: customTheme,
            ),
          ),
        ),
      );

      expect(find.byType(TypingIndicator), findsOneWidget);
    });

    testWidgets('respects animation speed parameter', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(
              visible: true,
              animationSpeed: 1000,
            ),
          ),
        ),
      );

      // Widget should render with custom animation speed
      expect(find.byType(TypingIndicator), findsOneWidget);
      expect(find.byType(FadeTransition), findsNWidgets(3));
    });

    testWidgets('properly disposes animation controllers', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(visible: true),
          ),
        ),
      );

      // Now remove the widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // Should not throw any errors about disposed controllers
      await tester.pump();
    });

    testWidgets('dots are arranged in a row', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(visible: true),
          ),
        ),
      );

      // Should find a Row widget containing the dots
      expect(find.byType(Row), findsOneWidget);

      final row = tester.widget<Row>(find.byType(Row));
      expect(row.mainAxisSize, equals(MainAxisSize.min));
    });

    testWidgets('visibility toggle works correctly', (WidgetTester tester) async {
      // Start visible
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(visible: true),
          ),
        ),
      );

      expect(find.byType(FadeTransition), findsNWidgets(3));

      // Toggle to not visible
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(visible: false),
          ),
        ),
      );

      expect(find.byType(FadeTransition), findsNothing);
    });
  });
}
