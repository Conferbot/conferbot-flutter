import 'dart:convert';

/// Status of a queued message
enum QueuedMessageStatus {
  pending('pending'),
  sending('sending'),
  sent('sent'),
  failed('failed');

  final String value;
  const QueuedMessageStatus(this.value);

  static QueuedMessageStatus fromString(String value) {
    return QueuedMessageStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => QueuedMessageStatus.pending,
    );
  }
}

/// Type of queued message
enum QueuedMessageType {
  chat('chat'),
  response('response'),
  analytics('analytics'),
  typing('typing'),
  handover('handover'),
  attachment('attachment');

  final String value;
  const QueuedMessageType(this.value);

  static QueuedMessageType fromString(String value) {
    return QueuedMessageType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => QueuedMessageType.chat,
    );
  }
}

/// A message that has been queued for sending when offline.
///
/// Supports:
/// - Automatic retry with exponential backoff
/// - Status tracking for UI updates
/// - Persistence across app restarts
/// - Priority ordering by queue time
class QueuedMessage {
  /// Unique identifier for this queued message
  final String id;

  /// Type of message (chat, response, analytics, etc.)
  final QueuedMessageType type;

  /// Socket event name to emit when sending
  final String eventName;

  /// The message data payload
  final Map<String, dynamic> data;

  /// When the message was queued
  final DateTime queuedAt;

  /// Number of retry attempts
  int retryCount;

  /// Current status of the message
  QueuedMessageStatus status;

  /// Last error message if failed
  String? lastError;

  /// Priority (lower = higher priority)
  final int priority;

  /// Maximum retry attempts before marking as failed
  static const int maxRetries = 3;

  /// Delay between retries in milliseconds (exponential backoff base)
  static const int retryDelayBaseMs = 1000;

  /// Maximum retry delay in milliseconds
  static const int maxRetryDelayMs = 30000;

  QueuedMessage({
    required this.id,
    required this.type,
    required this.eventName,
    required this.data,
    DateTime? queuedAt,
    this.retryCount = 0,
    this.status = QueuedMessageStatus.pending,
    this.lastError,
    this.priority = 0,
  }) : queuedAt = queuedAt ?? DateTime.now();

