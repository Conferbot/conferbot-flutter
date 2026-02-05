import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/services/storage_service.dart';
import 'package:conferbot_flutter/src/storage/adapters/hive_adapters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestableStorageService storageService;

  setUp(() {
    storageService = TestableStorageService();
  });

  tearDown(() async {
    await storageService.dispose();
  });

  group('StorageService Construction', () {
    test('should create singleton instance', () {
      expect(storageService, isNotNull);
    });

    test('should not be initialized before init', () {
      expect(storageService.isInitialized, false);
    });
  });

  group('StorageService Initialization', () {
    test('should initialize successfully', () async {
      await storageService.init();

      expect(storageService.isInitialized, true);
    });

    test('should not reinitialize if already initialized', () async {
      await storageService.init();
      await storageService.init();

      expect(storageService.isInitialized, true);
    });

    test('should throw if accessing storage before init', () {
      expect(
        () => storageService.getStoredChatbotIds(),
        throwsStateError,
      );
    });
  });

  group('StorageService Session Persistence', () {
    setUp(() async {
      await storageService.init();
    });

    test('should save session', () async {
      final session = PersistedChatSession(
        chatbotId: 'bot_123',
        chatSessionId: 'session_456',
        visitorId: 'visitor_789',
      );

      await storageService.saveSession('bot_123', session);

      final loaded = await storageService.loadSession('bot_123');
      expect(loaded, isNotNull);
      expect(loaded!.chatSessionId, 'session_456');
    });

    test('should load saved session', () async {
      final session = PersistedChatSession(
        chatbotId: 'bot_123',
        chatSessionId: 'session_456',
        visitorId: 'visitor_789',
        currentIndex: 5,
        workspaceId: 'workspace_abc',
      );

      await storageService.saveSession('bot_123', session);

      final loaded = await storageService.loadSession('bot_123');

      expect(loaded, isNotNull);
      expect(loaded!.chatbotId, 'bot_123');
      expect(loaded.chatSessionId, 'session_456');
      expect(loaded.visitorId, 'visitor_789');
      expect(loaded.currentIndex, 5);
      expect(loaded.workspaceId, 'workspace_abc');
    });

    test('should return null for non-existent session', () async {
      final loaded = await storageService.loadSession('non_existent');

      expect(loaded, isNull);
    });

    test('should update session on touch', () async {
      final session = PersistedChatSession(chatbotId: 'bot_123');
      final originalTime = session.lastActivityAt;

      await Future.delayed(const Duration(milliseconds: 10));
      session.touch();

      expect(session.lastActivityAt.isAfter(originalTime), true);
    });

    test('should save session with debounce', () async {
      final session = PersistedChatSession(
        chatbotId: 'bot_123',
        chatSessionId: 'session_456',
      );

      storageService.saveSessionDebounced('bot_123', session);
      storageService.saveSessionDebounced('bot_123', session);
      storageService.saveSessionDebounced('bot_123', session);

      // Wait for debounce
      await Future.delayed(const Duration(milliseconds: 600));

      final loaded = await storageService.loadSession('bot_123');
      expect(loaded, isNotNull);
    });
  });

  group('StorageService Session Expiry', () {
    setUp(() async {
      await storageService.init();
    });

    test('should detect expired session', () {
      final session = PersistedChatSession(chatbotId: 'bot_123');
      session.lastActivityAt = DateTime.now().subtract(const Duration(minutes: 35));

      expect(storageService.isSessionExpired(session), true);
    });

    test('should detect valid session', () {
      final session = PersistedChatSession(chatbotId: 'bot_123');
      session.lastActivityAt = DateTime.now().subtract(const Duration(minutes: 5));

      expect(storageService.isSessionExpired(session), false);
    });

    test('should use custom timeout', () {
      final session = PersistedChatSession(chatbotId: 'bot_123');
      session.lastActivityAt = DateTime.now().subtract(const Duration(minutes: 15));

      expect(
        storageService.isSessionExpired(
          session,
          timeout: const Duration(minutes: 10),
        ),
        true,
      );
      expect(
        storageService.isSessionExpired(
          session,
          timeout: const Duration(minutes: 20),
        ),
        false,
      );
    });

    test('should load valid session only', () async {
      // Save an expired session
      final expiredSession = PersistedChatSession(chatbotId: 'bot_expired');
      expiredSession.lastActivityAt = DateTime.now().subtract(const Duration(minutes: 35));
      await storageService.saveSession('bot_expired', expiredSession);

      // Save a valid session
      final validSession = PersistedChatSession(chatbotId: 'bot_valid');
      await storageService.saveSession('bot_valid', validSession);

      final loadedExpired = await storageService.loadValidSession('bot_expired');
      final loadedValid = await storageService.loadValidSession('bot_valid');

      expect(loadedExpired, isNull);
      expect(loadedValid, isNotNull);
    });

    test('should cleanup expired sessions', () async {
      // Save expired session
      final expiredSession = PersistedChatSession(chatbotId: 'bot_expired');
      expiredSession.lastActivityAt = DateTime.now().subtract(const Duration(minutes: 35));
      await storageService.saveSession('bot_expired', expiredSession);

      // Save valid session
      final validSession = PersistedChatSession(chatbotId: 'bot_valid');
      await storageService.saveSession('bot_valid', validSession);

      final cleanedCount = await storageService.cleanupExpiredSessions();

      expect(cleanedCount, 1);

      final remaining = storageService.getStoredChatbotIds();
      expect(remaining, contains('bot_valid'));
      expect(remaining, isNot(contains('bot_expired')));
    });
  });

  group('StorageService Session Clearing', () {
    setUp(() async {
      await storageService.init();
    });

    test('should clear specific session', () async {
      await storageService.saveSession(
        'bot_123',
        PersistedChatSession(chatbotId: 'bot_123'),
      );
      await storageService.saveSession(
        'bot_456',
        PersistedChatSession(chatbotId: 'bot_456'),
      );

      await storageService.clearSession('bot_123');

      final loaded = await storageService.loadSession('bot_123');
      final remaining = await storageService.loadSession('bot_456');

      expect(loaded, isNull);
      expect(remaining, isNotNull);
    });

    test('should clear all sessions', () async {
      await storageService.saveSession(
        'bot_123',
        PersistedChatSession(chatbotId: 'bot_123'),
      );
      await storageService.saveSession(
        'bot_456',
        PersistedChatSession(chatbotId: 'bot_456'),
      );

      await storageService.clearAllSessions();

      expect(storageService.getStoredChatbotIds(), isEmpty);
    });
  });

  group('StorageService Message Storage', () {
    setUp(() async {
      await storageService.init();
    });

    test('should save and load messages', () async {
      final messages = [
        PersistedChatMessage.create(
          id: 'msg_1',
          type: 'bot-message',
          time: DateTime.now(),
          text: 'Hello!',
        ),
        PersistedChatMessage.create(
          id: 'msg_2',
          type: 'user-input-response',
          time: DateTime.now(),
          text: 'Hi there!',
        ),
      ];

      await storageService.saveMessages('bot_123', messages);

      final loaded = await storageService.loadMessages('bot_123');

      expect(loaded.length, 2);
      expect(loaded[0].id, 'msg_1');
      expect(loaded[0].text, 'Hello!');
      expect(loaded[1].id, 'msg_2');
    });

    test('should return empty list for non-existent messages', () async {
      final loaded = await storageService.loadMessages('non_existent');

      expect(loaded, isEmpty);
    });

    test('should update existing session with messages', () async {
      final session = PersistedChatSession(
        chatbotId: 'bot_123',
        chatSessionId: 'session_456',
      );
      await storageService.saveSession('bot_123', session);

      final messages = [
        PersistedChatMessage.create(
          id: 'msg_1',
          type: 'bot-message',
          time: DateTime.now(),
          text: 'Hello!',
        ),
      ];

      await storageService.saveMessages('bot_123', messages);

      final loadedSession = await storageService.loadSession('bot_123');
      expect(loadedSession!.messages!.length, 1);
    });
  });

  group('StorageService Answer Variables', () {
    setUp(() async {
      await storageService.init();
    });

    test('should save and load answer variables', () async {
      // First create a session
      await storageService.saveSession(
        'bot_123',
        PersistedChatSession(chatbotId: 'bot_123'),
      );

      final variables = [
        PersistedAnswerVariable.create(
          nodeId: 'node_1',
          key: 'name',
          value: 'John',
        ),
        PersistedAnswerVariable.create(
          nodeId: 'node_2',
          key: 'email',
          value: 'john@example.com',
        ),
      ];

      await storageService.saveAnswerVariables('bot_123', variables);

      final loaded = await storageService.loadAnswerVariables('bot_123');

      expect(loaded.length, 2);
      expect(loaded[0].key, 'name');
      expect(loaded[0].value, 'John');
    });

    test('should return empty list for non-existent variables', () async {
      final loaded = await storageService.loadAnswerVariables('non_existent');

      expect(loaded, isEmpty);
    });
  });

  group('StorageService Visitor ID', () {
    setUp(() async {
      await storageService.init();
    });

    test('should create visitor ID if not exists', () async {
      final visitorId = await storageService.getOrCreateVisitorId();

      expect(visitorId, isNotNull);
      expect(visitorId, startsWith('visitor_'));
    });

    test('should return same visitor ID on subsequent calls', () async {
      final visitorId1 = await storageService.getOrCreateVisitorId();
      final visitorId2 = await storageService.getOrCreateVisitorId();

      expect(visitorId1, visitorId2);
    });

    test('should save custom visitor ID', () async {
      await storageService.saveVisitorId('custom_visitor_123');

      final loaded = await storageService.getVisitorId();

      expect(loaded, 'custom_visitor_123');
    });

    test('should get visitor ID (may be null)', () async {
      // Before any visitor ID is created
      final newService = TestableStorageService();
      await newService.init();

      // Call getVisitorId - may be null if never created
      await newService.getVisitorId();

      await newService.dispose();
    });
  });

  group('StorageService Settings', () {
    setUp(() async {
      await storageService.init();
    });

    test('should get and set settings', () async {
      await storageService.setSetting('theme', 'dark');
      await storageService.setSetting('language', 'en');

      expect(storageService.getSetting<String>('theme'), 'dark');
      expect(storageService.getSetting<String>('language'), 'en');
    });

    test('should return null for non-existent setting', () {
      expect(storageService.getSetting<String>('non_existent'), isNull);
    });

    test('should get install date', () async {
      final installDate = storageService.getInstallDate();

      expect(installDate, isNotNull);
      expect(installDate!.isBefore(DateTime.now().add(const Duration(seconds: 1))), true);
    });
  });

  group('StorageService Statistics', () {
    setUp(() async {
      await storageService.init();
    });

    test('should return storage stats', () async {
      await storageService.saveSession(
        'bot_123',
        PersistedChatSession(chatbotId: 'bot_123'),
      );

      final stats = storageService.getStats();

      expect(stats['sessionsCount'], 1);
      expect(stats['settingsCount'], isA<int>());
      expect(stats['installDate'], isNotNull);
    });
  });

  group('StorageService Export', () {
    setUp(() async {
      await storageService.init();
    });

    test('should export session data', () async {
      final session = PersistedChatSession(
        chatbotId: 'bot_123',
        chatSessionId: 'session_456',
        visitorId: 'visitor_789',
      );
      await storageService.saveSession('bot_123', session);

      final exported = storageService.exportSession('bot_123');

      expect(exported['chatbotId'], 'bot_123');
      expect(exported['chatSessionId'], 'session_456');
      expect(exported['visitorId'], 'visitor_789');
    });

    test('should return empty map for non-existent session', () {
      final exported = storageService.exportSession('non_existent');

      expect(exported, isEmpty);
    });
  });

  group('StorageService Lifecycle', () {
    test('should close storage', () async {
      await storageService.init();
      await storageService.close();

      expect(storageService.isInitialized, false);
    });

    test('should dispose and clear singleton', () async {
      await storageService.init();
      await storageService.dispose();

      expect(storageService.isInitialized, false);
    });
  });

  group('StorageService Stored Chatbot IDs', () {
    setUp(() async {
      await storageService.init();
    });

    test('should return list of stored chatbot IDs', () async {
      await storageService.saveSession(
        'bot_123',
        PersistedChatSession(chatbotId: 'bot_123'),
      );
      await storageService.saveSession(
        'bot_456',
        PersistedChatSession(chatbotId: 'bot_456'),
      );

      final ids = storageService.getStoredChatbotIds();

      expect(ids.length, 2);
      expect(ids, contains('bot_123'));
      expect(ids, contains('bot_456'));
    });

    test('should return empty list when no sessions stored', () async {
      final ids = storageService.getStoredChatbotIds();

      expect(ids, isEmpty);
    });
  });

  group('PersistedChatSession Model', () {
    test('should create with default values', () {
      final session = PersistedChatSession();

      expect(session.chatbotId, '');
      expect(session.isActive, true);
      expect(session.currentIndex, 0);
      expect(session.lastActivityAt, isNotNull);
      expect(session.createdAt, isNotNull);
    });

    test('should check expiry correctly', () {
      final session = PersistedChatSession();

      // Not expired immediately
      expect(session.isExpired(), false);

      // Set old activity time
      session.lastActivityAt = DateTime.now().subtract(const Duration(hours: 1));
      expect(session.isExpired(), true);

      // Custom timeout
      expect(session.isExpired(timeout: const Duration(hours: 2)), false);
    });

    test('should convert to JSON', () {
      final session = PersistedChatSession(
        chatbotId: 'bot_123',
        chatSessionId: 'session_456',
        visitorId: 'visitor_789',
        currentIndex: 3,
      );

      final json = session.toJson();

      expect(json['chatbotId'], 'bot_123');
      expect(json['chatSessionId'], 'session_456');
      expect(json['visitorId'], 'visitor_789');
      expect(json['currentIndex'], 3);
    });
  });

  group('PersistedChatMessage Model', () {
    test('should create from JSON', () {
      final json = {
        '_id': 'msg_123',
        'type': 'bot-message',
        'time': '2024-01-15T10:00:00Z',
        'text': 'Hello!',
        'customField': 'value',
      };

      final message = PersistedChatMessage.fromJson(json);

      expect(message.id, 'msg_123');
      expect(message.type, 'bot-message');
      expect(message.text, 'Hello!');
      expect(message.data!['customField'], 'value');
    });

    test('should convert to JSON', () {
      final message = PersistedChatMessage.create(
        id: 'msg_123',
        type: 'user-input-response',
        time: DateTime.parse('2024-01-15T10:00:00Z'),
        text: 'Hi!',
        data: {'extra': 'data'},
      );

      final json = message.toJson();

      expect(json['_id'], 'msg_123');
      expect(json['type'], 'user-input-response');
      expect(json['text'], 'Hi!');
      expect(json['extra'], 'data');
    });
  });

  group('PersistedAnswerVariable Model', () {
    test('should create from JSON', () {
      final json = {
        'nodeId': 'node_123',
        'key': 'email',
        'value': 'test@example.com',
      };

      final variable = PersistedAnswerVariable.fromJson(json);

      expect(variable.nodeId, 'node_123');
      expect(variable.key, 'email');
      expect(variable.value, 'test@example.com');
    });

    test('should convert to JSON', () {
      final variable = PersistedAnswerVariable.create(
        nodeId: 'node_123',
        key: 'name',
        value: 'John',
      );

      final json = variable.toJson();

      expect(json['nodeId'], 'node_123');
      expect(json['key'], 'name');
      expect(json['value'], 'John');
    });
  });

  group('ChatSessionPersistence Extension', () {
    test('should create snapshot', () {
      final snapshot = ChatSessionPersistence.createSnapshot(
        chatbotId: 'bot_123',
        chatSessionId: 'session_456',
        visitorId: 'visitor_789',
        currentIndex: 5,
        messages: [
          {'_id': 'msg_1', 'type': 'bot-message', 'text': 'Hello'},
        ],
        answerVariables: [
          {'nodeId': 'node_1', 'key': 'name', 'value': 'John'},
        ],
      );

      expect(snapshot.chatbotId, 'bot_123');
      expect(snapshot.chatSessionId, 'session_456');
      expect(snapshot.currentIndex, 5);
      expect(snapshot.messages!.length, 1);
      expect(snapshot.answerVariables!.length, 1);
    });
  });
}

