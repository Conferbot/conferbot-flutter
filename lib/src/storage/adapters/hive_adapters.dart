import 'package:hive/hive.dart';

/// Hive type IDs for ConferBot storage
/// Reserved range: 0-50 for core types
class HiveTypeIds {
  static const int chatMessage = 0;
  static const int answerVariable = 1;
  static const int userMetadata = 2;
  static const int persistedSession = 3;
  static const int transcriptEntry = 4;
  static const int recordEntry = 5;
}

/// Persisted chat message model for Hive storage
/// Stores messages in a format that can be reconstructed
@HiveType(typeId: HiveTypeIds.chatMessage)
class PersistedChatMessage extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String type; // MessageType.value

  @HiveField(2)
  late DateTime time;

  @HiveField(3)
  String? text;

  @HiveField(4)
  Map<String, dynamic>? data; // Additional data as JSON-compatible map

  PersistedChatMessage();

  PersistedChatMessage.create({
    required this.id,
    required this.type,
    required this.time,
    this.text,
    this.data,
  });

  /// Convert to JSON for RecordItem reconstruction
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type,
      'time': time.toIso8601String(),
      if (text != null) 'text': text,
      if (data != null) ...data!,
    };
  }

  /// Create from any record item JSON
  factory PersistedChatMessage.fromJson(Map<String, dynamic> json) {
    final knownKeys = {'_id', 'id', 'type', 'time', 'text'};
    final additionalData = Map<String, dynamic>.fromEntries(
      json.entries.where((e) => !knownKeys.contains(e.key)),
    );

    return PersistedChatMessage.create(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      type: json['type'] as String? ?? 'system-message',
      time: json['time'] != null
          ? (json['time'] is DateTime
              ? json['time'] as DateTime
              : DateTime.parse(json['time'] as String))
          : DateTime.now(),
      text: json['text'] as String?,
      data: additionalData.isNotEmpty ? additionalData : null,
    );
  }
}

/// Adapter for PersistedChatMessage
class PersistedChatMessageAdapter extends TypeAdapter<PersistedChatMessage> {
  @override
  final int typeId = HiveTypeIds.chatMessage;

  @override
  PersistedChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersistedChatMessage()
      ..id = fields[0] as String
      ..type = fields[1] as String
      ..time = fields[2] as DateTime
      ..text = fields[3] as String?
      ..data = fields[4] != null
          ? Map<String, dynamic>.from(fields[4] as Map)
          : null;
  }

  @override
  void write(BinaryWriter writer, PersistedChatMessage obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.time)
      ..writeByte(3)
      ..write(obj.text)
      ..writeByte(4)
      ..write(obj.data);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistedChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

/// Persisted answer variable for Hive storage
@HiveType(typeId: HiveTypeIds.answerVariable)
class PersistedAnswerVariable extends HiveObject {
  @HiveField(0)
  late String nodeId;

  @HiveField(1)
  late String key;

  @HiveField(2)
  dynamic value;

  PersistedAnswerVariable();

  PersistedAnswerVariable.create({
    required this.nodeId,
    required this.key,
    this.value,
  });

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'key': key,
      'value': value,
    };
  }

  factory PersistedAnswerVariable.fromJson(Map<String, dynamic> json) {
    return PersistedAnswerVariable.create(
      nodeId: json['nodeId'] as String,
      key: json['key'] as String,
      value: json['value'],
    );
  }
}

/// Adapter for PersistedAnswerVariable
class PersistedAnswerVariableAdapter
    extends TypeAdapter<PersistedAnswerVariable> {
  @override
  final int typeId = HiveTypeIds.answerVariable;

  @override
  PersistedAnswerVariable read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersistedAnswerVariable()
      ..nodeId = fields[0] as String
      ..key = fields[1] as String
      ..value = fields[2];
  }

  @override
  void write(BinaryWriter writer, PersistedAnswerVariable obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.nodeId)
      ..writeByte(1)
      ..write(obj.key)
      ..writeByte(2)
      ..write(obj.value);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistedAnswerVariableAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

/// Persisted user metadata for Hive storage
@HiveType(typeId: HiveTypeIds.userMetadata)
class PersistedUserMetadata extends HiveObject {
  @HiveField(0)
  String? name;

  @HiveField(1)
  String? email;

  @HiveField(2)
  String? phone;

