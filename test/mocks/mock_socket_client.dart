import 'package:conferbot_flutter/src/services/socket_client.dart';
import 'package:conferbot_flutter/src/models/queued_message.dart';

/// Mock implementation of SocketClient for testing
class MockSocketClient extends SocketClient {
  MockSocketClient() : super(apiKey: 'test_api_key', botId: 'test_bot_id');

  final List<EmittedEvent> emittedEvents = [];
  final Map<String, List<Function(dynamic)>> eventListeners = {};
  bool mockIsConnected = false;

  @override
  bool get isConnected => mockIsConnected;

  @override
  Future<void> connect() async {
    mockIsConnected = true;
  }

  @override
  void disconnect() {
    mockIsConnected = false;
  }

  @override
  void emit(String event, dynamic data) {
    emittedEvents.add(EmittedEvent(event, data));
  }

  @override
  void on(String event, Function(dynamic) callback) {
    eventListeners[event] ??= [];
    eventListeners[event]!.add(callback);
  }

  @override
  void off(String event, [Function(dynamic)? callback]) {
    if (callback != null) {
      eventListeners[event]?.remove(callback);
    } else {
      eventListeners.remove(event);
    }
  }

  @override
  void getChatbotData() {
    emit('get-chatbot-data', {'botId': botId});
  }

  @override
  void joinChatRoomVisitor(String chatSessionId) {
    emit('join-chat-room-visitor', {'chatSessionId': chatSessionId});
  }

  @override
  void leaveChatRoom(String chatSessionId) {
    emit('leave-chat-room', {'chatSessionId': chatSessionId});
  }

  @override
  Future<QueuedMessage?> sendResponseRecord({
    required String chatSessionId,
    required dynamic record,
    List<dynamic>? answerVariables,
    Map<String, dynamic>? visitorMeta,
  }) async {
    emit('response-record', {
      'chatSessionId': chatSessionId,
      'record': record,
      'answerVariables': answerVariables ?? [],
      if (visitorMeta != null) 'visitorMeta': visitorMeta,
    });
    return null;
  }

  @override
  void sendTypingStatus({
    required String chatSessionId,
    required bool isTyping,
  }) {
    emit('visitor-typing', {
      'chatSessionId': chatSessionId,
      'isTyping': isTyping,
    });
  }

  @override
  Future<QueuedMessage?> initiateHandover({
    required String chatSessionId,
    String? message,
  }) async {
    emit('initiate-handover', {
      'chatSessionId': chatSessionId,
      if (message != null) 'message': message,
    });
    return null;
  }

  @override
  void endChat(String chatSessionId) {
    emit('end-chat', {'chatSessionId': chatSessionId});
  }

  /// Simulate receiving an event from server
  void simulateEvent(String event, dynamic data) {
    final listeners = eventListeners[event];
    if (listeners != null) {
      for (final listener in listeners) {
        listener(data);
      }
    }
  }

  /// Clear all emitted events
  void clearEmittedEvents() {
    emittedEvents.clear();
  }

  /// Check if an event was emitted
  bool wasEventEmitted(String event) {
    return emittedEvents.any((e) => e.event == event);
  }

  /// Get emitted events by name
  List<EmittedEvent> getEmittedEvents(String event) {
    return emittedEvents.where((e) => e.event == event).toList();
  }
}

/// Record of an emitted event
class EmittedEvent {
  final String event;
  final dynamic data;

  EmittedEvent(this.event, this.data);

  @override
  String toString() => 'EmittedEvent($event, $data)';
}
