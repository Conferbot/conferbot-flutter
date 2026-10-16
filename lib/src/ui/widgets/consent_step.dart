/// consent-node's card (web richNodesView.ts consentCardHtml): the owner's
/// text with its links, bold and italics, a box to tick, then Continue.
/// Sends `{agreed}`; a required consent not ticked is refused by the step
/// ("Please tick the box to continue.") and the card stays.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/flow/i18n_en.dart';
import '../../core/flow/rich.dart' show safeLink;
import '../../core/nodes/node_ui_state.dart' as ui_state;
import '../../theme/conferbot_theme.dart';
import 'step_style.dart';

final RegExp _mdLink = RegExp(r'\[([^\]\n]{1,200})\]\(((?:[^()\s]|\([^()\s]*\)){1,500})\)');
final RegExp _mdToken = RegExp(r'\*\*([^*\n]+)\*\*|(^|[\s(])\*([^*\n]+)\*(?=[\s).,!?:;]|$)|(^|[\s(])_([^_\n]+)_(?=[\s).,!?:;]|$)');

/// Opens a link the visitor tapped in a step's text.
void openStepLink(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  launchUrl(uri, mode: LaunchMode.externalApplication).catchError((Object _) => false);
}

/// Markdown-lite as text spans (rich.dart markdownLiteHtml): [text](url)
/// links that open in the browser, **bold**, *italic* / _italic_ and line
/// breaks. A link that isn't http(s) / mailto stays text.
List<InlineSpan> markdownLiteSpans(
  String md, {
  required TextStyle linkStyle,
  required List<TapGestureRecognizer> recognizers,
  void Function(String url) onLink = openStepLink,
}) {
  final spans = <InlineSpan>[];
  void plain(String text) {
    var at = 0;
    for (final m in _mdToken.allMatches(text)) {
      if (m.group(1) != null) {
        if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
        spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else {
        final lead = m.group(2) ?? m.group(4) ?? '';
        final word = m.group(3) ?? m.group(5) ?? '';
        if (m.start + lead.length > at) spans.add(TextSpan(text: text.substring(at, m.start + lead.length)));
        spans.add(TextSpan(text: word, style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  }

  final text = md.replaceAll('\r\n', '\n');
  var at = 0;
  for (final m in _mdLink.allMatches(text)) {
    final href = safeLink(m.group(2));
    if (href.isEmpty) continue;
    if (m.start > at) plain(text.substring(at, m.start));
    final r = TapGestureRecognizer()..onTap = () => onLink(href);
    recognizers.add(r);
    spans.add(TextSpan(text: m.group(1), style: linkStyle, recognizer: r, semanticsLabel: '${m.group(1)} ${t('common.opensNewTab')}'));
    at = m.end;
  }
  if (at < text.length) plain(text.substring(at));
  return spans;
}

class ConsentNodeWidget extends StatefulWidget {
  final ui_state.SingleChoiceUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  /// Why the last answer was refused, shown on the card.
  final String? error;

  /// Opens a tapped link (the browser; tests pass their own).
  final void Function(String url) onLink;

  const ConsentNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
    this.error,
    this.onLink = openStepLink,
  });

  @override
  State<ConsentNodeWidget> createState() => _ConsentNodeWidgetState();
}

class _ConsentNodeWidgetState extends State<ConsentNodeWidget> {
  bool _agreed = false;
  bool _sent = false;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void didUpdateWidget(ConsentNodeWidget old) {
    super.didUpdateWidget(old);
    // The step answered again (refused): the card is live once more.
    if (!identical(old.state, widget.state) || old.error != widget.error) _sent = false;
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _extra => widget.state.extra;

  @override
  Widget build(BuildContext context) {
    final style = StepLook.of(context, widget.theme, widget.primaryColor);
    final required = _extra['required'] != false;
    final md = (_extra['markdown'] ?? _extra['consentText'] ?? '').toString();
    final label = (_extra['continueLabel'] ?? t('common.continue')).toString();
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final spans = markdownLiteSpans(
      md.trim().isEmpty ? t('consent.agreed') : md,
      linkStyle: TextStyle(
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: style.accent.withOpacity(0.7),
      ),
      recognizers: _recognizers,
      onLink: widget.onLink,
    );
    return Padding(
      padding: stepIndent(widget.theme),
      child: StepCard(
        style: style,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    key: const ValueKey('consent-box'),
                    value: _agreed,
                    activeColor: style.accent,
                    checkColor: style.ink,
                    side: BorderSide(color: style.text.withOpacity(0.45), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: _sent ? null : (v) => setState(() => _agreed = v ?? false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _sent ? null : () => setState(() => _agreed = !_agreed),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 14, height: 1.45, color: style.text),
                        children: [
                          ...spans,
                          if (!required) TextSpan(text: ' ${t('common.optional')}', style: TextStyle(fontSize: 12, color: style.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            StepStatus(style: style, error: widget.error),
            StepActions(children: [
              StepButton(
                key: const ValueKey('consent-go'),
                label: label,
                style: style,
                primary: true,
                onPressed: _sent
                    ? null
                    : () {
                        setState(() => _sent = true);
                        widget.onResponse({'agreed': _agreed, 'label': label});
                      },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
