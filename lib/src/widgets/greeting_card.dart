/// The greeting card by the closed launcher, dressed as the web widget dresses
/// it (conferbot-widget css/polish-home.css .cb-greet and .cb-greet--<style>,
/// ts/home/firstImpression.ts, ts/home/greetingStyle.ts; ported from the React
/// Native SDK's src/components/FloatingWidget/GreetingCard.tsx and its
/// docs/greeting-card-native-spec.md): the plain card, a handwritten note, a
/// phone text (the default), a postcard, a sticky note, a typewriter, glass, a
/// push notification, neon, a voice note or an aurora edge, each with its
/// reveal. Fonts are the platform's nearest ones (nothing is bundled).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/customization/svg_path.dart';
import '../core/customization/widget_theme.dart';
import 'greeting_controller.dart';

/// The platform's nearest fonts to the web's (spec 0.4).
class _Fonts {
  static bool get _apple => defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
  static String get note => _apple ? 'Noteworthy' : 'casual';
  static String get sticky => _apple ? 'Marker Felt' : 'casual';
  static String get serif => _apple ? 'Georgia' : 'serif';
  static String get mono => _apple ? 'Courier New' : 'monospace';
  static String get system => _apple ? '.AppleSystemUIFont' : 'Roboto';
}

const _widths = {
  'card': 296.0, 'note': 296.0, 'imessage': 270.0, 'postcard': 296.0, 'sticky': 250.0, 'typewriter': 296.0,
  'glass': 296.0, 'notification': 300.0, 'neon': 296.0, 'voice': 280.0, 'aurora': 296.0,
};

const _voiceBars = [30, 93, 41, 44, 38, 65, 74, 73, 84, 47, 44, 32, 74, 37, 98, 52, 67, 38, 42, 65, 64, 94];

const _closeD = 'm7.314 5.9l3.535-3.536A1 1 0 1 0 9.435.95L5.899 4.485L2.364.95A1 1 0 1 0 .95 2.364l3.535 3.535L.95 9.435a1 1 0 1 0 1.414 1.414l3.535-3.535l3.536 3.535a1 1 0 1 0 1.414-1.414L7.314 5.899z';
const _tailD = 'M0 0 C 2 9 7 14 16 16 C 8 16 3 14 0 11 Z';
const _playD = 'M8 5.5v13l10.5-6.5z';

Color _c(String v, [double a = 1]) {
  final p = WidgetTheme.parseColor(v) ?? const Rgba(0, 0, 0);
  return Color.fromRGBO(p.r.round(), p.g.round(), p.b.round(), p.a * a);
}

const _ink = Color(0xFF0F172A);
const _slate = Color(0xFF94A3B8);

Path _svg(String d) {
  final p = Path();
  for (final s in parseSvgPath(d)) {
    switch (s) {
      case SvgMove(): p.moveTo(s.x, s.y);
      case SvgLine(): p.lineTo(s.x, s.y);
      case SvgCubic(): p.cubicTo(s.x1, s.y1, s.x2, s.y2, s.x, s.y);
      case SvgClose(): p.close();
    }
  }
  return p;
}

/// A CSS box-shadow (x y blur spread colour), drawn outside the box only, as CSS does.
class _Shadow {
  final double x, y, blur, spread;
  final Color color;
  const _Shadow(this.x, this.y, this.blur, this.spread, this.color);
}

class _ShadowPainter extends CustomPainter {
  final BorderRadius radius;
  final List<_Shadow> shadows;
  _ShadowPainter(this.radius, this.shadows);

