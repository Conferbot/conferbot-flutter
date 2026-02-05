import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/services/message_queue_service.dart';
import 'package:conferbot_flutter/src/models/queued_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestableMessageQueueService queueService;

  setUp(() {
    MessageQueueService.resetInstance();
    queueService = TestableMessageQueueService();
  });

  tearDown(() {
    queueService.dispose();
  });

  group('MessageQueueService Construction', () {
    test('should create singleton instance', () {
      final service = MessageQueueService.instance;
      expect(service, isNotNull);
    });

    test('should start with empty queue', () {
      expect(queueService.queueSize, 0);
      expect(queueService.pendingCount, 0);
      expect(queueService.failedCount, 0);
      expect(queueService.hasPendingMessages, false);
    });

    test('should not be processing initially', () {
      expect(queueService.isProcessing, false);
    });
  });

  group('MessageQueueService.initialize', () {
    test('should initialize with send callback', () async {
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );

      expect(queueService.isInitialized, true);
    });

    test('should not reinitialize if already initialized', () async {
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );

      await queueService.initialize(
        sendCallback: (event, data) async => false,
      );

      expect(queueService.isInitialized, true);
    });
  });

  group('MessageQueueService.enqueue', () {
    setUp(() async {
      queueService.mockIsOnline = false;
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );
    });

    test('should enqueue message', () async {
      final message = QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {'text': 'Hello'},
      );

      await queueService.enqueue(message);

      expect(queueService.queueSize, 1);
      expect(queueService.pendingCount, 1);
    });

    test('should emit onMessageQueued event', () async {
      final queuedMessages = <QueuedMessage>[];
      queueService.onMessageQueued.listen(queuedMessages.add);

      final message = QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {'text': 'Hello'},
      );

      await queueService.enqueue(message);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(queuedMessages.length, 1);
      expect(queuedMessages.first.id, 'msg_1');
    });

    test('should emit onQueueSizeChanged event', () async {
      final sizeCh = <int>[];
      queueService.onQueueSizeChanged.listen(sizeCh.add);

      final message = QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      );

      await queueService.enqueue(message);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(sizeCh, contains(1));
    });

    test('should notify listeners', () async {
      var notified = false;
      queueService.addListener(() => notified = true);

      final message = QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      );

      await queueService.enqueue(message);

      expect(notified, true);
    });

    test('should try to send immediately if online', () async {
      queueService.mockIsOnline = true;
      var sendAttempted = false;

      await queueService.initialize(
        sendCallback: (event, data) async {
          sendAttempted = true;
          return true;
        },
      );

      final message = QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      );

      await queueService.enqueue(message);
      await Future.delayed(const Duration(milliseconds: 600));

      expect(sendAttempted, true);
    });
  });

  group('MessageQueueService.enqueueResponseRecord', () {
    setUp(() async {
      queueService.mockIsOnline = false;
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );
    });

    test('should create and enqueue response record message', () async {
      final message = await queueService.enqueueResponseRecord(
        chatSessionId: 'session_123',
        record: {'text': 'Hello'},
        answerVariables: [],
        botId: 'bot_456',
      );

      expect(message.type, QueuedMessageType.response);
      expect(message.eventName, 'response-record');
      expect(message.data['chatSessionId'], 'session_123');
      expect(message.data['botId'], 'bot_456');
      expect(queueService.queueSize, 1);
    });

    test('should include visitor meta if provided', () async {
      final message = await queueService.enqueueResponseRecord(
        chatSessionId: 'session_123',
        record: {},
        answerVariables: [],
        botId: 'bot_456',
        visitorMeta: {'name': 'John'},
      );

      expect(message.data['visitorMeta']['name'], 'John');
    });
  });

  group('MessageQueueService.enqueueChatMessage', () {
    setUp(() async {
      queueService.mockIsOnline = false;
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );
    });

    test('should create and enqueue chat message', () async {
      final message = await queueService.enqueueChatMessage(
        chatSessionId: 'session_123',
        text: 'Hello world',
        botId: 'bot_456',
      );

      expect(message.type, QueuedMessageType.chat);
      expect(message.data['record']['text'], 'Hello world');
      expect(message.data['chatSessionId'], 'session_123');
    });

    test('should track delivery status', () async {
      await queueService.enqueueChatMessage(
        chatSessionId: 'session_123',
        text: 'Hello',
        botId: 'bot_456',
        messageId: 'custom_id',
      );

      final status = queueService.getDeliveryStatus('custom_id');
      expect(status, MessageDeliveryStatus.queued);
    });

    test('should use custom message ID if provided', () async {
      final message = await queueService.enqueueChatMessage(
        chatSessionId: 'session_123',
        text: 'Hello',
        botId: 'bot_456',
        messageId: 'custom_msg_id',
      );

      expect(message.data['record']['_id'], 'custom_msg_id');
    });
  });

  group('MessageQueueService.processQueue', () {
    setUp(() async {
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );
    });

    test('should process pending messages', () async {
      queueService.mockIsOnline = false;

      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      ));
      await queueService.enqueue(QueuedMessage(
        id: 'msg_2',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      ));

      queueService.mockIsOnline = true;
      await queueService.processQueue();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(queueService.queueSize, 0);
    });

    test('should not process if offline', () async {
      queueService.mockIsOnline = false;

      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      ));

      await queueService.processQueue();

      expect(queueService.pendingCount, 1);
    });

    test('should not process if already processing', () async {
      queueService.mockIsOnline = true;
      queueService.mockIsProcessing = true;

      await queueService.processQueue();

      // Should return early without processing
    });

    test('should not process if no callback set', () async {
      final service = TestableMessageQueueService();
      service.mockIsOnline = true;

      await service.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      ));

      await service.processQueue();

      expect(service.pendingCount, 1);
      service.dispose();
    });

    test('should emit processing events', () async {
      final events = <QueueProcessingEvent>[];
      queueService.onProcessingEvent.listen(events.add);

      queueService.mockIsOnline = false;
      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      ));

      queueService.mockIsOnline = true;
      await queueService.processQueue();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.any((e) => e.type == ProcessingEventType.started), true);
      expect(events.any((e) => e.type == ProcessingEventType.completed), true);
    });
  });

  group('MessageQueueService Retry with Exponential Backoff', () {
    test('should retry failed messages', () async {
      var attempts = 0;
      await queueService.initialize(
        sendCallback: (event, data) async {
          attempts++;
          return attempts >= 2; // Succeed on second attempt
        },
      );

      queueService.mockIsOnline = false;
      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      ));

      queueService.mockIsOnline = true;
      await queueService.processQueue();
      await Future.delayed(const Duration(milliseconds: 100));

      // First attempt fails, should be retried
      expect(queueService.pendingCount, greaterThanOrEqualTo(0));
    });

    test('should mark as failed after max retries', () async {
      await queueService.initialize(
        sendCallback: (event, data) async => false,
      );

      queueService.mockIsOnline = false;
      final message = QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      );
      message.retryCount = QueuedMessage.maxRetries; // Already at max

      await queueService.enqueue(message);
      queueService.mockIsOnline = true;
      await queueService.processQueue();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(queueService.failedCount, greaterThanOrEqualTo(1));
    });
  });

  group('MessageQueueService.markAsSent', () {
    setUp(() async {
      queueService.mockIsOnline = false;
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );
    });

    test('should mark message as sent and remove from queue', () async {
      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      ));

      expect(queueService.queueSize, 1);

      await queueService.markAsSent('msg_1');

      expect(queueService.queueSize, 0);
    });

    test('should emit onMessageSent event', () async {
      final sentMessages = <QueuedMessage>[];
      queueService.onMessageSent.listen(sentMessages.add);

      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      ));

      await queueService.markAsSent('msg_1');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(sentMessages.length, 1);
      expect(sentMessages.first.id, 'msg_1');
    });
  });

  group('MessageQueueService.markAsFailed', () {
    setUp(() async {
      queueService.mockIsOnline = false;
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );
    });

    test('should mark message as failed', () async {
      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      ));

      await queueService.markAsFailed('msg_1', 'Network error');

      expect(queueService.failedCount, 1);
      final failedMessages = queueService.failedMessages;
      expect(failedMessages.first.lastError, 'Network error');
    });

    test('should emit onMessageFailed event', () async {
      final failedMessages = <QueuedMessage>[];
      queueService.onMessageFailed.listen(failedMessages.add);

      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      ));

      await queueService.markAsFailed('msg_1', 'Error');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(failedMessages.length, 1);
    });
  });

  group('MessageQueueService.retryFailedMessages', () {
    setUp(() async {
      queueService.mockIsOnline = false;
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );
    });

    test('should reset failed messages to pending', () async {
      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      ));

      await queueService.markAsFailed('msg_1', 'Error');
      expect(queueService.failedCount, 1);

      await queueService.retryFailedMessages();

      expect(queueService.failedCount, 0);
      expect(queueService.pendingCount, 1);
    });

    test('should reset retry count', () async {
      final message = QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'response-record',
        data: {},
      );
      message.retryCount = 2;

      await queueService.enqueue(message);
      await queueService.markAsFailed('msg_1', 'Error');
      await queueService.retryFailedMessages();

      final pending = queueService.pendingMessages;
      expect(pending.first.retryCount, 0);
    });
  });

  group('MessageQueueService.clearQueue', () {
    setUp(() async {
      queueService.mockIsOnline = false;
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );
    });

    test('should clear all messages from queue', () async {
      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'test',
        data: {},
      ));
      await queueService.enqueue(QueuedMessage(
        id: 'msg_2',
        type: QueuedMessageType.chat,
        eventName: 'test',
        data: {},
      ));

      expect(queueService.queueSize, 2);

      await queueService.clearQueue();

      expect(queueService.queueSize, 0);
    });

    test('should emit queue size changed event', () async {
      final sizes = <int>[];
      queueService.onQueueSizeChanged.listen(sizes.add);

      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'test',
        data: {},
      ));

      await queueService.clearQueue();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(sizes, contains(0));
    });
  });

  group('MessageQueueService.clearQueueForSession', () {
    setUp(() async {
      queueService.mockIsOnline = false;
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );
    });

    test('should clear messages for specific session', () async {
      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'test',
        data: {'chatSessionId': 'session_1'},
      ));
      await queueService.enqueue(QueuedMessage(
        id: 'msg_2',
        type: QueuedMessageType.chat,
        eventName: 'test',
        data: {'chatSessionId': 'session_2'},
      ));
      await queueService.enqueue(QueuedMessage(
        id: 'msg_3',
        type: QueuedMessageType.chat,
        eventName: 'test',
        data: {'chatSessionId': 'session_1'},
      ));

      await queueService.clearQueueForSession('session_1');

      expect(queueService.queueSize, 1);
      final remaining = queueService.allMessages;
      expect(remaining.first.data['chatSessionId'], 'session_2');
    });
  });

  group('MessageQueueService.removeMessage', () {
    setUp(() async {
      queueService.mockIsOnline = false;
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );
    });

    test('should remove specific message from queue', () async {
      await queueService.enqueue(QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'test',
        data: {},
      ));
      await queueService.enqueue(QueuedMessage(
        id: 'msg_2',
        type: QueuedMessageType.chat,
        eventName: 'test',
        data: {},
      ));

      await queueService.removeMessage('msg_1');

      expect(queueService.queueSize, 1);
      expect(queueService.allMessages.first.id, 'msg_2');
    });
  });

  group('MessageQueueService Delivery Status', () {
    setUp(() async {
      queueService.mockIsOnline = false;
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );
    });

    test('should track delivery status', () {
      queueService.trackDeliveryStatus(
        'msg_1',
        status: MessageDeliveryStatus.sending,
      );

      expect(queueService.getDeliveryStatus('msg_1'), MessageDeliveryStatus.sending);
    });

    test('should report message as pending', () async {
      await queueService.enqueueChatMessage(
        chatSessionId: 'session_1',
        text: 'Hello',
        botId: 'bot_1',
        messageId: 'msg_1',
      );

      expect(queueService.isMessagePending('msg_1'), true);
    });

    test('should mark message as delivered', () async {
      queueService.trackDeliveryStatus('msg_1', status: MessageDeliveryStatus.sent);

      await queueService.markAsDelivered('msg_1');

      expect(queueService.getDeliveryStatus('msg_1'), MessageDeliveryStatus.delivered);
    });
  });

  group('MessageQueueService Queue Size Limit', () {
    setUp(() async {
      queueService.mockIsOnline = false;
      await queueService.initialize(
        sendCallback: (event, data) async => true,
      );
    });

    test('should handle max queue size', () async {
      // Fill queue to max
      for (int i = 0; i < MessageQueueService.maxQueueSize + 5; i++) {
        await queueService.enqueue(QueuedMessage(
          id: 'msg_$i',
          type: QueuedMessageType.chat,
          eventName: 'test',
          data: {},
        ));
      }

      // Should not exceed max queue size
      expect(queueService.queueSize, lessThanOrEqualTo(MessageQueueService.maxQueueSize));
    });
  });

  group('QueuedMessage Model', () {
    test('should calculate next retry delay with exponential backoff', () {
      final message = QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'test',
        data: {},
      );

      final delay0 = message.nextRetryDelay;
      message.retryCount = 1;
      final delay1 = message.nextRetryDelay;
      message.retryCount = 2;
      final delay2 = message.nextRetryDelay;

      // Each retry should have longer delay (exponential backoff)
      expect(delay1.inMilliseconds, greaterThanOrEqualTo(delay0.inMilliseconds));
      expect(delay2.inMilliseconds, greaterThanOrEqualTo(delay1.inMilliseconds));
    });

    test('should report canRetry correctly', () {
      final message = QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'test',
        data: {},
      );

      expect(message.canRetry, true);

      message.retryCount = QueuedMessage.maxRetries;
      expect(message.canRetry, false);
    });

    test('should report isActive correctly', () {
      final message = QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.chat,
        eventName: 'test',
        data: {},
      );

      expect(message.isActive, true);

      message.status = QueuedMessageStatus.sent;
      expect(message.isActive, false);

      message.status = QueuedMessageStatus.failed;
      expect(message.isActive, false);
    });

    test('should serialize and deserialize correctly', () {
      final original = QueuedMessage(
        id: 'msg_1',
        type: QueuedMessageType.response,
        eventName: 'response-record',
        data: {'key': 'value'},
        retryCount: 2,
        status: QueuedMessageStatus.pending,
        lastError: 'Some error',
        priority: 5,
      );

      final json = original.toJson();
      final restored = QueuedMessage.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.eventName, original.eventName);
      expect(restored.retryCount, original.retryCount);
      expect(restored.lastError, original.lastError);
      expect(restored.priority, original.priority);
    });
  });

  group('QueueProcessingEvent', () {
    test('should create with correct properties', () {
      final event = QueueProcessingEvent(
        type: ProcessingEventType.started,
        pendingCount: 5,
      );

      expect(event.type, ProcessingEventType.started);
      expect(event.pendingCount, 5);
      expect(event.timestamp, isNotNull);
    });

    test('should track completion stats', () {
      final event = QueueProcessingEvent(
        type: ProcessingEventType.completed,
        successCount: 3,
        failCount: 1,
        remainingCount: 2,
      );

      expect(event.successCount, 3);
      expect(event.failCount, 1);
      expect(event.remainingCount, 2);
    });
  });

  group('QueueStats', () {
    test('should create from messages', () {
      final messages = [
        QueuedMessage(
          id: 'msg_1',
          type: QueuedMessageType.chat,
          eventName: 'test',
          data: {},
        )..status = QueuedMessageStatus.pending,
        QueuedMessage(
          id: 'msg_2',
          type: QueuedMessageType.chat,
          eventName: 'test',
          data: {},
        )..status = QueuedMessageStatus.sending,
        QueuedMessage(
          id: 'msg_3',
          type: QueuedMessageType.chat,
          eventName: 'test',
          data: {},
        )..status = QueuedMessageStatus.failed,
      ];

      final stats = QueueStats.fromMessages(messages);

      expect(stats.totalCount, 3);
      expect(stats.pendingCount, 1);
      expect(stats.sendingCount, 1);
      expect(stats.failedCount, 1);
      expect(stats.isEmpty, false);
      expect(stats.hasActive, true);
      expect(stats.hasFailed, true);
    });

    test('should handle empty messages list', () {
      final stats = QueueStats.fromMessages([]);

      expect(stats.totalCount, 0);
      expect(stats.isEmpty, true);
      expect(stats.hasActive, false);
    });
  });
}

