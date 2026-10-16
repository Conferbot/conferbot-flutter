/// The home screen (web conferbot-widget src/ts/home/firstImpression.ts
/// enhanceHome, askBox.ts, trust.ts, requests/card.ts over
/// templates/shared.ts generateInitialPage; CSS src/css/polish.css "Home",
/// polish-home.css, polish-requests.css "Home card"; RN
/// components/Home/HomeScreen.tsx). Draws core/home/home.dart [HomeModel]
/// and sends each tap where the web sends it:
///
///   "Talk to us" and a starter question     the conversation (asking it)
///   "Ask anything" rows                     ask the agent, open an article, or the chat
///   "Pick up where you left off"            the conversation, or ask again
///   "Your requests" rows / See all (n)      the requests portal over the home
///   a recent article / a topic / See all    the article / the help centre
///   the cross                               closes the chat
///
/// Calm, as the web: the brand band, the theme's cards, one accent; each
/// part rises 8pt into place once (the web's cb-rise), none with the
/// phone's animations off, and it stays still after.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/customization/svg_path.dart';
import '../../core/home/home.dart';
import '../../core/requests/requests.dart' show RequestState;

/// A `#rgb` / `#rrggbb` colour (anything else: [fallback]).
Color homeColorOf(String? hex, [Color fallback = const Color(0xFF4F46E5)]) {
  final rgb = parseColor(hex);
  return rgb == null ? fallback : Color.fromARGB(255, rgb[0], rgb[1], rgb[2]);
}

/// `a` moved toward `b` by `t` (RN theme/color mix).
Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

// ------------------------------------------------------------ icons (the web's SVGs)

class _Glyph {
  const _Glyph(this.paths, {this.box = 24, this.stroke, this.evenOdd = false});
  final List<String> paths;
  final double box;

  /// Stroke width; null fills.
  final double? stroke;
  final bool evenOdd;
}

const _icons = {
  'search': _Glyph(['M4 11a7 7 0 1 0 14 0a7 7 0 1 0 -14 0', 'M20 20l-3.5-3.5'], stroke: 2),
  'spark': _Glyph(['M12 2.5l1.9 5.6 5.6 1.9-5.6 1.9L12 17.5l-1.9-5.6L4.5 10l5.6-1.9zM18.5 15l.9 2.6 2.6.9-2.6.9-.9 2.6-.9-2.6-2.6-.9 2.6-.9z']),
  'chat': _Glyph(['M21 12a8 8 0 0 1-11.6 7.1L4 20.5l1.4-4.9A8 8 0 1 1 21 12z'], stroke: 1.9),
  'history': _Glyph(['M3 12a9 9 0 1 0 3-6.7L3 8', 'M3 3v5h5M12 7v5l3 2'], stroke: 1.9),
  'doc': _Glyph(['M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z', 'M14 3v5h5M9 13h6M9 17h4'], stroke: 1.8),
  'send': _Glyph([
    'M11.821.098a1.62 1.62 0 0 1 2.077 2.076l-3.574 10.712a1.62 1.62 0 0 1-1.168 1.069a1.599 1.599 0 0 1-1.52-.434l-1.918-1.909l-2.014 1.042a.5.5 0 0 1-.73-.457l.083-3.184l7.045-5.117a.625.625 0 1 0-.735-1.012L2.203 8.088l-1.73-1.73a1.6 1.6 0 0 1-.437-1.447a1.62 1.62 0 0 1 1.069-1.238h.003L11.82.097Z',
  ], box: 14, evenOdd: true),
  'close': _Glyph(['M4 4l12 12M16 4L4 16'], box: 20, stroke: 1.7),
  'star': _Glyph(['M12 2.6l2.9 6 6.6.8-4.9 4.6 1.3 6.5L12 17.3l-5.9 3.2 1.3-6.5-4.9-4.6 6.6-.8z']),
  'replied': _Glyph(['M21 12a8 8 0 0 1-11.6 7.1L4 20.5l1.4-4.9A8 8 0 1 1 21 12z', 'M8.5 12h7'], stroke: 1.9),
  'waiting': _Glyph(['M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M12 7v5l3 2'], stroke: 1.9),
  'solved': _Glyph(['M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M8 12.5l2.7 2.7L16 9.8'], stroke: 1.9),
};

