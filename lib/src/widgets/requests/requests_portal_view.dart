/// "Your requests": the screens (web conferbot-widget
/// src/ts/home/requests/view.ts, its CSS src/css/polish-requests.css; RN
/// components/Requests/RequestsPortal.tsx). Draws the portal's state
/// (core/requests/requests_portal.dart) over whatever it is placed in: the
/// list, one request with its banner, the conversation and the reply box.
/// Back (and Android's back) goes one step back.
///
/// Calm: the theme's page, card and ink, the app's font, one accent for the
/// Back link, the visitor's bubbles and Send (requestsAccent, the web's
/// --cb-accent). It slides in 14pt over 220ms unless animations are off,
/// and stays still after.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/requests/requests.dart';
import '../../core/requests/requests_portal.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';

const _solved = Color(0xFF16A34A);
const _errorInk = Color(0xFFDC2626);

/// A `#rgb` / `#rrggbb` colour.
Color requestsColorOf(String hex) {
  var s = hex.replaceFirst('#', '');
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  return Color(int.parse('FF$s', radix: 16));
}

class RequestsPortalView extends StatefulWidget {
  const RequestsPortalView({
    super.key,
    required this.portal,
    this.theme,
    this.accent,
    this.fontFamily,
    this.openUrl,
    this.now,
  });

  final RequestsPortal portal;
  final ConferBotTheme? theme;

  /// The bot's accent (requestsAccent of its settings); indigo when null.
  final Color? accent;

  /// The app's font for the chat (ConferBotCustomization.fontFamily).
  final String? fontFamily;

  /// Opens a link in a message (the browser by default).
  final Future<void> Function(String url)? openUrl;

  /// The clock for "2 hours ago" (tests).
  final int Function()? now;

  @override
  State<RequestsPortalView> createState() => _RequestsPortalViewState();
}

