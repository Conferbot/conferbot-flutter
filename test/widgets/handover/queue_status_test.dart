import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/widgets/handover/queue_status.dart';

void main() {
  group('QueueInfo', () {
    test('creates from constructor', () {
      const info = QueueInfo(
        position: 3,
        estimatedWaitSeconds: 120,
      );

      expect(info.position, equals(3));
      expect(info.estimatedWaitSeconds, equals(120));
      expect(info.agentsAvailable, isTrue);
      expect(info.isConnecting, isFalse);
    });

    test('creates from JSON', () {
      final json = {
        'position': 5,
        'estimatedWaitSeconds': 300,
        'agentsAvailable': false,
        'availableAgentCount': 0,
        'statusMessage': 'Please wait',
        'isConnecting': true,
      };

      final info = QueueInfo.fromJson(json);

      expect(info.position, equals(5));
      expect(info.estimatedWaitSeconds, equals(300));
      expect(info.agentsAvailable, isFalse);
      expect(info.availableAgentCount, equals(0));
      expect(info.statusMessage, equals('Please wait'));
      expect(info.isConnecting, isTrue);
    });

    test('handles estimatedWait fallback in JSON', () {
      final json = {
        'position': 1,
        'estimatedWait': 90,
      };

      final info = QueueInfo.fromJson(json);

      expect(info.estimatedWaitSeconds, equals(90));
    });

    test('copyWith creates new instance', () {
      const original = QueueInfo(
        position: 1,
        estimatedWaitSeconds: 60,
      );

      final copied = original.copyWith(position: 2);

      expect(copied.position, equals(2));
      expect(copied.estimatedWaitSeconds, equals(60));
    });
  });

  group('QueueStatusWidget', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueStatusWidget(
                maxWaitMinutes: 5,
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(QueueStatusWidget), findsOneWidget);
    });

    testWidgets('shows default connecting message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueStatusWidget(
                maxWaitMinutes: 5,
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Connecting you to an agent...'), findsOneWidget);
    });

    testWidgets('shows custom handover message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueStatusWidget(
                maxWaitMinutes: 5,
                primaryColor: Colors.blue,
                handoverMessage: 'Custom handover message',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Custom handover message'), findsOneWidget);
    });

    testWidgets('shows queue position when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueStatusWidget(
                maxWaitMinutes: 5,
                primaryColor: Colors.blue,
                queueInfo: const QueueInfo(
                  position: 3,
                  estimatedWaitSeconds: 120,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('#3'), findsOneWidget);
    });

    testWidgets('shows cancel button when onCancel is provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueStatusWidget(
                maxWaitMinutes: 5,
                primaryColor: Colors.blue,
                onCancel: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Leave Queue'), findsOneWidget);
    });

    testWidgets('calls onCancel when cancel button is tapped',
        (WidgetTester tester) async {
      bool cancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueStatusWidget(
                maxWaitMinutes: 5,
                primaryColor: Colors.blue,
                onCancel: () {
                  cancelCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Leave Queue'));
      await tester.pump();

      expect(cancelCalled, isTrue);
    });

    testWidgets('shows status message when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueStatusWidget(
                maxWaitMinutes: 5,
                primaryColor: Colors.blue,
                queueInfo: const QueueInfo(
                  position: 1,
                  estimatedWaitSeconds: 60,
                  statusMessage: 'You are next in line!',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('You are next in line!'), findsOneWidget);
    });

    testWidgets('shows agent availability', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueStatusWidget(
                maxWaitMinutes: 5,
                primaryColor: Colors.blue,
                showAgentAvailability: true,
                queueInfo: const QueueInfo(
                  position: 1,
                  estimatedWaitSeconds: 60,
                  agentsAvailable: true,
                  availableAgentCount: 2,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('2 agents available'), findsOneWidget);
    });

    testWidgets('shows busy agents message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueStatusWidget(
                maxWaitMinutes: 5,
                primaryColor: Colors.blue,
                showAgentAvailability: true,
                queueInfo: const QueueInfo(
                  position: 1,
                  estimatedWaitSeconds: 60,
                  agentsAvailable: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('All agents busy'), findsOneWidget);
    });

    testWidgets('shows progress bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueStatusWidget(
                maxWaitMinutes: 5,
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows max wait time info', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueStatusWidget(
                maxWaitMinutes: 5,
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Max wait: 5 min'), findsOneWidget);
    });

    testWidgets('disposes properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueStatusWidget(
                maxWaitMinutes: 5,
                primaryColor: Colors.blue,
              ),
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

  group('CompactQueueStatus', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactQueueStatus(
              maxWaitMinutes: 5,
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byType(CompactQueueStatus), findsOneWidget);
    });

    testWidgets('shows position when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactQueueStatus(
              maxWaitMinutes: 5,
              primaryColor: Colors.blue,
              queueInfo: const QueueInfo(
                position: 2,
                estimatedWaitSeconds: 120,
              ),
            ),
          ),
        ),
      );

      expect(find.text('#2'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactQueueStatus(
              maxWaitMinutes: 5,
              primaryColor: Colors.blue,
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

    testWidgets('shows time icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactQueueStatus(
              maxWaitMinutes: 5,
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('disposes properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactQueueStatus(
              maxWaitMinutes: 5,
              primaryColor: Colors.blue,
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

  group('WaitingIndicator', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaitingIndicator(
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byType(WaitingIndicator), findsOneWidget);
    });

    testWidgets('respects custom size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaitingIndicator(
              primaryColor: Colors.blue,
              size: 60,
            ),
          ),
        ),
      );

      expect(find.byType(WaitingIndicator), findsOneWidget);
    });

    testWidgets('disposes properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaitingIndicator(
              primaryColor: Colors.blue,
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
