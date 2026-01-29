import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../storage/adapters/hive_adapters.dart';
import '../utils/logger.dart';

/// Box names for Hive storage
class StorageBoxNames {
  static const String sessions = 'conferbot_sessions';
  static const String settings = 'conferbot_settings';
  static const String messages = 'conferbot_messages';
}

/// Settings keys
class StorageKeys {
  static const String visitorId = 'visitor_id';
  static const String lastChatbotId = 'last_chatbot_id';
  static const String installDate = 'install_date';
}

/// Storage service for persisting ConferBot session data
/// Uses Hive for efficient local storage on mobile devices
class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ?? StorageService._();

  StorageService._();

  factory StorageService() => instance;

  /// Boxes
  Box<PersistedChatSession>? _sessionsBox;
  Box<dynamic>? _settingsBox;

  /// Initialization state
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Session expiry duration (30 minutes like web widget)
  static const Duration sessionTimeout = Duration(minutes: 30);

  /// Debounce timer for auto-save
  Timer? _saveDebounceTimer;
  static const Duration _saveDebounceDelay = Duration(milliseconds: 500);

  /// UUID generator for visitor IDs
  final _uuid = const Uuid();

  /// Initialize Hive and register adapters
  /// Must be called before any storage operations
  /// Typically called in main() before runApp()
  static Future<void> init() async {
    if (_instance != null && _instance!._isInitialized) {
      return;
    }

    _instance = StorageService._();
    await _instance!._initialize();
  }

  /// Internal initialization
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive for Flutter
      await Hive.initFlutter();

      // Register adapters (check if not already registered)
      _registerAdapters();

      // Open boxes
      _sessionsBox = await Hive.openBox<PersistedChatSession>(
        StorageBoxNames.sessions,
      );
      _settingsBox = await Hive.openBox(StorageBoxNames.settings);

      // Ensure install date is set
      if (!_settingsBox!.containsKey(StorageKeys.installDate)) {
        await _settingsBox!.put(
          StorageKeys.installDate,
          DateTime.now().toIso8601String(),
        );
      }

      _isInitialized = true;

      storageLogger.info('Initialized successfully');
      storageLogger.debug('Sessions in storage: ${_sessionsBox!.length}');
    } catch (e, stack) {
      storageLogger.error('Initialization error', e, stack);
      // Clear corrupted data and retry
      await _clearAndRetry();
    }
  }

  /// Register Hive adapters
  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(HiveTypeIds.chatMessage)) {
      Hive.registerAdapter(PersistedChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.answerVariable)) {
      Hive.registerAdapter(PersistedAnswerVariableAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.userMetadata)) {
      Hive.registerAdapter(PersistedUserMetadataAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.transcriptEntry)) {
      Hive.registerAdapter(PersistedTranscriptEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.recordEntry)) {
      Hive.registerAdapter(PersistedRecordEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.persistedSession)) {
      Hive.registerAdapter(PersistedChatSessionAdapter());
    }
  }

  /// Clear corrupted data and retry initialization
  Future<void> _clearAndRetry() async {
    try {
      await Hive.deleteBoxFromDisk(StorageBoxNames.sessions);
      await Hive.deleteBoxFromDisk(StorageBoxNames.settings);

      _sessionsBox = await Hive.openBox<PersistedChatSession>(
        StorageBoxNames.sessions,
      );
      _settingsBox = await Hive.openBox(StorageBoxNames.settings);

      _isInitialized = true;

      storageLogger.info('Recovery successful after clearing data');
    } catch (e) {
      storageLogger.error('Recovery failed', e);
      _isInitialized = false;
    }
  }

  /// Ensure storage is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'StorageService not initialized. Call StorageService.init() first.',
      );
    }
  }

  // ========== Session Management ==========

  /// Save a chat session
  Future<void> saveSession(String chatbotId, PersistedChatSession session) async {
    _ensureInitialized();

    session.chatbotId = chatbotId;
    session.touch(); // Update last activity

    await _sessionsBox!.put(chatbotId, session);

    storageLogger.debug('Session saved for bot: $chatbotId');
  }

  /// Save session with debouncing (for auto-save on changes)
  void saveSessionDebounced(String chatbotId, PersistedChatSession session) {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(_saveDebounceDelay, () {
      saveSession(chatbotId, session);
    });
  }

  /// Load a chat session
  Future<PersistedChatSession?> loadSession(String chatbotId) async {
    _ensureInitialized();

    final session = _sessionsBox!.get(chatbotId);

    if (session != null) {
      storageLogger.debug('Session loaded for bot: $chatbotId');
      storageLogger.debug('Session last activity: ${session.lastActivityAt}');
      storageLogger.debug('Session expired: ${session.isExpired()}');
    }

    return session;
  }

  /// Load session if not expired, otherwise return null
  Future<PersistedChatSession?> loadValidSession(
    String chatbotId, {
    Duration? timeout,
  }) async {
    final session = await loadSession(chatbotId);

    if (session == null) return null;

    if (session.isExpired(timeout: timeout ?? sessionTimeout)) {
      storageLogger.debug('Session expired, will start fresh');
      return null;
    }

    return session;
  }

  /// Clear a session for a specific chatbot
  Future<void> clearSession(String chatbotId) async {
    _ensureInitialized();

    await _sessionsBox!.delete(chatbotId);

    storageLogger.debug('Session cleared for bot: $chatbotId');
  }

  /// Clear all sessions
  Future<void> clearAllSessions() async {
    _ensureInitialized();

    await _sessionsBox!.clear();

    storageLogger.debug('All sessions cleared');
  }

  /// Check if session is expired
  bool isSessionExpired(PersistedChatSession session, {Duration? timeout}) {
    return session.isExpired(timeout: timeout ?? sessionTimeout);
  }

  /// Get all stored session IDs
  List<String> getStoredChatbotIds() {
    _ensureInitialized();
    return _sessionsBox!.keys.cast<String>().toList();
  }

  /// Clean up expired sessions
  Future<int> cleanupExpiredSessions({Duration? timeout}) async {
    _ensureInitialized();

    final expiredKeys = <String>[];
    final effectiveTimeout = timeout ?? sessionTimeout;

    for (final key in _sessionsBox!.keys) {
      final session = _sessionsBox!.get(key);
      if (session != null && session.isExpired(timeout: effectiveTimeout)) {
        expiredKeys.add(key as String);
      }
    }

    for (final key in expiredKeys) {
      await _sessionsBox!.delete(key);
    }

    if (expiredKeys.isNotEmpty) {
      storageLogger.info('Cleaned up ${expiredKeys.length} expired sessions');
    }

    return expiredKeys.length;
  }

  // ========== Messages ==========

  /// Save messages for a chatbot session
  Future<void> saveMessages(
    String chatbotId,
    List<PersistedChatMessage> messages,
  ) async {
    _ensureInitialized();

    final session = _sessionsBox!.get(chatbotId);
    if (session != null) {
      session.messages = messages;
      session.touch();
      await session.save();
    } else {
      // Create new session with messages
      final newSession = PersistedChatSession(
        chatbotId: chatbotId,
        messages: messages,
      );
      await _sessionsBox!.put(chatbotId, newSession);
    }
  }

  /// Load messages for a chatbot session
  Future<List<PersistedChatMessage>> loadMessages(String chatbotId) async {
    _ensureInitialized();

    final session = _sessionsBox!.get(chatbotId);
    return session?.messages ?? [];
  }

  // ========== Answer Variables ==========

  /// Save answer variables for a session
  Future<void> saveAnswerVariables(
    String chatbotId,
    List<PersistedAnswerVariable> variables,
  ) async {
    _ensureInitialized();

    final session = _sessionsBox!.get(chatbotId);
    if (session != null) {
      session.answerVariables = variables;
      session.touch();
      await session.save();
    }
  }

  /// Load answer variables for a session
  Future<List<PersistedAnswerVariable>> loadAnswerVariables(
    String chatbotId,
  ) async {
    _ensureInitialized();

    final session = _sessionsBox!.get(chatbotId);
    return session?.answerVariables ?? [];
  }

  // ========== Visitor ID (Persistent) ==========

  /// Get or create a persistent visitor ID
  /// This persists across sessions and app restarts
  Future<String> getOrCreateVisitorId() async {
    _ensureInitialized();

    String? visitorId = _settingsBox!.get(StorageKeys.visitorId) as String?;

    if (visitorId == null || visitorId.isEmpty) {
      visitorId = 'visitor_${_uuid.v4()}';
      await _settingsBox!.put(StorageKeys.visitorId, visitorId);

      storageLogger.info('Created new visitor ID');
    }

    return visitorId;
  }

  /// Save visitor ID
  Future<void> saveVisitorId(String visitorId) async {
    _ensureInitialized();
    await _settingsBox!.put(StorageKeys.visitorId, visitorId);
  }

  /// Get visitor ID (may return null if not set)
  Future<String?> getVisitorId() async {
    _ensureInitialized();
    return _settingsBox!.get(StorageKeys.visitorId) as String?;
  }

  // ========== Settings ==========

  /// Get a setting value
  T? getSetting<T>(String key) {
    _ensureInitialized();
    return _settingsBox!.get(key) as T?;
  }

  /// Set a setting value
  Future<void> setSetting<T>(String key, T value) async {
    _ensureInitialized();
    await _settingsBox!.put(key, value);
  }

  /// Get install date
  DateTime? getInstallDate() {
    final dateStr = _settingsBox?.get(StorageKeys.installDate) as String?;
    if (dateStr != null) {
      return DateTime.tryParse(dateStr);
    }
    return null;
  }

  // ========== Utility ==========

  /// Get storage statistics
  Map<String, dynamic> getStats() {
    _ensureInitialized();

    return {
      'sessionsCount': _sessionsBox!.length,
      'settingsCount': _settingsBox!.length,
      'installDate': getInstallDate()?.toIso8601String(),
      'visitorId': _settingsBox!.get(StorageKeys.visitorId),
    };
  }

  /// Export session data for debugging
  Map<String, dynamic> exportSession(String chatbotId) {
    _ensureInitialized();

    final session = _sessionsBox!.get(chatbotId);
    if (session == null) return {};

    return session.toJson();
  }

  /// Close storage (call on app dispose)
  Future<void> close() async {
    _saveDebounceTimer?.cancel();

    if (_sessionsBox?.isOpen == true) {
      await _sessionsBox!.close();
    }
    if (_settingsBox?.isOpen == true) {
      await _settingsBox!.close();
    }

    _isInitialized = false;

    storageLogger.info('Storage closed');
  }

  /// Dispose and clear singleton
  Future<void> dispose() async {
    await close();
    _instance = null;
  }
}