final Map<String, List<Path>> _pathCache = {};

List<Path> _pathsOf(_Glyph g, String name) => _pathCache[name] ??= [
      for (final d in g.paths)
        () {
          final p = Path()..fillType = g.evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
          for (final s in parseSvgPath(d)) {
            switch (s) {
              case SvgMove(:final x, :final y):
                p.moveTo(x, y);
              case SvgLine(:final x, :final y):
                p.lineTo(x, y);
              case SvgCubic(:final x1, :final y1, :final x2, :final y2, :final x, :final y):
                p.cubicTo(x1, y1, x2, y2, x, y);
              case SvgClose():
                p.close();
            }
          }
          return p;
        }(),
    ];

class _IconPainter extends CustomPainter {
  _IconPainter(this.name, this.color);
  final String name;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _icons[name]!;
    final k = size.width / g.box;
    canvas.scale(k, k);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (g.stroke != null) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = g.stroke!
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    for (final p in _pathsOf(g, name)) {
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.name != name || old.color != color;
}

class HomeIcon extends StatelessWidget {
  const HomeIcon(this.name, {super.key, required this.color, this.size = 20});
  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: CustomPaint(size: Size.square(size), painter: _IconPainter(name, color)));
}

// ------------------------------------------------------------ the rise (web cb-rise)

class _Rise extends StatefulWidget {
  const _Rise({super.key, required this.delay, required this.still, required this.child});
  final int delay;
  final bool still;
  final Widget child;

  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.delay + 450));
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Interval(widget.delay / (widget.delay + 450), 1, curve: const Cubic(0.22, 1, 0.36, 1)));

  @override
  void initState() {
    super.initState();
    if (widget.still) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        builder: (_, child) => Opacity(
          opacity: _t.value.clamp(0, 1),
          child: Transform.translate(offset: Offset(0, 8 * (1 - _t.value)), child: child),
        ),
        child: widget.child,
      );
}

// ------------------------------------------------------------ the screen

/// The [HomeScreenView]'s surfaces, from core/home/home.dart [HomePalette].
class HomeColors {
  HomeColors(HomePalette p)
      : page = homeColorOf(p.page),
        card = homeColorOf(p.card),
        soft = homeColorOf(p.soft),
        ink = homeColorOf(p.ink),
        muted = homeColorOf(p.muted),
        line = homeColorOf(p.line);
  final Color page, card, soft, ink, muted, line;
}

class HomeScreenView extends StatefulWidget {
  const HomeScreenView({
    super.key,
    required this.model,
    required this.palette,
    this.fontFamily,
    this.rawArticles = const [],
    this.hasAgent = false,
    this.onClose,
    required this.onShowChat,
    required this.onOpenArticle,
    required this.onShowHelp,
    required this.onOpenRequests,
    this.searchArticleText,
    this.imageFor,
    this.mascotBuilder,
  });

  final HomeModel model;
  final HomePalette palette;

  /// The app's font for every text on the screen.
  final String? fontFamily;

  /// The help centre's articles as sent (for the server's body search).
  final List<dynamic> rawArticles;

  /// An AI agent bot: the help card's "Ask us instead".
  final bool hasAgent;

  /// The cross at the top: close the chat. None without it.
  final VoidCallback? onClose;

  /// To the conversation, asking [text] there when given.
  final void Function([String? text]) onShowChat;
  final void Function(String articleId) onOpenArticle;

  /// The help centre, on a topic or its list.
  final void Function([String? categoryId]) onShowHelp;