  @override
  void paint(Canvas canvas, Size size) {
    final box = radius.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipPath(Path.combine(PathOperation.difference, Path()..addRect(box.outerRect.inflate(200)), Path()..addRRect(box)));
    for (final s in shadows) {
      final paint = Paint()..color = s.color;
      if (s.blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
      canvas.drawRRect(box.shift(Offset(s.x, s.y)).inflate(s.spread), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => true;
}

/// An elliptical radial gradient (CSS radial-gradient(rx% ry% at fx fy, ...)).
class _EllipsePainter extends CustomPainter {
  final double fx, fy, rx, ry;
  final List<Color> colors;
  final List<double> stops;
  _EllipsePainter(this.fx, this.fy, this.rx, this.ry, this.colors, this.stops);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.translate(fx * size.width, fy * size.height);
    canvas.scale(rx * size.width, ry * size.height);
    canvas.drawPaint(Paint()..shader = ui.Gradient.radial(Offset.zero, 1, colors, stops));
  }

  @override
  bool shouldRepaint(_EllipsePainter old) => true;
}

/// An SVG path in a [box]-unit square, filled.
class _PathPainter extends CustomPainter {
  final String d;
  final double box;
  final Color color;
  _PathPainter(this.d, this.box, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / box, size.height / box);
    canvas.drawPath(_svg(d), Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.color != color || old.d != d;
}

/// The close glyph: the web's X in a viewBox of -6 -6 24 24.
class _ClosePainter extends CustomPainter {
  final Color color;
  _ClosePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.translate(6, 6);
    canvas.drawPath(_svg(_closeD), Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_ClosePainter old) => old.color != color;
}

/// Note paper: 1px rules every 26px from 69px down, plus the previous tile's line above 44px.
class _RulesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color.fromRGBO(59, 130, 246, 0.16);
    for (var y = 69.0; y < size.height; y += 26) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
    for (var k = 0; k < 40; k++) {
      final y = 69 - size.height + 26 * k;
      if (y >= 0 && y < 44) canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_RulesPainter old) => false;
}

/// The airmail edge: red 12 / paper 6 / blue 12 / paper 6 bands at 135deg, from the top-left corner.
class _AirmailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFBF6EA));
    canvas.save();
    canvas.rotate(math.pi / 4);
    final len = (size.width + size.height) / math.sqrt2 + 36;
    final red = Paint()..color = const Color(0xFFD9383A);
    final blue = Paint()..color = const Color(0xFF2754C5);
    for (var s = 0.0; s < len; s += 36) {
      canvas.drawRect(Rect.fromLTWH(s, -len, 12, len * 2), red);
      canvas.drawRect(Rect.fromLTWH(s + 18, -len, 12, len * 2), blue);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AirmailPainter old) => false;
}

/// The stamp's perforation: 3px paper dots round the box inflated by 2.5, ~6 apart.
class _PerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(4.5); // the stamp box sits 2 (frame) + 2.5 inside this canvas' edge
    final paint = Paint()..color = const Color(0xFFFBF6EA);
    void side(Offset a, Offset b) {
      final n = ((b - a).distance / 6).round();
      for (var i = 0; i <= n; i++) {
        canvas.drawCircle(Offset.lerp(a, b, i / n)!, 1.5, paint);
      }
    }

    final o = r.inflate(2.5);
    side(o.topLeft, o.topRight);
    side(o.topRight, o.bottomRight);
    side(o.bottomRight, o.bottomLeft);
    side(o.bottomLeft, o.topLeft);
  }

  @override
  bool shouldRepaint(_PerforationPainter old) => false;
}

/// The postmark: a 2px ring with 1px lines every 6px, clipped to the circle.
class _PostmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: 21)));
    final line = Paint()..color = const Color.fromRGBO(43, 33, 24, 0.28);
    for (var k = 0; k < 7; k++) {
      canvas.drawRect(Rect.fromLTWH(0, 5.0 + 6 * k, size.width, 1), line);
    }
    canvas.restore();
    canvas.drawCircle(c, 21, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color.fromRGBO(43, 33, 24, 0.35));
  }

  @override
  bool shouldRepaint(_PostmarkPainter old) => false;
}

/// Linear keyframes: the value at [t] between [at] stops.
double _keys(double t, List<double> at, List<double> v) {
  if (t <= at.first) return v.first;
  for (var i = 1; i < at.length; i++) {
    if (t <= at[i]) return v[i - 1] + (v[i] - v[i - 1]) * (t - at[i - 1]) / (at[i] - at[i - 1]);
  }
  return v.last;
}

class GreetingCard extends StatefulWidget {
  final GreetingCardData data;

  /// The card tapped: open the chat (or send, or open the link).
  final VoidCallback onPress;

  /// The X: dismiss.
  final VoidCallback onClose;
  final ValueChanged<String> onStarter;

  /// The launcher is on the left: the entrance grows from the bottom-left.
  final bool alignLeft;

  /// Overrides the phone's reduce-motion setting (tests).
  final bool? reduceMotion;

  const GreetingCard({
    super.key,
    required this.data,
    required this.onPress,
    required this.onClose,
    required this.onStarter,
    this.alignLeft = false,
    this.reduceMotion,
  });

  static double widthOf(String style) => _widths[style] ?? 296;

  @override
  State<GreetingCard> createState() => _GreetingCardState();
}

class _GreetingCardState extends State<GreetingCard> with TickerProviderStateMixin {
  late final AnimationController _enter;
  AnimationController? _reveal, _loop, _bars, _spin;
  Timer? _typeTimer;
  String _typed = '';
  bool _reduced = false;
  bool _started = false;

