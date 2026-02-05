import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() {
  // Helper function to create test messages
  List<RecordItem> createTestMessages(int count) {
    return List.generate(count, (index) => BotMessageRecord(
      id: 'msg-$index',
      time: DateTime.now().subtract(Duration(minutes: count - index)),
      text: 'Test message $index',
    ));
  }

  group('MessageListPaginationConfig', () {
    test('has default values', () {
      const config = MessageListPaginationConfig();

      expect(config.loadMoreThreshold, equals(200.0));
      expect(config.showLoadingIndicator, isTrue);
      expect(config.showJumpToBottom, isTrue);
      expect(config.jumpToBottomThreshold, equals(300.0));
    });

    test('accepts custom values', () {
      const config = MessageListPaginationConfig(
        loadMoreThreshold: 100.0,
        showLoadingIndicator: false,
        showJumpToBottom: false,
        jumpToBottomThreshold: 500.0,
      );

      expect(config.loadMoreThreshold, equals(100.0));
      expect(config.showLoadingIndicator, isFalse);
      expect(config.showJumpToBottom, isFalse);
      expect(config.jumpToBottomThreshold, equals(500.0));
    });
  });

  group('MessageList', () {
    group('Basic rendering', () {
      testWidgets('renders empty state when no messages',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: [],
              ),
            ),
          ),
        );

        // Should show empty state widget
        expect(find.byType(EmptyState), findsOneWidget);
      });

      testWidgets('renders messages list', (WidgetTester tester) async {
        final messages = createTestMessages(3);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
              ),
            ),
          ),
        );

        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(MessageBubble), findsNWidgets(3));
      });

      testWidgets('shows correct message content', (WidgetTester tester) async {
        final messages = [
          BotMessageRecord(
            id: 'msg-1',
            time: DateTime.now(),
            text: 'Hello from bot',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
              ),
            ),
          ),
        );

        expect(find.text('Hello from bot'), findsOneWidget);
      });

      testWidgets('renders custom empty widget when provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: [],
                emptyWidget: Text('No messages here'),
              ),
            ),
          ),
        );

        expect(find.text('No messages here'), findsOneWidget);
        expect(find.byType(EmptyState), findsNothing);
      });
    });

    group('Typing indicator', () {
      testWidgets('shows typing indicator when showTypingIndicator is true',
          (WidgetTester tester) async {
        final messages = createTestMessages(1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
                showTypingIndicator: true,
              ),
            ),
          ),
        );

        expect(find.byType(TypingIndicator), findsOneWidget);
        expect(find.text('Agent is typing...'), findsOneWidget);
      });

      testWidgets('hides typing indicator when showTypingIndicator is false',
          (WidgetTester tester) async {
        final messages = createTestMessages(1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
                showTypingIndicator: false,
              ),
            ),
          ),
        );

        expect(find.byType(TypingIndicator), findsNothing);
      });

      testWidgets('shows typing indicator even with empty messages',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: [],
                showTypingIndicator: true,
              ),
            ),
          ),
        );

        expect(find.byType(TypingIndicator), findsOneWidget);
      });
    });

    group('Pagination', () {
      testWidgets('shows load more indicator when hasMoreMessages is true',
          (WidgetTester tester) async {
        final messages = createTestMessages(5);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
                hasMoreMessages: true,
              ),
            ),
          ),
        );

        expect(find.text('Load older messages'), findsOneWidget);
      });

      testWidgets('shows loading indicator when isLoadingMore is true',
          (WidgetTester tester) async {
        final messages = createTestMessages(5);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
                hasMoreMessages: true,
                isLoadingMore: true,
              ),
            ),
          ),
        );

        expect(find.text('Loading more messages...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('calls onLoadMore when load more button is tapped',
          (WidgetTester tester) async {
        bool loadMoreCalled = false;
        final messages = createTestMessages(5);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
                hasMoreMessages: true,
                onLoadMore: () {
                  loadMoreCalled = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Load older messages'));
        await tester.pump();

        expect(loadMoreCalled, isTrue);
      });
    });

    group('Configuration', () {
      testWidgets('shows avatars when showAvatars is true',
          (WidgetTester tester) async {
        final messages = createTestMessages(1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
                showAvatars: true,
              ),
            ),
          ),
        );

        // MessageBubble should receive showAvatar: true
        expect(find.byType(MessageBubble), findsOneWidget);
      });

      testWidgets('respects showTimestamps parameter',
          (WidgetTester tester) async {
        final messages = createTestMessages(1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
                showTimestamps: true,
              ),
            ),
          ),
        );

        expect(find.byType(MessageList), findsOneWidget);
      });

      testWidgets('respects showDeliveryStatus parameter',
          (WidgetTester tester) async {
        final messages = createTestMessages(1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
                showDeliveryStatus: true,
              ),
            ),
          ),
        );

        expect(find.byType(MessageList), findsOneWidget);
      });
    });

    group('Theme integration', () {
      testWidgets('uses default theme when no theme provided',
          (WidgetTester tester) async {
        final messages = createTestMessages(1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
              ),
            ),
          ),
        );

        expect(find.byType(MessageList), findsOneWidget);
      });

      testWidgets('uses custom theme when provided',
          (WidgetTester tester) async {
        final messages = createTestMessages(1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
                theme: defaultTheme,
              ),
            ),
          ),
        );

        expect(find.byType(MessageList), findsOneWidget);
      });
    });

    group('Disposal', () {
      testWidgets('disposes properly without errors',
          (WidgetTester tester) async {
        final messages = createTestMessages(3);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageList(
                messages: messages,
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
  });

  group('SimpleMessageList', () {
    group('Basic rendering', () {
      testWidgets('renders empty state when no messages',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SimpleMessageList(
                messages: [],
              ),
            ),
          ),
        );

        expect(find.byType(EmptyState), findsOneWidget);
      });

      testWidgets('renders messages list', (WidgetTester tester) async {
        final messages = createTestMessages(3);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SimpleMessageList(
                messages: messages,
              ),
            ),
          ),
        );

        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(MessageBubble), findsNWidgets(3));
      });

      testWidgets('renders custom empty widget when provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SimpleMessageList(
                messages: [],
                emptyWidget: Text('Empty'),
              ),
            ),
          ),
        );

        expect(find.text('Empty'), findsOneWidget);
      });
    });

    group('Typing indicator', () {
      testWidgets('shows typing indicator when enabled',
          (WidgetTester tester) async {
        final messages = createTestMessages(1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SimpleMessageList(
                messages: messages,
                showTypingIndicator: true,
              ),
            ),
          ),
        );

        expect(find.byType(TypingIndicator), findsOneWidget);
      });
    });

    group('Theme integration', () {
      testWidgets('uses custom theme when provided',
          (WidgetTester tester) async {
        final messages = createTestMessages(1);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SimpleMessageList(
                messages: messages,
                theme: defaultTheme,
              ),
            ),
          ),
        );

        expect(find.byType(SimpleMessageList), findsOneWidget);
      });
    });

    group('Disposal', () {
      testWidgets('disposes properly without errors',
          (WidgetTester tester) async {
        final messages = createTestMessages(3);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SimpleMessageList(
                messages: messages,
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
  });
}
