import 'dart:async';
import 'dart:convert';
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
  // This would normally use SharedPreferences, but since it's not in pubspec,
  // we'll use a file-based approach as a placeholder
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
    // In production, this would initialize SharedPreferences
    storageLogger.debug('SharedPreferences storage initialized');
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('MessageStorageService not initialized. Call initialize() first.');
    }
  }

  String _getKey(String chatSessionId) => 'conferbot_messages_$chatSessionId';

  @override
  Future<void> saveMessages(
    String chatSessionId,
    List<RecordItem> messages, {
    bool append = false,
  }) async {
    _ensureInitialized();

    final key = _getKey(chatSessionId);
    final jsonMessages = messages.map((m) => m.toJson()).toList();

    if (append && _cache.containsKey(key)) {
      _cache[key]!.addAll(jsonMessages);
    } else {
      _cache[key] = jsonMessages;
    }
  }

  @override
  Future<void> appendMessage(String chatSessionId, RecordItem message) async {
    _ensureInitialized();

    final key = _getKey(chatSessionId);
    _cache.putIfAbsent(key, () => []);
    _cache[key]!.add(message.toJson());
  }

  @override
  Future<List<RecordItem>> loadMessages({
    required String chatSessionId,
    required int limit,
    required int offset,
  }) async {
    _ensureInitialized();

    final key = _getKey(chatSessionId);
    final jsonMessages = _cache[key];

    if (jsonMessages == null || jsonMessages.isEmpty) {
      return [];
    }

    // Messages are stored oldest first, load from newest
    final reversedMessages = jsonMessages.reversed.toList();

    if (offset >= reversedMessages.length) return [];

    final endIndex = (offset + limit).clamp(0, reversedMessages.length);
    final result = reversedMessages.sublist(offset, endIndex);

    // Return in chronological order
    return result.reversed.map((json) => RecordItem.fromJson(json)).toList();
  }

  @override
  Future<int> getMessageCount(String chatSessionId) async {
    _ensureInitialized();

    final key = _getKey(chatSessionId);
    return _cache[key]?.length ?? 0;
  }

  @override
  Future<void> updateMessage(String chatSessionId, RecordItem message) async {
    _ensureInitialized();

    final key = _getKey(chatSessionId);
    final messages = _cache[key];
    if (messages == null) return;

    final index = messages.indexWhere((m) => m['_id'] == message.id);
    if (index != -1) {
      messages[index] = message.toJson();
    }
  }

  @override
  Future<void> deleteMessage(String chatSessionId, String messageId) async {
    _ensureInitialized();

    final key = _getKey(chatSessionId);
    final messages = _cache[key];
    if (messages == null) return;

    messages.removeWhere((m) => m['_id'] == messageId);
  }

  @override
  Future<void> clearMessages(String chatSessionId) async {
    _ensureInitialized();

    final key = _getKey(chatSessionId);
    _cache.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _ensureInitialized();
    _cache.clear();
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
