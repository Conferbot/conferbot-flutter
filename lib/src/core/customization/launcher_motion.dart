/// The launcher's motion as the web widget plays it (conferbot-widget
/// src/svg/launcher/motion.ts and ts/launcher/launcherMotion.ts):
///
///   - which parts of an icon move, and how, at a moment of an "idle" or
///     "msg" (new message) moment: [LauncherMotion.iconFrame] evaluates the CSS
///     keyframes, easing, delays, iterations and fill modes at time t;
///   - when the moments play: [LauncherMotion.nextIdleDelay];
///   - the ripple: [LauncherMotion.rippleRing].
///
/// Pure: the launcher drives the clock. The same algorithm as the React
/// Native SDK's core/launcherMotion.ts, which is checked frame by frame
/// against Chrome's own animation of the web icons.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'launcher_icons.dart';
import 'launcher_motion_data.dart';

class MotionRing {
  final double scale;
  final double opacity;
  const MotionRing(this.scale, this.opacity);
}

/// One op mid-moment: the transform to draw it with, its clip's, and its
/// animated layers (group id, opacity), outer first.
class OpFrame {
  final List<double> m;
  final List<double>? clipM;
  final List<(int, double)> layers;
  const OpFrame(this.m, this.clipM, this.layers);
}

class _Frame {
  final double at;
  final Object? tx, ty;
  final double? sx, sy, r, o;
  const _Frame(this.at, {this.tx, this.ty, this.sx, this.sy, this.r, this.o});
  bool get hasTransform => tx != null || ty != null || sx != null || sy != null || r != null;
  bool get usesVars => tx is String || ty is String;
}

class _Rule {
  final String part, kf, fill;
  final double dur, delay;
  final int iter;
  final List<double> ease;
  const _Rule(this.part, this.kf, this.dur, this.delay, this.iter, this.ease, this.fill);
  _Rule withDelay(double d) => _Rule(part, kf, dur, d, iter, ease, fill);
}

class _Family {
  final List<_Rule> idle, msg;
  final Map<String, double>? awakeOpacity;
  const _Family(this.idle, this.msg, this.awakeOpacity);
}

class LauncherMotion {
  LauncherMotion._();

  /// How long a moment lasts (the longest keyframes are 2.4s).
  static const momentMs = 2600;

  /// The first idle moment, after the launcher shows.
  static const firstIdleMs = 2000;

  /// An opening rests the idle moments this long.
  static const openedRestMs = 30 * 60 * 1000;

  /// Milliseconds until the next idle moment after [played] of them, or null when there are no more.
  static int? nextIdleDelay(String mode, int played, [double Function()? random]) {
    if (mode == 'off') return null;
    final lively = mode == 'lively';
    final every = lively ? 20000 : 30000, jitter = lively ? 8000 : 0, plays = lively ? 10 : 4;
    if (played <= 0) return firstIdleMs;
    if (played >= plays) return null;
    return every + ((random ?? math.Random().nextDouble)() * jitter).round();
  }

  // The ripple (polish.css cb-ripple): two rings, the second 0.6s behind, each 1.8s, three times after 2.5s.
  static const rippleDelay = 2.5, rippleGap = 0.6, rippleDur = 1.8;
  static const rippleIter = 3;

  /// A ring's scale and opacity at t seconds into the ripple (null when it is not showing).
  static MotionRing? rippleRing(double t, int ring, {int iterations = rippleIter, double delay = rippleDelay}) {
    final lt = t - delay - ring * rippleGap;
    if (lt < 0 || lt >= rippleDur * iterations) return null;
    final p = cubicBezier(const [0, 0, 0.2, 1], (lt % rippleDur) / rippleDur);
    return MotionRing(1 + 0.7 * p, 0.45 * (1 - p));
  }

  /// CSS cubic-bezier timing: the y for a given x (Newton, then bisection).
  static double cubicBezier(List<double> e, double x) {
    final x1 = e[0], y1 = e[1], x2 = e[2], y2 = e[3];
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    double bx(double t) => 3 * x1 * t * (1 - t) * (1 - t) + 3 * x2 * t * t * (1 - t) + t * t * t;
    double by(double t) => 3 * y1 * t * (1 - t) * (1 - t) + 3 * y2 * t * t * (1 - t) + t * t * t;
    var t = x;
    for (var i = 0; i < 8; i++) {
      final d = (bx(t + 1e-6) - bx(t)) / 1e-6;
      if (d.abs() < 1e-6) break;
      t -= (bx(t) - x) / d;
    }
    if (t < 0 || t > 1 || (bx(t) - x).abs() > 1e-4) {
      var lo = 0.0, hi = 1.0;
      for (var i = 0; i < 40; i++) {
        t = (lo + hi) / 2;
        if (bx(t) < x) {
          lo = t;
        } else {
          hi = t;
        }
      }
    }
    return by(t);
  }

