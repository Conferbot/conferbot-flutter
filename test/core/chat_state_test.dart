import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';

void main() {
  late ChatState chatState;

  setUp(() {
    chatState = ChatState();
    chatState.reset(); // Ensure clean state for each test
  });

  tearDown(() {
    chatState.reset();
  });

  group('ChatState Initialization', () {
    test('should initialize with correct session data', () {
      chatState.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        workspaceId: 'workspace_101',
      );

      expect(chatState.chatSessionId, 'session_123');
      expect(chatState.visitorId, 'visitor_456');
      expect(chatState.botId, 'bot_789');
      expect(chatState.workspaceId, 'workspace_101');
    });

    test('should initialize with null workspaceId', () {
      chatState.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      expect(chatState.workspaceId, isNull);
    });

    test('should start with empty state', () {
      expect(chatState.answerVariables, isEmpty);
      expect(chatState.variables, isEmpty);
      expect(chatState.transcript, isEmpty);
      expect(chatState.record, isEmpty);
      expect(chatState.currentIndex, 0);
    });
  });

  group('Answer Variables', () {
    test('should add answer variable', () {
      chatState.addAnswerVariable('node_1', 'email');

      expect(chatState.answerVariables.length, 1);
      expect(chatState.answerVariables.first.nodeId, 'node_1');
      expect(chatState.answerVariables.first.key, 'email');
      expect(chatState.answerVariables.first.value, isNull);
    });

    test('should add answer variable with initial value', () {
      chatState.addAnswerVariable('node_1', 'email', value: 'test@example.com');

      expect(chatState.answerVariables.first.value, 'test@example.com');
    });

    test('should update existing answer variable by nodeId', () {
      chatState.addAnswerVariable('node_1', 'email');
      chatState.setAnswerVariable('node_1', 'test@example.com');

      expect(chatState.answerVariables.first.value, 'test@example.com');
    });

    test('should update answer variable by key', () {
      chatState.addAnswerVariable('node_1', 'email');
      chatState.setAnswerVariableByKey('email', 'updated@example.com');

      expect(chatState.getAnswerVariableValue('email'), 'updated@example.com');
    });

    test('should create new answer variable if key not found when updating by key', () {
      chatState.setAnswerVariableByKey('newKey', 'newValue');

      expect(chatState.getAnswerVariableValue('newKey'), 'newValue');
    });

    test('should get answer variable value by key', () {
      chatState.addAnswerVariable('node_1', 'name', value: 'John Doe');

      expect(chatState.getAnswerVariableValue('name'), 'John Doe');
    });

    test('should return null for non-existent answer variable', () {
      expect(chatState.getAnswerVariableValue('nonexistent'), isNull);
    });

    test('should get answer variables as map', () {
      chatState.addAnswerVariable('node_1', 'name', value: 'John');
      chatState.addAnswerVariable('node_2', 'email', value: 'john@example.com');

      final map = chatState.getAnswerVariablesMap();

      expect(map['name'], 'John');
      expect(map['email'], 'john@example.com');
    });

    test('should not create duplicate when adding variable with same nodeId', () {
      chatState.addAnswerVariable('node_1', 'email');
      chatState.addAnswerVariable('node_1', 'email', value: 'test@example.com');

      expect(chatState.answerVariables.length, 1);
      expect(chatState.answerVariables.first.value, 'test@example.com');
    });
  });

  group('Variables (Temporary)', () {
    test('should set and get variable', () {
      chatState.setVariable('count', 5);

      expect(chatState.getVariable('count'), 5);
    });

    test('should return null for non-existent variable', () {
      expect(chatState.getVariable('nonexistent'), isNull);
    });

    test('should handle different variable types', () {
      chatState.setVariable('string', 'hello');
      chatState.setVariable('number', 42);
      chatState.setVariable('double', 3.14);
      chatState.setVariable('bool', true);
      chatState.setVariable('list', [1, 2, 3]);

      expect(chatState.getVariable('string'), 'hello');
      expect(chatState.getVariable('number'), 42);
      expect(chatState.getVariable('double'), 3.14);
      expect(chatState.getVariable('bool'), true);
      expect(chatState.getVariable('list'), [1, 2, 3]);
    });
  });

  group('Variable Resolution', () {
    test('should resolve double-brace variable reference', () {
      chatState.addAnswerVariable('node_1', 'name', value: 'John');

      final resolved = chatState.resolveValue('{{name}}');

      expect(resolved, 'John');
    });

    test('should resolve dollar-brace variable reference', () {
      chatState.addAnswerVariable('node_1', 'name', value: 'Jane');

      final resolved = chatState.resolveValue('\${name}');

      expect(resolved, 'Jane');
    });

    test('should resolve from temp variables when not in answer variables', () {
      chatState.setVariable('count', 10);

      final resolved = chatState.resolveValue('{{count}}');

      expect(resolved, 10);
    });

    test('should return original value if no variable match', () {
      final resolved = chatState.resolveValue('plain text');

      expect(resolved, 'plain text');
    });

    test('should return original value if variable not found', () {
      final resolved = chatState.resolveValue('{{nonexistent}}');

      expect(resolved, '{{nonexistent}}');
    });

    test('should prioritize answer variables over temp variables', () {
      chatState.addAnswerVariable('node_1', 'value', value: 'answer');
      chatState.setVariable('value', 'temp');

      final resolved = chatState.resolveValue('{{value}}');

      expect(resolved, 'answer');
    });
  });

  group('User Metadata', () {
    test('should set and get name metadata', () {
      chatState.setUserMetadata('name', 'John Doe');

      expect(chatState.getUserMetadata('name'), 'John Doe');
      expect(chatState.userMetadata.name, 'John Doe');
    });

    test('should set and get email metadata', () {
      chatState.setUserMetadata('email', 'john@example.com');

      expect(chatState.getUserMetadata('email'), 'john@example.com');
      expect(chatState.userMetadata.email, 'john@example.com');
    });

    test('should set and get phone metadata', () {
      chatState.setUserMetadata('phone', '+1234567890');

      expect(chatState.getUserMetadata('phone'), '+1234567890');
      expect(chatState.userMetadata.phone, '+1234567890');
    });

    test('should handle mobile as alias for phone', () {
      chatState.setUserMetadata('mobile', '+1234567890');

      expect(chatState.getUserMetadata('mobile'), '+1234567890');
      expect(chatState.userMetadata.phone, '+1234567890');
    });

    test('should set custom metadata', () {
      chatState.setUserMetadata('company', 'Acme Inc');

      expect(chatState.getUserMetadata('company'), 'Acme Inc');
      expect(chatState.userMetadata.metadata['company'], 'Acme Inc');
    });

    test('should handle case-insensitive metadata keys', () {
      chatState.setUserMetadata('NAME', 'John');
      chatState.setUserMetadata('Email', 'john@example.com');

      expect(chatState.getUserMetadata('name'), 'John');
      expect(chatState.getUserMetadata('email'), 'john@example.com');
    });
  });

  group('Transcript', () {
    test('should add to transcript', () {
      chatState.addToTranscript('bot', 'Hello!');
      chatState.addToTranscript('user', 'Hi there!');

      expect(chatState.transcript.length, 2);
      expect(chatState.transcript[0].by, 'bot');
      expect(chatState.transcript[0].message, 'Hello!');
      expect(chatState.transcript[1].by, 'user');
      expect(chatState.transcript[1].message, 'Hi there!');
    });

    test('should include timestamp in transcript entry', () {
      final beforeAdd = DateTime.now().millisecondsSinceEpoch;
      chatState.addToTranscript('bot', 'Test');
      final afterAdd = DateTime.now().millisecondsSinceEpoch;

      expect(chatState.transcript.first.timestamp, greaterThanOrEqualTo(beforeAdd));
      expect(chatState.transcript.first.timestamp, lessThanOrEqualTo(afterAdd));
    });

    test('should get transcript for GPT', () {
      chatState.addToTranscript('bot', 'Hello!');
      chatState.addToTranscript('user', 'Hi!');
      chatState.addToTranscript('agent', 'How can I help?');

      final gptTranscript = chatState.getTranscriptForGPT();

      expect(gptTranscript.length, 3);
      expect(gptTranscript[0]['role'], 'assistant');
      expect(gptTranscript[0]['content'], 'Hello!');
      expect(gptTranscript[1]['role'], 'user');
      expect(gptTranscript[1]['content'], 'Hi!');
      expect(gptTranscript[2]['role'], 'assistant');
      expect(gptTranscript[2]['content'], 'How can I help?');
    });
  });

  group('Record', () {
    test('should push to record', () {
      final entry = RecordEntry(
        id: 'node_1',
        shape: 'bot-message',
        type: 'message-node',
        text: 'Hello!',
      );

      chatState.pushToRecord(entry);

      expect(chatState.record.length, 1);
      expect(chatState.record.first.id, 'node_1');
      expect(chatState.record.first.shape, 'bot-message');
    });

    test('should merge record with same id', () {
      final entry1 = RecordEntry(
        id: 'node_1',
        shape: 'user-input',
        text: 'Initial',
        data: {'key1': 'value1'},
      );

      final entry2 = RecordEntry(
        id: 'node_1',
        shape: 'user-input',
        text: 'Updated',
        data: {'key2': 'value2'},
      );

      chatState.pushToRecord(entry1);
      chatState.pushToRecord(entry2);

      expect(chatState.record.length, 1);
      expect(chatState.record.first.text, 'Updated');
      expect(chatState.record.first.data['key1'], 'value1');
      expect(chatState.record.first.data['key2'], 'value2');
    });

    test('should get record for server', () {
      final entry = RecordEntry(
        id: 'node_1',
        shape: 'bot-message',
        type: 'message-node',
        text: 'Hello!',
      );

      chatState.pushToRecord(entry);
      final serverRecord = chatState.getRecordForServer();

      expect(serverRecord.length, 1);
      expect(serverRecord.first['id'], 'node_1');
      expect(serverRecord.first['shape'], 'bot-message');
      expect(serverRecord.first['type'], 'message-node');
      expect(serverRecord.first['text'], 'Hello!');
    });

    test('RecordEntry should serialize to JSON correctly', () {
      final entry = RecordEntry(
        id: 'node_1',
        shape: 'user-input',
        type: 'ask-name-node',
        text: 'John',
        data: {'inputType': 'name'},
      );

      final json = entry.toJson();

      expect(json['id'], 'node_1');
      expect(json['shape'], 'user-input');
      expect(json['type'], 'ask-name-node');
      expect(json['text'], 'John');
      expect(json['inputType'], 'name');
    });
  });

  group('Flow Navigation', () {
    test('should set and get steps', () {
      final steps = [
        {'id': 'step_1', 'type': 'message-node'},
        {'id': 'step_2', 'type': 'ask-name-node'},
      ];

      chatState.setSteps(steps);

      expect(chatState.steps.length, 2);
      expect(chatState.steps[0]['id'], 'step_1');
    });

    test('should get current node', () {
      final steps = [
        {'id': 'step_1', 'type': 'message-node'},
        {'id': 'step_2', 'type': 'ask-name-node'},
      ];

      chatState.setSteps(steps);
      chatState.setCurrentIndex(0);

      final currentNode = chatState.getCurrentNode();

      expect(currentNode, isNotNull);
      expect(currentNode!['id'], 'step_1');
    });

    test('should return null for invalid index', () {
      final steps = [
        {'id': 'step_1', 'type': 'message-node'},
      ];

      chatState.setSteps(steps);
      chatState.setCurrentIndex(5);

      expect(chatState.getCurrentNode(), isNull);
    });

    test('should increment index', () {
      chatState.setCurrentIndex(0);
      chatState.incrementIndex();

      expect(chatState.currentIndex, 1);
    });
  });

  group('Build Response Data', () {
    test('should build complete response data', () {
      chatState.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
        workspaceId: 'workspace_101',
      );

      chatState.addAnswerVariable('node_1', 'name', value: 'John');
      chatState.pushToRecord(RecordEntry(
        id: 'node_1',
        shape: 'user-input',
        text: 'John',
      ));

      final responseData = chatState.buildResponseData();

      expect(responseData['version'], 'v2');
      expect(responseData['chatSessionId'], 'session_123');
      expect(responseData['visitorId'], 'visitor_456');
      expect(responseData['botId'], 'bot_789');
      expect(responseData['workspaceId'], 'workspace_101');
      expect(responseData['record'], isNotEmpty);
      expect(responseData['answerVariables'], isNotEmpty);
      expect(responseData['chatDate'], isNotNull);
      expect(responseData['deviceInfo'], isNotNull);
    });
  });

  group('Reset', () {
    test('should reset all state', () {
      chatState.initialize(
        chatSessionId: 'session_123',
        visitorId: 'visitor_456',
        botId: 'bot_789',
      );

      chatState.addAnswerVariable('node_1', 'name', value: 'John');
      chatState.setVariable('count', 5);
      chatState.setUserMetadata('name', 'John');
      chatState.addToTranscript('bot', 'Hello');
      chatState.pushToRecord(RecordEntry(id: 'node_1', shape: 'test'));
      chatState.setSteps([{'id': 'step_1'}]);
      chatState.setCurrentIndex(1);

      chatState.reset();

      expect(chatState.chatSessionId, isNull);
      expect(chatState.visitorId, isNull);
      expect(chatState.botId, isNull);
      expect(chatState.workspaceId, isNull);
      expect(chatState.answerVariables, isEmpty);
      expect(chatState.variables, isEmpty);
      expect(chatState.userMetadata.name, isNull);
      expect(chatState.transcript, isEmpty);
      expect(chatState.record, isEmpty);
      expect(chatState.steps, isEmpty);
      expect(chatState.currentIndex, 0);
    });
  });

  group('AnswerVariable', () {
    test('should create from JSON', () {
      final json = {
        'nodeId': 'node_1',
        'key': 'email',
        'value': 'test@example.com',
      };

      final answerVar = AnswerVariable.fromJson(json);

      expect(answerVar.nodeId, 'node_1');
      expect(answerVar.key, 'email');
      expect(answerVar.value, 'test@example.com');
    });

    test('should convert to JSON', () {
      final answerVar = AnswerVariable(
        nodeId: 'node_1',
        key: 'email',
        value: 'test@example.com',
      );

      final json = answerVar.toJson();

      expect(json['nodeId'], 'node_1');
      expect(json['key'], 'email');
      expect(json['value'], 'test@example.com');
    });

    test('should copy with new values', () {
      final original = AnswerVariable(
        nodeId: 'node_1',
        key: 'email',
        value: 'original@example.com',
      );

      final copied = original.copyWith(value: 'new@example.com');

      expect(copied.nodeId, 'node_1');
      expect(copied.key, 'email');
      expect(copied.value, 'new@example.com');
      expect(original.value, 'original@example.com');
    });
  });

  group('TranscriptEntry', () {
    test('should create from JSON', () {
      final json = {
        'by': 'bot',
        'message': 'Hello!',
        'timestamp': 1234567890,
      };

      final entry = TranscriptEntry.fromJson(json);

      expect(entry.by, 'bot');
      expect(entry.message, 'Hello!');
      expect(entry.timestamp, 1234567890);
    });

    test('should convert to JSON', () {
      final entry = TranscriptEntry(
        by: 'user',
        message: 'Hi!',
        timestamp: 1234567890,
      );

      final json = entry.toJson();

      expect(json['by'], 'user');
      expect(json['message'], 'Hi!');
      expect(json['timestamp'], 1234567890);
    });
  });

  group('UserMetadata', () {
    test('should create from JSON', () {
      final json = {
        'name': 'John',
        'email': 'john@example.com',
        'phone': '+1234567890',
        'metadata': {'company': 'Acme'},
      };

      final metadata = UserMetadata.fromJson(json);

      expect(metadata.name, 'John');
      expect(metadata.email, 'john@example.com');
      expect(metadata.phone, '+1234567890');
      expect(metadata.metadata['company'], 'Acme');
    });

    test('should convert to JSON', () {
      final metadata = UserMetadata(
        name: 'Jane',
        email: 'jane@example.com',
        phone: '+0987654321',
        metadata: {'title': 'Manager'},
      );

      final json = metadata.toJson();

      expect(json['name'], 'Jane');
      expect(json['email'], 'jane@example.com');
      expect(json['phone'], '+0987654321');
      expect(json['metadata']['title'], 'Manager');
    });

    test('should copy with new values', () {
      final original = UserMetadata(name: 'John');
      final copied = original.copyWith(email: 'john@example.com');

      expect(copied.name, 'John');
      expect(copied.email, 'john@example.com');
      expect(original.email, isNull);
    });
  });

  group('RecordEntry', () {
    test('should create from JSON', () {
      final json = {
        'id': 'node_1',
        'shape': 'user-input',
        'type': 'ask-name-node',
        'text': 'John',
        'time': '2024-01-01T00:00:00Z',
        'customField': 'customValue',
      };

      final entry = RecordEntry.fromJson(json);

      expect(entry.id, 'node_1');
      expect(entry.shape, 'user-input');
      expect(entry.type, 'ask-name-node');
      expect(entry.text, 'John');
      expect(entry.time, '2024-01-01T00:00:00Z');
      expect(entry.data['customField'], 'customValue');
    });

    test('should create with auto-generated time', () {
      final entry = RecordEntry(
        id: 'node_1',
        shape: 'test',
      );

      expect(entry.time, isNotEmpty);
    });

    test('should copy with new values', () {
      final original = RecordEntry(
        id: 'node_1',
        shape: 'original',
        text: 'original text',
      );

      final copied = original.copyWith(text: 'new text');

      expect(copied.id, 'node_1');
      expect(copied.shape, 'original');
      expect(copied.text, 'new text');
      expect(original.text, 'original text');
    });
  });
}
