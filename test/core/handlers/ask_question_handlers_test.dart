import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/core/nodes/handlers/ask_question_handlers.dart';
import 'package:conferbot_flutter/src/core/nodes/handlers/legacy_handlers.dart';
import 'package:conferbot_flutter/src/core/nodes/node_result.dart';
import 'package:conferbot_flutter/src/core/nodes/node_types.dart';
import '../../mocks/mock_chat_state.dart';
import '../../fixtures/test_fixtures.dart';

void main() {
  late MockChatState mockState;

  setUp(() {
    mockState = MockChatState();
  });

  tearDown(() {
    mockState.reset();
  });

  group('AskNameNodeHandler', () {
    late AskNameNodeHandler handler;

    setUp(() {
      handler = AskNameNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.askName);
    });

    test('should display name input', () async {
      final nodeData = TestFixtures.askNameNode(
        questionText: 'What is your name?',
        answerVariable: 'name',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'ask_name_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as TextInputState;
      expect(uiState.inputType, TextInputType.name);
      expect(uiState.nodeId, 'ask_name_1');
      expect(uiState.answerKey, 'name');
    });

    test('should add to transcript', () async {
      final nodeData = TestFixtures.askNameNode(
        questionText: 'What is your name?',
      )['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_name_1');

      expect(mockState.transcriptEntries.length, 1);
      expect(mockState.transcriptEntries.first.message, 'What is your name?');
    });

    test('should handle response and set metadata', () async {
      final nodeData = TestFixtures.askNameNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_name_1');
      final result = await handler.handleResponse('John Doe', nodeData, 'ask_name_1');

      expect(result, isA<DelayedProceedResult>());
      expect(mockState.userMetadata['name'], 'John Doe');
      expect(mockState.answerVariables['ask_name_1']?['value'], 'John Doe');
    });

    test('should return error for empty name', () async {
      final nodeData = TestFixtures.askNameNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_name_1');
      final result = await handler.handleResponse('', nodeData, 'ask_name_1');

      expect(result, isA<ErrorResult>());
      expect((result as ErrorResult).shouldProceed, false);
    });

    test('should add greeting response after name', () async {
      final nodeData = TestFixtures.askNameNode(
        nameGreet: 'Hello {name}!',
      )['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_name_1');
      await handler.handleResponse('John', nodeData, 'ask_name_1');

      expect(mockState.transcriptEntries.any((e) => e.message.contains('John')), true);
    });

    test('should push to record', () async {
      final nodeData = TestFixtures.askNameNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_name_1');
      await handler.handleResponse('John', nodeData, 'ask_name_1');

      expect(mockState.recordEntries.any((e) => e.shape == 'user-input-response'), true);
    });
  });

  group('AskEmailNodeHandler', () {
    late AskEmailNodeHandler handler;

    setUp(() {
      handler = AskEmailNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.askEmail);
    });

    test('should display email input', () async {
      final nodeData = TestFixtures.askEmailNode(
        questionText: 'What is your email?',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'ask_email_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as TextInputState;
      expect(uiState.inputType, TextInputType.email);
    });

    test('should validate and accept correct email', () async {
      final nodeData = TestFixtures.askEmailNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_email_1');
      final result = await handler.handleResponse('test@example.com', nodeData, 'ask_email_1');

      expect(result, isA<DelayedProceedResult>());
      expect(mockState.userMetadata['email'], 'test@example.com');
    });

    test('should reject invalid email', () async {
      final nodeData = TestFixtures.askEmailNode(
        errorMessage: 'Invalid email!',
      )['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_email_1');
      final result = await handler.handleResponse('invalid-email', nodeData, 'ask_email_1');

      expect(result, isA<ErrorResult>());
      expect((result as ErrorResult).message, contains('Invalid email'));
      expect(result.shouldProceed, false);
    });

    test('should trim whitespace from email', () async {
      final nodeData = TestFixtures.askEmailNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_email_1');
      await handler.handleResponse('  test@example.com  ', nodeData, 'ask_email_1');

      expect(mockState.answerVariables['ask_email_1']?['value'], 'test@example.com');
    });
  });

  group('AskPhoneNodeHandler', () {
    late AskPhoneNodeHandler handler;

    setUp(() {
      handler = AskPhoneNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.askPhone);
    });

    test('should display phone input', () async {
      final nodeData = TestFixtures.askPhoneNode(
        questionText: 'What is your phone?',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'ask_phone_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as TextInputState;
      expect(uiState.inputType, TextInputType.phone);
    });

    test('should validate and accept correct phone', () async {
      final nodeData = TestFixtures.askPhoneNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_phone_1');
      final result = await handler.handleResponse('+1234567890', nodeData, 'ask_phone_1');

      expect(result, isA<DelayedProceedResult>());
      expect(mockState.userMetadata['phone'], '+1234567890');
    });

    test('should reject invalid phone', () async {
      final nodeData = TestFixtures.askPhoneNode(
        errorMessage: 'Invalid phone!',
      )['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_phone_1');
      final result = await handler.handleResponse('abc', nodeData, 'ask_phone_1');

      expect(result, isA<ErrorResult>());
      expect((result as ErrorResult).shouldProceed, false);
    });

    test('should handle phone with dashes and spaces', () async {
      final nodeData = TestFixtures.askPhoneNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_phone_1');
      final result = await handler.handleResponse('+1 (234) 567-8900', nodeData, 'ask_phone_1');

      expect(result, isA<DelayedProceedResult>());
    });
  });

  group('AskNumberNodeHandler', () {
    late AskNumberNodeHandler handler;

    setUp(() {
      handler = AskNumberNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.askNumber);
    });

    test('should display number input', () async {
      final nodeData = TestFixtures.askNumberNode(
        questionText: 'Enter a number',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'ask_num_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as TextInputState;
      expect(uiState.inputType, TextInputType.number);
    });

    test('should validate and accept correct number', () async {
      final nodeData = TestFixtures.askNumberNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_num_1');
      final result = await handler.handleResponse('42', nodeData, 'ask_num_1');

      expect(result, isA<DelayedProceedResult>());
      expect(mockState.answerVariables['ask_num_1']?['value'], '42');
    });

    test('should accept decimal numbers', () async {
      final nodeData = TestFixtures.askNumberNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_num_1');
      final result = await handler.handleResponse('3.14', nodeData, 'ask_num_1');

      expect(result, isA<DelayedProceedResult>());
    });

    test('should reject non-numeric input', () async {
      final nodeData = TestFixtures.askNumberNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_num_1');
      final result = await handler.handleResponse('abc', nodeData, 'ask_num_1');

      expect(result, isA<ErrorResult>());
      expect((result as ErrorResult).shouldProceed, false);
    });

    test('should handle min/max validation', () async {
      final nodeData = {
        'type': 'ask-number-node',
        'questionText': 'Enter a number',
        'answerVariable': 'number',
        'minValue': 10,
        'maxValue': 100,
      };

      await handler.process(nodeData, 'ask_num_1');
      final belowMin = await handler.handleResponse('5', nodeData, 'ask_num_1');
      expect(belowMin, isA<ErrorResult>());

      final aboveMax = await handler.handleResponse('150', nodeData, 'ask_num_1');
      expect(aboveMax, isA<ErrorResult>());

      final inRange = await handler.handleResponse('50', nodeData, 'ask_num_1');
      expect(inRange, isA<DelayedProceedResult>());
    });
  });

  group('AskUrlNodeHandler', () {
    late AskUrlNodeHandler handler;

    setUp(() {
      handler = AskUrlNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.askUrl);
    });

    test('should display URL input', () async {
      final nodeData = TestFixtures.askUrlNode()['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'ask_url_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as TextInputState;
      expect(uiState.inputType, TextInputType.url);
    });

    test('should validate and accept correct URL', () async {
      final nodeData = TestFixtures.askUrlNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_url_1');
      final result = await handler.handleResponse('https://example.com', nodeData, 'ask_url_1');

      expect(result, isA<DelayedProceedResult>());
    });

    test('should reject invalid URL', () async {
      final nodeData = TestFixtures.askUrlNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_url_1');
      final result = await handler.handleResponse('not-a-url', nodeData, 'ask_url_1');

      expect(result, isA<ErrorResult>());
      expect((result as ErrorResult).shouldProceed, false);
    });
  });

  group('AskCustomNodeHandler', () {
    late AskCustomNodeHandler handler;

    setUp(() {
      handler = AskCustomNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.askCustom);
    });

    test('should display text input', () async {
      final nodeData = TestFixtures.askCustomNode(
        questionText: 'Custom question?',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'ask_custom_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as TextInputState;
      expect(uiState.inputType, TextInputType.text);
    });

    test('should accept any text response', () async {
      final nodeData = TestFixtures.askCustomNode()['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'ask_custom_1');
      final result = await handler.handleResponse('Any answer works', nodeData, 'ask_custom_1');

      expect(result, isA<DelayedProceedResult>());
      expect(mockState.answerVariables['ask_custom_1']?['value'], 'Any answer works');
    });

    test('should reject empty response when required', () async {
      final nodeData = {
        'type': 'ask-custom-question-node',
        'questionText': 'Custom question?',
        'answerVariable': 'custom',
        'required': true,
      };

      await handler.process(nodeData, 'ask_custom_1');
      final result = await handler.handleResponse('', nodeData, 'ask_custom_1');

      expect(result, isA<ErrorResult>());
    });

    test('should support custom regex validation', () async {
      final nodeData = {
        'type': 'ask-custom-question-node',
        'questionText': 'Enter code',
        'answerVariable': 'code',
        'validationRegex': r'^[A-Z]{3}[0-9]{3}$',
        'validationError': 'Must be 3 letters followed by 3 digits',
      };

      await handler.process(nodeData, 'ask_custom_1');

      final invalidResult = await handler.handleResponse('ABC12', nodeData, 'ask_custom_1');
      expect(invalidResult, isA<ErrorResult>());

      final validResult = await handler.handleResponse('ABC123', nodeData, 'ask_custom_1');
      expect(validResult, isA<DelayedProceedResult>());
    });
  });

  group('AskFileNodeHandler', () {
    late AskFileNodeHandler handler;

    setUp(() {
      handler = AskFileNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.askFile);
    });

    test('should display file upload', () async {
      final nodeData = {
        'type': 'ask-file-node',
        'questionText': 'Upload a file',
        'answerVariable': 'file',
        'maxSizeMb': 10,
        'allowedTypes': ['pdf', 'doc', 'docx'],
      };

      final result = await handler.process(nodeData, 'ask_file_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as FileUploadState;
      expect(uiState.maxSizeMb, 10);
      expect(uiState.allowedTypes, ['pdf', 'doc', 'docx']);
    });

    test('should handle file response', () async {
      final nodeData = {
        'type': 'ask-file-node',
        'questionText': 'Upload a file',
        'answerVariable': 'file',
      };

      await handler.process(nodeData, 'ask_file_1');
      final result = await handler.handleResponse(
        {'url': 'https://example.com/file.pdf', 'name': 'file.pdf'},
        nodeData,
        'ask_file_1',
      );

      expect(result, isA<DelayedProceedResult>());
    });
  });

  group('AskLocationNodeHandler', () {
    late AskLocationNodeHandler handler;

    setUp(() {
      handler = AskLocationNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.askLocation);
    });

    test('should display location input', () async {
      final nodeData = {
        'type': 'ask-location-node',
        'questionText': 'Enter your location',
        'answerVariable': 'location',
      };

      final result = await handler.process(nodeData, 'ask_loc_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as TextInputState;
      expect(uiState.inputType, TextInputType.location);
    });

    test('should handle location response', () async {
      final nodeData = {
        'type': 'ask-location-node',
        'questionText': 'Enter your location',
        'answerVariable': 'location',
      };

      await handler.process(nodeData, 'ask_loc_1');
      final result = await handler.handleResponse('New York, NY', nodeData, 'ask_loc_1');

      expect(result, isA<DelayedProceedResult>());
      expect(mockState.answerVariables['ask_loc_1']?['value'], 'New York, NY');
    });
  });

  group('CalendarNodeHandler', () {
    late CalendarNodeHandler handler;

    setUp(() {
      handler = CalendarNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.calendar);
    });

    test('should display calendar', () async {
      final nodeData = {
        'type': 'calendar-node',
        'questionText': 'Select a date',
        'answerVariable': 'date',
        'showTimeSelection': true,
        'timezone': 'America/New_York',
      };

      final result = await handler.process(nodeData, 'cal_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as CalendarState;
      expect(uiState.showTimeSelection, true);
    });

    test('should handle date response', () async {
      final nodeData = {
        'type': 'calendar-node',
        'questionText': 'Select a date',
        'answerVariable': 'date',
      };

      await handler.process(nodeData, 'cal_1');
      final result = await handler.handleResponse('2024-01-15', nodeData, 'cal_1');

      expect(result, isA<DelayedProceedResult>());
      expect(mockState.answerVariables['cal_1']?['value'], '2024-01-15');
    });

    test('should handle date and time response', () async {
      final nodeData = {
        'type': 'calendar-node',
        'questionText': 'Select a date and time',
        'answerVariable': 'datetime',
        'showTimeSelection': true,
      };

      await handler.process(nodeData, 'cal_1');
      final result = await handler.handleResponse(
        {'date': '2024-01-15', 'time': '14:30'},
        nodeData,
        'cal_1',
      );

      expect(result, isA<DelayedProceedResult>());
    });
  });

  group('AskMultipleQuestionsNodeHandler', () {
    late AskMultipleQuestionsNodeHandler handler;

    setUp(() {
      handler = AskMultipleQuestionsNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.askMultipleQuestions);
    });

    test('should display first question', () async {
      final nodeData = {
        'type': 'ask-multiple-questions-node',
        'questions': [
          {'questionText': 'First question', 'answerVariable': 'q1', 'answerType': 'text'},
          {'questionText': 'Second question', 'answerVariable': 'q2', 'answerType': 'email'},
        ],
      };

      final result = await handler.process(nodeData, 'multi_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState;
      expect(uiState, isNotNull);
    });

    test('should progress through questions', () async {
      final nodeData = {
        'type': 'ask-multiple-questions-node',
        'questions': [
          {'questionText': 'First', 'answerVariable': 'q1', 'answerType': 'text'},
          {'questionText': 'Second', 'answerVariable': 'q2', 'answerType': 'text'},
        ],
      };

      await handler.process(nodeData, 'multi_1');

      // Answer first question
      final firstResult = await handler.handleResponse('Answer 1', nodeData, 'multi_1');
      expect(firstResult, isA<DisplayUIResult>());

      // Answer second question
      final secondResult = await handler.handleResponse('Answer 2', nodeData, 'multi_1');
      expect(secondResult, isA<DelayedProceedResult>());
    });

    test('should store all answers', () async {
      final nodeData = {
        'type': 'ask-multiple-questions-node',
        'questions': [
          {'questionText': 'Name', 'answerVariable': 'name', 'answerType': 'name'},
          {'questionText': 'Email', 'answerVariable': 'email', 'answerType': 'email'},
        ],
      };

      await handler.process(nodeData, 'multi_1');
      await handler.handleResponse('John', nodeData, 'multi_1');
      await handler.handleResponse('john@example.com', nodeData, 'multi_1');

      expect(mockState.getAnswerVariableValue('name'), 'John');
      expect(mockState.getAnswerVariableValue('email'), 'john@example.com');
    });
  });

  group('Legacy UserInputNodeHandler', () {
    late UserInputNodeHandler handler;

    setUp(() {
      handler = UserInputNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.userInput);
    });

    test('should handle name type', () async {
      final nodeData = {
        'type': 'user-input-node',
        'inputType': 'name',
        'answerVariable': 'name',
      };

      final result = await handler.process(nodeData, 'input_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as TextInputState;
      expect(uiState.inputType, TextInputType.name);
    });

    test('should handle email type', () async {
      final nodeData = {
        'type': 'user-input-node',
        'inputType': 'email',
        'answerVariable': 'email',
      };

      final result = await handler.process(nodeData, 'input_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as TextInputState;
      expect(uiState.inputType, TextInputType.email);
    });

    test('should handle file type', () async {
      final nodeData = {
        'type': 'user-input-node',
        'inputType': 'file',
        'answerVariable': 'file',
      };

      final result = await handler.process(nodeData, 'input_1');

      expect(result, isA<DisplayUIResult>());
      expect((result as DisplayUIResult).uiState, isA<FileUploadState>());
    });

    test('should handle date type', () async {
      final nodeData = {
        'type': 'user-input-node',
        'inputType': 'date',
        'answerVariable': 'date',
      };

      final result = await handler.process(nodeData, 'input_1');

      expect(result, isA<DisplayUIResult>());
      expect((result as DisplayUIResult).uiState, isA<CalendarState>());
    });
  });

  group('AskQuestionHandlers Registry', () {
    test('should return all ask question handlers', () {
      final handlers = AskQuestionHandlers.handlers;

      expect(handlers.length, greaterThan(0));
      expect(handlers.any((h) => h.nodeType == NodeTypes.askName), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.askEmail), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.askPhone), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.askNumber), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.askUrl), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.askCustom), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.askFile), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.askLocation), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.calendar), true);
    });

    test('should get handler by type', () {
      final handler = AskQuestionHandlers.getHandler(NodeTypes.askName);
      expect(handler, isA<AskNameNodeHandler>());
    });

    test('should return null for unknown type', () {
      final handler = AskQuestionHandlers.getHandler('unknown-type');
      expect(handler, isNull);
    });
  });
}
