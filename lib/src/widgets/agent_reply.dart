/// What an AI agent's reply draws, as on the web widget: the sources it was
/// grounded in, the pages it points to, a facts or result card, an action to
/// confirm, and "Helpful?". Also the agent's rich messages and the one-tap
/// question chips. The reply's text itself is drawn by the bubble's markdown.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/agent/agent_bot.dart';
import '../core/agent/answer_feedback.dart';
import '../core/i18n/i18n.dart';
import '../models/message.dart';
import '../providers/conferbot_provider.dart';
import '../theme/conferbot_theme.dart';

Future<void> _open(String? url) async {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

ConferBotProvider? _providerOf(BuildContext context) {
  try {
    return Provider.of<ConferBotProvider>(context, listen: false);
  } catch (_) {
    return null;
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color accent;
  final bool filled;
  final VoidCallback? onTap;
  final ConferBotTheme theme;

  /// Opens a page: a small arrow after the label.
  final bool external;

  const _Pill({required this.label, required this.accent, required this.theme, this.filled = false, this.onTap, this.external = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? accent : theme.colors.surface,
      shape: StadiumBorder(side: BorderSide(color: accent)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: filled ? Colors.white : accent, fontSize: theme.typography.fontSizeSm, fontWeight: FontWeight.w500),
                ),
              ),
              if (external) ...[
                const SizedBox(width: 4),
                Icon(Icons.north_east, size: 13, color: filled ? Colors.white : accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardSurface extends StatelessWidget {
  final ConferBotTheme theme;
  final List<Widget> children;
  const _CardSurface({required this.theme, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

List<Widget> _rows(List<CardRow> rows, ConferBotTheme theme) => [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) Divider(height: 1, color: theme.colors.divider),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(rows[i].label, style: TextStyle(fontSize: theme.typography.fontSizeSm, color: theme.colors.textSecondary))),
              const SizedBox(width: 12),
              Text(rows[i].value, style: TextStyle(fontSize: theme.typography.fontSizeSm, color: theme.colors.text, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    ];

Widget _title(String text, ConferBotTheme theme) =>
    Text(text, style: TextStyle(fontSize: theme.typography.messageSize, fontWeight: FontWeight.w600, color: theme.colors.text));

Widget _link(String label, String url, ConferBotTheme theme) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _open(url),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: theme.typography.fontSizeSm, color: theme.colors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            // A drawn arrow: the \u2197 character renders as a coloured emoji on Android.
            Icon(Icons.north_east, size: 13, color: theme.colors.primary),
          ],
        ),
      ),
    );

/// "Read article" on a rich article card: opens it in the help centre.
Widget _articleLink(String label, VoidCallback onTap, ConferBotTheme theme) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        key: const ValueKey('agent-rich-article-open'),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: theme.typography.fontSizeSm, color: theme.colors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 16, color: theme.colors.primary),
          ],
        ),
      ),
    );

/// Under an AI reply: sources, buttons, cards, an action to confirm, "Helpful?".
class AgentReplyExtras extends StatelessWidget {
  final AgentMessageRecord message;
  final ConferBotTheme theme;

