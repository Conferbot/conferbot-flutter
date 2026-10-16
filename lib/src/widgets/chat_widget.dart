import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conferbot_provider.dart';
import '../providers/knowledge_base_provider.dart';
import '../models/socket_events.dart';
import '../models/knowledge_base.dart';
import '../models/agent.dart';
import '../services/connectivity_service.dart';
import '../services/message_queue_service.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import '../ui/widgets/node_widgets.dart';
import '../core/nodes/node_ui_state.dart';
import 'chat_header.dart';
import 'message_list.dart';
import 'message_bubble.dart';
import 'agent_reply.dart';
import '../models/message.dart';
import 'chat_input.dart';
import 'chat_bottom_bar.dart';
import 'typing_indicator.dart';
import 'offline_indicator.dart';
import 'knowledge_base/knowledge_base_screen.dart';
import 'handover/handover.dart';
import 'live_chat_cards.dart';
import '../core/customization/customizations.dart';
import '../core/i18n/i18n.dart';
import '../core/customization/chat_background.dart';
import 'chat_background.dart';
import '../core/live_chat/live_chat.dart';
import '../core/state/chat_state.dart';
import '../core/help_centre/help_centre.dart';
import '../core/live_chat/email_transcript.dart';
import '../core/requests/requests.dart';
import 'requests/requests_portal_view.dart';
import 'waiting/games_card_view.dart';
import 'waiting/wait_help_card.dart';
import 'home/home_screen_view.dart';
import 'home/view_switch.dart';
import '../core/home/home.dart' show HomeMascot, HomeView;
import 'package:file_picker/file_picker.dart';

/// Complete drop-in chat widget with node rendering support
/// Now includes:
/// - Pagination for efficient handling of long conversations
/// - Knowledge Base integration for help center access
/// - Offline message queue with delivery status indicators
/// - Human handover with pre-chat form, queue status, and post-chat survey
class ChatWidget extends StatefulWidget {
  final String? title;
  final String? placeholder;
  final bool showTimestamps;
  final bool enableAttachments;
  final ConferBotTheme? theme;

  /// Whether to enable message pagination
  final bool enablePagination;

  /// Pagination configuration
  final MessageListPaginationConfig? paginationConfig;

  /// The help centre (knowledge base) button, as an override of the
  /// owner's setting:
  ///  - `null` (default): follow the server. Shown while the owner's
  ///    `enableKnowledgeBase` is on and a published article exists, as on
  ///    the web widget.
  ///  - `false`: never shown.
  ///  - `true`: always shown, even with the owner's switch off.
  final bool? showKnowledgeBase;

  /// Optional callback when an article is inserted into chat
  final ValueChanged<KnowledgeBaseArticle>? onArticleInsert;

  /// Whether to show offline indicator banner
  final bool showOfflineIndicator;

  /// Whether to show delivery status on user messages
  final bool showDeliveryStatus;

  /// Whether to show pre-chat form for handover
  final bool showHandoverPreChatForm;

  /// Whether to show post-chat survey after handover
  final bool showHandoverPostChatSurvey;

  /// Max wait time in minutes for handover
  final int handoverMaxWaitMinutes;

  /// Callback when handover survey is submitted
  final ValueChanged<SurveyResult>? onHandoverSurveySubmit;

  /// The home screen's mascot spot, above the greeting (HomeScreenView.mascotBuilder): given the owner's mascot. None by default, as on the web.
  final Widget Function(BuildContext context, HomeMascot mascot)? homeMascotBuilder;

