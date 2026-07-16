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
import 'chat_input.dart';
import 'chat_bottom_bar.dart';
import 'typing_indicator.dart';
import 'offline_indicator.dart';
import 'knowledge_base/knowledge_base_screen.dart';
import 'handover/handover.dart';

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

  /// Whether to show the Knowledge Base button in the header
  final bool showKnowledgeBase;

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

  const ChatWidget({
    super.key,
    this.title,
    this.placeholder,
    this.showTimestamps = false,
    this.enableAttachments = false,
    this.theme,
    this.enablePagination = true,
    this.paginationConfig,
    this.showKnowledgeBase = true,
    this.onArticleInsert,
    this.showOfflineIndicator = true,
    this.showDeliveryStatus = true,
    this.showHandoverPreChatForm = true,
    this.showHandoverPostChatSurvey = true,
    this.handoverMaxWaitMinutes = 5,
    this.onHandoverSurveySubmit,
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

  void _initKnowledgeBase() {
    if (!widget.showKnowledgeBase) return;

    final provider = context.read<ConferBotProvider>();
    _kbProvider = KnowledgeBaseProvider(
      apiKey: provider.apiKey,
      botId: provider.botId,
      visitorId: provider.visitorId,
    );
  }

  void _openKnowledgeBase() {
    if (_kbProvider == null) return;
    setState(() {
      _showKnowledgeBase = true;
    });
    _kbProvider!.setVisitorId(context.read<ConferBotProvider>().visitorId ?? '');
    _kbProvider!.initialize();
  }

  void _closeKnowledgeBase() {
    setState(() {
      _showKnowledgeBase = false;
    });
  }

  void _handleArticleInsert(KnowledgeBaseArticle article) {
    final provider = context.read<ConferBotProvider>();

    // Send article reference as a message
    final articleText = 'I found this helpful article: "${article.title}"';
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

    // Cancel the handover
    provider.emit(SocketEvents.cancelHandover, {});

    setState(() {
      _queueInfo = null;
    });
  }

  void _handleHandoverTimeout() {
    final provider = context.read<ConferBotProvider>();

    // Emit timeout event
    provider.emit(SocketEvents.handoverTimeout, {});

    setState(() {
      _queueInfo = null;
    });
  }

  void _handleSurveySubmit(SurveyResult result) {
    final provider = context.read<ConferBotProvider>();

    // Submit survey via socket
    provider.emit(SocketEvents.submitPostChatSurvey, result.toJson());

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

    // End the agent chat
    provider.emit(SocketEvents.visitorEndedChat, {});
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChange);
    _messageQueue.removeListener(_onQueueChange);
    _kbProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConferBotProvider>();
    // Use server-themed colors when available, fall back to widget theme or defaults
    final effectiveTheme = provider.serverCustomizations != null
        ? provider.serverTheme
        : (widget.theme ?? defaultTheme);

    // Show Knowledge Base screen if active
    if (_showKnowledgeBase && _kbProvider != null) {
      return ChangeNotifierProvider.value(
        value: _kbProvider!,
        child: KnowledgeBaseScreen(
          title: 'Help Center',
          onClose: _closeKnowledgeBase,
          onArticleInsertToChat: _handleArticleInsert,
          theme: effectiveTheme,
        ),
      );
    }

    return Scaffold(
      backgroundColor: effectiveTheme.colors.background,
      body: Column(
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
    );
  }

  Widget _buildHeader(ConferBotProvider provider, ConferBotTheme theme) {
    final uiState = provider.currentUIState;
    final isHandoverActive = uiState is HumanHandoverUIState &&
        uiState.state == HandoverState.agentConnected;

    // Show agent header during active handover
    if (isHandoverActive && provider.currentAgent != null) {
      return AgentInfoHeader(
        agent: provider.currentAgent!,
        isTyping: _isAgentTyping,
        primaryColor: theme.colors.primary,
        theme: theme,
        onClose: () {
          provider.closeChat();
          Navigator.of(context).pop();
        },
        showCloseButton: true,
      );
    }

    return ChatHeaderWithKB(
      title: provider.botName ?? widget.title ?? 'Support Chat',
      subtitle: _getSubtitle(provider),
      agent: provider.currentAgent,
      botAvatarUrl: provider.botAvatarUrl,
      onClose: () {
        provider.closeChat();
        Navigator.of(context).pop();
      },
      showConnectionStatus: true,
      showKnowledgeBase: widget.showKnowledgeBase,
      onKnowledgeBaseTap: _openKnowledgeBase,
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
    final uiState = provider.currentUIState;
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
        ),
      );
    }

    // Handle handover overlay separately (still positioned)
    if (uiState is HumanHandoverUIState) {
      return Stack(
        children: [
          MessageList(
            messages: messages,
            showTypingIndicator: _isAgentTyping || provider.isProcessing,
            showTimestamps: widget.showTimestamps,
            showDeliveryStatus: widget.showDeliveryStatus,
            theme: theme,
            hasMoreMessages: provider.hasMoreMessages,
            isLoadingMore: provider.isLoadingMoreMessages,
            onLoadMore: () => provider.loadMoreMessages(),
            paginationConfig:
                widget.paginationConfig ?? const MessageListPaginationConfig(),
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
      showTypingIndicator: _isAgentTyping || provider.isProcessing,
      showTimestamps: widget.showTimestamps,
      showDeliveryStatus: widget.showDeliveryStatus,
      theme: theme,
      hasMoreMessages: provider.hasMoreMessages,
      isLoadingMore: provider.isLoadingMoreMessages,
      onLoadMore: () => provider.loadMoreMessages(),
      paginationConfig:
          widget.paginationConfig ?? const MessageListPaginationConfig(),
      trailingWidget: interactiveNode,
    );
  }

  Widget _buildSimpleMessageList(
      ConferBotProvider provider, ConferBotTheme theme) {
    return SimpleMessageList(
      messages: provider.record,
      showTypingIndicator: _isAgentTyping || provider.isProcessing,
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
        ? 'Offline - messages will be queued'
        : widget.placeholder ?? 'Type a message...';

    // Unified bottom bar: input + "Powered by" footer
    return ChatBottomBar(
      onSend: (text) async {
        await provider.sendMessage(text);
      },
      placeholder: placeholder,
      disabled: provider.isProcessing,
      enableAttachments: widget.enableAttachments,
      onAttachmentPress: null,
      showKnowledgeBase: widget.showKnowledgeBase,
      onKnowledgeBaseTap: _openKnowledgeBase,
      showOfflineIndicator: isOffline,
      theme: theme,
    );
  }

  bool _isInteractiveNodeShowing(ConferBotProvider provider) {
    final uiState = provider.currentUIState;
    if (uiState == null) return false;

    // These node types show their own input UI
    // For HumanHandover when agent is connected, allow text input
    if (uiState is HumanHandoverUIState) {
      // Only hide input for pre-chat, queue, survey states
      // Allow input when agent is connected
      return uiState.state != HandoverState.agentConnected;
    }

    // Web widget parity: the unified bottom bar stays visible for text
    // questions (answers are typed there) and choice nodes (visible under
    // the chips). Only nodes with genuinely modal inline UIs hide it.
    return uiState is FileUploadUIState ||
        uiState is ImageChoiceUIState ||
        uiState is RatingUIState ||
        uiState is DropdownUIState ||
        uiState is RangeUIState ||
        uiState is CalendarUIState ||
        uiState is QuizUIState ||
        uiState is MultipleQuestionsUIState;
  }

  String? _getSubtitle(ConferBotProvider provider) {
    // Check for handover states
    final uiState = provider.currentUIState;
    if (uiState is HumanHandoverUIState) {
      switch (uiState.state) {
        case HandoverState.preChatQuestions:
          return 'Please fill the form';
        case HandoverState.waitingForAgent:
          return 'Connecting to agent...';
        case HandoverState.agentConnected:
          return provider.currentAgent?.title ?? 'Live Agent';
        case HandoverState.noAgentsAvailable:
          return 'No agents available';
        case HandoverState.postChatSurvey:
          return 'Chat ended';
      }
    }

    if (provider.currentAgent != null) {
      return provider.currentAgent!.email ?? 'Live Agent';
    }
    if (!_connectivity.isOnline) {
      return 'Offline - messages queued';
    }
    if (!provider.isConnected) {
      return 'Reconnecting...';
    }
    if (provider.isFlowComplete) {
      return 'Conversation complete';
    }
    return null;
  }
}

/// Chat header with Knowledge Base button, offline badge, and handover indicator
/// Chat header matching Android SDK's ChatHeader — themed background, bot avatar, compact
class ChatHeaderWithKB extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final dynamic agent;
  final String? botAvatarUrl;
  final VoidCallback? onClose;
  final bool showConnectionStatus;
  final bool showKnowledgeBase;
  final VoidCallback? onKnowledgeBaseTap;
  final ConferBotTheme? theme;
  final Widget? handoverIndicator;

  const ChatHeaderWithKB({
    super.key,
    this.title,
    this.subtitle,
    this.agent,
    this.botAvatarUrl,
    this.onClose,
    this.showConnectionStatus = true,
    this.showKnowledgeBase = true,
    this.onKnowledgeBaseTap,
    this.theme,
    this.handoverIndicator,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme ?? defaultTheme;
    final displayTitle = agent?.name ?? title ?? 'Chat';
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
            // Bot avatar (32dp, matching Android)
            _buildHeaderAvatar(t),
            const SizedBox(width: 10),
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
                tooltip: 'Help Center',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
    final avatarUrl = botAvatarUrl ??
        (agent != null && agent?.avatar != null ? agent.avatar as String? : null);
    final name = agent?.name as String? ?? title ?? 'B';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'B';

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: t.colors.headerText.withOpacity(0.2),
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
                tooltip: 'Browse Help Articles',
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
                          hintText: widget.placeholder ?? 'Type a message...',
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
