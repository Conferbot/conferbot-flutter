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

  const ChatSession({
    required this.id,
    required this.chatSessionId,
    required this.botId,
    this.visitorId,
    required this.record,
    this.chatDate,
    this.visitorMeta,
    this.isActive = true,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final recordList = (json['record'] as List?)
            ?.map((item) => RecordItem.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];

    return ChatSession(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      chatSessionId: json['chatSessionId'] as String,
      botId: json['botId'] as String,
      visitorId: json['visitorId'] as String?,
      record: recordList,
      chatDate: json['chatDate'] != null ? DateTime.parse(json['chatDate'] as String) : null,
      visitorMeta: json['visitorMeta'] as Map<String, dynamic>?,
      isActive: json['isActive'] as bool? ?? true,
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
    );
  }
}