  const ChatWidget({
    super.key,
    this.title,
    this.placeholder,
    this.showTimestamps = false,
    this.enableAttachments = false,
    this.theme,
    this.enablePagination = true,
    this.paginationConfig,
    this.showKnowledgeBase,
    this.onArticleInsert,
    this.showOfflineIndicator = true,
    this.showDeliveryStatus = true,
    this.showHandoverPreChatForm = true,
    this.showHandoverPostChatSurvey = true,
    this.handoverMaxWaitMinutes = 5,
    this.onHandoverSurveySubmit,
    this.homeMascotBuilder,
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  bool _isAgentTyping = false;
  bool _showKnowledgeBase = false;
  KnowledgeBaseProvider? _kbProvider;

  // Handover state
  QueueInfo? _queueInfo;
  bool _showHandoverOverlay = false;

  final ConnectivityService _connectivity = ConnectivityService.instance;
  final MessageQueueService _messageQueue = MessageQueueService.instance;

  // The composer's focus: "Ask another way" under an AI answer puts the cursor there.
  final FocusNode _composerFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupListeners();
      context.read<ConferBotProvider>().openChat();
      _initKnowledgeBase();
    });
  }

  void _setupListeners() {
    final provider = context.read<ConferBotProvider>();

    // Agent typing status
    provider.on(SocketEvents.agentTypingStatus, (data) {
      if (data != null && data is Map<String, dynamic>) {
        setState(() {
          _isAgentTyping = data['isTyping'] as bool? ?? false;
        });
      }
    });

    // Queue status updates
    provider.on(SocketEvents.queueStatusUpdate, (data) {
      if (data != null && data is Map<String, dynamic>) {
        setState(() {
          _queueInfo = QueueInfo.fromJson(data);
        });
      }
    });

    // Agent accepted - show connected state
    provider.on(SocketEvents.agentAccepted, (data) {
      setState(() {
        _queueInfo = null; // Clear queue info when connected
      });
    });

    // Agent left
    provider.on(SocketEvents.agentLeft, (data) {
      // Could trigger post-chat survey here
    });

    // No agents available
    provider.on(SocketEvents.noAgentsAvailable, (data) {
      // Handle no agents available state
    });

    // Listen for connectivity changes
    _connectivity.addListener(_onConnectivityChange);
    _messageQueue.addListener(_onQueueChange);
  }

  void _onConnectivityChange() {
    if (mounted) setState(() {});
  }

  void _onQueueChange() {
    if (mounted) setState(() {});
  }

  ConferBotProvider? _chatProvider;

  void _initKnowledgeBase() {
    if (!mounted) return;
    // AI sources and rich article cards open articles through this chat.
    _chatProvider = context.read<ConferBotProvider>();
    _chatProvider!.articleOpener = _openArticleById;
    // The help card's articles, also those the help centre does not list.
    _chatProvider!.waitArticleOpener = _openWaitArticle;
    _chatProvider!.composerFocuser = () {
      if (mounted) _composerFocus.requestFocus();
    };
  }

  /// Is the help centre offered? The app's override first, else the owner's
  /// setting and the articles the server sent (core/help_centre).
  bool _helpCentreVisible(ConferBotProvider provider) => HelpCentre.isVisible(
        override: widget.showKnowledgeBase,
        customizations: provider.serverCustomizations,
        data: provider.helpCentreData,
      );

  KnowledgeBaseProvider _ensureKbProvider(ConferBotProvider provider) {
    final kb = _kbProvider ??= KnowledgeBaseProvider(
      apiKey: provider.apiKey,
      botId: provider.botId,
      baseUrl: provider.baseUrl,
      visitorId: provider.visitorId,
      initialData: provider.helpCentreData,
    );
    // The owner's hideRecentArticles (the list itself needs articles).
    kb.showRecentArticles = provider.serverCustomizations?['hideRecentArticles'] != true;
    kb.setInitialData(provider.helpCentreData);
    kb.setVisitorId(provider.visitorId ?? '');
    return kb;
  }

  /// The help centre comes up: the home's help view when the owner has a
  /// home screen (Back returns where it was opened from), else over the chat.
  void _showHelpCentre(ConferBotProvider provider, {String? categoryId}) {
    if (provider.homeModel != null) {
      provider.home.showHelp(categoryId: categoryId);
    } else {
      setState(() {
        _showKnowledgeBase = true;
      });
    }
  }

  void _openKnowledgeBase([String? categoryId]) {
    final provider = context.read<ConferBotProvider>();
    if (!_helpCentreVisible(provider)) return;
    final kb = _ensureKbProvider(provider);
    _showHelpCentre(provider, categoryId: categoryId);
    kb.initialize().then((_) {
      if (categoryId != null) kb.selectCategory(categoryId);
    });
  }

  /// An AI source or a rich article card: the article, in the help centre.
  void _openArticleById(String articleId) {
    if (!mounted) return;
    final provider = context.read<ConferBotProvider>();
    if (!_helpCentreVisible(provider)) return;
    final kb = _ensureKbProvider(provider);
    _showHelpCentre(provider);
    kb.openArticle(articleId);
  }

  /// An article from the help card while waiting: from the help centre data
  /// when it is there, else fetched from the server by id (the server picks
  /// articles the help centre may not list, or shows while it is off).
  void _openWaitArticle(String articleId) {
    if (!mounted || articleId.isEmpty) return;
    final provider = context.read<ConferBotProvider>();
    final kb = _ensureKbProvider(provider);
    _showHelpCentre(provider);
    kb.openArticle(articleId);
  }

  void _closeKnowledgeBase() {
    final provider = context.read<ConferBotProvider>();
    // The home's help view goes back where it was opened from.
    if (provider.home.view == HomeView.help) provider.home.leaveHelp();
    setState(() {
      _showKnowledgeBase = false;
    });
  }

  /// The view on screen: the help centre over the chat, else the home's
  /// (home, conversation or help centre; always the conversation without a home).
  HomeView _view(ConferBotProvider provider) {
    if (_showKnowledgeBase && _kbProvider != null) return HomeView.help;
    final v = provider.home.viewFor(provider.serverCustomizations);
    // The help centre needs its data: the conversation until it is there.
    if (v == HomeView.help && _kbProvider == null) return provider.homeModel != null ? HomeView.home : HomeView.chat;
    return v;
  }

  HomeView? _lastView;

  /// Back (the system's, or a view's own): a step back in the help centre,
  /// the help centre to where it came from, the conversation to the home.
  void _back(ConferBotProvider provider) {
    if (provider.requestsOpen) return; // the portal steps back itself
    final view = _view(provider);
    if (view == HomeView.help) {
      final kb = _kbProvider;
      if (kb != null && kb.canGoBack) {
        kb.goBack();
      } else {
        _closeKnowledgeBase();
      }
      return;
    }
    if (view == HomeView.chat && provider.home.back()) return;
    _close(provider);
  }

  /// Close the chat (the header's or the home's cross): past every view.
  void _close(ConferBotProvider provider) {
    provider.closeChat();
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  void _handleArticleInsert(KnowledgeBaseArticle article) {
    final provider = context.read<ConferBotProvider>();

    // Send article reference as a message
    final articleText = t('sdk.kb.foundArticle', {'title': article.title});
    provider.sendMessage(articleText);

    // Call custom callback if provided
    widget.onArticleInsert?.call(article);

    // Close knowledge base
    _closeKnowledgeBase();
  }

  Future<void> _handleRetryAll() async {
    await _messageQueue.retryFailedMessages();
    await _messageQueue.processQueue();
  }

  // Handover handlers
  void _handlePreChatSubmit(PreChatFormResult result) {
    final provider = context.read<ConferBotProvider>();

    // Emit pre-chat form data via socket
    provider.emit(SocketEvents.submitPreChatForm, {
      'visitorData': result.toJson(),
    });

    // Submit response to advance the flow
    provider.submitResponse(result.toJson());
  }

  void _handleHandoverCancel() {
    final provider = context.read<ConferBotProvider>();

    // Leave the queue on the server too (queue-self-resolve), then the flow
    // carries on. The server has no cancel-handover.
    provider.leaveQueue();

    setState(() {
      _queueInfo = null;
    });
  }

  void _handleHandoverTimeout() {
    final provider = context.read<ConferBotProvider>();

    // The max wait passed: the server decides (handover-timeout with the
    // step's assignment, as the web's maxWaitTimer sends it).
    final sessionId = provider.chatId;
    if (sessionId != null) {
      provider.emit(
        SocketEvents.handoverTimeout,
        LiveChat.handoverTimeoutPayload(sessionId, provider.flowEngine.handoverNodeData, ChatState.instance.workspaceId),
      );
    }

    setState(() {
      _queueInfo = null;
    });
  }

  void _handleSurveySubmit(SurveyResult result) {
    final provider = context.read<ConferBotProvider>();

    // The rating as the web widget sends it (submit-chat-rating); the
    // server has no submit-post-chat-survey.
    final sessionId = provider.chatId;
    if (sessionId != null) {
      provider.emit('submit-chat-rating', LiveChat.ratingPayload(sessionId, 'stars', result.rating, result.feedback));
    }

    // Call custom callback if provided
    widget.onHandoverSurveySubmit?.call(result);
  }

  void _handleSurveySkip() {
    final provider = context.read<ConferBotProvider>();

    // Submit empty survey to advance flow
    provider.submitResponse({'skipped': true});
  }

  void _handleEndAgentChat() {
    final provider = context.read<ConferBotProvider>();

    // The server has no visitor end-chat (only an agent ends a live chat).
    // Still in the queue: leave it (queue-self-resolve closes only a waiting
    // ticket; with a person on it the visitor stays).
    provider.leaveQueue();
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChange);
    _messageQueue.removeListener(_onQueueChange);
    _chatProvider?.articleOpener = null;
    _chatProvider?.waitArticleOpener = null;
    _chatProvider?.composerFocuser = null;
    _composerFocus.dispose();
    _kbProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();
    // A theme set to "auto" follows the phone's light / dark setting.
    final systemDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) provider.setSystemDarkMode(systemDark);
    });
    // Use server-themed colors when available, fall back to widget theme or defaults
    final effectiveTheme = provider.serverCustomizations != null
        ? provider.serverTheme
        : (widget.theme ?? defaultTheme);

    final view = _view(provider);
    // The home came into view: its requests card reads again.
    if (view == HomeView.home && _lastView != HomeView.home) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) provider.home.homeShown();
      });
    }
    _lastView = view;

    final Widget content = switch (view) {
      HomeView.home => _buildHome(provider),
      HomeView.help => ChangeNotifierProvider.value(
          value: _kbProvider!,
          child: KnowledgeBaseScreen(
            title: t('home.helpCentre'),
            onClose: _closeKnowledgeBase,
            onArticleInsertToChat: _handleArticleInsert,
            theme: effectiveTheme,
          ),
        ),
      HomeView.chat => Column(
          children: [
            _buildHeader(provider, effectiveTheme),
            // Offline indicator banner
            if (widget.showOfflineIndicator)
              OfflineIndicator(
                theme: effectiveTheme,
                showPendingCount: true,
                autoHide: true,
                onRetryAll: _handleRetryAll,
              ),
            Expanded(
              child: _buildChatContent(provider, effectiveTheme),
            ),
            _buildInputArea(provider, effectiveTheme),
          ],
        ),
    };

    return PopScope(
      // The system back: the help centre and the conversation step back
      // (to the home when there is one); the home closes the chat.
      canPop: view == HomeView.home || (view == HomeView.chat && provider.homeModel == null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(provider);
      },
      child: Scaffold(
        backgroundColor: view == HomeView.home ? homeColorOf(provider.homePalette.page) : effectiveTheme.colors.background,
        body: _withRequests(
          provider,
          effectiveTheme,
          ViewSwitch(
            view: view,
            transition: provider.serverCustomizations?['viewTransition'],
            direction: provider.serverCustomizations?['viewTransitionDirection'],
            child: content,
          ),
        ),
      ),
    );
  }

  /// The home screen (core/home, widgets/home): what the visitor sees first
  /// when the owner has one.
  Widget _buildHome(ConferBotProvider provider) {
    final model = provider.homeModel!;
    return HomeScreenView(
      model: model,
      palette: provider.homePalette,
      fontFamily: provider.customization?.fontFamily,
      rawArticles: provider.home.knowledgeBase.rawArticles,
      hasAgent: provider.agentBot != null,
      onClose: () => _close(provider),
      onShowChat: ([text]) => provider.home.showChat(text),
      onOpenArticle: _openArticleById,
      onShowHelp: ([categoryId]) => _openKnowledgeBase(categoryId),
      onOpenRequests: ([id]) => provider.openRequests(id),
      searchArticleText: provider.home.searchArticleText,
      mascotBuilder: widget.homeMascotBuilder,
    );
  }

  /// "Your requests" opened from the chat menu, over the conversation
  /// (core/requests); Back and Android's back step back.
  Widget _withRequests(ConferBotProvider provider, ConferBotTheme theme, Widget chat) {
    // Always a Stack, so the chat under it keeps its place.
    return Stack(
      children: [
        Positioned.fill(child: chat),
        if (provider.requestsOpen)
          Positioned.fill(
            child: RequestsPortalView(
              portal: provider.requests.portal,
              theme: theme,
              accent: requestsColorOf(requestsAccent(provider.serverCustomizations)),
              fontFamily: provider.customization?.fontFamily,
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(ConferBotProvider provider, ConferBotTheme theme) {
    // The header keeps the bot (never the agent), as the web widget does:
    // "Online" or the team's reply time under its name, plain "Online" once
    // a person is in the chat (core/live_chat/reply_time.dart).
    return ChatHeaderWithKB(
      title: provider.botName ?? widget.title ?? t('sdk.header.supportChat'),
      look: provider.serverCustomizations != null ? provider.customizations : null,
      subtitle: _getSubtitle(provider),
      statusText: provider.headerStatus,
      botAvatarUrl: provider.botAvatarUrl,
      onClose: () => _close(provider),
      // Back to the home screen, when the owner has one.
      onBack: provider.homeModel != null ? provider.home.showHome : null,
      showConnectionStatus: true,
      showKnowledgeBase: _helpCentreVisible(provider),
      onKnowledgeBaseTap: _openKnowledgeBase,
      // The chat menu: the conversation to the visitor's inbox (web
      // emailTranscript.ts), once there is one and the visitor is not blocked.
      onEmailTranscript: provider.chatSessionId != null && provider.visitorBlocked == null ? provider.openEmailTranscript : null,
      // "Your requests" once the visitor has one (web home card,
      // ts/home/requests/card.ts; there is no home screen yet).
      onRequests: provider.requests.hasRequests ? () => provider.openRequests() : null,
      requestsUnread: provider.requestsUnread,
      theme: provider.serverTheme,
      // Show handover indicator in header
      handoverIndicator: _buildHandoverIndicator(provider, theme),
    );
  }

  Widget? _buildHandoverIndicator(ConferBotProvider provider, ConferBotTheme theme) {
    final uiState = provider.currentUIState;
    if (uiState is! HumanHandoverUIState) return null;

    if (uiState.state == HandoverState.waitingForAgent) {
      return CompactQueueStatus(
        maxWaitMinutes: uiState.maxWaitTime ?? widget.handoverMaxWaitMinutes,
        queueInfo: _queueInfo,
        primaryColor: theme.colors.primary,
        theme: theme,
      );
    }

    return null;
  }

  Widget _buildChatContent(ConferBotProvider provider, ConferBotTheme theme) {
    return Stack(
      children: [
        // The bot's chat background (gradient, image, pattern) behind a see-through list.
        if (provider.serverCustomizations != null)
          Positioned.fill(
            // A widget theme paints it when the owner kept the default white.
            child: ChatBackgroundLayer(
              background: provider.customizations.surface != null
                  ? SolidBackground(provider.customizations.surface!)
                  : ChatBackgrounds.resolve(provider.serverCustomizations),
            ),
          ),
        // Message history list with interactive node rendered inline at bottom
        widget.enablePagination
            ? _buildPaginatedMessageList(provider, theme)
            : _buildSimpleMessageList(provider, theme),

        // Error message overlay
        if (provider.errorMessage != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildErrorBanner(provider, theme),
          ),
      ],
    );
  }

  Widget _buildPaginatedMessageList(
      ConferBotProvider provider, ConferBotTheme theme) {
    // Use paginated messages if available, otherwise fall back to record
    final messages = provider.paginatedMessages.isNotEmpty
        ? provider.paginatedMessages
        : provider.record;

    // Build the inline interactive node widget (choices, inputs, etc.)
    Widget? interactiveNode;
    // A blocked visitor gets no step card (core/live_chat/live_events.dart).
    final uiState = provider.visitorBlocked == null ? provider.currentUIState : null;
    if (uiState != null && uiState is! HumanHandoverUIState) {
      interactiveNode = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.chatContentPadding,
          vertical: theme.spacing.sm,
        ),
        child: NodeRenderer(
          uiState: uiState,
          onResponse: (response) {
            provider.submitResponse(response);
          },
          theme: theme,
          primaryColor: theme.colors.primary,
          stepKey: provider.stepVisit,
          error: provider.stepError,
        ),
      );
    }

    // The handover step waiting for a person: one card in the conversation,
    // as on the web widget (where they stand in line, about how long).
    if (uiState is HumanHandoverUIState && uiState.state == HandoverState.waitingForAgent) {
      interactiveNode = HandoverWaitCard(
        liveChat: provider.liveChat,
        theme: theme,
        message: uiState.handoverMessage,
        onLeave: () => provider.leaveQueue(),
      );
    }

    // While waiting for a person: the help card and the games, each after
    // the message that was last when it was drawn (core/waiting).
    final waiting = _waitingCards(provider, messages, theme);

    // Handle handover overlay separately (still positioned)
    if (uiState is HumanHandoverUIState && uiState.state != HandoverState.waitingForAgent) {
      return Stack(
        children: [
          MessageList(
            messages: messages,
            showTypingIndicator: _showTyping(provider),
            showTimestamps: widget.showTimestamps,
            showDeliveryStatus: widget.showDeliveryStatus,
            theme: theme,
            hasMoreMessages: provider.hasMoreMessages,
            isLoadingMore: provider.isLoadingMoreMessages,
            onLoadMore: () => provider.loadMoreMessages(),
            paginationConfig:
                widget.paginationConfig ?? const MessageListPaginationConfig(),
            inlineAfter: waiting.inline,
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildHandoverOverlay(provider, uiState, theme),
          ),
        ],
      );
    }

    return MessageList(
      messages: messages,
      showTypingIndicator: _showTyping(provider),
      showTimestamps: widget.showTimestamps,
      showDeliveryStatus: widget.showDeliveryStatus,
      theme: theme,
      hasMoreMessages: provider.hasMoreMessages,
      isLoadingMore: provider.isLoadingMoreMessages,
      onLoadMore: () => provider.loadMoreMessages(),
      paginationConfig:
          widget.paginationConfig ?? const MessageListPaginationConfig(),
      trailingWidget: _trailing(interactiveNode ?? _agentTrailing(provider, theme), provider, theme, waiting.atEnd),
      inlineAfter: waiting.inline,
    );
  }

  /// The help card and the games card: after the message each follows, or
  /// at the end when that message is not on screen.
  ({Map<String, List<Widget>> inline, List<Widget> atEnd}) _waitingCards(
      ConferBotProvider provider, List<RecordItem> messages, ConferBotTheme theme) {
    final inline = <String, List<Widget>>{};
    final atEnd = <Widget>[];
    final shown = {for (final m in messages) m.id};
    void place(String? after, Widget card) {
      if (after != null && shown.contains(after)) {
        inline.putIfAbsent(after, () => []).add(card);
      } else {
        atEnd.add(card);
      }
    }

    final help = provider.waitHelpCard;
    final games = provider.gamesCard;
    final helpCard = help == null
        ? null
        : WaitHelpCard(
            key: ValueKey('cb-wait-help-${help.key}'),
            card: help,
            theme: theme,
            onOpen: provider.openWaitHelpItem,
            onSolved: () => provider.solveWait(),
          );
    final gamesCard = games == null
        ? null
        : GamesCardView(key: ObjectKey(games), card: games, theme: theme, customizations: provider.serverCustomizations);
    final helpFirst = provider.waiting.gamesAfterHelp;
    for (final (after, card) in helpFirst
        ? [(provider.waitHelpAfter, helpCard), (provider.gamesAfter, gamesCard)]
        : [(provider.gamesAfter, gamesCard), (provider.waitHelpAfter, helpCard)]) {
      if (card != null) place(after, card);
    }
    return (inline: inline, atEnd: atEnd);
  }

  /// The step or AI reply at the end of the list, then the live chat's
  /// receipt and cards (core/live_chat), and a waiting card with nothing
  /// before it on screen.
  Widget _trailing(Widget? node, ConferBotProvider provider, ConferBotTheme theme, [List<Widget> cards = const []]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...cards,
        if (node != null) node,
        LiveChatFooter(provider: provider, theme: theme, onUpload: _pickLiveFile),
      ],
    );
  }

  /// The visitor's file for the agent: picked, uploaded, sent.
  Future<void> _pickLiveFile() async {
    final provider = context.read<ConferBotProvider>();
    final picked = await FilePicker.platform.pickFiles(withData: false);
    final file = picked?.files.single;
    if (file == null || file.path == null) return;
    final error = await provider.sendLiveFile(file.path!, fileName: file.name, mimeType: _mimeOf(file.extension));
    if (error != null && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  static String? _mimeOf(String? ext) => switch (ext?.toLowerCase()) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        'txt' => 'text/plain',
        'csv' => 'text/csv',
        'doc' => 'application/msword',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        _ => null,
      };

  /// The dots: an agent typing, a node processing, or waiting on an AI
  /// reply - none once the reply is being written.
  bool _showTyping(ConferBotProvider provider) =>
      (_isAgentTyping || provider.isProcessing || provider.awaitingReply) && provider.agentStream == null;

  /// AI agent bots: the reply as it is written, then the one-tap questions.
  Widget? _agentTrailing(ConferBotProvider provider, ConferBotTheme theme) {
    final stream = provider.agentStream;
    final suggestions = provider.awaitingReply ? const <String>[] : provider.suggestions;
    if (stream == null && suggestions.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stream != null)
          MessageBubble(
            message: AgentMessageRecord(
              id: 'stream-${stream.id}',
              time: DateTime.now(),
              text: stream.text,
              agentDetails: stream.agentDetails,
            ),
            theme: theme,
          ),
        if (stream == null) SuggestionChips(items: suggestions, theme: theme, onPick: (q) => provider.sendMessage(q)),
      ],
    );
  }

  Widget _buildSimpleMessageList(
      ConferBotProvider provider, ConferBotTheme theme) {
    return SimpleMessageList(
      messages: provider.record,
      showTypingIndicator: _showTyping(provider),
      showTimestamps: widget.showTimestamps,
      showDeliveryStatus: widget.showDeliveryStatus,
      theme: theme,
    );
  }

  Widget _buildCurrentNode(ConferBotProvider provider, ConferBotTheme theme) {
    final uiState = provider.currentUIState;
    if (uiState == null) return const SizedBox.shrink();

    // Handle human handover with dedicated overlay
    if (uiState is HumanHandoverUIState) {
      return _buildHandoverOverlay(provider, uiState, theme);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.all(theme.spacing.md),
      child: SafeArea(
        top: false,
        child: NodeRenderer(
          uiState: uiState,
          onResponse: (response) {
            provider.submitResponse(response);
          },
          theme: theme,
          primaryColor: theme.colors.primary,
          stepKey: provider.stepVisit,
          error: provider.stepError,
        ),
      ),
    );
  }

  Widget _buildHandoverOverlay(
    ConferBotProvider provider,
    HumanHandoverUIState uiState,
    ConferBotTheme theme,
  ) {
    return HumanHandoverOverlay(
      uiState: uiState,
      agent: provider.currentAgent,
      isAgentTyping: _isAgentTyping,
      queueInfo: _queueInfo,
      primaryColor: theme.colors.primary,
      theme: theme,
      onPreChatSubmit: _handlePreChatSubmit,
      onCancel: _handleHandoverCancel,
      onSurveySubmit: _handleSurveySubmit,
      onSurveySkip: _handleSurveySkip,
      onEndChat: _handleEndAgentChat,
      onTimeout: _handleHandoverTimeout,
      handoverMessage: uiState.handoverMessage,
      showPreChatForm: widget.showHandoverPreChatForm,
      showPostChatSurvey: widget.showHandoverPostChatSurvey,
      maxWaitMinutes: uiState.maxWaitTime ?? widget.handoverMaxWaitMinutes,
      conversationId: provider.chatId,
    );
  }

  Widget _buildErrorBanner(ConferBotProvider provider, ConferBotTheme theme) {
    return Material(
      borderRadius: BorderRadius.circular(theme.borderRadius.md),
      color: theme.colors.error.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colors.error,
              size: 20,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                provider.errorMessage!,
                style: TextStyle(
                  color: theme.colors.error,
                  fontSize: theme.typography.fontSizeSm,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: theme.colors.error,
              onPressed: () => provider.clearError(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ConferBotProvider provider, ConferBotTheme theme) {
    // Hide input when flow is complete or when interactive node is showing
    if (provider.isFlowComplete || _isInteractiveNodeShowing(provider)) {
      return const SizedBox.shrink();
    }

    // Show offline state in input placeholder
    final isOffline = !_connectivity.isOnline;
    final placeholder = isOffline
        ? t('sdk.chat.offlineWillQueue')
        : widget.placeholder ?? t('chat.composer.placeholder');

    // A live chat: locked or replies off, and a file for the agent; a closed
    // chat (blocked, or ended with nothing going on) takes no more input.
    final live = provider.liveChat;
    final closed = provider.closedState;
    final repliesOff = live.lockedBy != null || !live.visitorInputEnabled || closed?.inputOff == true;
    final canAttach = provider.isLiveChatMode &&
        (LiveChat.visitorUploadsOn(provider.serverCustomizations) || live.fileRequestedBy != null);

    // Unified bottom bar: input + "Powered by" footer
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiveChatComposerTop(provider: provider, theme: theme),
        ChatBottomBar(
      onSend: (text) async {
        await provider.sendMessage(text);
      },
      placeholder: closed?.inputOff == true
          ? closed!.text
          : repliesOff
              ? t('sdk.chat.repliesOff')
              : placeholder,
      disabled: provider.isProcessing || repliesOff,
      focusNode: _composerFocus,
      enableAttachments: widget.enableAttachments || canAttach,
      onAttachmentPress: canAttach ? _pickLiveFile : null,
      showKnowledgeBase: _helpCentreVisible(provider),
      onKnowledgeBaseTap: _openKnowledgeBase,
      showOfflineIndicator: isOffline,
      // "Powered by Conferbot", the owner's text, or nothing (plan-gated by the server).
      hideBrand: provider.serverCustomizations != null && provider.customizations.hideBrand,
      customBrand: provider.serverCustomizations != null ? provider.customizations.customBrand : null,
      theme: theme,
      // The widget theme's field and the palette's send colours.
      look: provider.serverCustomizations != null ? provider.customizations : null,
        ),
      ],
    );
  }

  bool _isInteractiveNodeShowing(ConferBotProvider provider) {
    final uiState = provider.currentUIState;
    if (uiState == null) return false;

    // These node types show their own input UI
    // For HumanHandover when agent is connected, allow text input
    if (uiState is HumanHandoverUIState) {
      // Hidden for the pre-chat form and the survey. Open while a person is
      // connected, and while waiting for one: as on the web widget, live
      // messages reach whoever joins, and "play" opens the games (#76).
      return uiState.state != HandoverState.agentConnected && uiState.state != HandoverState.waitingForAgent;
    }

    // Web widget parity: the unified bottom bar stays visible for text
    // questions (answers are typed there) and choice nodes (visible under
    // the chips). Only nodes with genuinely modal inline UIs hide it.
    // Cards with fields of their own (the code, the signature, the address)
    // take the answer there, as on the web.
    final step = uiState is NodeUIState ? uiState.extra['step'] : null;
    if (step == 'otp' || step == 'signature' || uiState is AddressUIState) return true;

    return uiState is FileUploadUIState ||
        uiState is ImageChoiceUIState ||
        uiState is RatingUIState ||
        uiState is DropdownUIState ||
        uiState is RangeUIState ||
        uiState is CalendarUIState ||
        uiState is QuizUIState ||
        uiState is MultipleQuestionsUIState;
  }

  /// Under the bot's name in place of its status: being offline, or the
  /// conversation being over. Never the agent (the web keeps the bot).
  String? _getSubtitle(ConferBotProvider provider) {
    if (!_connectivity.isOnline) {
      return t('sdk.chat.offlineQueued');
    }
    if (!provider.isConnected) {
      return t('sdk.chat.reconnecting');
    }
    if (provider.isFlowComplete) {
      return t('sdk.chat.complete');
    }
    return null;
  }
}

