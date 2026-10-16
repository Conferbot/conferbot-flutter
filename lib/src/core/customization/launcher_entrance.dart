/// Launcher entrance, as the web widget plays it (conferbot-widget
/// src/ts/launcher/entrance.ts): how the launcher arrives the first time it
/// shows, instead of simply being there.
///
///   customizations.launcherEntrance:
///     "classic"   (default) it just appears;
///     "lightning" a bolt strikes the corner, and the launcher is in the flash;
///     "rocket"    a rocket comes down, burns to land, and becomes the launcher;
///     "portal"    a ring of light opens and the launcher rises out of it;
///     "ufo"       a saucer flies in and beams the launcher down;
///     "drop"      it falls in, squashes on landing, and bounces;
///     "confetti"  it pops in with a burst of confetti;
///     "coin"      it flips in like a coin and catches the light;
///     "meteor", "magic", "parachute", "plane", "egg" (newer, same rules).
///
/// The rules (widgets/launcher_fx_controllers.dart keeps them): once per app
/// session per bot and entrance; never when the chat is open; nothing with
/// reduced motion. The launcher is held invisible until the effect reveals
/// it (it still takes a tap, which ends the entrance and opens the chat).
/// While it lands the greeting card stays hidden; 150ms after it has landed
/// the card fades up (0.9s). Attention and the idle call wait for it.
///
/// Each effect is a set of sprites (drawings with their Web Animations
/// tracks) on a stage laid over the launcher, plus the launcher's own
/// arrival track. Filters (brightness, glows, blur) are left out, as in RN;
/// the movement, timing and opacity are the web's. Ported from the React
/// Native SDK's core/launcherEntrance.ts. Pure: the launcher drives the clock.
library;

import 'dart:math' as math;

import 'fx_paint.dart';
import 'keyframes.dart';

const launcherEntrances = ['classic', 'lightning', 'rocket', 'portal', 'ufo', 'drop', 'confetti', 'coin', 'meteor', 'magic', 'parachute', 'plane', 'egg'];

String normalizeLauncherEntrance(Object? value) => launcherEntrances.contains(value) ? value as String : 'classic';

/// Whether this mount plays an entrance.
bool shouldPlayEntrance({required String mode, required bool reducedMotion, required bool chatOpen, required bool played}) =>
    mode != 'classic' && !reducedMotion && !chatOpen && !played;

/// After the launcher lands: a beat, then the rest fades up.
const settleBeatMs = 150;
const settleFadeMs = 900;

/// The launcher must be laid out this long before the effect starts.
const entranceStartMs = 60;

/// The greeting (and anything else beside the launcher) fading up after the landing (cb-ent-reveal).
final Track settleReveal = Track.of([
  {'opacity': 0, 'translate': '0 10px'},
  {'opacity': 1, 'translate': '0 0'},
], duration: settleFadeMs, easing: 'cubic-bezier(0.22, 1, 0.36, 1)', fill: 'both');

/// The stage laid over the launcher. Sizes come from `unit`, the button's
/// short side; (cx, cy) is its centre; `above` the distance from its bottom
/// to the top of the screen; `inward` -1 when it sits on the right.
class EntranceStage {
  final double w, h, unit, cx, cy, above;
  final int inward;
  final String accent;

  /// The launcher's top-left on the screen, and the screen's size.
  final double left, top, winW, winH;
  const EntranceStage({
    required this.w,
    required this.h,
    required this.unit,
    required this.cx,
    required this.cy,
    required this.above,
    required this.inward,
    required this.accent,
    required this.left,
    required this.top,
    required this.winW,
    required this.winH,
  });
}

EntranceStage entranceStage({
  required double width,
  required double height,
  required String position,
  required double screenWidth,
  required double screenHeight,
  required double side,
  required double bottom,
  required String accent,
}) {
  final left = position == 'right' ? screenWidth - side - width : side;
  final top = screenHeight - bottom - height;
  return EntranceStage(
    w: width,
    h: height,
    unit: math.min(width, height),
    cx: width / 2,
    cy: height / 2,
    above: top + height,
    inward: left + width / 2 > screenWidth / 2 ? -1 : 1,
    accent: accent,
    left: left,
    top: top,
    winW: screenWidth,
    winH: screenHeight,
  );
}

/// One drawing on the stage, with its animations. Children sit in its box and move with it.
class FxSprite {
  double x, y, w, h;

  /// The drawing (svg markup for w x h), or a plain box of a colour.
  final String? svg;
  final String? fill;
  final double? radius;

  /// The pivot, in px inside the box (default: its centre).
  final List<double>? origin;

  /// Its own static values (an opacity of 0 until it plays, a fixed rotate...).
  final Map<String, double>? base;
  List<Track> tracks;

  /// offset-path: the box's centre follows this path (px from the box's own top-left), turning with it.
  final String? path;

  /// A stroke drawn on (stroke-dashoffset 100 -> 0), shown as a wipe of the drawing: 'down' or 'right'.
  final String? wipe;

  /// Children are clipped to the box, with this corner radius.
  final double? clip;

  /// `left` animates as a share of this width (px).
  final double? leftOf;
  final List<FxSprite> children;

  FxSprite({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.svg,
    this.fill,
    this.radius,
    this.origin,
    this.base,
    List<Track>? tracks,
    this.path,
    this.wipe,
    this.clip,
    this.leftOf,
    List<FxSprite>? children,
  })  : tracks = tracks ?? [],
        children = children ?? const [];

  FxSprite _with({List<Track>? tracks, List<FxSprite>? children}) => FxSprite(
        x: x,
        y: y,
        w: w,
        h: h,
        svg: svg,
        fill: fill,
        radius: radius,
        origin: origin,
        base: base,
        tracks: tracks ?? this.tracks,
        path: path,
        wipe: wipe,
        clip: clip,
        leftOf: leftOf,
        children: children ?? this.children,
      );
}

class EntrancePlan {
  /// When the launcher itself appears (ms from the start), and how.
  final double revealAt;
  final Track arrive;

  /// When the whole effect is over and the stage goes.
  final double total;
  final List<FxSprite> sprites;

  /// Drawn just behind the launcher (it rises out of it).
  final bool behind;
  const EntrancePlan({required this.revealAt, required this.arrive, required this.total, required this.sprites, this.behind = false});
}

/// When each phase starts: the landing, the rest fading up, the end.
({double landAt, double landedAt, double settleAt, double endAt}) entranceTimeline(EntrancePlan p) {
  final landedAt = p.revealAt + p.arrive.options.duration;
  return (landAt: p.revealAt, landedAt: landedAt, settleAt: landedAt + settleBeatMs, endAt: math.max(p.total, landedAt + settleBeatMs + settleFadeMs) + 60);
}

const _colors = ['#f59e0b', '#ec4899', '#22c55e', '#3b82f6', '#a855f7', '#ef4444'];

/// The web's seeded random (a small LCG), 0..1.
double Function() seeded(int seed) {
  var r = seed == 0 ? 1 : seed;
  return () {
    r = (r * 9301 + 49297) % 233280;
    return r / 233280;
  };
}

/// A lightning channel by midpoint displacement: points, top to bottom.
List<(double, double)> boltPoints(double x1, double y1, double x2, double y2, double spread, double Function() rand, [int depth = 6]) {
  var pts = [(x1, y1), (x2, y2)];
  var disp = spread;
  for (var d = 0; d < depth; d++) {
    final next = [pts[0]];
    for (var i = 1; i < pts.length; i++) {
      final (ax, ay) = pts[i - 1];
      final (bx, by) = pts[i];
      next.add(((ax + bx) / 2 + (rand() - 0.5) * disp, (ay + by) / 2 + (rand() - 0.5) * disp * 0.25));
      next.add(pts[i]);
    }
    pts = next;
    disp *= 0.55;
  }
  return pts;
}

String _f(double x, int d) => jsNum(double.parse(x.toStringAsFixed(d)));
String _n(num x) => jsNum(x);
String _px(num x) => '${jsNum(x)}px';
String _deg(num x) => '${jsNum(x)}deg';
String _tr(num x, num y) => '${_px(x)} ${_px(y)}';

String _toPath(List<(double, double)> pts) => 'M${pts.map((p) => '${_f(p.$1, 1)},${_f(p.$2, 1)}').join(' L')}';
String _svgOf(num w, num h, String vb, String inner) =>
    '<svg xmlns="http://www.w3.org/2000/svg" width="${_f(w.toDouble(), 2)}" height="${_f(h.toDouble(), 2)}" viewBox="$vb">$inner</svg>';

Track _play(List<Keyframe> keyframes, {required num duration, num? delay, num? iterations, String? easing, String? fill}) =>
    Track.of(keyframes, duration: duration, delay: delay, iterations: iterations, easing: easing, fill: fill);

// ---- Shared pieces ----

/// A soft smoke puff at (x, y), drifting by (dx, dy) as it grows and fades.
FxSprite _puff(EntranceStage s, double x, double y, double d, num delay, double dx, double dy, [num dur = 900, String tint = 'rgba(203, 213, 225, 0.9)']) => FxSprite(
      x: x - d / 2,
      y: y - d / 2,
      w: d,
      h: d,
      svg: radialDisc(d, d, stops([tint, 'rgba(148, 163, 184, 0)'])),
      base: {'o': 0},
      tracks: [
        _play([
          {'opacity': 0, 'translate': '0 0', 'scale': 0.4},
          {'opacity': 0.9, 'offset': 0.2},
          {'opacity': 0, 'translate': _tr(dx, dy), 'scale': 1.9},
        ], duration: dur, delay: delay, easing: 'ease-out', fill: 'forwards'),
      ],
    );