  // ---- data ----

  static final Map<String, dynamic> _raw = jsonDecode(launcherMotionJson) as Map<String, dynamic>;

  static final Map<String, List<_Frame>> _keyframes = (_raw['keyframes'] as Map<String, dynamic>).map((k, v) => MapEntry(
        k,
        (v as List).map((f) {
          final j = f as Map<String, dynamic>;
          double? n(String key) => (j[key] as num?)?.toDouble();
          Object? tv(String key) => j[key] is num ? (j[key] as num).toDouble() : j[key];
          return _Frame((j['at'] as num).toDouble(), tx: tv('tx'), ty: tv('ty'), sx: n('sx'), sy: n('sy'), r: n('r'), o: n('o'));
        }).toList(),
      ));

  static List<_Rule> _rules(dynamic v) => ((v as List?) ?? const []).map((r) {
        final j = r as Map<String, dynamic>;
        return _Rule(j['part'] as String, j['kf'] as String, (j['dur'] as num).toDouble(), (j['delay'] as num).toDouble(), j['iter'] as int,
            (j['ease'] as List).map((x) => (x as num).toDouble()).toList(), j['fill'] as String);
      }).toList();

  static final Map<String, _Family> _families = (_raw['families'] as Map<String, dynamic>).map((k, v) {
    final j = v as Map<String, dynamic>;
    final awake = (j['awakeOpacity'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble()));
    return MapEntry(k, _Family(_rules(j['idle']), _rules(j['msg']), awake));
  });

