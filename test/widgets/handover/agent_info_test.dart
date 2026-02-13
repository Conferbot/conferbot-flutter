import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/models/agent.dart';
import 'package:conferbot_flutter/src/widgets/handover/agent_info.dart';

void main() {
  Agent createTestAgent({
    String id = 'agent-1',
    String name = 'John Doe',
    String? email,
    String? avatar,
    String? title,
    String? status,
  }) {
    return Agent(
      id: id,
      name: name,
      email: email,
      avatar: avatar,
      title: title,
      status: status,
    );
  }

  group('AgentInfoWidget', () {
    group('Basic rendering', () {
      testWidgets('renders agent name', (WidgetTester tester) async {
        final agent = createTestAgent(name: 'Test Agent');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
              ),
            ),
          ),
        );

        expect(find.text('Test Agent'), findsOneWidget);
      });

      testWidgets('renders agent title when provided', (WidgetTester tester) async {
        final agent = createTestAgent(title: 'Support Manager');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
              ),
            ),
          ),
        );

        expect(find.text('Support Manager'), findsOneWidget);
      });

      testWidgets('renders default status when no title provided',
          (WidgetTester tester) async {
        final agent = createTestAgent();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
              ),
            ),
          ),
        );

        expect(find.text('Support Agent'), findsOneWidget);
      });

      testWidgets('renders custom status text', (WidgetTester tester) async {
        final agent = createTestAgent();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
                customStatus: 'Currently helping you',
              ),
            ),
          ),
        );

        expect(find.text('Currently helping you'), findsOneWidget);
      });
    });

    group('Typing indicator', () {
      testWidgets('shows typing indicator when isTyping is true',
          (WidgetTester tester) async {
        final agent = createTestAgent();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
                isTyping: true,
              ),
            ),
          ),
        );

        expect(find.text('typing'), findsOneWidget);
      });

      testWidgets('hides typing indicator when isTyping is false',
          (WidgetTester tester) async {
        final agent = createTestAgent();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
                isTyping: false,
              ),
            ),
          ),
        );

        expect(find.text('typing'), findsNothing);
      });
    });

    group('Avatar', () {
      testWidgets('renders initials when no avatar provided',
          (WidgetTester tester) async {
        final agent = createTestAgent(name: 'John Doe');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
              ),
            ),
          ),
        );

        expect(find.text('JD'), findsOneWidget);
      });

      testWidgets('renders single initial for single name',
          (WidgetTester tester) async {
        final agent = createTestAgent(name: 'John');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
              ),
            ),
          ),
        );

        expect(find.text('J'), findsOneWidget);
      });
    });

    group('Size variants', () {
      testWidgets('renders small size variant', (WidgetTester tester) async {
        final agent = createTestAgent();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
                size: AgentInfoSize.small,
              ),
            ),
          ),
        );

        expect(find.byType(AgentInfoWidget), findsOneWidget);
      });

      testWidgets('renders medium size variant', (WidgetTester tester) async {
        final agent = createTestAgent();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
                size: AgentInfoSize.medium,
              ),
            ),
          ),
        );

        expect(find.byType(AgentInfoWidget), findsOneWidget);
      });

      testWidgets('renders large size variant', (WidgetTester tester) async {
        final agent = createTestAgent();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
                size: AgentInfoSize.large,
              ),
            ),
          ),
        );

        expect(find.byType(AgentInfoWidget), findsOneWidget);
      });
    });

    group('Online status', () {
      testWidgets('shows online indicator when showOnlineStatus is true',
          (WidgetTester tester) async {
        final agent = createTestAgent();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
                showOnlineStatus: true,
              ),
            ),
          ),
        );

        expect(find.byType(AgentInfoWidget), findsOneWidget);
      });
    });

    group('Interactions', () {
      testWidgets('calls onTap when tapped', (WidgetTester tester) async {
        bool tapped = false;
        final agent = createTestAgent();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
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

      testWidgets('shows chevron when onTap is provided',
          (WidgetTester tester) async {
        final agent = createTestAgent();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentInfoWidget(
                agent: agent,
                primaryColor: Colors.blue,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });
    });
  });

  group('AgentInfoHeader', () {
    testWidgets('renders agent name', (WidgetTester tester) async {
      final agent = createTestAgent(name: 'Header Agent');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentInfoHeader(
              agent: agent,
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Header Agent'), findsOneWidget);
    });

    testWidgets('shows online status', (WidgetTester tester) async {
      final agent = createTestAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentInfoHeader(
              agent: agent,
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('shows typing indicator when agent is typing',
        (WidgetTester tester) async {
      final agent = createTestAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentInfoHeader(
              agent: agent,
              primaryColor: Colors.blue,
              isTyping: true,
            ),
          ),
        ),
      );

      expect(find.text('typing'), findsOneWidget);
      expect(find.text('Online'), findsNothing);
    });

    testWidgets('shows close button when onClose is provided',
        (WidgetTester tester) async {
      final agent = createTestAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentInfoHeader(
              agent: agent,
              primaryColor: Colors.blue,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('hides close button when showCloseButton is false',
        (WidgetTester tester) async {
      final agent = createTestAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentInfoHeader(
              agent: agent,
              primaryColor: Colors.blue,
              showCloseButton: false,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('calls onClose when close button is tapped',
        (WidgetTester tester) async {
      bool closeCalled = false;
      final agent = createTestAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentInfoHeader(
              agent: agent,
              primaryColor: Colors.blue,
              onClose: () {
                closeCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(closeCalled, isTrue);
    });
  });

  group('AgentConnectedBanner', () {
    testWidgets('renders agent connected message', (WidgetTester tester) async {
      final agent = createTestAgent(name: 'Connected Agent');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentConnectedBanner(
              agent: agent,
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Agent Connected'), findsOneWidget);
      expect(find.text('Connected Agent has joined the chat'), findsOneWidget);
    });

    testWidgets('has close button', (WidgetTester tester) async {
      final agent = createTestAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentConnectedBanner(
              agent: agent,
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('has check icon', (WidgetTester tester) async {
      final agent = createTestAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentConnectedBanner(
              agent: agent,
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('disposes properly', (WidgetTester tester) async {
      final agent = createTestAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentConnectedBanner(
              agent: agent,
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

  group('AgentAvatarWithTyping', () {
    testWidgets('renders avatar', (WidgetTester tester) async {
      final agent = createTestAgent(name: 'Avatar Agent');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentAvatarWithTyping(
              agent: agent,
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byType(AgentAvatarWithTyping), findsOneWidget);
    });

    testWidgets('renders initials when no avatar', (WidgetTester tester) async {
      final agent = createTestAgent(name: 'AB Test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentAvatarWithTyping(
              agent: agent,
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('AT'), findsOneWidget);
    });

    testWidgets('shows typing animation when isTyping is true',
        (WidgetTester tester) async {
      final agent = createTestAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentAvatarWithTyping(
              agent: agent,
              primaryColor: Colors.blue,
              isTyping: true,
            ),
          ),
        ),
      );

      expect(find.byType(AgentAvatarWithTyping), findsOneWidget);
    });

    testWidgets('respects custom size', (WidgetTester tester) async {
      final agent = createTestAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentAvatarWithTyping(
              agent: agent,
              primaryColor: Colors.blue,
              size: 60,
            ),
          ),
        ),
      );

      expect(find.byType(AgentAvatarWithTyping), findsOneWidget);
    });
  });

  group('AgentInfoSize enum', () {
    test('has all expected values', () {
      expect(AgentInfoSize.values.length, equals(3));
      expect(AgentInfoSize.values, contains(AgentInfoSize.small));
      expect(AgentInfoSize.values, contains(AgentInfoSize.medium));
      expect(AgentInfoSize.values, contains(AgentInfoSize.large));
    });
  });
}