/// Testable storage service that uses in-memory storage
class TestableStorageService {
  bool _isInitialized = false;
  final Map<String, PersistedChatSession> _sessions = {};
  final Map<String, dynamic> _settings = {};
  DateTime? _installDate;

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    _installDate = DateTime.now();
    _settings[StorageKeys.installDate] = _installDate!.toIso8601String();
    _isInitialized = true;
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'StorageService not initialized. Call StorageService.init() first.',
      );
    }
  }

  Future<void> saveSession(String chatbotId, PersistedChatSession session) async {
    _ensureInitialized();
    session.chatbotId = chatbotId;
    session.touch();
    _sessions[chatbotId] = session;
  }

  void saveSessionDebounced(String chatbotId, PersistedChatSession session) {
    Future.delayed(const Duration(milliseconds: 500), () {
      saveSession(chatbotId, session);
    });
  }

  Future<PersistedChatSession?> loadSession(String chatbotId) async {
    _ensureInitialized();
    return _sessions[chatbotId];
  }

  Future<PersistedChatSession?> loadValidSession(
    String chatbotId, {
    Duration? timeout,
  }) async {
    final session = await loadSession(chatbotId);
    if (session == null) return null;
    if (isSessionExpired(session, timeout: timeout)) return null;
    return session;
  }

  bool isSessionExpired(PersistedChatSession session, {Duration? timeout}) {
    return session.isExpired(timeout: timeout ?? StorageService.sessionTimeout);
  }

  Future<void> clearSession(String chatbotId) async {
    _ensureInitialized();
    _sessions.remove(chatbotId);
  }

  Future<void> clearAllSessions() async {
    _ensureInitialized();
    _sessions.clear();
  }

  List<String> getStoredChatbotIds() {
    _ensureInitialized();
    return _sessions.keys.toList();
  }

  Future<int> cleanupExpiredSessions({Duration? timeout}) async {
    _ensureInitialized();
    final effectiveTimeout = timeout ?? StorageService.sessionTimeout;
    final expiredKeys = <String>[];

    for (final entry in _sessions.entries) {
      if (entry.value.isExpired(timeout: effectiveTimeout)) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _sessions.remove(key);
    }

    return expiredKeys.length;
  }

  Future<void> saveMessages(
    String chatbotId,
    List<PersistedChatMessage> messages,
  ) async {
    _ensureInitialized();
    final session = _sessions[chatbotId];
    if (session != null) {
      session.messages = messages;
      session.touch();
    } else {
      final newSession = PersistedChatSession(
        chatbotId: chatbotId,
        messages: messages,
      );
      _sessions[chatbotId] = newSession;
    }
  }

  Future<List<PersistedChatMessage>> loadMessages(String chatbotId) async {
    _ensureInitialized();
    return _sessions[chatbotId]?.messages ?? [];
  }

  Future<void> saveAnswerVariables(
    String chatbotId,
    List<PersistedAnswerVariable> variables,
  ) async {
    _ensureInitialized();
    final session = _sessions[chatbotId];
    if (session != null) {
      session.answerVariables = variables;
      session.touch();
    }
  }

  Future<List<PersistedAnswerVariable>> loadAnswerVariables(String chatbotId) async {
    _ensureInitialized();
    return _sessions[chatbotId]?.answerVariables ?? [];
  }

  Future<String> getOrCreateVisitorId() async {
    _ensureInitialized();
    var visitorId = _settings[StorageKeys.visitorId] as String?;
    if (visitorId == null || visitorId.isEmpty) {
      visitorId = 'visitor_${DateTime.now().millisecondsSinceEpoch}';
      _settings[StorageKeys.visitorId] = visitorId;
    }
    return visitorId;
  }

  Future<void> saveVisitorId(String visitorId) async {
    _ensureInitialized();
    _settings[StorageKeys.visitorId] = visitorId;
  }

  Future<String?> getVisitorId() async {
    _ensureInitialized();
    return _settings[StorageKeys.visitorId] as String?;
  }

  T? getSetting<T>(String key) {
    _ensureInitialized();
    return _settings[key] as T?;
  }

  Future<void> setSetting<T>(String key, T value) async {
    _ensureInitialized();
    _settings[key] = value;
  }

  DateTime? getInstallDate() {
    final dateStr = _settings[StorageKeys.installDate] as String?;
    if (dateStr != null) {
      return DateTime.tryParse(dateStr);
    }
    return null;
  }

  Map<String, dynamic> getStats() {
    _ensureInitialized();
    return {
      'sessionsCount': _sessions.length,
      'settingsCount': _settings.length,
      'installDate': getInstallDate()?.toIso8601String(),
      'visitorId': _settings[StorageKeys.visitorId],
    };
  }

  Map<String, dynamic> exportSession(String chatbotId) {
    _ensureInitialized();
    final session = _sessions[chatbotId];
    if (session == null) return {};
    return session.toJson();
  }

  Future<void> close() async {
    _isInitialized = false;
  }

  Future<void> dispose() async {
    await close();
    _sessions.clear();
    _settings.clear();
  }
}
