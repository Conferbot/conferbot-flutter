import '../core/agent/agent_bot.dart';
import '../core/live_chat/live_chat.dart';

/// Message types matching embed-server schema
enum MessageType {
  userMessage('user-message'),
  userInputResponse('user-input-response'), // User input response from chatbot flow
  botMessage('bot-message'),
  agentMessage('agent-message'),
  agentMessageFile('agent-message-file'),
  agentMessageAudio('agent-message-audio'),
  agentMessageRich('agent-message-rich'),
  agentJoinedMessage('agent-joined-message'),
  userLiveMessageFile('user-live-message-file'), // The visitor's file in a live chat
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
      case MessageType.userInputResponse:
        return UserInputResponseRecord.fromJson(json);
      case MessageType.botMessage:
        return BotMessageRecord.fromJson(json);
      case MessageType.agentMessage:
        return AgentMessageRecord.fromJson(json);
      case MessageType.agentMessageFile:
        return AgentMessageFileRecord.fromJson(json);
      case MessageType.agentMessageAudio:
        return AgentMessageAudioRecord.fromJson(json);
      case MessageType.agentMessageRich:
        return AgentRichMessageRecord.fromJson(json);
      case MessageType.agentJoinedMessage:
        return AgentJoinedMessageRecord.fromJson(json);
      case MessageType.userLiveMessageFile:
        return UserLiveMessageFileRecord.fromJson(json);
      case MessageType.visitorDisconnectedMessage:
      case MessageType.visitorReconnectedMessage:
      case MessageType.systemMessage:
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
      time: _parseTime(json['time']),
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

/// User input response record (from chatbot flow)
class UserInputResponseRecord extends RecordItem {
  final String text;
  final Map<String, dynamic>? metadata;

  const UserInputResponseRecord({
    required super.id,
    required super.time,
    required this.text,
    this.metadata,
  }) : super(type: MessageType.userInputResponse);

  factory UserInputResponseRecord.fromJson(Map<String, dynamic> json) {
    return UserInputResponseRecord(
      id: json['_id'].toString(),
      time: _parseTime(json['time']),
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

/// Helper to parse time from various formats
DateTime _parseTime(dynamic time) {
  if (time is String) {
    return DateTime.parse(time);
  } else if (time is DateTime) {
    return time;
  }
  return DateTime.now();
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
  final String? avatar;

  /// An AI agent (Agent Studio) rather than a person.
  final bool isAIAgent;

  const AgentDetails({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.isAIAgent = false,
  });

  // An AI agent's details carry no email (and a person's may not): the
  // strict casts threw on them and the message was dropped.
  factory AgentDetails.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? '';
    final avatar = json['avatar']?.toString();
    return AgentDetails(
      id: id,
      name: json['name']?.toString() ?? 'Agent',
      email: json['email']?.toString() ?? '',
      avatar: avatar == null || avatar.isEmpty ? null : avatar,
      isAIAgent: json['isAIAgent'] == true || id.startsWith('ai-agent-'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      if (avatar != null) 'avatar': avatar,
      if (isAIAgent) 'isAIAgent': true,
    };
  }
}

/// The AI reply as it is being written: one live bubble, replaced by the
/// finished agent-message.
class AgentStream {
  final String id;
  final String text;
  final AgentDetails agentDetails;
  const AgentStream({required this.id, required this.text, required this.agentDetails});
}

/// Agent message record
class AgentMessageRecord extends RecordItem {
  final String text;
  final AgentDetails agentDetails;

  /// An AI reply's sources, buttons and cards (core/agent/agent_bot.dart).
  final AIReplyExtras? extras;

  /// The visitor's "Helpful?" vote on an AI reply.
  final AnswerFeedback? feedback;

  /// The agent edited / unsent it (agent-message-edited / -deleted).
  final bool edited;
  final bool deleted;

  /// Sent in the visitor's language: the agent's own words kept (See original).
  final AgentTranslation? translation;

  const AgentMessageRecord({
    required super.id,
    required super.time,
    required this.text,
    required this.agentDetails,
    this.extras,
    this.feedback,
    this.edited = false,
    this.deleted = false,
    this.translation,
  }) : super(type: MessageType.agentMessage);

  factory AgentMessageRecord.fromJson(Map<String, dynamic> json) {
    final agentDetails = json['agentDetails'] is Map
        ? AgentDetails.fromJson(Map<String, dynamic>.from(json['agentDetails'] as Map))
        : const AgentDetails(id: '', name: 'Agent', email: '');
    final extrasRaw = json['extras'];
    return AgentMessageRecord(
      id: json['_id'].toString(),
      time: DateTime.parse(json['time'] as String),
      text: json['text']?.toString() ?? '',
      agentDetails: agentDetails,
      extras: extrasRaw is Map ? AgentBotParser.aiReplyExtrasOf(Map<String, dynamic>.from(extrasRaw)) : null,
      feedback: AnswerFeedback.fromJson(json['feedback']),
      edited: json['edited'] == true,
      deleted: json['deleted'] == true,
      translation: AgentTranslation.fromJson(json['translation']),
    );
  }

  /// The same message with a change applied (vote, edit, unsend).
  AgentMessageRecord copyWith({String? text, AnswerFeedback? feedback, bool? edited, bool? deleted}) => AgentMessageRecord(
        id: id,
        time: time,
        text: text ?? this.text,
        agentDetails: agentDetails,
        extras: extras,
        feedback: feedback ?? this.feedback,
        edited: edited ?? this.edited,
        deleted: deleted ?? this.deleted,
        translation: translation,
      );

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type.value,
      'time': time.toIso8601String(),
      'text': text,
      'agentDetails': agentDetails.toJson(),
      if (extras != null) 'extras': extras!.toJson(),
      if (feedback != null) 'feedback': feedback!.toJson(),
      if (edited) 'edited': true,
      if (deleted) 'deleted': true,
      if (translation != null) 'translation': translation!.toJson(),
    };
  }
}

/// An agent's article, quick replies or card (agent-message-rich).
class AgentRichMessageRecord extends RecordItem {
  final RichEntry rich;
  final String text;
  final AgentDetails? agentDetails;

