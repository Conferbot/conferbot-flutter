import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:url_launcher/url_launcher.dart';
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
import '../utils/chat_markdown.dart';
import '../core/agent/agent_bot.dart';
import '../core/agent/answer_feedback.dart';
import '../core/help_centre/help_centre.dart';
import '../models/knowledge_base.dart';
import '../core/agent/agent_handover.dart';
import 'analytics_provider.dart';
import '../core/live_chat/live_chat.dart';
import '../core/live_chat/live_chat_extras.dart';
import '../core/live_chat/live_events.dart';
import '../core/live_chat/email_transcript.dart';
import '../core/live_chat/handover_lifecycle.dart';
import '../core/waiting/games_card.dart';
import '../core/waiting/wait_articles.dart';
import '../core/waiting/waiting_extras.dart';
import '../core/live_chat/handover_state.dart';
import '../core/requests/requests.dart';
import '../core/requests/requests_extras.dart';
import '../core/live_chat/reply_time.dart';
import '../core/customization/customizations.dart';
import '../core/i18n/i18n.dart' show I18n;
import '../core/customization/widget_theme.dart';
import '../core/customization/personalize.dart';
import '../core/home/home.dart' hide homeModel, homePalette;
import '../core/home/home.dart' as rules show homeModel, homePalette;
import '../core/home/home_extras.dart';
import '../core/customization/message_sound.dart';
import '../services/chat_sounds.dart';
import '../core/delight/delight.dart';
import '../core/delight/delight_extras.dart';
import '../core/live_chat/typing_preview.dart';
import '../core/live_chat/post_chat_redirect.dart';
import '../services/font_loader.dart';

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

  /// The language the widget draws its own words in: "en", "nl", "fr", "de",
  /// "es" or "auto" (the phone's languages); an unknown code is "auto".
  /// When set it overrides the owner's `widgetLanguage` (as the web's
  /// host-page `customizations.widgetLanguage` does); null leaves the
  /// owner's choice.
  final String? widgetLanguage;

  /// The owner's post-chat redirect (Customize > Conversations), before the
  /// countdown starts: return true when the app handled the URL itself (or
  /// wants no redirect), and the SDK shows no countdown. Anything else: the
  /// SDK counts down 10 seconds with Cancel, then opens the URL in the
  /// system browser. Only http(s) URLs reach it.
  final bool Function(String url)? onPostChatRedirect;

  /// Never follow the owner's post-chat redirect (default false).
  final bool disablePostChatRedirect;

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
    this.widgetLanguage,
    this.onPostChatRedirect,
    this.disablePostChatRedirect = false,
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
  /// The signed-in user: the constructor's, then whatever [identify] set.
  ConferBotUser? get user => _user;
  ConferBotUser? _user;
  final String? baseUrl;
  final String? socketUrl;

  late final ApiClient _apiClient;
  late final SocketClient _socketClient;
  late final NodeFlowEngine _flowEngine;

  /// Live chat extras: queue position, leave a message, receipts, locks,
  /// file requests, the lead card and the post-chat rating.
  late final LiveChatExtras liveChat;

  /// The handover's lifecycle: the Connecting line and its outcome, the 20s
  /// waiting signal, leaving the queue, and a live chat picked back up after
  /// a restart (core/live_chat/handover_lifecycle.dart).
  late final HandoverLifecycle handover;

  /// While the visitor waits for a person: the help card (articles 6s in,
  /// or the server's queue-help pick with "That solved it"), the games offer
  /// 2.5s after the waiting signal, "play" typed while waiting
  /// (core/waiting/waiting_extras.dart). Its cards are never saved.
  late final WaitingExtras waiting;

  /// "Your requests": the visitor's conversations with the team, the chat
  /// menu's item, the unread count and the portal's screens
  /// (core/requests/requests_extras.dart).
  late final RequestsExtras requests;

  /// The home screen: which view the open chat shows (home, conversation,
  /// help centre), what the device remembers for "Welcome back", the help
  /// centre's data and the server's article search (core/home/home_extras.dart).
  late final HomeExtras home;

  /// The chat's sounds: a message arriving, opening, closing and sending,
  /// under the owner's messageSound / soundPack / launcher sound, and the
  /// visitor's Sound on / off (services/chat_sounds.dart).
  late final ChatSounds sounds;

  /// The human touches: the bot's tapback and the confetti on an answer,
  /// the waiting nudge, "Edit" under the latest answer
  /// (core/delight/delight_extras.dart).
  late final DelightExtras delight;

  /// The owner's post-chat redirect: after the conversation ends and the
  /// rating is done, the app's onPostChatRedirect, else "Taking you to
  /// example.com in 10s" with Cancel, then the system browser
  /// (core/live_chat/post_chat_redirect.dart).
  late final PostChatRedirect postChatRedirect;

  /// The bot's redirectUrl (fetched-chatbot-data).
  Object? _redirectUrl;

  /// The visitor's draft to the person in the chat (core/live_chat/typing_preview.dart).
  late final DraftSender _drafts = DraftSender((draft) {
    final sid = _chatSessionId;
    if (sid != null && _socketClient.isConnected) _socketClient.emit('visitor-draft', {'chatSessionId': sid, 'draft': draft});
  });

  /// The chat's font: the owner's, else the theme's, loaded from Google Fonts
  /// (services/font_loader.dart). `chatFont.body` / `chatFont.display` are
  /// family names, or null for the platform font.
  late final ChatFont chatFont = ChatFont()..addListener(notifyListeners);

  /// The family the chat's text is drawn in: the bot's font once loaded,
  /// else the app's own `ConferBotCustomization.fontFamily`, else null.
  String? get chatFontFamily => chatFont.body ?? customization?.fontFamily;

  /// The family the chat's headings are drawn in (the header's title).
  String? get chatDisplayFontFamily => chatFont.display ?? chatFontFamily;

  /// The step that said each row of the conversation, by row id.
  final Map<String, String> _rowNodes = {};

  /// A score answer's text as the web reads it ("4/5"), for the next answer row.
  ({String nodeId, String text})? _pendingScore;

  // The session whose flow has been started (or picked back up): bot data
  // comes again on every reconnect and must not run the flow again.
  String? _flowStartedFor;

  // Start-up (the saved session restored, the socket, pagination): the chat
  // opens only once it is done, or a restored session would be missed.
  final Completer<void> _started = Completer<void>();

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

  /// The widget's language (core/i18n): the app's `config.widgetLanguage`
  /// when set (RN's `config.widgetLanguage ?? customizations.widgetLanguage`),
  /// else the owner's `customizations.widgetLanguage`; "auto", unset or
  /// unknown the phone's languages, else English. Set before the chat is
  /// drawn; widgets listening to [I18n.languageListenable] redraw.
  String applyWidgetLanguageFor(Map<String, dynamic>? customizations) =>
      I18n.setWidgetLanguage(config.widgetLanguage ?? customizations?['widgetLanguage']);

  void _applyWidgetLanguage() => applyWidgetLanguageFor(_rawCustomizations);

  void _onLanguage() => notifyListeners();

  /// Scoped logger for this provider
  static final _logger = ConferBotLogger.scoped('ConferBotProvider');

  ConferBotProvider({
    required this.apiKey,
    required this.botId,
    this.config = const ConferBotConfig(),
    this.customization,
    ConferBotUser? user,
    this.baseUrl,
    this.socketUrl,
  }) : _user = user {
    ChatState.instance.visitorContext = user?.toVisitorContext();
    // The app's language (else the phone's) until the bot's settings arrive;
    // a change redraws everything that reads this provider.
    _applyWidgetLanguage();
    I18n.languageListenable.addListener(_onLanguage);
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
      // "Email me this chat" (core/live_chat/email_transcript.dart).
      postTranscriptEmail: (sessionId, email) => _apiClient.sendTranscriptEmail(sessionId, email),
      // A queue-status's help is what to offer while waiting (core/waiting).
      onQueueStatus: (data) => waiting.onQueueStatus(data),
    );
    liveChat.addListener(notifyListeners);

    handover = HandoverLifecycle(
      socket: () => _socketClient,
      sessionId: () => _chatSessionId,
      isOpen: () => _isOpen,
      addLine: (line) {
        _addMessageToRecord(line);
        notifyListeners();
      },
      updateLines: _updateAllMessages,
      flow: _EngineHandoverFlow(() => _flowEngine),
      setLive: (on) {
        _isLiveChatMode = on;
        ChatState.instance.setLiveChatMode(on);
        if (!on) _currentAgent = null;
        notifyListeners();
      },
      setAgent: (a) {
        _currentAgent = Agent(id: a.id, name: a.name, email: a.email);
        notifyListeners();
      },
      // Back in the queue: nobody is in the chat (core/live_chat/live_events.dart).
      clearAgent: () {
        _currentAgent = null;
        _agentTyping = false;
        notifyListeners();
      },
      // Where a wait for a person begins and ends: the help card's timer.
      waitStart: () => waiting.startWait(),
      waitEnd: () => waiting.endWait(),
      // An agent bot's inactivity close only pauses it (no flow to go on with).
      isAgentBot: () => _agentBot != null,
      // The escalation's handover-timeout names the bot's workspace.
      workspaceId: () => ChatState.instance.workspaceId ?? _serverWorkspaceId,
      // A restored wait's countdown goes on from the server's seconds left.
      onRestoredWait: (remaining) => liveChat.resumeWaitWith(remaining),
    );

    waiting = WaitingExtras(
      socket: () => _socketClient,
      sessionId: () => _chatSessionId,
      record: () => ChatState.instance.getRecordForServer(),
      customizations: () => _serverCustomizations,
      personJoined: () => handover.personInChat,
      leftQueueHelped: () {
        handover.leftQueueHelped();
        notifyListeners();
      },
      lastShownId: () {
        final shown = paginatedMessages.isNotEmpty ? paginatedMessages : _record;
        return shown.isEmpty ? null : shown.last.id;
      },
    );
    waiting.bind(handover.onSignal);
    waiting.addListener(notifyListeners);

    requests = RequestsExtras(
      botId: () => botId,
      socket: () => SocketClientRequestsSocket(_socketClient),
      connected: () => _socketClient.isConnected,
      // The visitor id the records carry, else the handshake's.
      visitorId: () {
        final v = ChatState.instance.visitorId;
        return v != null && v.isNotEmpty ? v : (_visitorId ?? _socketClient.visitorId);
      },
      user: () => user,
      store: () => const SharedPreferencesRequestsStore(),
      chatSessionId: () => _chatSessionId,
      chatEnded: () => LiveEvents.endedSinceLastLive(ChatState.instance.getRecordForServer()),
      // The portal sits over the chat: closing it shows that chat.
      openChat: () {
        if (!_isOpen) openChat();
        home.showChat();
      },
    );
    requests.addListener(notifyListeners);

    home = HomeExtras(
      botId: () => botId,
      // The settings as the chat uses them: themed and personalised.
      customizations: () => _themed,
      chatSessionId: () => _chatSessionId,
      store: () => const SharedPreferencesRequestsStore(),
      socket: () => SocketClientRequestsSocket(_socketClient),
      connected: () => _socketClient.isConnected,
      send: (text) => unawaited(sendMessage(text).catchError((_) {})),
      // The home came into view: the requests card reads again (at most every 15s).
      onHomeShown: () => unawaited(requests.onChatShown()),
    );
    home.addListener(notifyListeners);

    sounds = ChatSounds(customizations: () => _serverCustomizations);
    sounds.addListener(notifyListeners);

    delight = DelightExtras(
      customizations: () => _serverCustomizations,
      engine: () => _flowEngine,
      rows: () => [
        for (final r in _record)
          DelightRow(
            id: r.id,
            nodeId: _rowNodes[r.id],
            visitor: r.type == MessageType.userMessage || r.type == MessageType.userInputResponse,
            time: r.time,
          ),
      ],
      chatVisible: () => _chatOnScreen,
      // A person or the AI agent in the conversation, or on their way: no going back.
      locked: () => _isLiveChatMode || _agentBot != null || !handover.talkToPersonAllowed,
      cut: _cutRecordFrom,
    );
    delight.addListener(notifyListeners);

    postChatRedirect = PostChatRedirect(
      redirectUrl: () => _redirectUrl,
      sessionId: () => _chatSessionId,
      chatVisible: () => _chatOnScreen,
      blocked: () => liveChat.blocked != null,
      // A person in the chat, or one on their way.
      live: () => _isLiveChatMode || !handover.talkToPersonAllowed,
      ratingPending: () => liveChat.csatConfig != null && liveChat.csatOpen && !liveChat.csatSent,
      disabled: () => config.disablePostChatRedirect,
      onPostChatRedirect: () => config.onPostChatRedirect,
      store: () => config.enablePersistence ? const SharedPreferencesRequestsStore() : null,
      appInForeground: _appInForeground,
      // The system browser, as the SDK opens every link.
      open: (href) => launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication),
    );
    postChatRedirect.addListener(notifyListeners);
    // Whatever the chat shows changed: the redirect waits for the rating,
    // and a countdown that can no longer go stops.
    addListener(postChatRedirect.update);
    // Seen receipts count the chat as visible only on the conversation.
    home.chosen.addListener(() {
      if (_isOpen) liveChat.reportReceipts(chatVisible: _chatOnScreen);
    });
    // A chat the visitor wrote in may become a request (web _sendResponse).
    _socketClient.onResponseRecord = (sessionId, record) => requests.onRecord(sessionId, record is List ? record : null);

    if (config.autoConnect) {
      // Done even when start-up fails, so openChat never waits forever.
      _initialize().whenComplete(() {
        if (!_started.isCompleted) _started.complete();
      });
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

  /// The bot's settings as the server sent them, before "Greet by name".
  Map<String, dynamic>? _rawCustomizations;

  /// "Hi {{first_name|there}}": the signed-in user (its metadata and name)
  /// and a name the chat asked for fill the owner's texts before anything
  /// reads them, the greeting card and the home screen alike
  /// (core/customization/personalize.dart, web ownerLayout.ts). Run again on
  /// [identify].
  void _personalize() {
    final u = _user;
    final context = u == null ? null : <String, dynamic>{...?u.metadata, if (u.name != null && u.name!.isNotEmpty) 'name': u.name};
    _serverCustomizations = personalizeCustomizations(_rawCustomizations, visitorVars(context, ChatState.instance.userMetadata.name));
  }

  /// The open chat shows the conversation (not the home screen or help centre).
  bool get _chatOnScreen => _isOpen && home.view == HomeView.chat;

  /// The app is in the foreground (true before the binding runs, in tests).
  static bool _appInForeground() {
    try {
      final s = WidgetsBinding.instance.lifecycleState;
      return s == null || s == AppLifecycleState.resumed || s == AppLifecycleState.inactive;
    } catch (_) {
      return true;
    }
  }

  /// What the home screen shows (core/home/home.dart), or null when the
  /// owner has none (`enableInitialPage` off) or the settings have not come.
  HomeModel? get homeModel {
    final c = _themed;
    if (c == null) return null;
    final a = _agentBot;
    final kb = home.knowledgeBase;
    return rules.homeModel(
      c: c,
      botName: botName,
      agent: a == null ? null : HomeAgent(displayName: a.displayName, starters: a.starters, avatar: a.avatar),
      categories: kb.categories,
      recentArticles: kb.recentArticles,
      memory: home.memory,
      chatSessionId: _chatSessionId,
      requests: requests.list,
      seen: requests.memory.seen,
    );
  }

  /// The home screen's surfaces: the widget theme's, else the classic widget's.
  HomePalette get homePalette {
    final t = widgetTheme.tokens;
    return t == null ? classicHomePalette : rules.homePalette(bg2: t.bg2, card: t.card, card2: t.card2, ink: t.ink, muted: t.muted, line: t.line);
  }

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

  // ---- Help centre (knowledge base) ----

  KnowledgeBaseData _helpCentreData = KnowledgeBaseData.empty;
  void Function(String articleId)? _articleOpener;

  /// The help centre from fetched-chatbot-data: titles and descriptions,
  /// no bodies (the article view fetches a body on open).
  KnowledgeBaseData get helpCentreData => _helpCentreData;

  /// The owner's help centre switch is on and it has a published article
  /// (core/help_centre/help_centre.dart). The app's own override is applied
  /// by ChatWidget.
  bool get helpCentreOn =>
      HelpCentre.isVisible(customizations: _serverCustomizations, data: _helpCentreData);

  /// The chat on screen registers how it opens an article (null to clear).
  set articleOpener(void Function(String articleId)? opener) => _articleOpener = opener;

  /// The chat on screen says whether it shows the help centre (the owner's
  /// switch, or its own `showKnowledgeBase`); unset, the owner's switch.
  set articlesShown(bool Function()? shown) => _articlesShown = shown;
  bool Function()? _articlesShown;

  /// Can AI sources and rich article cards open articles in the help
  /// centre? Only while a chat is on screen whose help centre is on (RN
  /// agentBot.ts canOpenArticles: helpCentreOn and the host can show one).
  bool get canOpenArticles => _articleOpener != null && (_articlesShown?.call() ?? helpCentreOn);

  /// Can this article open in the help centre?
  bool canOpenArticle(String? articleId) => canOpenArticles && HelpCentre.canOpenArticle(visible: true, articleId: articleId);

  /// Open a help centre article by id; false when it cannot open here.
  bool openArticle(String articleId) {
    if (!canOpenArticle(articleId)) return false;
    _articleOpener!(articleId);
    return true;
  }

  /// The AI reply as it is being written (one live bubble), or null.
  AgentStream? get agentStream => _agentStream;

  /// One-tap questions: the greeting's starters, then each answer's follow-ups.
  List<String> get suggestions => _suggestions;

  /// Waiting for the AI's reply (the typing dots), at most 45 seconds.
  bool get awaitingReply => _awaitingReply;

  /// The workspace blocked this visitor: the closed line's words, else null.
  String? get visitorBlocked => liveChat.blocked;

  /// The chat's closed state (core/live_chat/live_events.dart): blocked, or
  /// the live chat ended with nothing going on (then "Start a new chat").
  ClosedState? get closedState => LiveEvents.closedStateOf(
        ChatState.instance.getRecordForServer(),
        blocked: liveChat.blocked,
        stepWaiting: _flowEngine.currentUIState != null || _flowEngine.isProcessing,
        live: _isLiveChatMode && _currentAgent != null,
      );

  /// The newest AI answer that can be rated: only it asks "Helpful?".
  String? get newestRateableAnswerId {
    final seen = <String>{};
    return Helpful.newestRateableId([
      for (final m in [...paginatedMessages, ..._record])
        if (m is AgentMessageRecord && seen.add(m.id))
          (id: m.id, rateable: m.agentDetails.isAIAgent && m.extras?.isFallback != true && !m.deleted),
    ]);
  }

  // The chat on screen registers how its composer takes focus.
  VoidCallback? _composerFocuser;

  /// The chat on screen registers how its composer takes focus (null to clear).
  set composerFocuser(VoidCallback? focus) => _composerFocuser = focus;

  /// Put the cursor in the composer ("Ask another way" under an answer).
  void focusComposer() => _composerFocuser?.call();

  // ---- While you wait (core/waiting) ----

  void Function(String articleId)? _waitArticleOpener;

  /// The help card while waiting for a person, or null.
  HelpCardState? get waitHelpCard => waiting.helpCard;

  /// The message the help card follows (null: at the end).
  String? get waitHelpAfter => waiting.helpAfter;

  /// The games card on screen, or null.
  GamesCard? get gamesCard => waiting.gamesCard;

  /// The message the games card follows (null: at the end).
  String? get gamesAfter => waiting.gamesAfter;

  /// The chat on screen registers how it opens an article from the help
  /// card: from the help centre data, else fetched from the server by id
  /// (the server picks articles the help centre may not list).
  set waitArticleOpener(void Function(String articleId)? opener) => _waitArticleOpener = opener;

  /// A row of the help card: an article opens in the app (a page is the
  /// view's to open in the browser).
  void openWaitHelpItem(HelpItem item) {
    waiting.opened(item);
    if (!item.isPage) _waitArticleOpener?.call(item.id);
  }

  /// "That solved it": queue-self-resolve with the article; true when the
  /// visitor left the queue ("You left the queue. Glad that helped.").
  Future<bool> solveWait() => waiting.solveWait();

  /// "Email me this chat" (core/live_chat/email_transcript.dart): the card
  /// from the chat menu, and where the transcript went once sent.
  bool get emailTranscriptOpen => liveChat.mailOpen;
  String? get emailTranscriptSentTo => liveChat.mailSentTo;
  void openEmailTranscript() => liveChat.openEmailTranscript();
  void closeEmailTranscript() => liveChat.closeEmailTranscript();

  /// Email the transcript to this address; on success the address is kept
  /// as the visitor's. Only the server sends it, and only there.
  Future<TranscriptEmailResult> emailTranscript(String email) => liveChat.emailTranscript(email);

  // ---- Your requests (core/requests) ----

  /// The visitor's requests (newest replies first), null until read.
  List<RequestSummary>? get myRequests => requests.list;

  /// Requests with a team reply not read on this device: the app's badge.
  int get requestsUnread => requests.unread;

  /// The requests portal is up.
  bool get requestsOpen => requests.isOpen;

  /// Open "Your requests": the list, or one request by its id.
  Future<void> openRequests([String? requestId]) => requests.open(requestId);

  /// Leave "Your requests".
  void closeRequests() => requests.close();

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

  /// A person (not the AI) is in the chat, from the record (web handoverState.ts).
  bool get personInChat => handover.personInChat;

  /// "Talk to a person" may be offered: nobody is coming or here.
  bool get talkToPersonAllowed => handover.talkToPersonAllowed;

  // Retired once tapped, or once a handover took it off: an AI reply
  // arriving mid-handover cannot bring it back (web quickActions.ts).
  bool _talkToPersonRetired = false;

  /// "Talk to a person" on the quick actions: an AI agent bot whose owner
  /// turned it on, only while no handover is under way and nobody is here.
  bool get offerTalkToPerson =>
      _agentBot != null && _serverCustomizations?['chatTalkToHuman'] == true && !_talkToPersonRetired && talkToPersonAllowed;

  /// The visitor taps "Talk to a person": it goes, and the AI is asked.
  Future<void> talkToPerson() async {
    _talkToPersonRetired = true;
    notifyListeners();
    await sendMessage(LiveChat.talkToPersonAsk);
  }

  /// The header's line under the bot name: "Online", the team's reply time
  /// ("Typically replies in a few minutes", "Online · team back Monday 9 AM"),
  /// or plain "Online" once a person is in the chat; null when the owner
  /// turned the status off (core/live_chat/reply_time.dart).
  String? get headerStatus => ReplyTime.headerStatus(
        _serverCustomizations?['replyTime'],
        personInChat: personInChat,
        agentBot: _agentBot != null,
        hidden: _serverCustomizations != null && !customizations.showOnline,
      );

  /// The visitor leaves the queue (queue-self-resolve): the team stops
  /// seeing them waiting and the flow carries on. False when a person has
  /// already picked the chat up (they stay).
  Future<bool> leaveQueue() async {
    final left = await handover.leaveQueue();
    notifyListeners();
    return left;
  }

  /// Listen to a widget signal, as the web widget's window events:
  /// `cb:waiting-for-human` ({offline, reason, backAt, emailCaptured}),
  /// `cb:human-joined` ({name}) and `cb:wait-over` ({reason: unavailable |
  /// cancelled | ended}). Call the returned function to stop listening.
  void Function() onWidgetSignal(String name, void Function(Map<String, dynamic> detail) listener) =>
      handover.onSignal(name, listener);

  /// Whether a previous session was restored from persistence
  bool get sessionRestored => _sessionRestored;

  /// Whether persistence system is ready
  bool get isPersistenceReady => _isPersistenceReady;

  /// Flow engine for node processing
  NodeFlowEngine get flowEngine => _flowEngine;

  /// Current UI state from flow engine
  dynamic get currentUIState => _flowEngine.currentUIState;

  /// The waiting step's visit (a card keeps its draft through a refusal of it).
  int get stepVisit => _flowEngine.stepVisit;

  /// Why the visitor's last answer to the waiting step was refused, for its card.
  String? get stepError => _flowEngine.validationMessage;

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

    // The visitor as the records name it: the server refuses a blocked one
    // at the handshake (web core/socket.ts).
    if (_visitorId == null && StorageService.instance.isInitialized) {
      try {
        _visitorId = await StorageService.instance.getOrCreateVisitorId();
      } catch (_) {}
    }
    _socketClient.visitorId = _visitorId ?? user?.id;

    await _socketClient.connect();
    _logger.debug('Socket connect() returned, registering listeners...');
    _setupSocketListeners();
    _setupFlowEngineListeners();

    // Explicitly request chatbot data after connection setup
    // (handles race condition where connect event fires before listeners are registered)
    if (_socketClient.isConnected) {
      _socketClient.getChatbotData();
      // Connected before the listeners: the visitor's requests now.
      requests.onConnected();
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
    handover.setupListeners();
    waiting.setupListeners();
    requests.attach();
    // Connection events
    _socketClient.on(SocketEvents.connect, (_) {
      _isConnected = true;
      // Every connect: the visitor's requests read again.
      requests.onConnected();

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
        liveChat.reportReceipts(chatVisible: _chatOnScreen);

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
      if (data is! Map || !_isOwnSession(data)) return;
      // The wait is over: the Connecting line settles (joined, or
      // unavailable when the AI takes the chat back), the waiting signal
      // stops (core/live_chat/handover_state.dart acceptedPlan).
      final plan = handover.onAccepted(data);
      if (plan.humanJoined) _talkToPersonRetired = true;
      // An agent bot's own AI agent taking the chat it already greeted:
      // nothing to announce, the held messages go out.
      if (_onAgentBotAccepted(data)) return;
      final agentDetails = data['agentDetails'] is Map ? Map<String, dynamic>.from(data['agentDetails'] as Map) : null;
      if (agentDetails == null) return;
      final agentName = agentDetails['name']?.toString() ?? 'Agent';
      _currentAgent = Agent(
        id: agentDetails['_id']?.toString() ?? '',
        name: agentName,
        email: agentDetails['email']?.toString(),
        avatar: agentDetails['avatar']?.toString(),
      );

      // Set live chat mode
      _isLiveChatMode = true;
      ChatState.instance.setLiveChatMode(true);

      // "<name> joined the chat" - not again for the same person (a repeat
      // after a reconnect), with "They can see your conversation so far"
      // after an AI handover.
      if (plan.announce) handover.addJoin(agentDetails, plan);

      // Notify flow engine of agent acceptance; the handover step's
      // waiting card goes (the join is already a line).
      _flowEngine.handleAgentAccepted(agentName);
      _flowEngine.clearHandoverUI();
      notifyListeners();
    });

    // No agents available
    _socketClient.on(SocketEvents.noAgentsAvailable, (_) {
      // A flow at its handover step, as the web widget does it: the owner's
      // fallback as the bot's message, then "Leave a message" (the flow
      // carries on once it is sent or skipped), or straight on when the
      // owner turned that off.
      if (_flowEngine.isAtHandover) {
        // The step says the owner's fallback itself and carries the flow
        // on when "leave a message" is off (special_handlers.dart).
        _flowEngine.clearHandoverUI();
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

    // Agent left: an AI handing the visitor to the team is not leaving them
    // (the Connecting line, not "<name> left"); an AI pausing an idle
    // visitor draws nothing (core/live_chat/handover_state.dart agentLeftKind).
    _socketClient.on(SocketEvents.agentLeft, (data) {
      if (!_isOwnSession(data)) return;
      // The AI left: no reply is coming, so no "took too long" either.
      _setAwaitingReply(false);
      final kind = handover.onAgentLeft(data, fallbackName: _currentAgent?.name);
      if (kind == AgentLeftKind.left) _currentAgent = null;
      if (kind == AgentLeftKind.handover) _talkToPersonRetired = true;
      if (kind != AgentLeftKind.ignore) _agentTyping = false;
      notifyListeners();
    });

    // Chat ended
    _socketClient.on(SocketEvents.chatEnded, (data) {
      if (!_isOwnSession(data)) return;
      _setAwaitingReply(false);
      // The same end again (an agent's double click, an AI close racing a
      // person's): one "Chat ended" line, not two (web endedSinceLastLive).
      if (LiveEvents.endedSinceLastLive(ChatState.instance.getRecordForServer())) return;
      // Its own id: never the session's, or a second live chat's end would
      // merge into the first one's entry (web agentListeners.ts).
      final msgId = LiveEvents.eventId('agent-chat-ended');
      final systemMessage = SystemMessageRecord(
        id: msgId,
        time: DateTime.now(),
        text: 'Chat has ended',
        kind: 'agent-chat-ended',
      );
      _addMessageToRecord(systemMessage);

      // Add to ChatState record, as the web records it (it closes the
      // live episode for a restart).
      ChatState.instance.pushToRecord(RecordEntry(
        id: msgId,
        shape: 'agent-chat-ended',
        type: 'agent-chat-ended',
        text: 'Chat has ended',
      ));

      // Add to transcript
      ChatState.instance.addToTranscript('bot', 'Chat has ended');

      // Clear agent state and live chat mode
      _currentAgent = null;
      _isLiveChatMode = false;
      _agentTyping = false;
      ChatState.instance.setLiveChatMode(false);

      // A flow at its handover step goes on from it; otherwise the
      // conversation is over (the post-chat redirect may follow).
      final flowGoesOn = _flowEngine.isAtHandover;
      _flowEngine.handleChatEnded();
      if (!flowGoesOn) postChatRedirect.conversationEnded();
      notifyListeners();
    });

    // Blocked by the workspace, mid-chat or at the handshake: the dots stop,
    // nobody is here (handover and liveChat close the rest).
    _socketClient.on(SocketEvents.visitorBlocked, (data) {
      if (!_isOwnSession(data)) return;
      _setAwaitingReply(false);
      _currentAgent = null;
      _agentTyping = false;
      _suggestions = const [];
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
      _awaitReplyTimer = Timer(AgentBotParser.awaitReply, () {
        _awaitReplyTimer = null;
        _awaitingReply = false;
        // Say so, instead of silently dropping the dots (web
        // agentListeners.ts). On screen only, not in the record.
        final notice = AgentBotParser.replyTimeoutNotice();
        _addMessageToRecord(SystemMessageRecord(id: notice.id, time: DateTime.now(), text: notice.text, kind: 'reply-timeout'));
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
    final shown = [..._record, ...paginatedMessages];
    final resumed = shown.any((m) =>
        (m is AgentMessageRecord && m.id.startsWith('agent-greeting-')) || m is UserMessageRecord);
    // A restored chat a person has (the AI handed it on): not the AI.
    if (!(resumed && handover.personInChat)) {
      _currentAgent = Agent(id: details.id, name: details.name, avatar: bot.avatar);
    }
    // Visitor messages go the live way from the start.
    _isLiveChatMode = true;
    ChatState.instance.setLiveChatMode(true);

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

    // Paused for inactivity; a later message from the visitor reopens it.
    // The line and its record entry are the handover's
    // (core/live_chat/handover_lifecycle.dart onInactiveClose).
    _socketClient.on(SocketEvents.aiAgentInactiveClose, (data) {
      if (!_isOwnSession(data)) return;
      _setAwaitingReply(false);
      _suggestions = const [];
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

  /// "Helpful?" on an AI answer (core/agent/answer_feedback.dart): kept on
  /// the message and on its record entry, as the web keeps it, and sent.
  void sendAnswerFeedback(String agentMessageId, AnswerFeedback feedback) {
    _updateMessage(agentMessageId, (m) => m is AgentMessageRecord ? m.copyWith(feedback: feedback) : null);
    ChatState.instance.setAnswerFeedback(agentMessageId, feedback.toJson());
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

  /// Change every message on screen that [change] answers for (the
  /// handover lines settling): in the record and in the paginated list.
  void _updateAllMessages(RecordItem? Function(RecordItem) change) {
    var changed = false;
    for (var i = 0; i < _record.length; i++) {
      final next = change(_record[i]);
      if (next != null) {
        _record[i] = next;
        changed = true;
      }
    }
    final shown = _paginationController?.state.visibleMessages ?? const <RecordItem>[];
    for (final m in shown) {
      final next = change(m);
      if (next != null) {
        _paginationController!.updateMessage(next);
        changed = true;
      }
    }
    if (changed) notifyListeners();
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
    // A message arriving (a bot step, a person's or the AI's message).
    sounds.rowAdded(message.toJson());

    // Also add to pagination controller if available
    if (_paginationController != null) {
      _paginationController!.addMessage(message);
    }
  }

  /// Setup flow engine listeners
  void _setupFlowEngineListeners() {
    _flowEngine.addListener(_onFlowEngineChange);

    // The flow's end is the conversation's end (the post-chat redirect).
    _flowEngine.isFlowCompleteStream.listen((_) => postChatRedirect.conversationEnded());

    // The lines the flow's steps say (questions, answers, media, links),
    // as the web widget draws them.
    _flowEngine.botMessageStream.listen((messageData) {
      final text = messageData['text'] as String? ?? '';
      final nodeId = messageData['nodeId'] as String? ?? '';
      final media = <String, dynamic>{
        for (final k in _flowMediaKeys)
          if (messageData[k] != null && messageData[k] != '') k: messageData[k],
      };
      // A video, audio, file or HTML line shows the media, not its URL.
      final mediaOnly = media.containsKey('videoUrl') ||
          media.containsKey('audioUrl') ||
          media.containsKey('fileUrl') ||
          media.containsKey('html') ||
          media.containsKey('imageUrl');
      if (text.isEmpty && media.isEmpty) return;
      final id = 'bot_${nodeId}_${DateTime.now().millisecondsSinceEpoch}_${_lineSeq++}';
      if (nodeId.isNotEmpty) _rowNodes[id] = nodeId;
      _addMessageToRecord(BotMessageRecord(
        id: id,
        time: DateTime.now(),
        text: mediaOnly ? null : text,
        nodeData: media.isEmpty ? null : {...media, 'nodeId': nodeId},
      ));
      notifyListeners();
    });

    // The visitor's answers, as the steps record them (a choice's label,
    // a masked card number stays as typed in the chat).
    _flowEngine.userMessageStream.listen((messageData) {
      final text = messageData['text'] as String? ?? '';
      final nodeId = messageData['nodeId'] as String? ?? '';
      if (text.isEmpty) return;
      final id = 'user_${nodeId}_${DateTime.now().millisecondsSinceEpoch}_${_lineSeq++}';
      final now = DateTime.now();
      _addMessageToRecord(UserInputResponseRecord(id: id, time: now, text: text));
      if (nodeId.isNotEmpty) {
        _rowNodes[id] = nodeId;
        // What the answer answered, for the bot's tapback and "Edit"; a
        // score as the web reads it ("4/5").
        final score = _pendingScore;
        _pendingScore = null;
        delight.answered(
          id,
          AnswerOf(nodeId: nodeId, type: _nodeTypeOf(nodeId), text: score != null && score.nodeId == nodeId ? score.text : text),
          at: now,
        );
      }
      delight.conversationChanged();
      notifyListeners();
    });
  }

  /// The media and link fields a step's line may carry.
  static const _flowMediaKeys = [
    'imageUrl',
    'videoUrl',
    'audioUrl',
    'fileUrl',
    'fileName',
    'html',
    'linkUrl',
    'linkLabel',
    'openInNewTab',
    'mediaNodeId',
    'allowDownload',
    'sources',
  ];

  /// Makes line ids unique within a millisecond.
  int _lineSeq = 0;

  /// A step's type, by its id.
  String _nodeTypeOf(String nodeId) {
    for (final n in _flowEngine.steps) {
      if (n['id']?.toString() == nodeId) return (n['type'] ?? '').toString();
    }
    return '';
  }

  /// "Edit": the conversation cut from [index] on (the question's own rows
  /// and what came after), the engine then asks the question again.
  void _cutRecordFrom(int index) {
    if (index < 0 || index >= _record.length) return;
    final gone = _record.sublist(index);
    _record.removeRange(index, _record.length);
    for (final m in gone) {
      _rowNodes.remove(m.id);
      _paginationController?.deleteMessage(m.id);
    }
    notifyListeners();
  }

  /// "Edit" under the visitor's latest answer: back to that question.
  Future<bool> changeAnswer() => delight.changeAnswer();

  /// The composer's text changed: the waiting nudge waits while something is
  /// typed, and the person in the chat sees the draft (never a secret field;
  /// web index.ts updateVisitorDraft).
  void composerChanged(String text, {bool secret = false}) {
    delight.setComposerValue(text);
    final person = _isLiveChatMode && handover.personInChat;
    if (!secret && TypingPreview.draftPreviewOn(_serverCustomizations, person)) {
      _drafts.update(text);
    } else {
      _drafts.clear();
    }
  }

  /// Any touch in the chat: the visitor is busy here (the waiting nudge waits).
  void noteChatActivity() => delight.noteActivity();

  /// Handle flow engine state changes
  void _onFlowEngineChange() {
    // Where the visitor stands: asked while the handover waits for a person.
    final ui = _flowEngine.currentUIState;
    final waiting = ui is HumanHandoverUIState && ui.state == HandoverState.waitingForAgent && !_isLiveChatMode;
    // The 20s waiting signal while the step waits for a person.
    handover.setWaitingForPerson(waiting, _flowEngine.handoverNodeData);
    if (waiting) {
      liveChat.startQueuePoll();
      liveChat.startWaitTimer(_flowEngine.handoverNodeData, ChatState.instance.workspaceId);
    } else {
      liveChat.stopQueuePoll();
      liveChat.stopWaitTimer();
    }
    // The nudge's question, and "Edit" once the bot is quiet again.
    delight.stepChanged(
      _flowEngine.isWaitingForInput ? _flowEngine.currentNodeId : null,
      _flowEngine.isWaitingForInput ? _flowEngine.currentNodeType : null,
      loading: _flowEngine.isProcessing,
    );
    delight.conversationChanged();
    notifyListeners();
  }

  /// Feeds a fetched-chatbot-data payload as the socket would (tests).
  @visibleForTesting
  void debugHandleChatbotData(Map<String, dynamic> data) {
    _handleChatbotData(data);
    notifyListeners();
  }

  /// Handle incoming chatbot data (steps and edges)
  void _handleChatbotData(Map<String, dynamic> data) {
    final chatbotData = data['chatbotData'] as Map<String, dynamic>?;
    final kb = data['knowledgeBaseData'];
    _helpCentreData = kb is Map ? KnowledgeBaseData.fromJson(Map<String, dynamic>.from(kb)) : KnowledgeBaseData.empty;
    // As sent, for the articles offered while waiting and the quiz.
    waiting.setKnowledgeBase(kb);
    // The home screen's help card and ask box.
    home.setKnowledgeBase(kb);
    if (chatbotData != null) {
      liveChat.setChatbotData(chatbotData);
      // The owner's post-chat redirect (checked when it is followed).
      _redirectUrl = chatbotData['redirectUrl'];
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

      // The bot's bookings: a calendar's taken slots (web index.ts setCalendarBookings).
      _flowEngine.setCalendarBookings(chatbotData['calendarBookings']);

      // Parse server customizations (theme colors, bot name, etc.)
      _rawCustomizations = chatbotData['customizations'] as Map<String, dynamic>?;
      _personalize();
      _applyWidgetLanguage();
      // The owner's font over the theme's (core/customization/owner_font.dart).
      chatFont.update(_serverCustomizations?['font'], themeFont: widgetTheme.font, themeFontRole: widgetTheme.fontRole);
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
        if (_sessionRestored) _resumeRestoredAgentChat();
        notifyListeners();
        return;
      }

      _logger.debug('Loaded ${_steps.length} steps and ${_edges.length} edges');

      // Start flow engine if we got steps and have a session - once per
      // session (this data comes again on every reconnect). A session
      // restored from the device is picked back up instead (its live chat,
      // or its wait for a person), never run again from the top.
      if (_steps.isNotEmpty && _chatSessionId != null && _flowStartedFor != _chatSessionId) {
        if (_sessionRestored) {
          final resolvedName = _serverCustomizations?['botName']?.toString() ?? _serverCustomizations?['logoText']?.toString() ?? '';
          if (resolvedName.isNotEmpty) ChatState().setVariable('_botName', resolvedName);
          _resumeRestoredFlow();
          notifyListeners();
          return;
        }
        _flowStartedFor = _chatSessionId;
        _flowEngine.initialize(
          chatSessionId: _chatSessionId!,
          visitorId: _visitorId ?? '',
          botId: botId,
          workspaceId: serverWorkspaceId,
          stepsData: _steps,
          edgesData: _edges,
          customizations: _serverCustomizations,
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

  /// A flow chat restored from the device, once: ask the server where its
  /// live chat stands and pick it back up - a person, the wait for one, or
  /// carry on from the handover step - instead of running the flow again
  /// (a second initiate-handover would open a second ticket). Anything else
  /// resumes at the step it was on.
  Future<void> _resumeRestoredFlow() async {
    final sessionId = _chatSessionId;
    if (sessionId == null || _steps.isEmpty || _flowStartedFor == sessionId) return;
    _flowStartedFor = sessionId;
    // The step it was on, read before the engine is set up again.
    final savedNodeId = ChatState.instance.currentNodeId;
    _flowEngine.initialize(
      chatSessionId: sessionId,
      visitorId: _visitorId ?? '',
      botId: botId,
      workspaceId: _serverWorkspaceId,
      stepsData: _steps,
      edgesData: _edges,
      customizations: _serverCustomizations,
    );
    ChatState.instance.setCurrentNodeId(savedNodeId);
    RestoreStep step;
    try {
      step = await handover.resumeRestored(steps: _steps, agentBot: false);
    } catch (e) {
      _logger.debug('Live chat restore failed: $e');
      step = RestoreStep.start;
    }
    if (step == RestoreStep.start) {
      if (savedNodeId != null) {
        _flowEngine.resumeFromNode(savedNodeId);
      } else {
        _flowEngine.start();
      }
    }
    notifyListeners();
  }

  /// An agent bot's chat restored from the device, once: a person the AI
  /// handed it to is picked back up (the header and the composer stay theirs).
  Future<void> _resumeRestoredAgentChat() async {
    final sessionId = _chatSessionId;
    if (sessionId == null || _flowStartedFor == sessionId || !_socketClient.isConnected) return;
    _flowStartedFor = sessionId;
    try {
      await handover.resumeRestored(steps: _steps, agentBot: true);
    } catch (e) {
      _logger.debug('Live chat restore failed: $e');
    }
    notifyListeners();
  }

  /// Sign a user in after construction, or out with `null` (RN's `user`
  /// prop, iOS `identify(user:)`, Android `Conferbot.identify`).
  ///
  /// The next response records carry the user as `visitorContext` (with its
  /// identity `hash`), "Your requests" is read again for them (a signed-out
  /// user's list is dropped), and the greeting card's signed-in fact follows.
  /// With no stored visitor id, the user's id is the next handshake's visitor.
  void identify(ConferBotUser? user) {
    _user = user;
    ChatState.instance.visitorContext = user?.toVisitorContext();
    if (_visitorId == null) _socketClient.visitorId = user?.id;
    unawaited(requests.onUserChanged());
    // "Hi {{first_name|there}}" again for whoever it is now.
    _personalize();
    notifyListeners();
  }

  /// Open chat and start the flow
  /// If a previous session was restored, it will resume from where it left off
  Future<void> openChat() async {
    // The visitor's Sound on / off, as they left it.
    unawaited(sounds.load());
    // Not before start-up is done: a session being restored would be
    // replaced by a new one (and its handover ticket left behind).
    if (config.autoConnect && !_started.isCompleted) await _started.future;
    // The chat opening: the visitor's requests again, at most every 15s.
    requests.onChatShown();
    // What the device remembers for "Welcome back".
    unawaited(home.load());
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
        _markOpen();
        _unreadCount = 0;
        _startAgentBotChat();
        _resumeRestoredAgentChat();
        notifyListeners();
        return;
      }

      // The flow is picked back up once (its live chat or its wait for a
      // person from the server first); the bot data's arrival does it when
      // it comes later.
      if (_steps.isNotEmpty && _socketClient.isConnected) _resumeRestoredFlow();

      _markOpen();
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
        _markOpen();
        _unreadCount = 0;
        _startAgentBotChat();
        notifyListeners();
        return;
      }

      // Initialize and start the flow engine (never for a blocked visitor)
      if (_steps.isNotEmpty && liveChat.blocked == null) {
        _flowEngine.initialize(
          chatSessionId: _chatSessionId!,
          visitorId: _visitorId ?? '',
          botId: botId,
          workspaceId: _serverWorkspaceId,
          stepsData: _steps,
          edgesData: _edges,
        );
        _flowStartedFor = _chatSessionId;
        _flowEngine.start();
      }
    }

    _markOpen();
    _unreadCount = 0;
    liveChat.reportReceipts(chatVisible: _chatOnScreen);
    notifyListeners();
  }

  /// The chat opening: the launcher sound, or the pack's open.
  void _markOpen() {
    if (!_isOpen) sounds.play(SoundEvent.open);
    _isOpen = true;
  }

  /// Sound on / off from the chat menu, kept on the device.
  void toggleSound() => sounds.toggle();

  /// Close chat
  void closeChat() {
    // The launcher sound, or the pack's close.
    if (_isOpen) sounds.play(SoundEvent.close);
    _isOpen = false;
    requests.onChatShown();

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
    // Web widget parity: a choice step keeps its chips under its question,
    // disabled, with the pick highlighted. The question and the visitor's
    // answer are lines the step itself says (botMessageStream /
    // userMessageStream).
    final uiState = _flowEngine.currentUIState;
    final nodeId = _flowEngine.currentNodeId;
    List<Map<String, dynamic>>? choices;
    if (uiState is SingleChoiceUIState) {
      choices = [for (final c in uiState.choices) {'id': c.id, 'text': c.text}];
    } else if (uiState is MultipleChoiceUIState) {
      choices = [for (final o in uiState.options) {'id': o.id, 'text': o.text}];
    }
    if (choices != null && nodeId != null && _flowEngine.isWaitingForInput) {
      String? selected;
      if (response is Map) {
        final ids = response['buttonIds'];
        selected = ids is List
            ? choices.where((c) => ids.map((e) => '$e').contains(c['id'])).map((c) => c['text']).join(', ')
            : (response['label'] ?? response['text'] ?? response['value'])?.toString();
      } else {
        selected = response?.toString();
      }
      _attachChoices(nodeId, choices, selected);
    }

    // A score answer as the web reads it ("4/5"), for the bot's tapback.
    if (uiState is RatingUIState && nodeId != null) {
      final raw = response is Map ? (response['value'] ?? response['rating']) : response;
      final v = raw is num ? raw : num.tryParse('$raw');
      final text = Delight.scoreText(_flowEngine.currentNodeType ?? '', v, uiState.maxValue);
      _pendingScore = text.isEmpty ? null : (nodeId: nodeId, text: text);
    }

    _flowEngine.submitResponse(response);
    // A name the flow asked for: "Welcome back, <name>" and greet by name.
    final asked = ChatState.instance.userMetadata.name;
    if (asked != null && asked.isNotEmpty) unawaited(home.rememberName(asked));
  }

  /// The choice chips under the step's question line (the last line it said).
  void _attachChoices(String nodeId, List<Map<String, dynamic>> choices, String? selected) {
    for (var i = _record.length - 1; i >= 0; i--) {
      final m = _record[i];
      if (m is BotMessageRecord && m.id.startsWith('bot_${nodeId}_') && m.nodeData == null) {
        final updated = BotMessageRecord(
          id: m.id,
          time: m.time,
          text: m.text,
          nodeData: {'choices': choices, 'selected': selected},
        );
        _record[i] = updated;
        _paginationController?.updateMessage(updated);
        notifyListeners();
        return;
      }
    }
  }

  /// Send text message
  /// In live chat mode, sends as a visitor live message to the agent.
  /// Otherwise, submits as a flow response or direct socket message.
  Future<void> sendMessage(String text) async {
    if (_chatSessionId == null || text.trim().isEmpty) {
      return;
    }

    // "play" while waiting for a person opens the games instead of being sent.
    if (waiting.interceptPlay(text)) {
      notifyListeners();
      return;
    }

    // The pack's send sound; the agent's typing preview goes.
    sounds.play(SoundEvent.send);
    _drafts.clear();
    delight.setComposerValue('');

    // What they type in a live or agent chat is what they came for, for
    // "Welcome back" (web special.ts _handleHumanHandoverInputSubmit).
    if (_isLiveChatMode || _agentBot != null) unawaited(home.rememberText(text));

    // Live chat mode: send as visitor message to agent
    if (_isLiveChatMode) {
      await _sendLiveChatMessage(text);
      return;
    }

    // Waiting for a person at the handover step: a live message, for
    // whoever joins (web special.ts, the handover queue; #76).
    final ui = _flowEngine.currentUIState;
    if (ui is HumanHandoverUIState && ui.state == HandoverState.waitingForAgent) {
      await _sendLiveChatMessage(text);
      return;
    }

    // A step waiting for the visitor takes it as its answer
    if (_flowEngine.isWaitingForInput) {
      submitResponse(text);
      return;
    }
    // A flow still running: the step's own input decides what comes next.
    if (_flowEngine.currentNodeId != null && !_flowEngine.isFlowComplete) return;

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
    postChatRedirect.reset();
    liveChat.reset();
    requests.reset();
    home.reset();
    handover.reset();
    waiting.reset();
    delight.reset();
    _rowNodes.clear();
    _flowStartedFor = null;
    _talkToPersonRetired = false;
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

  /// "Start a new chat" once a live chat has ended: a fresh conversation,
  /// opened. Not for a blocked visitor (the server refuses them).
  Future<void> startNewChat() async {
    if (liveChat.blocked != null) return;
    resetConversation();
    await openChat();
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
    I18n.languageListenable.removeListener(_onLanguage);
    // Persist state before disposing
    if (config.enablePersistence) {
      ChatState.instance.persistNow();
    }

    _flowEngine.removeListener(_onFlowEngineChange);
    liveChat.removeListener(notifyListeners);
    liveChat.dispose();
    handover.dispose();
    waiting.removeListener(notifyListeners);
    waiting.dispose();
    _socketClient.onResponseRecord = null;
    requests.removeListener(notifyListeners);
    requests.dispose();
    home.dispose();
    sounds.removeListener(notifyListeners);
    sounds.dispose();
    delight.removeListener(notifyListeners);
    delight.dispose();
    removeListener(postChatRedirect.update);
    postChatRedirect.removeListener(notifyListeners);
    postChatRedirect.dispose();
    chatFont.removeListener(notifyListeners);
    chatFont.dispose();
    _drafts.clear();
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

/// The flow engine as the handover lifecycle uses it.
class _EngineHandoverFlow implements HandoverFlow {
  _EngineHandoverFlow(this._engine);
  final NodeFlowEngine Function() _engine;

  @override
  bool get atHandover => _engine().isAtHandover;

  @override
  Map<String, dynamic>? get handoverNodeData => _engine().handoverNodeData;

  @override
  bool waitAt(String nodeId, {required bool waiting}) {
    final step = _engine().steps.where((s) => s['id'] == nodeId).firstOrNull;
    final data = step?['data'] is Map ? Map<String, dynamic>.from(step!['data'] as Map) : const <String, dynamic>{};
    final message = LiveChat.plainText(data['handoverMessage']?.toString() ?? '');
    return _engine().waitAt(
      nodeId,
      waiting
          ? HumanHandoverUIState(
              state: HandoverState.waitingForAgent,
              handoverMessage: message.isEmpty ? null : message,
              nodeId: nodeId,
            )
          : null,
    );
  }

  @override
  void continueFlow() => _engine().continueAfterHandover();

  @override
  void resumeFrom(String nodeId) => _engine().resumeFromNode(nodeId);

  @override
  void stop() => _engine().reset();
}