  /// "Your requests": the list, or one request.
  final void Function([String? requestId]) onOpenRequests;

  /// The server's matches inside article text (HomeExtras.searchArticleText).
  final Future<List<({String id, String snippet})>> Function(String query)? searchArticleText;

  /// How an image is fetched (default: the network).
  final ImageProvider Function(String url)? imageFor;

  /// The app's own mascot spot, above the greeting: given the owner's
  /// mascot (look and colour), e.g. `(context, m) => Mascot(look: m.look,
  /// accent: m.accent, mood: 'wave')`. The web's home draws none, so nothing
  /// is drawn without it.
  final Widget Function(BuildContext context, HomeMascot mascot)? mascotBuilder;

  @override
  State<HomeScreenView> createState() => _HomeScreenViewState();
}

class _HomeScreenViewState extends State<HomeScreenView> {
  final _query = TextEditingController();
  final _helpQuery = TextEditingController();
  final _askFocus = FocusNode();
  final _helpFocus = FocusNode();
  final _content = GlobalKey();
  final _talk = GlobalKey();
  RemoteHits? _remote;
  Timer? _remoteTimer;
  double _band = 250;
  final Set<String> _broken = {};
  bool _logoLoaded = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQuery);
    _helpQuery.addListener(() => setState(() {}));
    _askFocus.addListener(() => setState(() {}));
    _helpFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _remoteTimer?.cancel();
    _query.dispose();
    _helpQuery.dispose();
    _askFocus.dispose();
    _helpFocus.dispose();
    super.dispose();
  }

  // The server's matches inside article text, 280ms after the last key (askBox.ts askRemote).
  void _onQuery() {
    setState(() {});
    _remoteTimer?.cancel();
    final q = _query.text.trim();
    final key = q.isNotEmpty && widget.model.ask != null ? remoteQueryFor(q, widget.rawArticles) : null;
    final search = widget.searchArticleText;
    if (key == null || search == null) return;
    _remoteTimer = Timer(const Duration(milliseconds: 280), () async {
      final hits = await search(key);
      if (mounted && _query.text.trim() == q) setState(() => _remote = RemoteHits(q.toLowerCase(), hits));
    });
  }

  // The band runs down to the middle of "Talk to us" (at most 72 into it).
  void _measureBand() {
    final content = _content.currentContext?.findRenderObject() as RenderBox?;
    final talk = _talk.currentContext?.findRenderObject() as RenderBox?;
    if (content == null || talk == null || !content.hasSize || !talk.hasSize) return;
    final top = talk.localToGlobal(Offset.zero, ancestor: content).dy;
    final next = (top + (talk.size.height / 2).clamp(0, 72)).roundToDouble();
    if ((next - _band).abs() >= 1) setState(() => _band = next);
  }

  ImageProvider _image(String url) => widget.imageFor?.call(url) ?? NetworkImage(url);
  bool _ok(String? url) => url != null && url.isNotEmpty && !_broken.contains(url);
  void _lose(String url) {
    if (_broken.add(url)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Widget _img(String url, {required double w, required double h, BorderRadius? radius, Color? bg, BoxFit fit = BoxFit.cover, double opacity = 1, String? label}) {
    final image = Image(
      image: _image(url),
      width: w,
      height: h,
      fit: fit,
      opacity: opacity == 1 ? null : AlwaysStoppedAnimation(opacity),
      semanticLabel: label,
      excludeFromSemantics: label == null,
      errorBuilder: (_, __, ___) {
        _lose(url);
        return SizedBox(width: w, height: h);
      },
    );
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      clipBehavior: radius != null ? Clip.antiAlias : Clip.none,
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final pal = HomeColors(widget.palette);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final accent = homeColorOf(m.accent);
    final bandA = homeColorOf(m.band.$1);
    final bandB = homeColorOf(m.band.$2);
    final bandInk = m.light ? const Color(0xFF0F172A) : Colors.white;
    final ff = widget.fontFamily;
    final asking = m.ask != null && _query.text.trim().isNotEmpty;
    final rows = m.ask != null ? askRows(_query.text, agentName: m.ask!.agentName, articles: m.articles, remote: _remote) : const <AskRow>[];

    TextStyle ts(double size, Color color, {FontWeight weight = FontWeight.w400, double? height, double? spacing}) =>
        TextStyle(fontSize: size, color: color, fontWeight: weight, height: height, letterSpacing: spacing, fontFamily: ff);

    BoxDecoration card({double shadow = 0.12, Border? border}) => BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(18),
          border: border,
          boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: shadow), blurRadius: 14, offset: const Offset(0, 8))],
        );

    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: Text(text.toUpperCase(), style: ts(11.5, pal.muted, weight: FontWeight.w600, spacing: 0.46)),
        );

    Widget seeAll(String text, VoidCallback onTap, String id) => Semantics(
          button: true,
          child: InkWell(
            key: ValueKey(id),
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Text(text, style: ts(12.5, accent, weight: FontWeight.w600)),
            ),
          ),
        );

    Widget iconBox(String name, {Color? tint, Color? bg}) => Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg ?? _mix(pal.card, accent, 0.12), borderRadius: BorderRadius.circular(10)),
          child: HomeIcon(name, color: tint ?? accent),
        );

    InlineSpan runs(List<TextRun> list) => TextSpan(children: [
          for (final r in list)
            TextSpan(text: r.text, style: r.mark ? TextStyle(backgroundColor: _mix(pal.card, accent, 0.12)) : null),
        ]);

    // A row of a card (polish.css .recent-articles .article-card / .cb-home-row).
    Widget row({
      required String id,
      required Widget lead,
      required InlineSpan title,
      String? sub,
      required VoidCallback onTap,
      int lines = 1,
      FontWeight weight = FontWeight.w600,
      TextStyle? subStyle,
      Widget? trail,
      String? a11y,
    }) {
      return Semantics(
        button: true,
        label: a11y,
        child: InkWell(
          key: ValueKey(id),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            child: Row(children: [
              lead,
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text.rich(title, maxLines: lines, overflow: TextOverflow.ellipsis, style: ts(14, pal.ink, weight: weight, height: 19 / 14)),
                  if (sub != null && sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, pal.muted, height: 17.5 / 12.5).merge(subStyle)),
                  ],
                ]),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 14,
                child: trail ?? Text('›', textAlign: TextAlign.center, style: TextStyle(color: _mix(pal.card, pal.muted, 0.8), fontSize: 18, height: 1)),
              ),
            ]),
          ),
        ),
      );
    }

    Widget searchBox(TextEditingController c, FocusNode focus, String placeholder, String a11y, VoidCallback onSubmit, TextInputAction action, String id) {
      final on = focus.hasFocus;
      return Container(
        height: 42,
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? pal.card : pal.soft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? _mix(pal.card, accent, 0.35) : Colors.transparent, width: 2),
        ),
        child: Row(children: [
          HomeIcon('search', color: pal.muted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label: a11y,
              textField: true,
              child: TextField(
                key: ValueKey(id),
                controller: c,
                focusNode: focus,
                maxLength: 300,
                autocorrect: false,
                textInputAction: action,
                onSubmitted: (_) => onSubmit(),
                cursorColor: accent,
                style: ts(14.5, pal.ink),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  counterText: '',
                  hintText: placeholder,
                  hintStyle: ts(14.5, pal.muted),
                ),
              ),
            ),
          ),
        ]),
      );
    }

    void runAsk(AskRow? r) {
      switch (r) {
        case AskQueryRow():
          widget.onShowChat(r.query);
        case AskArticleRow():
          widget.onOpenArticle(r.id);
        case AskChatRow():
          widget.onShowChat();
        default:
          break;
      }
    }

    // ---------- the parts ----------

    Widget ask() {
      final first = askDefault(rows);
      return Container(
        key: const ValueKey('cb-home-ask'),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(6),
        decoration: card(shadow: 0.09),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          searchBox(_query, _askFocus, m.ask!.placeholder, m.ask!.label, () => runAsk(askDefault(rows)),
              m.ask!.agentName != null ? TextInputAction.send : TextInputAction.search, 'cb-home-ask-input'),
          if (asking)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final r in rows)
                  switch (r) {
                    AskLabelRow() => label(r.text),
                    AskNoneRow() => Padding(
                        key: const ValueKey('cb-home-ask-none'),
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
                        child: Text(r.text, textAlign: TextAlign.center, style: ts(13.5, pal.muted)),
                      ),
                    _ => Container(
                        decoration: identical(r, first) ? BoxDecoration(color: _mix(pal.card, accent, 0.08), borderRadius: BorderRadius.circular(12)) : null,
                        child: row(
                          id: 'cb-home-ask-${r.kind.name}${r is AskArticleRow ? '-${r.id}' : ''}',
                          lead: iconBox(r is AskArticleRow ? 'doc' : (r is AskQueryRow ? 'spark' : 'chat')),
                          title: switch (r) {
                            AskQueryRow() => TextSpan(children: [
                                const TextSpan(text: '${HomeText.askQuery} '),
                                TextSpan(text: '“${r.query}”', style: const TextStyle(fontWeight: FontWeight.w700)),
                              ]),
                            AskArticleRow() => runs(r.title),
                            AskChatRow() => TextSpan(text: r.title),
                            _ => const TextSpan(),
                          },
                          sub: switch (r) {
                            AskQueryRow() => r.sub,
                            AskArticleRow() => r.sub,
                            AskChatRow() => r.sub,
                            _ => null,
                          },
                          lines: r is AskQueryRow ? 2 : 1,
                          weight: r is AskQueryRow ? FontWeight.w500 : FontWeight.w600,
                          onTap: () => runAsk(r),
                          trail: const SizedBox.shrink(),
                        ),
                      ),
                  },
              ]),
            ),
        ]),
      );
    }

    Widget resume() {
      final r = m.resume!;
      return Container(
        key: const ValueKey('cb-home-resume'),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(6),
        decoration: card(shadow: 0.09),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          label(HomeText.resume),
          row(
            id: 'cb-home-resume-row',
            lead: iconBox('history'),
            title: TextSpan(text: r.topic),
            sub: r.line,
            lines: 2,
            // The conversation is on the device: open it. Otherwise ask again.
            onTap: () => widget.onShowChat(r.resumable ? null : r.topic),
          ),
        ]),
      );
    }

    Widget requests() {
      final q = m.requests!;
      return Container(
        key: const ValueKey('cb-home-requests'),
        margin: q.fresh ? const EdgeInsets.only(bottom: 14) : const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(6),
        decoration: card(shadow: 0.09, border: q.fresh ? Border.all(color: _mix(pal.card, accent, 0.45), width: 1.5) : null),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: label(HomeText.requestsTitle)),
            if (q.seeAll != null) Padding(padding: const EdgeInsets.only(right: 6, top: 6), child: seeAll(q.seeAll!, () => widget.onOpenRequests(), 'cb-home-requests-all')),
          ]),
          for (final r in q.rows)
            () {
              final tint = r.state == RequestState.solved ? const Color(0xFF16A34A) : (r.state == RequestState.replied ? accent : pal.ink);
              final bg = r.state == RequestState.solved
                  ? const Color(0x2416A34A)
                  : (r.state == RequestState.replied ? _mix(pal.card, accent, 0.1) : _mix(pal.card, pal.ink, 0.09));
              return row(
                id: 'cb-home-request-${r.id}',
                lead: iconBox(r.state.name, tint: tint, bg: bg),
                title: TextSpan(text: r.title),
                sub: r.line,
                lines: 2,
                weight: r.fresh ? FontWeight.w700 : FontWeight.w600,
                subStyle: TextStyle(color: pal.ink.withValues(alpha: r.fresh ? 1 : 0.72), fontSize: 13, fontWeight: r.fresh ? FontWeight.w700 : FontWeight.w400),
                onTap: () => widget.onOpenRequests(r.id),
                a11y: '${r.title}. ${r.line}',
                trail: r.fresh
                    ? Center(
                        child: Container(
                          key: ValueKey('cb-home-request-new-${r.id}'),
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        ),
                      )
                    : const SizedBox.shrink(),
              );
            }(),
        ]),
      );
    }

    Widget talk() {
      final t = m.talk;
      final faces = t.faces.where(_ok).toList();
      return Column(
        key: const ValueKey('cb-home-talk'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (m.message.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(m.message, style: ts(14, bandInk))),
          Container(
            key: _talk,
            padding: const EdgeInsets.all(16),
            decoration: card(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Stack(clipBehavior: Clip.none, children: [
                    if (_ok(t.avatar))
                      _img(t.avatar, w: 46, h: 46, radius: BorderRadius.circular(23), bg: _mix(pal.card, pal.ink, 0.06))
                    else
                      Container(decoration: BoxDecoration(color: _mix(pal.card, pal.ink, 0.06), shape: BoxShape.circle)),
                    if (t.dot)
                      Positioned(
                        left: 34,
                        top: 34,
                        child: Container(
                          key: const ValueKey('cb-home-online-dot'),
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle, border: Border.all(color: pal.card, width: 2.5)),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, pal.ink, weight: FontWeight.w700)),
                    const SizedBox(height: 1),
                    if (t.tagline != null) Text(t.tagline!, style: ts(13, pal.muted, weight: FontWeight.w500, height: 17.5 / 13)),
                    if (t.status != null)
                      Text(t.status!, key: const ValueKey('cb-home-status'), style: ts(13, pal.muted, weight: FontWeight.w500, height: 17.5 / 13)),
                  ]),
                ),
                if (faces.isNotEmpty)
                  Semantics(
                    label: HomeText.ourTeam,
                    child: Padding(
                      key: const ValueKey('cb-home-faces'),
                      padding: const EdgeInsets.only(left: 10),
                      child: SizedBox(
                        width: 24 + 17.0 * (faces.length - 1),
                        height: 24,
                        child: Stack(children: [
                          for (var i = 0; i < faces.length; i++)
                            Positioned(
                              left: 17.0 * i,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: pal.card, width: 2), color: const Color(0xFFE2E8F0)),
                                child: ClipOval(child: _img(faces[i], w: 20, h: 20)),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(begin: const Alignment(-0.707, -0.707), end: const Alignment(0.707, 0.707), colors: [bandA, bandB]),
                    ),
                    child: InkWell(
                      key: const ValueKey('cb-home-talk-button'),
                      onTap: () => widget.onShowChat(),
                      borderRadius: BorderRadius.circular(12),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Flexible(child: Text(t.button, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14.5, bandInk, weight: FontWeight.w600, spacing: 0.15))),
                        const SizedBox(width: 8),
                        HomeIcon('send', color: bandInk, size: 16),
                      ]),
                    ),
                  ),
                ),
              ),
              if (t.starters.isNotEmpty)
                Container(
                  key: const ValueKey('cb-home-starters'),
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (var i = 0; i < t.starters.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      Semantics(
                        button: true,
                        child: Material(
                          color: _mix(pal.card, accent, 0.07),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: _mix(pal.card, accent, 0.22))),
                          child: InkWell(
                            key: ValueKey('cb-home-starter-$i'),
                            onTap: () => widget.onShowChat(t.starters[i]),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              child: Text(t.starters[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, accent, weight: FontWeight.w600, height: 17 / 13)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              if (t.rating != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    label: t.rating!.label,
                    excludeSemantics: true,
                    child: Wrap(
                      key: const ValueKey('cb-home-rating'),
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      children: [
                        Stack(children: [
                          Opacity(opacity: 0.3, child: Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < 5; i++) const HomeIcon('star', color: Color(0xFFF5B544), size: 12)])),
                          ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: t.rating!.fill / 100,
                              child: Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < 5; i++) const HomeIcon('star', color: Color(0xFFF5B544), size: 12)]),
                            ),
                          ),
                        ]),
                        Text(t.rating!.average, style: ts(12.5, _mix(pal.muted, pal.ink, 0.5), weight: FontWeight.w500)),
                        Text('·', style: ts(12.5, pal.muted.withValues(alpha: 0.7))),
                        Text(t.rating!.count, style: ts(12.5, pal.muted)),
                      ],
                    ),
                  ),
                ),
            ]),
          ),
        ],
      );
    }

    Widget help() {
      final h = m.help!;
      final found = h.search ? helpSearch(_helpQuery.text, m.articles, widget.hasAgent) : null;
      return Container(
        key: const ValueKey('cb-home-help'),
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(6),
        decoration: card(shadow: 0.09),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (h.search)
            searchBox(_helpQuery, _helpFocus, HomeText.searchPlaceholder, HomeText.searchLabel, () {
              if (found is HelpSearchResults && found.rows.isNotEmpty) widget.onOpenArticle(found.rows.first.id);
            }, TextInputAction.search, 'cb-home-help-input'),
          if (found is HelpSearchResults)
            for (final r in found.rows)
              row(id: 'cb-home-help-result-${r.id}', lead: iconBox('doc'), title: runs(r.title), sub: r.sub, onTap: () => widget.onOpenArticle(r.id))
          else if (found is HelpSearchEmpty)
            Padding(
              key: const ValueKey('cb-home-help-empty'),
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
              child: Column(children: [
                Text(found.text, textAlign: TextAlign.center, style: ts(13.5, pal.muted)),
                const SizedBox(height: 10),
                Material(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: const ValueKey('cb-home-help-instead'),
                    onTap: () => widget.onShowChat(found.asks ? _helpQuery.text.trim() : null),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                      child: Text(found.action, style: ts(13.5, Colors.white, weight: FontWeight.w600)),
                    ),
                  ),
                ),
              ]),
            )
          else ...[
            Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Semantics(header: true, child: Text(h.title, style: ts(13, pal.ink, weight: FontWeight.w700, spacing: 0.26))),
                ),
              ),
              if (h.seeAll) Padding(padding: const EdgeInsets.only(right: 6, top: 4), child: seeAll(HomeText.seeAll, () => widget.onShowHelp(), 'cb-home-help-all')),
            ]),
            for (final a in h.recent)
              row(
                id: 'cb-home-article-${a.id}',
                lead: a.image != null && _ok(a.image) ? _img(a.image!, w: 44, h: 44, radius: BorderRadius.circular(10), bg: pal.soft) : iconBox('doc'),
                title: TextSpan(text: a.title),
                sub: a.description,
                onTap: () => widget.onOpenArticle(a.id),
              ),
            if (h.topics.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 2),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
                child: SingleChildScrollView(
                  key: const ValueKey('cb-home-topics'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                  child: Row(children: [
                    for (var i = 0; i < h.topics.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Material(
                        color: pal.soft,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          key: ValueKey('cb-home-topic-${h.topics[i].id}'),
                          onTap: () => widget.onShowHelp(h.topics[i].id),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(h.topics[i].name, style: ts(12.5, _mix(pal.muted, pal.ink, 0.6), weight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              Text('${h.topics[i].count}', style: ts(11, _mix(pal.card, pal.muted, 0.75), weight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
          ],
        ]),
      );
    }

    // The customer logos show once one has really loaded (trust.ts): a
    // label over nothing is a claim with no proof.
    Widget? trust() {
      final logos = m.trust!.logos.where(_ok).toList();
      if (logos.isEmpty) return null;
      return Padding(
        key: const ValueKey('cb-home-trust'),
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Column(children: [
          if (m.trust!.label.isNotEmpty && _logoLoaded)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(m.trust!.label, textAlign: TextAlign.center, style: ts(12, pal.muted, weight: FontWeight.w600))),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 18, runSpacing: 12, children: [
            for (final src in logos)
              Image(
                image: _image(src),
                height: 22,
                width: 88,
                fit: BoxFit.contain,
                // No image filters here: the web's grayscale is drawn as 55%.
                opacity: const AlwaysStoppedAnimation(0.55),
                semanticLabel: HomeText.customerLogo,
                frameBuilder: (_, child, frame, sync) {
                  if ((frame != null || sync) && !_logoLoaded) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _logoLoaded = true);
                    });
                  }
                  return child;
                },
                errorBuilder: (_, __, ___) {
                  _lose(src);
                  return const SizedBox.shrink();
                },
              ),
          ]),
        ]),
      );
    }

    final shown = m.order.where((p) => !(asking && hiddenWhileAsking.contains(p))).toList();
    const delays = {
      HomeSection.ask: 220,
      HomeSection.resume: 220,
      HomeSection.requests: 220,
      HomeSection.talk: 220,
      HomeSection.help: 300,
      HomeSection.trust: 300,
    };
    Widget? part(HomeSection s) => switch (s) {
          HomeSection.ask => ask(),
          HomeSection.resume => resume(),
          HomeSection.requests => requests(),
          HomeSection.talk => talk(),
          HomeSection.help => help(),
          HomeSection.trust => trust(),
        };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureBand();
    });

    final header = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m.brand != null)
            Padding(
              key: const ValueKey('cb-home-brand'),
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                if (_ok(m.brand!.logo)) ...[
                  _img(m.brand!.logo, w: 40, h: 40, radius: BorderRadius.circular(20)),
                  const SizedBox(width: 10),
                ],
                if (m.brand!.name.isNotEmpty)
                  Flexible(child: Text(m.brand!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, bandInk, weight: FontWeight.w600, spacing: -0.15))),
              ]),
            ),
          if (widget.mascotBuilder != null) widget.mascotBuilder!(context, m.mascot),
          Text(m.hello, key: const ValueKey('cb-home-hello'), style: ts(13.5, bandInk.withValues(alpha: 0.82), weight: FontWeight.w600)),
          if (m.title.isNotEmpty)
            Semantics(
              header: true,
              child: Text(m.title, key: const ValueKey('cb-home-title'), style: ts(24, bandInk, weight: FontWeight.w700, spacing: -0.48, height: 29 / 24)),
            ),
        ]),
      ),
      if (widget.onClose != null) ...[
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: HomeText.close,
          excludeSemantics: true,
          child: InkWell(
            key: const ValueKey('cb-home-close'),
            onTap: widget.onClose,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 32, height: 32, child: Center(child: HomeIcon('close', color: bandInk, size: 18))),
          ),
        ),
      ],
    ]);

    return Material(
      key: const ValueKey('cb-home'),
      color: pal.page,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Stack(key: _content, children: [
            // The brand band, scrolling with the content, ending behind the middle of "Talk to us".
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: asking ? 250 : _band,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('cb-home-band'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: const Alignment(-0.5, -0.866), end: const Alignment(0.5, 0.866), colors: [bandA, bandB]),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Rise(delay: 100, still: still, child: Padding(padding: const EdgeInsets.only(bottom: 8), child: header)),
                _Rise(
                  delay: 160,
                  still: still,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(m.description, key: const ValueKey('cb-home-description'), style: ts(14.5, bandInk.withValues(alpha: 0.92), height: 21 / 14.5)),
                  ),
                ),
                for (final s in shown)
                  if (part(s) case final node?) _Rise(key: ValueKey('rise-${s.name}'), delay: delays[s]!, still: still, child: node),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