  /// The quick reply the visitor chose.
  final String? answered;

  const AgentRichMessageRecord({
    required super.id,
    required super.time,
    required this.rich,
    this.text = '',
    this.agentDetails,
    this.answered,
  }) : super(type: MessageType.agentMessageRich);

  factory AgentRichMessageRecord.fromJson(Map<String, dynamic> json) {
    final rich = AgentBotParser.safeRich(json['rich']) ?? const RichQuickReplies(text: '', options: []);
    return AgentRichMessageRecord(
      id: json['_id'].toString(),
      time: DateTime.parse(json['time'] as String),
      rich: rich,
      text: json['text']?.toString() ?? '',
      agentDetails: json['agentDetails'] is Map
          ? AgentDetails.fromJson(Map<String, dynamic>.from(json['agentDetails'] as Map))
          : null,
      answered: json['answered']?.toString(),
    );
  }

  AgentRichMessageRecord answering(String label) =>
      AgentRichMessageRecord(id: id, time: time, rich: rich, text: text, agentDetails: agentDetails, answered: label);

  @override
  Map<String, dynamic> toJson() => {
        '_id': id,
        'type': type.value,
        'time': time.toIso8601String(),
        'text': text,
        'rich': AgentBotParser.richToJson(rich),
        if (agentDetails != null) 'agentDetails': agentDetails!.toJson(),
        if (answered != null) 'answered': answered,
      };
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

/// The visitor's file in a live chat (user-live-message-file).
class UserLiveMessageFileRecord extends RecordItem {
  final String url;
  final String? fileName;
  final String? mimeType;

  const UserLiveMessageFileRecord({
    required super.id,
    required super.time,
    required this.url,
    this.fileName,
    this.mimeType,
  }) : super(type: MessageType.userLiveMessageFile);

  factory UserLiveMessageFileRecord.fromJson(Map<String, dynamic> json) => UserLiveMessageFileRecord(
        id: (json['_id'] ?? json['id']).toString(),
        time: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.now(),
        url: json['url']?.toString() ?? '',
        fileName: json['fileName']?.toString(),
        mimeType: json['mimeType']?.toString(),
      );

  @override
  Map<String, dynamic> toJson() => {
        '_id': id,
        'type': type.value,
        'time': time.toIso8601String(),
        'url': url,
        if (fileName != null) 'fileName': fileName,
        if (mimeType != null) 'mimeType': mimeType,
      };
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
