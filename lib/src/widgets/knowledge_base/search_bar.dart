import 'package:flutter/material.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';

/// Search bar widget with debounced input for knowledge base
class KBSearchBar extends StatefulWidget {
  final String? placeholder;
  final String? initialValue;
  final ValueChanged<String> onSearch;
  final VoidCallback? onClear;
  final bool autofocus;
  final bool enabled;
  final ConferBotTheme? theme;

  const KBSearchBar({
    super.key,
    this.placeholder,
    this.initialValue,
    required this.onSearch,
    this.onClear,
    this.autofocus = false,
    this.enabled = true,
    this.theme,
  });

  @override
  State<KBSearchBar> createState() => _KBSearchBarState();
}

class _KBSearchBarState extends State<KBSearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(KBSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });
  }

  void _handleClear() {
    _controller.clear();
    widget.onSearch('');
    widget.onClear?.call();
  }

  void _handleSubmit(String value) {
    widget.onSearch(value);
    _focusNode.unfocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final hasText = _controller.text.isNotEmpty;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: effectiveTheme.colors.surface,
        borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.lg),
        border: Border.all(
          color: _hasFocus
              ? effectiveTheme.colors.primary
              : effectiveTheme.colors.border,
          width: _hasFocus ? 2 : 1,
        ),
        boxShadow: _hasFocus
            ? [
                BoxShadow(
                  color: effectiveTheme.colors.primary.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: effectiveTheme.spacing.md),
            child: Icon(
              Icons.search,
              color: _hasFocus
                  ? effectiveTheme.colors.primary
                  : effectiveTheme.colors.textSecondary,
              size: 22,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              textInputAction: TextInputAction.search,
              onChanged: widget.onSearch,
              onSubmitted: _handleSubmit,
              style: TextStyle(
                fontSize: effectiveTheme.typography.fontSizeMd,
                color: effectiveTheme.colors.text,
              ),
              decoration: InputDecoration(
                hintText: widget.placeholder ?? 'Search articles...',
                hintStyle: TextStyle(
                  color: effectiveTheme.colors.textSecondary,
                  fontSize: effectiveTheme.typography.fontSizeMd,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: effectiveTheme.spacing.sm,
                  vertical: effectiveTheme.spacing.sm,
                ),
              ),
            ),
          ),
          if (hasText)
            IconButton(
              onPressed: widget.enabled ? _handleClear : null,
              icon: Icon(
                Icons.close,
                color: effectiveTheme.colors.textSecondary,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            )
          else
            SizedBox(width: effectiveTheme.spacing.md),
        ],
      ),
    );
  }
}

/// Compact search bar for embedding in headers
class KBCompactSearchBar extends StatelessWidget {
  final String? placeholder;
  final VoidCallback onTap;
  final ConferBotTheme? theme;

  const KBCompactSearchBar({
    super.key,
    this.placeholder,
    required this.onTap,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: effectiveTheme.colors.background,
          borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.full),
          border: Border.all(
            color: effectiveTheme.colors.border,
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: effectiveTheme.spacing.sm),
              child: Icon(
                Icons.search,
                color: effectiveTheme.colors.textSecondary,
                size: 20,
              ),
            ),
            Expanded(
              child: Text(
                placeholder ?? 'Search...',
                style: TextStyle(
                  color: effectiveTheme.colors.textSecondary,
                  fontSize: effectiveTheme.typography.fontSizeSm,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
