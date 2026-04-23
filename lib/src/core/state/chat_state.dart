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
                  shape: r.shape,
                  type: r.type,
                  text: r.text,
                  time: r.time,
                  data: r.data,
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

  // ========== Initialization ==========

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
    _schedulePersist();
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
      _schedulePersist();
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
    _schedulePersist();
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
    _schedulePersist();
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
    _schedulePersist();
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

  /// Reset all state for new conversation
  /// Set clearPersistence to true to also clear stored session data
  void reset({bool clearPersistence = false}) {
    _autoSaveTimer?.cancel();

    final previousBotId = _botId;

    _answerVariables.clear();
    _variables.clear();
    _userMetadata = UserMetadata();
    _transcript.clear();
    _record.clear();
    _currentIndex = 0;
    _steps = [];
    _currentNodeId = null;
    _chatSessionId = null;
    _visitorId = null;
    _botId = null;
    _workspaceId = null;
    _sessionRestored = false;
    _lastActivityAt = null;
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
