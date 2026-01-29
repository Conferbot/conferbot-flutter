import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/queued_message.dart';
import '../utils/logger.dart';
import 'connectivity_service.dart';

/// Hive box names for message queue persistence
class QueueBoxNames {
  static const String messageQueue = 'conferbot_message_queue';
  static const String deliveryStatus = 'conferbot_delivery_status';
}

/// Service for managing offline message queue.
/// Persists messages locally using Hive and processes them when connection is restored.
///
/// Features:
/// - Automatic queuing when offline
/// - Persistent storage across app restarts
/// - Automatic retry with exponential backoff
/// - Delivery status tracking for UI updates
/// - Session-aware queue management
class MessageQueueService with ChangeNotifier {
  static MessageQueueService? _instance;
  static MessageQueueService get instance {
    _instance ??= MessageQueueService._internal();
    return _instance!;
  }

  MessageQueueService._internal();

  /// For testing purposes - creates isolated instance
  @visibleForTesting
  factory MessageQueueService.forTesting() {
    return MessageQueueService._internal();
  }

  /// Reset singleton for testing
  @visibleForTesting
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  // Dependencies
  final ConnectivityService _connectivity = ConnectivityService.instance;

  // Hive boxes for persistence
  Box<String>? _queueBox;
  Box<String>? _deliveryBox;

  // Queue state
  final List<QueuedMessage> _queue = [];
  final Map<String, DeliveryTrackedMessage> _deliveryStatus = {};
  bool _isProcessing = false;
  bool _isInitialized = false;
  Timer? _processTimer;
  Timer? _retryTimer;
  StreamSubscription<bool>? _connectivitySubscription;

  // Configuration
  static const int maxQueueSize = 100;
  static const Duration processingDebounce = Duration(milliseconds: 500);
  static const Duration cleanupAge = Duration(days: 7);

  // Stream controllers for reactive updates
  final StreamController<QueuedMessage> _onMessageQueuedController =
      StreamController<QueuedMessage>.broadcast();
  final StreamController<QueuedMessage> _onMessageSentController =
      StreamController<QueuedMessage>.broadcast();
  final StreamController<QueuedMessage> _onMessageFailedController =
      StreamController<QueuedMessage>.broadcast();
  final StreamController<int> _onQueueSizeChangedController =
      StreamController<int>.broadcast();
  final StreamController<QueueProcessingEvent> _onProcessingEventController =
      StreamController<QueueProcessingEvent>.broadcast();

  // Callback for actually sending messages
  Future<bool> Function(String event, Map<String, dynamic> data)? _sendCallback;

  // ========== Getters ==========

  /// Stream of messages being queued
  Stream<QueuedMessage> get onMessageQueued => _onMessageQueuedController.stream;

  /// Stream of messages successfully sent
  Stream<QueuedMessage> get onMessageSent => _onMessageSentController.stream;

  /// Stream of messages that failed to send
  Stream<QueuedMessage> get onMessageFailed => _onMessageFailedController.stream;

  /// Stream of queue size changes
  Stream<int> get onQueueSizeChanged => _onQueueSizeChangedController.stream;

  /// Stream of queue processing events
  Stream<QueueProcessingEvent> get onProcessingEvent =>
      _onProcessingEventController.stream;

  /// Current queue size
  int get queueSize => _queue.length;

  /// Number of pending messages
  int get pendingCount =>
      _queue.where((m) => m.status == QueuedMessageStatus.pending).length;

  /// Number of failed messages
  int get failedCount =>
      _queue.where((m) => m.status == QueuedMessageStatus.failed).length;

  /// Whether the queue is currently processing
  bool get isProcessing => _isProcessing;

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether there are any pending or sending messages
  bool get hasPendingMessages => _queue.any((m) => m.isActive);