/// A ground shockwave: a flattened ring racing out from under the button.
FxSprite _shockwave(EntranceStage s, num delay, [String color = 'rgba(255, 255, 255, 0.9)', num spread = 2.6]) {
  final w = s.w + s.unit * 0.4;
  final h = s.unit * 0.5;
  return FxSprite(
    x: s.cx - w / 2,
    y: s.h - s.unit * 0.25,
    w: w,
    h: h,
    // A 2px border with a soft glow (box-shadow 0 0 10px).
    svg: _svgOf(w, h, '0 0 ${_n(w)} ${_n(h)}',
        '<ellipse cx="${_n(w / 2)}" cy="${_n(h / 2)}" rx="${_n(w / 2 - 1)}" ry="${_n(h / 2 - 1)}" fill="none" stroke="$color" stroke-width="6" stroke-opacity="0.25"/><ellipse cx="${_n(w / 2)}" cy="${_n(h / 2)}" rx="${_n(w / 2 - 1)}" ry="${_n(h / 2 - 1)}" fill="none" stroke="$color" stroke-width="2"/>'),
    base: {'o': 0},
    tracks: [
      _play([
        {'opacity': 0.95, 'scale': 0.4},
        {'opacity': 0, 'scale': spread},
      ], duration: 650, delay: delay, easing: 'cubic-bezier(0.1, 0.8, 0.3, 1)', fill: 'forwards'),
    ],
  );
}

const _star4 = 'M6 0 L7.2 4.8 L12 6 L7.2 7.2 L6 12 L4.8 7.2 L0 6 L4.8 4.8 Z';

/// Twinkling four-point stars round the button.
List<FxSprite> _sparkles(EntranceStage s, int n, num delay, [String color = '#fde047', double reach = 1]) => List.generate(n, (i) {
      final a = (i / n) * math.pi * 2 + 0.4;
      final x = s.cx + math.cos(a) * (s.w / 2 + s.unit * 0.3 * reach);
      final y = s.cy + math.sin(a) * (s.h / 2 + s.unit * 0.3 * reach);
      final size = 9 + (i % 3) * 4;
      return FxSprite(
        x: x - size / 2,
        y: y - size / 2,
        w: size.toDouble(),
        h: size.toDouble(),
        svg: _svgOf(size, size, '0 0 12 12', '<path d="$_star4" fill="$color"/>'),
        base: {'o': 0},
        tracks: [
          _play([
            {'opacity': 0, 'scale': 0, 'rotate': '0deg'},
            {'opacity': 1, 'scale': 1.25, 'rotate': '60deg', 'offset': 0.45},
            {'opacity': 0, 'scale': 0.3, 'rotate': '120deg'},
          ], duration: 620, delay: delay + i * 55, easing: 'ease-out', fill: 'forwards'),
        ],
      );
    });

/// Bits thrown up from the button's base that fall back with gravity.
List<FxSprite> _debris(EntranceStage s, int n, num delay, List<String> colors, [num size = 5, double height = 1]) => List.generate(n, (i) {
      final dir = i % 2 == 1 ? 1 : -1;
      final dx = dir * (s.w / 2 + s.unit * (0.2 + (i % 4) * 0.22));
      final up = s.unit * (0.5 + ((i * 3) % 5) * 0.16) * height;
      final d = size + (i % 3) * 2;
      return FxSprite(
        x: s.cx - d / 2,
        y: s.h - d,
        w: d.toDouble(),
        h: d * 0.8,
        fill: colors[i % colors.length],
        radius: d * 0.35,
        base: {'o': 0},
        tracks: [
          _play([
            {'opacity': 1, 'translate': '0 0', 'rotate': '0deg', 'easing': 'cubic-bezier(0.2, 0.7, 0.4, 1)'},
            {'opacity': 1, 'translate': '${_px(dx * 0.6)} -${_px(up)}', 'rotate': _deg(dir * 200), 'offset': 0.4, 'easing': 'cubic-bezier(0.5, 0, 0.9, 0.5)'},
            {'opacity': 0, 'translate': _tr(dx, s.unit * 0.2), 'rotate': _deg(dir * 420)},
          ], duration: 820, delay: delay, fill: 'forwards'),
        ],
      );
    });

/// A launcher arrival that lands with a jolt (for impacts).
Track _joltArrival(num duration, Keyframe from) => _play([
      {'opacity': 0, 'scale': 0.4, 'translate': '0 0', ...from},
      {'opacity': 1, 'scale': 1.15, 'translate': '-3px 0', 'offset': 0.18},
      {'scale': 0.95, 'translate': '3px 1px', 'offset': 0.3},
      {'scale': 1.03, 'translate': '-2px 0', 'offset': 0.42},
      {'scale': 1, 'translate': '1px 0', 'offset': 0.54},
      {'opacity': 1, 'scale': 1, 'translate': '0 0', 'filter': 'none'},
    ], duration: duration, easing: 'linear');

/// A sprite's tracks delayed (lightning: everything after the storm gathers).
FxSprite _later(FxSprite sp, num ms) => sp._with(
      tracks: sp.tracks.map((t) => t.withDelay(t.options.delay + ms)).toList(),
      children: sp.children.map((c) => _later(c, ms)).toList(),
    );

typedef _Effect = EntrancePlan Function(EntranceStage s, double Function() rand);