  @HiveField(3)
  Map<String, dynamic>? metadata;

  PersistedUserMetadata();

  PersistedUserMetadata.create({
    this.name,
    this.email,
    this.phone,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'metadata': metadata ?? {},
    };
  }

  factory PersistedUserMetadata.fromJson(Map<String, dynamic> json) {
    return PersistedUserMetadata.create(
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// Adapter for PersistedUserMetadata
class PersistedUserMetadataAdapter extends TypeAdapter<PersistedUserMetadata> {
  @override
  final int typeId = HiveTypeIds.userMetadata;

  @override
  PersistedUserMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersistedUserMetadata()
      ..name = fields[0] as String?
      ..email = fields[1] as String?
      ..phone = fields[2] as String?
      ..metadata = fields[3] != null
          ? Map<String, dynamic>.from(fields[3] as Map)
          : null;
  }

  @override
  void write(BinaryWriter writer, PersistedUserMetadata obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistedUserMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

/// Persisted transcript entry for Hive storage
@HiveType(typeId: HiveTypeIds.transcriptEntry)
class PersistedTranscriptEntry extends HiveObject {
  @HiveField(0)
  late String by; // "bot", "user", or "agent"

  @HiveField(1)
  late String message;

  @HiveField(2)
  late int timestamp;

  PersistedTranscriptEntry();

  PersistedTranscriptEntry.create({
    required this.by,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'by': by,
      'message': message,
      'timestamp': timestamp,
    };
  }

  factory PersistedTranscriptEntry.fromJson(Map<String, dynamic> json) {
    return PersistedTranscriptEntry.create(
      by: json['by'] as String,
      message: json['message'] as String,
      timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Adapter for PersistedTranscriptEntry
class PersistedTranscriptEntryAdapter
    extends TypeAdapter<PersistedTranscriptEntry> {
  @override
  final int typeId = HiveTypeIds.transcriptEntry;

  @override
  PersistedTranscriptEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersistedTranscriptEntry()
      ..by = fields[0] as String
      ..message = fields[1] as String
      ..timestamp = fields[2] as int;
  }

  @override
  void write(BinaryWriter writer, PersistedTranscriptEntry obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.by)
      ..writeByte(1)
      ..write(obj.message)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistedTranscriptEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

/// Persisted record entry for Hive storage
@HiveType(typeId: HiveTypeIds.recordEntry)
class PersistedRecordEntry extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String shape;

  @HiveField(2)
  String? type;

  @HiveField(3)
  String? text;

  @HiveField(4)
  late String time;

  @HiveField(5)
  Map<String, dynamic>? data;

  PersistedRecordEntry();

  PersistedRecordEntry.create({
    required this.id,
    required this.shape,
    this.type,
    this.text,
    required this.time,
    this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shape': shape,
      'type': type,
      'text': text,
      'time': time,
      if (data != null) ...data!,
    };
  }

  factory PersistedRecordEntry.fromJson(Map<String, dynamic> json) {
    final knownKeys = {'id', 'shape', 'type', 'text', 'time'};
    final additionalData = Map<String, dynamic>.fromEntries(
      json.entries.where((e) => !knownKeys.contains(e.key)),
    );

    return PersistedRecordEntry.create(
      id: json['id'] as String,
      shape: json['shape'] as String,
      type: json['type'] as String?,
      text: json['text'] as String?,
      time: json['time'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      data: additionalData.isNotEmpty ? additionalData : null,
    );
  }
}

/// Adapter for PersistedRecordEntry
class PersistedRecordEntryAdapter extends TypeAdapter<PersistedRecordEntry> {
  @override
  final int typeId = HiveTypeIds.recordEntry;

  @override
  PersistedRecordEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersistedRecordEntry()
      ..id = fields[0] as String
      ..shape = fields[1] as String
      ..type = fields[2] as String?
      ..text = fields[3] as String?
      ..time = fields[4] as String
      ..data = fields[5] != null
          ? Map<String, dynamic>.from(fields[5] as Map)
          : null;
  }

  @override
  void write(BinaryWriter writer, PersistedRecordEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.shape)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.text)
      ..writeByte(4)
      ..write(obj.time)
      ..writeByte(5)
      ..write(obj.data);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistedRecordEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

/// Persisted chat session containing all session state
@HiveType(typeId: HiveTypeIds.persistedSession)
class PersistedChatSession extends HiveObject {
  @HiveField(0)
  late String chatbotId;

  @HiveField(1)
  String? chatSessionId;

  @HiveField(2)
  String? visitorId;

  @HiveField(3)
  late DateTime lastActivityAt;

  @HiveField(4)
  late DateTime createdAt;

  @HiveField(5)
  int currentIndex;

  @HiveField(6)
  String? workspaceId;

  @HiveField(7)
  bool isActive;

  @HiveField(8)
  List<PersistedChatMessage>? messages;

  @HiveField(9)
  List<PersistedAnswerVariable>? answerVariables;

  @HiveField(10)
  PersistedUserMetadata? userMetadata;

  @HiveField(11)
  List<PersistedTranscriptEntry>? transcript;

  @HiveField(12)
  List<PersistedRecordEntry>? record;

  @HiveField(13)
  Map<String, dynamic>? variables;

  @HiveField(14)
  String? currentNodeId;

  PersistedChatSession({
    this.chatbotId = '',
    this.chatSessionId,
    this.visitorId,
    DateTime? lastActivityAt,
    DateTime? createdAt,
    this.currentIndex = 0,
    this.workspaceId,
    this.isActive = true,
    this.messages,
    this.answerVariables,
    this.userMetadata,
    this.transcript,
    this.record,
    this.variables,
    this.currentNodeId,
  })  : lastActivityAt = lastActivityAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// Check if session is expired (default: 30 minutes)
  bool isExpired({Duration timeout = const Duration(minutes: 30)}) {
    return DateTime.now().difference(lastActivityAt) > timeout;
  }

  /// Update last activity timestamp
  void touch() {
    lastActivityAt = DateTime.now();
  }

  /// Convert to JSON for debugging
  Map<String, dynamic> toJson() {
    return {
      'chatbotId': chatbotId,
      'chatSessionId': chatSessionId,
      'visitorId': visitorId,
      'lastActivityAt': lastActivityAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'currentIndex': currentIndex,
      'workspaceId': workspaceId,
      'isActive': isActive,
      'currentNodeId': currentNodeId,
      'messagesCount': messages?.length ?? 0,
      'answerVariablesCount': answerVariables?.length ?? 0,
    };
  }
}

/// Adapter for PersistedChatSession
class PersistedChatSessionAdapter extends TypeAdapter<PersistedChatSession> {
  @override
  final int typeId = HiveTypeIds.persistedSession;

  @override
  PersistedChatSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersistedChatSession(
      chatbotId: fields[0] as String? ?? '',
      chatSessionId: fields[1] as String?,
      visitorId: fields[2] as String?,
      lastActivityAt: fields[3] as DateTime?,
      createdAt: fields[4] as DateTime?,
      currentIndex: fields[5] as int? ?? 0,
      workspaceId: fields[6] as String?,
      isActive: fields[7] as bool? ?? true,
      messages: fields[8] != null
          ? (fields[8] as List).cast<PersistedChatMessage>()
          : null,
      answerVariables: fields[9] != null
          ? (fields[9] as List).cast<PersistedAnswerVariable>()
          : null,
      userMetadata: fields[10] as PersistedUserMetadata?,
      transcript: fields[11] != null
          ? (fields[11] as List).cast<PersistedTranscriptEntry>()
          : null,
      record: fields[12] != null
          ? (fields[12] as List).cast<PersistedRecordEntry>()
          : null,
      variables: fields[13] != null
          ? Map<String, dynamic>.from(fields[13] as Map)
          : null,
      currentNodeId: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PersistedChatSession obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.chatbotId)
      ..writeByte(1)
      ..write(obj.chatSessionId)
      ..writeByte(2)
      ..write(obj.visitorId)
      ..writeByte(3)
      ..write(obj.lastActivityAt)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.currentIndex)
      ..writeByte(6)
      ..write(obj.workspaceId)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.messages)
      ..writeByte(9)
      ..write(obj.answerVariables)
      ..writeByte(10)
      ..write(obj.userMetadata)
      ..writeByte(11)
      ..write(obj.transcript)
      ..writeByte(12)
      ..write(obj.record)
      ..writeByte(13)
      ..write(obj.variables)
      ..writeByte(14)
      ..write(obj.currentNodeId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistedChatSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