  GreetingCardData get d => widget.data;
  String get style => d.style;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: Duration(milliseconds: style == 'neon' ? 900 : (style == 'notification' ? 500 : 620)));
    _typed = d.text;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = widget.reduceMotion ?? MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduced) {
      _enter.value = 1;
      return;
    }
    _enter.forward();
    // imessage: typing dots 1.1s, the bubble pops at 1.05s, "Delivered" and chips at 1.45s.
    if (style == 'imessage' && d.firstShow) {
      _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 1750))..forward();
    }
    // typewriter: typed from 260ms, 34ms + up to 30ms a character, a pause after punctuation.
    if (style == 'typewriter') {
      _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
      _typed = '';
      final rnd = math.Random();
      var i = 0;
      void step() {
        if (!mounted) return;
        i += 1;
        setState(() => _typed = d.text.substring(0, i));
        if (i >= d.text.length) return;
        final ch = d.text[i - 1];
        _typeTimer = Timer(Duration(milliseconds: '.,!?'.contains(ch) ? 204 : 34 + rnd.nextInt(31)), step);
      }

      _typeTimer = Timer(const Duration(milliseconds: 260), d.text.isEmpty ? () {} : step);
    }
    // voice: bars squash to 35% and back, twice, 60ms apart.
    if (style == 'voice') {
      _bars = AnimationController(vsync: this, duration: Duration(milliseconds: (_voiceBars.length - 1) * 60 + 2400))..forward();
    }
    // aurora: the coloured edge turns once every 6s.
    if (style == 'aurora') {
      _spin = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    }
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _enter.dispose();
    _reveal?.dispose();
    _loop?.dispose();
    _bars?.dispose();
    _spin?.dispose();
    super.dispose();
  }

  double _ms(AnimationController? c) => c == null ? double.infinity : c.value * c.duration!.inMilliseconds;

  // ---- the parts ----

  TextStyle get _base => TextStyle(fontFamily: d.font ?? _Fonts.system, color: _ink, fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none);

  Widget _close({double top = 10, double right = 10, Color color = _slate, Color? circle, double size = 26, double glyph = 20, List<BoxShadow>? shadow}) {
    return Positioned(
      top: top,
      right: right,
      child: Semantics(
        button: true,
        label: 'Dismiss',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: circle, borderRadius: BorderRadius.circular(circle != null ? size / 2 : 8), boxShadow: shadow),
            child: CustomPaint(size: Size(glyph, glyph), painter: _ClosePainter(color)),
          ),
        ),
      ),
    );
  }

  Widget _avatar(double size, double radius) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: size,
          height: size,
          color: const Color(0xFFEEF2F7),
          child: Image.network(d.head.avatar!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      );

  /// The head: avatar, name, "Online".
  Widget _head({TextStyle name = const TextStyle(), TextStyle status = const TextStyle(), double avatar = 32, double? avatarRadius, bool showAvatar = true, String? statusText, bool dot = true, bool row = false, double padRight = 22, bool upper = false}) {
    final nameText = Text(upper ? d.head.name.toUpperCase() : d.head.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _base.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.25).merge(name));
    final showStatus = statusText != null || d.head.online;
    final statusRow = Padding(
      padding: EdgeInsets.only(right: row ? 18 : 0),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot && statusText == null) ...[
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(statusText ?? 'Online', maxLines: row ? 1 : 2, overflow: TextOverflow.ellipsis, style: _base.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF64748B), height: 1.25).merge(status)),
        ),
      ]),
    );
    return Padding(
      padding: EdgeInsets.only(right: padRight),
      child: Row(children: [
        if (showAvatar && d.head.avatar != null) ...[_avatar(avatar, avatarRadius ?? avatar / 2), const SizedBox(width: 10)],
        Expanded(
          child: row
              ? Row(children: [Flexible(child: nameText), const Spacer(), if (showStatus) statusRow])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [nameText, if (showStatus) statusRow]),
        ),
      ]),
    );
  }

  Widget _msg(TextStyle s, {int lines = 3}) {
    final style0 = _base.copyWith(height: 1.45, color: const Color(0xFF1E293B)).merge(s);
    if (style == 'typewriter') {
      final caretOn = !_reduced && (_loop?.value ?? 0) < 0.5;
      return Text.rich(
        TextSpan(children: [
          TextSpan(text: _typed),
          if (!_reduced)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: const EdgeInsets.only(left: 1),
                child: Transform.translate(
                  offset: Offset(0, (style0.fontSize ?? 15) * 0.15),
                  child: Container(width: (style0.fontSize ?? 15) * 0.55, height: (style0.fontSize ?? 15) * 1.05, color: caretOn ? _c(d.accent) : const Color(0x00000000)),
                ),
              ),
            ),
        ]),
        semanticsLabel: d.text,
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
        style: style0,
      );
    }
    return Text(d.text, maxLines: lines, overflow: TextOverflow.ellipsis, style: style0);
  }

  Widget _chips({BoxDecoration? deco, TextStyle text = const TextStyle(), EdgeInsets pad = const EdgeInsets.symmetric(vertical: 6, horizontal: 12), WrapAlignment align = WrapAlignment.start}) {
    final deco0 = deco ?? BoxDecoration(color: _c(d.accent, 0.07), border: Border.all(color: _c(d.accent, 0.22)), borderRadius: BorderRadius.circular(999));
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: align,
        children: [
          for (final s in d.starters)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onStarter(s),
              child: Container(
                padding: pad,
                decoration: deco0,
                child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: _base.copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3, color: _c(d.accent)).merge(text)),
              ),
            ),
        ],
      ),
    );
  }

  static List<Widget> _spaced(List<Widget?> items, double gap) {
    final out = <Widget>[];
    for (final w in items.whereType<Widget>()) {
      if (out.isNotEmpty) out.add(SizedBox(height: gap));
      out.add(w);
    }
    return out;
  }

  /// A card: its shadow (outside only), its clipped backgrounds, the content, then what overhangs.
  Widget _shell({
    required BorderRadius radius,
    Color? color,
    List<_Shadow> shadows = const [],
    List<Widget> under = const [],
    required List<Widget?> children,
    List<Widget> over = const [],
    EdgeInsets padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    double rotate = 0,
  }) {
    final card = Stack(clipBehavior: Clip.none, children: [
      if (shadows.isNotEmpty) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ShadowPainter(radius, shadows)))),
      Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(fit: StackFit.expand, children: [if (color != null) ColoredBox(color: color), ...under]),
          ),
        ),
      ),
      Padding(
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: _spaced(children, 8)),
      ),
      ...over,
    ]);
    return rotate == 0 || _reduced ? card : Transform.rotate(angle: rotate * math.pi / 180, child: card);
  }

  // ---- the styles ----

  Widget _imessage() {
    final reveal = _reveal != null;
    final ms = _ms(_reveal);
    final pop = reveal ? const Cubic(0.2, 1.3, 0.4, 1).transform(((ms - 1050) / 420).clamp(0.0, 1.0)) : 1.0;
    final late = reveal ? Curves.ease.transform(((ms - 1450) / 300).clamp(0.0, 1.0)) : 1.0;
    final bubbleBg = d.bubble.bg;
    final gradient = bubbleBg.length > 1 ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_c(bubbleBg[0]), _c(bubbleBg[1])]) : null;
    Widget tail(Color c) => Positioned(right: -5, bottom: 0, child: IgnorePointer(child: CustomPaint(size: const Size(16, 16), painter: _PathPainter(_tailD, 16, c))));

    final bubble = Opacity(
      opacity: pop.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.4 + 0.6 * pop,
        alignment: Alignment.bottomRight,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 270 * 0.88),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
            decoration: BoxDecoration(
              color: gradient == null ? _c(bubbleBg.first) : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(19),
              boxShadow: const [BoxShadow(offset: Offset(0, 10), blurRadius: 21.6, spreadRadius: -12, color: Color.fromRGBO(15, 23, 42, 0.45))],
            ),
            child: Text(d.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: _base.copyWith(color: _c(d.bubble.fg), fontSize: 15, fontWeight: FontWeight.w400, height: 1.35)),
          ),
          tail(_c(d.bubble.tail)),
        ]),
      ),
    );

    Widget? dots;
    if (reveal && ms < 1100) {
      final p = ms / 1100;
      dots = Positioned(
        top: 0,
        right: 0,
        child: IgnorePointer(
          child: Opacity(
            opacity: _keys(p, const [0, 0.15, 0.8, 1], const [0, 1, 1, 0]),
            child: Transform.scale(
              scale: _keys(p, const [0, 0.15, 0.8, 1], const [0.6, 1, 1, 1.08]),
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(color: const Color(0xFFE9E9EB), borderRadius: BorderRadius.circular(19)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var k = 0; k < 3; k++) ...[
                      if (k > 0) const SizedBox(width: 4),
                      Builder(builder: (_) {
                        // Each dot bobs on a 1s loop, 150ms after the one before.
                        final elapsed = ms - k * 150;
                        final t = elapsed < 0 ? 0.0 : (elapsed % 1000) / 1000;
                        final o = _keys(t, const [0, 0.3, 0.6, 1], const [0.35, 1, 0.35, 0.35]);
                        final y = _keys(t, const [0, 0.3, 0.6, 1], const [0, -3, 0, 0]);
                        return Transform.translate(
                          offset: Offset(0, y),
                          child: Container(width: 7, height: 7, decoration: BoxDecoration(color: Color.fromRGBO(142, 142, 147, o), shape: BoxShape.circle)),
                        );
                      }),
                    ],
                  ]),
                ),
                tail(const Color(0xFFE9E9EB)),
              ]),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 270,
      child: Stack(clipBehavior: Clip.none, children: [
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Align(alignment: Alignment.centerRight, child: Stack(clipBehavior: Clip.none, children: [bubble, if (dots != null) dots])),
            const SizedBox(height: 4),
            Opacity(
              opacity: late,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('Delivered', textAlign: TextAlign.right, style: _base.copyWith(fontFamily: d.font, fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF8E8E93))),
              ),
            ),
            if (d.starters.isNotEmpty) ...[
              const SizedBox(height: 6),
              Opacity(
                opacity: late,
                child: _chips(
                  align: WrapAlignment.end,
                  deco: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.94),
                    border: Border.all(color: _c(d.accent, 0.35)),
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: const [BoxShadow(offset: Offset(0, 6), blurRadius: 12.9, spreadRadius: -10, color: Color.fromRGBO(15, 23, 42, 0.45))],
                  ),
                ),
              ),
            ],
          ]),
        ),
        _close(top: -6, right: -4, color: const Color(0xFFFFFFFF), circle: const Color.fromRGBO(142, 142, 147, 0.9), size: 22, glyph: 16),
      ]),
    );
  }

  Widget _note() {
    final font = _Fonts.note;
    return _shell(
      radius: BorderRadius.circular(3),
      color: const Color(0xFFFFFDF5),
      rotate: -1.6,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      shadows: const [_Shadow(0, 16, 34, -14, Color.fromRGBO(30, 41, 59, 0.45)), _Shadow(0, 1, 0, 0, Color.fromRGBO(30, 41, 59, 0.06))],
      under: [CustomPaint(painter: _RulesPainter())],
      over: [
        // The tape
        Positioned(
          top: -9,
          left: (296 - 84) / 2,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: 2 * math.pi / 180,
              child: Container(
                width: 84,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(253, 230, 138, 0.72),
                  boxShadow: [BoxShadow(offset: Offset(0, 1), blurRadius: 1, color: Color.fromRGBO(0, 0, 0, 0.12))],
                ),
              ),
            ),
          ),
        ),
        _close(),
      ],
      children: [
        _head(
          name: TextStyle(fontFamily: font, fontSize: 17, color: const Color(0xFF1F2A44)),
          status: TextStyle(fontFamily: font, color: const Color(0xFF475569)),
        ),
        _msg(TextStyle(fontFamily: font, fontSize: 20, fontWeight: FontWeight.w400, height: 1.3, color: const Color(0xFF1F2A44))),
        if (d.starters.isNotEmpty)
          _chips(
            pad: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            deco: BoxDecoration(borderRadius: BorderRadius.circular(4)),
            text: TextStyle(
              fontFamily: font,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: _c(d.accent, 0.5),
            ),
          ),
      ],
    );
  }

  Widget _postcard() {
    final serif = _Fonts.serif;
    const paper = Color(0xFFFBF6EA);
    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ShadowPainter(BorderRadius.circular(6), const [_Shadow(0, 18, 40, -16, Color.fromRGBO(43, 33, 24, 0.5))])))),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(
          painter: _AirmailPainter(),
          child: Container(
            margin: const EdgeInsets.all(6),
            color: paper,
            child: Stack(clipBehavior: Clip.none, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: _spaced([
                  _head(
                    showAvatar: false,
                    upper: true,
                    padRight: 62,
                    dot: false,
                    statusText: 'Greetings from ${d.head.name}',
                    name: TextStyle(fontFamily: serif, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.44, color: const Color(0xFF8A6D4B)),
                    status: TextStyle(fontFamily: serif, fontSize: 17, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, color: const Color(0xFF2B2118), height: 1.25),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 40),
                    child: _msg(TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 15, color: const Color(0xFF3B2F24))),
                  ),
                  if (d.starters.isNotEmpty)
                    _chips(
                      deco: BoxDecoration(color: _c(d.accent, 0.07), border: Border.all(color: _c(d.accent, 0.22)), borderRadius: BorderRadius.circular(3)),
                      text: TextStyle(fontFamily: serif),
                    ),
                ], 8)),
              ),
              // The stamp, its perforation, and the postmark over it.
              Positioned(
                top: 12 - 4.5,
                right: 14 - 4.5,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 49,
                    height: 57,
                    child: Stack(children: [
                      Positioned(
                        left: 2.5,
                        top: 2.5,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFFFFF),
                            boxShadow: [BoxShadow(offset: Offset(0, 1), blurRadius: 1.7, spreadRadius: 2, color: Color.fromRGBO(43, 33, 24, 0.25))],
                          ),
                          child: Container(
                            width: 40,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                transform: const GradientRotation(-20 * math.pi / 180),
                                colors: [_c(d.accent), _c(d.accent, 0.7)],
                              ),
                            ),
                            child: Text('♥', style: TextStyle(fontFamily: serif, fontSize: 20, height: 1, color: const Color.fromRGBO(255, 255, 255, 0.92), decoration: TextDecoration.none)),
                          ),
                        ),
                      ),
                      Positioned.fill(child: CustomPaint(painter: _PerforationPainter())),
                    ]),
                  ),
                ),
              ),
              Positioned(
                top: 34,
                right: 34,
                child: IgnorePointer(child: Transform.rotate(angle: -14 * math.pi / 180, child: CustomPaint(size: const Size(44, 44), painter: _PostmarkPainter()))),
              ),
            ]),
          ),
        ),
      ),
      _close(top: -6, right: -6, circle: paper, shadow: const [BoxShadow(offset: Offset(0, 2), blurRadius: 4.3, color: Color.fromRGBO(0, 0, 0, 0.2))]),
    ]);
  }

  Widget _sticky() {
    final marker = _Fonts.sticky;
    const radius = BorderRadius.only(topLeft: Radius.circular(2), topRight: Radius.circular(2), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(2));
    return _shell(
      radius: radius,
      rotate: 1.8,
      shadows: const [_Shadow(0, 22, 30, -18, Color.fromRGBO(90, 70, 0, 0.55))],
      under: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              transform: GradientRotation(-10 * math.pi / 180),
              colors: [Color(0xFFFFF8B0), Color(0xFFFFEC6E)],
            ),
          ),
        ),
        // The inset darkening toward the bottom edge.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.fromRGBO(120, 90, 0, 0), Color.fromRGBO(120, 90, 0, 0.1)]),
            ),
          ),
        ),
        // The curl
        Positioned(
          right: 0,
          bottom: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(bottomRight: Radius.circular(18)),
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFE45C), Color(0xFFFFE45C), Color.fromRGBO(0, 0, 0, 0.12), Color(0xFFF4D63A), Color(0xFFF4D63A)],
                  stops: [0, 0.5, 0.5, 0.6, 1],
                ),
              ),
            ),
          ),
        ),
      ],
      over: [_close(color: const Color(0xFF6B5A00))],
      children: [
        _head(
          avatar: 26,
          name: TextStyle(fontFamily: marker, fontSize: 15, fontWeight: FontWeight.w400, color: const Color(0xFF3A2F00)),
          status: TextStyle(fontFamily: _Fonts.system, color: const Color(0xFF6B5A00)),
        ),
        _msg(TextStyle(fontFamily: marker, fontSize: 18, fontWeight: FontWeight.w400, height: 1.3, color: const Color(0xFF2B2300))),
        if (d.starters.isNotEmpty)
          _chips(
            deco: BoxDecoration(color: const Color.fromRGBO(255, 255, 255, 0.55), border: Border.all(color: const Color.fromRGBO(58, 47, 0, 0.25)), borderRadius: BorderRadius.circular(999)),
            text: TextStyle(fontFamily: _Fonts.system, color: const Color(0xFF3A2F00)),
          ),
      ],
    );
  }

  Widget _typewriter() {
    final mono = _Fonts.mono;
    return _shell(
      radius: BorderRadius.circular(4),
      color: const Color(0xFFFCFBF6),
      shadows: const [_Shadow(0, 16, 36, -16, Color.fromRGBO(0, 0, 0, 0.45))],
      under: [Positioned(left: 0, right: 0, top: 0, height: 3, child: ColoredBox(color: _c(d.accent)))],
      over: [_close()],
      children: [
        _head(name: TextStyle(fontFamily: mono, letterSpacing: 0.27), status: TextStyle(fontFamily: mono)),
        _msg(TextStyle(fontFamily: mono, fontSize: 15, fontWeight: FontWeight.w600, height: 1.5, color: const Color(0xFF1C1C1C)), lines: 4),
        if (d.starters.isNotEmpty)
          _chips(
            deco: BoxDecoration(color: _c(d.accent, 0.07), border: Border.all(color: _c(d.accent, 0.22)), borderRadius: BorderRadius.circular(3)),
            text: TextStyle(fontFamily: mono),
          ),
      ],
    );
  }

  Widget _glass() {
    return _shell(
      radius: BorderRadius.circular(20),
      shadows: const [_Shadow(0, 24, 48, -20, Color.fromRGBO(15, 23, 42, 0.45))],
      under: [
        BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: const SizedBox.expand()),
        const ColoredBox(color: Color.fromRGBO(255, 255, 255, 0.62)),
        CustomPaint(painter: _EllipsePainter(1, 0, 1.2, 0.9, [_c(d.accent, 0.22), _c(d.accent, 0)], const [0, 0.6])),
        DecoratedBox(decoration: BoxDecoration(border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.7)), borderRadius: BorderRadius.circular(20))),
        const Positioned(left: 10, right: 10, top: 0, height: 1, child: ColoredBox(color: Color.fromRGBO(255, 255, 255, 0.9))),
      ],
      over: [_close()],
      children: [
        _head(status: const TextStyle(color: Color(0xFF475569))),
        _msg(const TextStyle(color: _ink)),
        if (d.starters.isNotEmpty)
          _chips(
            deco: BoxDecoration(color: const Color.fromRGBO(255, 255, 255, 0.7), border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)), borderRadius: BorderRadius.circular(999)),
            text: const TextStyle(color: _ink),
          ),
      ],
    );
  }

  Widget _notification() {
    final sys = _Fonts.system;
    return _shell(
      radius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      shadows: const [_Shadow(0, 18, 40, -16, Color.fromRGBO(0, 0, 0, 0.45))],
      under: [
        BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: const SizedBox.expand()),
        const ColoredBox(color: Color.fromRGBO(246, 246, 248, 0.88)),
        DecoratedBox(decoration: BoxDecoration(border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.08), width: 0.5), borderRadius: BorderRadius.circular(22))),
      ],
      over: [_close()],
      children: [
        _head(
          avatar: 22,
          avatarRadius: 6,
          row: true,
          upper: true,
          dot: false,
          statusText: 'now',
          name: TextStyle(fontFamily: sys, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.24, color: const Color(0xFF555555)),
          status: TextStyle(fontFamily: sys, color: const Color(0xFF8E8E93)),
        ),
        _msg(TextStyle(fontFamily: sys, fontSize: 14.5, height: 1.35, color: const Color(0xFF111111))),
        if (d.starters.isNotEmpty)
          _chips(
            deco: BoxDecoration(color: const Color.fromRGBO(0, 0, 0, 0.06), borderRadius: BorderRadius.circular(12)),
            text: TextStyle(fontFamily: sys, color: const Color(0xFF111111)),
          ),
      ],
    );
  }

  Widget _neon() {
    final a = d.accent;
    return _shell(
      radius: BorderRadius.circular(16),
      shadows: [_Shadow(0, 0, 18, 0, _c(a, 0.55)), _Shadow(0, 0, 42, -6, _c(a, 0.5)), const _Shadow(0, 24, 40, -20, Color.fromRGBO(0, 0, 0, 0.7))],
      under: [
        CustomPaint(painter: _EllipsePainter(0, 0, 1.4, 1.2, const [Color(0xFF1B1530), Color(0xFF07070C)], const [0, 0.7])),
        DecoratedBox(decoration: BoxDecoration(border: Border.all(color: _c(a, 0.95), width: 1.5), borderRadius: BorderRadius.circular(16))),
      ],
      over: [_close(color: const Color(0xFFC4B5FD))],
      children: [
        _head(
          name: TextStyle(color: const Color(0xFFFFFFFF), shadows: [Shadow(color: _c(a, 0.9), blurRadius: 8), Shadow(color: _c(a, 0.6), blurRadius: 18)]),
          status: const TextStyle(color: Color(0xFFA5A3C7)),
        ),
        _msg(const TextStyle(color: Color(0xFFEDE9FE))),
        if (d.starters.isNotEmpty)
          _chips(
            deco: BoxDecoration(
              border: Border.all(color: _c(a, 0.8)),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(blurRadius: 8, color: _c(a, 0.35))],
            ),
            text: const TextStyle(color: Color(0xFFF5F3FF)),
          ),
      ],
    );
  }

  Widget _voice() {
    final words = d.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final secs = (words / 2.4 + 0.5).floor().clamp(2, 59);
    final bg = d.bubble.bg;
    final fg = _c(d.bubble.fg);
    final ms = _ms(_bars);
    double barScale(int i) {
      if (_bars == null) return 1;
      final t = ms - i * 60;
      if (t <= 0 || t >= 2400) return 1;
      final half = (t % 1200) / 600; // 0..2: down then up
      final e = Curves.easeInOut.transform(half <= 1 ? half : 2 - half);
      return 1 - 0.65 * e;
    }

    return _shell(
      radius: BorderRadius.circular(20),
      color: const Color(0xFFFFFFFF),
      shadows: const [_Shadow(0, 20, 40, -18, Color.fromRGBO(15, 23, 42, 0.4))],
      under: [DecoratedBox(decoration: BoxDecoration(border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.06)), borderRadius: BorderRadius.circular(20)))],
      over: [_close()],
      children: [
        _head(),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            color: bg.length > 1 ? null : _c(bg.first),
            gradient: bg.length > 1 ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_c(bg[0]), _c(bg[1])]) : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Color.fromRGBO(255, 255, 255, 0.22), shape: BoxShape.circle),
              child: CustomPaint(size: const Size(14, 14), painter: _PathPainter(_playD, 24, fg)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 26,
                child: Row(children: [
                  for (var i = 0; i < _voiceBars.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      child: Transform.scale(
                        scaleY: barScale(i),
                        child: Container(
                          height: 26 * _voiceBars[i] / 100,
                          decoration: BoxDecoration(color: _c(d.bubble.fg, 0.85), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Opacity(
              opacity: 0.9,
              child: Text('0:${secs.toString().padLeft(2, '0')}', style: _base.copyWith(color: fg, fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _msg(const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF475569))),
        ),
        if (d.starters.isNotEmpty) _chips(),
      ],
    );
  }

  Widget _aurora() {
    final a = _c(d.accent);
    final turn = _spin?.value ?? 0;
    return _shell(
      radius: BorderRadius.circular(20),
      shadows: [_Shadow(0, 24, 50, -22, _c(d.accent, 0.55))],
      under: [
        // A conic ring (accent, cyan, violet, pink) from 12 o'clock, turning, under a white card inset 2.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: SweepGradient(
              colors: [a, const Color(0xFF22D3EE), const Color(0xFFA78BFA), const Color(0xFFF472B6), a],
              transform: GradientRotation(-math.pi / 2 + turn * 2 * math.pi),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(2),
          child: DecoratedBox(decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(18))),
        ),
      ],
      over: [_close()],
      children: [_head(), _msg(const TextStyle()), if (d.starters.isNotEmpty) _chips()],
    );
  }

  Widget _card() {
    return _shell(
      radius: BorderRadius.circular(16),
      color: const Color(0xFFFFFFFF),
      shadows: const [_Shadow(0, 18, 44, -14, Color.fromRGBO(15, 23, 42, 0.32)), _Shadow(0, 0, 0, 1, Color.fromRGBO(15, 23, 42, 0.06))],
      over: [_close()],
      children: [_head(), _msg(const TextStyle()), if (d.starters.isNotEmpty) _chips()],
    );
  }

  Widget _body() {
    switch (style) {
      case 'imessage':
        return _imessage();
      case 'note':
        return _note();
      case 'postcard':
        return _postcard();
      case 'sticky':
        return _sticky();
      case 'typewriter':
        return _typewriter();
      case 'glass':
        return _glass();
      case 'notification':
        return _notification();
      case 'neon':
        return _neon();
      case 'voice':
        return _voice();
      case 'aurora':
        return _aurora();
      default:
        return _card();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listen = Listenable.merge([_enter, if (_reveal != null) _reveal, if (_loop != null) _loop, if (_bars != null) _bars, if (_spin != null) _spin]);
    return AnimatedBuilder(
      animation: listen,
      builder: (context, _) {
        final width = math.min(GreetingCard.widthOf(style), MediaQuery.maybeSizeOf(context)?.width.isFinite == true ? MediaQuery.sizeOf(context).width - 24 : double.infinity);
        Widget card = Semantics(
          button: true,
          label: d.text,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onPress, child: SizedBox(width: width, child: _body())),
        );
        // ---- Entrance (cb-greet-spring 620ms; notification slides down; neon flickers) ----
        final v = _enter.value;
        if (style == 'neon') {
          // Hard steps: 0, 1, .3, 1, .55, 1 at 0/90/144/216/270/342ms.
          final ms = v * 900;
          final o = ms < 90 ? 0.0 : ms < 144 ? 1.0 : ms < 216 ? 0.3 : ms < 270 ? 1.0 : ms < 342 ? 0.55 : 1.0;
          return Opacity(opacity: _reduced ? 1 : o, child: card);
        }
        final notif = style == 'notification';
        final e = (notif ? const Cubic(0.2, 1.2, 0.3, 1) : const Cubic(0.2, 0.9, 0.3, 1)).transform(v).clamp(0.0, 1.0);
        final opacity = _keys(e, const [0, 0.55, 1], const [0, 1, 1]);
        final dy = _keys(e, const [0, 0.55, 0.78, 1], notif ? const [-14, -1, 0, 0] : const [14, -3, 1, 0]);
        final scale = _keys(e, const [0, 0.55, 0.78, 1], notif ? const [0.96, 1.005, 1, 1] : const [0.94, 1.01, 0.998, 1]);
        card = Transform.scale(scale: scale, alignment: widget.alignLeft ? Alignment.bottomLeft : Alignment.bottomRight, child: card);
        return Opacity(opacity: opacity.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, dy), child: card));
      },
    );
  }
}