final Map<String, _Effect> _effects = {
  // A storm gathers (the corner of the screen dims), then a blue-white bolt
  // with forks races down, flashes, restrikes and fades; sky light, a burst,
  // crackles and a wisp of smoke at the strike point.
  'lightning': (s, rand) {
    const dark = 240;
    final sprites = <FxSprite>[
      FxSprite(
        x: -s.left,
        y: -s.top,
        w: s.winW,
        h: s.winH,
        svg: radialWash(s.winW, s.winH, s.left + s.cx, s.top, s.winW * 0.6, s.winH * 0.85,
            stops(['rgba(8, 12, 32, 0.55)', ('rgba(8, 12, 32, 0.18)', 55), ('rgba(8, 12, 32, 0)', 80)])),
        base: {'o': 0},
        tracks: [
          _play([
            {'opacity': 0},
            {'opacity': 1, 'offset': 0.2},
            {'opacity': 1, 'offset': 0.45},
            {'opacity': 0},
          ], duration: 1150, easing: 'ease-in-out', fill: 'forwards'),
        ],
      ),
    ];
    final after = <FxSprite>[];
    final h = math.min(s.above + s.cy, 560.0);
    const W = 220.0;
    const x = W / 2;
    final main = boltPoints(x, 0, x, h, math.max(24, h * 0.22), rand);
    main[main.length - 1] = (x, h);
    final branches = <String>[];
    for (var i = 0; i < 3; i++) {
      final at = main[(main.length * (0.25 + i * 0.18 + rand() * 0.08)).floor()];
      final dir = rand() > 0.5 ? 1 : -1;
      final len = h * (0.18 + rand() * 0.16);
      final b = boltPoints(at.$1, at.$2, at.$1 + dir * len * (0.4 + rand() * 0.4), at.$2 + len, len * 0.35, rand, 4);
      branches.add(_toPath(b));
    }
    final all = [_toPath(main), ...branches];
    // Glow, halo and core; the blurred layers are a little fainter without the blur.
    String layer(String d, num width, String color, double opacity) =>
        '<path d="$d" fill="none" stroke="$color" stroke-width="${_n(width)}" stroke-opacity="${_n(opacity)}" stroke-linecap="round" stroke-linejoin="round"/>';
    final bolt = [for (var i = 0; i < all.length; i++) layer(all[i], i > 0 ? 8 : 16, '#6d9eff', (i > 0 ? 0.35 : 0.45) * 0.55)].join() +
        [for (var i = 0; i < all.length; i++) layer(all[i], i > 0 ? 2.6 : 5, '#c7dcff', (i > 0 ? 0.7 : 0.95) * 0.85)].join() +
        [for (var i = 0; i < all.length; i++) layer(all[i], i > 0 ? 1 : 2, '#ffffff', 1)].join();
    after.add(FxSprite(
      x: s.cx - x,
      y: s.cy - h,
      w: W,
      h: h,
      svg: _svgOf(W, h, '0 0 ${_n(W)} ${_n(h)}', bolt),
      // Stepped leader: every channel races down in ~110ms.
      wipe: 'down',
      base: {'dash': 100},
      tracks: [
        _play([
          {'strokeDashoffset': 100},
          {'strokeDashoffset': 0},
        ], duration: 110, easing: 'linear', fill: 'forwards'),
        // Return stroke, a dim beat, one restrike, then the channel fades.
        _play([
          {'opacity': 1},
          {'opacity': 1, 'offset': 0.2},
          {'opacity': 0.25, 'offset': 0.3},
          {'opacity': 1, 'offset': 0.38},
          {'opacity': 0.55, 'offset': 0.55},
          {'opacity': 0},
        ], duration: 560, fill: 'forwards'),
      ],
    ));
    // Sky light: the screen lights up blue-white round the strike, twice.
    final skyH = s.top + s.h;
    after.add(FxSprite(
      x: -s.left,
      y: -s.top,
      w: s.winW,
      h: skyH,
      svg: radialWash(s.winW, skyH, s.left + s.cx, skyH * 0.55, s.winW * 0.45, skyH * 0.7, stops(['rgba(210, 226, 255, 0.55)', ('rgba(210, 226, 255, 0)', 70)])),
      base: {'o': 0},
      tracks: [
        _play([
          {'opacity': 0},
          {'opacity': 0.85, 'offset': 0.2},
          {'opacity': 0.12, 'offset': 0.34},
          {'opacity': 0.6, 'offset': 0.42},
          {'opacity': 0},
        ], duration: 620, fill: 'forwards'),
      ],
    ));
    final d = s.unit * 3.2;
    after.add(FxSprite(
      x: s.cx - d / 2,
      y: s.cy - d / 2,
      w: d,
      h: d,
      svg: radialDisc(d, d, stops(['#ffffff', ('rgba(186, 212, 255, 0.9)', 30), ('rgba(109, 158, 255, 0.35)', 55), ('transparent', 75)])),
      base: {'o': 0},
      tracks: [
        _play([
          {'opacity': 0, 'scale': 0.2},
          {'opacity': 1, 'scale': 1, 'offset': 0.25},
          {'opacity': 0.3, 'scale': 1.1, 'offset': 0.5},
          {'opacity': 0, 'scale': 1.45},
        ], duration: 640, delay: 100, easing: 'ease-out', fill: 'forwards'),
      ],
    ));
    // Crackles: tiny arcs that flicker round the button.
    for (var i = 0; i < 7; i++) {
      final a = (i / 7) * math.pi * 2 + rand();
      final r1 = s.unit * 0.55;
      final r2 = s.unit * (0.95 + rand() * 0.35);
      final pts = boltPoints(math.cos(a) * r1, math.sin(a) * r1, math.cos(a) * r2, math.sin(a) * r2, s.unit * 0.25, rand, 3);
      final xs = pts.map((p) => p.$1), ys = pts.map((p) => p.$2);
      final x0 = xs.reduce(math.min) - 2;
      final y0 = ys.reduce(math.min) - 2;
      final bw = xs.reduce(math.max) - x0 + 2;
      final bh = ys.reduce(math.max) - y0 + 2;
      after.add(FxSprite(
        x: s.cx + x0,
        y: s.cy + y0,
        w: bw,
        h: bh,
        svg: _svgOf(bw, bh, '${_n(x0)} ${_n(y0)} ${_n(bw)} ${_n(bh)}', '<path d="${_toPath(pts)}" fill="none" stroke="#e0ecff" stroke-width="1.6" stroke-linecap="round"/>'),
        base: {'o': 0},
        tracks: [
          _play([
            {'opacity': 0},
            {'opacity': 1, 'offset': 0.1},
            {'opacity': 0.1, 'offset': 0.3},
            {'opacity': 1, 'offset': 0.45},
            {'opacity': 0},
          ], duration: 380, delay: 110 + i * 35, fill: 'forwards'),
        ],
      ));
    }
    // A wisp of smoke once it has struck.
    for (var i = 0; i < 3; i++) {
      final pd = s.unit * (0.5 + i * 0.15);
      after.add(FxSprite(
        x: s.cx - pd / 2 + (i - 1) * s.unit * 0.25,
        y: s.cy - pd / 2,
        w: pd,
        h: pd,
        svg: radialDisc(pd, pd, stops(['rgba(203, 213, 225, 0.85)', 'rgba(148, 163, 184, 0)'])),
        base: {'o': 0},
        tracks: [
          _play([
            {'opacity': 0, 'translate': '0 0', 'scale': 0.5},
            {'opacity': 0.55, 'offset': 0.3},
            {'opacity': 0, 'translate': '0 -${_px(s.unit * 0.9)}', 'scale': 1.6},
          ], duration: 1100, delay: 320 + i * 90, easing: 'ease-out', fill: 'forwards'),
        ],
      ));
    }
    return EntrancePlan(
      revealAt: dark + 110,
      arrive: _play([
        {'opacity': 0, 'scale': 0.4, 'translate': '0 0', 'filter': 'brightness(3) drop-shadow(0 0 18px #9ec5ff)'},
        {'opacity': 1, 'scale': 1.16, 'translate': '-3px 0', 'offset': 0.14, 'filter': 'brightness(2.2) drop-shadow(0 0 16px #9ec5ff)'},
        {'scale': 0.96, 'translate': '3px 1px', 'offset': 0.24},
        {'scale': 1.03, 'translate': '-2px 0', 'offset': 0.34, 'filter': 'brightness(1.4) drop-shadow(0 0 12px #9ec5ff)'},
        {'scale': 1, 'translate': '1px 0', 'offset': 0.44},
        {'opacity': 1, 'scale': 1, 'translate': '0 0', 'filter': 'brightness(1) drop-shadow(0 0 0 rgba(158, 197, 255, 0))'},
      ], duration: 1100, easing: 'ease-out'),
      total: dark + 1500,
      sprites: [...sprites, ...after.map((sp) => _later(sp, dark))],
    );
  },

  // A rocket comes down on a flickering flame that burns harder as it slows,
  // leaving a smoke trail; legs unfold for touchdown, a dust ring races out,
  // and the rocket becomes the button.
  'rocket': (s, _) {
    final w = s.unit * 0.78;
    final h = s.unit * 1.6;
    final k = w / 40;
    final accent = s.accent;
    // The drawing reaches past its 40 x 82 box (the flame, the fins): drawn padded.
    FxSprite pad(String inner, num ox, num oy) =>
        FxSprite(x: -5 * k, y: -2 * k, w: 50 * k, h: 92 * k, origin: [(ox + 5) * k, (oy + 2) * k], svg: _svgOf(50 * k, 92 * k, '-5 -2 50 92', inner));
    final body =
        '<defs><linearGradient id="b" x1="0" x2="1"><stop offset="0" stop-color="#94a3b8"/><stop offset="0.4" stop-color="#ffffff"/><stop offset="0.7" stop-color="#e2e8f0"/><stop offset="1" stop-color="#64748b"/></linearGradient>'
        '<radialGradient id="w" cx="0.35" cy="0.35" r="0.7"><stop offset="0" stop-color="#e0f2fe"/><stop offset="1" stop-color="$accent"/></radialGradient></defs>'
        '<path d="M20 1 C32 11 34 28 33 46 L33 58 L7 58 L7 46 C6 28 8 11 20 1 Z" fill="url(#b)" stroke="#64748b" stroke-width="1"/>'
        '<path d="M7 38 L-1 54 L7 57 Z M33 38 L41 54 L33 57 Z" fill="$accent" stroke="rgba(15,23,42,0.35)" stroke-width="1"/>'
        '<path d="M14 10 Q20 4 26 10" fill="none" stroke="$accent" stroke-width="3" stroke-linecap="round"/>'
        '<circle cx="20" cy="27" r="7" fill="url(#w)" stroke="#64748b" stroke-width="1.4"/>'
        '<ellipse cx="17.5" cy="24.5" rx="2.4" ry="1.6" fill="#fff" opacity="0.9"/>'
        '<path d="M12 22 V50" stroke="#fff" stroke-width="2" opacity="0.7" stroke-linecap="round"/>';
    const flame =
        '<defs><radialGradient id="f" cx="0.5" cy="0.1" r="0.9"><stop offset="0" stop-color="#fffbeb"/><stop offset="0.35" stop-color="#fde047"/><stop offset="0.7" stop-color="#fb923c"/><stop offset="1" stop-color="#ef4444" stop-opacity="0"/></radialGradient></defs>'
        '<ellipse cx="20" cy="70" rx="9" ry="16" fill="url(#f)"/><ellipse cx="20" cy="66" rx="5" ry="10" fill="#fffbeb" opacity="0.9"/>';
    const legs = '<path d="M9 50 L3 64 M31 50 L37 64" stroke="#475569" stroke-width="2.4" stroke-linecap="round"/>';
    final fall = s.above + h + 40;
    const D = 1250;
    const decel = 'cubic-bezier(0.22, 0.7, 0.3, 1)';
    final legsL = pad(legs, 20, 56);
    legsL.tracks = [
      _play([
        {'scale': '1 0'},
        {'scale': '1 0', 'offset': 0.7},
        {'scale': '1 1'},
      ], duration: D, fill: 'forwards'),
    ];
    final flameL = pad(flame, 20, 58);
    flameL.tracks = [
      _play([
        {'scale': '1 1'},
        {'scale': '0.85 1.15'},
        {'scale': '1.05 0.9'},
        {'scale': '1 1'},
      ], duration: 120, iterations: (D / 120).ceil()),
      _play([
        {'opacity': 0.8},
        {'opacity': 1, 'offset': 0.7},
        {'opacity': 0},
      ], duration: D + 100, fill: 'forwards'),
    ];
    final rocket = FxSprite(
      x: s.cx - w / 2,
      y: s.h - h,
      w: w,
      h: h,
      tracks: [
        _play([
          {'translate': '0 -${_px(fall)}', 'rotate': '-3deg'},
          {'translate': '0 -10px', 'rotate': '1.5deg', 'offset': 0.88},
          {'translate': '0 0', 'rotate': '0deg'},
        ], duration: D, easing: decel, fill: 'forwards'),
        _play([
          {'opacity': 1, 'scale': 1},
          {'opacity': 0, 'scale': 0.5},
        ], duration: 260, delay: D + 60, easing: 'ease-in', fill: 'forwards'),
      ],
      children: [legsL, flameL, pad(body, 20, 41)],
    );
    final sprites = <FxSprite>[];
    // Smoke left along the path: where the rocket is at each moment.
    double ease(double t) => 1 - math.pow(1 - t, 3).toDouble();
    for (var i = 0; i < 9; i++) {
      final t = 0.1 + i * 0.09;
      final y = s.h - (1 - ease(t)) * fall + s.unit * 0.1;
      if (y < -s.top) continue;
      sprites.add(_puff(s, s.cx + (i % 2 == 1 ? 3 : -3), y, s.unit * (0.35 + i * 0.03), t * D, (i % 2 == 1 ? 1 : -1) * s.unit * 0.25, -s.unit * 0.2, 1100));
    }
    sprites.add(rocket);
    // Touchdown: a dust ring, dust both ways.
    sprites.add(_shockwave(s, D - 40, 'rgba(226, 232, 240, 0.95)'));
    for (var i = 0; i < 8; i++) {
      final dir = i % 2 == 1 ? 1 : -1;
      sprites.add(_puff(s, s.cx, s.h - s.unit * 0.1, s.unit * (0.35 + (i % 3) * 0.12), D - 60 + i * 25, dir * (s.w / 2 + s.unit * (0.3 + (i >> 1) * 0.25)), -s.unit * 0.15, 900));
    }
    return EntrancePlan(revealAt: D + 80, arrive: _joltArrival(520, {}), total: D + 1100, sprites: sprites);
  },

  // A flat, glowing vortex opens on the ground under the button (rings
  // spinning inside a squashed frame), sparks spiral in, a column of light
  // rises; drawn BEHIND the button, which rises out of it; a flash closes it.
  'portal': (s, _) {
    final W = math.max(s.w * 1.35, s.unit * 2);
    final H = W * 0.32;
    final cy = s.h - H * 0.15;
    FxSprite disc(double inset, String svg, num spin, num dur) => FxSprite(
          x: inset,
          y: inset,
          w: W - inset * 2,
          h: W - inset * 2,
          svg: svg,
          tracks: spin != 0
              ? [
                  _play([
                    {'rotate': '0deg'},
                    {'rotate': _deg(spin * 360)},
                  ], duration: dur, iterations: double.infinity),
                ]
              : [],
        );
    double size(double inset) => W - inset * 2;
    // The ring mask (transparent 52%, solid 60-86%, gone at 100%), as a band.
    const ring = (0.56, 0.93);
    final well = FxSprite(
      x: 0,
      y: 0,
      w: W,
      h: W,
      tracks: [
        _play([
          {'opacity': 0, 'scale': 0},
          {'opacity': 1, 'scale': 1.08, 'offset': 0.2, 'easing': 'ease-out'},
          {'opacity': 1, 'scale': 1, 'offset': 0.3},
          {'opacity': 1, 'scale': 1, 'offset': 0.76, 'easing': 'ease-in'},
          {'opacity': 1, 'scale': 0.08, 'offset': 0.92},
          {'opacity': 0, 'scale': 0},
        ], duration: 1650, fill: 'forwards'),
      ],
      children: [
        disc(-W * 0.12, radialDisc(size(-W * 0.12), size(-W * 0.12), stops([s.accent, ('rgba(168, 85, 247, 0.55)', 45), ('transparent', 72)])), 0, 0),
        disc(0, conicDisc(size(0), 0, stops([s.accent, '#a855f7', '#22d3ee', '#f0abfc', s.accent]), ring), 1, 1100),
        disc(W * 0.08, conicDisc(size(W * 0.08), 90, stops(['#22d3ee', ('transparent', 25), ('#a855f7', 50), ('transparent', 75), '#22d3ee']), ring), -1, 700),
        disc(W * 0.16, conicDisc(size(W * 0.16), 45, stops(['#ffffff', ('transparent', 20), ('#f0abfc', 50), ('transparent', 70), '#ffffff']), ring), 1, 520),
        disc(W * 0.22, radialDisc(size(W * 0.22), size(W * 0.22), stops(['#020617', ('#1e1b4b', 55), ('#4c1d95', 80), 'rgba(76, 29, 149, 0)'])), 0, 0),
        disc(W * 0.3,
            conicDisc(size(W * 0.3), 0, stops(['rgba(165, 243, 252, 0.7)', ('transparent', 30), ('rgba(240, 171, 252, 0.6)', 60), ('transparent', 85), 'rgba(165, 243, 252, 0.7)'])), 1, 900),
      ],
    );
    // Sparks drawn in along a spiral: each on an arm spinning inside the frame.
    final arms = <FxSprite>[];
    for (var i = 0; i < 12; i++) {
      final d = (4 + (i % 3) * 1.5) * (W / H) * 0.35;
      final c = i % 2 == 1 ? '#f5d0fe' : '#cffafe';
      arms.add(FxSprite(
        x: W / 2,
        y: W / 2,
        w: 0,
        h: 0,
        origin: [0, 0],
        tracks: [
          _play([
            {'rotate': _deg(i * 30)},
            {'rotate': _deg(i * 30 + 420)},
          ], duration: 950, delay: 180 + i * 35, easing: 'ease-in', fill: 'forwards'),
        ],
        children: [
          FxSprite(
            x: W * 0.62,
            y: -d / 2,
            w: d,
            h: d,
            svg: radialDisc(d, d, stops([c, (c, 70), 'transparent'])),
            base: {'o': 0},
            tracks: [
              _play([
                {'opacity': 0, 'translate': '0 0'},
                {'opacity': 1, 'offset': 0.2},
                {'opacity': 0, 'translate': '-${_px(W * 0.62)} 0'},
              ], duration: 950, delay: 180 + i * 35, easing: 'ease-in', fill: 'forwards'),
            ],
          ),
        ],
      ));
    }
    final frame = FxSprite(x: s.cx - W / 2, y: cy - W / 2, w: W, h: W, base: {'sy': H / W}, children: [well, ...arms]);
    final colW = math.min(W * 0.62, s.w + s.unit * 0.3);
    final colH = s.unit * 2.2;
    final col = FxSprite(
      x: s.cx - colW / 2,
      y: cy - colH,
      w: colW,
      h: colH,
      origin: [colW / 2, colH],
      svg: linearBox(colW, colH, 0, stops(['rgba(240, 171, 252, 0.75)', ('rgba(165, 243, 252, 0.35)', 50), 'rgba(165, 243, 252, 0)']), [colW / 2, colW / 2, 0, 0]),
      base: {'o': 0},
      tracks: [
        _play([
          {'opacity': 0, 'scale': '0.4 0'},
          {'opacity': 1, 'scale': '1 1', 'offset': 0.35},
          {'opacity': 0.6, 'offset': 0.7},
          {'opacity': 0, 'scale': '0.6 1.1'},
        ], duration: 1000, delay: 380, easing: 'ease-out', fill: 'forwards'),
      ],
    );
    final flash = FxSprite(
      x: s.cx - W / 2,
      y: cy - H * 0.3,
      w: W,
      h: H * 0.6,
      svg: radialDisc(W, H * 0.6, stops(['#ffffff', ('rgba(165, 243, 252, 0.7)', 40), ('transparent', 75)])),
      base: {'o': 0},
      tracks: [
        _play([
          {'opacity': 0, 'scale': '0.3 1'},
          {'opacity': 1, 'scale': '1.3 1', 'offset': 0.35},
          {'opacity': 0, 'scale': '0.05 0.4'},
        ], duration: 420, delay: 1250, easing: 'ease-out', fill: 'forwards'),
      ],
    );
    return EntrancePlan(
      revealAt: 450,
      arrive: _play([
        {'opacity': 0, 'scale': 0.55, 'translate': '0 ${_px(s.unit * 0.7)}', 'filter': 'brightness(2.2) drop-shadow(0 0 16px #a5f3fc)', 'easing': 'cubic-bezier(0.2, 0.8, 0.3, 1.2)'},
        {'opacity': 1, 'scale': 1.08, 'translate': '0 -${_px(s.unit * 0.18)}', 'offset': 0.6, 'filter': 'brightness(1.4) drop-shadow(0 0 10px #c084fc)'},
        {'opacity': 1, 'scale': 0.98, 'translate': '0 2px', 'offset': 0.8},
        {'opacity': 1, 'scale': 1, 'translate': '0 0', 'filter': 'brightness(1) drop-shadow(0 0 0 rgba(192, 132, 252, 0))'},
      ], duration: 820),
      total: 1750,
      sprites: [frame, col, flash],
      behind: true,
    );
  },

  // A saucer with chasing rim lights glides in and hovers; its tractor beam
  // lifts sparkles and draws the button down, top to bottom; then it zips off.
  'ufo': (s, _) {
    final w = s.unit * 1.6;
    final h = s.unit * 0.8;
    final k = w / 60;
    final lift = s.unit * 1.9;
    final saucer =
        '<defs><radialGradient id="d" cx="0.38" cy="0.3" r="0.8"><stop offset="0" stop-color="#ffffff"/><stop offset="0.5" stop-color="#bae6fd"/><stop offset="1" stop-color="#0ea5e9"/></radialGradient>'
        '<linearGradient id="h" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f1f5f9"/><stop offset="0.5" stop-color="#94a3b8"/><stop offset="1" stop-color="#334155"/></linearGradient></defs>'
        '<ellipse cx="30" cy="12" rx="12" ry="10.5" fill="url(#d)" stroke="#334155" stroke-width="1"/>'
        '<ellipse cx="26" cy="7.5" rx="4" ry="2.4" fill="#fff" opacity="0.85"/>'
        '<ellipse cx="30" cy="18.5" rx="29" ry="8.5" fill="url(#h)" stroke="#1e293b" stroke-width="1"/>'
        '<ellipse cx="30" cy="16" rx="24" ry="2.2" fill="${s.accent}" opacity="0.85"/>';
    final lxs = [8, 19, 30, 41, 52];
    final lights = [
      for (var i = 0; i < lxs.length; i++)
        () {
          final ly = i == 2 ? 22.5 : (i == 1 || i == 3 ? 21.5 : 19.5);
          final r = 2.1 * k;
          return FxSprite(
            x: lxs[i] * k - r,
            y: ly * k - r,
            w: r * 2,
            h: r * 2,
            fill: '#fde047',
            radius: r,
            tracks: [
              _play([
                {'opacity': 0.25},
                {'opacity': 1, 'offset': 0.2},
                {'opacity': 0.25, 'offset': 0.4},
                {'opacity': 0.25},
              ], duration: 500, delay: i * 100, iterations: double.infinity),
            ],
          );
        }(),
    ];
    final from = s.inward == -1 ? s.winW - s.left + w : -(s.left + w * 2);
    final ufo = FxSprite(
      x: s.cx - w / 2,
      y: -lift,
      w: w,
      h: h,
      origin: [w * 0.5, h * 0.62],
      svg: _svgOf(w, h, '0 0 60 30', saucer),
      tracks: [
        _play([
          {'translate': '${_px(from)} -70px', 'rotate': _deg(s.inward * -16), 'easing': 'cubic-bezier(0.2, 0.8, 0.3, 1)'},
          {'translate': '0 0', 'rotate': _deg(s.inward * 5), 'offset': 0.3},
          {'translate': '0 -4px', 'rotate': '0deg', 'offset': 0.42},
          {'translate': '0 3px', 'rotate': '0deg', 'offset': 0.56},
          {'translate': '0 -2px', 'rotate': '0deg', 'offset': 0.7},
          {'translate': '0 0', 'rotate': '0deg', 'offset': 0.78, 'easing': 'cubic-bezier(0.6, 0, 0.9, 0.4)'},
          {'translate': '${_px(s.inward * -40)} -${_px(s.above + lift + 120)}', 'rotate': _deg(s.inward * 20), 'scale': '0.6 0.6'},
        ], duration: 2300, fill: 'forwards'),
      ],
      children: lights,
    );
    final beamTop = -lift + h * 0.8;
    final beamH = s.h - beamTop;
    final bw = w * 1.05;
    final stripes = StringBuffer();
    for (var y = 0; y < beamH; y += 30) {
      for (final o in const [6, 15, 24]) {
        if (y + o < beamH) stripes.write('<rect x="0" y="${y + o}" width="${_n(bw)}" height="3" fill="rgb(254,249,195)" fill-opacity="0.35"/>');
      }
    }
    final beam = FxSprite(
      x: s.cx - bw / 2,
      y: beamTop,
      w: bw,
      h: beamH,
      svg: _svgOf(
        bw,
        beamH,
        '0 0 ${_n(bw)} ${_n(beamH)}',
        '<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="rgb(254,240,138)" stop-opacity="0.9"/><stop offset="1" stop-color="rgb(254,240,138)" stop-opacity="0.15"/></linearGradient>'
            '<clipPath id="c"><polygon points="${_n(bw * 0.36)},0 ${_n(bw * 0.64)},0 ${_n(bw)},${_n(beamH)} 0,${_n(beamH)}"/></clipPath></defs>'
            '<g clip-path="url(#c)"><rect width="${_n(bw)}" height="${_n(beamH)}" fill="url(#g)"/>$stripes</g>',
      ),
      base: {'o': 0},
      tracks: [
        _play([
          {'opacity': 0},
          {'opacity': 0.95, 'offset': 0.15},
          {'opacity': 0.95, 'offset': 0.8},
          {'opacity': 0},
        ], duration: 1000, delay: 760, fill: 'forwards'),
      ],
    );
    final dots = List.generate(
      8,
      (i) => FxSprite(
        x: s.cx + (i - 3.5) * (s.unit * 0.13),
        y: s.h - 6,
        w: 4,
        h: 4,
        fill: '#fef9c3',
        radius: 2,
        base: {'o': 0},
        tracks: [
          _play([
            {'opacity': 0, 'translate': '0 0'},
            {'opacity': 1, 'offset': 0.2},
            {'opacity': 0, 'translate': '0 -${_px(beamH * 0.8)}'},
          ], duration: 800, delay: 820 + i * 60, easing: 'ease-in', fill: 'forwards'),
        ],
      ),
    );
    return EntrancePlan(
      revealAt: 900,
      arrive: _play([
        {'opacity': 0.2, 'scale': 0.9, 'translate': '0 -${_px(s.unit * 0.35)}', 'clipPath': 'inset(0 0 100% 0)', 'filter': 'brightness(1.8)'},
        {'opacity': 0.6, 'offset': 0.25},
        {'opacity': 0.35, 'offset': 0.35},
        {'opacity': 1, 'scale': 1, 'translate': '0 0', 'clipPath': 'inset(0 0 0% 0)', 'filter': 'brightness(1)', 'offset': 0.8},
        {'opacity': 1, 'scale': 1, 'translate': '0 0', 'clipPath': 'inset(0 0 0% 0)', 'filter': 'brightness(1)'},
      ], duration: 700, easing: 'ease-out'),
      total: 2350,
      sprites: [beam, ...dots, ufo],
    );
  },

  // It falls from the sky with speed lines, stretched by the speed; hits the
  // ground in a squash with a shockwave, pebbles and a ring of cartoon stars;
  // bounces twice and settles.
  'drop': (s, _) {
    final fall = s.above + s.h + 20;
    final sprites = <FxSprite>[];
    for (var i = 0; i < 3; i++) {
      final lh = s.unit * 0.9;
      sprites.add(FxSprite(
        x: s.cx + (i - 1) * s.unit * 0.3,
        y: -s.unit * 1.1,
        w: 2,
        h: lh,
        svg: linearBox(2, lh, 180, stops(['rgba(148, 163, 184, 0)', 'rgba(100, 116, 139, 0.8)']), 1),
        base: {'o': 0},
        tracks: [
          _play([
            {'opacity': 0, 'translate': '0 -${_px(fall * 0.6)}'},
            {'opacity': 0.9, 'translate': '0 0', 'offset': 0.85},
            {'opacity': 0, 'translate': '0 ${_px(s.unit * 0.4)}'},
          ], duration: 480, delay: 20 + i * 30, easing: 'cubic-bezier(0.55, 0, 1, 0.45)', fill: 'forwards'),
        ],
      ));
    }
    const hit = 470;
    sprites.add(_shockwave(s, hit, 'rgba(148, 163, 184, 0.9)', 2.4));
    sprites.addAll(_debris(s, 6, hit, ['#94a3b8', '#64748b', '#cbd5e1'], 5, 0.9));
    sprites.add(_puff(s, s.cx - s.w * 0.3, s.h - 4, s.unit * 0.5, hit, -s.unit * 0.6, -4, 700));
    sprites.add(_puff(s, s.cx + s.w * 0.3, s.h - 4, s.unit * 0.5, hit, s.unit * 0.6, -4, 700));
    // Cartoon stars circling where it hit, for a moment.
    const star5 = 'M6 0 L7.5 4.2 L12 4.6 L8.5 7.4 L9.7 12 L6 9.4 L2.3 12 L3.5 7.4 L0 4.6 L4.5 4.2 Z';
    for (var i = 0; i < 3; i++) {
      sprites.add(FxSprite(
        x: s.cx,
        y: -s.unit * 0.15,
        w: 0,
        h: 0,
        origin: [0, 0],
        base: {'sy': 0.35},
        tracks: [
          _play([
            {'rotate': _deg(i * 120)},
            {'rotate': _deg(i * 120 + 520)},
          ], duration: 1100, delay: hit + 60, fill: 'forwards'),
        ],
        children: [
          FxSprite(
            x: s.unit * 0.55,
            y: -6,
            w: 12,
            h: 12,
            svg: _svgOf(12, 12, '0 0 12 12', '<path d="$star5" fill="#fde047" stroke="#b45309" stroke-width="0.8"/>'),
            base: {'o': 0},
            tracks: [
              _play([
                {'opacity': 0},
                {'opacity': 1, 'offset': 0.15},
                {'opacity': 1, 'offset': 0.75},
                {'opacity': 0},
              ], duration: 1100, delay: hit + 60, fill: 'forwards'),
            ],
          ),
        ],
      ));
    }
    return EntrancePlan(
      revealAt: 0,
      arrive: _play([
        {'opacity': 1, 'translate': '0 -${_px(fall)}', 'scale': '0.86 1.18', 'easing': 'cubic-bezier(0.55, 0, 1, 0.45)'},
        {'translate': '0 0', 'scale': '0.9 1.12', 'offset': 0.43, 'easing': 'ease-out'},
        {'translate': '0 ${_px(s.unit * 0.1)}', 'scale': '1.28 0.72', 'offset': 0.5, 'easing': 'ease-out'},
        {'translate': '0 -${_px(s.unit * 0.45)}', 'scale': '0.93 1.08', 'offset': 0.65, 'easing': 'ease-in'},
        {'translate': '0 0', 'scale': '1.12 0.88', 'offset': 0.78, 'easing': 'ease-out'},
        {'translate': '0 -${_px(s.unit * 0.12)}', 'scale': '0.98 1.02', 'offset': 0.87, 'easing': 'ease-in'},
        {'translate': '0 0', 'scale': '1.03 0.97', 'offset': 0.94},
        {'opacity': 1, 'translate': '0 0', 'scale': '1 1'},
      ], duration: 1100),
      total: 1700,
      sprites: sprites,
    );
  },

  // A confetti cannon: 40 pieces blasted up and out, each tumbling as it
  // flutters down, drifting.
  'confetti': (s, _) {
    const n = 40;
    final fd = s.unit * 2.4;
    final sprites = <FxSprite>[
      FxSprite(
        x: s.cx - s.unit * 1.2,
        y: s.cy - s.unit * 1.2,
        w: fd,
        h: fd,
        svg: radialDisc(fd, fd, stops(['rgba(255, 255, 255, 0.95)', ('rgba(253, 224, 71, 0.4)', 45), ('transparent', 70)])),
        base: {'o': 0},
        tracks: [
          _play([
            {'opacity': 0, 'scale': 0.3},
            {'opacity': 1, 'scale': 1, 'offset': 0.3},
            {'opacity': 0, 'scale': 1.4},
          ], duration: 420, delay: 60, fill: 'forwards'),
        ],
      ),
    ];
    for (var i = 0; i < n; i++) {
      final kind = i % 4;
      final wpx = kind == 1 ? 7 : (kind == 2 ? 4 : 7);
      final hpx = kind == 1 ? 7 : (kind == 2 ? 16 : 10);
      // A fan leaning into the screen (so the burst is never cut off).
      final a = (-170 + (160 * i) / (n - 1)) * (math.pi / 180);
      final v = s.unit * (1.2 + ((i * 7) % 9) * 0.18) + s.w * 0.2;
      final dx = math.cos(a) * v * (s.inward == -1 ? -1 : 1) * -1;
      final dy = math.sin(a) * v;
      final drift = ((i % 3) - 1) * s.unit * 0.4;
      final dur = 1500 + (i % 5) * 140;
      sprites.add(FxSprite(
        x: s.cx - wpx / 2,
        y: s.cy - hpx / 2,
        w: wpx.toDouble(),
        h: hpx.toDouble(),
        fill: i % 5 == 0 ? s.accent : _colors[i % _colors.length],
        radius: kind == 1 ? wpx / 2 : 2,
        base: {'o': 0},
        tracks: [
          _play([
            {'opacity': 1, 'translate': '0 0', 'rotate': '0deg', 'easing': 'cubic-bezier(0.1, 0.8, 0.3, 1)'},
            {'opacity': 1, 'translate': _tr(dx, dy), 'rotate': _deg(160 + i * 23), 'offset': 0.3, 'easing': 'cubic-bezier(0.4, 0, 0.8, 0.6)'},
            {'opacity': 1, 'translate': _tr(dx + drift, dy + s.unit * 1.1), 'rotate': _deg(320 + i * 31), 'offset': 0.75},
            {'opacity': 0, 'translate': _tr(dx - drift, dy + s.unit * 1.8), 'rotate': _deg(420 + i * 37)},
          ], duration: dur, delay: 60 + (i % 6) * 12, fill: 'forwards'),
          // The 3D tumble: the piece flips edge-on and back as it spins.
          _play([
            {'scale': '1 1'},
            {'scale': '1 0.1'},
            {'scale': '1 1'},
          ], duration: 260 + (i % 4) * 70, iterations: (dur / 300).ceil()),
        ],
      ));
    }
    return EntrancePlan(
      revealAt: 0,
      arrive: _play([
        {'opacity': 0, 'scale': 0, 'rotate': '-14deg'},
        {'opacity': 1, 'scale': 1.22, 'rotate': '6deg', 'offset': 0.5},
        {'scale': 0.94, 'rotate': '-3deg', 'offset': 0.72},
        {'scale': 1.03, 'rotate': '1deg', 'offset': 0.86},
        {'opacity': 1, 'scale': 1, 'rotate': '0deg'},
      ], duration: 700, easing: 'ease-out'),
      total: 2200,
      sprites: sprites,
    );
  },

  // Jackpot: it rises spinning like a gold coin, a shower of coins bursts
  // out and falls, it lands with a bounce and a glint sweeps across it.
  'coin': (s, _) {
    final sprites = <FxSprite>[];
    for (var i = 0; i < 12; i++) {
      final d = s.unit * (0.28 + (i % 3) * 0.06);
      final dir = i % 2 == 1 ? 1 : -1;
      final dx = dir * (s.w / 2 + s.unit * (0.2 + (i % 4) * 0.28));
      final up = s.unit * (0.9 + ((i * 5) % 4) * 0.3);
      sprites.add(FxSprite(
        x: s.cx - d / 2,
        y: s.cy - d / 2,
        w: d,
        h: d,
        svg: _svgOf(d, d, '0 0 20 20',
            '<defs><radialGradient id="c" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#fef9c3"/><stop offset="0.45" stop-color="#facc15"/><stop offset="1" stop-color="#a16207"/></radialGradient></defs><circle cx="10" cy="10" r="9" fill="url(#c)" stroke="#854d0e" stroke-width="1"/><circle cx="10" cy="10" r="5.5" fill="none" stroke="#fef08a" stroke-width="1" opacity="0.8"/>'),
        base: {'o': 0},
        tracks: [
          _play([
            {'opacity': 1, 'translate': '0 0', 'easing': 'cubic-bezier(0.2, 0.7, 0.4, 1)'},
            {'opacity': 1, 'translate': '${_px(dx * 0.6)} -${_px(up)}', 'offset': 0.4, 'easing': 'cubic-bezier(0.5, 0, 0.9, 0.5)'},
            {'opacity': 0, 'translate': _tr(dx, s.unit * 0.6)},
          ], duration: 1100, delay: 560 + i * 25, fill: 'forwards'),
          _play([
            {'scale': '1 1'},
            {'scale': '0.1 1'},
            {'scale': '1 1'},
          ], duration: 240, iterations: 5, delay: 560 + i * 25),
        ],
      ));
    }
    sprites.addAll(_sparkles(s, 6, 900, '#fde047', 1.2));
    // The glint: a band that sweeps across the button (left -40% -> 115%).
    final bandW = s.w * 0.35;
    sprites.add(FxSprite(
      x: 0,
      y: 0,
      w: s.w,
      h: s.h,
      clip: s.h / 2,
      children: [
        FxSprite(
          x: 0,
          y: -s.h * 0.2,
          w: bandW,
          h: s.h * 1.4,
          leftOf: s.w,
          svg: linearBox(bandW, s.h * 1.4, 100, stops(['transparent', 'rgba(255,255,255,0.75)', 'transparent'])),
          tracks: [
            _play([
              {'left': '-40%'},
              {'left': '115%'},
            ], duration: 520, delay: 1050, easing: 'ease-in-out', fill: 'forwards'),
          ],
        ),
      ],
    ));
    return EntrancePlan(
      revealAt: 0,
      arrive: _play([
        {'opacity': 0, 'scale': 0.3, 'rotate': 'y 0deg', 'translate': '0 ${_px(s.unit * 0.8)}', 'filter': 'brightness(1)'},
        {'opacity': 1, 'rotate': 'y 180deg', 'filter': 'brightness(1.6) sepia(0.4)', 'offset': 0.15},
        {'rotate': 'y 360deg', 'filter': 'brightness(0.8)', 'offset': 0.3},
        {'rotate': 'y 540deg', 'translate': '0 -${_px(s.unit * 0.5)}', 'filter': 'brightness(1.6) sepia(0.4)', 'offset': 0.45, 'scale': 1.1},
        {'rotate': 'y 720deg', 'filter': 'brightness(0.85)', 'offset': 0.6},
        {'rotate': 'y 1080deg', 'translate': '0 0', 'scale': 1.06, 'filter': 'brightness(1.2)', 'offset': 0.8, 'easing': 'ease-out'},
        {'translate': '0 -${_px(s.unit * 0.1)}', 'scale': 0.98, 'offset': 0.9},
        {'opacity': 1, 'rotate': 'y 1080deg', 'translate': '0 0', 'scale': 1, 'filter': 'brightness(1)'},
      ], duration: 1200),
      total: 1900,
      sprites: sprites,
    );
  },

  // A fireball streaks in from the top corner of the screen with a burning
  // tail, strikes with a flash and a shockwave, throws rocks and smoke.
  'meteor': (s, _) {
    const D = 560;
    final sx = s.inward * math.min(s.winW * 0.35, 380.0);
    final sy = -(s.above + s.unit);
    final ang = (math.atan2(-sy, -sx) * 180) / math.pi;
    final len = math.sqrt(sx * sx + sy * sy);
    final bd = s.unit * 0.56;
    final tw = math.min(len * 0.45, 260.0);
    final th = s.unit * 0.4;
    final sprites = <FxSprite>[
      FxSprite(
        x: s.cx,
        y: s.cy,
        w: 0,
        h: 0,
        origin: [0, 0],
        base: {'r': ang},
        tracks: [
          _play([
            {'translate': _tr(sx, sy), 'opacity': 1},
            {'translate': '0 0', 'opacity': 1, 'offset': 0.97},
            {'translate': '0 0', 'opacity': 0},
          ], duration: D, easing: 'cubic-bezier(0.5, 0, 0.9, 0.6)', fill: 'forwards'),
        ],
        children: [
          FxSprite(
            x: -s.unit * 0.1 - tw,
            y: -s.unit * 0.2,
            w: tw,
            h: th,
            svg: linearBox(tw, th, 270, stops(['rgba(253, 224, 71, 0.95)', ('rgba(249, 115, 22, 0.6)', 30), 'rgba(127, 29, 29, 0)']), th / 2),
          ),
          FxSprite(x: -bd / 2, y: -bd / 2, w: bd, h: bd, svg: radialDisc(bd, bd, stops(['#fffbeb', ('#fde047', 30), ('#f97316', 60), '#7c2d12']))),
        ],
      ),
    ];
    final bu = s.unit * 3.4;
    sprites.add(FxSprite(
      x: s.cx - bu / 2,
      y: s.cy - bu / 2,
      w: bu,
      h: bu,
      svg: radialDisc(bu, bu, stops(['#ffffff', ('rgba(253, 224, 71, 0.95)', 25), ('rgba(249, 115, 22, 0.6)', 50), ('transparent', 72)])),
      base: {'o': 0},
      tracks: [
        _play([
          {'opacity': 0, 'scale': 0.2},
          {'opacity': 1, 'scale': 1, 'offset': 0.25},
          {'opacity': 0, 'scale': 1.5},
        ], duration: 620, delay: D - 20, easing: 'ease-out', fill: 'forwards'),
      ],
    ));
    sprites.add(_shockwave(s, D, 'rgba(253, 186, 116, 0.95)', 3));
    sprites.addAll(_debris(s, 9, D, ['#44403c', '#78716c', '#292524', '#f97316'], 6, 1.3));
    for (var i = 0; i < 5; i++) {
      sprites.add(_puff(s, s.cx + (i - 2) * s.unit * 0.25, s.cy, s.unit * (0.55 + (i % 2) * 0.2), D + 120 + i * 60, (i - 2) * s.unit * 0.15, -s.unit * 1.1, 1300, 'rgba(120, 113, 108, 0.75)'));
    }
    return EntrancePlan(
      revealAt: D.toDouble(),
      arrive: _joltArrival(1500, {'filter': 'brightness(1.7) sepia(1) saturate(4) hue-rotate(-20deg) drop-shadow(0 0 14px #f97316)'}),
      total: D + 1600,
      sprites: sprites,
    );
  },

  // A top hat appears where the button will be, a wand taps it twice in a
  // flurry of sparkles, and the button springs out; the hat drops away.
  'magic': (s, _) {
    final hw = s.unit * 1.2;
    final hh = s.unit * 1.0;
    final hatTop = s.h - hh * 0.72;
    final sprites = <FxSprite>[
      FxSprite(
        x: s.cx - hw / 2,
        y: hatTop,
        w: hw,
        h: hh,
        svg: _svgOf(hw, hh, '0 0 60 50',
            '<defs><linearGradient id="h" x1="0" x2="1"><stop offset="0" stop-color="#0f172a"/><stop offset="0.35" stop-color="#475569"/><stop offset="0.6" stop-color="#1e293b"/><stop offset="1" stop-color="#020617"/></linearGradient></defs>'
            '<ellipse cx="30" cy="44" rx="29" ry="6" fill="#0f172a"/><path d="M12 44 L14 6 Q30 1 46 6 L48 44 Z" fill="url(#h)"/><rect x="13" y="30" width="34" height="7" fill="${s.accent}"/>'
            '<ellipse cx="30" cy="6" rx="16" ry="4" fill="#334155"/><path d="M19 10 L18 28" stroke="#fff" stroke-width="2" opacity="0.25" stroke-linecap="round"/>'),
        tracks: [
          _play([
            {'opacity': 0, 'scale': 0.3, 'rotate': '-10deg'},
            {'opacity': 1, 'scale': 1.1, 'rotate': '4deg', 'offset': 0.12, 'easing': 'ease-out'},
            {'opacity': 1, 'scale': 1, 'rotate': '0deg', 'offset': 0.2},
            {'opacity': 1, 'scale': 1, 'rotate': '0deg', 'offset': 0.62},
            {'opacity': 1, 'translate': '0 ${_px(s.unit * 0.3)}', 'scale': '1.15 0.85', 'offset': 0.68},
            {'opacity': 0, 'translate': '0 ${_px(s.unit * 0.9)}', 'scale': 0.6},
          ], duration: 2000, fill: 'forwards'),
        ],
      ),
    ];
    final ww = s.unit * 0.9;
    final tilt = s.inward == -1 ? 1 : -1;
    sprites.add(FxSprite(
      x: s.inward == -1 ? s.cx - hw / 2 - ww * 0.8 : s.cx + hw / 2 - ww * 0.2,
      y: hatTop - ww * 0.2,
      w: ww,
      h: ww * 0.2,
      svg: _svgOf(ww, ww * 0.2, '0 0 50 10',
          '<rect x="0" y="3" width="42" height="4" rx="2" fill="#111827"/><rect x="38" y="2.4" width="12" height="5.2" rx="2.4" fill="#f8fafc"/><rect x="0" y="3" width="8" height="4" rx="2" fill="#f8fafc"/>'),
      base: {'o': 0, if (s.inward == 1) 'sx': -1},
      tracks: [
        _play([
          {'opacity': 0, 'rotate': _deg(tilt * -30), 'translate': '${_px(-s.inward * 0)} 0'},
          {'opacity': 1, 'rotate': _deg(tilt * -20), 'offset': 0.12},
          {'rotate': _deg(tilt * 10), 'offset': 0.24},
          {'rotate': _deg(tilt * -20), 'offset': 0.34},
          {'rotate': _deg(tilt * 10), 'offset': 0.44},
          {'opacity': 1, 'rotate': _deg(tilt * -15), 'offset': 0.56},
          {'opacity': 0, 'rotate': _deg(tilt * -30)},
        ], duration: 1400, delay: 150, fill: 'forwards'),
      ],
    ));
    sprites.addAll(_sparkles(s, 5, 480, '#fde047', 0.8));
    sprites.addAll(_sparkles(s, 5, 800, '#f0abfc', 1.1));
    sprites.add(_puff(s, s.cx, s.h - s.unit * 0.1, s.unit * 1.1, 1350, 0, -s.unit * 0.3, 900, 'rgba(226, 232, 240, 0.95)'));
    return EntrancePlan(
      revealAt: 1150,
      arrive: _play([
        {'opacity': 0, 'translate': '0 ${_px(s.unit * 0.55)}', 'scale': 0.5, 'easing': 'cubic-bezier(0.2, 0.8, 0.3, 1)'},
        {'opacity': 1, 'translate': '0 -${_px(s.unit * 0.9)}', 'scale': 1.08, 'rotate': _deg(s.inward * 8), 'offset': 0.45, 'easing': 'cubic-bezier(0.55, 0, 1, 0.45)'},
        {'translate': '0 0', 'scale': '1.12 0.88', 'rotate': '0deg', 'offset': 0.75, 'easing': 'ease-out'},
        {'translate': '0 -4px', 'scale': '0.98 1.02', 'offset': 0.88},
        {'opacity': 1, 'translate': '0 0', 'scale': 1, 'rotate': '0deg'},
      ], duration: 900),
      total: 2300,
      sprites: sprites,
    );
  },

  // It drifts down under a striped parachute, swaying; touches down softly,
  // and the canopy collapses and floats away.
  'parachute': (s, _) {
    final a = s.accent;
    final cw = math.max(s.unit * 1.7, s.w * 0.9);
    final ch = s.unit * 1.25;
    final fall = s.above + ch + s.h;
    const D = 1900;
    final mid = s.left + s.cx;
    final shift = math.min(0.0, s.winW - 6 - (mid + cw / 2)) + math.max(0.0, 6 - (mid - cw / 2));
    final sway = <Keyframe>[
      {'translate': '0 -${_px(fall)}', 'rotate': '0deg'},
      {'translate': '${_px(s.unit * 0.35)} -${_px(fall * 0.72)}', 'rotate': '-9deg', 'offset': 0.22},
      {'translate': '-${_px(s.unit * 0.35)} -${_px(fall * 0.45)}', 'rotate': '8deg', 'offset': 0.45},
      {'translate': '${_px(s.unit * 0.2)} -${_px(fall * 0.2)}', 'rotate': '-5deg', 'offset': 0.68},
      {'translate': '-${_px(s.unit * 0.05)} -${_px(s.unit * 0.12)}', 'rotate': '2deg', 'offset': 0.88},
      {'translate': '0 0', 'rotate': '0deg'},
    ];
    final canopy = '<defs><linearGradient id="s" x1="0" x2="1">'
        '<stop offset="0" stop-color="$a"/><stop offset="0.2" stop-color="$a"/><stop offset="0.2" stop-color="#ffffff"/><stop offset="0.4" stop-color="#ffffff"/>'
        '<stop offset="0.4" stop-color="$a"/><stop offset="0.6" stop-color="$a"/><stop offset="0.6" stop-color="#ffffff"/><stop offset="0.8" stop-color="#ffffff"/>'
        '<stop offset="0.8" stop-color="$a"/><stop offset="1" stop-color="$a"/></linearGradient>'
        '<radialGradient id="l" cx="0.4" cy="0.2" r="0.9"><stop offset="0" stop-color="#fff" stop-opacity="0.45"/><stop offset="1" stop-color="#000" stop-opacity="0.18"/></radialGradient></defs>'
        '<path d="M2 26 Q40 -12 78 26 Q70 22 60 26 Q50 21 40 26 Q30 21 20 26 Q10 22 2 26 Z" fill="url(#s)" stroke="rgba(15,23,42,0.35)" stroke-width="1"/>'
        '<path d="M2 26 Q40 -12 78 26 Q70 22 60 26 Q50 21 40 26 Q30 21 20 26 Q10 22 2 26 Z" fill="url(#l)"/>'
        '<path d="M4 26 L30 60 M20 26 L35 60 M40 26 L40 60 M60 26 L45 60 M76 26 L50 60" stroke="rgba(71,85,105,0.8)" stroke-width="0.8"/>';
    final chute = FxSprite(
      x: s.cx - cw / 2 + shift,
      y: s.cy - ch - s.h * 0.35,
      w: cw,
      h: ch,
      origin: [cw / 2 - shift, ch + s.h * 0.35],
      tracks: [_play(sway, duration: D, easing: 'cubic-bezier(0.3, 0.2, 0.4, 1)', fill: 'forwards')],
      children: [
        FxSprite(
          x: 0,
          y: 0,
          w: cw,
          h: ch,
          origin: [cw / 2, ch],
          svg: '<svg xmlns="http://www.w3.org/2000/svg" width="${_n(cw)}" height="${_n(ch)}" viewBox="0 0 80 60" preserveAspectRatio="none">$canopy</svg>',
          tracks: [
            _play([
              {'scale': '1 1', 'opacity': 1, 'translate': '0 0'},
              {'scale': '0.8 0.35', 'opacity': 1, 'translate': _tr(s.inward * s.unit * 0.4, ch * 0.45), 'offset': 0.45},
              {'scale': '0.4 0.2', 'opacity': 0, 'translate': _tr(s.inward * s.unit * 1.2, ch * 0.6)},
            ], duration: 800, delay: D + 80, fill: 'forwards'),
          ],
        ),
      ],
    );
    final sprites = [
      chute,
      _puff(s, s.cx - s.w * 0.3, s.h - 3, s.unit * 0.4, D - 40, -s.unit * 0.4, -3, 600),
      _puff(s, s.cx + s.w * 0.3, s.h - 3, s.unit * 0.4, D - 40, s.unit * 0.4, -3, 600),
    ];
    return EntrancePlan(
      revealAt: 0,
      arrive: _play([
        for (var i = 0; i < sway.length; i++)
          () {
            final k = {...sway[i], 'opacity': 1, 'offset': i == 0 ? 0 : sway[i]['offset']};
            final o = k['offset'] as num?;
            return {...k, 'offset': o == null ? null : o * (D / (D + 260))};
          }(),
      ], duration: D + 260, easing: 'cubic-bezier(0.3, 0.2, 0.4, 1)'),
      total: D + 950,
      sprites: sprites,
    );
  },

  // A paper plane loops the loop across the screen and glides in; at the
  // corner it unfolds into the button.
  'plane': (s, _) {
    final pw = s.unit * 0.95;
    final ph = pw * 0.55;
    final L = math.min(s.winW * 0.55, 520.0) * s.inward;
    final top = -math.min(s.top * 0.6, 260.0);
    final R = s.unit * 1.1;
    final d = 'M ${_n(L * 1.1)},${_n(top)} C ${_n(L * 0.6)},${_n(top + 40)} ${_n(L * 0.35)},${_n(top - 30)} ${_n(L * 0.25)},${_n(top + 20)} '
        'a ${_n(R)},${_n(R)} 0 1,${s.inward == -1 ? 1 : 0} ${_n(s.inward * 0.01)},0 '
        'C ${_n(L * 0.12)},${_n(top + 60)} ${_n(s.inward * s.unit * 0.8)},${_n(s.cy - 30)} ${_n(s.cx - s.w / 2 + s.w / 2)},${_n(s.cy)}';
    const D = 1700;
    const ease = 'cubic-bezier(0.35, 0.1, 0.4, 1)';
    final sprites = <FxSprite>[
      FxSprite(
        x: -pw / 2,
        y: -ph / 2,
        w: pw,
        h: ph,
        path: d,
        svg: _svgOf(pw, ph, '0 0 40 22',
            '<defs><linearGradient id="p" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#cbd5e1"/></linearGradient></defs>'
            '<path d="M40 11 L0 0 L10 11 Z" fill="url(#p)" stroke="#94a3b8" stroke-width="0.8" stroke-linejoin="round"/><path d="M40 11 L10 11 L0 22 Z" fill="#e2e8f0" stroke="#94a3b8" stroke-width="0.8" stroke-linejoin="round"/>'
            '<path d="M40 11 L10 11 L14 15 Z" fill="#94a3b8"/><path d="M40 11 L10 11" stroke="${s.accent}" stroke-width="1.2"/>'),
        tracks: [
          _play([
            {'offsetDistance': '0%', 'opacity': 1},
            {'offsetDistance': '100%', 'opacity': 1, 'offset': 0.96},
            {'offsetDistance': '100%', 'opacity': 0},
          ], duration: D, easing: ease, fill: 'forwards'),
        ],
      ),
    ];
    for (var i = 0; i < 6; i++) {
      sprites.add(FxSprite(
        x: -2,
        y: -2,
        w: 4,
        h: 4,
        fill: 'rgba(148, 163, 184, 0.7)',
        radius: 2,
        path: d,
        base: {'o': 0},
        tracks: [
          _play([
            {'offsetDistance': '0%', 'opacity': 0},
            {'offsetDistance': '80%', 'opacity': 0.6, 'offset': 0.7},
            {'offsetDistance': '96%', 'opacity': 0},
          ], duration: D, delay: 80 + i * 70, easing: ease, fill: 'forwards'),
        ],
      ));
    }
    sprites.add(FxSprite(
      x: 0,
      y: 0,
      w: s.w,
      h: s.h,
      svg: linearBox(s.w, s.h, 135, stops(['#ffffff', '#e2e8f0']), math.min(s.w, s.h) / 2),
      base: {'o': 0},
      tracks: [
        _play([
          {'opacity': 0, 'scale': '0.2 0.2', 'rotate': '-40deg'},
          {'opacity': 1, 'scale': '1 1', 'rotate': '0deg', 'offset': 0.55},
          {'opacity': 0, 'scale': '1 1', 'rotate': '0deg'},
        ], duration: 520, delay: D - 80, easing: 'ease-out', fill: 'forwards'),
      ],
    ));
    return EntrancePlan(
      revealAt: D + 150,
      arrive: _play([
        {'opacity': 0, 'scale': '1 0.1', 'rotate': 'x 80deg'},
        {'opacity': 1, 'scale': '1 1.08', 'rotate': 'x 0deg', 'offset': 0.6},
        {'opacity': 1, 'scale': '1 1', 'rotate': 'x 0deg'},
      ], duration: 480, easing: 'cubic-bezier(0.22, 1, 0.36, 1)'),
      total: D + 700,
      sprites: sprites,
    );
  },

  // An egg lands in the corner, wobbles, cracks, the top pops off; the button
  // hatches with a happy bounce.
  'egg': (s, _) {
    final ew = s.unit * 0.95;
    final eh = s.unit * 1.2;
    final left = s.cx - ew / 2;
    final top = s.h - eh;
    String shell(String part) => _svgOf(ew, eh, '0 0 40 50',
        '<defs><radialGradient id="g" cx="0.38" cy="0.3" r="0.85"><stop offset="0" stop-color="#fffdf5"/><stop offset="0.6" stop-color="#fdf2d8"/><stop offset="1" stop-color="#d6b98c"/></radialGradient>'
        '<clipPath id="c"><path d="${part == 'top' ? 'M-5 -5 H45 V24 L36 20 L29 27 L21 20 L13 27 L6 21 L-5 25 Z' : 'M-5 25 L6 21 L13 27 L21 20 L29 27 L36 20 L45 24 V60 H-5 Z'}"/></clipPath></defs>'
        '<g clip-path="url(#c)"><path d="M20 1 C33 1 39 20 39 31 C39 43 30 49 20 49 C10 49 1 43 1 31 C1 20 7 1 20 1 Z" fill="url(#g)" stroke="#c9a57a" stroke-width="1"/>'
        '<circle cx="13" cy="16" r="1.6" fill="#d6b98c" opacity="0.7"/><circle cx="27" cy="12" r="1.2" fill="#d6b98c" opacity="0.7"/>'
        '<circle cx="29" cy="36" r="1.6" fill="#d6b98c" opacity="0.6"/><circle cx="11" cy="38" r="1.2" fill="#d6b98c" opacity="0.6"/>'
        '<ellipse cx="14" cy="12" rx="4" ry="6" fill="#fff" opacity="0.7"/></g>');
    final land = _play([
      {'translate': '0 -${_px(s.above + eh)}', 'rotate': '0deg', 'scale': '1 1', 'easing': 'cubic-bezier(0.55, 0, 1, 0.45)'},
      {'translate': '0 0', 'scale': '1.12 0.9', 'offset': 0.22, 'easing': 'ease-out'},
      {'translate': '0 0', 'scale': '1 1', 'rotate': '0deg', 'offset': 0.3},
      {'rotate': '-12deg', 'offset': 0.38},
      {'rotate': '10deg', 'offset': 0.46},
      {'rotate': '-8deg', 'offset': 0.54},
      {'rotate': '6deg', 'offset': 0.6},
      {'rotate': '0deg', 'offset': 0.66},
      {'translate': '0 0', 'rotate': '0deg', 'scale': '1 1'},
    ], duration: 1600, fill: 'forwards');
    const hatch = 1600;
    final k = ew / 40;
    final bottom = FxSprite(
      x: left,
      y: top,
      w: ew,
      h: eh,
      origin: [ew / 2, eh],
      tracks: [land],
      children: [
        FxSprite(x: 0, y: 0, w: ew, h: eh, svg: shell('bottom'), tracks: [
          _play([
            {'opacity': 1, 'scale': 1},
            {'opacity': 0, 'scale': 0.7, 'translate': '0 ${_px(s.unit * 0.3)}'},
          ], duration: 500, delay: hatch + 250, fill: 'forwards'),
        ]),
      ],
    );
    final topHalf = FxSprite(
      x: left,
      y: top,
      w: ew,
      h: eh,
      origin: [ew / 2, eh],
      tracks: [land],
      children: [
        FxSprite(
          x: 0,
          y: 0,
          w: ew,
          h: eh,
          svg: shell('top'),
          tracks: [
            _play([
              {'translate': '0 0', 'rotate': '0deg', 'opacity': 1},
              {'translate': '${_px(-s.inward * s.unit * 0.8)} -${_px(s.unit * 1.2)}', 'rotate': _deg(-s.inward * 160), 'opacity': 1, 'offset': 0.55},
              {'translate': _tr(-s.inward * s.unit * 1.2, s.unit * 0.4), 'rotate': _deg(-s.inward * 260), 'opacity': 0},
            ], duration: 800, delay: hatch, easing: 'cubic-bezier(0.2, 0.8, 0.4, 1)', fill: 'forwards'),
          ],
          children: [
            // The crack racing across the shell, as a wipe from the left.
            FxSprite(
              x: 2 * k,
              y: 19 * k,
              w: 37 * k,
              h: 9 * k,
              svg: _svgOf(37 * k, 9 * k, '2 19 37 9', '<path d="M3 24 L6 21 L13 27 L21 20 L29 27 L36 20 L38 22" fill="none" stroke="#7c5a33" stroke-width="1.4" stroke-linejoin="round"/>'),
              wipe: 'right',
              base: {'dash': 100},
              tracks: [
                _play([
                  {'strokeDashoffset': 100},
                  {'strokeDashoffset': 100, 'offset': 0.4},
                  {'strokeDashoffset': 0},
                ], duration: 1400, fill: 'forwards'),
              ],
            ),
          ],
        ),
      ],
    );
    return EntrancePlan(
      revealAt: hatch + 60,
      arrive: _play([
        {'opacity': 0, 'scale': 0.2, 'translate': '0 ${_px(s.unit * 0.25)}'},
        {'opacity': 1, 'scale': 1.25, 'translate': '0 -${_px(s.unit * 0.35)}', 'offset': 0.4, 'easing': 'ease-in'},
        {'scale': '1.12 0.88', 'translate': '0 0', 'offset': 0.62, 'easing': 'ease-out'},
        {'scale': '0.97 1.03', 'translate': '0 -3px', 'offset': 0.8},
        {'opacity': 1, 'scale': 1, 'translate': '0 0'},
      ], duration: 820),
      total: hatch + 1000,
      sprites: [
        bottom,
        topHalf,
        ..._debris(s, 6, hatch + 30, ['#fdf2d8', '#f5e6c8', '#e7d3b0'], 5, 0.8),
        ..._sparkles(s, 5, hatch + 120, '#fde047', 0.9),
      ],
    );
  },
};

