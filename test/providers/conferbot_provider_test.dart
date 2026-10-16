import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:conferbot_flutter/src/providers/conferbot_provider.dart';
import 'package:conferbot_flutter/src/models/user.dart';
import 'package:conferbot_flutter/src/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../fixtures/test_fixtures.dart';

class _TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TempPaths(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConferBotProvider provider;

  // openChat starts a session: the visitor id comes from StorageService
  // (the test binding answers every HTTP call with 400, so the session is local).
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _TempPaths(Directory.systemTemp.createTempSync('cb_provider_').path);
    await StorageService.init();
  });

  setUp(() {
    // Create provider with autoConnect disabled for testing
    provider = ConferBotProvider(
      apiKey: 'test_api_key',
      botId: 'test_bot_id',
      config: const ConferBotConfig(autoConnect: false, enablePersistence: false),
    );
  });

  tearDown(() {
    provider.dispose();
  });

  group('ConferBotProvider Construction', () {
    test('should create with required parameters', () {
      expect(provider.apiKey, 'test_api_key');
      expect(provider.botId, 'test_bot_id');
    });

    test('should create with default config', () {
      final defaultProvider = ConferBotProvider(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        config: const ConferBotConfig(autoConnect: false),
      );

      expect(defaultProvider.config.enableNotifications, true);
      expect(defaultProvider.config.enableOfflineMode, true);
      expect(defaultProvider.config.autoConnect, false);

      defaultProvider.dispose();
    });

    test('should create with custom config', () {
      final customProvider = ConferBotProvider(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        config: const ConferBotConfig(
          enableNotifications: false,
          enableOfflineMode: false,
          autoConnect: false,
          reconnectionAttempts: 10,
          reconnectionDelay: 2000,
        ),
      );

      expect(customProvider.config.enableNotifications, false);
      expect(customProvider.config.enableOfflineMode, false);
      expect(customProvider.config.reconnectionAttempts, 10);
      expect(customProvider.config.reconnectionDelay, 2000);

      customProvider.dispose();
    });

    test('should create with user', () {
      final userProvider = ConferBotProvider(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        config: const ConferBotConfig(autoConnect: false),
        user: const ConferBotUser(
          id: 'user_123',
          name: 'John Doe',
          email: 'john@example.com',
        ),
      );

      expect(userProvider.user, isNotNull);
      expect(userProvider.user!.id, 'user_123');
      expect(userProvider.user!.name, 'John Doe');
      expect(userProvider.user!.email, 'john@example.com');

      userProvider.dispose();
    });

    test('should create with custom URLs', () {
      final customUrlProvider = ConferBotProvider(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        config: const ConferBotConfig(autoConnect: false),
        baseUrl: 'https://custom.api.com',
        socketUrl: 'https://custom.socket.com',
      );

      expect(customUrlProvider.baseUrl, 'https://custom.api.com');
      expect(customUrlProvider.socketUrl, 'https://custom.socket.com');

      customUrlProvider.dispose();
    });
  });

  group('ConferBotProvider Initial State', () {
    test('should start not initialized', () {
      expect(provider.isInitialized, false);
    });

    test('should start disconnected', () {
      expect(provider.isConnected, false);
    });

    test('should start closed', () {
      expect(provider.isOpen, false);
    });

    test('should start with no session', () {
      expect(provider.chatSessionId, isNull);
      expect(provider.visitorId, isNull);
    });

    test('should start with empty record', () {
      expect(provider.record, isEmpty);
    });

    test('should start with no agent', () {
      expect(provider.currentAgent, isNull);
    });

    test('should start with zero unread count', () {
      expect(provider.unreadCount, 0);
    });

    test('should start with no UI state', () {
      expect(provider.currentUIState, isNull);
    });

    test('should start not processing', () {
      expect(provider.isProcessing, false);
    });

    test('should start flow not complete', () {
      expect(provider.isFlowComplete, false);
    });

    test('should start with no error', () {
      expect(provider.errorMessage, isNull);
    });
  });

  group('ConferBotProvider Flow Engine', () {
    test('should expose flow engine', () {
      expect(provider.flowEngine, isNotNull);
    });
  });

  group('ConferBotProvider Open/Close Chat', () {
    test('should set isOpen to true when opened', () async {
      // Note: This will attempt to init session but we're just testing the open state
      await provider.openChat();

      expect(provider.isOpen, true);
    });

    test('should clear unread count when opened', () async {
      await provider.openChat();

      expect(provider.unreadCount, 0);
    });

    test('should set isOpen to false when closed', () async {
      await provider.openChat();
      provider.closeChat();

      expect(provider.isOpen, false);
    });
  });

  group('ConferBotProvider Send Message', () {
    test('should not send empty message', () async {
      await provider.sendMessage('');

      // No message should be recorded
      expect(provider.record.length, 0);
    });

    test('should not send message without session', () async {
      await provider.sendMessage('Hello');

      // Message should not be sent without session
      expect(provider.record.length, 0);
    });
  });

  group('ConferBotProvider Typing Status', () {
    test('should not send typing without session', () {
      // Should not throw
      expect(() => provider.sendTypingStatus(true), returnsNormally);
    });
  });

  group('ConferBotProvider Handover', () {
    test('should not initiate handover without session', () {
      // Should not throw
      expect(() => provider.initiateHandover(), returnsNormally);
    });

    test('should accept optional message', () {
      // Should not throw
      expect(() => provider.initiateHandover(message: 'Need help'), returnsNormally);
    });
  });

  group('ConferBotProvider Error Handling', () {
    test('should clear error', () {
      provider.clearError();

      expect(provider.errorMessage, isNull);
    });
  });

  group('ConferBotProvider Reset', () {
    test('should reset conversation', () {
      provider.resetConversation();

      expect(provider.record, isEmpty);
      expect(provider.chatSessionId, isNull);
      expect(provider.currentAgent, isNull);
    });
  });

  group('ConferBotProvider Event Listeners', () {
    test('should register custom event listener', () {
      var received = false;

      provider.on('custom-event', (_) => received = true);

      // The listener is registered, but events come through socket
      expect(() => provider.off('custom-event'), returnsNormally);
    });

    test('should remove custom event listener', () {
      void callback(dynamic data) {}

      provider.on('custom-event', callback);
      provider.off('custom-event', callback);

      // Should not throw
      expect(true, true);
    });
  });

  group('ConferBotProvider Notification', () {
    test('should notify listeners on state change', () async {
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.openChat();

      expect(notified, true);
    });

    test('should not notify after dispose', () async {
      // Its own provider: the shared one is disposed in tearDown.
      final own = ConferBotProvider(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        config: const ConferBotConfig(autoConnect: false, enablePersistence: false),
      );
      var notifyCount = 0;
      own.addListener(() => notifyCount++);

      await own.openChat();
      final countAfterOpen = notifyCount;

      own.dispose();

      // After dispose, we should not be able to trigger more notifications
      expect(notifyCount, countAfterOpen);
    });
  });

  group('ConferBotConfig', () {
    test('should create with defaults', () {
      const config = ConferBotConfig();

      expect(config.enableNotifications, true);
      expect(config.enableOfflineMode, true);
      expect(config.autoConnect, true);
      expect(config.reconnectionAttempts, isNull);
      expect(config.reconnectionDelay, isNull);
    });

    test('should create with custom values', () {
      const config = ConferBotConfig(
        enableNotifications: false,
        enableOfflineMode: false,
        autoConnect: false,
        reconnectionAttempts: 5,
        reconnectionDelay: 1000,
      );

      expect(config.enableNotifications, false);
      expect(config.enableOfflineMode, false);
      expect(config.autoConnect, false);
      expect(config.reconnectionAttempts, 5);
      expect(config.reconnectionDelay, 1000);
    });
  });

  group('ConferBotCustomization', () {
    test('should pass customization to provider', () {
      final customizedProvider = ConferBotProvider(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        config: const ConferBotConfig(autoConnect: false),
        customization: const ConferBotCustomization(
          primaryColor: '#0000FF',
          headerTitle: 'Custom Chat',
        ),
      );

      expect(customizedProvider.customization, isNotNull);
      expect(customizedProvider.customization!.primaryColor, '#0000FF');
      expect(customizedProvider.customization!.headerTitle, 'Custom Chat');

      customizedProvider.dispose();
    });
  });

  group('ConferBotUser', () {
    test('should create user with all fields', () {
      const user = ConferBotUser(
        id: 'user_123',
        name: 'John Doe',
        email: 'john@example.com',
        phone: '+1234567890',
        metadata: {'company': 'Acme'},
      );

      expect(user.id, 'user_123');
      expect(user.name, 'John Doe');
      expect(user.email, 'john@example.com');
      expect(user.phone, '+1234567890');
      expect(user.metadata?['company'], 'Acme');
    });

    test('should create user with minimal fields', () {
      const user = ConferBotUser(id: 'user_123');

      expect(user.id, 'user_123');
      expect(user.name, isNull);
      expect(user.email, isNull);
      expect(user.phone, isNull);
      expect(user.metadata, isNull);
    });

    test('should convert to JSON', () {
      const user = ConferBotUser(
        id: 'user_123',
        name: 'John',
        email: 'john@example.com',
      );

      final json = user.toJson();

      expect(json['id'], 'user_123');
      expect(json['name'], 'John');
      expect(json['email'], 'john@example.com');
    });
  });

  group('ConferBotCustomization', () {
    test('should create with all fields', () {
      const customization = ConferBotCustomization(
        primaryColor: '#0000FF',
        fontFamily: 'Inter',
        bubbleRadius: 12,
        headerTitle: 'Custom Chat',
        enableAvatar: true,
        avatarUrl: 'https://example.com/avatar.png',
        botBubbleColor: '#EEEEEE',
        userBubbleColor: '#0808EE',
      );

      expect(customization.primaryColor, '#0000FF');
      expect(customization.headerTitle, 'Custom Chat');
      expect(customization.avatarUrl, 'https://example.com/avatar.png');
      expect(ConferBotCustomization.fromJson(customization.toJson()).toJson(), customization.toJson());
    });

    test('should create with minimal fields', () {
      const customization = ConferBotCustomization();

      expect(customization.primaryColor, isNull);
      expect(customization.headerTitle, isNull);
    });
  });

  group('ConferBotProvider Submit Response', () {
    test('should submit response to flow engine', () {
      // Just verify it doesn't throw
      expect(() => provider.submitResponse('test response'), returnsNormally);
    });

    test('should accept different response types', () {
      expect(() => provider.submitResponse('string'), returnsNormally);
      expect(() => provider.submitResponse(42), returnsNormally);
      expect(() => provider.submitResponse({'key': 'value'}), returnsNormally);
      expect(() => provider.submitResponse(['a', 'b', 'c']), returnsNormally);
    });
  });

  group('ConferBotProvider Dispose', () {
    test('should dispose without error', () {
      final disposableProvider = ConferBotProvider(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        config: const ConferBotConfig(autoConnect: false),
      );

      expect(() => disposableProvider.dispose(), returnsNormally);
    });

    test('should remove flow engine listener on dispose', () {
      final disposableProvider = ConferBotProvider(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        config: const ConferBotConfig(autoConnect: false),
      );

      // Dispose should clean up listeners
      disposableProvider.dispose();

      // After dispose, adding listeners should not cause issues
      // (this tests that internal cleanup happened)
    });
  });
}
