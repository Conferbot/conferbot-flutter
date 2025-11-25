import 'package:flutter/material.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import '../config/constants.dart';

/// Chat input widget with send button
class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final String? placeholder;
  final bool disabled;
  final int? maxLength;
  final bool enableAttachments;
  final VoidCallback? onAttachmentPress;
  final ConferBotTheme? theme;

  const ChatInput({
    super.key,
    required this.onSend,
    this.placeholder,
    this.disabled = false,
    this.maxLength,
    this.enableAttachments = false,
    this.onAttachmentPress,
    this.theme,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
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
      debugPrint('[ChatInput] Error sending message: $e');
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
                ),
                child: TextField(
                  controller: _controller,
                  enabled: !widget.disabled,
                  maxLength: widget.maxLength ?? ConferBotConstants.maxMessageLength,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: widget.placeholder ?? 'Type a message...',
                    hintStyle: TextStyle(
                      color: effectiveTheme.colors.textSecondary,
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
            ),
            SizedBox(width: effectiveTheme.spacing.sm),
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
