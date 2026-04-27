import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../core/state/chat_state.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import '../models/agent.dart';
import '../models/message.dart';
import '../models/socket_events.dart';
import '../models/user.dart';
import '../models/analytics.dart';
import '../config/constants.dart';
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

  // Live chat state
  bool _isLiveChatMode = false;
  bool _agentTyping = false;

  // Chatbot flow data
  List<Map<String, dynamic>> _steps = [];
  List<Map<String, dynamic>> _edges = [];
  Map<String, dynamic>? _serverCustomizations;

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
      baseUrl: baseUrl ?? ConferBotEndpoints.apiBaseUrl,
    );

    _socketClient = SocketClient(
      apiKey: apiKey,
      botId: botId,
      socketUrl: socketUrl ?? ConferBotEndpoints.socketUrl,
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

  /// Server customizations (theme, bot name, avatar, etc.)
  Map<String, dynamic>? get serverCustomizations => _serverCustomizations;

  /// Bot name from server customizations
  String? get botName {
    final name = _serverCustomizations?['botName']?.toString();
    if (name != null && name.isNotEmpty) return name;
    final logoText = _serverCustomizations?['logoText']?.toString();
    if (logoText != null && logoText.isNotEmpty) return logoText;
    return null;
  }

  /// Bot avatar URL from server customizations
  String? get botAvatarUrl {
    final avatar = _serverCustomizations?['avatar']?.toString();
    if (avatar != null && avatar.isNotEmpty) return avatar;
    final logoUrl = _serverCustomizations?['logo']?.toString();
    if (logoUrl != null && logoUrl.isNotEmpty) return logoUrl;
    return null;
  }

  /// Build a ConferBotTheme from server customizations
  ConferBotTheme get serverTheme => _buildServerTheme();

  /// Whether the conversation is in live chat mode (agent connected)
  bool get isLiveChatMode => _isLiveChatMode;

  /// Whether the connected agent is currently typing
  bool get agentTyping => _agentTyping;

  /// Whether a previous session was restored from persistence
  bool get sessionRestored => _sessionRestored;

  /// Whether persistence system is ready
  bool get isPersistenceReady => _isPersistenceReady;

  /// Flow engine for node processing
  NodeFlowEngine get flowEngine => _flowEngine;

  /// Current UI state from flow engine
  dynamic get currentUIState => _flowEngine.currentUIState;

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

    await _socketClient.connect();
    _logger.debug('Socket connect() returned, registering listeners...');
    _setupSocketListeners();
    _setupFlowEngineListeners();

    // Explicitly request chatbot data after connection setup
    // (handles race condition where connect event fires before listeners are registered)
    if (_socketClient.isConnected) {
      _socketClient.getChatbotData();
    }

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
      _logger.debug('fetchedChatbotData event received, data type: ${data.runtimeType}');
      if (data != null && data is Map<String, dynamic>) {
        _logger.debug('Chatbot data received with ${data.keys.length} keys');
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
    // Server sends: { message, agentDetails, isFileInput, isAudioInput, agentMessageId }
    _socketClient.on(SocketEvents.agentMessage, (data) {
      if (data != null && data is Map<String, dynamic>) {
        final agentDetailsRaw = data['agentDetails'] as Map<String, dynamic>?;
        // Strip HTML tags from agent messages (admin sends via rich text editor with <p> tags)
        final rawMessageText = data['message']?.toString() ?? '';
        final messageText = rawMessageText
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .trim();
        final isFileInput = data['isFileInput'] as bool? ?? false;
        final isAudioInput = data['isAudioInput'] as bool? ?? false;
        final agentMessageId = data['agentMessageId']?.toString()
            ?? 'agent_msg_${DateTime.now().millisecondsSinceEpoch}';

        final agentDetails = agentDetailsRaw != null
            ? AgentDetails.fromJson(agentDetailsRaw)
            : AgentDetails(
                id: _currentAgent?.id ?? '',
                name: _currentAgent?.name ?? 'Agent',
                email: _currentAgent?.email ?? '',
              );

        RecordItem message;
        if (isFileInput) {
          message = AgentMessageFileRecord(
            id: agentMessageId,
            time: DateTime.now(),
            file: messageText,
            agentDetails: agentDetails,
          );
        } else if (isAudioInput) {
          message = AgentMessageAudioRecord(
            id: agentMessageId,
            time: DateTime.now(),
            url: messageText,
            agentDetails: agentDetails,
          );
        } else {
          message = AgentMessageRecord(
            id: agentMessageId,
            time: DateTime.now(),
            text: messageText,
            agentDetails: agentDetails,
          );
        }

        _addMessageToRecord(message);

        // Add to record in ChatState
        ChatState.instance.pushToRecord(RecordEntry(
          id: agentMessageId,
          shape: 'agent-message',
          type: 'agent-message',
          text: messageText,
          data: {
            'agentDetails': agentDetailsRaw ?? agentDetails.toJson(),
            if (isFileInput) 'isFileInput': true,
            if (isAudioInput) 'isAudioInput': true,
          },
        ));

        // Add to transcript
        ChatState.instance.addToTranscript('agent', messageText);

        // Clear agent typing indicator
        _agentTyping = false;

        // Track agent message in analytics
        _analyticsProvider?.trackMessage(
          sender: 'agent',
          text: messageText,
        );

        notifyListeners();
      }
    });

    // Agent accepted handover
    _socketClient.on(SocketEvents.agentAccepted, (data) {
      if (data != null && data is Map<String, dynamic>) {
        final agentDetails = data['agentDetails'] as Map<String, dynamic>?;
        if (agentDetails != null) {
          final agentName = agentDetails['name']?.toString() ?? 'Agent';
          _currentAgent = Agent(
            id: agentDetails['_id']?.toString() ?? '',
            name: agentName,
            email: agentDetails['email'] as String?,
          );

          // Set live chat mode
          _isLiveChatMode = true;
          ChatState.instance.setLiveChatMode(true);

          // Add system message "{agent name} has joined the chat"
          final joinMessageId = 'agent_joined_${DateTime.now().millisecondsSinceEpoch}';
          final systemMessage = SystemMessageRecord(
            id: joinMessageId,
            time: DateTime.now(),
            text: '$agentName has joined the chat',
          );
          _addMessageToRecord(systemMessage);

          // Add to ChatState record
          ChatState.instance.pushToRecord(RecordEntry(
            id: joinMessageId,
            shape: 'agent-joined-message',
            type: 'agent-joined-message',
            data: {
              'name': agentName,
              'agentDetails': agentDetails,
            },
          ));

          // Add to transcript
          ChatState.instance.addToTranscript('bot', '$agentName has joined the chat');

          // Notify flow engine of agent acceptance
          _flowEngine.handleAgentAccepted(agentName);
          notifyListeners();
        }
      }
    });

    // No agents available
    _socketClient.on(SocketEvents.noAgentsAvailable, (_) {
      // Add system message
      final msgId = 'no_agents_${DateTime.now().millisecondsSinceEpoch}';
      final systemMessage = SystemMessageRecord(
        id: msgId,
        time: DateTime.now(),
        text: 'No agents are available at the moment. Please try again later.',
      );
      _addMessageToRecord(systemMessage);

      // Add to ChatState record
      ChatState.instance.pushToRecord(RecordEntry(
        id: msgId,
        shape: 'system-message',
        type: 'no-agents-available',
        text: 'No agents are available at the moment. Please try again later.',
      ));

      _flowEngine.handleNoAgentsAvailable();
      notifyListeners();
    });

    // Agent left
    _socketClient.on(SocketEvents.agentLeft, (data) {
      final agentName = _currentAgent?.name ?? 'Agent';

      // Add system message "{agent name} has left the chat"
      final msgId = 'agent_left_${DateTime.now().millisecondsSinceEpoch}';
      final systemMessage = SystemMessageRecord(
        id: msgId,
        time: DateTime.now(),
        text: '$agentName has left the chat',
      );
      _addMessageToRecord(systemMessage);

      // Add to ChatState record
      ChatState.instance.pushToRecord(RecordEntry(
        id: msgId,
        shape: 'agent-left-chat',
        type: 'agent-left-chat',
        text: '$agentName has left the chat',
      ));

      // Add to transcript
      ChatState.instance.addToTranscript('bot', '$agentName has left the chat');

      _currentAgent = null;
      _agentTyping = false;
      notifyListeners();
    });

    // Chat ended
    _socketClient.on(SocketEvents.chatEnded, (_) {
      // Add system message "Chat has ended"
      final msgId = 'chat_ended_${DateTime.now().millisecondsSinceEpoch}';
      final systemMessage = SystemMessageRecord(
        id: msgId,
        time: DateTime.now(),
        text: 'Chat has ended',
      );
      _addMessageToRecord(systemMessage);

      // Add to ChatState record
      ChatState.instance.pushToRecord(RecordEntry(
        id: msgId,
        shape: 'system-message',
        type: 'chat-ended',
        text: 'Chat has ended',
      ));

      // Add to transcript
      ChatState.instance.addToTranscript('bot', 'Chat has ended');

      // Clear agent state and live chat mode
      _currentAgent = null;
      _isLiveChatMode = false;
      _agentTyping = false;
      ChatState.instance.setLiveChatMode(false);

      _flowEngine.handleChatEnded();
      notifyListeners();
    });

    // Agent typing status
    _socketClient.on(SocketEvents.agentTypingStatus, (data) {
      if (data != null && data is Map<String, dynamic>) {
        _agentTyping = data['isTyping'] as bool? ?? false;
        ChatState.instance.setAgentTyping(_agentTyping);
        notifyListeners();
      }
    });
  }

  /// Add message to record with pagination support and deduplication
  void _addMessageToRecord(RecordItem message) {
    // HIGH FIX 4: Deduplication by message ID
    if (_record.any((m) => m.id == message.id)) {
      _logger.debug('Skipping duplicate message: ${message.id}');
      return;
    }

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

    // Listen for bot messages from flow engine to add to chat record
    _flowEngine.botMessageStream.listen((messageData) {
      final text = messageData['text'] as String? ?? '';
      final nodeId = messageData['nodeId'] as String? ?? '';
      if (text.isNotEmpty) {
        final botMessage = BotMessageRecord(
          id: 'bot_${nodeId}_${DateTime.now().millisecondsSinceEpoch}',
          time: DateTime.now(),
          text: text,
        );
        _addMessageToRecord(botMessage);
        _logger.debug('Added bot message to record: "$text"');
        notifyListeners();
      }
    });

    // Listen for user messages from flow engine (choice selections, form inputs, etc.)
    _flowEngine.userMessageStream.listen((messageData) {
      final text = messageData['text'] as String? ?? '';
      final nodeId = messageData['nodeId'] as String? ?? '';
      if (text.isNotEmpty) {
        final userMessage = UserInputResponseRecord(
          id: 'user_${nodeId}_${DateTime.now().millisecondsSinceEpoch}',
          time: DateTime.now(),
          text: text,
        );
        _addMessageToRecord(userMessage);
        _logger.debug('Added user message to record: "$text"');
        notifyListeners();
      }
    });
  }

  /// Handle flow engine state changes
  void _onFlowEngineChange() {
    notifyListeners();
  }

  /// Handle incoming chatbot data (steps and edges)
  void _handleChatbotData(Map<String, dynamic> data) {
    final chatbotData = data['chatbotData'] as Map<String, dynamic>?;
    if (chatbotData != null) {
      // Server sends: { elements: [{ nodes: [...], edges: [...] }], customizations: {...}, ... }
      final elements = chatbotData['elements'] as List<dynamic>?;
      if (elements != null && elements.isNotEmpty) {
        final firstElement = elements[0] as Map<String, dynamic>;
        final nodesData = firstElement['nodes'] as List<dynamic>?;
        final edgesData = firstElement['edges'] as List<dynamic>?;

        if (nodesData != null) {
          _steps = nodesData.map((s) => Map<String, dynamic>.from(s as Map)).toList();
        }
        if (edgesData != null) {
          _edges = edgesData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }

      // Parse server customizations (theme colors, bot name, etc.)
      _serverCustomizations = chatbotData['customizations'] as Map<String, dynamic>?;
      if (_serverCustomizations != null) {
        _logger.debug('Server customizations: ${_serverCustomizations!.keys.toList()}');
        _logger.debug('headerBgColor: ${_serverCustomizations!['headerBgColor']}');
        _logger.debug('botName: ${_serverCustomizations!['botName']}');
        _logger.debug('logoText: ${_serverCustomizations!['logoText']}');
        _logger.debug('avatar: ${_serverCustomizations!['avatar']}');
        _logger.debug('botMsgColor: ${_serverCustomizations!['botMsgColor']}');
      }

      // Extract workspaceId from server chatbot data
      final serverWorkspaceId = chatbotData['workspaceId']?.toString();

      _logger.debug('Loaded ${_steps.length} steps and ${_edges.length} edges');

      // Start flow engine if we got steps and have a session
      if (_steps.isNotEmpty && _chatSessionId != null) {
        _flowEngine.initialize(
          chatSessionId: _chatSessionId!,
          visitorId: _visitorId ?? '',
          botId: botId,
          workspaceId: serverWorkspaceId,
          stepsData: _steps,
          edgesData: _edges,
        );

        // Set _botName variable for handover handler
        final resolvedBotName = _serverCustomizations?['botName']?.toString()
            ?? _serverCustomizations?['logoText']?.toString()
            ?? '';
        if (resolvedBotName.isNotEmpty) {
          ChatState().setVariable('_botName', resolvedBotName);
        }

        _flowEngine.start();
        _logger.debug('Flow engine started with ${_steps.length} nodes');
      }

      notifyListeners();
    }
  }

  // ========== Server Theme Builder ==========

  /// Parse hex color string to Color, with fallback
  static Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    return value != null ? Color(value) : null;
  }

  /// Build a ConferBotTheme by applying server customizations over defaults
  ConferBotTheme _buildServerTheme() {
    final c = _serverCustomizations;
    if (c == null) return defaultTheme;

    final headerBg = _parseHexColor(c['headerBgColor']?.toString());
    final headerText = _parseHexColor(c['headerTextColor']?.toString());
    final botBubble = _parseHexColor(c['botMsgColor']?.toString());
    final botText = _parseHexColor(c['botTextColor']?.toString());
    final userBubble = _parseHexColor(c['userMsgColor']?.toString());
    final userText = _parseHexColor(c['userTextColor']?.toString());
    final optionBubble = _parseHexColor(c['optionBubbleMsgColor']?.toString());
    final optionText = _parseHexColor(c['optionBubbleTextColor']?.toString());
    final chatBgColor = _parseHexColor(c['chatBgColor']?.toString());

    final colors = defaultTheme.colors.copyWith(
      primary: headerBg,
      headerBg: headerBg,
      headerText: headerText,
      botBubble: botBubble,
      botBubbleText: botText,
      userBubble: userBubble,
      userBubbleText: userText,
      optionBubble: optionBubble,
      optionBubbleText: optionText,
      background: chatBgColor,
    );

    // Parse font size override
    final fontSize = c['fontSize'];
    final parsedFontSize = fontSize is num ? fontSize.toDouble() : null;

    // Parse bubble border radius override
    final bubbleRadius = c['bubbleBorderRadius'];
    final parsedBubbleRadius = bubbleRadius is num ? bubbleRadius.toDouble() : null;

    return defaultTheme.copyWith(
      colors: colors,
      typography: parsedFontSize != null
          ? ConferBotTypography(messageSize: parsedFontSize)
          : null,
      borderRadius: parsedBubbleRadius != null
          ? ConferBotBorderRadius(bubble: parsedBubbleRadius)
          : null,
    );
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
      // Ensure we have a persistent visitor ID before starting a new session
      if (_visitorId == null && StorageService.instance.isInitialized) {
        _visitorId = await StorageService.instance.getOrCreateVisitorId();
      }

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
        _logger.debug('API initSession error: $e');
      }

      // Fallback: generate local session if API failed
      if (_chatSessionId == null) {
        _chatSessionId = 'mobile_${DateTime.now().millisecondsSinceEpoch}';
        if (_visitorId == null) {
          _visitorId = await StorageService.instance.getOrCreateVisitorId();
        }
        _logger.debug('Using local session ID: $_chatSessionId');

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

      // Wait for socket connection before emitting
      if (!_socketClient.isConnected) {
        for (int i = 0; i < 20; i++) {
          await Future.delayed(const Duration(milliseconds: 250));
          if (_socketClient.isConnected) break;
        }
      }

      // Join chat room via socket
      if (_chatSessionId != null) {
        _socketClient.joinChatRoomVisitor(_chatSessionId!);
      }

      // Request chatbot data if we don't have steps yet
      if (_steps.isEmpty) {
        _socketClient.getChatbotData();
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
    // Show user's selection as a right-aligned user bubble
    // (matches web widget's _displayUserInputMessage after choice selection)
    String? displayText;
    if (response is String) {
      displayText = response;
    } else if (response is Map) {
      displayText = (response['label'] ?? response['text'] ?? response['value'])?.toString();
    } else if (response is List) {
      displayText = response.join(', ');
    } else {
      displayText = response?.toString();
    }

    if (displayText != null && displayText.isNotEmpty) {
      final userMessage = UserInputResponseRecord(
        id: 'user_choice_${DateTime.now().millisecondsSinceEpoch}',
        time: DateTime.now(),
        text: displayText,
      );
      _addMessageToRecord(userMessage);
      notifyListeners();
    }

    _flowEngine.submitResponse(response);
  }

  /// Send text message
  /// In live chat mode, sends as a visitor live message to the agent.
  /// Otherwise, submits as a flow response or direct socket message.
  Future<void> sendMessage(String text) async {
    if (_chatSessionId == null || text.trim().isEmpty) {
      return;
    }

    // Live chat mode: send as visitor message to agent
    if (_isLiveChatMode) {
      await _sendLiveChatMessage(text);
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

  /// Send a message during live chat (agent handover) mode
  Future<void> _sendLiveChatMessage(String text) async {
    final msgId = 'user_live_${DateTime.now().millisecondsSinceEpoch}';

    // Add user message to display record
    final userMessage = UserMessageRecord(
      id: msgId,
      time: DateTime.now(),
      text: text,
    );
    _addMessageToRecord(userMessage);

    // Push to ChatState record with user-live-message shape
    ChatState.instance.pushToRecord(RecordEntry(
      id: msgId,
      shape: 'user-live-message',
      type: 'user-live-message',
      text: text,
    ));

    // Add to transcript
    ChatState.instance.addToTranscript('user', text);

    // Track in analytics
    _analyticsProvider?.trackMessage(
      sender: 'user',
      text: text,
    );

    // Send via response-record socket event with full state
    _socketClient.sendResponseRecord(
      chatSessionId: _chatSessionId!,
      record: ChatState.instance.buildResponseData(),
      answerVariables: ChatState.instance.answerVariables
          .map((v) => v.toJson())
          .toList(),
    );

    // Stop visitor typing indicator
    sendTypingStatus(false);

    notifyListeners();
  }

  /// Send visitor typing status during live chat
  void sendLiveChatTyping(bool isTyping) {
    if (_chatSessionId == null || !_isLiveChatMode) return;
    _socketClient.sendTypingStatus(
      chatSessionId: _chatSessionId!,
      isTyping: isTyping,
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
    _isLiveChatMode = false;
    _agentTyping = false;
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

  /// Emit a custom socket event
  void emit(String event, [dynamic data]) {
    _socketClient.emit(event, data);
  }

  /// Current chat session ID
  String? get chatId => _chatSessionId;

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
