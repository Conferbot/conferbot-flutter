import 'package:flutter/foundation.dart';
import '../models/agent.dart';
import '../models/message.dart';
import '../models/socket_events.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/socket_client.dart';
import '../core/node_flow_engine.dart';
import '../core/nodes/node_ui_state.dart';

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
/// Integrates with NodeFlowEngine for handling all 51 node types
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
  late final NodeFlowEngine _flowEngine;

  // State
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isOpen = false;
  String? _chatSessionId;
  String? _visitorId;
  List<RecordItem> _record = [];
  Agent? _currentAgent;
  int _unreadCount = 0;

  // Chatbot flow data
  List<Map<String, dynamic>> _steps = [];
  List<Map<String, dynamic>> _edges = [];

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

    _flowEngine = NodeFlowEngine(socketClient: _socketClient);

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

  /// Flow engine for node processing
  NodeFlowEngine get flowEngine => _flowEngine;

  /// Current UI state from flow engine
  NodeUIState? get currentUIState => _flowEngine.currentUIState;

  /// Whether the engine is processing a node
  bool get isProcessing => _flowEngine.isProcessing;

  /// Flow completion status
  bool get isFlowComplete => _flowEngine.isFlowComplete;

  /// Error message from engine
  String? get errorMessage => _flowEngine.errorMessage;

  /// Initialize the SDK
  Future<void> _initialize() async {
    _socketClient.connect();
    _setupSocketListeners();
    _setupFlowEngineListeners();
    _isInitialized = true;
    notifyListeners();
  }

  /// Setup socket event listeners
  void _setupSocketListeners() {
    // Connection events
    _socketClient.on(SocketEvents.connect, (_) {
      _isConnected = true;
      // Request chatbot data on connection
      _socketClient.getChatbotData();
      notifyListeners();
    });

    _socketClient.on(SocketEvents.disconnect, (_) {
      _isConnected = false;
      notifyListeners();
    });

    // Chatbot data fetched - contains steps and edges for flow
    _socketClient.on(SocketEvents.fetchedChatbotData, (data) {
      if (data != null && data is Map<String, dynamic>) {
        if (kDebugMode) {
          print('[ConferBot] Chatbot data received');
        }
        _handleChatbotData(data);
      }
    });

    // Bot response - incoming node from server
    _socketClient.on(SocketEvents.botResponse, (data) {
      if (data != null && data is Map<String, dynamic>) {
        // Add to record for display
        final message = RecordItem.fromJson(data);
        _record.add(message);
        if (!_isOpen) {
          _unreadCount++;
        }

        // Process through flow engine if it has node data
        if (data['nodeData'] != null) {
          _flowEngine.handleServerMessage(data);
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
        final agentDetails = data['agentDetails'] as Map<String, dynamic>?;
        if (agentDetails != null) {
          _currentAgent = Agent(
            id: agentDetails['_id'] as String,
            name: agentDetails['name'] as String,
            email: agentDetails['email'] as String?,
          );
          // Notify flow engine of agent acceptance
          _flowEngine.handleAgentAccepted(_currentAgent!.name);
          notifyListeners();
        }
      }
    });

    // No agents available
    _socketClient.on(SocketEvents.noAgentsAvailable, (_) {
      _flowEngine.handleNoAgentsAvailable();
      notifyListeners();
    });

    // Agent left
    _socketClient.on(SocketEvents.agentLeft, (_) {
      _currentAgent = null;
      notifyListeners();
    });

    // Chat ended
    _socketClient.on(SocketEvents.chatEnded, (_) {
      _currentAgent = null;
      _flowEngine.handleChatEnded();
      notifyListeners();
    });
  }

  /// Setup flow engine listeners
  void _setupFlowEngineListeners() {
    _flowEngine.addListener(_onFlowEngineChange);
  }

  /// Handle flow engine state changes
  void _onFlowEngineChange() {
    notifyListeners();
  }

  /// Handle incoming chatbot data (steps and edges)
  void _handleChatbotData(Map<String, dynamic> data) {
    final chatbotData = data['chatbotData'] as Map<String, dynamic>?;
    if (chatbotData != null) {
      // Extract steps (nodes) and edges from chatbot data
      final stepsData = chatbotData['steps'] as List<dynamic>?;
      final edgesData = chatbotData['edges'] as List<dynamic>?;

      if (stepsData != null) {
        _steps = stepsData.map((s) => Map<String, dynamic>.from(s as Map)).toList();
      }
      if (edgesData != null) {
        _edges = edgesData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      if (kDebugMode) {
        print('[ConferBot] Loaded ${_steps.length} steps and ${_edges.length} edges');
      }
    }
  }

  /// Open chat and start the flow
  Future<void> openChat() async {
    if (_chatSessionId == null) {
      // Try to initialize session via REST API
      try {
        final response = await _apiClient.initSession(userId: user?.id ?? _visitorId);
        if (response.success && response.data != null) {
          _chatSessionId = response.data!.chatSessionId;
          _visitorId = response.data!.visitorId ?? _visitorId;
          _record = response.data!.record;

          // Load steps and edges if provided in session
          if (response.data!.steps != null) {
            _steps = response.data!.steps!;
          }
          if (response.data!.edges != null) {
            _edges = response.data!.edges!;
          }
        }
      } catch (e) {
        // REST API not available, generate local session ID
        _chatSessionId = 'mobile_${DateTime.now().millisecondsSinceEpoch}';
        _visitorId = 'visitor_${DateTime.now().millisecondsSinceEpoch}';
        if (kDebugMode) {
          print('[ConferBot] Using local session ID: $_chatSessionId');
        }
      }

      // Join chat room via socket
      if (_chatSessionId != null) {
        _socketClient.joinChatRoomVisitor(_chatSessionId!);
      }

      // Initialize and start the flow engine
      if (_steps.isNotEmpty) {
        _flowEngine.initialize(
          chatSessionId: _chatSessionId!,
          visitorId: _visitorId ?? '',
          botId: botId,
          stepsData: _steps,
          edgesData: _edges,
        );
        _flowEngine.start();
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

  /// Submit response for current interactive node
  void submitResponse(dynamic response) {
    _flowEngine.submitResponse(response);
  }

  /// Send text message (legacy fallback for simple text input)
  Future<void> sendMessage(String text) async {
    if (_chatSessionId == null || text.trim().isEmpty) {
      return;
    }

    // If flow engine has a current node, submit as response
    if (_flowEngine.currentNodeId != null) {
      submitResponse(text);
      return;
    }

    // Legacy fallback: direct socket message
    final userMessage = UserInputResponseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      time: DateTime.now(),
      text: text,
    );

    _record.add(userMessage);
    notifyListeners();

    _socketClient.sendResponseRecord(
      chatSessionId: _chatSessionId!,
      record: _record.map((r) => r.toJson()).toList(),
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

  /// Clear current error
  void clearError() {
    _flowEngine.clearError();
  }

  /// Reset conversation and start fresh
  void resetConversation() {
    _flowEngine.reset();
    _record.clear();
    _chatSessionId = null;
    _currentAgent = null;
    notifyListeners();
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
    _flowEngine.removeListener(_onFlowEngineChange);
    if (_chatSessionId != null) {
      _socketClient.leaveChatRoom(_chatSessionId!);
    }
    _flowEngine.dispose();
    _socketClient.dispose();
    _apiClient.dispose();
    super.dispose();
  }
}
