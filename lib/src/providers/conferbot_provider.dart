import 'package:flutter/foundation.dart';
import '../core/state/chat_state.dart';
import '../models/agent.dart';
import '../models/message.dart';
import '../models/socket_events.dart';
import '../models/user.dart';
import '../models/analytics.dart';
import '../services/api_client.dart';
import '../services/socket_client.dart';
import '../services/storage_service.dart';
import '../core/node_flow_engine.dart';
import '../core/nodes/node_ui_state.dart';
import '../core/state/message_pagination_controller.dart';
import '../core/state/message_storage_service.dart';
import '../utils/logger.dart';
import 'analytics_provider.dart';

/// ConferBot provider configuration
class ConferBotConfig {
  final bool enableNotifications;
  final bool enableOfflineMode;
  final bool autoConnect;
  final int? reconnectionAttempts;
  final int? reconnectionDelay;

  /// Whether to enable message pagination
  final bool enablePagination;

  /// Configuration for pagination
  final PaginationConfig? paginationConfig;

  /// Whether to enable analytics tracking
  final bool enableAnalytics;

  /// Interval for flushing analytics to server (default: 30 seconds)
  final Duration analyticsFlushInterval;

  /// Whether to enable session persistence (survives app restart)
  final bool enablePersistence;

  /// Session timeout duration (default: 30 minutes like web widget)
  /// After this timeout, a new session will be started but visitor ID is preserved
  final Duration sessionTimeout;

  const ConferBotConfig({
    this.enableNotifications = true,
    this.enableOfflineMode = true,
    this.autoConnect = true,
    this.reconnectionAttempts,
    this.reconnectionDelay,
    this.enablePagination = true,
    this.paginationConfig,
    this.enableAnalytics = true,
    this.analyticsFlushInterval = const Duration(seconds: 30),
    this.enablePersistence = true,
    this.sessionTimeout = const Duration(minutes: 30),
  });
}