/// Extension to create PersistedChatSession from current state
extension ChatSessionPersistence on PersistedChatSession {
  /// Create a session snapshot with current data
  static PersistedChatSession createSnapshot({
    required String chatbotId,
    String? chatSessionId,
    String? visitorId,
    String? workspaceId,
    int currentIndex = 0,
    String? currentNodeId,
    List<Map<String, dynamic>>? messages,
    List<Map<String, dynamic>>? answerVariables,
    Map<String, dynamic>? userMetadata,
    List<Map<String, dynamic>>? transcript,
    List<Map<String, dynamic>>? record,
    Map<String, dynamic>? variables,
  }) {
    return PersistedChatSession(
      chatbotId: chatbotId,
      chatSessionId: chatSessionId,
      visitorId: visitorId,
      workspaceId: workspaceId,
      currentIndex: currentIndex,
      currentNodeId: currentNodeId,
      messages: messages
          ?.map((m) => PersistedChatMessage.fromJson(m))
          .toList(),
      answerVariables: answerVariables
          ?.map((v) => PersistedAnswerVariable.fromJson(v))
          .toList(),
      userMetadata: userMetadata != null
          ? PersistedUserMetadata.fromJson(userMetadata)
          : null,
      transcript: transcript
          ?.map((t) => PersistedTranscriptEntry.fromJson(t))
          .toList(),
      record: record
          ?.map((r) => PersistedRecordEntry.fromJson(r))
          .toList(),
      variables: variables,
    );
  }
}
