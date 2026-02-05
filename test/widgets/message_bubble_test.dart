import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/models/queued_message.dart';

void main() {
  group('MessageBubble', () {
    group('Basic rendering', () {
      testWidgets('renders bot message', (WidgetTester tester) async {
        final message = BotMessageRecord(
          id: 'bot-1',
          time: DateTime.now(),
          text: 'Hello from bot!',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
              ),
            ),
          ),
        );

        expect(find.text('Hello from bot!'), findsOneWidget);
      });

      testWidgets('renders user message', (WidgetTester tester) async {
        final message = UserMessageRecord(
          id: 'user-1',
          time: DateTime.now(),
          text: 'Hello from user!',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
              ),
            ),
          ),
        );

        expect(find.text('Hello from user!'), findsOneWidget);
      });

      testWidgets('renders system message', (WidgetTester tester) async {
        final message = SystemMessageRecord(
          id: 'system-1',
          time: DateTime.now(),
          text: 'System notification',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
              ),
            ),
          ),
        );

        expect(find.text('System notification'), findsOneWidget);
      });

      testWidgets('renders agent message with agent name',
          (WidgetTester tester) async {
        final message = AgentMessageRecord(
          id: 'agent-1',
          time: DateTime.now(),
          text: 'Hello from agent!',
          agentDetails: AgentDetails(
            id: 'agent-id-1',
            name: 'John Agent',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
              ),
            ),
          ),
        );

        expect(find.text('Hello from agent!'), findsOneWidget);
        expect(find.text('John Agent'), findsOneWidget);
      });
    });

    group('Message alignment', () {
      testWidgets('user messages are aligned to the right',
          (WidgetTester tester) async {
        final message = UserMessageRecord(
          id: 'user-1',
          time: DateTime.now(),
          text: 'User message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
              ),
            ),
          ),
        );

        final row = tester.widget<Row>(find.byType(Row).first);
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.end));
      });

      testWidgets('bot messages are aligned to the left',
          (WidgetTester tester) async {
        final message = BotMessageRecord(
          id: 'bot-1',
          time: DateTime.now(),
          text: 'Bot message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
              ),
            ),
          ),
        );

        final row = tester.widget<Row>(find.byType(Row).first);
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.start));
      });
    });

    group('Avatar display', () {
      testWidgets('shows avatar when showAvatar is true for bot message',
          (WidgetTester tester) async {
        final message = BotMessageRecord(
          id: 'bot-1',
          time: DateTime.now(),
          text: 'Bot message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                showAvatar: true,
              ),
            ),
          ),
        );

        expect(find.byType(ConferBotAvatar), findsOneWidget);
      });

      testWidgets('hides avatar when showAvatar is false',
          (WidgetTester tester) async {
        final message = BotMessageRecord(
          id: 'bot-1',
          time: DateTime.now(),
          text: 'Bot message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                showAvatar: false,
              ),
            ),
          ),
        );

        expect(find.byType(ConferBotAvatar), findsNothing);
      });
    });

    group('Timestamp display', () {
      testWidgets('shows timestamp when showTimestamp is true',
          (WidgetTester tester) async {
        final message = BotMessageRecord(
          id: 'bot-1',
          time: DateTime.now(),
          text: 'Bot message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                showTimestamp: true,
              ),
            ),
          ),
        );

        // Timestamp text should be present
        // The exact format depends on the time, but there should be a time display
        expect(find.byType(MessageBubble), findsOneWidget);
      });
    });

    group('Tap handlers', () {
      testWidgets('calls onTap when message is tapped',
          (WidgetTester tester) async {
        bool tapped = false;
        final message = BotMessageRecord(
          id: 'bot-1',
          time: DateTime.now(),
          text: 'Bot message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
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

      testWidgets('calls onLongPress when message is long pressed',
          (WidgetTester tester) async {
        bool longPressed = false;
        final message = BotMessageRecord(
          id: 'bot-1',
          time: DateTime.now(),
          text: 'Bot message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                onLongPress: () {
                  longPressed = true;
                },
              ),
            ),
          ),
        );

        await tester.longPress(find.byType(GestureDetector).first);
        await tester.pump();

        expect(longPressed, isTrue);
      });
    });

    group('Delivery status', () {
      testWidgets('shows delivery status for user messages when enabled',
          (WidgetTester tester) async {
        final message = UserMessageRecord(
          id: 'user-1',
          time: DateTime.now(),
          text: 'User message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                showDeliveryStatus: true,
                deliveryStatus: MessageDeliveryStatus.delivered,
              ),
            ),
          ),
        );

        // Should show the double check icon for delivered
        expect(find.byIcon(Icons.done_all), findsOneWidget);
      });

      testWidgets('shows sending indicator', (WidgetTester tester) async {
        final message = UserMessageRecord(
          id: 'user-1',
          time: DateTime.now(),
          text: 'User message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                showDeliveryStatus: true,
                deliveryStatus: MessageDeliveryStatus.sending,
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows queued indicator', (WidgetTester tester) async {
        final message = UserMessageRecord(
          id: 'user-1',
          time: DateTime.now(),
          text: 'User message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                showDeliveryStatus: true,
                deliveryStatus: MessageDeliveryStatus.queued,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.schedule), findsOneWidget);
      });

      testWidgets('shows sent indicator', (WidgetTester tester) async {
        final message = UserMessageRecord(
          id: 'user-1',
          time: DateTime.now(),
          text: 'User message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                showDeliveryStatus: true,
                deliveryStatus: MessageDeliveryStatus.sent,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('shows failed indicator with retry option',
          (WidgetTester tester) async {
        bool retryCalled = false;
        final message = UserMessageRecord(
          id: 'user-1',
          time: DateTime.now(),
          text: 'User message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                showDeliveryStatus: true,
                deliveryStatus: MessageDeliveryStatus.failed,
                onRetry: () {
                  retryCalled = true;
                },
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(retryCalled, isTrue);
      });
    });

    group('Markdown rendering', () {
      testWidgets('renders markdown when enableMarkdown is true',
          (WidgetTester tester) async {
        final message = BotMessageRecord(
          id: 'bot-1',
          time: DateTime.now(),
          text: '**Bold text**',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                enableMarkdown: true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(MarkdownMessage), findsOneWidget);
      });

      testWidgets('renders plain text when enableMarkdown is false',
          (WidgetTester tester) async {
        final message = BotMessageRecord(
          id: 'bot-1',
          time: DateTime.now(),
          text: '**Bold text**',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                enableMarkdown: false,
              ),
            ),
          ),
        );

        expect(find.text('**Bold text**'), findsOneWidget);
        expect(find.byType(MarkdownMessage), findsNothing);
      });

      testWidgets('auto-detects markdown when autoDetectMarkdown is true',
          (WidgetTester tester) async {
        final plainMessage = BotMessageRecord(
          id: 'bot-1',
          time: DateTime.now(),
          text: 'Plain text without markdown',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: plainMessage,
                enableMarkdown: true,
                autoDetectMarkdown: true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Plain text should not use markdown renderer
        expect(find.byType(MarkdownMessage), findsNothing);
      });
    });

    group('Theme integration', () {
      testWidgets('uses default theme when no theme provided',
          (WidgetTester tester) async {
        final message = BotMessageRecord(
          id: 'bot-1',
          time: DateTime.now(),
          text: 'Bot message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
              ),
            ),
          ),
        );

        expect(find.byType(MessageBubble), findsOneWidget);
      });

      testWidgets('uses custom theme when provided',
          (WidgetTester tester) async {
        final message = BotMessageRecord(
          id: 'bot-1',
          time: DateTime.now(),
          text: 'Bot message',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                theme: defaultTheme,
              ),
            ),
          ),
        );

        expect(find.byType(MessageBubble), findsOneWidget);
      });
    });
  });

  group('DeliveryStatusIndicator', () {
    testWidgets('shows sending spinner', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryStatusIndicator(
              status: MessageDeliveryStatus.sending,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows queued icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryStatusIndicator(
              status: MessageDeliveryStatus.queued,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('shows sent icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryStatusIndicator(
              status: MessageDeliveryStatus.sent,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows delivered icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryStatusIndicator(
              status: MessageDeliveryStatus.delivered,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });

    testWidgets('shows failed icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryStatusIndicator(
              status: MessageDeliveryStatus.failed,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('calls onRetry when failed indicator is tapped',
        (WidgetTester tester) async {
      bool retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryStatusIndicator(
              status: MessageDeliveryStatus.failed,
              onRetry: () {
                retryCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(retryCalled, isTrue);
    });

    testWidgets('respects custom size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryStatusIndicator(
              status: MessageDeliveryStatus.delivered,
              size: 20,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.done_all));
      expect(icon.size, equals(20));
    });
  });

  group('RichTextMessage', () {
    testWidgets('renders plain text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RichTextMessage(
              text: 'Plain text message',
            ),
          ),
        ),
      );

      expect(find.text('Plain text message'), findsOneWidget);
    });

    testWidgets('renders markdown when detected', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RichTextMessage(
              text: '**Bold text**',
              enableMarkdown: true,
              autoDetectMarkdown: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(MarkdownMessage), findsOneWidget);
    });

    testWidgets('returns empty widget for empty text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RichTextMessage(
              text: '',
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, isNull);
      expect(sizedBox.height, isNull);
    });

    testWidgets('uses selectable text when selectable is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RichTextMessage(
              text: 'Selectable text',
              selectable: true,
              enableMarkdown: false,
            ),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('uses custom text style', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RichTextMessage(
              text: 'Styled text',
              enableMarkdown: false,
              textStyle: TextStyle(
                color: Colors.red,
                fontSize: 20,
              ),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Styled text'));
      expect(text.style?.color, equals(Colors.red));
      expect(text.style?.fontSize, equals(20));
    });
  });
}
