import 'package:flutter/material.dart';
import '../../core/nodes/node_ui_state.dart';
import '../../models/agent.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';
import 'pre_chat_form.dart';
import 'queue_status.dart';
import 'agent_info.dart';
import 'post_chat_survey.dart';

/// Comprehensive human handover overlay widget
/// Manages the entire handover flow from pre-chat form to post-chat survey
class HumanHandoverOverlay extends StatefulWidget {
  /// Current UI state from the handover node
  final HumanHandoverUIState uiState;

  /// Current agent (if connected)
  final Agent? agent;

  /// Whether agent is typing
  final bool isAgentTyping;

  /// Queue information (if waiting)
  final QueueInfo? queueInfo;

  /// Primary color for theming
  final Color primaryColor;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Called when pre-chat form is submitted
  final ValueChanged<PreChatFormResult>? onPreChatSubmit;

  /// Called when user cancels handover
  final VoidCallback? onCancel;

  /// Called when post-chat survey is submitted
  final ValueChanged<SurveyResult>? onSurveySubmit;

  /// Called when survey is skipped
  final VoidCallback? onSurveySkip;

  /// Called when user wants to end the agent chat
  final VoidCallback? onEndChat;

  /// Called when handover times out
  final VoidCallback? onTimeout;

  /// Custom handover message
  final String? handoverMessage;

  /// Whether to show pre-chat form
  final bool showPreChatForm;

  /// Whether to show post-chat survey
  final bool showPostChatSurvey;

  /// Max wait time in minutes
  final int maxWaitMinutes;

  /// Conversation ID for survey
  final String? conversationId;

  const HumanHandoverOverlay({
    super.key,
    required this.uiState,
    this.agent,
    this.isAgentTyping = false,
    this.queueInfo,
    required this.primaryColor,
    this.theme,
    this.onPreChatSubmit,
    this.onCancel,
    this.onSurveySubmit,
    this.onSurveySkip,
    this.onEndChat,
    this.onTimeout,
    this.handoverMessage,
    this.showPreChatForm = true,
    this.showPostChatSurvey = true,
    this.maxWaitMinutes = 5,
    this.conversationId,
  });

  @override
  State<HumanHandoverOverlay> createState() => _HumanHandoverOverlayState();
}