  /// Create a copy with updated fields
  QueuedMessage copyWith({
    String? id,
    QueuedMessageType? type,
    String? eventName,
    Map<String, dynamic>? data,
    DateTime? queuedAt,
    int? retryCount,
    QueuedMessageStatus? status,
    String? lastError,
    int? priority,
  }) {
    return QueuedMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      eventName: eventName ?? this.eventName,
      data: data ?? Map<String, dynamic>.from(this.data),
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      priority: priority ?? this.priority,
    );
  }

  /// Calculate next retry delay with exponential backoff and jitter
  Duration get nextRetryDelay {
    // Exponential backoff: base * 2^retryCount
    final baseDelay = retryDelayBaseMs * (1 << retryCount);

    // Add jitter (10-20% random variance)
    final jitter = (baseDelay * 0.1) +
        (DateTime.now().millisecond % (baseDelay ~/ 10));

    final delay = (baseDelay + jitter.toInt()).clamp(
      retryDelayBaseMs,
      maxRetryDelayMs,
    );

    return Duration(milliseconds: delay);
  }

  /// Whether this message can be retried
  bool get canRetry => retryCount < maxRetries;

  /// Whether this message is pending or sending
  bool get isActive =>
      status == QueuedMessageStatus.pending ||
      status == QueuedMessageStatus.sending;

  /// Whether this message has permanently failed
  bool get hasFailed =>
      status == QueuedMessageStatus.failed && !canRetry;

  /// Get the chat session ID from the data payload
  String? get chatSessionId => data['chatSessionId'] as String?;

  /// Get the associated message ID from the record (if available)
  String? get messageId {
    final record = data['record'];
    if (record is Map) {
      return record['_id'] as String? ?? record['id'] as String?;
    }
    return null;
  }

  /// Age of this queued message
  Duration get age => DateTime.now().difference(queuedAt);

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'eventName': eventName,
      'data': data,
      'queuedAt': queuedAt.toIso8601String(),
      'retryCount': retryCount,
      'status': status.value,
      'lastError': lastError,
      'priority': priority,
    };
  }

  /// Create from JSON
  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      id: json['id'] as String,
      type: QueuedMessageType.fromString(json['type'] as String),
      eventName: json['eventName'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      status: QueuedMessageStatus.fromString(json['status'] as String? ?? 'pending'),
      lastError: json['lastError'] as String?,
      priority: json['priority'] as int? ?? 0,
    );
  }

  /// Serialize to string for storage
  String serialize() => jsonEncode(toJson());

  /// Deserialize from string
  factory QueuedMessage.deserialize(String data) {
    return QueuedMessage.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  @override
  String toString() {
    return 'QueuedMessage(id: $id, type: ${type.value}, status: ${status.value}, retryCount: $retryCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueuedMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Delivery status for messages in the UI
enum MessageDeliveryStatus {
  /// Message is being sent
  sending,

  /// Message was queued because offline
  queued,

  /// Message was sent successfully
  sent,

  /// Message delivery confirmed by server
  delivered,

  /// Message delivery failed
  failed,
}

/// Extension to get human-readable descriptions
extension MessageDeliveryStatusExtension on MessageDeliveryStatus {
  String get description {
    switch (this) {
      case MessageDeliveryStatus.sending:
        return 'Sending...';
      case MessageDeliveryStatus.queued:
        return 'Waiting to send';
      case MessageDeliveryStatus.sent:
        return 'Sent';
      case MessageDeliveryStatus.delivered:
        return 'Delivered';
      case MessageDeliveryStatus.failed:
        return 'Failed to send';
    }
  }

  bool get isInProgress =>
      this == MessageDeliveryStatus.sending ||
      this == MessageDeliveryStatus.queued;
}

/// Tracks delivery status for a message with metadata
class DeliveryTrackedMessage {
  /// The ID of the message in the conversation
  final String messageId;

  /// The ID of the queued message (if applicable)
  final String? queuedMessageId;

  /// Current delivery status
  MessageDeliveryStatus deliveryStatus;

  /// When the message was delivered (if successful)
  DateTime? deliveredAt;

  /// When tracking started
  final DateTime createdAt;

  DeliveryTrackedMessage({
    required this.messageId,
    this.queuedMessageId,
    this.deliveryStatus = MessageDeliveryStatus.sending,
    this.deliveredAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Whether this message is still in progress
  bool get isInProgress => deliveryStatus.isInProgress;

  /// Whether this message was successfully delivered
  bool get wasDelivered =>
      deliveryStatus == MessageDeliveryStatus.sent ||
      deliveryStatus == MessageDeliveryStatus.delivered;

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'queuedMessageId': queuedMessageId,
      'deliveryStatus': deliveryStatus.name,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DeliveryTrackedMessage.fromJson(Map<String, dynamic> json) {
    return DeliveryTrackedMessage(
      messageId: json['messageId'] as String,
      queuedMessageId: json['queuedMessageId'] as String?,
      deliveryStatus: MessageDeliveryStatus.values.firstWhere(
        (e) => e.name == json['deliveryStatus'],
        orElse: () => MessageDeliveryStatus.sending,
      ),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'DeliveryTrackedMessage(messageId: $messageId, status: ${deliveryStatus.name})';
  }
}

/// Queue statistics for monitoring
class QueueStats {
  final int totalCount;
  final int pendingCount;
  final int sendingCount;
  final int failedCount;
  final DateTime? oldestMessageTime;
  final DateTime? newestMessageTime;

  const QueueStats({
    required this.totalCount,
    required this.pendingCount,
    required this.sendingCount,
    required this.failedCount,
    this.oldestMessageTime,
    this.newestMessageTime,
  });

  /// Create from a list of queued messages
  factory QueueStats.fromMessages(List<QueuedMessage> messages) {
    if (messages.isEmpty) {
      return const QueueStats(
        totalCount: 0,
        pendingCount: 0,
        sendingCount: 0,
        failedCount: 0,
      );
    }

    final sorted = List<QueuedMessage>.from(messages)
      ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

    return QueueStats(
      totalCount: messages.length,
      pendingCount: messages.where((m) => m.status == QueuedMessageStatus.pending).length,
      sendingCount: messages.where((m) => m.status == QueuedMessageStatus.sending).length,
      failedCount: messages.where((m) => m.status == QueuedMessageStatus.failed).length,
      oldestMessageTime: sorted.first.queuedAt,
      newestMessageTime: sorted.last.queuedAt,
    );
  }

  bool get isEmpty => totalCount == 0;
  bool get hasActive => pendingCount > 0 || sendingCount > 0;
  bool get hasFailed => failedCount > 0;

  @override
  String toString() {
    return 'QueueStats(total: $totalCount, pending: $pendingCount, sending: $sendingCount, failed: $failedCount)';
  }
}