  const AgentReplyExtras({super.key, required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    final provider = _providerOf(context);
    final extras = message.extras;
    final showHelpful = message.agentDetails.isAIAgent &&
        extras?.isFallback != true &&
        !message.deleted &&
        AgentBotParser.canRate(message.id) &&
        AgentBotParser.answerFeedbackOn(provider?.serverCustomizations) &&
        provider != null &&
        // Rated answers keep their line; only the newest unrated one asks.
        (message.feedback != null || provider.newestRateableAnswerId == message.id);
    if ((extras == null || extras.isEmpty) && !showHelpful) return const SizedBox.shrink();
    final accent = theme.colors.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: theme.layout.maxBubbleWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final source in extras?.sources ?? const <AgentSource>[])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  // A help centre article opens in the help centre, by its id
                  // (web agentSources.ts); a page opens in the browser.
                  onTap: provider != null && provider.canOpenArticle(source.articleId)
                      ? () => provider.openArticle(source.articleId!)
                      : source.url == null
                          ? null
                          : () => _open(source.url),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: theme.colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colors.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            source.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: theme.typography.fontSizeSm, fontWeight: FontWeight.w500, color: theme.colors.text),
                          ),
                        ),
                        if (provider != null && provider.canOpenArticle(source.articleId)) ...[
                          const SizedBox(width: 6),
                          Text(t('kb.helpArticle'),
                              style: TextStyle(fontSize: theme.typography.fontSizeXs, color: theme.colors.textSecondary)),
                          Icon(Icons.chevron_right, size: 14, color: theme.colors.textSecondary),
                        ] else if (source.url != null) ...[
                          const SizedBox(width: 6),
                          Text(AgentBotParser.sourceHost(source.url),
                              style: TextStyle(fontSize: theme.typography.fontSizeXs, color: theme.colors.textSecondary)),
                          const SizedBox(width: 3),
                          Icon(Icons.north_east, size: 12, color: theme.colors.textSecondary),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (extras?.card != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _CardSurface(theme: theme, children: [
                  if (extras!.card!.title != null) _title(extras.card!.title!, theme),
                  ..._rows(extras.card!.rows, theme),
                  if (extras.card!.note != null)
                    Text(extras.card!.note!, style: TextStyle(fontSize: theme.typography.fontSizeXs, color: theme.colors.textSecondary)),
                  if (extras.card!.url != null) _link(t('sdk.card.learnMore'), extras.card!.url!, theme),
                ]),
              ),
            if (extras?.resultCard != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: _resultCard(extras!.resultCard!)),
            if (extras?.actionRequest != null)
              Padding(padding: const EdgeInsets.only(bottom: 6), child: _ActionCard(request: extras!.actionRequest!, theme: theme)),
            if (extras?.actions.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in extras!.actions)
                      _Pill(
                        label: a.label,
                        external: true,
                        accent: accent,
                        theme: theme,
                        onTap: () {
                          provider?.trackConversion('answer-action:${a.label}', AgentBotParser.conversionEventOf(a.label, a.url));
                          _open(a.url);
                        },
                      ),
                  ],
                ),
              ),
            if (showHelpful)
              HelpfulRow(
                key: ValueKey('helpful-${message.id}'),
                initial: message.feedback,
                theme: theme,
                onSend: (fb) => provider.sendAnswerFeedback(message.id, fb),
                // "Talk to a person" only while nobody is coming or here (web offerHuman).
                onAsk: provider.talkToPersonAllowed ? (text) => provider.sendMessage(text) : null,
                onRetry: provider.focusComposer,
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(ResultCard card) {
    final tone = switch (card.tone) {
      'done' => const Color(0xFF15803D),
      'moving' => const Color(0xFF1D4ED8),
      'problem' => theme.colors.error,
      _ => theme.colors.textSecondary,
    };
    return _CardSurface(theme: theme, children: [
      Row(
        children: [
          Expanded(child: _title(card.title, theme)),
          if (card.status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: ShapeDecoration(shape: StadiumBorder(side: BorderSide(color: tone))),
              child: Text(card.status!, style: TextStyle(fontSize: theme.typography.fontSizeXs, color: tone, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      ..._rows(card.rows, theme),
      if (card.linkUrl != null) _link(card.linkLabel ?? t('result.open'), card.linkUrl!, theme),
    ]);
  }
}

class _ActionCard extends StatefulWidget {
  final ActionRequest request;
  final ConferBotTheme theme;
  const _ActionCard({required this.request, required this.theme});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  String _state = 'ask';

  Future<void> _answer(bool accept) async {
    final provider = _providerOf(context);
    if (_state != 'ask' || provider == null) return;
    setState(() => _state = 'busy');
    final res = await provider.decideAction(widget.request.token, accept);
    if (!mounted) return;
    setState(() => _state = res.ok ? (accept ? 'done' : 'declined') : (res.code == 'declined' ? 'declined' : 'failed'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return _CardSurface(theme: theme, children: [
      _title(widget.request.name, theme),
      ..._rows(widget.request.summary, theme),
      if (_state == 'ask' || _state == 'busy')
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: theme.colors.primary),
                  onPressed: _state == 'ask' ? () => _answer(true) : null,
                  child: _state == 'busy'
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(t('action.confirm')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _state == 'ask' ? () => _answer(false) : null,
                  child: Text(t('common.notNow'), style: TextStyle(color: theme.colors.text)),
                ),
              ),
            ],
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _state == 'done'
                ? t('sdk.action.confirmed')
                : _state == 'declined'
                    ? t('common.notNow')
                    : t('sdk.action.notThroughAsk'),
            style: TextStyle(fontSize: theme.typography.fontSizeSm, color: theme.colors.textSecondary),
          ),
        ),
    ]);
  }
}

/// "Helpful?" under an AI answer (core/agent/answer_feedback.dart, web
/// answerFeedback.ts): a vote goes the moment it is given - a No too, before
/// any reason - then the reasons, an optional comment, "Talk to a person" and
/// "Ask another way". The rated line's thumbs change the vote.
class HelpfulRow extends StatefulWidget {
  /// The vote the answer already has (a restored chat starts rated).
  final AnswerFeedback? initial;
  final ConferBotTheme theme;

  /// Send this vote (ai-answer-feedback) and keep it on the answer.
  final void Function(AnswerFeedback feedback) onSend;

  /// Send the visitor's words ("Talk to a person"); null hides the button.
  final void Function(String text)? onAsk;

  /// Put the cursor in the composer ("Ask another way").
  final VoidCallback? onRetry;

  const HelpfulRow({super.key, this.initial, required this.theme, required this.onSend, this.onAsk, this.onRetry});

  @override
  State<HelpfulRow> createState() => _HelpfulRowState();
}

class _HelpfulRowState extends State<HelpfulRow> {
  late HelpfulState _state = Helpful.start(widget.initial);
  final _comment = TextEditingController();
  Timer? _settle;

  @override
  void dispose() {
    _settle?.cancel();
    _comment.dispose();
    super.dispose();
  }

  void _tap(HelpfulTap tap) {
    final r = Helpful.step(_state, tap);
    if (r.send != null) widget.onSend(r.send!);
    if (r.ask != null) widget.onAsk?.call(r.ask!);
    if (r.focus) widget.onRetry?.call();
    setState(() => _state = r.state);
    _settle?.cancel();
    // "Thanks for letting us know!", then the quiet rated line.
    if (_state.view == HelpfulView.thanks) {
      _settle = Timer(Helpful.thanksFor, () {
        if (mounted) setState(() => _state = Helpful.step(_state, const HelpfulSettle()).state);
      });
    }
  }

  Widget _thumb(bool helpful, {bool pressed = false}) {
    final theme = widget.theme;
    final rated = _state.view == HelpfulView.rated;
    final icon = helpful ? (pressed ? Icons.thumb_up : Icons.thumb_up_outlined) : (pressed ? Icons.thumb_down : Icons.thumb_down_outlined);
    return Semantics(
      button: true,
      selected: pressed,
      label: rated ? (helpful ? Helpful.ratedUp : Helpful.ratedDown) : (helpful ? Helpful.yes : Helpful.no),
      child: InkWell(
        key: ValueKey('cb-helpful-${helpful ? 'up' : 'down'}'),
        customBorder: const StadiumBorder(),
        onTap: () => _tap(HelpfulVote(helpful)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: pressed
              ? ShapeDecoration(color: theme.colors.surface, shape: StadiumBorder(side: BorderSide(color: theme.colors.border, width: 0.5)))
              : null,
          child: Icon(icon, size: 15, color: theme.colors.textSecondary.withOpacity(rated && !pressed ? 0.45 : 1)),
        ),
      ),
    );
  }

  Widget _action(String label, VoidCallback onTap, String key) => InkWell(
        key: ValueKey(key),
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(label,
              style: TextStyle(fontSize: widget.theme.typography.fontSizeXs, color: widget.theme.colors.primary, fontWeight: FontWeight.w600)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final label = TextStyle(fontSize: theme.typography.fontSizeXs, color: theme.colors.textSecondary);
    switch (_state.view) {
      case HelpfulView.thanks:
        return Text(Helpful.thanks, style: label);
      case HelpfulView.rated:
        return Semantics(
          container: true,
          label: Helpful.groupLabel,
          child: Row(
            key: const ValueKey('cb-helpful-rated'),
            mainAxisSize: MainAxisSize.min,
            children: [
              _thumb(true, pressed: _state.current?.helpful == true),
              _thumb(false, pressed: _state.current?.helpful == false),
              const SizedBox(width: 4),
              Flexible(child: Text(Helpful.ratedLabel(_state.current), style: label)),
            ],
          ),
        );
      case HelpfulView.ask:
        return Semantics(
          container: true,
          label: Helpful.groupLabel,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(Helpful.ask, style: label), const SizedBox(width: 4), _thumb(true), _thumb(false)],
          ),
        );
      case HelpfulView.down:
        final reason = _state.current?.reason;
        final onPrimary = theme.colors.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white;
        final border = OutlineInputBorder(borderRadius: BorderRadius.circular(theme.borderRadius.md), borderSide: BorderSide(color: theme.colors.border, width: 0.5));
        return Semantics(
          container: true,
          label: Helpful.groupLabel,
          child: Column(
            key: const ValueKey('cb-helpful-reasons'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Helpful.sorry, style: label),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (key, text) in Helpful.reasons)
                    Semantics(
                      inMutuallyExclusiveGroup: true,
                      checked: reason == key,
                      child: InkWell(
                        key: ValueKey('cb-helpful-reason-$key'),
                        customBorder: const StadiumBorder(),
                        onTap: () => _tap(HelpfulReason(key)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: ShapeDecoration(
                            color: reason == key ? theme.colors.primary : null,
                            shape: StadiumBorder(side: BorderSide(color: reason == key ? theme.colors.primary : theme.colors.border)),
                          ),
                          child: Text(text,
                              style: TextStyle(
                                  fontSize: theme.typography.fontSizeXs, color: reason == key ? onPrimary : theme.colors.text)),
                        ),
                      ),
                    ),
                ],
              ),
              if (_state.commented)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(Helpful.thanksComment, style: label))
              else if (reason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('cb-helpful-comment'),
                          controller: _comment,
                          autofocus: true,
                          maxLength: 500,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (v) => _tap(HelpfulComment(v)),
                          style: TextStyle(fontSize: theme.typography.fontSizeSm, color: theme.colors.text),
                          decoration: InputDecoration(
                            isDense: true,
                            counterText: '',
                            hintText: Helpful.comment,
                            hintStyle: TextStyle(fontSize: theme.typography.fontSizeSm, color: theme.colors.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            filled: true,
                            fillColor: theme.colors.background,
                            border: border,
                            enabledBorder: border,
                            focusedBorder: border,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Semantics(
                        button: true,
                        label: Helpful.sendFeedback,
                        child: InkWell(
                          key: const ValueKey('cb-helpful-comment-send'),
                          onTap: () => _tap(HelpfulComment(_comment.text)),
                          borderRadius: BorderRadius.circular(theme.borderRadius.md),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: theme.colors.primary, borderRadius: BorderRadius.circular(theme.borderRadius.md)),
                            child: Icon(Icons.send, size: 15, color: onPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  if (widget.onAsk != null) _action(Helpful.talkToPerson, () => _tap(const HelpfulHuman()), 'cb-helpful-human'),
                  _action(Helpful.retry, () => _tap(const HelpfulRetry()), 'cb-helpful-retry'),
                ],
              ),
            ],
          ),
        );
    }
  }
}

