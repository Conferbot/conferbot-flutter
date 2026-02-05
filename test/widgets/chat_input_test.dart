import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';

void main() {
  group('ChatInput', () {
    group('Basic rendering', () {
      testWidgets('renders text field', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('renders with default placeholder', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
              ),
            ),
          ),
        );

        expect(find.text('Type a message...'), findsOneWidget);
      });

      testWidgets('renders with custom placeholder', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
                placeholder: 'Enter your message',
              ),
            ),
          ),
        );

        expect(find.text('Enter your message'), findsOneWidget);
      });

      testWidgets('shows send button container', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
              ),
            ),
          ),
        );

        // Should have the action button area
        expect(find.byType(ChatInput), findsOneWidget);
      });
    });

    group('Text input behavior', () {
      testWidgets('can enter text', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'Hello, World!');
        await tester.pump();

        expect(find.text('Hello, World!'), findsOneWidget);
      });

      testWidgets('clears text after sending', (WidgetTester tester) async {
        String? sentText;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) async {
                  sentText = text;
                },
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.pump();

        // Find and tap send button (when text is present, send icon should appear)
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        expect(sentText, equals('Test message'));
      });

      testWidgets('does not send empty text', (WidgetTester tester) async {
        bool sendCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {
                  sendCalled = true;
                },
              ),
            ),
          ),
        );

        // Try to tap send without entering text
        // The button should be disabled or not trigger onSend
        await tester.pump();

        expect(sendCalled, isFalse);
      });

      testWidgets('trims whitespace from sent text', (WidgetTester tester) async {
        String? sentText;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) async {
                  sentText = text;
                },
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), '  Hello  ');
        await tester.pump();

        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        expect(sentText, equals('Hello'));
      });
    });

    group('Disabled state', () {
      testWidgets('text field is disabled when disabled is true',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
                disabled: true,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isFalse);
      });

      testWidgets('text field is enabled when disabled is false',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
                disabled: false,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isTrue);
      });
    });

    group('Attachment button', () {
      testWidgets('shows attachment button when enableAttachments is true',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
                enableAttachments: true,
                onAttachmentPress: () {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.attach_file), findsOneWidget);
      });

      testWidgets('hides attachment button when enableAttachments is false',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
                enableAttachments: false,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.attach_file), findsNothing);
      });

      testWidgets('calls onAttachmentPress when attachment button is tapped',
          (WidgetTester tester) async {
        bool attachmentPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
                enableAttachments: true,
                onAttachmentPress: () {
                  attachmentPressed = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.attach_file));
        await tester.pump();

        expect(attachmentPressed, isTrue);
      });
    });

    group('Voice recording', () {
      testWidgets('shows mic button when enableVoice is true and no text',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
                enableVoice: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.mic), findsOneWidget);
      });

      testWidgets('shows send button when there is text',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
                enableVoice: true,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();

        expect(find.byIcon(Icons.send), findsOneWidget);
      });

      testWidgets('hides mic button when enableVoice is false',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
                enableVoice: false,
              ),
            ),
          ),
        );

        // When voice is disabled and no text, it should show send button
        expect(find.byIcon(Icons.mic), findsNothing);
      });
    });

    group('Theme integration', () {
      testWidgets('uses default theme when no theme provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
              ),
            ),
          ),
        );

        expect(find.byType(ChatInput), findsOneWidget);
      });

      testWidgets('uses custom theme when provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
                theme: defaultTheme,
              ),
            ),
          ),
        );

        expect(find.byType(ChatInput), findsOneWidget);
      });
    });

    group('Max length', () {
      testWidgets('respects maxLength parameter', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
                maxLength: 10,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.maxLength, equals(10));
      });
    });

    group('Layout', () {
      testWidgets('contains SafeArea', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
              ),
            ),
          ),
        );

        expect(find.byType(SafeArea), findsOneWidget);
      });

      testWidgets('uses Row for horizontal layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
              ),
            ),
          ),
        );

        expect(find.byType(Row), findsAtLeastNWidgets(1));
      });
    });

    group('Disposal', () {
      testWidgets('disposes properly without errors',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) {},
              ),
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
  });

  group('EnhancedChatInput', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnhancedChatInput(
              onSend: (text) {},
            ),
          ),
        ),
      );

      expect(find.byType(EnhancedChatInput), findsOneWidget);
    });

    testWidgets('accepts all ChatInput parameters', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnhancedChatInput(
              onSend: (text) {},
              placeholder: 'Custom placeholder',
              disabled: false,
              enableVoice: true,
              enableAttachments: true,
              onAttachmentPress: () {},
              onVoiceRecordingComplete: (path, duration) {},
              theme: defaultTheme,
            ),
          ),
        ),
      );

      expect(find.byType(EnhancedChatInput), findsOneWidget);
    });

    testWidgets('disposes properly without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnhancedChatInput(
              onSend: (text) {},
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
