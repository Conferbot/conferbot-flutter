import 'package:flutter/material.dart';
import '../../core/nodes/node_ui_state.dart';
import '../../services/voice_recording_service.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';
import 'voice_recorder.dart';

/// Widget for voice input node that allows recording or text fallback
class VoiceInputNodeWidget extends StatefulWidget {
  final VoiceInputUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const VoiceInputNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<VoiceInputNodeWidget> createState() => _VoiceInputNodeWidgetState();
}

class _VoiceInputNodeWidgetState extends State<VoiceInputNodeWidget> {
  final TextEditingController _textController = TextEditingController();
  final VoiceRecordingService _recordingService = VoiceRecordingService();

  bool _isRecording = false;
  bool _showTextInput = false;
  bool _submitted = false;

  @override
  void dispose() {
    _textController.dispose();
    _recordingService.dispose();
    super.dispose();
  }

  void _handleRecordingComplete(String filePath, Duration duration) {
    if (_submitted) return;

    setState(() => _submitted = true);

    widget.onResponse({
      'localFilePath': filePath,
      'duration': duration.inMilliseconds,
    });
  }

  void _handleTextSubmit() {
    if (_submitted) return;

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitted = true);
    widget.onResponse(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Question text
        if (widget.state.questionText.isNotEmpty) ...[
          _BotMessageBubble(
            text: widget.state.questionText,
            theme: theme,
          ),
          SizedBox(height: theme.spacing.md),
        ],

        // Recording or text input area
        if (_submitted)
          _buildSubmittedState(theme)
        else if (_isRecording)
          _buildRecordingState(theme)
        else if (_showTextInput)
          _buildTextInputState(theme)
        else
          _buildIdleState(theme),
      ],
    );
  }

  Widget _buildIdleState(ConferBotTheme theme) {
    return Column(
      children: [
        // Main instruction
        Container(
          padding: EdgeInsets.all(theme.spacing.md),
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: BorderRadius.circular(theme.borderRadius.lg),
            border: Border.all(color: theme.colors.border),
          ),
          child: Column(
            children: [
              Icon(
                Icons.mic,
                size: 48,
                color: widget.primaryColor,
              ),
              SizedBox(height: theme.spacing.sm),
              Text(
                'Hold to record',
                style: TextStyle(
                  fontSize: theme.typography.fontSizeMd,
                  fontWeight: theme.typography.fontWeightMedium,
                  color: theme.colors.text,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                'Max ${widget.state.maxDurationSeconds ~/ 60} min ${widget.state.maxDurationSeconds % 60} sec',
                style: TextStyle(
                  fontSize: theme.typography.fontSizeSm,
                  color: theme.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: theme.spacing.md),

        // Action buttons
        Row(
          children: [
            // Record button
            Expanded(
              child: GestureDetector(
                onLongPressStart: (_) async {
                  final started = await _recordingService.startRecording();
                  if (started && mounted) {
                    setState(() => _isRecording = true);
                  }
                },
                onLongPressEnd: (_) async {
                  if (_isRecording) {
                    final filePath = await _recordingService.stopRecording();
                    if (filePath != null && mounted) {
                      _handleRecordingComplete(
                        filePath,
                        _recordingService.currentDuration,
                      );
                    }
                    setState(() => _isRecording = false);
                  }
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: widget.primaryColor,
                    borderRadius: BorderRadius.circular(theme.borderRadius.lg),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic, color: Colors.white),
                      SizedBox(width: theme.spacing.sm),
                      Text(
                        'Hold to Record',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: theme.typography.fontWeightMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Text fallback button
            if (widget.state.allowTextFallback) ...[
              SizedBox(width: theme.spacing.sm),
              IconButton(
                onPressed: () => setState(() => _showTextInput = true),
                icon: Icon(Icons.keyboard),
                tooltip: 'Type instead',
                style: IconButton.styleFrom(
                  backgroundColor: theme.colors.surface,
                  foregroundColor: theme.colors.text,
                  padding: EdgeInsets.all(theme.spacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(theme.borderRadius.lg),
                    side: BorderSide(color: theme.colors.border),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildRecordingState(ConferBotTheme theme) {
    return VoiceRecorderWidget(
      onRecordingComplete: _handleRecordingComplete,
      onRecordingCancelled: () {
        setState(() => _isRecording = false);
      },
      theme: widget.theme,
      primaryColor: widget.primaryColor,
      recordingService: _recordingService,
    );
  }

  Widget _buildTextInputState(ConferBotTheme theme) {
    return Column(
      children: [
        // Text input field
        TextField(
          controller: _textController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Type your response...',
            filled: true,
            fillColor: theme.colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              borderSide: BorderSide(color: theme.colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              borderSide: BorderSide(color: theme.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              borderSide: BorderSide(color: widget.primaryColor, width: 2),
            ),
          ),
        ),

        SizedBox(height: theme.spacing.md),

        // Action buttons
        Row(
          children: [
            // Back to recording button
            IconButton(
              onPressed: () => setState(() => _showTextInput = false),
              icon: Icon(Icons.mic),
              tooltip: 'Record instead',
              style: IconButton.styleFrom(
                backgroundColor: theme.colors.surface,
                foregroundColor: theme.colors.text,
                padding: EdgeInsets.all(theme.spacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.borderRadius.lg),
                  side: BorderSide(color: theme.colors.border),
                ),
              ),
            ),

            SizedBox(width: theme.spacing.sm),

            // Submit button
            Expanded(
              child: ElevatedButton(
                onPressed: _textController.text.trim().isNotEmpty
                    ? _handleTextSubmit
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(theme.borderRadius.lg),
                  ),
                ),
                child: Text('Submit'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmittedState(ConferBotTheme theme) {
    return Container(
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: theme.colors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
        border: Border.all(color: theme.colors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: theme.colors.success,
          ),
          SizedBox(width: theme.spacing.sm),
          Text(
            'Response submitted',
            style: TextStyle(
              color: theme.colors.success,
              fontWeight: theme.typography.fontWeightMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bot message bubble helper widget
class _BotMessageBubble extends StatelessWidget {
  final String text;
  final ConferBotTheme theme;

  const _BotMessageBubble({
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(theme.spacing.sm),
      decoration: BoxDecoration(
        color: theme.colors.botBubble,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(theme.borderRadius.lg),
          topRight: Radius.circular(theme.borderRadius.lg),
          bottomRight: Radius.circular(theme.borderRadius.lg),
          bottomLeft: Radius.circular(theme.borderRadius.sm),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: theme.typography.fontSizeMd,
          color: theme.colors.botBubbleText,
          height: theme.typography.lineHeightNormal,
        ),
      ),
    );
  }
}

/// Voice message bubble for displaying recorded messages in chat
class VoiceMessageBubble extends StatelessWidget {
  final String audioUrl;
  final Duration? duration;
  final List<double>? waveformData;
  final bool isUserMessage;
  final ConferBotTheme? theme;
  final Color? primaryColor;

  const VoiceMessageBubble({
    super.key,
    required this.audioUrl,
    this.duration,
    this.waveformData,
    this.isUserMessage = false,
    this.theme,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;
    final effectivePrimaryColor = primaryColor ?? effectiveTheme.colors.primary;

    // Import and use VoicePlayerWidget here
    // For now, show a placeholder
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: EdgeInsets.all(effectiveTheme.spacing.sm),
      decoration: BoxDecoration(
        color: isUserMessage
            ? effectiveTheme.colors.userBubble
            : effectiveTheme.colors.botBubble,
        borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_filled,
            color: isUserMessage
                ? effectiveTheme.colors.userBubbleText
                : effectivePrimaryColor,
            size: 32,
          ),
          SizedBox(width: effectiveTheme.spacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Voice message',
                  style: TextStyle(
                    fontSize: effectiveTheme.typography.fontSizeSm,
                    color: isUserMessage
                        ? effectiveTheme.colors.userBubbleText
                        : effectiveTheme.colors.botBubbleText,
                  ),
                ),
                if (duration != null)
                  Text(
                    _formatDuration(duration!),
                    style: TextStyle(
                      fontSize: effectiveTheme.typography.fontSizeXs,
                      color: isUserMessage
                          ? effectiveTheme.colors.userBubbleText.withOpacity(0.7)
                          : effectiveTheme.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
