import 'dart:io';
import 'package:flutter/foundation.dart';

/// Answer variable stored during conversation flow
/// Mirrors the web widget's answerVariables structure
class AnswerVariable {
  final String nodeId;
  final String key;
  dynamic value;

  AnswerVariable({
    required this.nodeId,
    required this.key,
    this.value,
  });

  AnswerVariable copyWith({
    String? nodeId,
    String? key,
    dynamic value,
  }) {
    return AnswerVariable(
      nodeId: nodeId ?? this.nodeId,
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'key': key,
      'value': value,
    };
  }

  factory AnswerVariable.fromJson(Map<String, dynamic> json) {
    return AnswerVariable(
      nodeId: json['nodeId'] as String,
      key: json['key'] as String,
      value: json['value'],
    );
  }
}

/// Transcript entry for conversation history
class TranscriptEntry {
  final String by; // "bot", "user", or "agent"
  final String message;
  final int timestamp;

  TranscriptEntry({
    required this.by,
    required this.message,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  TranscriptEntry copyWith({
    String? by,
    String? message,
    int? timestamp,
  }) {
    return TranscriptEntry(
      by: by ?? this.by,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'by': by,
      'message': message,
      'timestamp': timestamp,
    };
  }

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) {
    return TranscriptEntry(
      by: json['by'] as String,
      message: json['message'] as String,
      timestamp: json['timestamp'] as int?,
    );
  }
}

/// User metadata collected during conversation
class UserMetadata {
  String? name;
  String? email;
  String? phone;
  Map<String, dynamic> metadata;