class _RequestsPortalViewState extends State<RequestsPortalView> with SingleTickerProviderStateMixin {
  late final AnimationController _slide;
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _wasOpen = false;
  final List<TapGestureRecognizer> _taps = [];

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    widget.portal.addListener(_onChange);
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
    _onChange(rebuild: false);
  }

  @override
  void didUpdateWidget(RequestsPortalView old) {
    super.didUpdateWidget(old);
    if (old.portal != widget.portal) {
      old.portal.removeListener(_onChange);
      widget.portal.addListener(_onChange);
    }
  }

  void _onChange({bool rebuild = true}) {
    final s = widget.portal.state;
    // In from the side, once per opening; still with animations off.
    if (s.isOpen && !_wasOpen) {
      final still = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
      if (still) {
        _slide.value = 1;
      } else {
        _slide.forward(from: 0);
      }
    }
    _wasOpen = s.isOpen;
    if (_input.text != s.draft) {
      _input.value = TextEditingValue(text: s.draft, selection: TextSelection.collapsed(offset: s.draft.length));
    }
    if (rebuild && mounted) setState(() {});
    if (s.screen == RequestsScreen.request) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    widget.portal.removeListener(_onChange);
    _slide.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _launch(String url) async {
    if (widget.openUrl != null) return widget.openUrl!(url);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.portal.state;
    if (!s.isOpen) return const SizedBox.shrink();
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();

    final t = widget.theme ?? defaultTheme;
    final page = t.colors.background;
    final card = t.colors.surface;
    final ink = t.colors.text;
    final muted = Color.lerp(page, ink, 0.64)!;
    final line = Color.lerp(card, ink, 0.14)!;
    final accent = widget.accent ?? const Color(0xFF4F46E5);
    final ff = widget.fontFamily;
    TextStyle ts(double size, Color color, {FontWeight? weight, double? height}) =>
        TextStyle(fontSize: size, color: color, fontWeight: weight, height: height, fontFamily: ff);

    Widget note(List<Widget> children) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]],
          ]),
        );
    Widget noteText(String text, String key) =>
        Text(text, key: ValueKey(key), textAlign: TextAlign.center, style: ts(15, muted, height: 22 / 15));
    Widget link(String label, VoidCallback onTap, String key, [Color? color]) => Semantics(
          button: true,
          child: GestureDetector(
            key: ValueKey(key),
            onTap: onTap,
            child: Text(label,
                style: ts(15, color ?? accent, weight: FontWeight.w700).copyWith(decoration: TextDecoration.underline, decorationColor: color ?? accent)),
          ),
        );

    Widget iconBox(RequestState state, double size, bool round) {
      final tint = state == RequestState.solved ? _solved : (state == RequestState.replied ? accent : ink);
      final bg = state == RequestState.solved
          ? _solved.withValues(alpha: 0.14)
          : (state == RequestState.replied ? Color.lerp(card, accent, 0.1)! : Color.lerp(card, ink, 0.09)!);
      final icon = switch (state) {
        RequestState.replied => Icons.chat_bubble_outline,
        RequestState.waiting => Icons.schedule,
        RequestState.solved => Icons.check_circle_outline,
      };
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(round ? size / 2 : 10)),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: tint),
      );
    }

    Widget linked(String text, TextStyle style) {
      final runs = linkRuns(text);
      return SelectableText.rich(TextSpan(style: style, children: [
        for (final r in runs)
          if (r.url == null)
            TextSpan(text: r.text)
          else
            TextSpan(
              text: r.text,
              style: TextStyle(decoration: TextDecoration.underline, decorationColor: style.color),
              recognizer: (TapGestureRecognizer()..onTap = () => _launch(r.url!)).also(_taps.add),
            ),
      ]));
    }

    final now = widget.now?.call();
    Widget? body;
    if (s.loading) {
      body = note([noteText(RequestsText.loading, 'cb-requests-loading')]);
    } else if (s.failed) {
      body = note([
        noteText(RequestsText.loadFailed, 'cb-requests-failed'),
        link(RequestsText.tryAgain, widget.portal.reload, 'cb-requests-reload'),
      ]);
    } else if (s.screen == RequestsScreen.list) {
      final list = s.list ?? const <RequestSummary>[];
      body = list.isEmpty
          ? note([noteText(RequestsText.empty, 'cb-requests-empty')])
          : Container(
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: line, width: 0.5)),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (var i = 0; i < list.length; i++)
                  _row(list[i], i, s, ink, line, accent, ts, iconBox, now),
              ]),
            );
    } else if (s.request != null) {
      final q = s.request!;
      Widget bubble(RequestMessage m, [PendingReply? p]) {
        final you = m.you;
        final who = you ? RequestsText.you : (m.name.isNotEmpty ? m.name : RequestsText.supportTeam);
        final when = whenWords(m.at, now);
        return Align(
          key: ValueKey(p != null ? 'cb-requests-pending-${p.entryId}' : 'cb-requests-msg-${m.id}'),
          alignment: you ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.86,
            alignment: you ? Alignment.centerRight : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: you ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                  child: Text(when.isNotEmpty ? '$who · $when' : who, style: ts(12.5, muted)),
                ),
                Opacity(
                  opacity: p != null ? 0.75 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: you ? accent : card,
                      border: you ? null : Border.all(color: line, width: 0.5),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(you ? 16 : 4),
                        bottomRight: Radius.circular(you ? 4 : 16),
                      ),
                    ),
                    child: linked(m.text, ts(15, you ? Colors.white : ink, height: 22 / 15)),
                  ),
                ),
                if (p != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: switch (p.status) {
                      PendingStatus.sending => Text(RequestsText.sending, style: ts(12.5, muted)),
                      PendingStatus.locked => Text(RequestsText.locked,
                          key: const ValueKey('cb-requests-locked'), style: ts(12.5, _errorInk, weight: FontWeight.w600)),
                      PendingStatus.failed => Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${RequestsText.notSent} ',
                              key: const ValueKey('cb-requests-not-sent'), style: ts(12.5, _errorInk, weight: FontWeight.w600)),
                          link(RequestsText.tryAgain, () => widget.portal.retry(p.entryId), 'cb-requests-retry', _errorInk),
                        ]),
                    },
                  ),
              ],
            ),
          ),
        );
      }

      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          liveRegion: true,
          child: Container(
            key: const ValueKey('cb-requests-banner'),
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: line, width: 0.5)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              iconBox(s.requestState!, 38, true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.banner!.label, style: ts(16, ink, weight: FontWeight.w700, height: 23 / 16)),
                  const SizedBox(height: 2),
                  Text(s.banner!.detail, style: ts(14, muted, height: 20 / 14)),
                ]),
              ),
            ]),
          ),
        ),
        for (final m in q.messages) ...[bubble(m), const SizedBox(height: 14)],
        for (final p in s.pending) ...[
          bubble(RequestMessage(id: p.entryId, from: 'you', name: '', text: p.text, at: p.at), p),
          const SizedBox(height: 14),
        ],
      ]);
    }

    final compose = s.screen == RequestsScreen.request && s.request != null;

    return PopScope(
      canPop: false,
      // Android's back: one step back, as the web's Escape.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.portal.back();
      },
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, child) {
          final v = Curves.easeOutCubic.transform(_slide.value);
          return Opacity(opacity: v, child: Transform.translate(offset: Offset(14 * (1 - v), 0), child: child));
        },
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          label: s.title,
          child: Material(
            key: const ValueKey('cb-requests'),
            color: page,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(color: card, border: Border(bottom: BorderSide(color: line, width: 0.5))),
                  child: Row(children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 72),
                      child: Semantics(
                        button: true,
                        label: RequestsText.back,
                        excludeSemantics: true,
                        child: InkWell(
                          key: const ValueKey('cb-requests-back'),
                          onTap: widget.portal.back,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('‹', style: TextStyle(color: accent, fontSize: 22, height: 1)),
                              const SizedBox(width: 2),
                              Text(RequestsText.back, style: ts(15, accent, weight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(s.title,
                            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(16, ink, weight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 72),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('cb-requests-body'),
                    controller: _scroll,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: body ?? const SizedBox.shrink(),
                  ),
                ),
                if (compose)
                  Container(
                    padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
                    decoration: BoxDecoration(color: card, border: Border(top: BorderSide(color: line, width: 0.5))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 46, maxHeight: 120),
                          child: TextField(
                            key: const ValueKey('cb-requests-input'),
                            controller: _input,
                            focusNode: _focus,
                            onChanged: widget.portal.setDraft,
                            maxLength: requestsMaxReply,
                            maxLines: null,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            style: ts(15, ink),
                            cursorColor: accent,
                            decoration: InputDecoration(
                              hintText: s.placeholder,
                              hintStyle: ts(15, muted),
                              semanticCounterText: '',
                              counterText: '',
                              isDense: true,
                              filled: true,
                              fillColor: card,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color.lerp(card, ink, 0.24)!, width: 1.5)),
                              focusedBorder:
                                  OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        enabled: s.canSend,
                        child: Opacity(
                          opacity: s.canSend ? 1 : 0.45,
                          child: Material(
                            color: accent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              key: const ValueKey('cb-requests-send'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: s.canSend ? widget.portal.send : null,
                              child: Container(
                                height: 46,
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                alignment: Alignment.center,
                                child: Text(RequestsText.send, style: ts(15, Colors.white, weight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(
    RequestSummary q,
    int i,
    RequestsPortalState s,
    Color ink,
    Color line,
    Color accent,
    TextStyle Function(double, Color, {FontWeight? weight, double? height}) ts,
    Widget Function(RequestState, double, bool) iconBox,
    int? now,
  ) {
    final fresh = isNewReply(q, s.seen);
    final words = rowLine(q, s.seen, now);
    return Semantics(
      button: true,
      label: '${q.title}. $words',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('cb-requests-row-${q.id}'),
        onTap: () => widget.portal.pick(q.id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: i > 0 ? Border(top: BorderSide(color: line, width: 0.5)) : null),
          child: Row(children: [
            iconBox(stateOf(q), 40, false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(q.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ts(15, ink, weight: fresh ? FontWeight.w700 : FontWeight.w600, height: 20 / 15)),
                const SizedBox(height: 2),
                Text(words,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(13, fresh ? ink : ink.withValues(alpha: 0.72), weight: fresh ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
            if (fresh) ...[
              const SizedBox(width: 12),
              Container(
                key: ValueKey('cb-requests-new-${q.id}'),
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

extension _Also<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}
