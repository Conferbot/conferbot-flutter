import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/widgets/handover/pre_chat_form.dart';

void main() {
  group('PreChatFormField', () {
    test('creates from constructor', () {
      const field = PreChatFormField(
        id: 'test-id',
        questionText: 'Test question',
        answerType: 'text',
      );

      expect(field.id, equals('test-id'));
      expect(field.questionText, equals('Test question'));
      expect(field.answerType, equals('text'));
      expect(field.required, isTrue);
    });

    test('creates from JSON', () {
      final json = {
        'id': 'json-field',
        'questionText': 'JSON question',
        'answerVariable': 'email',
        'placeholder': 'Enter email',
        'required': false,
      };

      final field = PreChatFormField.fromJson(json);

      expect(field.id, equals('json-field'));
      expect(field.questionText, equals('JSON question'));
      expect(field.answerType, equals('email'));
      expect(field.placeholder, equals('Enter email'));
      expect(field.required, isFalse);
    });

    test('creates name field factory', () {
      final field = PreChatFormField.name();

      expect(field.id, equals('name'));
      expect(field.answerType, equals('name'));
      expect(field.questionText, contains('name'));
    });

    test('creates email field factory', () {
      final field = PreChatFormField.email();

      expect(field.id, equals('email'));
      expect(field.answerType, equals('email'));
      expect(field.questionText, contains('email'));
    });

    test('creates phone field factory', () {
      final field = PreChatFormField.phone();

      expect(field.id, equals('phone'));
      expect(field.answerType, equals('phone'));
      expect(field.questionText, contains('phone'));
    });

    test('creates custom field factory', () {
      final field = PreChatFormField.custom(
        id: 'custom-id',
        questionText: 'Custom question',
        answerType: 'dropdown',
        options: ['Option 1', 'Option 2'],
      );

      expect(field.id, equals('custom-id'));
      expect(field.answerType, equals('dropdown'));
      expect(field.options, contains('Option 1'));
    });
  });

  group('PreChatFormResult', () {
    test('creates from constructor', () {
      const result = PreChatFormResult(
        answers: {'name': 'John'},
        name: 'John',
        email: 'john@example.com',
      );

      expect(result.answers['name'], equals('John'));
      expect(result.name, equals('John'));
      expect(result.email, equals('john@example.com'));
    });

    test('converts to JSON', () {
      const result = PreChatFormResult(
        answers: {'name': 'John'},
        name: 'John',
        email: 'john@example.com',
        phone: '+1234567890',
      );

      final json = result.toJson();

      expect(json['answers'], equals({'name': 'John'}));
      expect(json['name'], equals('John'));
      expect(json['email'], equals('john@example.com'));
      expect(json['phone'], equals('+1234567890'));
    });
  });

  group('PreChatFormWidget', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [
                  PreChatFormField.name(),
                ],
                onSubmit: (result) {},
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PreChatFormWidget), findsOneWidget);
    });

    testWidgets('renders title when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [PreChatFormField.name()],
                onSubmit: (result) {},
                primaryColor: Colors.blue,
                title: 'Start Chat',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Start Chat'), findsOneWidget);
    });

    testWidgets('renders description when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [PreChatFormField.name()],
                onSubmit: (result) {},
                primaryColor: Colors.blue,
                description: 'Please fill in your details',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Please fill in your details'), findsOneWidget);
    });

    testWidgets('renders submit button with default text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [PreChatFormField.name()],
                onSubmit: (result) {},
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Start Chat'), findsOneWidget);
    });

    testWidgets('renders submit button with custom text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [PreChatFormField.name()],
                onSubmit: (result) {},
                primaryColor: Colors.blue,
                submitButtonText: 'Begin',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Begin'), findsOneWidget);
    });

    testWidgets('shows cancel button when showCancelButton is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [PreChatFormField.name()],
                onSubmit: (result) {},
                onCancel: () {},
                primaryColor: Colors.blue,
                showCancelButton: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('calls onCancel when cancel button is tapped',
        (WidgetTester tester) async {
      bool cancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [PreChatFormField.name()],
                onSubmit: (result) {},
                onCancel: () {
                  cancelCalled = true;
                },
                primaryColor: Colors.blue,
                showCancelButton: true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(cancelCalled, isTrue);
    });

    testWidgets('renders all form fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [
                  PreChatFormField.name(questionText: 'Your name'),
                  PreChatFormField.email(questionText: 'Your email'),
                ],
                onSubmit: (result) {},
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Your name'), findsOneWidget);
      expect(find.text('Your email'), findsOneWidget);
    });

    testWidgets('can enter text in name field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [PreChatFormField.name()],
                onSubmit: (result) {},
                primaryColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'John Doe');
      await tester.pump();

      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [PreChatFormField.name()],
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

    testWidgets('renders custom header widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [PreChatFormField.name()],
                onSubmit: (result) {},
                primaryColor: Colors.blue,
                headerWidget: const Text('Custom Header'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Custom Header'), findsOneWidget);
    });

    testWidgets('renders custom footer widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [PreChatFormField.name()],
                onSubmit: (result) {},
                primaryColor: Colors.blue,
                footerWidget: const Text('Custom Footer'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Custom Footer'), findsOneWidget);
    });

    testWidgets('disposes properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreChatFormWidget(
                fields: [PreChatFormField.name()],
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