  UserMetadata({
    this.name,
    this.email,
    this.phone,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  UserMetadata copyWith({
    String? name,
    String? email,
    String? phone,
    Map<String, dynamic>? metadata,
  }) {
    return UserMetadata(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'metadata': metadata,
    };
  }

  factory UserMetadata.fromJson(Map<String, dynamic> json) {
    return UserMetadata(
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// Record entry for each interaction
class RecordEntry {
  final String id;
  final String shape;
  final String? type;
  final String? text;
  final String time;
  final Map<String, dynamic> data;

  RecordEntry({
    required this.id,
    required this.shape,
    this.type,
    this.text,
    String? time,
    Map<String, dynamic>? data,
  })  : time = time ?? DateTime.now().toUtc().toIso8601String(),
        data = data ?? {};

  RecordEntry copyWith({
    String? id,
    String? shape,
    String? type,
    String? text,
    String? time,
    Map<String, dynamic>? data,
  }) {
    return RecordEntry(
      id: id ?? this.id,
      shape: shape ?? this.shape,
      type: type ?? this.type,
      text: text ?? this.text,
      time: time ?? this.time,
      data: data ?? Map<String, dynamic>.from(this.data),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shape': shape,
      'type': type,
      'text': text,
      'time': time,
      ...data,
    };
  }

  factory RecordEntry.fromJson(Map<String, dynamic> json) {
    final knownKeys = {'id', 'shape', 'type', 'text', 'time'};
    final data = Map<String, dynamic>.fromEntries(
      json.entries.where((entry) => !knownKeys.contains(entry.key)),
    );

    return RecordEntry(
      id: json['id'] as String,
      shape: json['shape'] as String,
      type: json['type'] as String?,
      text: json['text'] as String?,
      time: json['time'] as String?,
      data: data,
    );
  }
}

/// Central state manager for the chat conversation
/// Manages all state following the web widget's architecture
/// Uses ChangeNotifier for Flutter reactivity
class ChatState extends ChangeNotifier {
  // Singleton pattern
  static final ChatState _instance = ChatState._internal();
  static ChatState get instance => _instance;
  factory ChatState() => _instance;
  ChatState._internal();

  // Answer variables - stores all user responses
  final List<AnswerVariable> _answerVariables = [];
  List<AnswerVariable> get answerVariables => List.unmodifiable(_answerVariables);

  // Variables - temporary calculation storage
  final Map<String, dynamic> _variables = {};
  Map<String, dynamic> get variables => Map.unmodifiable(_variables);

  // User metadata
  UserMetadata _userMetadata = UserMetadata();
  UserMetadata get userMetadata => _userMetadata;

  // Transcript - conversation history
  final List<TranscriptEntry> _transcript = [];
  List<TranscriptEntry> get transcript => List.unmodifiable(_transcript);

  // Record - full conversation record for server sync
  final List<RecordEntry> _record = [];
  List<RecordEntry> get record => List.unmodifiable(_record);

  // Current node index in the flow
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  // Current flow steps
  List<Map<String, dynamic>> _steps = [];
  List<Map<String, dynamic>> get steps => List.unmodifiable(_steps);

  // Chat session ID
  String? _chatSessionId;
  String? get chatSessionId => _chatSessionId;

  // Visitor ID
  String? _visitorId;
  String? get visitorId => _visitorId;

  // Bot ID
  String? _botId;
  String? get botId => _botId;

  // Workspace ID
  String? _workspaceId;
  String? get workspaceId => _workspaceId;

  /// Initialize chat state with session info
  void initialize({
    required String chatSessionId,
    required String visitorId,
    required String botId,
    String? workspaceId,
  }) {
    _chatSessionId = chatSessionId;
    _visitorId = visitorId;
    _botId = botId;
    _workspaceId = workspaceId;
    notifyListeners();
  }

  /// Set the flow steps from server response
  void setSteps(List<Map<String, dynamic>> steps) {
    _steps = List.from(steps);
    notifyListeners();
  }

  /// Get current node from steps
  Map<String, dynamic>? getCurrentNode() {
    if (_currentIndex >= 0 && _currentIndex < _steps.length) {
      return _steps[_currentIndex];
    }
    return null;
  }

  /// Move to next node
  void incrementIndex() {
    _currentIndex++;
    notifyListeners();
  }

  /// Set specific index (for jumping)
  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  // ========== Answer Variables ==========

  /// Add a new answer variable (when node is displayed)
  void addAnswerVariable(String nodeId, String key, {dynamic value}) {
    final existingIndex = _answerVariables.indexWhere((v) => v.nodeId == nodeId);
    if (existingIndex != -1) {
      _answerVariables[existingIndex].value = value;
    } else {
      _answerVariables.add(AnswerVariable(
        nodeId: nodeId,
        key: key,
        value: value,
      ));
    }
    notifyListeners();
  }

  /// Update answer variable by nodeId
  void setAnswerVariable(String nodeId, dynamic value) {
    final variable = _answerVariables.firstWhere(
      (v) => v.nodeId == nodeId,
      orElse: () => AnswerVariable(nodeId: '', key: ''),
    );
    if (variable.nodeId.isNotEmpty) {
      variable.value = value;
      notifyListeners();
    }
  }

  /// Update or create answer variable by key
  void setAnswerVariableByKey(String key, dynamic value) {
    final existingIndex = _answerVariables.indexWhere((v) => v.key == key);
    if (existingIndex != -1) {
      _answerVariables[existingIndex].value = value;
    } else {
      _answerVariables.add(AnswerVariable(
        nodeId: 'column_mapped_$key',
        key: key,
        value: value,
      ));
    }
    notifyListeners();
  }

  /// Get answer variable value by key
  dynamic getAnswerVariableValue(String key) {
    final variable = _answerVariables.firstWhere(
      (v) => v.key == key,
      orElse: () => AnswerVariable(nodeId: '', key: ''),
    );
    return variable.nodeId.isNotEmpty ? variable.value : null;
  }

  /// Get all answer variables as map
  Map<String, dynamic> getAnswerVariablesMap() {
    return {for (var v in _answerVariables) v.key: v.value};
  }

  // ========== Variables (Temporary Calculations) ==========

  /// Set a temporary variable
  void setVariable(String name, dynamic value) {
    _variables[name] = value;
    notifyListeners();
  }

  /// Get a temporary variable
  dynamic getVariable(String name) {
    return _variables[name];
  }

  /// Resolve a value that might be a variable reference
  /// Format: {{variableName}} or ${variableName}
  dynamic resolveValue(String value) {
    // Check if it's a variable reference
    final variablePattern = RegExp(r'\{\{(.+?)\}\}|\$\{(.+?)\}');
    final match = variablePattern.firstMatch(value);

    if (match != null) {
      final varName = match.group(1)?.isNotEmpty == true
          ? match.group(1)!
          : match.group(2)!;
      // First check answer variables
      final answerValue = getAnswerVariableValue(varName);
      if (answerValue != null) return answerValue;
      // Then check temp variables
      return getVariable(varName) ?? value;
    }

    return value;
  }

  // ========== User Metadata ==========

  /// Set user metadata field
  void setUserMetadata(String type, String value) {
    final lowercaseType = type.toLowerCase();
    switch (lowercaseType) {
      case 'name':
        _userMetadata = _userMetadata.copyWith(name: value);
        break;
      case 'email':
        _userMetadata = _userMetadata.copyWith(email: value);
        break;
      case 'phone':
      case 'mobile':
        _userMetadata = _userMetadata.copyWith(phone: value);
        break;
      default:
        _userMetadata.metadata[type] = value;
        break;
    }
    notifyListeners();
  }

  /// Get user metadata field
  String? getUserMetadata(String type) {
    final lowercaseType = type.toLowerCase();
    switch (lowercaseType) {
      case 'name':
        return _userMetadata.name;
      case 'email':
        return _userMetadata.email;
      case 'phone':
      case 'mobile':
        return _userMetadata.phone;
      default:
        return _userMetadata.metadata[type] as String?;
    }
  }

  // ========== Transcript ==========

  /// Add entry to transcript
  void addToTranscript(String by, String message) {
    _transcript.add(TranscriptEntry(by: by, message: message));
    notifyListeners();
  }

  /// Get full transcript for GPT context
  List<Map<String, String>> getTranscriptForGPT() {
    return _transcript.map((entry) {
      return {
        'role': entry.by == 'bot' || entry.by == 'agent' ? 'assistant' : 'user',
        'content': entry.message,
      };
    }).toList();
  }

  // ========== Record ==========

  /// Push data to record (with auto-merge if same ID exists)
  void pushToRecord(RecordEntry entry) {
    final existingIndex = _record.indexWhere((r) => r.id == entry.id);

    if (existingIndex != -1) {
      // Merge with existing record
      final existing = _record[existingIndex];
      final mergedData = Map<String, dynamic>.from(existing.data);
      mergedData.addAll(entry.data);
      _record[existingIndex] = entry.copyWith(data: mergedData);
    } else {
      _record.add(entry);
    }

    notifyListeners();
  }

  /// Get record as JSON-serializable list
  List<Map<String, dynamic>> getRecordForServer() {
    return _record.map((entry) => entry.toJson()).toList();
  }

  /// Build full response data object for socket emit
  Map<String, dynamic> buildResponseData() {
    return {
      'version': 'v2',
      'chatSessionId': _chatSessionId,
      'visitorId': _visitorId,
      'botId': _botId,
      'chatDate': DateTime.now().toUtc().toIso8601String(),
      'deviceInfo': _getDeviceInfo(),
      'location': DateTime.now().timeZoneName,
      'record': getRecordForServer(),
      'answerVariables': _answerVariables.map((v) => v.toJson()).toList(),
      'workspaceId': _workspaceId,
    };
  }

  /// Get device info string
  String _getDeviceInfo() {
    if (kIsWeb) {
      return 'Web';
    }
    try {
      if (Platform.isAndroid) {
        return 'Android';
      } else if (Platform.isIOS) {
        return 'iOS';
      } else if (Platform.isMacOS) {
        return 'macOS';
      } else if (Platform.isWindows) {
        return 'Windows';
      } else if (Platform.isLinux) {
        return 'Linux';
      }
    } catch (_) {
      // Platform not supported, return generic
    }
    return 'Flutter';
  }

  // ========== Reset ==========

  /// Reset all state for new conversation
  void reset() {
    _answerVariables.clear();
    _variables.clear();
    _userMetadata = UserMetadata();
    _transcript.clear();
    _record.clear();
    _currentIndex = 0;
    _steps = [];
    _chatSessionId = null;
    _visitorId = null;
    _botId = null;
    _workspaceId = null;
    notifyListeners();
  }

  /// Dispose and reset when not needed
  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
