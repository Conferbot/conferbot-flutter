import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/message.dart';
import '../../utils/logger.dart';

/// Abstract interface for message storage
/// Allows different storage backends (Hive, SQLite, SharedPreferences)
abstract class MessageStorageService {
  /// Initialize the storage service
  Future<void> initialize();

  /// Save messages to storage
  Future<void> saveMessages(
    String chatSessionId,
    List<RecordItem> messages, {
    bool append = false,
  });

  /// Append a single message
  Future<void> appendMessage(String chatSessionId, RecordItem message);

  /// Load messages with pagination
  Future<List<RecordItem>> loadMessages({
    required String chatSessionId,
    required int limit,
    required int offset,
  });

  /// Get total message count for a chat session
  Future<int> getMessageCount(String chatSessionId);

  /// Update a specific message
  Future<void> updateMessage(String chatSessionId, RecordItem message);

  /// Delete a specific message
  Future<void> deleteMessage(String chatSessionId, String messageId);

  /// Clear all messages for a chat session
  Future<void> clearMessages(String chatSessionId);

  /// Clear all data
  Future<void> clearAll();

  /// Dispose resources
  void dispose();
}

/// In-memory implementation of MessageStorageService
/// Useful for testing and when persistence is not needed
class InMemoryMessageStorage implements MessageStorageService {
  final Map<String, List<RecordItem>> _storage = {};

  @override
  Future<void> initialize() async {
    // No initialization needed for in-memory storage
  }

  @override
  Future<void> saveMessages(
    String chatSessionId,
    List<RecordItem> messages, {
    bool append = false,
  }) async {
    if (append && _storage.containsKey(chatSessionId)) {
      _storage[chatSessionId]!.addAll(messages);
    } else {
      _storage[chatSessionId] = List.from(messages);
    }
  }

  @override
  Future<void> appendMessage(String chatSessionId, RecordItem message) async {
    _storage.putIfAbsent(chatSessionId, () => []);
    _storage[chatSessionId]!.add(message);
  }

  @override
  Future<List<RecordItem>> loadMessages({
    required String chatSessionId,
    required int limit,
    required int offset,
  }) async {
    final messages = _storage[chatSessionId] ?? [];
    if (messages.isEmpty) return [];

    // Messages are stored oldest first, but we want to load from newest
    // So we reverse the order for pagination
    final reversedMessages = messages.reversed.toList();

    if (offset >= reversedMessages.length) return [];

    final endIndex = (offset + limit).clamp(0, reversedMessages.length);
    final result = reversedMessages.sublist(offset, endIndex);

    // Return in chronological order (oldest first)
    return result.reversed.toList();
  }

  @override
  Future<int> getMessageCount(String chatSessionId) async {
    return _storage[chatSessionId]?.length ?? 0;
  }

  @override
  Future<void> updateMessage(String chatSessionId, RecordItem message) async {
    final messages = _storage[chatSessionId];
    if (messages == null) return;

    final index = messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      messages[index] = message;
    }
  }

  @override
  Future<void> deleteMessage(String chatSessionId, String messageId) async {
    final messages = _storage[chatSessionId];
    if (messages == null) return;

    messages.removeWhere((m) => m.id == messageId);
  }

  @override
  Future<void> clearMessages(String chatSessionId) async {
    _storage.remove(chatSessionId);
  }

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }

  @override
  void dispose() {
    _storage.clear();
  }
}