  static final Map<String, List<double>> _origins =
      (_raw['origins'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as List).map((x) => (x as num).toDouble()).toList()));

  static final Map<String, double> _delays = (_raw['delays'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()));

  // ---- evaluation ----

  /// 2x3 affine matrices [a, b, c, d, e, f].
  static const _identity = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];

  static List<double> mul(List<double> a, List<double> b) => [
        a[0] * b[0] + a[2] * b[1],
        a[1] * b[0] + a[3] * b[1],
        a[0] * b[2] + a[2] * b[3],
        a[1] * b[2] + a[3] * b[3],
        a[0] * b[4] + a[2] * b[5] + a[4],
        a[1] * b[4] + a[3] * b[5] + a[5],
      ];

  static const _base = {'tx': 0.0, 'ty': 0.0, 'sx': 1.0, 'sy': 1.0, 'r': 0.0, 'o': 1.0};

  static double? _read(_Frame f, String prop, double? dx, double? dy) {
    final Object? v = switch (prop) { 'tx' => f.tx, 'ty' => f.ty, 'sx' => f.sx, 'sy' => f.sy, 'r' => f.r, _ => f.o };
    if (v == null) return null;
    if (v == 'dx') return dx ?? 0;
    if (v == 'dy') return dy ?? 0;
    return v is double ? v : null;
  }

  /// A property at progress p of one iteration: interpolated between the frames that set it, eased per segment.
  static double _valueAt(List<_Frame> frames, String prop, double p, List<double> ease, double? dx, double? dy) {
    final base = _base[prop]!;
    final pts = <(double, double)>[];
    for (final f in frames) {
      final v = _read(f, prop, dx, dy);
      if (v != null) pts.add((f.at, v));
    }
    if (pts.isEmpty) return base;
    if (pts.first.$1 > 0) pts.insert(0, (0, base));
    if (pts.last.$1 < 1) pts.add((1, base));
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      if (p >= a.$1 && p <= b.$1) {
        final span = b.$1 - a.$1;
        final local = span > 0 ? cubicBezier(ease, (p - a.$1) / span) : 1.0;
        return a.$2 + (b.$2 - a.$2) * local;
      }
    }
    return pts.last.$2;
  }

  static double? _progress(_Rule rule, double t) {
    final lt = t - rule.delay;
    final back = rule.fill == 'backwards' || rule.fill == 'both';
    final fwd = rule.fill == 'forwards' || rule.fill == 'both';
    if (lt < 0) return back ? 0 : null;
    if (rule.iter != -1 && lt >= rule.dur * rule.iter) return fwd ? 1 : null;
    if (rule.dur <= 0) return null;
    return (lt % rule.dur) / rule.dur;
  }

  /// Each op of [icon] at t seconds into a [state] ("idle" or "msg") moment, or null for "at rest".
  static List<OpFrame?> iconFrame(LauncherIcon icon, String state, double t) {
    final fam = _families[icon.anim];
    if (fam == null) return List.filled(icon.ops.length, null);
    final rules = state == 'msg' ? fam.msg : fam.idle;
    final awakeOpacity = state == 'msg' ? fam.awakeOpacity : null;
    final cache = <int, (List<double>?, double?)?>{};

    (List<double>?, double?)? partFrame(List<String> classes, int gid, double? dx, double? dy, bool unclassed) {
      if (cache.containsKey(gid)) return cache[gid];
      List<double>? m;
      double? o;
      // The cascade gives an element one animation: the last rule that matches it.
      _Rule? rule;
      for (final r in rules) {
        if (classes.contains(r.part)) rule = r;
      }
      if (rule != null) {
        // A delay set on one of the element's own classes wins.
        for (final c in classes) {
          final d = _delays['${icon.anim} $c'] ?? _delays['* $c'];
          if (d != null) rule = rule!.withDelay(d);
        }
      }
      final p = rule == null ? null : _progress(rule, t);
      if (rule != null && p != null) {
        // A frame using --dx / --dy on an element without them is "none".
        final frames = _keyframes[rule.kf]!
            .map((f) => f.usesVars && (dx == null || dy == null) ? _Frame(f.at, tx: 0.0, ty: 0.0, sx: 1, sy: 1, r: 0, o: f.o) : f)
            .toList();
        final r = rule;
        double v(String k) => _valueAt(frames, k, p, r.ease, dx, dy);
        if (frames.any((f) => f.hasTransform)) {
          final box = unclassed ? const [0.0, 0.0, 0.0, 0.0] : (icon.boxes[gid] ?? const [0.0, 0.0, 24.0, 24.0]);
          final origin = _origins['${icon.anim} ${r.part}'] ?? const [0.5, 0.5];
          final ox = box[0] + box[2] * origin[0];
          final oy = box[1] + box[3] * origin[1];
          final rad = v('r') * math.pi / 180;
          // translate(origin) translate(tx, ty) rotate(r) scale(sx, sy) translate(-origin)
          var n = [1.0, 0.0, 0.0, 1.0, ox + v('tx'), oy + v('ty')];
          n = mul(n, [math.cos(rad), math.sin(rad), -math.sin(rad), math.cos(rad), 0, 0]);
          n = mul(n, [v('sx'), 0, 0, v('sy'), 0, 0]);
          n = mul(n, [1, 0, 0, 1, -ox, -oy]);
          m = n;
        }
        // CSS clamps opacity (an overshooting easing goes past 1).
        if (frames.any((f) => f.o != null)) o = v('o').clamp(0, 1).toDouble();
      }
      if (o == null && awakeOpacity != null) {
        for (final c in classes) {
          if (awakeOpacity[c] != null) o = awakeOpacity[c];
        }
      }
      final out = m != null || o != null ? (m, o) : null;
      cache[gid] = out;
      return out;
    }

    return icon.ops.map((op) {
      final chain = [const IconPart(c: ['cbl-r'], g: 0), ...op.parts];
      var m = _identity;
      List<double>? clipM;
      final layers = <(int, double)>[];
      var moved = false;
      for (var i = 0; i < chain.length; i++) {
        final part = chain[i];
        // The clip moves with the root and the parts down to the element that declared it.
        if (op.clip != null && i == op.clipDepth + 1) clipM = m;
        if (part.pre != null) m = mul(m, part.pre!);
        final f = partFrame(part.c, part.g, part.dx, part.dy, part.unclassed);
        if (f != null) moved = true;
        // A CSS transform replaces the element's own transform attribute while it runs.
        m = mul(m, f?.$1 ?? part.t ?? _identity);
        if (f?.$2 != null) layers.add((part.g, f!.$2!));
      }
      if (!moved) return null;
      if (op.clip != null && clipM == null) clipM = m;
      if (op.post != null) m = mul(m, op.post!);
      return OpFrame(m, op.clip != null ? clipM : null, layers);
    }).toList();
  }
}
