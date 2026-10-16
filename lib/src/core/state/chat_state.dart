import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/message.dart';
import '../../models/queued_message.dart';
import '../../services/storage_service.dart';
import '../../services/message_queue_service.dart';
import '../../storage/adapters/hive_adapters.dart';
import '../../utils/logger.dart';
import 'message_pagination_controller.dart';
import 'message_storage_service.dart';
import '../flow/js.dart' show jsIsoString;
import '../flow/text.dart' show fillVariables;
import '../privacy/redact.dart' show maskValue, maskRecordEntry;
import '../device_language.dart';

/// Answer variable stored during conversation flow
/// Mirrors the web widget's answerVariables structure
class AnswerVariable {
  final String nodeId;
  final String key;
  dynamic value;

  /// The question it answers (a multi-question's or pre-chat question's id);
  /// the step's id otherwise.
  final String? questionId;

  AnswerVariable({
    required this.nodeId,
    required this.key,
    this.value,
    this.questionId,
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

  /// The flow step that said it, when a step did.
  final String? nodeId;
  final String? nodeType;

  /// Extra content a step's line carries (sources, an image...).
  final Map<String, dynamic>? data;

  TranscriptEntry({
    required this.by,
    required this.message,
    int? timestamp,
    this.nodeId,
    this.nodeType,
    this.data,
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

  /// Check if any user metadata has been collected
  bool get hasData =>
      (name != null && name!.isNotEmpty) ||
      (email != null && email!.isNotEmpty) ||
      (phone != null && phone!.isNotEmpty) ||
      metadata.isNotEmpty;
}

/// Record entry for each interaction
class RecordEntry {
  final String id;
  final String shape;
  final String? type;
  final String? text;
  final String time;
  final Map<String, dynamic> data;

  /// An entry kept exactly as the flow wrote it (a step, an edge, the
  /// visitor's answer in the web's shape): sent to the server as is.
  final Map<String, dynamic>? fields;

  RecordEntry({
    required this.id,
    required this.shape,
    this.type,
    this.text,
    String? time,
    Map<String, dynamic>? data,
  })  : time = time ?? DateTime.now().toUtc().toIso8601String(),
        data = data ?? {},
        fields = null;

  /// An entry in the web widget's own shape (index.ts S.record.push).
  RecordEntry.raw(Map<String, dynamic> this.fields)
      : id = (fields['id'] ?? fields['_id'] ?? '').toString(),
        shape = (fields['shape'] ?? '').toString(),
        type = fields['type']?.toString(),
        text = fields['text'] is String ? fields['text'] as String : null,
        time = (fields['time'] ?? '').toString(),
        data = fields['data'] is Map ? Map<String, dynamic>.from(fields['data'] as Map) : <String, dynamic>{};

  /// Whether this is an entry kept in the web's shape.
  bool get isRaw => fields != null;

  RecordEntry copyWith({
    String? id,
    String? shape,
    String? type,
    String? text,
    String? time,
    Map<String, dynamic>? data,
  }) {
    if (fields != null) {
      return RecordEntry.raw({
        ...fields!,
        if (id != null) 'id': id,
        if (id != null) '_id': id,
        if (shape != null) 'shape': shape,
        if (type != null) 'type': type,
        if (text != null) 'text': text,
        if (time != null) 'time': time,
        if (data != null) 'data': data,
      });
    }
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
    if (fields != null) return Map<String, dynamic>.from(fields!);
    final json = <String, dynamic>{
      '_id': id,
      'id': id,
      'type': type,
      'time': time,
    };
    // For user responses, keep flat shape/text format
    if (shape.startsWith('user-')) {
      json['shape'] = shape;
      json['text'] = text;
      // A live chat file ({url}) and a message left by email ({via, data})
      // carry their fields at the top, as the web widget records them.
      if (shape == 'user-live-message-file' || data.containsKey('via')) {
        data.forEach((k, v) => json.putIfAbsent(k, () => v));
      }
    } else {
      // For bot messages, nest data as sub-object (web widget format)
      final dataMap = Map<String, dynamic>.from(data);
      if (text != null) dataMap['text'] = text;
      json['data'] = dataMap;
    }
    return json;
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
///
/// Includes:
/// - Pagination support for efficient message handling
/// - Session persistence via Hive (30 minute timeout like web widget)
/// - Automatic state restoration on app restart
/// - GPT context building with full conversation history
/// - Offline message queue integration with delivery status tracking
/// The persisted shape of an entry kept in the web's own shape.
const String _rawShape = '__raw__';

class ChatState extends ChangeNotifier {
  // Singleton pattern
  static final ChatState _instance = ChatState._internal();
  static ChatState get instance => _instance;
  factory ChatState() => _instance;
  ChatState._internal();

  // ========== Pagination Configuration ==========

  /// Default page size for message loading
  static const int defaultPageSize = 50;

  /// Maximum messages to keep in memory
  static const int defaultMaxInMemory = 150;

  /// Maximum transcript entries to keep (oldest trimmed when exceeded)
  static const int maxTranscriptSize = 500;

  // Pagination controller for message management
  MessagePaginationController? _paginationController;
  MessagePaginationController? get paginationController => _paginationController;

  // Message queue service for offline support
  final MessageQueueService _messageQueue = MessageQueueService.instance;

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

  // Integration webhooks from chatbot data (Zapier etc.)
  // Entries: { nodeId, botId, webhookURL, active }
  List<Map<String, dynamic>> _integrationWebhooks = [];
  List<Map<String, dynamic>> get integrationWebhooks =>
      List.unmodifiable(_integrationWebhooks);

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

  // Current node ID (for persistence/resume)
  String? _currentNodeId;
  String? get currentNodeId => _currentNodeId;

  // ========== Live Chat (Agent Handover) State ==========

  /// Whether the conversation is currently in live chat mode (agent connected)
  bool _isLiveChatMode = false;
  bool get isLiveChatMode => _isLiveChatMode;

  /// Whether the agent is currently typing
  bool _agentTyping = false;
  bool get agentTyping => _agentTyping;

  // ========== Session Persistence State ==========

  /// Whether persistence is enabled
  bool _isPersistenceEnabled = false;
  bool get isPersistenceEnabled => _isPersistenceEnabled;

  /// Auto-save debounce timer
  Timer? _autoSaveTimer;
  static const Duration _autoSaveDelay = Duration(milliseconds: 500);

  /// Session restored flag
  bool _sessionRestored = false;
  bool get sessionRestored => _sessionRestored;

  /// Last activity timestamp
  DateTime? _lastActivityAt;
  DateTime? get lastActivityAt => _lastActivityAt;

  // ========== Pagination Getters ==========

  /// Get visible messages from pagination controller
  List<RecordItem> get visibleMessages =>
      _paginationController?.state.visibleMessages ?? [];

  /// Check if there are more messages to load
  bool get hasMoreMessages =>
      _paginationController?.state.hasMoreMessages ?? false;

  /// Check if currently loading more messages
  bool get isLoadingMoreMessages =>
      _paginationController?.state.isLoadingMore ?? false;

  /// Get total message count
  int get totalMessageCount =>
      _paginationController?.state.totalMessages ?? 0;

  /// Get current page
  int get currentMessagePage =>
      _paginationController?.state.currentPage ?? 0;

  // ========== Offline Queue Getters ==========

  /// Number of pending messages in queue
  int get pendingMessageCount => _messageQueue.pendingCount;

  /// Whether there are pending messages
  bool get hasPendingMessages => _messageQueue.hasPendingMessages;

  /// Whether queue is processing
  bool get isQueueProcessing => _messageQueue.isProcessing;

  // ========== Delivery Status ==========

  /// Get delivery status for a message by ID.
  /// Returns null if no tracking info is available for this message.
  MessageDeliveryStatus? getDeliveryStatus(String messageId) {
    return _messageQueue.getDeliveryStatus(messageId);
  }

  /// Check if a message is pending or sending
  bool isMessagePending(String messageId) {
    return _messageQueue.isMessagePending(messageId);
  }

  /// Track delivery status for a message
  void trackDeliveryStatus(
    String messageId, {
    String? queuedMessageId,
    MessageDeliveryStatus status = MessageDeliveryStatus.sending,
  }) {
    _messageQueue.trackDeliveryStatus(
      messageId,
      queuedMessageId: queuedMessageId,
      status: status,
    );
    notifyListeners();
  }

  /// Mark a message as delivered (confirmed by server)
  Future<void> markMessageDelivered(String messageId) async {
    await _messageQueue.markAsDelivered(messageId);
    notifyListeners();
  }

  // ========== Persistence Methods ==========

  /// Enable session persistence
  void enablePersistence() {
    _isPersistenceEnabled = true;
  }

  /// Disable session persistence
  void disablePersistence() {
    _isPersistenceEnabled = false;
    _autoSaveTimer?.cancel();
  }

  /// Restore session from persistence
  /// Returns true if a valid (non-expired) session was restored
  Future<bool> restoreFromPersistence(String botId) async {
    if (!StorageService.instance.isInitialized) {
      chatStateLogger.debug('StorageService not initialized, skipping restore');
      return false;
    }

    try {
      // Load valid session (not expired - 30 minute timeout)
      final session = await StorageService.instance.loadValidSession(botId);

      if (session == null) {
        chatStateLogger.debug('No valid session found for bot: $botId');
        // Load persisted visitor ID for new sessions
        final savedVisitorId = await StorageService.instance.getVisitorId();
        if (savedVisitorId != null) {
          _visitorId = savedVisitorId;
        }
        _sessionRestored = false;
        return false;
      }

      // Restore state from session
      _botId = botId;
      _chatSessionId = session.chatSessionId;
      _visitorId = session.visitorId;
      _workspaceId = session.workspaceId;
      _currentIndex = session.currentIndex;
      _currentNodeId = session.currentNodeId;
      _lastActivityAt = session.lastActivityAt;

      // Restore answer variables
      _answerVariables.clear();
      if (session.answerVariables != null) {
        for (final v in session.answerVariables!) {
          _answerVariables.add(AnswerVariable(
            nodeId: v.nodeId,
            key: v.key,
            value: v.value,
          ));
        }
      }

      // Restore variables
      _variables.clear();
      if (session.variables != null) {
        _variables.addAll(session.variables!);
      }

      // Restore user metadata
      if (session.userMetadata != null) {
        _userMetadata = UserMetadata(
          name: session.userMetadata!.name,
          email: session.userMetadata!.email,
          phone: session.userMetadata!.phone,
          metadata: session.userMetadata!.metadata ?? {},
        );
      }

      // Restore transcript
      _transcript.clear();
      if (session.transcript != null) {
        for (final t in session.transcript!) {
          _transcript.add(TranscriptEntry(
            by: t.by,
            message: t.message,
            timestamp: t.timestamp,
          ));
        }
      }

      // Restore record
      _record.clear();
      if (session.record != null) {
        for (final r in session.record!) {
          if (r.shape == _rawShape) {
            _record.add(RecordEntry.raw(Map<String, dynamic>.from(r.data ?? {})));
            continue;
          }
          _record.add(RecordEntry(
            id: r.id,
            shape: r.shape,
            type: r.type,
            text: r.text,
            time: r.time,
            data: r.data ?? {},
          ));
        }
      }

      _sessionRestored = true;

      chatStateLogger.debug('Session restored for bot: $botId');
      chatStateLogger.debug('Chat session ID: $_chatSessionId');
      chatStateLogger.debug('Visitor ID: $_visitorId');
      chatStateLogger.debug('Restored ${_answerVariables.length} answer variables');
      chatStateLogger.debug('Restored ${_transcript.length} transcript entries');
      chatStateLogger.debug('Restored ${_record.length} record entries');
      chatStateLogger.debug('Current index: $_currentIndex');
      chatStateLogger.debug('Current node ID: $_currentNodeId');

      notifyListeners();
      return true;
    } catch (e, stack) {
      chatStateLogger.error('Error restoring session: $e', e, stack);
      _sessionRestored = false;
      return false;
    }
  }

  /// Persist current state to storage
  Future<void> persist() async {
    if (!_isPersistenceEnabled || _botId == null) {
      return;
    }

    if (!StorageService.instance.isInitialized) {
      chatStateLogger.debug('StorageService not initialized, skipping persist');
      return;
    }

    try {
      final session = PersistedChatSession(
        chatbotId: _botId!,
        chatSessionId: _chatSessionId,
        visitorId: _visitorId,
        workspaceId: _workspaceId,
        currentIndex: _currentIndex,
        currentNodeId: _currentNodeId,
        isActive: true,
        answerVariables: _answerVariables
            .map((v) => PersistedAnswerVariable.create(
                  nodeId: v.nodeId,
                  key: v.key,
                  value: v.value,
                ))
            .toList(),
        variables: Map<String, dynamic>.from(_variables),
        userMetadata: PersistedUserMetadata.create(
          name: _userMetadata.name,
          email: _userMetadata.email,
          phone: _userMetadata.phone,
          metadata: _userMetadata.metadata,
        ),
        transcript: _transcript
            .map((t) => PersistedTranscriptEntry.create(
                  by: t.by,
                  message: t.message,
                  timestamp: t.timestamp,
                ))
            .toList(),
        record: _record
            .map((r) => PersistedRecordEntry.create(
                  id: r.id,
                  shape: r.isRaw ? _rawShape : r.shape,
                  type: r.type,
                  text: r.text,
                  time: r.time,
                  data: r.isRaw ? r.fields : r.data,
                ))
            .toList(),
      );

      await StorageService.instance.saveSession(_botId!, session);

      // Also persist visitor ID separately (survives session expiry)
      if (_visitorId != null) {
        await StorageService.instance.saveVisitorId(_visitorId!);
      }

      chatStateLogger.debug('State persisted for bot: $_botId');
    } catch (e, stack) {
      chatStateLogger.error('Error persisting state: $e', e, stack);
    }
  }

  /// Schedule a debounced persist operation
  void _schedulePersist() {
    if (!_isPersistenceEnabled) return;

    _lastActivityAt = DateTime.now();
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, () {
      persist();
    });
  }

  /// Force immediate persist (useful before app backgrounding)
  Future<void> persistNow() async {
    _autoSaveTimer?.cancel();
    await persist();
  }

  /// Clear persisted session data
  Future<void> clearPersistedSession() async {
    if (_botId != null && StorageService.instance.isInitialized) {
      await StorageService.instance.clearSession(_botId!);
    }
  }

  // ========== Live Chat State Methods ==========

  /// Set live chat mode (agent handover active)
  void setLiveChatMode(bool value) {
    _isLiveChatMode = value;
    notifyListeners();
    _schedulePersist();
  }

  /// Set agent typing status
  void setAgentTyping(bool value) {
    _agentTyping = value;
    notifyListeners();
  }

  // ========== Initialization ==========

  /// The workspace, once fetched-chatbot-data names it (an agent bot runs no
  /// flow engine, which is what set it for a flow bot).
  void setWorkspaceId(String? workspaceId) {
    if (workspaceId != null && workspaceId.isNotEmpty) _workspaceId = workspaceId;
  }

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
    _lastActivityAt = DateTime.now();
    notifyListeners();
    _schedulePersist();
  }

  /// Initialize pagination with optional custom configuration
  Future<void> initializePagination({
    PaginationConfig? config,
    MessageStorageService? storageService,
  }) async {
    final effectiveConfig = config ?? const PaginationConfig(
      pageSize: defaultPageSize,
      maxInMemory: defaultMaxInMemory,
    );

    _paginationController?.dispose();
    _paginationController = MessagePaginationController(
      config: effectiveConfig,
      storageService: storageService,
    );

    // Listen for pagination changes
    _paginationController!.addListener(_onPaginationChange);

    if (_chatSessionId != null) {
      await _paginationController!.initialize(_chatSessionId!);
    }

    notifyListeners();
  }

  void _onPaginationChange() {
    notifyListeners();
  }

  /// Set the flow steps from server response
  void setSteps(List<Map<String, dynamic>> steps) {
    _steps = List.from(steps);
    notifyListeners();
  }

  /// Set the integration webhooks from the fetched chatbot data
  void setIntegrationWebhooks(List<Map<String, dynamic>> webhooks) {
    _integrationWebhooks = List.from(webhooks);
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
    _schedulePersist();
  }

  /// Set specific index (for jumping)
  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
    _schedulePersist();
  }

  /// Set current node ID (for flow state tracking)
  void setCurrentNodeId(String? nodeId) {
    _currentNodeId = nodeId;
    _schedulePersist();
  }

  // ========== Message Pagination Methods ==========

  /// Add a message with pagination support
  Future<void> addMessage(RecordItem message) async {
    if (_paginationController != null) {
      await _paginationController!.addMessage(message);
    }
    _schedulePersist();
  }

  /// Add multiple messages with pagination support
  Future<void> addMessages(List<RecordItem> messages) async {
    if (_paginationController != null) {
      await _paginationController!.addMessages(messages);
    }
    _schedulePersist();
  }

  /// Load messages from an existing list (e.g., from API)
  Future<void> loadMessagesFromList(List<RecordItem> messages) async {
    if (_paginationController != null) {
      await _paginationController!.loadFromList(messages);
    }
  }

  /// Load more (older) messages
  Future<void> loadMoreMessages() async {
    if (_paginationController != null) {
      await _paginationController!.loadMoreMessages();
    }
  }

  /// Trim older messages from memory
  void trimOlderMessages() {
    _paginationController?.trimOlderMessages();
  }

  /// Clear pagination error
  void clearPaginationError() {
    _paginationController?.clearError();
  }

  // ========== Answer Variables ==========
  //
  // The web widget's answerVariables (index.ts _nodeCategorizeHelper,
  // _setAnswerVariable, _setAnswerVariableByKey): a question step registers
  // {nodeId, key, value: null} when it is shown and its answer fills that
  // entry; logic results and integration values are saved by name.

  /// Masking of card numbers, ids and passwords in the answers and the
  /// visitor's record entries (customizations.redactSensitive: on unless
  /// false). The transcript keeps what was typed.
  bool _redactSensitive = true;
  bool get redactSensitive => _redactSensitive;
  void setRedactSensitive(bool on) => _redactSensitive = on;

  dynamic _masked(dynamic value) => _redactSensitive ? maskValue(value) : value;

  /// A question step with data.answerVariable registers {nodeId, key,
  /// value: null} when it is shown.
  void registerAnswerVariable(String nodeId, String key) {
    if (key.isEmpty) return;
    _answerVariables.add(AnswerVariable(nodeId: nodeId, key: key, questionId: nodeId));
    notifyListeners();
    _schedulePersist();
  }

  /// Add an answer variable for a step: the step's entry is replaced (the
  /// value too), else one is added.
  void addAnswerVariable(String nodeId, String key, {dynamic value}) {
    final existingIndex = _answerVariables.indexWhere((v) => v.nodeId == nodeId);
    if (existingIndex != -1) {
      _answerVariables[existingIndex].value = value;
    } else {
      _answerVariables.add(AnswerVariable(nodeId: nodeId, key: key, value: value));
    }
    notifyListeners();
    _schedulePersist();
  }

  /// Fills the entry registered for a step (the first with that nodeId).
  /// Nothing happens when the step registered none - a question without
  /// data.answerVariable stores nothing. Returns whether one was filled.
  bool setAnswerVariable(String nodeId, dynamic value) {
    final index = _answerVariables.indexWhere((v) => v.nodeId == nodeId);
    if (index == -1) return false;
    _answerVariables[index].value = _masked(value);
    notifyListeners();
    _schedulePersist();
    return true;
  }

  /// Saves a value under a variable's name: every entry with that name gets
  /// it; with none, one entry is added (nodeId "column_mapped_<key>" unless
  /// one is given).
  void saveVariableByName(String key, dynamic value, [String? nodeId, String? questionId]) {
    if (key.isEmpty) return;
    final v = _masked(value);
    var matched = false;
    for (final a in _answerVariables) {
      if (a.key == key) {
        a.value = v;
        matched = true;
      }
    }
    if (!matched) {
      final id = (nodeId != null && nodeId.isNotEmpty) ? nodeId : 'column_mapped_$key';
      _answerVariables.add(AnswerVariable(nodeId: id, key: key, value: v, questionId: questionId ?? id));
    }
    notifyListeners();
    _schedulePersist();
  }

  /// Saves a value by name (see [saveVariableByName]).
  void setAnswerVariableByKey(String key, dynamic value) => saveVariableByName(key, value);

  /// Whether an entry with this key exists (answered or not).
  bool hasAnswerVariable(String key) => _answerVariables.any((a) => a.key == key);

  /// An answer by name: the FIRST entry with that key; null when none.
  dynamic getAnswer(String key) {
    for (final a in _answerVariables) {
      if (a.key == key) return a.value;
    }
    return null;
  }

  /// Get answer variable value by key (the first entry with that key)
  dynamic getAnswerVariableValue(String key) => getAnswer(key);

  /// All answers by name (the first entry per key)
  Map<String, dynamic> getAnswerVariablesMap() {
    final out = <String, dynamic>{};
    for (final v in _answerVariables) {
      out.putIfAbsent(v.key, () => v.value);
    }
    return out;
  }

  // ========== Variables (Temporary Calculations) ==========

  /// Set a temporary variable
  void setVariable(String name, dynamic value) {
    _variables[name] = value;
    notifyListeners();
    _schedulePersist();
  }

  /// Get a temporary variable
  dynamic getVariable(String name) {
    return _variables[name];
  }

  /// Remove a temporary variable
  void deleteVariable(String name) {
    _variables.remove(name);
    notifyListeners();
  }

  /// A placeholder's value: the answers first (the first entry with that
  /// key), then the flow variables, then the visitor's details. Internal
  /// "_" variables never fill text.
  dynamic lookupVariable(String key) {
    final name = key.trim();
    if (name.isEmpty) return null;
    if (hasAnswerVariable(name)) return getAnswer(name);
    if (!name.startsWith('_')) {
      if (_variables.containsKey(name)) return _variables[name];
    }
    switch (name) {
      case 'name':
        return _userMetadata.name;
      case 'email':
        return _userMetadata.email;
      case 'phone':
        return _userMetadata.phone;
    }
    return _userMetadata.metadata[name];
  }

  /// Fills {x}, ${x}, {{x}}, ${ANSWERS.x} and $${x} from the answers (web
  /// nodeLogic.fillVariables): an unknown, null or "" value shows nothing
  /// and the gap is tidied. "html" escapes the values; "raw" does not.
  String resolveVariables(String text, {String mode = 'raw'}) {
    if (text.isEmpty) return text;
    return fillVariables(text, lookupVariable, mode: mode);
  }

  /// Resolve the variables in a value (see [resolveVariables]).
  dynamic resolveValue(String value) => resolveVariables(value);

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
    _schedulePersist();
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

    // Trim oldest entries if transcript exceeds max size
    if (_transcript.length > maxTranscriptSize) {
      _transcript.removeRange(0, _transcript.length - maxTranscriptSize);
    }

    notifyListeners();
    _schedulePersist();
  }

  /// The lines a flow step says or the visitor answers in it
  /// ([addBotMessage], [addUserMessage]): the chat draws them.
  final StreamController<TranscriptEntry> _flowLines = StreamController<TranscriptEntry>.broadcast(sync: true);
  Stream<TranscriptEntry> get flowLines => _flowLines.stream;

  void _addLine(TranscriptEntry entry) {
    _transcript.add(entry);
    if (_transcript.length > maxTranscriptSize) {
      _transcript.removeRange(0, _transcript.length - maxTranscriptSize);
    }
    if (!_flowLines.isClosed) _flowLines.add(entry);
    notifyListeners();
    _schedulePersist();
  }

  /// A bot line a step says (a question, a greeting, an answer).
  void addBotMessage(String text, [String? nodeId, String? nodeType, Map<String, dynamic>? data]) {
    _addLine(TranscriptEntry(by: 'bot', message: text, nodeId: nodeId, nodeType: nodeType, data: data));
  }

  /// The visitor's line in a step (as typed: the transcript is never masked).
  void addUserMessage(String text, [String? nodeId]) {
    _addLine(TranscriptEntry(by: 'user', message: text, nodeId: nodeId));
  }

  void setUserName(String name) {
    _userMetadata = _userMetadata.copyWith(name: name);
    notifyListeners();
  }

  void setUserEmail(String email) {
    _userMetadata = _userMetadata.copyWith(email: email);
    notifyListeners();
  }

  void setUserPhone(String phone) {
    _userMetadata = _userMetadata.copyWith(phone: phone);
    notifyListeners();
  }

  /// Get full transcript for GPT context (simple version)
  List<Map<String, String>> getTranscriptForGPT() {
    return _transcript.map((entry) {
      return {
        'role': entry.by == 'bot' || entry.by == 'agent' ? 'assistant' : 'user',
        'content': entry.message,
      };
    }).toList();
  }

  /// Get transcript with optional message limit
  /// Returns the most recent messages if limit is specified
  List<Map<String, String>> getTranscriptForGPTWithLimit({int? maxMessages}) {
    List<TranscriptEntry> relevantTranscript;
    if (maxMessages != null && maxMessages > 0 && _transcript.length > maxMessages) {
      relevantTranscript = _transcript.sublist(_transcript.length - maxMessages);
    } else {
      relevantTranscript = _transcript.toList();
    }

    return relevantTranscript.map((entry) {
      return {
        'role': entry.by == 'bot' || entry.by == 'agent' ? 'assistant' : 'user',
        'content': entry.message,
      };
    }).toList();
  }

  // ========== GPT Context Building ==========

  /// Build comprehensive GPT context including all conversation data
  /// This is the main method for GPT integrations to get full context
  ///
  /// [systemPrompt] - Optional system prompt to include
  /// [maxHistoryMessages] - Optional limit on conversation history
  /// [includeUserContext] - Whether to include user metadata in system prompt
  /// [includeAnswerVariables] - Whether to include previous answers in context
  Map<String, dynamic> buildGptContext({
    String? systemPrompt,
    int? maxHistoryMessages,
    bool includeUserContext = true,
    bool includeAnswerVariables = true,
  }) {
    final messages = <Map<String, String>>[];

    // Build enhanced system prompt
    final enhancedSystemPrompt = _buildEnhancedSystemPrompt(
      basePrompt: systemPrompt,
      includeUserContext: includeUserContext,
      includeAnswerVariables: includeAnswerVariables,
    );
    messages.add({'role': 'system', 'content': enhancedSystemPrompt});

    // Add conversation history
    final transcriptMessages = getTranscriptForGPTWithLimit(maxMessages: maxHistoryMessages);
    messages.addAll(transcriptMessages);

    return {
      'messages': messages,
      'userContext': _buildUserContextMap(),
      'conversationMetadata': {
        'chatSessionId': _chatSessionId,
        'visitorId': _visitorId,
        'botId': _botId,
        'workspaceId': _workspaceId,
        'messageCount': _transcript.length,
        'answerVariables': getAnswerVariablesMap(),
      },
    };
  }

  /// Build OpenAI-compatible messages array with full context
  List<Map<String, String>> buildGptMessagesArray({
    String? systemPrompt,
    int? maxHistoryMessages,
    bool includeUserContext = true,
    bool includeAnswerVariables = true,
  }) {
    final context = buildGptContext(
      systemPrompt: systemPrompt,
      maxHistoryMessages: maxHistoryMessages,
      includeUserContext: includeUserContext,
      includeAnswerVariables: includeAnswerVariables,
    );
    return List<Map<String, String>>.from(context['messages'] as List);
  }

  /// Build enhanced system prompt with user context and answer variables
  String _buildEnhancedSystemPrompt({
    String? basePrompt,
    bool includeUserContext = true,
    bool includeAnswerVariables = true,
  }) {
    final buffer = StringBuffer();

    // Base system prompt
    buffer.writeln(basePrompt ?? 'You are a helpful assistant.');

    // Add user context to system prompt
    if (includeUserContext && _userMetadata.hasData) {
      buffer.writeln();
      buffer.writeln('User Information:');
      if (_userMetadata.name != null && _userMetadata.name!.isNotEmpty) {
        buffer.writeln('- Name: ${_userMetadata.name}');
      }
      if (_userMetadata.email != null && _userMetadata.email!.isNotEmpty) {
        buffer.writeln('- Email: ${_userMetadata.email}');
      }
      if (_userMetadata.phone != null && _userMetadata.phone!.isNotEmpty) {
        buffer.writeln('- Phone: ${_userMetadata.phone}');
      }
      // Include any custom metadata
      _userMetadata.metadata.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          buffer.writeln('- $key: $value');
        }
      });
    }

