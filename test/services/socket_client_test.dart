import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/models/socket_events.dart';
import '../mocks/mock_socket_client.dart';

void main() {
  late MockSocketClient socketClient;

  setUp(() {
    socketClient = MockSocketClient();
  });

  tearDown(() {
    socketClient.disconnect();
    socketClient.clearEmittedEvents();
  });

  group('SocketClient Construction', () {
    test('should create with required parameters', () {
      expect(socketClient.apiKey, 'test_api_key');
      expect(socketClient.botId, 'test_bot_id');
    });

    test('should start disconnected', () {
      expect(socketClient.isConnected, false);
    });
  });

  group('SocketClient Connection', () {
    test('should connect', () {
      socketClient.connect();

      expect(socketClient.isConnected, true);
    });

    test('should disconnect', () {
      socketClient.connect();
      socketClient.disconnect();

      expect(socketClient.isConnected, false);
    });

    test('should not connect if already connected', () {
      socketClient.connect();
      socketClient.connect();

      expect(socketClient.isConnected, true);
    });
  });

  group('SocketClient.getChatbotData', () {
    test('should emit get-chatbot-data event', () {
      socketClient.mockIsConnected = true;
      socketClient.getChatbotData();

      expect(socketClient.wasEventEmitted('get-chatbot-data'), true);
      final events = socketClient.getEmittedEvents('get-chatbot-data');
      expect(events.first.data['botId'], 'test_bot_id');
    });
  });

  group('SocketClient.joinChatRoomVisitor', () {
    test('should emit join-chat-room-visitor event', () {
      socketClient.mockIsConnected = true;
      socketClient.joinChatRoomVisitor('session_123');

      expect(socketClient.wasEventEmitted('join-chat-room-visitor'), true);
      final events = socketClient.getEmittedEvents('join-chat-room-visitor');
      expect(events.first.data['chatSessionId'], 'session_123');
    });
  });

  group('SocketClient.leaveChatRoom', () {
    test('should emit leave-chat-room event', () {
      socketClient.mockIsConnected = true;
      socketClient.leaveChatRoom('session_123');

      expect(socketClient.wasEventEmitted('leave-chat-room'), true);
      final events = socketClient.getEmittedEvents('leave-chat-room');
      expect(events.first.data['chatSessionId'], 'session_123');
    });
  });

  group('SocketClient.sendResponseRecord', () {
    test('should emit response-record event', () {
      socketClient.mockIsConnected = true;
      socketClient.sendResponseRecord(
        chatSessionId: 'session_123',
        record: {'id': 'msg_1', 'text': 'Hello'},
        answerVariables: [
          {'nodeId': 'node_1', 'key': 'name', 'value': 'John'}
        ],
      );

      expect(socketClient.wasEventEmitted('response-record'), true);
      final events = socketClient.getEmittedEvents('response-record');
      expect(events.first.data['chatSessionId'], 'session_123');
      expect(events.first.data['record'], isNotNull);
      expect(events.first.data['answerVariables'], isNotNull);
    });

    test('should include visitor meta if provided', () {
      socketClient.mockIsConnected = true;
      socketClient.sendResponseRecord(
        chatSessionId: 'session_123',
        record: {},
        visitorMeta: {'name': 'John', 'email': 'john@example.com'},
      );

      final events = socketClient.getEmittedEvents('response-record');
      expect(events.first.data['visitorMeta']['name'], 'John');
    });

    test('should handle list of records', () {
      socketClient.mockIsConnected = true;
      socketClient.sendResponseRecord(
        chatSessionId: 'session_123',
        record: [
          {'id': 'msg_1', 'text': 'Hello'},
          {'id': 'msg_2', 'text': 'World'},
        ],
      );

      final events = socketClient.getEmittedEvents('response-record');
      expect(events.first.data['record'], isList);
    });
  });

  group('SocketClient.sendTypingStatus', () {
    test('should emit visitor-typing event', () {
      socketClient.mockIsConnected = true;
      socketClient.sendTypingStatus(
        chatSessionId: 'session_123',
        isTyping: true,
      );

      expect(socketClient.wasEventEmitted('visitor-typing'), true);
      final events = socketClient.getEmittedEvents('visitor-typing');
      expect(events.first.data['chatSessionId'], 'session_123');
      expect(events.first.data['isTyping'], true);
    });

    test('should emit typing false', () {
      socketClient.mockIsConnected = true;
      socketClient.sendTypingStatus(
        chatSessionId: 'session_123',
        isTyping: false,
      );

      final events = socketClient.getEmittedEvents('visitor-typing');
      expect(events.first.data['isTyping'], false);
    });
  });

  group('SocketClient.initiateHandover', () {
    test('should emit initiate-handover event', () {
      socketClient.mockIsConnected = true;
      socketClient.initiateHandover(
        chatSessionId: 'session_123',
        message: 'Need help',
      );

      expect(socketClient.wasEventEmitted('initiate-handover'), true);
      final events = socketClient.getEmittedEvents('initiate-handover');
      expect(events.first.data['chatSessionId'], 'session_123');
      expect(events.first.data['message'], 'Need help');
    });

    test('should not include message if null', () {
      socketClient.mockIsConnected = true;
      socketClient.initiateHandover(chatSessionId: 'session_123');

      final events = socketClient.getEmittedEvents('initiate-handover');
      expect(events.first.data.containsKey('message'), false);
    });
  });

  group('SocketClient.endChat', () {
    test('should emit end-chat event', () {
      socketClient.mockIsConnected = true;
      socketClient.endChat('session_123');

      expect(socketClient.wasEventEmitted('end-chat'), true);
      final events = socketClient.getEmittedEvents('end-chat');
      expect(events.first.data['chatSessionId'], 'session_123');
    });
  });

  group('SocketClient Event Listeners', () {
    test('should register event listener', () {
      var received = false;
      socketClient.on('test-event', (_) => received = true);

      socketClient.simulateEvent('test-event', {});

      expect(received, true);
    });

    test('should receive event data', () {
      dynamic receivedData;
      socketClient.on('test-event', (data) => receivedData = data);

      socketClient.simulateEvent('test-event', {'key': 'value'});

      expect(receivedData['key'], 'value');
    });

    test('should support multiple listeners for same event', () {
      var count = 0;
      socketClient.on('test-event', (_) => count++);
      socketClient.on('test-event', (_) => count++);

      socketClient.simulateEvent('test-event', {});

      expect(count, 2);
    });

    test('should remove event listener', () {
      var received = false;
      void callback(dynamic data) => received = true;

      socketClient.on('test-event', callback);
      socketClient.off('test-event', callback);

      socketClient.simulateEvent('test-event', {});

      expect(received, false);
    });

    test('should remove all listeners for event', () {
      var count = 0;
      socketClient.on('test-event', (_) => count++);
      socketClient.on('test-event', (_) => count++);

      socketClient.off('test-event');

      socketClient.simulateEvent('test-event', {});

      expect(count, 0);
    });
  });

  group('SocketClient Emit When Disconnected', () {
    test('should not emit when not connected', () {
      socketClient.mockIsConnected = false;
      socketClient.emit('test-event', {});

      expect(socketClient.emittedEvents.isEmpty, true);
    });

    test('should emit when connected', () {
      socketClient.mockIsConnected = true;
      socketClient.emit('test-event', {'key': 'value'});

      expect(socketClient.emittedEvents.length, 1);
      expect(socketClient.emittedEvents.first.event, 'test-event');
    });
  });

  group('SocketEvents Constants', () {
    test('should have connection events', () {
      expect(SocketEvents.connect, 'connect');
      expect(SocketEvents.disconnect, 'disconnect');
      expect(SocketEvents.connectError, 'connect_error');
      expect(SocketEvents.reconnect, 'reconnect');
    });

    test('should have chat events', () {
      expect(SocketEvents.getChatbotData, 'get-chatbot-data');
      expect(SocketEvents.fetchedChatbotData, 'fetched-chatbot-data');
      expect(SocketEvents.botResponse, 'bot-response');
      expect(SocketEvents.responseRecord, 'response-record');
    });

    test('should have room events', () {
      expect(SocketEvents.joinChatRoomVisitor, 'join-chat-room-visitor');
      expect(SocketEvents.leaveChatRoom, 'leave-chat-room');
    });

    test('should have handover events', () {
      expect(SocketEvents.initiateHandover, 'initiate-handover');
      expect(SocketEvents.agentAccepted, 'agent-accepted');
      expect(SocketEvents.agentMessage, 'agent-message');
      expect(SocketEvents.agentLeft, 'agent-left');
      expect(SocketEvents.noAgentsAvailable, 'no-agents-available');
    });

    test('should have typing events', () {
      expect(SocketEvents.visitorTyping, 'visitor-typing');
    });

    test('should have chat control events', () {
      expect(SocketEvents.endChat, 'end-chat');
      expect(SocketEvents.chatEnded, 'chat-ended');
    });
  });

  group('MockSocketClient Utilities', () {
    test('should clear emitted events', () {
      socketClient.mockIsConnected = true;
      socketClient.emit('event1', {});
      socketClient.emit('event2', {});

      expect(socketClient.emittedEvents.length, 2);

      socketClient.clearEmittedEvents();

      expect(socketClient.emittedEvents.isEmpty, true);
    });

    test('should check if event was emitted', () {
      socketClient.mockIsConnected = true;
      socketClient.emit('test-event', {});

      expect(socketClient.wasEventEmitted('test-event'), true);
      expect(socketClient.wasEventEmitted('other-event'), false);
    });

    test('should get emitted events by name', () {
      socketClient.mockIsConnected = true;
      socketClient.emit('test-event', {'data': 1});
      socketClient.emit('other-event', {'data': 2});
      socketClient.emit('test-event', {'data': 3});

      final events = socketClient.getEmittedEvents('test-event');

      expect(events.length, 2);
      expect(events[0].data['data'], 1);
      expect(events[1].data['data'], 3);
    });
  });

  group('EmittedEvent', () {
    test('should have correct toString', () {
      final event = EmittedEvent('test-event', {'key': 'value'});

      expect(event.toString(), contains('EmittedEvent'));
      expect(event.toString(), contains('test-event'));
    });

    test('should store event name and data', () {
      final event = EmittedEvent('my-event', {'foo': 'bar'});

      expect(event.event, 'my-event');
      expect(event.data['foo'], 'bar');
    });
  });
}
