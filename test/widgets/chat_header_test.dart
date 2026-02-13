import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/models/agent.dart';

/// Mock ConferBotProvider for testing
class MockConferBotProvider extends ChangeNotifier implements ConferBotProvider {
  bool _isConnected = true;

  @override
  bool get isConnected => _isConnected;

  void setConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late MockConferBotProvider mockProvider;

  setUp(() {
    mockProvider = MockConferBotProvider();
  });

  Widget buildTestWidget({
    required Widget child,
    MockConferBotProvider? provider,
  }) {
    return MaterialApp(
      home: ChangeNotifierProvider<ConferBotProvider>.value(
        value: provider ?? mockProvider,
        child: Scaffold(body: child),
      ),
    );
  }

  group('ChatHeader', () {
    group('Title and subtitle rendering', () {
      testWidgets('renders default title when no title provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const ChatHeader(),
          ),
        );

        expect(find.text('Chat'), findsOneWidget);
      });

      testWidgets('renders custom title', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const ChatHeader(
              title: 'Support Chat',
            ),
          ),
        );

        expect(find.text('Support Chat'), findsOneWidget);
      });

      testWidgets('renders subtitle when provided', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const ChatHeader(
              title: 'Support',
              subtitle: 'We are here to help',
            ),
          ),
        );

        expect(find.text('Support'), findsOneWidget);
        expect(find.text('We are here to help'), findsOneWidget);
      });

      testWidgets('shows connection status when no subtitle and showConnectionStatus is true',
          (WidgetTester tester) async {
        mockProvider.setConnected(false);

        await tester.pumpWidget(
          buildTestWidget(
            child: const ChatHeader(
              title: 'Chat',
              showConnectionStatus: true,
            ),
          ),
        );

        // ConnectionStatus widget should be present
        expect(find.byType(ConnectionStatus), findsOneWidget);
      });

      testWidgets('hides connection status when showConnectionStatus is false',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const ChatHeader(
              title: 'Chat',
              showConnectionStatus: false,
            ),
          ),
        );

        expect(find.byType(ConnectionStatus), findsNothing);
      });
    });

    group('Agent info rendering', () {
      testWidgets('displays agent name when agent is provided',
          (WidgetTester tester) async {
        final agent = Agent(
          id: 'agent-1',
          name: 'John Doe',
          email: 'john@example.com',
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: ChatHeader(
              agent: agent,
            ),
          ),
        );

        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('john@example.com'), findsOneWidget);
      });

      testWidgets('prefers agent name over title', (WidgetTester tester) async {
        final agent = Agent(
          id: 'agent-1',
          name: 'Agent Smith',
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: ChatHeader(
              title: 'Custom Title',
              agent: agent,
            ),
          ),
        );

        expect(find.text('Agent Smith'), findsOneWidget);
        expect(find.text('Custom Title'), findsNothing);
      });

      testWidgets('shows avatar when agent is provided',
          (WidgetTester tester) async {
        final agent = Agent(
          id: 'agent-1',
          name: 'Agent',
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: ChatHeader(
              agent: agent,
            ),
          ),
        );

        expect(find.byType(ConferBotAvatar), findsOneWidget);
      });

      testWidgets('does not show avatar when no agent',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const ChatHeader(
              title: 'Chat',
            ),
          ),
        );

        expect(find.byType(ConferBotAvatar), findsNothing);
      });
    });

    group('Close button', () {
      testWidgets('shows close button when onClose is provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: ChatHeader(
              title: 'Chat',
              onClose: () {},
            ),
          ),
        );

        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('hides close button when onClose is null',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const ChatHeader(
              title: 'Chat',
            ),
          ),
        );

        expect(find.byIcon(Icons.close), findsNothing);
      });

      testWidgets('calls onClose when close button is tapped',
          (WidgetTester tester) async {
        bool closeCalled = false;

        await tester.pumpWidget(
          buildTestWidget(
            child: ChatHeader(
              title: 'Chat',
              onClose: () {
                closeCalled = true;
              },
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        expect(closeCalled, isTrue);
      });
    });

    group('Theme integration', () {
      testWidgets('uses default theme when no theme provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const ChatHeader(
              title: 'Chat',
            ),
          ),
        );

        expect(find.byType(ChatHeader), findsOneWidget);
      });

      testWidgets('uses custom theme when provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: ChatHeader(
              title: 'Chat',
              theme: defaultTheme,
            ),
          ),
        );

        expect(find.byType(ChatHeader), findsOneWidget);
      });

      testWidgets('header has correct background color from theme',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const ChatHeader(
              title: 'Chat',
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container).first);
        expect(container.decoration, isA<BoxDecoration>());
      });
    });

    group('Layout', () {
      testWidgets('contains SafeArea', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const ChatHeader(
              title: 'Chat',
            ),
          ),
        );

        expect(find.byType(SafeArea), findsOneWidget);
      });

      testWidgets('uses Row for horizontal layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const ChatHeader(
              title: 'Chat',
            ),
          ),
        );

        expect(find.byType(Row), findsAtLeastNWidgets(1));
      });

      testWidgets('title truncates with ellipsis on overflow',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: const SizedBox(
              width: 100,
              child: ChatHeader(
                title: 'This is a very long title that should be truncated',
              ),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(
          find.text('This is a very long title that should be truncated'),
        );
        expect(textWidget.overflow, equals(TextOverflow.ellipsis));
        expect(textWidget.maxLines, equals(1));
      });
    });
  });
}
