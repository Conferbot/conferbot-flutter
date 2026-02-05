import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/services/connectivity_service.dart';
import 'package:conferbot_flutter/src/services/message_queue_service.dart';

void main() {
  group('OfflineIndicator', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineIndicator(),
          ),
        ),
      );

      expect(find.byType(OfflineIndicator), findsOneWidget);
    });

    testWidgets('accepts custom theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineIndicator(
              theme: defaultTheme,
            ),
          ),
        ),
      );

      expect(find.byType(OfflineIndicator), findsOneWidget);
    });

    testWidgets('accepts custom offline message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineIndicator(
              offlineMessage: 'Custom offline message',
            ),
          ),
        ),
      );

      expect(find.byType(OfflineIndicator), findsOneWidget);
    });

    testWidgets('accepts custom pending message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineIndicator(
              pendingMessage: 'Custom pending message',
            ),
          ),
        ),
      );

      expect(find.byType(OfflineIndicator), findsOneWidget);
    });

    testWidgets('has showPendingCount parameter', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineIndicator(
              showPendingCount: false,
            ),
          ),
        ),
      );

      expect(find.byType(OfflineIndicator), findsOneWidget);
    });

    testWidgets('has autoHide parameter', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineIndicator(
              autoHide: false,
            ),
          ),
        ),
      );

      expect(find.byType(OfflineIndicator), findsOneWidget);
    });

    testWidgets('accepts onRetryAll callback', (WidgetTester tester) async {
      bool callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineIndicator(
              onRetryAll: () {
                callbackCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.byType(OfflineIndicator), findsOneWidget);
      // Note: callback would only be called when conditions are met
      // (online with pending messages)
    });

    testWidgets('disposes properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineIndicator(),
          ),
        ),
      );

      // Replace with different widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // Should not throw
      await tester.pump();
    });
  });

  group('OfflineBadge', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBadge(),
          ),
        ),
      );

      expect(find.byType(OfflineBadge), findsOneWidget);
    });

    testWidgets('accepts custom theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineBadge(
              theme: defaultTheme,
            ),
          ),
        ),
      );

      expect(find.byType(OfflineBadge), findsOneWidget);
    });

    testWidgets('has showWhenOnline parameter', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBadge(
              showWhenOnline: true,
            ),
          ),
        ),
      );

      expect(find.byType(OfflineBadge), findsOneWidget);
    });

    testWidgets('uses ListenableBuilder for connectivity', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBadge(),
          ),
        ),
      );

      expect(find.byType(ListenableBuilder), findsOneWidget);
    });
  });

  group('PendingMessagesIndicator', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PendingMessagesIndicator(),
          ),
        ),
      );

      expect(find.byType(PendingMessagesIndicator), findsOneWidget);
    });

    testWidgets('accepts custom theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PendingMessagesIndicator(
              theme: defaultTheme,
            ),
          ),
        ),
      );

      expect(find.byType(PendingMessagesIndicator), findsOneWidget);
    });

    testWidgets('accepts onTap callback', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PendingMessagesIndicator(
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.byType(PendingMessagesIndicator), findsOneWidget);
    });

    testWidgets('uses ListenableBuilder for message queue', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PendingMessagesIndicator(),
          ),
        ),
      );

      expect(find.byType(ListenableBuilder), findsOneWidget);
    });
  });
}