  /// Get all pending messages
  List<QueuedMessage> get pendingMessages => List.unmodifiable(
        _queue.where((m) => m.isActive).toList()
          ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt)),
      );

  /// Get all queued messages
  List<QueuedMessage> get allMessages => List.unmodifiable(_queue);

  /// Get all failed messages
  List<QueuedMessage> get failedMessages => List.unmodifiable(
        _queue.where((m) => m.status == QueuedMessageStatus.failed).toList(),
      );

  // ========== Initialization ==========

  /// Initialize the message queue service.
  /// Should be called before using the service.
  Future<void> initialize({
    Future<bool> Function(String event, Map<String, dynamic> data)? sendCallback,
  }) async {
    if (_isInitialized) return;

    _sendCallback = sendCallback;

    try {
      // Open Hive boxes for persistence
      await _initializeStorage();

      // Load persisted queue
      await _loadQueue();
      await _loadDeliveryStatus();

      // Listen for connectivity changes
      _connectivitySubscription?.cancel();
      _connectivitySubscription = _connectivity.onlineStatus.listen((isOnline) {
        if (isOnline) {
          queueLogger.debug('Connection restored, processing queue...');
          _scheduleProcessQueue();
        }
      });

      _isInitialized = true;
      queueLogger.debug('Message queue initialized with ${_queue.length} pending messages');

      // Process queue if online
      if (_connectivity.isOnline && _queue.isNotEmpty) {
        _scheduleProcessQueue();
      }
    } catch (e, stackTrace) {
      queueLogger.error('Failed to initialize message queue', e, stackTrace);
      _isInitialized = true; // Mark as initialized even on error to avoid blocking
    }
  }

  /// Initialize Hive storage
  Future<void> _initializeStorage() async {
    try {
      if (!Hive.isBoxOpen(QueueBoxNames.messageQueue)) {
        _queueBox = await Hive.openBox<String>(QueueBoxNames.messageQueue);
      } else {
        _queueBox = Hive.box<String>(QueueBoxNames.messageQueue);
      }

      if (!Hive.isBoxOpen(QueueBoxNames.deliveryStatus)) {
        _deliveryBox = await Hive.openBox<String>(QueueBoxNames.deliveryStatus);
      } else {
        _deliveryBox = Hive.box<String>(QueueBoxNames.deliveryStatus);
      }
    } catch (e) {
      queueLogger.error('Error initializing storage, clearing corrupted data: $e');
      await _clearAndRetryStorage();
    }
  }

  /// Clear corrupted storage and retry
  Future<void> _clearAndRetryStorage() async {
    try {
      await Hive.deleteBoxFromDisk(QueueBoxNames.messageQueue);
      await Hive.deleteBoxFromDisk(QueueBoxNames.deliveryStatus);

      _queueBox = await Hive.openBox<String>(QueueBoxNames.messageQueue);
      _deliveryBox = await Hive.openBox<String>(QueueBoxNames.deliveryStatus);
    } catch (e) {
      queueLogger.error('Failed to recover storage: $e');
    }
  }

  /// Set the send callback for processing queue
  void setSendCallback(
    Future<bool> Function(String event, Map<String, dynamic> data) callback,
  ) {
    _sendCallback = callback;
  }

  // ========== Queue Management ==========

  /// Enqueue a message for sending.
  /// Returns the queued message with assigned ID.
  Future<QueuedMessage> enqueue(QueuedMessage message) async {
    // Check queue size limit
    if (_queue.length >= maxQueueSize) {
      // Remove oldest sent/failed messages to make room
      _pruneQueue();
      if (_queue.length >= maxQueueSize) {
        queueLogger.warning('Queue full, removing oldest pending message');
        _queue.removeAt(0);
      }
    }

    // Add to queue
    _queue.add(message);
    _onMessageQueuedController.add(message);
    _onQueueSizeChangedController.add(_queue.length);

    // Persist queue
    await _saveQueue();

    queueLogger.debug('Message queued: ${message.id} (${message.type.value})');
    notifyListeners();

    // Try to send immediately if online
    if (_connectivity.isOnline && !_isProcessing) {
      _scheduleProcessQueue();
    }

    return message;
  }

  /// Create and enqueue a response record message
  Future<QueuedMessage> enqueueResponseRecord({
    required String chatSessionId,
    required dynamic record,
    required List<dynamic> answerVariables,
    required String botId,
    Map<String, dynamic>? visitorMeta,
  }) async {
    final message = QueuedMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${_queue.length}',
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

  /// Create and enqueue a chat message
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

    // Track delivery status for this message
    _deliveryStatus[id] = DeliveryTrackedMessage(
      messageId: id,
      queuedMessageId: message.id,
      deliveryStatus: MessageDeliveryStatus.queued,
    );
    await _saveDeliveryStatus();

    return enqueue(message);
  }

  /// Get pending messages ordered by queue time
  Future<List<QueuedMessage>> getPendingMessages() async {
    return pendingMessages;
  }

  /// Mark a message as sent
  Future<void> markAsSent(String messageId) async {
    final index = _queue.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final message = _queue[index];
      message.status = QueuedMessageStatus.sent;

      _onMessageSentController.add(message);
      queueLogger.debug('Message marked as sent: $messageId');

      // Update delivery status
      final deliveryKey = _findDeliveryKey(messageId);
      if (deliveryKey != null && _deliveryStatus.containsKey(deliveryKey)) {
        _deliveryStatus[deliveryKey]!.deliveryStatus = MessageDeliveryStatus.sent;
        _deliveryStatus[deliveryKey]!.deliveredAt = DateTime.now();
        await _saveDeliveryStatus();
      }

      // Remove from queue after successful send
      _queue.removeAt(index);
      _onQueueSizeChangedController.add(_queue.length);
      await _saveQueue();
      notifyListeners();
    }
  }

  /// Mark a message as failed
  Future<void> markAsFailed(String messageId, String error) async {
    final index = _queue.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final message = _queue[index];
      message.status = QueuedMessageStatus.failed;
      message.lastError = error;

      _onMessageFailedController.add(message);
      queueLogger.debug('Message marked as failed: $messageId - $error');

      // Update delivery status
      final deliveryKey = _findDeliveryKey(messageId);
      if (deliveryKey != null && _deliveryStatus.containsKey(deliveryKey)) {
        _deliveryStatus[deliveryKey]!.deliveryStatus = MessageDeliveryStatus.failed;
        await _saveDeliveryStatus();
      }

      await _saveQueue();
      notifyListeners();
    }
  }

  // ========== Queue Processing ==========

  /// Schedule queue processing with debounce
  void _scheduleProcessQueue() {
    _processTimer?.cancel();
    _processTimer = Timer(processingDebounce, () {
      processQueue();
    });
  }

  /// Process the queue, attempting to send pending messages
  Future<void> processQueue() async {
    if (_isProcessing) {
      queueLogger.debug('Queue already processing, skipping...');
      return;
    }

    if (!_connectivity.isOnline) {
      queueLogger.debug('Offline, cannot process queue');
      return;
    }

    if (_sendCallback == null) {
      queueLogger.debug('No send callback configured');
      return;
    }

    if (_queue.isEmpty) {
      queueLogger.debug('Queue is empty');
      return;
    }

    _isProcessing = true;
    notifyListeners();

    _onProcessingEventController.add(QueueProcessingEvent(
      type: ProcessingEventType.started,
      pendingCount: pendingCount,
    ));

    queueLogger.debug('Processing queue with ${pendingCount} pending messages...');

    try {
      // Get pending messages sorted by queue time
      final pending = _queue
          .where((m) => m.status == QueuedMessageStatus.pending)
          .toList()
        ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

      int successCount = 0;
      int failCount = 0;

      for (final message in pending) {
        if (!_connectivity.isOnline) {
          queueLogger.debug('Connection lost during processing, stopping...');
          break;
        }

        final success = await _processMessage(message);
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      }

      _onProcessingEventController.add(QueueProcessingEvent(
        type: ProcessingEventType.completed,
        successCount: successCount,
        failCount: failCount,
        remainingCount: pendingCount,
      ));
    } finally {
      _isProcessing = false;
      notifyListeners();
      queueLogger.debug('Queue processing complete. Remaining: ${pendingCount}');
    }
  }

  /// Process a single message
  Future<bool> _processMessage(QueuedMessage message) async {
    queueLogger.debug('Processing message: ${message.id}');

    // Update status to sending
    message.status = QueuedMessageStatus.sending;

    // Update delivery status
    final deliveryKey = _findDeliveryKey(message.id);
    if (deliveryKey != null && _deliveryStatus.containsKey(deliveryKey)) {
      _deliveryStatus[deliveryKey]!.deliveryStatus = MessageDeliveryStatus.sending;
    }
    notifyListeners();

    try {
      final success = await _sendCallback!(message.eventName, message.data);

      if (success) {
        await markAsSent(message.id);
        return true;
      } else {
        await _handleSendFailure(message, 'Send returned false');
        return false;
      }
    } catch (e) {
      await _handleSendFailure(message, e.toString());
      return false;
    }
  }

  /// Handle send failure with retry logic
  Future<void> _handleSendFailure(QueuedMessage message, String error) async {
    message.retryCount++;
    message.lastError = error;

    if (message.canRetry) {
      message.status = QueuedMessageStatus.pending;
      queueLogger.debug(
        'Message ${message.id} failed, will retry (${message.retryCount}/${QueuedMessage.maxRetries}): $error',
      );

      // Schedule retry with exponential backoff
      _scheduleRetry(message);
    } else {
      await markAsFailed(message.id, error);
    }

    await _saveQueue();
    notifyListeners();
  }

  /// Schedule a retry for a message
  void _scheduleRetry(QueuedMessage message) {
    final delay = message.nextRetryDelay;
    queueLogger.debug('Scheduling retry for ${message.id} in ${delay.inSeconds}s');

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (_connectivity.isOnline && !_isProcessing) {
        processQueue();
      }
    });
  }

  /// Retry all failed messages
  Future<void> retryFailedMessages() async {
    final failed =
        _queue.where((m) => m.status == QueuedMessageStatus.failed).toList();

    if (failed.isEmpty) {
      queueLogger.debug('No failed messages to retry');
      return;
    }

    queueLogger.debug('Retrying ${failed.length} failed messages');

    for (final message in failed) {
      message.status = QueuedMessageStatus.pending;
      message.retryCount = 0;
      message.lastError = null;

      // Update delivery status
      final deliveryKey = _findDeliveryKey(message.id);
      if (deliveryKey != null && _deliveryStatus.containsKey(deliveryKey)) {
        _deliveryStatus[deliveryKey]!.deliveryStatus = MessageDeliveryStatus.queued;
      }
    }

    await _saveQueue();
    await _saveDeliveryStatus();
    notifyListeners();

    if (_connectivity.isOnline) {
      _scheduleProcessQueue();
    }
  }

  /// Clear all messages from queue
  Future<void> clearQueue() async {
    _queue.clear();
    _onQueueSizeChangedController.add(0);
    await _saveQueue();
    notifyListeners();
    queueLogger.debug('Queue cleared');
  }

  /// Clear queue for a specific session
  Future<void> clearQueueForSession(String chatSessionId) async {
    _queue.removeWhere((m) {
      final sessionId = m.data['chatSessionId'];
      return sessionId == chatSessionId;
    });
    _onQueueSizeChangedController.add(_queue.length);
    await _saveQueue();
    notifyListeners();
    queueLogger.debug('Queue cleared for session: $chatSessionId');
  }

  /// Remove a specific message from queue
  Future<void> removeMessage(String messageId) async {
    _queue.removeWhere((m) => m.id == messageId);
    _onQueueSizeChangedController.add(_queue.length);
    await _saveQueue();
    notifyListeners();
  }

  /// Prune old sent/failed messages from queue
  void _pruneQueue() {
    final now = DateTime.now();
    _queue.removeWhere((m) {
      if (m.status == QueuedMessageStatus.sent ||
          m.status == QueuedMessageStatus.failed) {
        return now.difference(m.queuedAt) > cleanupAge;
      }
      return false;
    });
  }

  // ========== Delivery Status ==========

  /// Get delivery status for a message
  MessageDeliveryStatus? getDeliveryStatus(String messageId) {
    return _deliveryStatus[messageId]?.deliveryStatus;
  }

  /// Check if a message is queued or pending
  bool isMessagePending(String messageId) {
    final status = getDeliveryStatus(messageId);
    return status == MessageDeliveryStatus.queued ||
        status == MessageDeliveryStatus.sending;
  }

  /// Track delivery status for a message ID
  void trackDeliveryStatus(
    String messageId, {
    String? queuedMessageId,
    MessageDeliveryStatus status = MessageDeliveryStatus.sending,
  }) {
    _deliveryStatus[messageId] = DeliveryTrackedMessage(
      messageId: messageId,
      queuedMessageId: queuedMessageId,
      deliveryStatus: status,
    );
    _saveDeliveryStatus();
    notifyListeners();
  }

  /// Update delivery status to delivered (confirmed by server)
  Future<void> markAsDelivered(String messageId) async {
    if (_deliveryStatus.containsKey(messageId)) {
      _deliveryStatus[messageId]!.deliveryStatus = MessageDeliveryStatus.delivered;
      _deliveryStatus[messageId]!.deliveredAt = DateTime.now();
      await _saveDeliveryStatus();
      notifyListeners();
    }
  }

  /// Find delivery key by queued message ID
  String? _findDeliveryKey(String queuedMessageId) {
    for (final entry in _deliveryStatus.entries) {
      if (entry.value.queuedMessageId == queuedMessageId ||
          entry.key == queuedMessageId) {
        return entry.key;
      }
    }
    return null;
  }

  // ========== Persistence ==========

  /// Load queue from Hive storage
  Future<void> _loadQueue() async {
    try {
      if (_queueBox == null || !_queueBox!.isOpen) return;

      _queue.clear();
      for (final key in _queueBox!.keys) {
        try {
          final jsonStr = _queueBox!.get(key);
          if (jsonStr != null) {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            final message = QueuedMessage.fromJson(json);
            // Only restore active messages
            if (message.isActive) {
              _queue.add(message);
            }
          }
        } catch (e) {
          queueLogger.warning('Error parsing queued message: $e');
        }
      }
      queueLogger.debug('Loaded ${_queue.length} messages from storage');
    } catch (e) {
      queueLogger.error('Error loading queue: $e');
    }
  }

  /// Save queue to Hive storage
  Future<void> _saveQueue() async {
    try {
      if (_queueBox == null || !_queueBox!.isOpen) return;

      await _queueBox!.clear();
      for (final message in _queue) {
        await _queueBox!.put(message.id, jsonEncode(message.toJson()));
      }
    } catch (e) {
      queueLogger.error('Error saving queue: $e');
    }
  }

  /// Load delivery status from Hive storage
  Future<void> _loadDeliveryStatus() async {
    try {
      if (_deliveryBox == null || !_deliveryBox!.isOpen) return;

      _deliveryStatus.clear();
      for (final key in _deliveryBox!.keys) {
        try {
          final jsonStr = _deliveryBox!.get(key);
          if (jsonStr != null) {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            _deliveryStatus[key as String] = DeliveryTrackedMessage.fromJson(json);
          }
        } catch (e) {
          queueLogger.warning('Error parsing delivery status: $e');
        }
      }
    } catch (e) {
      queueLogger.error('Error loading delivery status: $e');
    }
  }

  /// Save delivery status to Hive storage
  Future<void> _saveDeliveryStatus() async {
    try {
      if (_deliveryBox == null || !_deliveryBox!.isOpen) return;

      await _deliveryBox!.clear();
      for (final entry in _deliveryStatus.entries) {
        await _deliveryBox!.put(entry.key, jsonEncode(entry.value.toJson()));
      }
    } catch (e) {
      queueLogger.error('Error saving delivery status: $e');
    }
  }

  /// Clean up old delivery status entries (older than cleanup age)
  Future<void> cleanupOldEntries() async {
    final cutoff = DateTime.now().subtract(cleanupAge);

    // Remove old sent messages from queue
    _queue.removeWhere(
      (m) =>
          m.status == QueuedMessageStatus.sent && m.queuedAt.isBefore(cutoff),
    );

    // Remove old delivery status entries
    _deliveryStatus.removeWhere((key, value) {
      if (value.deliveredAt != null && value.deliveredAt!.isBefore(cutoff)) {
        return true;
      }
      return false;
    });

    await _saveQueue();
    await _saveDeliveryStatus();
  }

  // ========== Cleanup ==========

  /// Dispose of resources
  @override
  void dispose() {
    _processTimer?.cancel();
    _retryTimer?.cancel();
    _connectivitySubscription?.cancel();
    _onMessageQueuedController.close();
    _onMessageSentController.close();
    _onMessageFailedController.close();
    _onQueueSizeChangedController.close();
    _onProcessingEventController.close();
    super.dispose();
  }
}

/// Queue processing event for tracking progress
class QueueProcessingEvent {
  final ProcessingEventType type;
  final int? pendingCount;
  final int? successCount;
  final int? failCount;
  final int? remainingCount;
  final DateTime timestamp;

  QueueProcessingEvent({
    required this.type,
    this.pendingCount,
    this.successCount,
    this.failCount,
    this.remainingCount,
  }) : timestamp = DateTime.now();
}

/// Processing event types
enum ProcessingEventType {
  /// Processing has started
  started,

  /// Processing has completed
  completed,

  /// A message was sent successfully
  messageSent,

  /// A message failed to send
  messageFailed,
}