/// SharedPreferences-based implementation for simple persistence
/// Uses JSON serialization to store messages
/// Note: For production use with large message volumes, consider using Hive or SQLite
class SharedPreferencesMessageStorage implements MessageStorageService {
  // A session's messages as JSON under one key, cached in memory. They were
  // only ever kept in memory (a placeholder), so no conversation survived an
  // app restart.
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // No platform storage (tests, unsupported platform): memory only.
      storageLogger.debug('SharedPreferences unavailable, keeping messages in memory: $e');
    }
    _isInitialized = true;
    storageLogger.debug('SharedPreferences storage initialized');
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('MessageStorageService not initialized. Call initialize() first.');
    }
  }

  String _getKey(String chatSessionId) => 'conferbot_messages_$chatSessionId';

  /// The session's messages, read from storage the first time.
  List<Map<String, dynamic>>? _messagesFor(String key) {
    if (_cache.containsKey(key)) return _cache[key];
    final raw = _prefs?.getString(key);
    if (raw == null) return null;
    try {
      final list = (jsonDecode(raw) as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      _cache[key] = list;
      return list;
    } catch (e) {
      storageLogger.debug('Unreadable stored messages for $key: $e');
      return null;
    }
  }

  Future<void> _persist(String key) async {
    final messages = _cache[key];
    if (_prefs == null) return;
    if (messages == null) {
      await _prefs!.remove(key);
    } else {
      await _prefs!.setString(key, jsonEncode(messages));
    }
  }

  @override
  Future<void> saveMessages(
    String chatSessionId,
    List<RecordItem> messages, {
    bool append = false,
  }) async {
    _ensureInitialized();

    final key = _getKey(chatSessionId);
    final jsonMessages = messages.map((m) => m.toJson()).toList();
    final existing = _messagesFor(key);

    if (append && existing != null) {
      existing.addAll(jsonMessages);
    } else {
      _cache[key] = jsonMessages;
    }
    await _persist(key);
  }

  @override
  Future<void> appendMessage(String chatSessionId, RecordItem message) async {
    _ensureInitialized();

    final key = _getKey(chatSessionId);
    final messages = _messagesFor(key) ?? (_cache[key] = []);
    messages.add(message.toJson());
    await _persist(key);
  }

  @override
  Future<List<RecordItem>> loadMessages({
    required String chatSessionId,
    required int limit,
    required int offset,
  }) async {
    _ensureInitialized();

    final jsonMessages = _messagesFor(_getKey(chatSessionId));

    if (jsonMessages == null || jsonMessages.isEmpty) {
      return [];
    }

    // Messages are stored oldest first, load from newest
    final reversedMessages = jsonMessages.reversed.toList();

    if (offset >= reversedMessages.length) return [];

    final endIndex = (offset + limit).clamp(0, reversedMessages.length);
    final result = reversedMessages.sublist(offset, endIndex);

    // Return in chronological order; an entry that no longer parses is skipped.
    final out = <RecordItem>[];
    for (final json in result.reversed) {
      try {
        out.add(RecordItem.fromJson(json));
      } catch (e) {
        storageLogger.debug('Skipping unreadable stored message: $e');
      }
    }
    return out;
  }

  @override
  Future<int> getMessageCount(String chatSessionId) async {
    _ensureInitialized();
    return _messagesFor(_getKey(chatSessionId))?.length ?? 0;
  }

  @override
  Future<void> updateMessage(String chatSessionId, RecordItem message) async {
    _ensureInitialized();

    final key = _getKey(chatSessionId);
    final messages = _messagesFor(key);
    if (messages == null) return;

    final index = messages.indexWhere((m) => m['_id'] == message.id);
    if (index != -1) {
      messages[index] = message.toJson();
      await _persist(key);
    }
  }

  @override
  Future<void> deleteMessage(String chatSessionId, String messageId) async {
    _ensureInitialized();

    final key = _getKey(chatSessionId);
    final messages = _messagesFor(key);
    if (messages == null) return;

    messages.removeWhere((m) => m['_id'] == messageId);
    await _persist(key);
  }

  @override
  Future<void> clearMessages(String chatSessionId) async {
    _ensureInitialized();

    final key = _getKey(chatSessionId);
    _cache.remove(key);
    await _prefs?.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _ensureInitialized();
    _cache.clear();
    final keys = _prefs?.getKeys().where((k) => k.startsWith('conferbot_messages_')).toList() ?? const [];
    for (final k in keys) {
      await _prefs!.remove(k);
    }
  }

  @override
  void dispose() {
    _cache.clear();
    _isInitialized = false;
  }
}

/// Factory for creating storage service instances
class MessageStorageFactory {
  /// Create an in-memory storage (no persistence)
  static MessageStorageService createInMemory() {
    return InMemoryMessageStorage();
  }

  /// Create a SharedPreferences-based storage (simple persistence)
  static Future<MessageStorageService> createSharedPreferences() async {
    final storage = SharedPreferencesMessageStorage();
    await storage.initialize();
    return storage;
  }

  /// Default storage factory
  /// In production, this could be configured to use different backends
  static Future<MessageStorageService> createDefault({
    bool enablePersistence = true,
  }) async {
    if (enablePersistence) {
      return createSharedPreferences();
    }
    return createInMemory();
  }
}
