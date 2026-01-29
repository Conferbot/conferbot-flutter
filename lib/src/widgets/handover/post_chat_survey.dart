import 'package:flutter/material.dart';
import '../../models/agent.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';

/// Survey result data
class SurveyResult {
  /// Star rating (1-5)
  final int rating;

  /// Optional feedback text
  final String? feedback;

  /// Agent ID if available
  final String? agentId;

  /// Conversation ID
  final String? conversationId;

  /// Timestamp
  final DateTime submittedAt;

  const SurveyResult({
    required this.rating,
    this.feedback,
    this.agentId,
    this.conversationId,
    required this.submittedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      if (feedback != null && feedback!.isNotEmpty) 'feedback': feedback,
      if (agentId != null) 'agentId': agentId,
      if (conversationId != null) 'conversationId': conversationId,
      'submittedAt': submittedAt.toIso8601String(),
    };
  }
}

/// Post-chat survey widget with star rating and feedback
class PostChatSurveyWidget extends StatefulWidget {
  /// Agent who handled the chat (optional)
  final Agent? agent;

  /// Called when survey is submitted
  final ValueChanged<SurveyResult> onSubmit;

  /// Called when user skips the survey
  final VoidCallback? onSkip;

  /// Primary color for accents
  final Color primaryColor;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Custom title
  final String? title;

  /// Custom subtitle
  final String? subtitle;

  /// Submit button text
  final String submitButtonText;

  /// Skip button text
  final String skipButtonText;

  /// Feedback placeholder text
  final String feedbackPlaceholder;

  /// Whether to show skip button
  final bool showSkipButton;

  /// Whether to require feedback for low ratings
  final bool requireFeedbackForLowRating;

  /// Low rating threshold (ratings <= this require feedback)
  final int lowRatingThreshold;

  /// Maximum feedback length
  final int maxFeedbackLength;

  /// Whether the survey is loading
  final bool isLoading;

  /// Conversation ID for the survey
  final String? conversationId;

  const PostChatSurveyWidget({
    super.key,
    this.agent,
    required this.onSubmit,
    this.onSkip,
    required this.primaryColor,
    this.theme,
    this.title,
    this.subtitle,
    this.submitButtonText = 'Submit',
    this.skipButtonText = 'Skip',
    this.feedbackPlaceholder = 'Tell us more about your experience...',
    this.showSkipButton = true,
    this.requireFeedbackForLowRating = true,
    this.lowRatingThreshold = 3,
    this.maxFeedbackLength = 500,
    this.isLoading = false,
    this.conversationId,
  });

  @override
  State<PostChatSurveyWidget> createState() => _PostChatSurveyWidgetState();
}

