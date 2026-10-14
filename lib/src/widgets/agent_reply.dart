/// What an AI agent's reply draws, as on the web widget: the sources it was
/// grounded in, the pages it points to, a facts or result card, an action to
/// confirm, and "Helpful?". Also the agent's rich messages and the one-tap
/// question chips. The reply's text itself is drawn by the bubble's markdown.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/agent/agent_bot.dart';
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

class _QuietPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final ConferBotTheme theme;
  const _QuietPill({required this.label, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: ShapeDecoration(shape: StadiumBorder(side: BorderSide(color: theme.colors.border))),
        child: Text(label, style: TextStyle(fontSize: theme.typography.fontSizeXs, color: theme.colors.text)),
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
        provider != null;
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
                  onTap: source.url == null ? null : () => _open(source.url),
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
                        if (source.url != null) ...[
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
                  if (extras.card!.url != null) _link('Learn more', extras.card!.url!, theme),
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
            if (showHelpful) _Helpful(message: message, theme: theme, provider: provider),
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
      if (card.linkUrl != null) _link(card.linkLabel ?? 'Open', card.linkUrl!, theme),
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
                      : const Text('Confirm'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _state == 'ask' ? () => _answer(false) : null,
                  child: Text('Not now', style: TextStyle(color: theme.colors.text)),
                ),
              ),
            ],
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _state == 'done' ? 'Confirmed' : _state == 'declined' ? 'Not now' : 'That did not go through. Please ask again.',
            style: TextStyle(fontSize: theme.typography.fontSizeSm, color: theme.colors.textSecondary),
          ),
        ),
    ]);
  }
}

class _Helpful extends StatefulWidget {
  final AgentMessageRecord message;
  final ConferBotTheme theme;
  final ConferBotProvider? provider;
  const _Helpful({required this.message, required this.theme, required this.provider});

  @override
  State<_Helpful> createState() => _HelpfulState();
}

class _HelpfulState extends State<_Helpful> {
  bool _askWhy = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final label = TextStyle(fontSize: theme.typography.fontSizeXs, color: theme.colors.textSecondary);
    final given = widget.message.feedback;
    if (given != null) {
      return Text(given.helpful ? 'Thanks, glad it helped' : 'Thanks for telling us', style: label);
    }
    if (_askWhy) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('What was wrong?', style: label),
          for (final (key, text) in AgentBotParser.feedbackReasons)
            _QuietPill(label: text, theme: theme, onTap: () => widget.provider?.sendAnswerFeedback(widget.message.id, false, key)),
        ],
      );
    }
    return Row(
      children: [
        Text('Helpful?', style: label),
        const SizedBox(width: 6),
        _QuietPill(label: 'Yes', theme: theme, onTap: () => widget.provider?.sendAnswerFeedback(widget.message.id, true)),
        const SizedBox(width: 6),
        _QuietPill(label: 'No', theme: theme, onTap: () => setState(() => _askWhy = true)),
      ],
    );
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
          Text('Help article', style: TextStyle(fontSize: theme.typography.fontSizeXs, color: theme.colors.textSecondary)),
          _title(r.title, theme),
          if (r.snippet.isNotEmpty)
            Text(r.snippet, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: theme.typography.fontSizeSm, color: theme.colors.textSecondary)),
          if (r.url != null) _link('Read article', r.url!, theme),
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