    // Add previous answers context
    if (includeAnswerVariables) {
      final previousAnswers = getAnswerVariablesMap();
      if (previousAnswers.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Previous Answers from Conversation:');
        previousAnswers.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            buffer.writeln('- $key: $value');
          }
        });
      }
    }

    return buffer.toString();
  }

  /// Build user context map for external use
  Map<String, dynamic> _buildUserContextMap() {
    return {
      if (_userMetadata.name != null && _userMetadata.name!.isNotEmpty)
        'name': _userMetadata.name,
      if (_userMetadata.email != null && _userMetadata.email!.isNotEmpty)
        'email': _userMetadata.email,
      if (_userMetadata.phone != null && _userMetadata.phone!.isNotEmpty)
        'phone': _userMetadata.phone,
      ..._userMetadata.metadata,
    };
  }

  // ========== Record ==========

  /// Adds an entry; one with the same id AND the same kind (type|shape)
  /// is merged into, as the web widget's _pushDataToRecord does - the bot's
  /// step and the visitor's answer to it stay separate entries.
  void pushToRecord(RecordEntry entry) {
    String kind(Map<String, dynamic> r) => '${r['type'] ?? ''}|${r['shape'] ?? ''}';
    final json = entry.toJson();
    final existingIndex = _record.indexWhere((r) => r.id == entry.id && kind(r.toJson()) == kind(json));

    if (existingIndex != -1) {
      final existing = _record[existingIndex];
      if (existing.isRaw || entry.isRaw) {
        final merged = <String, dynamic>{...existing.toJson(), ...json};
        final a = existing.toJson()['data'];
        final b = json['data'];
        if (a is Map || b is Map) {
          merged['data'] = {...?(a is Map ? Map<String, dynamic>.from(a) : null), ...?(b is Map ? Map<String, dynamic>.from(b) : null)};
        }
        _record[existingIndex] = RecordEntry.raw(merged);
      } else {
        final mergedData = Map<String, dynamic>.from(existing.data);
        mergedData.addAll(entry.data);
        _record[existingIndex] = entry.copyWith(data: mergedData);
      }
    } else {
      _record.add(entry);
    }

    notifyListeners();
    _schedulePersist();
  }

  /// An entry in the web's shape, merged like [pushToRecord]. The visitor's
  /// own entries never carry a card number, id or password (web
  /// _pushDataToRecord -> privacy maskRecordEntry).
  void addRecord(Map<String, dynamic> entry) {
    final e = Map<String, dynamic>.from(entry);
    if (_redactSensitive) maskRecordEntry(e);
    pushToRecord(RecordEntry.raw(e));
  }

  /// Appends an entry as it is - every visit of a step and every edge taken
  /// is its own entry (web index.ts S.record.push).
  void appendRecord(Map<String, dynamic> entry) {
    _record.add(RecordEntry.raw(Map<String, dynamic>.from(entry)));
    notifyListeners();
    _schedulePersist();
  }

  /// The visitor's vote kept on the answer's agent-message entry, as the web
  /// keeps it (`entry.feedback = {...feedback, at}`), so the conversation's
  /// record says how it was rated. False when no entry has that id.
  bool setAnswerFeedback(String agentMessageId, Map<String, dynamic> feedback, {String? at}) {
    final i = _record.indexWhere((e) => e.id == agentMessageId && (e.shape == 'agent-message' || e.type == 'agent-message'));
    if (i < 0) return false;
    _record[i] = RecordEntry.raw({
      ..._record[i].toJson(),
      'feedback': {...feedback, 'at': at ?? jsIsoString(DateTime.now())},
    });
    notifyListeners();
    _schedulePersist();
    return true;
  }

  /// The record as the server gets it.
  List<Map<String, dynamic>> getRecord() => getRecordForServer();

  /// The flow reached its end (web: hasChatEnded).
  void markConversationComplete([String? reason]) {
    _variables['_flowComplete'] = true;
    _variables['_flowCompletedAt'] = jsIsoString(DateTime.now());
    if (reason != null) _variables['_flowCompletionReason'] = reason;
    notifyListeners();
    _schedulePersist();
  }

  /// Get record as JSON-serializable list
  List<Map<String, dynamic>> getRecordForServer() {
    return _record.map((entry) => entry.toJson()).toList();
  }

  /// Build full response data object for socket emit
  /// The app's signed-in user (ConferBotUser.toVisitorContext), sent with every
  /// response record. Set by ConferBotProvider; kept across resets.
  Map<String, dynamic>? visitorContext;

  Map<String, dynamic> buildResponseData() {
    // The app's signed-in user travels with every record, as the web widget's
    // visitorContext; the server checks its hash and drops it.
    final ctx = visitorContext;
    // The device's language, as the web's visitorInsights.language.browser:
    // the AI answers a short message in it (core/device_language.dart).
    final insights = DeviceLanguage.visitorInsightsOf(DeviceLanguage.current);
    return {
      if (insights != null) 'visitorInsights': insights,
      if (ctx != null) ...{
        'visitorContext': ctx,
        if (ctx['name'] is String) 'visitorName': ctx['name'],
        if (ctx['email'] is String) 'visitorEmail': ctx['email'],
      },
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
      'channel': 'mobile',
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

  /// A copy of the conversation's state as it is now: what "Edit" on an
  /// answer returns to (core/delight/delight.dart; RN ChatState.toJSON).
  ChatSnapshot snapshot() => ChatSnapshot._(
        answerVariables: [for (final a in _answerVariables) a.copyWith()],
        variables: _deepCopy(_variables) as Map<String, dynamic>,
        userMetadata: _userMetadata.copyWith(metadata: _deepCopy(_userMetadata.metadata) as Map<String, dynamic>),
        transcript: List.of(_transcript),
        record: List.of(_record),
        currentIndex: _currentIndex,
        currentNodeId: _currentNodeId,
      );

  /// Puts a [snapshot] back in place, keeping this instance and its
  /// listeners (RN ChatState.restore).
  void restore(ChatSnapshot s) {
    _answerVariables
      ..clear()
      ..addAll([for (final a in s.answerVariables) a.copyWith()]);
    _variables
      ..clear()
      ..addAll(_deepCopy(s.variables) as Map<String, dynamic>);
    _userMetadata = s.userMetadata.copyWith(metadata: _deepCopy(s.userMetadata.metadata) as Map<String, dynamic>);
    _transcript
      ..clear()
      ..addAll(s.transcript);
    _record
      ..clear()
      ..addAll(s.record);
    _currentIndex = s.currentIndex;
    _currentNodeId = s.currentNodeId;
    notifyListeners();
  }

  static dynamic _deepCopy(dynamic v) {
    if (v is Map) return <String, dynamic>{for (final e in v.entries) '${e.key}': _deepCopy(e.value)};
    if (v is List) return [for (final x in v) _deepCopy(x)];
    return v;
  }

  /// Reset all state for new conversation
  /// Set clearPersistence to true to also clear stored session data
  void reset({bool clearPersistence = false}) {
    _autoSaveTimer?.cancel();

    final previousBotId = _botId;

    _answerVariables.clear();
    _variables.clear();
    _redactSensitive = true;
    _userMetadata = UserMetadata();
    _transcript.clear();
    _record.clear();
    _currentIndex = 0;
    _steps = [];
    _integrationWebhooks = [];
    _currentNodeId = null;
    _chatSessionId = null;
    _visitorId = null;
    _botId = null;
    _workspaceId = null;
    _sessionRestored = false;
    _lastActivityAt = null;
    _isLiveChatMode = false;
    _agentTyping = false;
    _paginationController?.reset();

    notifyListeners();

    // Clear persisted session if requested
    if (clearPersistence && previousBotId != null) {
      StorageService.instance.clearSession(previousBotId);
    }
  }

  /// Reset while keeping visitor ID (for session expiry)
  /// This starts a fresh conversation but retains visitor identity
  void resetKeepingVisitor({bool clearPersistence = false}) {
    final savedVisitorId = _visitorId;
    final previousBotId = _botId;
    reset(clearPersistence: false);
    _visitorId = savedVisitorId;

    // Clear persisted session if requested
    if (clearPersistence && previousBotId != null) {
      StorageService.instance.clearSession(previousBotId);
    }
  }

  /// Reset pagination only (useful for refreshing messages)
  Future<void> resetPagination() async {
    if (_paginationController != null && _chatSessionId != null) {
      await _paginationController!.initialize(_chatSessionId!);
    }
  }

  /// Dispose and reset when not needed
  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    // Force final persist before dispose
    if (_isPersistenceEnabled && _botId != null) {
      persist();
    }
    _paginationController?.removeListener(_onPaginationChange);
    _paginationController?.dispose();
    reset();
    super.dispose();
  }
}

/// The conversation's state at one moment (ChatState.snapshot).
class ChatSnapshot {
  final List<AnswerVariable> answerVariables;
  final Map<String, dynamic> variables;
  final UserMetadata userMetadata;
  final List<TranscriptEntry> transcript;
  final List<RecordEntry> record;
  final int currentIndex;
  final String? currentNodeId;

  const ChatSnapshot._({
    required this.answerVariables,
    required this.variables,
    required this.userMetadata,
    required this.transcript,
    required this.record,
    required this.currentIndex,
    required this.currentNodeId,
  });
}
