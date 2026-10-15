import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import '../config/constants.dart';
import '../core/customization/customizations.dart';

const String _conferbotUrl = 'https://www.conferbot.com';
const String _conferbotLogoUrl =
    'https://www.conferbot.com/img/logo/conferbot-logo.png';

/// Unified bottom bar: chat input + powered-by footer as one seamless block.
///
/// Matches the web widget where the input area and footer share the same
/// white background with a single upward shadow, creating one cohesive unit.
///
/// Layout:
/// ┌─────────────────────────────────────────┐  ← upward shadow
/// │  ┌─────────────────────────┐  ┌──────┐  │
/// │  │  Type a message...      │  │  ➤   │  │  ← pill input + send btn
/// │  └─────────────────────────┘  └──────┘  │
/// │          Powered by [LOGO]              │  ← footer, no separator
/// └─────────────────────────────────────────┘
class ChatBottomBar extends StatefulWidget {
  final Function(String) onSend;
  final String? placeholder;
  final bool disabled;
  final int? maxLength;
  final bool enableAttachments;
  final VoidCallback? onAttachmentPress;
  final bool showKnowledgeBase;
  final VoidCallback? onKnowledgeBaseTap;
  final bool showOfflineIndicator;
  final bool hideBrand;
  final String? customBrand;
  final ConferBotTheme? theme;

  /// The bot's look: the widget theme's field and radius, the palette's send colours.
  final ResolvedCustomizations? look;

  const ChatBottomBar({
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
    this.hideBrand = false,
    this.customBrand,
    this.theme,
    this.look,
  });

  @override
  State<ChatBottomBar> createState() => _ChatBottomBarState();
}

class _ChatBottomBarState extends State<ChatBottomBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.disabled || _isSending) return;

    setState(() => _isSending = true);
    try {
      await widget.onSend(text);
      _controller.clear();
      setState(() {});
    } catch (e) {
      debugPrint('[ChatBottomBar] Error sending: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? defaultTheme;
    final canSend =
        _controller.text.trim().isNotEmpty && !widget.disabled && !_isSending;

    // The send button in the header colour (or the theme palette's accent),
    // with ink that reads on it (or the palette's own).
    final look = widget.look;
    final sendColor = look?.accentInk != null ? (_hex(look!.accent) ?? theme.colors.headerBg) : theme.colors.headerBg;
    final sendInk = _hex(look?.accentInk) ?? (sendColor.computeLuminance() > 0.5 ? Colors.black : Colors.white);
    // The widget theme's field fill and radius (a white pill without one).
    final tokens = look?.theme.tokens;
    final fieldColor = _hex(tokens?.field) ?? theme.colors.surface;
    final fieldRadius = BorderRadius.circular((look?.fieldRadius ?? 25).clamp(0, 25).toDouble());

    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF636363).withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, -4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Input row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Pill-shaped input field with subtle border
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 40,
                        maxHeight: 100,
                      ),
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: fieldRadius,
                        border: Border.all(
                          color: theme.colors.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (widget.showOfflineIndicator) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                Icons.cloud_off,
                                size: 16,
                                color: theme.colors.warning,
                              ),
                            ),
                          ],
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              enabled: !widget.disabled,
                              maxLength: widget.maxLength ??
                                  ConferBotConstants.maxMessageLength,
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _handleSend(),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText:
                                    widget.placeholder ?? 'Type a message...',
                                hintStyle: TextStyle(
                                  color: theme.colors.textSecondary,
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                counterText: '',
                              ),
                              style: TextStyle(
                                fontSize: 16,
                                color: theme.colors.text,
                              ),
                            ),
                          ),
                          // A file for the agent, in a live chat.
                          if (widget.enableAttachments && widget.onAttachmentPress != null && !widget.disabled)
                            IconButton(
                              onPressed: widget.onAttachmentPress,
                              tooltip: 'Attach a file',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.attach_file, size: 20, color: Color(0xFF687882)),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Themed circular send button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: canSend
                          ? sendColor
                          : sendColor.withOpacity(0.35),
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
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(sendInk),
                              ),
                            )
                          : Icon(
                              Icons.send,
                              color: sendInk,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Powered-by footer — same white background, no separator ──
            if (!widget.hideBrand) _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ConferBotTheme theme) {
    if (widget.customBrand != null && widget.customBrand!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Center(
          child: Text(
            widget.customBrand!,
            // The owner's text: weight 600 in the footer grey, as on the web.
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colors.textSecondary,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openConferbotUrl(),
      child: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Powered by ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _hex(widget.look?.theme.tokens?.muted) ?? const Color(0xFF56595B),
              ),
            ),
            Image.network(
              _conferbotLogoUrl,
              height: 18,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback: bold "conferbot" text if image fails
                return const Text(
                  'conferbot',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A4A4A),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Color? _hex(String? v) {
    if (v == null || !v.startsWith('#') || v.length != 7) return null;
    final n = int.tryParse(v.substring(1), radix: 16);
    return n == null ? null : Color(0xFF000000 | n);
  }

  void _openConferbotUrl() {
    launchUrl(
      Uri.parse(_conferbotUrl),
      mode: LaunchMode.externalApplication,
    );
  }
}