/// Chat header with Knowledge Base button, offline badge, and handover indicator
/// Chat header matching Android SDK's ChatHeader — themed background, bot avatar, compact
class ChatHeaderWithKB extends StatelessWidget {
  final String? title;
  final String? subtitle;

  /// The words on the "Online" line: "Online", or the team's reply time
  /// ("Typically replies in a few minutes", "Online · team back at 9 AM").
  /// Null hides the line (the owner turned the status off).
  final String? statusText;
  final dynamic agent;
  final String? botAvatarUrl;
  final VoidCallback? onClose;
  final bool showConnectionStatus;
  final bool showKnowledgeBase;
  final VoidCallback? onKnowledgeBaseTap;
  final ConferBotTheme? theme;
  final Widget? handoverIndicator;

  /// The bot's settings as the web applies them; null keeps the host app's look.
  final ResolvedCustomizations? look;

  /// "Email me this chat" in the chat menu; null leaves it out.
  final VoidCallback? onEmailTranscript;

  /// "Your requests" in the chat menu; null leaves it out.
  final VoidCallback? onRequests;

  /// ‹ at the start: back to the home screen; null leaves it out.
  final VoidCallback? onBack;

  /// Requests with a new reply: the item says "Your requests · New reply".
  final int requestsUnread;

  const ChatHeaderWithKB({
    super.key,
    this.title,
    this.subtitle,
    this.statusText = 'Online',
    this.agent,
    this.botAvatarUrl,
    this.onClose,
    this.showConnectionStatus = true,
    this.showKnowledgeBase = true,
    this.onKnowledgeBaseTap,
    this.theme,
    this.handoverIndicator,
    this.look,
    this.onEmailTranscript,
    this.onRequests,
    this.onBack,
    this.requestsUnread = 0,
  });