/// ConferBot provider for state management
/// Integrates with NodeFlowEngine for handling all 51 node types
/// Includes:
/// - Pagination support for efficient message handling
/// - Comprehensive analytics tracking
/// - Session persistence via Hive (30 minute timeout like web widget)
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

  // Pagination controller
  MessagePaginationController? _paginationController;
  MessageStorageService? _storageService;

  // Analytics provider
  AnalyticsProvider? _analyticsProvider;

  // State
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isOpen = false;
  String? _chatSessionId;
  String? _visitorId;
  List<RecordItem> _record = [];
  Agent? _currentAgent;
  int _unreadCount = 0;

  // Session persistence state
  bool _sessionRestored = false;
  bool _isPersistenceReady = false;

  // Chatbot flow data
  List<Map<String, dynamic>> _steps = [];
  List<Map<String, dynamic>> _edges = [];

  /// Scoped logger for this provider
  static final _logger = ConferBotLogger.scoped('ConferBotProvider');

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

  /// Whether a previous session was restored from persistence
  bool get sessionRestored => _sessionRestored;

  /// Whether persistence system is ready
  bool get isPersistenceReady => _isPersistenceReady;

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

  // ========== Pagination Getters ==========

  /// Get paginated messages (visible messages from pagination controller)
  List<RecordItem> get paginatedMessages =>
      _paginationController?.state.visibleMessages ?? [];

  /// Check if there are more messages to load
  bool get hasMoreMessages =>
      _paginationController?.state.hasMoreMessages ?? false;

  /// Check if currently loading more messages
  bool get isLoadingMoreMessages =>
      _paginationController?.state.isLoadingMore ?? false;

  /// Get total message count
  int get totalMessageCount =>
      _paginationController?.state.totalMessages ?? _record.length;

  /// Get current page
  int get currentMessagePage =>
      _paginationController?.state.currentPage ?? 0;

  /// Pagination controller (for direct access if needed)
  MessagePaginationController? get paginationController => _paginationController;

  // ========== Analytics Getters ==========

  /// Analytics provider for direct access
  AnalyticsProvider? get analyticsProvider => _analyticsProvider;

  /// Current session analytics
  ChatAnalytics? get sessionAnalytics => _analyticsProvider?.currentAnalytics;

  /// Whether analytics is active
  bool get isAnalyticsActive => _analyticsProvider?.isInitialized ?? false;

  /// Number of queued analytics events (for offline tracking)
  int get queuedAnalyticsEventCount =>
      _analyticsProvider?.queuedEventCount ?? 0;

  // ========== Initialization ==========

  /// Initialize the SDK
  Future<void> _initialize() async {
    // Initialize persistence first if enabled
    if (config.enablePersistence) {
      await _initializeSessionPersistence();
    }

    _socketClient.connect();
    _setupSocketListeners();
    _setupFlowEngineListeners();

    // Initialize pagination if enabled
    if (config.enablePagination) {
      await _initializePagination();
    }

    // Initialize analytics if enabled
    if (config.enableAnalytics) {
      await _initializeAnalytics();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Initialize session persistence (Hive-based storage for full session state)
  Future<void> _initializeSessionPersistence() async {
    try {
      // Ensure storage service is initialized
      if (!StorageService.instance.isInitialized) {
        await StorageService.init();
      }

      _isPersistenceReady = true;

      // Enable persistence on ChatState
      ChatState.instance.enablePersistence();

      // Try to restore previous session
      _sessionRestored = await ChatState.instance.restoreFromPersistence(botId);

      if (_sessionRestored) {
        // Restore provider state from ChatState
        _chatSessionId = ChatState.instance.chatSessionId;
        _visitorId = ChatState.instance.visitorId;

        _logger.info('Session restored from persistence');
        _logger.debug('Chat session ID: $_chatSessionId');
        _logger.debug('Visitor ID: $_visitorId');
      } else {
        // No valid session, but we might have a visitor ID
        final savedVisitorId = await StorageService.instance.getVisitorId();
        if (savedVisitorId != null) {
          _visitorId = savedVisitorId;
          _logger.debug('Using saved visitor ID: $_visitorId');
        }
      }

      // Cleanup expired sessions periodically
      await StorageService.instance.cleanupExpiredSessions(
        timeout: config.sessionTimeout,
      );
    } catch (e, stack) {
      _logger.error('Error initializing persistence', e, stack);
      _isPersistenceReady = false;
    }
  }

  /// Initialize pagination controller and storage
  Future<void> _initializePagination() async {
    final effectiveConfig = config.paginationConfig ?? const PaginationConfig(
      pageSize: 50,
      maxInMemory: 150,
      enablePersistence: true,
    );

    // Create storage service
    if (effectiveConfig.enablePersistence) {
      _storageService = await MessageStorageFactory.createDefault(
        enablePersistence: true,
      );
    } else {
      _storageService = MessageStorageFactory.createInMemory();
    }

    _paginationController = MessagePaginationController(
      config: effectiveConfig,
      storageService: _storageService,
    );

    _paginationController!.addListener(_onPaginationChange);
  }

  /// Initialize analytics provider
  Future<void> _initializeAnalytics() async {
    _analyticsProvider = AnalyticsProvider(
      socketClient: _socketClient,
      flushInterval: config.analyticsFlushInterval,
    );

    await _analyticsProvider!.initialize(_socketClient);

    _analyticsProvider!.addListener(_onAnalyticsChange);

    _logger.info('Analytics initialized');
  }

  void _onPaginationChange() {
    notifyListeners();
  }

  void _onAnalyticsChange() {
    notifyListeners();
  }

  /// Setup socket event listeners
  void _setupSocketListeners() {
    // Connection events
    _socketClient.on(SocketEvents.connect, (_) {
      _isConnected = true;

      // Update analytics online status
      _analyticsProvider?.setOnlineStatus(true);

      // Request chatbot data on connection
      _socketClient.getChatbotData();
      notifyListeners();
    });

    _socketClient.on(SocketEvents.disconnect, (_) {
      _isConnected = false;

      // Update analytics online status
      _analyticsProvider?.setOnlineStatus(false);

      // Persist state when disconnected
      if (config.enablePersistence) {
        ChatState.instance.persistNow();
      }

      notifyListeners();
    });

    // Chatbot data fetched - contains steps and edges for flow
    _socketClient.on(SocketEvents.fetchedChatbotData, (data) {
      if (data != null && data is Map<String, dynamic>) {
        _logger.debug('Chatbot data received');
        _handleChatbotData(data);
      }
    });

    // Bot response - incoming node from server
    _socketClient.on(SocketEvents.botResponse, (data) {
      if (data != null && data is Map<String, dynamic>) {
        // Add to record for display
        final message = RecordItem.fromJson(data);
        _addMessageToRecord(message);

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
        _addMessageToRecord(message);

        // Track agent message in analytics
        if (message is AgentMessageRecord) {
          _analyticsProvider?.trackMessage(
            sender: 'agent',
            text: message.text,
          );
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

  /// Add message to record with pagination support
  void _addMessageToRecord(RecordItem message) {
    _record.add(message);
    if (!_isOpen) {
      _unreadCount++;
    }

    // Also add to pagination controller if available
    if (_paginationController != null) {
      _paginationController!.addMessage(message);
    }
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

      _logger.debug('Loaded ${_steps.length} steps and ${_edges.length} edges');
    }
  }

  /// Open chat and start the flow
  /// If a previous session was restored, it will resume from where it left off
  Future<void> openChat() async {
    // Check if we have a restored session that we can resume
    if (_sessionRestored && _chatSessionId != null) {
      _logger.info('Resuming restored session: $_chatSessionId');

      // Join chat room with existing session
      _socketClient.joinChatRoomVisitor(_chatSessionId!);

      // Initialize pagination with restored session
      if (_paginationController != null) {
        await _paginationController!.initialize(_chatSessionId!);
      }

      // If we have steps, resume the flow engine
      if (_steps.isNotEmpty) {
        _flowEngine.initialize(
          chatSessionId: _chatSessionId!,
          visitorId: _visitorId ?? '',
          botId: botId,
          stepsData: _steps,
          edgesData: _edges,
        );

        // Resume from saved node if available
        final savedNodeId = ChatState.instance.currentNodeId;
        if (savedNodeId != null) {
          _flowEngine.resumeFromNode(savedNodeId);
        } else {
          _flowEngine.start();
        }
      }

      _isOpen = true;
      _unreadCount = 0;
      notifyListeners();
      return;
    }

    // No restored session - start fresh
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

          // Initialize pagination with existing messages
          if (_paginationController != null && _chatSessionId != null) {
            await _paginationController!.initialize(_chatSessionId!);
            await _paginationController!.loadFromList(_record);
          }
        }
      } catch (e) {
        // REST API not available, generate local session ID
        _chatSessionId = 'mobile_${DateTime.now().millisecondsSinceEpoch}';
        if (_visitorId == null) {
          // Generate new visitor ID if we don't have one
          _visitorId = await StorageService.instance.getOrCreateVisitorId();
        }
        _logger.debug('Using local session ID: $_chatSessionId');

        // Initialize pagination with empty state
        if (_paginationController != null && _chatSessionId != null) {
          await _paginationController!.initialize(_chatSessionId!);
        }
      }

      // Initialize ChatState with session info for persistence
      ChatState.instance.initialize(
        chatSessionId: _chatSessionId!,
        visitorId: _visitorId ?? '',
        botId: botId,
      );

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

    // Track potential drop-off when closing chat mid-flow
    if (!_flowEngine.isFlowComplete && _analyticsProvider != null) {
      _analyticsProvider!.trackDropOff(reason: 'chat_closed');
    }

    // Persist state when chat is closed
    if (config.enablePersistence) {
      ChatState.instance.persistNow();
    }

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

    _addMessageToRecord(userMessage);
    notifyListeners();

    _socketClient.sendResponseRecord(
      chatSessionId: _chatSessionId!,
      record: _record.map((r) => r.toJson()).toList(),
      answerVariables: [],
    );
  }

  // ========== Pagination Methods ==========

  /// Load more (older) messages
  Future<void> loadMoreMessages() async {
    if (_paginationController != null) {
      await _paginationController!.loadMoreMessages();
    }
  }

  /// Trim older messages from memory (call when scrolling to bottom)
  void trimOlderMessages() {
    _paginationController?.trimOlderMessages();
  }

  /// Refresh messages (reload from storage)
  Future<void> refreshMessages() async {
    if (_paginationController != null && _chatSessionId != null) {
      await _paginationController!.initialize(_chatSessionId!);
    }
  }

  /// Clear all messages from pagination
  Future<void> clearMessages() async {
    if (_paginationController != null) {
      await _paginationController!.clearMessages();
    }
    _record.clear();
    notifyListeners();
  }

  // ========== Session Persistence Methods ==========

  /// Force persist current state
  /// Useful for calling before app goes to background
  Future<void> persistState() async {
    if (config.enablePersistence) {
      await ChatState.instance.persistNow();
    }
  }

  /// Clear all persisted session data
  Future<void> clearAllPersistedData() async {
    if (StorageService.instance.isInitialized) {
      await StorageService.instance.clearAllSessions();
    }
    ChatState.instance.reset(clearPersistence: true);
    _sessionRestored = false;
  }

  /// Clear current session but keep visitor ID
  Future<void> clearCurrentSession() async {
    if (StorageService.instance.isInitialized) {
      await StorageService.instance.clearSession(botId);
    }
    ChatState.instance.resetKeepingVisitor(clearPersistence: true);
    _sessionRestored = false;
  }

  /// Get storage statistics for debugging
  Map<String, dynamic> getStorageStats() {
    if (!StorageService.instance.isInitialized) {
      return {'error': 'Storage not initialized'};
    }
    return StorageService.instance.getStats();
  }

  // ========== Analytics Methods ==========

  /// Track a custom interaction event
  void trackInteraction({
    required String type,
    Map<String, dynamic>? data,
  }) {
    _analyticsProvider?.trackInteraction(type: type, data: data);
  }

  /// Track goal completion
  void trackGoalCompletion({
    required String goalId,
    String? conversionEvent,
    double? conversionValue,
  }) {
    _analyticsProvider?.trackGoalCompletion(
      goalId: goalId,
      conversionEvent: conversionEvent,
      conversionValue: conversionValue,
    );
  }

  /// Submit chat rating
  void submitChatRating({
    int? csatScore,
    String? feedback,
    bool? thumbsUp,
    int? npsScore,
    String source = 'post_chat_survey',
  }) {
    _analyticsProvider?.submitRating(
      csatScore: csatScore,
      feedback: feedback,
      thumbsUp: thumbsUp,
      npsScore: npsScore,
      source: source,
    );
  }

  /// Track typing start (call when user starts typing)
  void trackTypingStart() {
    _analyticsProvider?.trackTypingStart();
  }

  /// Track typing end (call when user stops typing or sends message)
  void trackTypingEnd() {
    _analyticsProvider?.trackTypingEnd();
  }

  /// Track text deletion (call on backspace/delete)
  void trackDeletion() {
    _analyticsProvider?.trackDeletion();
  }

  /// Force flush analytics to server
  Future<void> flushAnalytics() async {
    await _analyticsProvider?.forceFlush();
  }

  /// Get current session analytics data
  Map<String, dynamic>? getAnalyticsData() {
    return _analyticsProvider?.currentAnalytics?.toJson();
  }

  // ========== Other Methods ==========

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

    // Track handover initiation
    _analyticsProvider?.trackInteraction(
      type: 'handover_initiated',
      data: {'hasMessage': message != null},
    );

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

    // Track typing behavior
    if (isTyping) {
      _analyticsProvider?.trackTypingStart();
    } else {
      _analyticsProvider?.trackTypingEnd();
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
  /// Set clearPersistence to true to also clear stored session data
  void resetConversation({bool clearPersistence = true}) {
    // End analytics session before reset
    _analyticsProvider?.endSession();

    _flowEngine.reset();
    _record.clear();
    _chatSessionId = null;
    _currentAgent = null;
    _sessionRestored = false;
    _paginationController?.reset();

    // Reset ChatState (optionally clearing persistence)
    ChatState.instance.resetKeepingVisitor(clearPersistence: clearPersistence);

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
    // Persist state before disposing
    if (config.enablePersistence) {
      ChatState.instance.persistNow();
    }

    _flowEngine.removeListener(_onFlowEngineChange);
    _paginationController?.removeListener(_onPaginationChange);
    _analyticsProvider?.removeListener(_onAnalyticsChange);

    if (_chatSessionId != null) {
      _socketClient.leaveChatRoom(_chatSessionId!);
    }

    _flowEngine.dispose();
    _socketClient.dispose();
    _apiClient.dispose();
    _paginationController?.dispose();
    _storageService?.dispose();
    _analyticsProvider?.dispose();

    super.dispose();
  }
}
