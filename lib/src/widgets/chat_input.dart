import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import '../config/constants.dart';
import '../services/voice_recording_service.dart';
import 'voice_message/voice_recorder.dart';

/// Chat input widget with send button and voice recording
class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final String? placeholder;
  final bool disabled;
  final int? maxLength;
  final bool enableAttachments;
  final VoidCallback? onAttachmentPress;
  final bool enableVoice;
  final Function(String filePath, Duration duration)? onVoiceRecordingComplete;
  final ConferBotTheme? theme;

  const ChatInput({
    super.key,
    required this.onSend,
    this.placeholder,
    this.disabled = false,
    this.maxLength,
    this.enableAttachments = false,
    this.onAttachmentPress,
    this.enableVoice = true,
    this.onVoiceRecordingComplete,
    this.theme,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final VoiceRecordingService _recordingService = VoiceRecordingService();

  bool _isSending = false;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;

  // Animation for transitioning between text and voice
  late AnimationController _modeAnimationController;

  @override
  void initState() {
    super.initState();
    _modeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _recordingService.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _recordingDuration = duration);
      }
    });

    _recordingService.stateStream.listen((state) {
      if (mounted && state == RecordingState.idle && _isRecording) {
        setState(() => _isRecording = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _modeAnimationController.dispose();
    _recordingService.dispose();
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
      debugPrint('[ChatInput] Error sending message: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();

    final started = await _recordingService.startRecording();
    if (started && mounted) {
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      _modeAnimationController.forward();
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    if (!_isRecording) return;

    _modeAnimationController.reverse();

    if (cancel) {
      await _recordingService.cancelRecording();
      setState(() => _isRecording = false);
      HapticFeedback.lightImpact();
    } else {
      // Check minimum duration (500ms)
      if (_recordingDuration < const Duration(milliseconds: 500)) {
        await _recordingService.cancelRecording();
        setState(() => _isRecording = false);
        _showMinDurationSnackBar();
        return;
      }

      final filePath = await _recordingService.stopRecording();
      if (filePath != null && mounted) {
        HapticFeedback.mediumImpact();

        if (widget.onVoiceRecordingComplete != null) {
          widget.onVoiceRecordingComplete!(filePath, _recordingDuration);
        }
      }
      setState(() => _isRecording = false);
    }
  }

  void _showMinDurationSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recording too short. Hold longer to record.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    final theme = widget.theme ?? defaultTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Microphone Permission',
          style: TextStyle(
            fontSize: theme.typography.fontSizeLg,
            fontWeight: theme.typography.fontWeightBold,
          ),
        ),
        content: Text(
          'Microphone permission is required to record voice messages. Please enable it in your device settings.',
          style: TextStyle(fontSize: theme.typography.fontSizeMd),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _recordingService.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final hasText = _controller.text.trim().isNotEmpty;
    final canSend = hasText && !widget.disabled && !_isSending;

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
        child: _isRecording
            ? _buildRecordingUI(effectiveTheme)
            : _buildNormalUI(effectiveTheme, canSend, hasText),
      ),
    );
  }

  Widget _buildNormalUI(ConferBotTheme theme, bool canSend, bool hasText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Attachment button
        if (widget.enableAttachments) ...[
          IconButton(
            onPressed: widget.disabled ? null : widget.onAttachmentPress,
            icon: Icon(
              Icons.attach_file,
              color: widget.disabled
                  ? theme.colors.textDisabled
                  : theme.colors.textSecondary,
            ),
          ),
          SizedBox(width: theme.spacing.xs),
        ],

        // Text input field
        Expanded(
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 40,
              maxHeight: 120,
            ),
            decoration: BoxDecoration(
              color: theme.colors.background,
              borderRadius: BorderRadius.circular(theme.borderRadius.full),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !widget.disabled,
              maxLength: widget.maxLength ?? ConferBotConstants.maxMessageLength,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.placeholder ?? 'Type a message...',
                hintStyle: TextStyle(
                  color: theme.colors.textSecondary,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.md,
                  vertical: theme.spacing.sm,
                ),
                counterText: '',
              ),
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
                color: theme.colors.text,
              ),
            ),
          ),
        ),

        SizedBox(width: theme.spacing.sm),

        // Voice or Send button
        _buildActionButton(theme, canSend, hasText),
      ],
    );
  }

  Widget _buildActionButton(ConferBotTheme theme, bool canSend, bool hasText) {
    // Show send button when there's text, voice button otherwise
    if (hasText) {
      return _buildSendButton(theme, canSend);
    }

    if (widget.enableVoice && !widget.disabled) {
      return _buildVoiceButton(theme);
    }

    return _buildSendButton(theme, canSend);
  }

  Widget _buildSendButton(ConferBotTheme theme, bool canSend) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: canSend ? theme.colors.primary : theme.colors.textDisabled,
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
                    theme.colors.surface,
                  ),
                ),
              )
            : Icon(
                Icons.send,
                color: theme.colors.surface,
                size: 20,
              ),
      ),
    );
  }

  Widget _buildVoiceButton(ConferBotTheme theme) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      onTap: () async {
        // Single tap - check permission
        final hasPermission = await _recordingService.requestPermission();
        if (!hasPermission && mounted) {
          _showPermissionDeniedDialog();
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mic,
          color: theme.colors.surface,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildRecordingUI(ConferBotTheme theme) {
    return GestureDetector(
      onLongPressEnd: (_) => _stopRecording(),
      onPanUpdate: (details) {
        // Slide left to cancel
        if (details.delta.dx < -5) {
          _stopRecording(cancel: true);
        }
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: theme.colors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(theme.borderRadius.full),
          border: Border.all(
            color: theme.colors.error.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Cancel hint
            Padding(
              padding: EdgeInsets.only(left: theme.spacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_back,
                    color: theme.colors.error,
                    size: 16,
                  ),
                  SizedBox(width: theme.spacing.xs),
                  Text(
                    'Slide to cancel',
                    style: TextStyle(
                      fontSize: theme.typography.fontSizeSm,
                      color: theme.colors.error,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Duration display
            Padding(
              padding: EdgeInsets.only(right: theme.spacing.sm),
              child: Text(
                VoiceRecordingService.formatDuration(_recordingDuration),
                style: TextStyle(
                  fontSize: theme.typography.fontSizeMd,
                  fontWeight: theme.typography.fontWeightMedium,
                  color: theme.colors.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),

            // Recording indicator
            Container(
              width: 40,
              height: 40,
              margin: EdgeInsets.only(right: theme.spacing.xs),
              decoration: BoxDecoration(
                color: theme.colors.error,
                shape: BoxShape.circle,
              ),
              child: _RecordingPulse(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing recording indicator
class _RecordingPulse extends StatefulWidget {
  final Color color;

  const _RecordingPulse({required this.color});

  @override
  State<_RecordingPulse> createState() => _RecordingPulseState();
}

class _RecordingPulseState extends State<_RecordingPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Center(
          child: Opacity(
            opacity: _animation.value,
            child: Icon(
              Icons.mic,
              color: widget.color,
              size: 24,
            ),
          ),
        );
      },
    );
  }
}

/// Chat input with enhanced voice recording UI
class EnhancedChatInput extends StatefulWidget {
  final Function(String) onSend;
  final Function(String filePath, Duration duration)? onVoiceRecordingComplete;
  final String? placeholder;
  final bool disabled;
  final bool enableVoice;
  final bool enableAttachments;
  final VoidCallback? onAttachmentPress;
  final ConferBotTheme? theme;

  const EnhancedChatInput({
    super.key,
    required this.onSend,
    this.onVoiceRecordingComplete,
    this.placeholder,
    this.disabled = false,
    this.enableVoice = true,
    this.enableAttachments = false,
    this.onAttachmentPress,
    this.theme,
  });

  @override
  State<EnhancedChatInput> createState() => _EnhancedChatInputState();
}

class _EnhancedChatInputState extends State<EnhancedChatInput> {
  final TextEditingController _controller = TextEditingController();
  final VoiceRecordingService _recordingService = VoiceRecordingService();

  bool _isSending = false;
  bool _isRecording = false;

  @override
  void dispose() {
    _controller.dispose();
    _recordingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    if (_isRecording) {
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
          child: VoiceRecorderWidget(
            onRecordingComplete: (path, duration) {
              setState(() => _isRecording = false);
              widget.onVoiceRecordingComplete?.call(path, duration);
            },
            onRecordingCancelled: () {
              setState(() => _isRecording = false);
            },
            theme: widget.theme,
            recordingService: _recordingService,
          ),
        ),
      );
    }

    return ChatInput(
      onSend: widget.onSend,
      onVoiceRecordingComplete: widget.onVoiceRecordingComplete,
      placeholder: widget.placeholder,
      disabled: widget.disabled,
      enableVoice: widget.enableVoice,
      enableAttachments: widget.enableAttachments,
      onAttachmentPress: widget.onAttachmentPress,
      theme: widget.theme,
    );
  }
}
