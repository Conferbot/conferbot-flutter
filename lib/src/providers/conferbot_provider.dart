import 'dart:async';
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
import '../core/nodes/handlers/choices/choice_ui_states.dart';
import '../core/state/message_pagination_controller.dart';
import '../core/state/message_storage_service.dart';
import '../utils/logger.dart';
import '../utils/chat_markdown.dart';
import '../core/agent/agent_bot.dart';
import '../core/agent/agent_handover.dart';
import 'analytics_provider.dart';
import '../core/live_chat/live_chat.dart';
import '../core/live_chat/live_chat_extras.dart';
import '../core/customization/customizations.dart';
import '../core/customization/widget_theme.dart';

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

  /// Live chat extras: queue position, leave a message, receipts, locks,
  /// file requests, the lead card and the post-chat rating.
  late final LiveChatExtras liveChat;

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

  // AI agent bots (Agent Studio): a bot with no flow, answered by an AI
  // agent from the first message (core/agent/agent_bot.dart). null for
  // every flow bot.
  AgentBot? _agentBot;
  AgentStream? _agentStream;
  List<String> _suggestions = const [];
  bool _awaitingReply = false;
  Timer? _awaitReplyTimer;
  // The silent handover waits for the visitor to engage (every record sent
  // becomes a Response - a chat on the customer's plan); live sends wait
  // for its acceptance.
  Map<String, dynamic>? _agentPendingHandover;
  bool _agentHandoverPending = false;
  String? _agentStartedFor;
  String? _serverWorkspaceId;

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
    ChatState.instance.visitorContext = user?.toVisitorContext();
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

    // Live chat extras (core/live_chat): queue, leave a message, receipts,
    // locks, file requests, the lead card and the post-chat rating.
    liveChat = LiveChatExtras(
      socket: () => _socketClient,
      sessionId: () => _chatSessionId,
      addMessage: (item) {
        _addMessageToRecord(item);
        notifyListeners();
      },
      sendRecord: _sendRecord,
      continueFlow: () => _flowEngine.continueAfterHandover(),
    );
    liveChat.addListener(notifyListeners);

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
  /// The settings with the widget theme's palette applied (theme colours),
  /// as the web widget renders them; null until the bot's settings arrive.
  Map<String, dynamic>? get serverCustomizations => _themed;

  /// The phone's dark mode: a theme set to "auto" follows it.
  bool _prefersDark = false;
  Map<String, dynamic>? _themedFor;
  Map<String, dynamic>? _themedCache;
  ResolvedWidgetTheme _widgetTheme = const ResolvedWidgetTheme();

  Map<String, dynamic>? get _themed {
    final raw = _serverCustomizations;
    if (raw == null) return null;
    if (!identical(raw, _themedFor)) {
      _themedFor = raw;
      _themedCache = WidgetTheme.withThemePalette(raw, _prefersDark);
      _widgetTheme = WidgetTheme.resolve(_themedCache, _prefersDark);
    }
    return _themedCache;
  }

  /// The widget theme in force (tokens, shape, scheme).
  ResolvedWidgetTheme get widgetTheme {
    _themed;
    return _widgetTheme;
  }

  /// The phone switched between light and dark: a bot whose theme follows
  /// the phone ("auto") repaints. The chat widget calls this; apps need not.
  void setSystemDarkMode(bool dark) {
    if (dark == _prefersDark) return;
    _prefersDark = dark;
    _themedFor = null;
    notifyListeners();
  }

  /// The bot's AI agent when it is a no-flow agent bot (Agent Studio), else null.
  AgentBot? get agentBot => _agentBot;

  /// The AI reply as it is being written (one live bubble), or null.
  AgentStream? get agentStream => _agentStream;

  /// One-tap questions: the greeting's starters, then each answer's follow-ups.
  List<String> get suggestions => _suggestions;

  /// Waiting for the AI's reply (the typing dots), at most 45 seconds.
  bool get awaitingReply => _awaitingReply;

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

  /// The bot's settings as the web widget applies them (core/customization); defaults until it loads.
  ResolvedCustomizations get customizations => Customizations.resolve(_themed, theme: widgetTheme);

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
    _setupAgentBotListeners();
    liveChat.setupListeners();
    // Connection events
    _socketClient.on(SocketEvents.connect, (_) {
      _isConnected = true;

      // Update analytics online status
      _analyticsProvider?.setOnlineStatus(true);

      // Re-join chat room on reconnect (socket.io drops room membership on disconnect)
      if (_chatSessionId != null) {
        _socketClient.joinChatRoomVisitor(_chatSessionId!);
        _logger.debug('Rejoined chat room on reconnect: $_chatSessionId');
      }

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
        final sid = data['chatSessionId']?.toString();
        if (sid != null && _chatSessionId != null && sid != _chatSessionId) return;
        final agentDetailsRaw = data['agentDetails'] is Map ? Map<String, dynamic>.from(data['agentDetails'] as Map) : null;
        final isFileInput = data['isFileInput'] as bool? ?? false;
        final isAudioInput = data['isAudioInput'] as bool? ?? false;
        // A file or voice note's message is its URL; text is the inbox
        // editor's HTML or the AI's markdown, as one markdown subset.
        final rawMessageText = data['message']?.toString() ?? '';
        final messageText = (isFileInput || isAudioInput) ? rawMessageText.trim() : ChatMarkdown.htmlToMarkdown(rawMessageText);
        // An AI reply's sources, buttons and cards; its follow-ups shown.
        final extras = AgentBotParser.aiReplyExtrasOf(data);
        _onAgentBotMessage(data);
        final agentMessageId = data['agentMessageId']?.toString()
            ?? 'agent_msg_${DateTime.now().millisecondsSinceEpoch}';

        final agentDetails = agentDetailsRaw != null
            ? AgentDetails.fromJson(agentDetailsRaw)
            : AgentDetails(
                id: _currentAgent?.id ?? '',
                name: _currentAgent?.name ?? 'Agent',
                email: _currentAgent?.email ?? '',
              );

        final translation = LiveChat.agentTranslationOf(data);
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
            extras: extras != null && (!extras.isEmpty || extras.isFallback) ? extras : null,
            translation: translation,
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

        // The visitor's delivered / seen receipt for it.
        liveChat.reportReceipts(chatVisible: _isOpen);

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
      // An agent bot's own AI agent taking the chat it already greeted:
      // nothing to announce, the held messages go out.
      if (_onAgentBotAccepted(data)) return;
      if (data != null && data is Map<String, dynamic>) {
        final agentDetails = data['agentDetails'] as Map<String, dynamic>?;
        if (agentDetails != null) {
          final agentName = agentDetails['name']?.toString() ?? 'Agent';
          _currentAgent = Agent(
            id: agentDetails['_id']?.toString() ?? '',
            name: agentName,
            email: agentDetails['email']?.toString(),
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

          // Notify flow engine of agent acceptance; the handover step's
          // waiting card goes ("{name} has joined" is already a line).
          _flowEngine.handleAgentAccepted(agentName);
          _flowEngine.clearHandoverUI();
          notifyListeners();
        }
      }
    });

    // No agents available
    _socketClient.on(SocketEvents.noAgentsAvailable, (_) {
      // A flow at its handover step, as the web widget does it: the owner's
      // fallback as the bot's message, then "Leave a message" (the flow
      // carries on once it is sent or skipped), or straight on when the
      // owner turned that off.
      if (_flowEngine.isAtHandover) {
        final fallback = LiveChat.plainText(
          ChatState.instance.resolveValue(_flowEngine.handoverNodeData?['fallbackMessage']?.toString() ?? '').toString(),
        );
        _flowEngine.clearHandoverUI();
        if (fallback.isNotEmpty) {
          final id = 'agent-declined-${DateTime.now().millisecondsSinceEpoch}';
          _addMessageToRecord(BotMessageRecord(id: id, time: DateTime.now(), text: fallback));
          ChatState.instance.pushToRecord(RecordEntry(
            id: id,
            shape: 'agent-declined-message',
            type: 'agent-declined-message',
            text: fallback,
            data: {'message': fallback, 'renderedText': fallback},
          ));
        }
        if (_serverCustomizations?['chatLeaveMessage'] == false) _flowEngine.continueAfterHandover();
        notifyListeners();
        return;
      }
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
  // ========== AI Agent Bots (Agent Studio) ==========

  AgentDetails _agentDetailsOf(AgentBot bot) =>
      AgentDetails(id: bot.agentDetailsId, name: bot.displayName, email: '', avatar: bot.avatar, isAIAgent: true);

  void _setAwaitingReply(bool on) {
    _awaitReplyTimer?.cancel();
    _awaitingReply = on;
    if (on) {
      _awaitReplyTimer = Timer(const Duration(seconds: 45), () {
        _awaitingReply = false;
        notifyListeners();
      });
    }
  }

  /// The record itself, with its answer variables, on response-record.
  void _sendRecord() {
    if (_chatSessionId == null) return;
    final data = ChatState.instance.buildResponseData();
    _socketClient.sendResponseRecord(
      chatSessionId: _chatSessionId!,
      record: data['record'],
      answerVariables: data['answerVariables'] as List<dynamic>?,
      extra: data,
    );
  }

  /// Open the agent chat for this session on screen: the greeting and the
  /// starters. Nothing is sent yet - only a person starts a conversation
  /// (see [engageAgent]). A restored session already has its conversation:
  /// back in the room only, nothing greeted or handed over again.
  void _startAgentBotChat() {
    final bot = _agentBot;
    final sessionId = _chatSessionId;
    if (bot == null || sessionId == null || _agentStartedFor == sessionId) return;
    _agentStartedFor = sessionId;
    ChatState.instance.setWorkspaceId(_serverWorkspaceId);
    final details = _agentDetailsOf(bot);
    _currentAgent = Agent(id: details.id, name: details.name, avatar: bot.avatar);
    // Visitor messages go the live way from the start.
    _isLiveChatMode = true;
    ChatState.instance.setLiveChatMode(true);

    final shown = [..._record, ...paginatedMessages];
    final resumed = shown.any((m) =>
        (m is AgentMessageRecord && m.id.startsWith('agent-greeting-')) || m is UserMessageRecord);
    if (resumed) {
      _agentPendingHandover = null;
      _agentHandoverPending = false;
      return;
    }

    _agentHandoverPending = true;
    final greeting = bot.greeting.isEmpty ? AgentBotParser.defaultGreeting : bot.greeting;
    final shell = AgentBotParser.agentShellNodes(_steps, bot.agentId);
    final welcomeId = shell.welcome?['id']?.toString() ?? 'agent-welcome';
    ChatState.instance.pushToRecord(RecordEntry(
      id: welcomeId,
      shape: 'welcome-node',
      type: 'welcome-node',
      text: greeting,
      data: {
        ...?(shell.welcome?['data'] is Map ? Map<String, dynamic>.from(shell.welcome!['data'] as Map) : null),
        'text': greeting,
        'disableImage': true,
        'agentDetails': AgentBotParser.agentDetailsOf(bot),
      },
    ));
    ChatState.instance.addToTranscript('bot', greeting);
    _addMessageToRecord(AgentMessageRecord(id: 'agent-greeting-$sessionId', time: DateTime.now(), text: greeting, agentDetails: details));
    _suggestions = bot.starters;

    final shellData = shell.handover?['data'] is Map ? Map<String, dynamic>.from(shell.handover!['data'] as Map) : null;
    _agentPendingHandover = {
      'id': shell.handover?['id']?.toString() ?? 'agent-handover',
      'data': AgentBotParser.agentHandoverData(shellData, bot.agentId),
    };
    notifyListeners();
  }

  /// The visitor is engaging (typing, a suggestion tapped, a message sent):
  /// create the Response from the record, then the silent handover. Once.
  void engageAgent() {
    final step = _agentPendingHandover;
    if (step == null || !_socketClient.isConnected) return;
    _agentPendingHandover = null;
    _sendRecord();
    final data = Map<String, dynamic>.from(step['data'] as Map);
    ChatState.instance.pushToRecord(RecordEntry(
      id: step['id'].toString(),
      shape: 'human-handover-node',
      type: 'human-handover-node',
      data: data,
    ));
    final payload = AgentHandover.payload(ChatState.instance, data, extra: const {'silentStart': true});
    if (payload != null) _socketClient.emit(SocketEvents.initiateHandover, payload);
  }

  /// agent-accepted for this bot's own AI agent: nothing drawn, held messages sent.
  bool _onAgentBotAccepted(dynamic data) {
    if (_agentBot == null || data is! Map) return false;
    final raw = data['agentDetails'];
    if (raw is! Map) return false;
    final details = AgentDetails.fromJson(Map<String, dynamic>.from(raw));
    if (!details.isAIAgent) return false;
    final wasPending = _agentHandoverPending;
    _agentHandoverPending = false;
    _currentAgent = Agent(id: details.id, name: details.name, avatar: details.avatar);
    _isLiveChatMode = true;
    ChatState.instance.setLiveChatMode(true);
    final hasVisitorWords = ChatState.instance.getRecordForServer().any((r) => r['shape'] == 'user-live-message');
    if (wasPending && hasVisitorWords) {
      _sendRecord();
      _setAwaitingReply(true);
    }
    notifyListeners();
    return true;
  }

  /// An agent message arrived: the wait and the live bubble end, its follow-ups show.
  void _onAgentBotMessage(Map<String, dynamic> data) {
    _setAwaitingReply(false);
    _agentStream = null;
    final details = data['agentDetails'] is Map ? Map<String, dynamic>.from(data['agentDetails'] as Map) : null;
    _suggestions = AgentBotParser.isAIAgent(details) && data['isFallback'] != true
        ? AgentBotParser.followUpsOf(data['followUps'])
        : const [];
  }

  /// The visitor said something: the chips go, the dots wait for the AI.
  void _noteVisitorMessage() {
    _suggestions = const [];
    final types = ChatState.instance.getRecordForServer().map((r) => r['type']?.toString()).toList();
    if (_agentBot != null && AgentBotParser.isAgentAIActive(types)) _setAwaitingReply(true);
  }

  void _resetAgentBotChat() {
    _agentStartedFor = null;
    _agentPendingHandover = null;
    _agentHandoverPending = false;
    _agentStream = null;
    _suggestions = const [];
    _setAwaitingReply(false);
  }

  bool _isOwnSession(dynamic data) {
    final sid = data is Map ? data['chatSessionId']?.toString() : null;
    return sid == null || _chatSessionId == null || sid == _chatSessionId;
  }

  AgentDetails _detailsFrom(dynamic raw) => raw is Map
      ? AgentDetails.fromJson(Map<String, dynamic>.from(raw))
      : const AgentDetails(id: '', name: 'Agent', email: '');

  void _setupAgentBotListeners() {
    // The reply as it is written: one live bubble, replaced by the finished agent-message.
    _socketClient.on(SocketEvents.agentMessageStream, (data) {
      if (data is! Map || !_isOwnSession(data)) return;
      final text = data['text']?.toString() ?? '';
      final streamId = data['streamId']?.toString() ?? '';
      if (text.trim().isEmpty || streamId.isEmpty) return;
      _setAwaitingReply(false);
      _agentTyping = false;
      _agentStream = AgentStream(id: streamId, text: ChatMarkdown.htmlToMarkdown(text), agentDetails: _detailsFrom(data['agentDetails']));
      notifyListeners();
    });

    // An article, quick replies or a card from the agent.
    _socketClient.on(SocketEvents.agentMessageRich, (data) {
      if (data is! Map || !_isOwnSession(data) || data['entry'] is! Map) return;
      final entry = Map<String, dynamic>.from(data['entry'] as Map);
      final id = entry['id']?.toString() ?? '';
      final rich = AgentBotParser.safeRich(entry['rich']);
      if (id.isEmpty || rich == null || _record.any((m) => m.id == id)) return;
      _setAwaitingReply(false);
      _agentStream = null;
      final text = entry['text']?.toString() ?? '';
      _addMessageToRecord(AgentRichMessageRecord(
        id: id,
        time: DateTime.now(),
        rich: rich,
        text: text,
        agentDetails: entry['agentDetails'] is Map ? _detailsFrom(entry['agentDetails']) : null,
      ));
      ChatState.instance.pushToRecord(RecordEntry(
        id: id,
        shape: 'agent-message-rich',
        type: 'agent-message-rich',
        text: text,
        data: {'rich': entry['rich'], 'agentDetails': entry['agentDetails']},
      ));
      notifyListeners();
    });

    // An agent edited or unsent a message: the bubble changes in place.
    void change(dynamic data, bool deleted) {
      if (data is! Map || !_isOwnSession(data)) return;
      final newText = (data['text'] ?? data['message'])?.toString();
      _updateMessage(data['agentMessageId']?.toString(), (m) {
        if (m is! AgentMessageRecord) return null;
        return deleted
            ? m.copyWith(text: '', deleted: true)
            : m.copyWith(text: newText != null ? ChatMarkdown.htmlToMarkdown(newText) : null, edited: true);
      });
    }

    _socketClient.on(SocketEvents.agentMessageEdited, (data) => change(data, false));
    _socketClient.on(SocketEvents.agentMessageDeleted, (data) => change(data, true));

    // Closed for inactivity; the visitor's next message reopens it.
    _socketClient.on(SocketEvents.aiAgentInactiveClose, (data) {
      if (!_isOwnSession(data)) return;
      _setAwaitingReply(false);
      _suggestions = const [];
      ChatState.instance.pushToRecord(RecordEntry(
        id: 'ai-close-${DateTime.now().millisecondsSinceEpoch}',
        shape: 'ai-agent-inactive-close',
        type: 'ai-agent-inactive-close',
      ));
      notifyListeners();
    });
    _socketClient.on(SocketEvents.aiAgentResumed, (data) {
      if (!_isOwnSession(data)) return;
      ChatState.instance.pushToRecord(RecordEntry(
        id: 'ai-resumed-${DateTime.now().millisecondsSinceEpoch}',
        shape: 'ai-agent-resumed',
        type: 'ai-agent-resumed',
      ));
      _isLiveChatMode = true;
      ChatState.instance.setLiveChatMode(true);
      notifyListeners();
    });
  }

  /// "Helpful?" on an AI answer: kept on the message, sent to the server.
  void sendAnswerFeedback(String agentMessageId, bool helpful, [String? reason]) {
    final feedback = AnswerFeedback(helpful, helpful ? null : reason);
    _updateMessage(agentMessageId, (m) => m is AgentMessageRecord ? m.copyWith(feedback: feedback) : null);
    _socketClient.emitWithAck(SocketEvents.aiAnswerFeedback, {
      'chatSessionId': _chatSessionId,
      'agentMessageId': agentMessageId,
      ...feedback.toJson(),
    }).catchError((_) => null);
  }

  /// The visitor's Confirm / Not now on an action the AI is about to take.
  Future<({bool ok, String? code})> decideAction(String token, bool accept) async {
    try {
      final res = await _socketClient.emitWithAck(
        SocketEvents.aiActionDecision,
        {'chatSessionId': _chatSessionId, 'token': token, 'accept': accept},
        timeout: const Duration(seconds: 30),
      );
      final map = res is List && res.isNotEmpty ? res.first : res;
      final ok = map is Map && map['ok'] == true;
      if (ok && accept) {
        _setAwaitingReply(true);
        notifyListeners();
      }
      return (ok: ok, code: map is Map ? map['code']?.toString() : null);
    } catch (_) {
      return (ok: false, code: null);
    }
  }

  /// A tapped answer button or quick action, as a goal.
  void trackConversion(String goalId, String conversionEvent) {
    _socketClient.emit(SocketEvents.trackGoalCompletion, {
      'chatSessionId': _chatSessionId,
      'goalId': goalId,
      'conversionEvent': conversionEvent,
    });
  }

  /// A quick reply chosen on a rich message: the chips freeze, the label is sent.
  Future<void> answerRichMessage(String messageId, String label) async {
    _updateMessage(messageId, (m) => m is AgentRichMessageRecord ? m.answering(label) : null);
    await sendMessage(label);
  }

  /// Change one message in place (a vote, an edit, a chosen quick reply):
  /// in the record and in the paginated list the chat draws.
  bool _updateMessage(String? id, RecordItem? Function(RecordItem) change) {
    if (id == null) return false;
    RecordItem? updated;
    final index = _record.indexWhere((m) => m.id == id);
    if (index >= 0) {
      updated = change(_record[index]);
      if (updated != null) _record[index] = updated;
    } else {
      final shown = paginatedMessages.where((m) => m.id == id);
      if (shown.isNotEmpty) updated = change(shown.first);
    }
    if (updated == null) return false;
    _paginationController?.updateMessage(updated);
    notifyListeners();
    return true;
  }

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
      final imageUrl = messageData['imageUrl'] as String? ?? '';
      final nodeId = messageData['nodeId'] as String? ?? '';
      if (text.isNotEmpty || imageUrl.isNotEmpty) {
        final botMessage = BotMessageRecord(
          id: 'bot_${nodeId}_${DateTime.now().millisecondsSinceEpoch}',
          time: DateTime.now(),
          text: text,
          nodeData: imageUrl.isNotEmpty ? {'imageUrl': imageUrl} : null,
        );
        _addMessageToRecord(botMessage);
        _logger.debug('Added bot message to record: "$text" image: "$imageUrl"');
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
    // Where the visitor stands: asked while the handover waits for a person.
    final ui = _flowEngine.currentUIState;
    if (ui is HumanHandoverUIState && ui.state == HandoverState.waitingForAgent && !_isLiveChatMode) {
      liveChat.startQueuePoll();
      liveChat.startWaitTimer(_flowEngine.handoverNodeData, ChatState.instance.workspaceId);
    } else {
      liveChat.stopQueuePoll();
      liveChat.stopWaitTimer();
    }
    notifyListeners();
  }

  /// Handle incoming chatbot data (steps and edges)
  void _handleChatbotData(Map<String, dynamic> data) {
    final chatbotData = data['chatbotData'] as Map<String, dynamic>?;
    if (chatbotData != null) {
      liveChat.setChatbotData(chatbotData);
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

      // Store integration webhooks (Zapier) for the zapier-node handler
      final webhooksData = chatbotData['integrationWebhooks'] as List<dynamic>?;
      if (webhooksData != null) {
        ChatState.instance.setIntegrationWebhooks(
          webhooksData
              .whereType<Map>()
              .map((w) => Map<String, dynamic>.from(w))
              .toList(),
        );
      }

      // Extract workspaceId from server chatbot data
      final serverWorkspaceId = chatbotData['workspaceId']?.toString();

      // No-flow AI agent bot (Agent Studio)? null for every flow bot.
      _agentBot = AgentBotParser.parseAgentBot(chatbotData);
      _serverWorkspaceId = serverWorkspaceId;
      if (_agentBot != null) {
        ChatState.instance.setWorkspaceId(serverWorkspaceId);
        final resolvedName = _serverCustomizations?['botName']?.toString() ?? _serverCustomizations?['logoText']?.toString() ?? '';
        if (resolvedName.isNotEmpty) ChatState().setVariable('_botName', resolvedName);
        if (_chatSessionId != null && _isOpen) _startAgentBotChat();
        notifyListeners();
        return;
      }

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

  /// Parse a builder color value: #RGB, #RRGGBB, #RRGGBBAA, rgb(), rgba()
  static Color? _parseHexColor(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    raw = raw.trim();

    // rgb(r, g, b) / rgba(r, g, b, a) - the flow builder stores both forms
    final rgb = RegExp(
            r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)')
        .firstMatch(raw);
    if (rgb != null) {
      final a = rgb.group(4) != null
          ? ((double.tryParse(rgb.group(4)!) ?? 1.0) * 255).round().clamp(0, 255)
          : 255;
      return Color.fromARGB(a, int.parse(rgb.group(1)!),
          int.parse(rgb.group(2)!), int.parse(rgb.group(3)!));
    }

    var hex = raw.replaceFirst('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((ch) => '$ch$ch').join();
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    return value != null ? Color(value) : null;
  }

  /// Build a ConferBotTheme by applying server customizations over defaults
  ConferBotTheme _buildServerTheme() {
    final c = _themed;
    if (c == null) return defaultTheme;
    final tokens = widgetTheme.tokens;

    // The web widget's defaults and fallbacks (core/customization): #0b4eb8
    // bot bubbles with white text, light grey visitor bubbles with dark
    // text, choices in the option colours else the bot's.
    final look = customizations;
    final headerBg = _parseHexColor(look.headerBg);
    final headerText = _parseHexColor(look.headerText);
    final botBubble = _parseHexColor(look.botBubbleColor) ?? const Color(0xFF0B4EB8);
    final botText = _parseHexColor(look.botTextColor) ?? const Color(0xFFFFFFFF);
    final userBubble = _parseHexColor(look.userBubbleColor) ?? const Color(0xFFF0F0F0);
    final userText = _parseHexColor(look.userTextColor) ?? const Color(0xFF000000);
    final optionBubble = _parseHexColor(look.optionBubbleColor);
    final optionText = _parseHexColor(look.optionTextColor);
    final chatBgColor = _parseHexColor(c['chatBgColor']?.toString());

    final colors = defaultTheme.colors.copyWith(
      primary: headerBg,
      headerBg: headerBg,
      headerText: headerText,
      botBubble: botBubble,
      botBubbleText: botText,
      // An agent - person or AI - speaks in the bot's colours, as on the web.
      agentBubble: botBubble,
      agentBubbleText: botText,
      userBubble: userBubble,
      userBubbleText: userText,
      optionBubble: optionBubble,
      optionBubbleText: optionText,
      background: chatBgColor,
    );

    // The widget theme's surfaces and text (every theme but classic in
    // light): chat, composer, cards, quiet text, lines. The owner's own chat
    // background stays theirs.
    final themed = tokens == null
        ? colors
        : colors.copyWith(
            background: look.surface != null ? _parseHexColor(tokens.bg) : chatBgColor,
            surface: _parseHexColor(tokens.bg),
            systemBubble: _parseHexColor(tokens.card2),
            systemBubbleText: _parseHexColor(tokens.text),
            text: _parseHexColor(tokens.ink),
            textSecondary: _parseHexColor(tokens.muted),
            textDisabled: _parseHexColor(tokens.faint),
            border: _parseHexColor(tokens.line2),
            divider: _parseHexColor(tokens.line),
          );

    // Font size: 14 counts as unset (14.5 on the web). Bubble corners come
    // from the resolved settings in the bubbles themselves.
    return defaultTheme.copyWith(
      brightness: widgetTheme.isDark ? Brightness.dark : Brightness.light,
      colors: themed,
      typography: ConferBotTypography(messageSize: look.fontSize),
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

      // An agent bot picks its conversation back up.
      if (_agentBot != null) {
        _isOpen = true;
        _unreadCount = 0;
        _startAgentBotChat();
        notifyListeners();
        return;
      }

      // If we have steps, resume the flow engine
      if (_steps.isNotEmpty) {
        _flowEngine.initialize(
          chatSessionId: _chatSessionId!,
          visitorId: _visitorId ?? '',
          botId: botId,
          workspaceId: _serverWorkspaceId,
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

      // An agent bot opens into the agent chat, never the shell flow.
      if (_agentBot != null) {
        _isOpen = true;
        _unreadCount = 0;
        _startAgentBotChat();
        notifyListeners();
        return;
      }

      // Initialize and start the flow engine
      if (_steps.isNotEmpty) {
        _flowEngine.initialize(
          chatSessionId: _chatSessionId!,
          visitorId: _visitorId ?? '',
          botId: botId,
          workspaceId: _serverWorkspaceId,
          stepsData: _steps,
          edgesData: _edges,
        );
        _flowEngine.start();
      }
    }

    _isOpen = true;
    _unreadCount = 0;
    liveChat.reportReceipts(chatVisible: true);
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

    // Web widget parity: keep the question (and, for choice nodes, the
    // disabled choice chips with the selection highlighted) in the
    // transcript, so nothing vanishes when the node advances.
    final questionText = _flowEngine.currentQuestionText;
    final uiState = _flowEngine.currentUIState;
    Map<String, dynamic>? persistedNodeData;
    if (uiState is SingleChoiceState) {
      persistedNodeData = {
        'choices': uiState.choices
            .map((c) => {'id': c.id, 'text': c.text})
            .toList(),
        'selected': displayText,
      };
    } else if (uiState is MultipleChoiceState) {
      persistedNodeData = {
        'choices': uiState.options
            .map((o) => {'id': o.id, 'text': o.text})
            .toList(),
        'selected': displayText,
      };
    } else if (uiState is SingleChoiceUIState) {
      persistedNodeData = {
        'choices': uiState.choices
            .map((c) => {'id': c.id, 'text': c.text})
            .toList(),
        'selected': displayText,
      };
    } else if (uiState is MultipleChoiceUIState) {
      persistedNodeData = {
        'choices': uiState.options
            .map((o) => {'id': o.id, 'text': o.text})
            .toList(),
        'selected': displayText,
      };
    }
    if ((questionText != null && questionText.isNotEmpty) ||
        persistedNodeData != null) {
      _addMessageToRecord(BotMessageRecord(
        id: 'bot_q_${DateTime.now().millisecondsSinceEpoch}',
        time: DateTime.now(),
        // The builder writes questions as rich text (<p>...</p>).
        text: questionText == null ? null : LiveChat.plainText(questionText),
        nodeData: persistedNodeData,
      ));
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
    // An agent bot's conversation starts with the visitor's first word.
    engageAgent();
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

    // Send via response-record - the record itself (the whole payload was
    // sent as the record, so the server could not read the message). Held
    // while an agent bot's handover is being accepted; the acceptance
    // sends it.
    if (!_agentHandoverPending) _sendRecord();
    _noteVisitorMessage();

    // Stop visitor typing indicator
    sendTypingStatus(false);

    notifyListeners();
  }

  /// The visitor's file in a live chat: uploaded, then sent as the web
  /// widget sends it. Returns an error message, or null when it went.
  Future<String?> sendLiveFile(String filePath, {required String fileName, String? mimeType}) async {
    final sessionId = _chatSessionId;
    if (sessionId == null) return 'Not ready';
    final res = await _apiClient.uploadFile(chatSessionId: sessionId, filePath: filePath, fileName: fileName, mimeType: mimeType);
    final url = res.data?['url']?.toString() ?? res.data?['fileUrl']?.toString();
    if (!res.success || url == null || url.isEmpty) return "That file can't be sent. Please try another one.";
    liveChat.sendLiveFile(url, fileName: fileName, mimeType: mimeType);
    return null;
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
    // Typing in the composer: a person is here.
    if (isTyping) engageAgent();
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
    liveChat.reset();
    _record.clear();
    _chatSessionId = null;
    _currentAgent = null;
    _isLiveChatMode = false;
    _agentTyping = false;
    _sessionRestored = false;
    _resetAgentBotChat();
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
    liveChat.removeListener(notifyListeners);
    liveChat.dispose();
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
