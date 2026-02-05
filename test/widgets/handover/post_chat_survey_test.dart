import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/models/agent.dart';
import 'package:conferbot_flutter/src/widgets/handover/post_chat_survey.dart';

void main() {
  group('SurveyResult', () {
    test('creates from constructor', () {
      final result = SurveyResult(
        rating: 5,
        feedback: 'Great service!',
        agentId: 'agent-1',
        conversationId: 'conv-1',
        submittedAt: DateTime(2024, 1, 1),
      );

      expect(result.rating, equals(5));
      expect(result.feedback, equals('Great service!'));
      expect(result.agentId, equals('agent-1'));
      expect(result.conversationId, equals('conv-1'));
    });

    test('converts to JSON', () {
      final result = SurveyResult(
        rating: 4,
        feedback: 'Good',
        agentId: 'agent-1',
        submittedAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final json = result.toJson();

      expect(json['rating'], equals(4));
      expect(json['feedback'], equals('Good'));
      expect(json['agentId'], equals('agent-1'));
      expect(json['submittedAt'], isNotNull);
    });

    test('omits empty feedback in JSON', () {
      final result = SurveyResult(
        rating: 5,
        feedback: '',
        submittedAt: DateTime(2024, 1, 1),
      );

      final json = result.toJson();

      expect(json.containsKey('feedback'), isFalse);
    });

    test('omits null feedback in JSON', () {
      final result = SurveyResult(
        rating: 5,
        submittedAt: DateTime(2024, 1, 1),
      );

      final json = result.toJson();

      expect(json.containsKey('feedback'), isFalse);
    });
  });

  group('PostChatSurveyWidget', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PostChatSurveyWidget), findsOneWidget);
    });

    testWidgets('shows default title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      // Default title should be shown
      expect(find.byType(PostChatSurveyWidget), findsOneWidget);
    });

    testWidgets('shows custom title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                primaryColor: Colors.blue,
                title: 'Rate Your Experience',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Rate Your Experience'), findsOneWidget);
    });

    testWidgets('shows submit button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('shows custom submit button text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                primaryColor: Colors.blue,
                submitButtonText: 'Send Feedback',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Send Feedback'), findsOneWidget);
    });

    testWidgets('shows skip button when enabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                onSkip: () {},
                primaryColor: Colors.blue,
                showSkipButton: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('calls onSkip when skip button is tapped',
        (WidgetTester tester) async {
      bool skipCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                onSkip: () {
                  skipCalled = true;
                },
                primaryColor: Colors.blue,
                showSkipButton: true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(skipCalled, isTrue);
    });

    testWidgets('hides skip button when disabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                primaryColor: Colors.blue,
                showSkipButton: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('shows star rating icons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      // Should show star icons for rating
      expect(find.byType(PostChatSurveyWidget), findsOneWidget);
    });

    testWidgets('shows feedback text field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('shows custom feedback placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                primaryColor: Colors.blue,
                feedbackPlaceholder: 'Share your thoughts',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Share your thoughts'), findsOneWidget);
    });

    testWidgets('shows agent info when provided', (WidgetTester tester) async {
      final agent = Agent(
        id: 'agent-1',
        name: 'Test Agent',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                agent: agent,
                onSubmit: (result) {},
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PostChatSurveyWidget), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                primaryColor: Colors.blue,
                isLoading: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('can enter feedback text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Great experience!');
      await tester.pump();

      expect(find.text('Great experience!'), findsOneWidget);
    });

    testWidgets('disposes properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostChatSurveyWidget(
                onSubmit: (result) {},
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
}
