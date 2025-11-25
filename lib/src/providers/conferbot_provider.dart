import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/agent.dart';
import '../models/chat_session.dart';
import '../models/message.dart';
import '../models/socket_events.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/socket_client.dart';

/// ConferBot provider configuration
class ConferBotConfig {
  final bool enableNotifications;
  final bool enableOfflineMode;
  final bool autoConnect;
  final int? reconnectionAttempts;
  final int? reconnectionDelay;

  const ConferBotConfig({
    this.enableNotifications = true,
    this.enableOfflineMode = true,
    this.autoConnect = true,
    this.reconnectionAttempts,
    this.reconnectionDelay,
  });
}

/// ConferBot provider for state management
class ConferBotProvider with ChangeNotifier {
  final String apiKey;
  final String botId;
  final ConferBotConfig config;
  final ConferBotCustomization? customization;
  final ConferBotUser? user;
  final String? baseUrl;
  final String? socketUrl;

  late final ApiClient _apiClient;
  late final SocketClient _socketClient;

  // State
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isOpen = false;
  String? _chatSessionId;
  String? _visitorId;
  List<RecordItem> _record = [];
  Agent? _currentAgent;
  int _unreadCount = 0;

  ConferBotProvider({
    required this.apiKey,
    required this.botId,
    this.config = const ConferBotConfig(),
    this.customization,
    this.user,
    this.baseUrl,
    this.socketUrl,
  }) {
    _apiClient = ApiClient(
      apiKey: apiKey,
      botId: botId,
      baseUrl: baseUrl ?? 'https://embed.conferbot.com/api/v1/mobile',
    );

    _socketClient = SocketClient(
      apiKey: apiKey,
      botId: botId,
      socketUrl: socketUrl ?? 'https://embed.conferbot.com',
    );

    if (config.autoConnect) {
      _initialize();
    }
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isOpen => _isOpen;
  String? get chatSessionId => _chatSessionId;
  String? get visitorId => _visitorId;
  List<RecordItem> get record => List.unmodifiable(_record);
  Agent? get currentAgent => _currentAgent;
  int get unreadCount => _unreadCount;

  /// Initialize the SDK
  Future<void> _initialize() async {
    _socketClient.connect();
    _setupSocketListeners();
    _isInitialized = true;
    notifyListeners();
  }

  /// Setup socket event listeners
  void _setupSocketListeners() {
    // Connection events
    _socketClient.on(SocketEvents.connect, (_) {
      _isConnected = true;
      notifyListeners();
    });

    _socketClient.on(SocketEvents.disconnect, (_) {
      _isConnected = false;
      notifyListeners();
    });

    // Bot response
    _socketClient.on(SocketEvents.botResponse, (data) {
      if (data != null && data is Map<String, dynamic>) {
        final message = RecordItem.fromJson(data);
        _record.add(message);
        if (!_isOpen) {
          _unreadCount++;
        }
        notifyListeners();
      }
    });

    // Agent message
    _socketClient.on(SocketEvents.agentMessage, (data) {
      if (data != null && data is Map<String, dynamic>) {
        final message = RecordItem.fromJson(data);
        _record.add(message);
        if (!_isOpen) {
          _unreadCount++;
        }
        notifyListeners();
      }
    });

    // Agent accepted handover
    _socketClient.on(SocketEvents.agentAccepted, (data) {
      if (data != null && data is Map<String, dynamic>) {
        final agentData = data['agent'] as Map<String, dynamic>?;
        if (agentData != null) {
          _currentAgent = Agent.fromJson(agentData);
          notifyListeners();
        }
      }
    });

    // Agent left
    _socketClient.on(SocketEvents.agentLeft, (_) {
      _currentAgent = null;
      notifyListeners();
    });

    // Chat ended
    _socketClient.on(SocketEvents.chatEnded, (_) {
      _currentAgent = null;
      notifyListeners();
    });
  }

  /// Open chat
  Future<void> openChat() async {
    if (_chatSessionId == null) {
      // Initialize new session
      final response = await _apiClient.initSession(userId: user?.id ?? _visitorId);
      if (response.success && response.data != null) {
        _chatSessionId = response.data!.chatSessionId;
        _record = response.data!.record;

        // Join chat room via socket
        _socketClient.joinChatRoom(_chatSessionId!);

        // Initialize mobile session
        _socketClient.mobileInit(
          chatSessionId: _chatSessionId!,
          visitorId: user?.id ?? _visitorId,
          deviceInfo: {
            'platform': Platform.operatingSystem,
            'version': Platform.operatingSystemVersion,
          },
        );
      }
    }

    _isOpen = true;
    _unreadCount = 0;
    notifyListeners();
  }

  /// Close chat
  void closeChat() {
    _isOpen = false;
    notifyListeners();
  }

  /// Send message
  Future<void> sendMessage(String text) async {
    if (_chatSessionId == null || text.trim().isEmpty) {
      return;
    }

    // Create user message
    final userMessage = UserMessageRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      time: DateTime.now(),
      text: text,
    );

    // Add to record optimistically
    _record.add(userMessage);
    notifyListeners();

    // Send via socket
    _socketClient.sendVisitorMessage(
      chatSessionId: _chatSessionId!,
      record: userMessage.toJson(),
      answerVariables: [],
    );
  }

  /// Register push notification token
  Future<void> registerPushToken(String token) async {
    if (_chatSessionId == null) {
      return;
    }

    await _apiClient.registerPushToken(
      token: token,
      chatSessionId: _chatSessionId!,
    );
  }

  /// Initiate handover to live agent
  void initiateHandover({String? message}) {
    if (_chatSessionId == null) {
      return;
    }

    _socketClient.initiateHandover(
      chatSessionId: _chatSessionId!,
      message: message,
    );
  }

  /// Send typing status
  void sendTypingStatus(bool isTyping) {
    if (_chatSessionId == null) {
      return;
    }

    _socketClient.sendTypingStatus(
      chatSessionId: _chatSessionId!,
      isTyping: isTyping,
    );
  }

  /// Listen to custom socket event
  void on(String event, Function(dynamic) callback) {
    _socketClient.on(event, callback);
  }

  /// Remove socket event listener
  void off(String event, [Function(dynamic)? callback]) {
    _socketClient.off(event, callback);
  }

  @override
  void dispose() {
    if (_chatSessionId != null) {
      _socketClient.leaveChatRoom(_chatSessionId!);
    }
    _socketClient.dispose();
    _apiClient.dispose();
    super.dispose();
  }
}