  // The stock "Online" in the active language; any other status as given.
  static String _status(String s) => s == 'Online' ? I18n.t('status.online') : s;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? defaultTheme;
    final displayTitle = agent?.name ?? look?.title ?? title ?? I18n.t('sdk.header.chat');
    final displaySubtitle = agent?.email ?? subtitle;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: t.colors.headerBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
          children: [
            if (onBack != null) ...[
              Semantics(
                button: true,
                label: I18n.t('common.back'),
                excludeSemantics: true,
                child: InkWell(
                  key: const ValueKey('cb-header-back'),
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 4, 6, 4),
                    child: Text('‹', style: TextStyle(color: t.colors.headerText, fontSize: 28, height: 1)),
                  ),
                ),
              ),
              const SizedBox(width: 2),
            ],
            // The agent's photo, else the bot's logo (none when the owner hid it).
            if (agent != null || look?.hideLogo != true) ...[
              _buildHeaderAvatar(t),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: t.typography.fontWeightSemiBold,
                      color: t.colors.headerText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // The web's "Online" line: a 7px green dot with a soft ring
                  // and the status (or the tagline).
                  if (displaySubtitle == null && agent == null && look != null && (look!.tagline != null || (look!.showOnline && statusText != null))) ...[
                    const SizedBox(height: 1),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (look!.tagline == null) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            look!.tagline ?? _status(statusText!),
                            style: TextStyle(fontSize: 12, color: t.colors.headerText.withOpacity(0.85)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (displaySubtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      displaySubtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: t.colors.headerText.withOpacity(0.75),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Handover indicator
            if (handoverIndicator != null) ...[
              handoverIndicator!,
              const SizedBox(width: 8),
            ],
            if (showKnowledgeBase && onKnowledgeBaseTap != null) ...[
              IconButton(
                onPressed: onKnowledgeBaseTap,
                icon: Icon(Icons.help_outline, color: t.colors.headerText),
                tooltip: I18n.t('home.helpCentre'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
            ],
            if (onEmailTranscript != null || onRequests != null) ...[
              PopupMenuButton<String>(
                key: const ValueKey('cb-chat-menu'),
                icon: Icon(Icons.more_vert, color: t.colors.headerText),
                tooltip: I18n.t('sdk.chat.menu'),
                padding: EdgeInsets.zero,
                onSelected: (id) {
                  if (id == 'email-transcript') onEmailTranscript?.call();
                  if (id == 'requests') onRequests?.call();
                },
                itemBuilder: (_) => [
                  if (onRequests != null)
                    PopupMenuItem(
                      key: const ValueKey('cb-menu-requests'),
                      value: 'requests',
                      child: Row(
                        children: [
                          const Icon(Icons.inbox_outlined, size: 18),
                          const SizedBox(width: 10),
                          Flexible(child: Text(RequestsText.menu(requestsUnread), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  if (onEmailTranscript != null)
                    PopupMenuItem(
                      value: 'email-transcript',
                      child: Row(
                        children: [const Icon(Icons.mail_outline, size: 18), const SizedBox(width: 10), Text(EmailTranscript.menuLabel)],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
            ],
            if (onClose != null) ...[
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close, color: t.colors.headerText),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
    );
  }

  Widget _buildHeaderAvatar(ConferBotTheme t) {
    final avatarUrl = agent != null
        ? agent?.avatar as String?
        : (look?.logo ?? botAvatarUrl);
    final name = agent?.name as String? ?? title ?? 'B';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'B';

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: look != null ? 19 : 16,
        backgroundColor: look != null ? Colors.transparent : t.colors.headerText.withOpacity(0.2),
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: t.colors.headerText.withOpacity(0.2),
      child: Text(
        initial,
        style: TextStyle(
          color: t.colors.headerText,
          fontWeight: t.typography.fontWeightSemiBold,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Chat input with Knowledge Base quick access button and offline awareness
class ChatInputWithKB extends StatefulWidget {
  final Function(String) onSend;
  final String? placeholder;
  final bool disabled;
  final int? maxLength;
  final bool enableAttachments;
  final VoidCallback? onAttachmentPress;
  final bool showKnowledgeBase;
  final VoidCallback? onKnowledgeBaseTap;
  final bool showOfflineIndicator;
  final ConferBotTheme? theme;

  const ChatInputWithKB({
    super.key,
    required this.onSend,
    this.placeholder,
    this.disabled = false,
    this.maxLength,
    this.enableAttachments = false,
    this.onAttachmentPress,
    this.showKnowledgeBase = true,
    this.onKnowledgeBaseTap,
    this.showOfflineIndicator = false,
    this.theme,
  });

  @override
  State<ChatInputWithKB> createState() => _ChatInputWithKBState();
}

class _ChatInputWithKBState extends State<ChatInputWithKB> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.disabled || _isSending) {
      return;
    }

    setState(() => _isSending = true);

    try {
      await widget.onSend(text);
      _controller.clear();
    } catch (e) {
      debugPrint('[ChatInputWithKB] Error sending message: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final canSend = _controller.text.trim().isNotEmpty &&
        !widget.disabled &&
        !_isSending;

    return Container(
      padding: EdgeInsets.all(effectiveTheme.spacing.md),
      decoration: BoxDecoration(
        color: effectiveTheme.colors.surface,
        border: Border(
          top: BorderSide(
            color: effectiveTheme.colors.border,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Knowledge Base button
            if (widget.showKnowledgeBase && widget.onKnowledgeBaseTap != null) ...[
              IconButton(
                onPressed: widget.disabled ? null : widget.onKnowledgeBaseTap,
                icon: Icon(
                  Icons.menu_book_outlined,
                  color: widget.disabled
                      ? effectiveTheme.colors.textDisabled
                      : effectiveTheme.colors.primary,
                ),
                tooltip: t('sdk.kb.browseTitle'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
              SizedBox(width: effectiveTheme.spacing.xs),
            ],
            // Attachment button
            if (widget.enableAttachments) ...[
              IconButton(
                onPressed: widget.disabled ? null : widget.onAttachmentPress,
                icon: Icon(
                  Icons.attach_file,
                  color: widget.disabled
                      ? effectiveTheme.colors.textDisabled
                      : effectiveTheme.colors.textSecondary,
                ),
              ),
              SizedBox(width: effectiveTheme.spacing.xs),
            ],
            // Text input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 40,
                  maxHeight: 120,
                ),
                decoration: BoxDecoration(
                  color: effectiveTheme.colors.background,
                  borderRadius: BorderRadius.circular(
                    effectiveTheme.borderRadius.full,
                  ),
                  border: widget.showOfflineIndicator
                      ? Border.all(
                          color: effectiveTheme.colors.warning.withOpacity(0.5),
                          width: 1,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    if (widget.showOfflineIndicator) ...[
                      Padding(
                        padding: EdgeInsets.only(left: effectiveTheme.spacing.sm),
                        child: Icon(
                          Icons.cloud_off,
                          size: 16,
                          color: effectiveTheme.colors.warning,
                        ),
                      ),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !widget.disabled,
                        maxLength: widget.maxLength ?? 5000,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleSend(),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: widget.placeholder ?? t('chat.composer.placeholder'),
                          hintStyle: TextStyle(
                            color: widget.showOfflineIndicator
                                ? effectiveTheme.colors.warning
                                : effectiveTheme.colors.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: effectiveTheme.spacing.md,
                            vertical: effectiveTheme.spacing.sm,
                          ),
                          counterText: '',
                        ),
                        style: TextStyle(
                          fontSize: effectiveTheme.typography.fontSizeMd,
                          color: effectiveTheme.colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: effectiveTheme.spacing.sm),
            // Send button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: canSend
                    ? effectiveTheme.colors.primary
                    : effectiveTheme.colors.textDisabled,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: canSend ? _handleSend : null,
                padding: EdgeInsets.zero,
                icon: _isSending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            effectiveTheme.colors.surface,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: effectiveTheme.colors.surface,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Note: Node types and handover widgets re-exported from conferbot_flutter.dart barrel