class _HumanHandoverOverlayState extends State<HumanHandoverOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _showSurveyThankYou = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HumanHandoverOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate when state changes
    if (widget.uiState.state != oldWidget.uiState.state) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _handleSurveySubmit(SurveyResult result) {
    setState(() => _showSurveyThankYou = true);
    widget.onSurveySubmit?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: effectiveTheme.colors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(effectiveTheme.borderRadius.xl),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(effectiveTheme.borderRadius.xl),
          ),
          child: _buildContent(effectiveTheme),
        ),
      ),
    );
  }

  Widget _buildContent(ConferBotTheme theme) {
    // Show thank you screen after survey
    if (_showSurveyThankYou) {
      return _buildSurveyThankYou(theme);
    }

    // Map UI state to the appropriate widget
    switch (widget.uiState.state) {
      case HandoverState.preChatQuestions:
        return _buildPreChatForm(theme);

      case HandoverState.waitingForAgent:
        return _buildQueueStatus(theme);

      case HandoverState.agentConnected:
        return _buildAgentConnected(theme);

      case HandoverState.noAgentsAvailable:
        return _buildNoAgentsAvailable(theme);

      case HandoverState.postChatSurvey:
        return _buildPostChatSurvey(theme);
    }
  }

  Widget _buildPreChatForm(ConferBotTheme theme) {
    if (!widget.showPreChatForm ||
        widget.uiState.preChatQuestions == null ||
        widget.uiState.preChatQuestions!.isEmpty) {
      // Skip to queue if no pre-chat questions
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPreChatSubmit?.call(const PreChatFormResult(answers: {}));
      });
      return _buildQueueStatus(theme);
    }

    // Convert QuestionDefinition to PreChatFormField
    final fields = widget.uiState.preChatQuestions!.map((q) {
      return PreChatFormField(
        id: q.answerKey,
        questionText: q.questionText,
        answerType: q.answerType,
        required: true,
      );
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.spacing.lg),
      child: PreChatFormWidget(
        fields: fields,
        onSubmit: (result) {
          widget.onPreChatSubmit?.call(result);
        },
        onCancel: widget.onCancel,
        primaryColor: widget.primaryColor,
        theme: theme,
        title: 'Before we connect you',
        description: widget.handoverMessage ??
            'Please provide your details so our agent can assist you better.',
        showCancelButton: widget.onCancel != null,
      ),
    );
  }

  Widget _buildQueueStatus(ConferBotTheme theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.spacing.lg),
      child: QueueStatusWidget(
        queueInfo: widget.queueInfo,
        maxWaitMinutes: widget.uiState.maxWaitTime ?? widget.maxWaitMinutes,
        onCancel: widget.onCancel,
        handoverMessage: widget.handoverMessage ?? widget.uiState.handoverMessage,
        primaryColor: widget.primaryColor,
        theme: theme,
        showTimer: true,
        showAgentAvailability: true,
        onTimeout: widget.onTimeout,
      ),
    );
  }

  Widget _buildAgentConnected(ConferBotTheme theme) {
    final agent = widget.agent ??
        Agent(
          id: 'unknown',
          name: widget.uiState.agentName ?? 'Support Agent',
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Agent info header
        AgentInfoHeader(
          agent: agent,
          isTyping: widget.isAgentTyping,
          primaryColor: widget.primaryColor,
          theme: theme,
          onClose: widget.onEndChat,
          showCloseButton: widget.onEndChat != null,
        ),

        // Connection success banner (initially)
        AgentConnectedBanner(
          agent: agent,
          primaryColor: widget.primaryColor,
          theme: theme,
          displayDuration: const Duration(seconds: 4),
        ),
      ],
    );
  }

  Widget _buildNoAgentsAvailable(ConferBotTheme theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.spacing.lg),
      child: Container(
        padding: EdgeInsets.all(theme.spacing.lg),
        decoration: BoxDecoration(
          color: theme.colors.surface,
          borderRadius: BorderRadius.circular(theme.borderRadius.lg),
          boxShadow: [theme.shadows.md],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colors.warning.withOpacity(0.1),
              ),
              child: Icon(
                Icons.access_time_filled,
                color: theme.colors.warning,
                size: 36,
              ),
            ),
            SizedBox(height: theme.spacing.lg),

            // Title
            Text(
              'No Agents Available',
              style: TextStyle(
                fontSize: theme.typography.fontSizeLg,
                fontWeight: theme.typography.fontWeightSemiBold,
                color: theme.colors.text,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.spacing.sm),

            // Description
            Text(
              'All our agents are currently busy. Please try again later or leave us a message.',
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
                color: theme.colors.textSecondary,
                height: theme.typography.lineHeightNormal,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: theme.spacing.xl),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colors.textSecondary,
                      side: BorderSide(color: theme.colors.border),
                      padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(theme.borderRadius.md),
                      ),
                    ),
                    child: const Text('Go Back'),
                  ),
                ),
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Could trigger a "leave a message" flow
                      widget.onCancel?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(theme.borderRadius.md),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Leave Message'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostChatSurvey(ConferBotTheme theme) {
    if (!widget.showPostChatSurvey) {
      widget.onSurveySkip?.call();
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.spacing.lg),
      child: PostChatSurveyWidget(
        agent: widget.agent,
        onSubmit: _handleSurveySubmit,
        onSkip: widget.onSurveySkip,
        primaryColor: widget.primaryColor,
        theme: theme,
        conversationId: widget.conversationId,
        showSkipButton: true,
      ),
    );
  }

  Widget _buildSurveyThankYou(ConferBotTheme theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.spacing.lg),
      child: SurveyThankYouWidget(
        primaryColor: widget.primaryColor,
        theme: theme,
        onDismiss: widget.onSurveySkip,
      ),
    );
  }
}

/// Compact handover indicator for the chat header
class HandoverStatusIndicator extends StatelessWidget {
  final HumanHandoverUIState uiState;
  final QueueInfo? queueInfo;
  final Agent? agent;
  final bool isAgentTyping;
  final Color primaryColor;
  final ConferBotTheme? theme;
  final VoidCallback? onTap;

  const HandoverStatusIndicator({
    super.key,
    required this.uiState,
    this.queueInfo,
    this.agent,
    this.isAgentTyping = false,
    required this.primaryColor,
    this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    switch (uiState.state) {
      case HandoverState.waitingForAgent:
        return CompactQueueStatus(
          maxWaitMinutes: uiState.maxWaitTime ?? 5,
          queueInfo: queueInfo,
          primaryColor: primaryColor,
          theme: effectiveTheme,
          onTap: onTap,
        );

      case HandoverState.agentConnected:
        if (agent != null) {
          return AgentAvatarWithTyping(
            agent: agent!,
            isTyping: isAgentTyping,
            primaryColor: primaryColor,
            size: 32,
          );
        }
        return const SizedBox.shrink();

      default:
        return const SizedBox.shrink();
    }
  }
}

/// Helper function to convert node HandoverState to socket HandoverState
HandoverState? nodeToSocketState(
    HumanHandoverUIState? uiState) {
  if (uiState == null) return null;
  return switch (uiState.state) {
    // Map to the socket HandoverState enum
    _ => null,
  };
}
