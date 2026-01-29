import 'message.dart';

/// Chat session model matching embed-server Response schema
class ChatSession {
  final String id;
  final String chatSessionId;
  final String botId;
  final String? visitorId;
  final List<RecordItem> record;
  final DateTime? chatDate;
  final Map<String, dynamic>? visitorMeta;
  final bool isActive;

  /// Chatbot flow steps (nodes) - optional, returned by API
  final List<Map<String, dynamic>>? steps;

  /// Chatbot flow edges (connections) - optional, returned by API
  final List<Map<String, dynamic>>? edges;

  /// Total message count (for pagination)
  final int? totalMessages;

  /// Current page (for pagination)
  final int? currentPage;

  const ChatSession({
    required this.id,
    required this.chatSessionId,
    required this.botId,
    this.visitorId,
    required this.record,
    this.chatDate,
    this.visitorMeta,
    this.isActive = true,
    this.steps,
    this.edges,
    this.totalMessages,
    this.currentPage,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final recordList = (json['record'] as List?)
            ?.map((item) => RecordItem.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];

    final stepsList = (json['steps'] as List?)
        ?.map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final edgesList = (json['edges'] as List?)
        ?.map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return ChatSession(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      chatSessionId: json['chatSessionId'] as String,
      botId: json['botId'] as String,
      visitorId: json['visitorId'] as String?,
      record: recordList,
      chatDate: json['chatDate'] != null ? DateTime.parse(json['chatDate'] as String) : null,
      visitorMeta: json['visitorMeta'] as Map<String, dynamic>?,
      isActive: json['isActive'] as bool? ?? true,
      steps: stepsList,
      edges: edgesList,
      totalMessages: json['totalMessages'] as int?,
      currentPage: json['currentPage'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'chatSessionId': chatSessionId,
      'botId': botId,
      if (visitorId != null) 'visitorId': visitorId,
      'record': record.map((item) => item.toJson()).toList(),
      if (chatDate != null) 'chatDate': chatDate!.toIso8601String(),
      if (visitorMeta != null) 'visitorMeta': visitorMeta,
      'isActive': isActive,
      if (steps != null) 'steps': steps,
      if (edges != null) 'edges': edges,
      if (totalMessages != null) 'totalMessages': totalMessages,
      if (currentPage != null) 'currentPage': currentPage,
    };
  }

  ChatSession copyWith({
    String? id,
    String? chatSessionId,
    String? botId,
    String? visitorId,
    List<RecordItem>? record,
    DateTime? chatDate,
    Map<String, dynamic>? visitorMeta,
    bool? isActive,
    List<Map<String, dynamic>>? steps,
    List<Map<String, dynamic>>? edges,
    int? totalMessages,
    int? currentPage,
  }) {
    return ChatSession(
      id: id ?? this.id,
      chatSessionId: chatSessionId ?? this.chatSessionId,
      botId: botId ?? this.botId,
      visitorId: visitorId ?? this.visitorId,
      record: record ?? this.record,
      chatDate: chatDate ?? this.chatDate,
      visitorMeta: visitorMeta ?? this.visitorMeta,
      isActive: isActive ?? this.isActive,
      steps: steps ?? this.steps,
      edges: edges ?? this.edges,
      totalMessages: totalMessages ?? this.totalMessages,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}