/// The entrance for a mode on this stage (null for "classic"). `seed` picks the lightning's shape.
EntrancePlan? entrancePlan(String mode, EntranceStage s, [int? seed]) {
  final fx = _effects[mode];
  if (fx == null) return null;
  return fx(s, seeded(seed ?? math.Random().nextInt(100000) + 7));
}

/// A sprite's drawn values at t ms: its translate (px, the box's own share
/// and an animated `left` folded in, and a motion path's point), rotate, the
/// scale (a 3D turn about x / y, unlit and without perspective as on the
/// web, is the cosine of its angle), opacity and how much of a wipe shows.
class SpriteFrame {
  final double tx, ty, r, sx, sy, o, reveal;
  const SpriteFrame(this.tx, this.ty, this.r, this.sx, this.sy, this.o, this.reveal);
}

final Map<String, List<(double, double)>> _pathCache = {};

SpriteFrame spriteFrame(FxSprite sp, double t, [FxValues? values]) {
  final f = values ?? evaluate(sp.tracks, t, sp.base);
  var tx = f.tx + (f.txp / 100) * sp.w + (sp.leftOf != null ? (f.left / 100) * sp.leftOf! : 0);
  var ty = f.ty + (f.typ / 100) * sp.h;
  var r = f.r;
  final path = sp.path;
  if (path != null) {
    final pts = _pathCache.putIfAbsent(path, () => flattenPath(path));
    final at = pointAlong(pts, f.od / 100);
    // Chrome measures the path from the box's own top-left and puts its centre on it.
    tx += at.x - sp.w / 2;
    ty += at.y - sp.h / 2;
    r += at.angle;
  }
  return SpriteFrame(
    tx,
    ty,
    r,
    f.sx * math.cos((f.ry * math.pi) / 180),
    f.sy * math.cos((f.rx * math.pi) / 180),
    f.o,
    sp.wipe != null ? 1 - f.dash / 100 : 1,
  );
}
