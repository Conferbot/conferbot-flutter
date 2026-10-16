/// The "While you wait, this might help" card (web
/// conferbot-widget src/ts/chat/waitArticles.ts mountHelpCard, its CSS in
/// src/css/polish.css .cb-wait-articles; RN components/LiveChat/
/// WaitHelpCard.tsx): in the bot bubble's colours, a row per item (an
/// article opens in the app, a page in the browser) and, for the server's
/// pick, "That solved it". Once the wait is over it stays as history under
/// "Articles that might help". The state is the provider's
/// (core/waiting/wait_articles.dart WaitHelp); nothing moves on its own.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/waiting/wait_articles.dart';
import '../../theme/conferbot_theme.dart';

class WaitHelpCard extends StatelessWidget {
  const WaitHelpCard({
    super.key,
    required this.card,
    required this.theme,
    required this.onOpen,
    required this.onSolved,
    this.openUrl,
  });

  final HelpCardState card;
  final ConferBotTheme theme;

  /// A row was tapped (an article opens in the app).
  final void Function(HelpItem item) onOpen;

  /// "That solved it".
  final VoidCallback onSolved;

  /// Opens a page's address (the browser by default).
  final Future<void> Function(String url)? openUrl;

  Future<void> _launch(String url) async {
    if (openUrl != null) return openUrl!(url);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (card.items.isEmpty) return const SizedBox.shrink();
    final bg = theme.colors.botBubble;
    final ink = theme.colors.botBubbleText;
    final title = card.settled ? WaitText.settledTitle : WaitText.title;
    final indent = theme.layout.avatarSize + 10 + theme.spacing.chatContentPadding;

    return Padding(
      padding: EdgeInsets.only(left: indent, right: theme.spacing.chatContentPadding + 12, top: 4, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          container: true,
          label: card.settled ? WaitText.settledTitle : WaitText.label,
          child: Container(
            key: const ValueKey('cb-wait-help'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
                  child: Text(
                    title,
                    key: const ValueKey('cb-wait-help-title'),
                    style: TextStyle(color: ink.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                for (final item in card.items) ...[
                  const SizedBox(height: 6),
                  _Row(
                    item: item,
                    bg: Color.lerp(bg, ink, 0.1)!,
                    ink: ink,
                    onTap: () {
                      onOpen(item);
                      final url = item.url;
                      if (item.isPage && url != null) _launch(url);
                    },
                  ),
                ],
                if (card.done) ...[
                  const SizedBox(height: 6),
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2, right: 2, top: 2),
                      child: Text(
                        WaitText.done,
                        key: const ValueKey('cb-wait-help-done'),
                        style: TextStyle(color: ink.withOpacity(0.85), fontSize: 12),
                      ),
                    ),
                  ),
                ] else if (card.solvable && !card.settled) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _SolvedButton(
                        busy: card.busy,
                        ink: ink,
                        line: Color.lerp(bg, ink, 0.45)!,
                        onTap: onSolved,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.bg, required this.ink, required this.onTap});
  final HelpItem item;
  final Color bg;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !item.isPage,
      link: item.isPage,
      label: '${WaitText.read}: ${item.title}',
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('cb-wait-help-row-${item.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: TextStyle(color: ink, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3)),
                      if (item.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: ink.withOpacity(0.8), fontSize: 12, height: 1.33),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(WaitText.read, style: TextStyle(color: ink.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SolvedButton extends StatelessWidget {
  const _SolvedButton({required this.busy, required this.ink, required this.line, required this.onTap});
  final bool busy;
  final Color ink;
  final Color line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !busy,
      label: WaitText.solved,
      excludeSemantics: true,
      child: Opacity(
        opacity: busy ? 0.6 : 1,
        child: Material(
          color: Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: line)),
          child: InkWell(
            key: const ValueKey('cb-wait-help-solved'),
            customBorder: const StadiumBorder(),
            onTap: busy ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: ink)),
                    const SizedBox(width: 6),
                  ],
                  Text(WaitText.solved, style: TextStyle(color: ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