class _PostChatSurveyWidgetState extends State<PostChatSurveyWidget>
    with SingleTickerProviderStateMixin {
  int _selectedRating = 0;
  final _feedbackController = TextEditingController();
  String? _feedbackError;
  bool _isSubmitting = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _getRatingLabel(int rating) {
    return switch (rating) {
      1 => 'Very Poor',
      2 => 'Poor',
      3 => 'Okay',
      4 => 'Good',
      5 => 'Excellent',
      _ => '',
    };
  }

  Color _getRatingColor(int rating, ConferBotTheme theme) {
    return switch (rating) {
      1 => theme.colors.error,
      2 => const Color(0xFFFF6B6B),
      3 => theme.colors.warning,
      4 => const Color(0xFF69DB7C),
      5 => theme.colors.success,
      _ => theme.colors.textSecondary,
    };
  }

  IconData _getRatingIcon(int rating) {
    return switch (rating) {
      1 => Icons.sentiment_very_dissatisfied,
      2 => Icons.sentiment_dissatisfied,
      3 => Icons.sentiment_neutral,
      4 => Icons.sentiment_satisfied,
      5 => Icons.sentiment_very_satisfied,
      _ => Icons.star_border,
    };
  }

  void _handleSubmit() {
    if (_isSubmitting || widget.isLoading) return;
    if (_selectedRating == 0) return;

    // Validate feedback if required
    if (widget.requireFeedbackForLowRating &&
        _selectedRating <= widget.lowRatingThreshold &&
        _feedbackController.text.trim().isEmpty) {
      setState(() {
        _feedbackError = 'Please tell us how we can improve';
      });
      return;
    }

    setState(() => _isSubmitting = true);

    widget.onSubmit(SurveyResult(
      rating: _selectedRating,
      feedback: _feedbackController.text.trim().isEmpty
          ? null
          : _feedbackController.text.trim(),
      agentId: widget.agent?.id,
      conversationId: widget.conversationId,
      submittedAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: effectiveTheme.colors.surface,
          borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.lg),
          boxShadow: [effectiveTheme.shadows.lg],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(effectiveTheme),

            // Content
            Padding(
              padding: EdgeInsets.all(effectiveTheme.spacing.lg),
              child: Column(
                children: [
                  // Star rating
                  _buildStarRating(effectiveTheme),

                  // Rating label
                  if (_selectedRating > 0) ...[
                    SizedBox(height: effectiveTheme.spacing.md),
                    _buildRatingLabel(effectiveTheme),
                  ],

                  // Feedback input
                  SizedBox(height: effectiveTheme.spacing.lg),
                  _buildFeedbackInput(effectiveTheme),

                  // Buttons
                  SizedBox(height: effectiveTheme.spacing.lg),
                  _buildButtons(effectiveTheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ConferBotTheme theme) {
    return Container(
      padding: EdgeInsets.all(theme.spacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.primaryColor.withOpacity(0.1),
            widget.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(theme.borderRadius.lg),
          topRight: Radius.circular(theme.borderRadius.lg),
        ),
      ),
      child: Column(
        children: [
          // Agent avatar if available
          if (widget.agent != null) ...[
            _buildAgentAvatar(theme),
            SizedBox(height: theme.spacing.md),
          ],

          // Title
          Text(
            widget.title ?? 'How was your experience?',
            style: TextStyle(
              fontSize: theme.typography.fontSizeLg,
              fontWeight: theme.typography.fontWeightSemiBold,
              color: theme.colors.text,
            ),
            textAlign: TextAlign.center,
          ),

          // Subtitle
          if (widget.subtitle != null ||
              (widget.agent != null && widget.agent!.name.isNotEmpty)) ...[
            SizedBox(height: theme.spacing.xs),
            Text(
              widget.subtitle ??
                  'Rate your chat with ${widget.agent!.name}',
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                color: theme.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAgentAvatar(ConferBotTheme theme) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.primaryColor.withOpacity(0.1),
        border: Border.all(
          color: widget.primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: widget.agent?.avatar != null && widget.agent!.avatar!.isNotEmpty
            ? Image.network(
                widget.agent!.avatar!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildAgentInitials(theme);
                },
              )
            : _buildAgentInitials(theme),
      ),
    );
  }

  Widget _buildAgentInitials(ConferBotTheme theme) {
    final name = widget.agent?.name ?? 'Agent';
    final parts = name.trim().split(' ');
    String initials;
    if (parts.length >= 2) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      initials = parts[0][0].toUpperCase();
    } else {
      initials = 'A';
    }

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: widget.primaryColor,
          fontSize: 24,
          fontWeight: theme.typography.fontWeightSemiBold,
        ),
      ),
    );
  }

  Widget _buildStarRating(ConferBotTheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final rating = index + 1;
        final isSelected = _selectedRating >= rating;
        final isHovered = _selectedRating == rating;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedRating = rating;
              _feedbackError = null;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(theme.spacing.xs),
            child: AnimatedScale(
              scale: isHovered ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Icon(
                isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                size: 44,
                color: isSelected
                    ? _getRatingColor(_selectedRating, theme)
                    : theme.colors.border,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRatingLabel(ConferBotTheme theme) {
    final color = _getRatingColor(_selectedRating, theme);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(_selectedRating),
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(theme.borderRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getRatingIcon(_selectedRating),
              size: 20,
              color: color,
            ),
            SizedBox(width: theme.spacing.xs),
            Text(
              _getRatingLabel(_selectedRating),
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                fontWeight: theme.typography.fontWeightSemiBold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackInput(ConferBotTheme theme) {
    final isRequired = widget.requireFeedbackForLowRating &&
        _selectedRating > 0 &&
        _selectedRating <= widget.lowRatingThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Additional feedback',
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                fontWeight: theme.typography.fontWeightMedium,
                color: theme.colors.text,
              ),
            ),
            if (isRequired) ...[
              SizedBox(width: theme.spacing.xs),
              Text(
                '*',
                style: TextStyle(
                  color: theme.colors.error,
                  fontWeight: theme.typography.fontWeightBold,
                ),
              ),
            ],
            if (!isRequired) ...[
              SizedBox(width: theme.spacing.xs),
              Text(
                '(optional)',
                style: TextStyle(
                  fontSize: theme.typography.fontSizeXs,
                  color: theme.colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        TextField(
          controller: _feedbackController,
          maxLines: 4,
          maxLength: widget.maxFeedbackLength,
          enabled: !_isSubmitting && !widget.isLoading,
          onChanged: (_) {
            if (_feedbackError != null) {
              setState(() => _feedbackError = null);
            }
          },
          decoration: InputDecoration(
            hintText: widget.feedbackPlaceholder,
            hintStyle: TextStyle(
              color: theme.colors.textSecondary.withOpacity(0.7),
            ),
            filled: true,
            fillColor: theme.colors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.borderRadius.md),
              borderSide: BorderSide(color: theme.colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.borderRadius.md),
              borderSide: BorderSide(
                color: _feedbackError != null
                    ? theme.colors.error
                    : theme.colors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.borderRadius.md),
              borderSide: BorderSide(
                color: _feedbackError != null
                    ? theme.colors.error
                    : widget.primaryColor,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.all(theme.spacing.md),
            counterStyle: TextStyle(
              fontSize: theme.typography.fontSizeXs,
              color: theme.colors.textSecondary,
            ),
          ),
          style: TextStyle(
            fontSize: theme.typography.fontSizeMd,
            color: theme.colors.text,
          ),
        ),
        if (_feedbackError != null) ...[
          SizedBox(height: theme.spacing.xs),
          Text(
            _feedbackError!,
            style: TextStyle(
              fontSize: theme.typography.fontSizeSm,
              color: theme.colors.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildButtons(ConferBotTheme theme) {
    final isDisabled = _isSubmitting || widget.isLoading;
    final canSubmit = _selectedRating > 0;

    return Column(
      children: [
        // Submit button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isDisabled || !canSubmit ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: widget.primaryColor.withOpacity(0.4),
              disabledForegroundColor: Colors.white.withOpacity(0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.borderRadius.md),
              ),
              elevation: 0,
            ),
            child: _isSubmitting || widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    widget.submitButtonText,
                    style: TextStyle(
                      fontWeight: theme.typography.fontWeightSemiBold,
                    ),
                  ),
          ),
        ),

        // Skip button
        if (widget.showSkipButton && widget.onSkip != null) ...[
          SizedBox(height: theme.spacing.sm),
          TextButton(
            onPressed: isDisabled ? null : widget.onSkip,
            style: TextButton.styleFrom(
              foregroundColor: theme.colors.textSecondary,
              padding: EdgeInsets.symmetric(
                vertical: theme.spacing.sm,
                horizontal: theme.spacing.md,
              ),
            ),
            child: Text(
              widget.skipButtonText,
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact post-chat survey (inline)
class CompactPostChatSurvey extends StatefulWidget {
  final ValueChanged<int> onRatingSelected;
  final VoidCallback? onExpand;
  final Color primaryColor;
  final ConferBotTheme? theme;
  final String title;

  const CompactPostChatSurvey({
    super.key,
    required this.onRatingSelected,
    this.onExpand,
    required this.primaryColor,
    this.theme,
    this.title = 'Rate this conversation',
  });

  @override
  State<CompactPostChatSurvey> createState() => _CompactPostChatSurveyState();
}

class _CompactPostChatSurveyState extends State<CompactPostChatSurvey> {
  int _selectedRating = 0;

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    return Container(
      padding: EdgeInsets.all(effectiveTheme.spacing.md),
      decoration: BoxDecoration(
        color: effectiveTheme.colors.surface,
        borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.md),
        border: Border.all(color: effectiveTheme.colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: effectiveTheme.typography.fontSizeSm,
              fontWeight: effectiveTheme.typography.fontWeightMedium,
              color: effectiveTheme.colors.text,
            ),
          ),
          SizedBox(height: effectiveTheme.spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final rating = index + 1;
              final isSelected = _selectedRating >= rating;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedRating = rating);
                  widget.onRatingSelected(rating);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: effectiveTheme.spacing.xs,
                  ),
                  child: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 32,
                    color: isSelected
                        ? widget.primaryColor
                        : effectiveTheme.colors.border,
                  ),
                ),
              );
            }),
          ),
          if (widget.onExpand != null && _selectedRating > 0) ...[
            SizedBox(height: effectiveTheme.spacing.sm),
            TextButton(
              onPressed: widget.onExpand,
              style: TextButton.styleFrom(
                foregroundColor: widget.primaryColor,
                padding: EdgeInsets.symmetric(
                  vertical: effectiveTheme.spacing.xs,
                  horizontal: effectiveTheme.spacing.sm,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add feedback',
                    style: TextStyle(
                      fontSize: effectiveTheme.typography.fontSizeSm,
                    ),
                  ),
                  SizedBox(width: effectiveTheme.spacing.xs),
                  const Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thank you message after survey submission
class SurveyThankYouWidget extends StatefulWidget {
  final Color primaryColor;
  final ConferBotTheme? theme;
  final String title;
  final String subtitle;
  final VoidCallback? onDismiss;

  const SurveyThankYouWidget({
    super.key,
    required this.primaryColor,
    this.theme,
    this.title = 'Thank you!',
    this.subtitle = 'Your feedback helps us improve.',
    this.onDismiss,
  });

  @override
  State<SurveyThankYouWidget> createState() => _SurveyThankYouWidgetState();
}

class _SurveyThankYouWidgetState extends State<SurveyThankYouWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(effectiveTheme.spacing.xl),
        decoration: BoxDecoration(
          color: effectiveTheme.colors.surface,
          borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.lg),
          boxShadow: [effectiveTheme.shadows.md],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated check icon
            AnimatedBuilder(
              animation: _checkAnimation,
              builder: (context, child) {
                return Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: effectiveTheme.colors.success.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: effectiveTheme.colors.success,
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 32 * _checkAnimation.value,
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: effectiveTheme.spacing.lg),

            // Title
            Text(
              widget.title,
              style: TextStyle(
                fontSize: effectiveTheme.typography.fontSizeXl,
                fontWeight: effectiveTheme.typography.fontWeightSemiBold,
                color: effectiveTheme.colors.text,
              ),
            ),
            SizedBox(height: effectiveTheme.spacing.xs),

            // Subtitle
            Text(
              widget.subtitle,
              style: TextStyle(
                fontSize: effectiveTheme.typography.fontSizeMd,
                color: effectiveTheme.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            // Dismiss button
            if (widget.onDismiss != null) ...[
              SizedBox(height: effectiveTheme.spacing.lg),
              TextButton(
                onPressed: widget.onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: widget.primaryColor,
                ),
                child: const Text('Close'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
