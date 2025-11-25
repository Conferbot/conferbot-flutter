import 'agent.dart';

/// Message types matching embed-server schema
enum MessageType {
  userMessage('user-message'),
  botMessage('bot-message'),
  agentMessage('agent-message'),
  agentMessageFile('agent-message-file'),
  agentMessageAudio('agent-message-audio'),
  agentJoinedMessage('agent-joined-message'),
  visitorDisconnectedMessage('visitor-disconnected-message'),
  visitorReconnectedMessage('visitor-reconnected-message'),
  systemMessage('system-message');

  final String value;
  const MessageType(this.value);

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageType.systemMessage,
    );
  }
}

/// Base record item matching embed-server Response.record structure
abstract class RecordItem {
  final String id;
  final MessageType type;
  final DateTime time;

  const RecordItem({
    required this.id,
    required this.type,
    required this.time,
  });

  factory RecordItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = MessageType.fromString(typeStr);

    switch (type) {
      case MessageType.userMessage:
        return UserMessageRecord.fromJson(json);
      case MessageType.botMessage:
        return BotMessageRecord.fromJson(json);
      case MessageType.agentMessage:
        return AgentMessageRecord.fromJson(json);
      case MessageType.agentMessageFile:
        return AgentMessageFileRecord.fromJson(json);
      case MessageType.agentMessageAudio:
        return AgentMessageAudioRecord.fromJson(json);
      case MessageType.agentJoinedMessage:
        return AgentJoinedMessageRecord.fromJson(json);
      case MessageType.systemMessage:
        return SystemMessageRecord.fromJson(json);
      default:
        return SystemMessageRecord.fromJson(json);
    }
  }

  Map<String, dynamic> toJson();
}

/// User message record
class UserMessageRecord extends RecordItem {
  final String text;
  final Map<String, dynamic>? metadata;

  const UserMessageRecord({
    required super.id,
    required super.time,
    required this.text,
    this.metadata,
  }) : super(type: MessageType.userMessage);

  factory UserMessageRecord.fromJson(Map<String, dynamic> json) {
    return UserMessageRecord(
      id: json['_id'].toString(),
      time: DateTime.parse(json['time'] as String),
      text: json['text'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type.value,
      'time': time.toIso8601String(),
      'text': text,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Bot message record
class BotMessageRecord extends RecordItem {
  final String? text;
  final Map<String, dynamic>? nodeData;

  const BotMessageRecord({
    required super.id,
    required super.time,
    this.text,
    this.nodeData,
  }) : super(type: MessageType.botMessage);

  factory BotMessageRecord.fromJson(Map<String, dynamic> json) {
    return BotMessageRecord(
      id: json['_id'].toString(),
      time: DateTime.parse(json['time'] as String),
      text: json['text'] as String?,
      nodeData: json,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type.value,
      'time': time.toIso8601String(),
      if (text != null) 'text': text,
      if (nodeData != null) ...nodeData!,
    };
  }
}

/// Agent details matching embed-server agentDetails structure
class AgentDetails {
  final String id;
  final String name;
  final String email;

  const AgentDetails({
    required this.id,
    required this.name,
    required this.email,
  });

  factory AgentDetails.fromJson(Map<String, dynamic> json) {
    return AgentDetails(
      id: json['_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
    };
  }
}

/// Agent message record
class AgentMessageRecord extends RecordItem {
  final String text;
  final AgentDetails agentDetails;

  const AgentMessageRecord({
    required super.id,
    required super.time,
    required this.text,
    required this.agentDetails,
  }) : super(type: MessageType.agentMessage);

  factory AgentMessageRecord.fromJson(Map<String, dynamic> json) {
    return AgentMessageRecord(
      id: json['_id'].toString(),
      time: DateTime.parse(json['time'] as String),
      text: json['text'] as String,
      agentDetails: AgentDetails.fromJson(json['agentDetails'] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type.value,
      'time': time.toIso8601String(),
      'text': text,
      'agentDetails': agentDetails.toJson(),
    };
  }
}

/// Agent file message record
class AgentMessageFileRecord extends RecordItem {
  final String file;
  final AgentDetails? agentDetails;

  const AgentMessageFileRecord({
    required super.id,
    required super.time,
    required this.file,
    this.agentDetails,
  }) : super(type: MessageType.agentMessageFile);

  factory AgentMessageFileRecord.fromJson(Map<String, dynamic> json) {
    return AgentMessageFileRecord(
      id: json['_id'].toString(),
      time: DateTime.parse(json['time'] as String),
      file: json['file'] as String,
      agentDetails: json['agentDetails'] != null
          ? AgentDetails.fromJson(json['agentDetails'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type.value,
      'time': time.toIso8601String(),
      'file': file,
      if (agentDetails != null) 'agentDetails': agentDetails!.toJson(),
    };
  }
}

/// Agent audio message record
class AgentMessageAudioRecord extends RecordItem {
  final String url;
  final AgentDetails agentDetails;

  const AgentMessageAudioRecord({
    required super.id,
    required super.time,
    required this.url,
    required this.agentDetails,
  }) : super(type: MessageType.agentMessageAudio);

  factory AgentMessageAudioRecord.fromJson(Map<String, dynamic> json) {
    return AgentMessageAudioRecord(
      id: json['_id'].toString(),
      time: DateTime.parse(json['time'] as String),
      url: json['url'] as String,
      agentDetails: AgentDetails.fromJson(json['agentDetails'] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type.value,
      'time': time.toIso8601String(),
      'url': url,
      'agentDetails': agentDetails.toJson(),
    };
  }
}

/// Agent joined message record
class AgentJoinedMessageRecord extends RecordItem {
  final AgentDetails agentDetails;

  const AgentJoinedMessageRecord({
    required super.id,
    required super.time,
    required this.agentDetails,
  }) : super(type: MessageType.agentJoinedMessage);

  factory AgentJoinedMessageRecord.fromJson(Map<String, dynamic> json) {
    return AgentJoinedMessageRecord(
      id: json['_id'].toString(),
      time: DateTime.parse(json['time'] as String),
      agentDetails: AgentDetails.fromJson(json['agentDetails'] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type.value,
      'time': time.toIso8601String(),
      'agentDetails': agentDetails.toJson(),
    };
  }
}

/// System message record
class SystemMessageRecord extends RecordItem {
  final String text;

  const SystemMessageRecord({
    required super.id,
    required super.time,
    required this.text,
  }) : super(type: MessageType.systemMessage);

  factory SystemMessageRecord.fromJson(Map<String, dynamic> json) {
    return SystemMessageRecord(
      id: json['_id'].toString(),
      time: DateTime.parse(json['time'] as String),
      text: json['text'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type.value,
      'time': time.toIso8601String(),
      'text': text,
    };
  }
}