/// An agent's article, quick replies or card.
class RichAgentMessage extends StatelessWidget {
  final AgentRichMessageRecord message;
  final ConferBotTheme theme;
  final Widget avatar;

  const RichAgentMessage({super.key, required this.message, required this.theme, required this.avatar});

  @override
  Widget build(BuildContext context) {
    final provider = _providerOf(context);
    final rich = message.rich;
    final accent = theme.colors.primary;
    final Widget body = switch (rich) {
      RichQuickReplies r => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((r.text.isEmpty ? message.text : r.text).isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.bubblePaddingH, vertical: theme.spacing.bubblePaddingV),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(color: theme.colors.agentBubble, borderRadius: BorderRadius.circular(theme.borderRadius.bubble)),
                child: Text(r.text.isEmpty ? message.text : r.text,
                    style: TextStyle(color: theme.colors.agentBubbleText, fontSize: theme.typography.messageSize)),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final option in r.options)
                  Opacity(
                    opacity: message.answered != null && message.answered != option ? 0.45 : 1,
                    child: _Pill(
                      label: option,
                      accent: accent,
                      theme: theme,
                      filled: message.answered == option,
                      onTap: message.answered == null ? () => provider?.answerRichMessage(message.id, option) : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      RichArticle r => _CardSurface(theme: theme, children: [
          Text(t('kb.helpArticle'), style: TextStyle(fontSize: theme.typography.fontSizeXs, color: theme.colors.textSecondary)),
          _title(r.title, theme),
          if (r.snippet.isNotEmpty)
            Text(r.snippet, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: theme.typography.fontSizeSm, color: theme.colors.textSecondary)),
          // In the help centre by id (web agentRich.ts openArticle), else
          // the public help centre page when there is one.
          if (provider != null && provider.canOpenArticle(r.articleId))
            _articleLink(t('sdk.kb.readArticle'), () => provider.openArticle(r.articleId), theme)
          else if (r.url != null)
            _link(t('sdk.kb.readArticle'), r.url!, theme),
        ]),
      RichCard r => _CardSurface(theme: theme, children: [
          if (r.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(r.imageUrl!, height: 140, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          _title(r.title, theme),
          if (r.description.isNotEmpty) Text(r.description, style: TextStyle(fontSize: theme.typography.fontSizeSm, color: theme.colors.textSecondary)),
          if (r.buttonUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  onPressed: () => _open(r.buttonUrl),
                  child: Text(r.buttonLabel ?? ''),
                ),
              ),
            ),
        ]),
    };
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.chatContentPadding, vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          avatar,
          const SizedBox(width: 10),
          Flexible(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: theme.layout.maxBubbleWidth), child: body)),
        ],
      ),
    );
  }
}

/// One-tap questions: the agent's starters, then each answer's follow-ups.
class SuggestionChips extends StatelessWidget {
  final List<String> items;
  final ConferBotTheme theme;
  final ValueChanged<String> onPick;

  const SuggestionChips({super.key, required this.items, required this.theme, required this.onPick});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.chatContentPadding, vertical: theme.spacing.sm),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          runSpacing: 6,
          children: [for (final q in items) _Pill(label: q, accent: theme.colors.primary, theme: theme, onTap: () => onPick(q))],
        ),
      ),
    );
  }
}