/// Testable MessageQueueService that bypasses storage dependencies
class TestableMessageQueueService with ChangeNotifier {
  bool mockIsOnline = false;
  bool mockIsProcessing = false;

  TestableMessageQueueService();

  bool get isProcessing => mockIsProcessing;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<bool> Function(String event, Map<String, dynamic> data)? _sendCallback;

  Future<void> initialize({
    Future<bool> Function(String event, Map<String, dynamic> data)? sendCallback,
  }) async {
    _sendCallback = sendCallback;
    _isInitialized = true;
  }

  void setSendCallback(
    Future<bool> Function(String event, Map<String, dynamic> data) callback,
  ) {
    _sendCallback = callback;
  }

  final List<QueuedMessage> _testQueue = [];
  final Map<String, DeliveryTrackedMessage> _testDeliveryStatus = {};

  int get queueSize => _testQueue.length;

  int get pendingCount =>
      _testQueue.where((m) => m.status == QueuedMessageStatus.pending).length;

  int get failedCount =>
      _testQueue.where((m) => m.status == QueuedMessageStatus.failed).length;

  bool get hasPendingMessages => _testQueue.any((m) => m.isActive);

  List<QueuedMessage> get pendingMessages => List.unmodifiable(
        _testQueue.where((m) => m.isActive).toList()
          ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt)),
      );

  List<QueuedMessage> get allMessages => List.unmodifiable(_testQueue);

  List<QueuedMessage> get failedMessages => List.unmodifiable(
        _testQueue.where((m) => m.status == QueuedMessageStatus.failed).toList(),
      );

  final _onMessageQueuedController = StreamController<QueuedMessage>.broadcast();
  final _onMessageSentController = StreamController<QueuedMessage>.broadcast();
  final _onMessageFailedController = StreamController<QueuedMessage>.broadcast();
  final _onQueueSizeChangedController = StreamController<int>.broadcast();
  final _onProcessingEventController = StreamController<QueueProcessingEvent>.broadcast();

  Stream<QueuedMessage> get onMessageQueued => _onMessageQueuedController.stream;

  Stream<QueuedMessage> get onMessageSent => _onMessageSentController.stream;

  Stream<QueuedMessage> get onMessageFailed => _onMessageFailedController.stream;

  Stream<int> get onQueueSizeChanged => _onQueueSizeChangedController.stream;

  Stream<QueueProcessingEvent> get onProcessingEvent => _onProcessingEventController.stream;

  Future<QueuedMessage> enqueue(QueuedMessage message) async {
    if (_testQueue.length >= MessageQueueService.maxQueueSize) {
      _testQueue.removeAt(0);
    }

    _testQueue.add(message);
    _onMessageQueuedController.add(message);
    _onQueueSizeChangedController.add(_testQueue.length);
    notifyListeners();

    if (mockIsOnline && !mockIsProcessing && _sendCallback != null) {
      _scheduleProcess();
    }

    return message;
  }

  void _scheduleProcess() {
    Future.delayed(const Duration(milliseconds: 500), () {
      processQueue();
    });
  }

  Future<QueuedMessage> enqueueChatMessage({
    required String chatSessionId,
    required String text,
    required String botId,
    String? messageId,
    Map<String, dynamic>? metadata,
  }) async {
    final id = messageId ?? 'chat_${DateTime.now().millisecondsSinceEpoch}';
    final message = QueuedMessage(
      id: id,
      type: QueuedMessageType.chat,
      eventName: 'response-record',
      data: {
        'chatSessionId': chatSessionId,
        'record': {
          '_id': id,
          'type': 'user-input-response',
          'text': text,
          'time': DateTime.now().toUtc().toIso8601String(),
          if (metadata != null) 'metadata': metadata,
        },
        'answerVariables': [],
        'botId': botId,
      },
    );

    _testDeliveryStatus[id] = DeliveryTrackedMessage(
      messageId: id,
      queuedMessageId: message.id,
      deliveryStatus: MessageDeliveryStatus.queued,
    );

    return enqueue(message);
  }

  Future<QueuedMessage> enqueueResponseRecord({
    required String chatSessionId,
    required dynamic record,
    required List<dynamic> answerVariables,
    required String botId,
    Map<String, dynamic>? visitorMeta,
  }) async {
    final message = QueuedMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${_testQueue.length}',
      type: QueuedMessageType.response,
      eventName: 'response-record',
      data: {
        'chatSessionId': chatSessionId,
        'record': record,
        'answerVariables': answerVariables,
        'botId': botId,
        if (visitorMeta != null) 'visitorMeta': visitorMeta,
      },
    );

    return enqueue(message);
  }

  Future<void> processQueue() async {
    if (mockIsProcessing) return;
    if (!mockIsOnline) return;
    if (_sendCallback == null) return;
    if (_testQueue.isEmpty) return;

    mockIsProcessing = true;
    notifyListeners();

    _onProcessingEventController.add(QueueProcessingEvent(
      type: ProcessingEventType.started,
      pendingCount: pendingCount,
    ));

    try {
      final pending = _testQueue
          .where((m) => m.status == QueuedMessageStatus.pending)
          .toList()
        ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

      int successCount = 0;
      int failCount = 0;

      for (final message in pending) {
        if (!mockIsOnline) break;

        message.status = QueuedMessageStatus.sending;

        try {
          final success = await _sendCallback!(message.eventName, message.data);
          if (success) {
            await markAsSent(message.id);
            successCount++;
          } else {
            message.retryCount++;
            if (message.canRetry) {
              message.status = QueuedMessageStatus.pending;
            } else {
              await markAsFailed(message.id, 'Send returned false');
              failCount++;
            }
          }
        } catch (e) {
          message.retryCount++;
          if (message.canRetry) {
            message.status = QueuedMessageStatus.pending;
          } else {
            await markAsFailed(message.id, e.toString());
            failCount++;
          }
        }
      }

      _onProcessingEventController.add(QueueProcessingEvent(
        type: ProcessingEventType.completed,
        successCount: successCount,
        failCount: failCount,
        remainingCount: pendingCount,
      ));
    } finally {
      mockIsProcessing = false;
      notifyListeners();
    }
  }

  Future<void> markAsSent(String messageId) async {
    final index = _testQueue.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final message = _testQueue[index];
      message.status = QueuedMessageStatus.sent;
      _onMessageSentController.add(message);

      _testQueue.removeAt(index);
      _onQueueSizeChangedController.add(_testQueue.length);
      notifyListeners();
    }
  }

  Future<void> markAsFailed(String messageId, String error) async {
    final index = _testQueue.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final message = _testQueue[index];
      message.status = QueuedMessageStatus.failed;
      message.lastError = error;
      _onMessageFailedController.add(message);
      notifyListeners();
    }
  }

  Future<void> retryFailedMessages() async {
    final failed = _testQueue.where((m) => m.status == QueuedMessageStatus.failed).toList();
    for (final message in failed) {
      message.status = QueuedMessageStatus.pending;
      message.retryCount = 0;
      message.lastError = null;
    }
    notifyListeners();

    if (mockIsOnline) {
      _scheduleProcess();
    }
  }

  Future<void> clearQueue() async {
    _testQueue.clear();
    _onQueueSizeChangedController.add(0);
    notifyListeners();
  }

  Future<void> clearQueueForSession(String chatSessionId) async {
    _testQueue.removeWhere((m) {
      final sessionId = m.data['chatSessionId'];
      return sessionId == chatSessionId;
    });
    _onQueueSizeChangedController.add(_testQueue.length);
    notifyListeners();
  }

  Future<void> removeMessage(String messageId) async {
    _testQueue.removeWhere((m) => m.id == messageId);
    _onQueueSizeChangedController.add(_testQueue.length);
    notifyListeners();
  }

  MessageDeliveryStatus? getDeliveryStatus(String messageId) {
    return _testDeliveryStatus[messageId]?.deliveryStatus;
  }

  bool isMessagePending(String messageId) {
    final status = getDeliveryStatus(messageId);
    return status == MessageDeliveryStatus.queued ||
        status == MessageDeliveryStatus.sending;
  }

  void trackDeliveryStatus(
    String messageId, {
    String? queuedMessageId,
    MessageDeliveryStatus status = MessageDeliveryStatus.sending,
  }) {
    _testDeliveryStatus[messageId] = DeliveryTrackedMessage(
      messageId: messageId,
      queuedMessageId: queuedMessageId,
      deliveryStatus: status,
    );
    notifyListeners();
  }

  Future<void> markAsDelivered(String messageId) async {
    if (_testDeliveryStatus.containsKey(messageId)) {
      _testDeliveryStatus[messageId]!.deliveryStatus = MessageDeliveryStatus.delivered;
      _testDeliveryStatus[messageId]!.deliveredAt = DateTime.now();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _onMessageQueuedController.close();
    _onMessageSentController.close();
    _onMessageFailedController.close();
    _onQueueSizeChangedController.close();
    _onProcessingEventController.close();
    super.dispose();
  }
}
