/// Web Animations, evaluated: the launcher's entrance, attention and idle
/// call (conferbot-widget src/ts/launcher/entrance.ts, attention.ts,
/// idleCall.ts) are element.animate() calls on the individual translate /
/// scale / rotate properties and opacity. Their keyframes are kept here as the
/// web wrote them, and this works out each property at time t the way the
/// browser does:
///
///   - offsets: a keyframe without one is spaced evenly between its
///     neighbours (the first defaults to 0, the last to 1);
///   - per property, only the keyframes that set it count; a missing 0% or
///     100% keyframe is the element's own value (the step from a missing 0%
///     eases with the 0% keyframe's easing, as Chrome plays it);
///   - each keyframe's `easing` eases the step that starts at it; the
///     options' easing eases the whole iteration first;
///   - delay, iterations (infinity loops) and fill (forwards / backwards /
///     both; none: the element's own value outside the animation);
///   - several animations on one element: the later one wins for the
///     properties it sets.
///
/// The same algorithm as the React Native SDK's core/keyframes.ts, which is
/// checked against Chrome's own animations frame by frame
/// (scripts/parity/launcherfx); test/fixtures/launcherfx_golden.json is that
/// golden. Pure.
library;

import 'dart:math' as math;

import 'launcher_motion.dart';

/// One keyframe, as the web passes it to element.animate(): `offset`, `easing`
/// and the properties (strings or numbers).
typedef Keyframe = Map<String, Object?>;

class TrackOptions {
  final double duration;
  final double delay;

  /// `double.infinity` loops forever.
  final double iterations;
  final String? easing;

  /// none, forwards, backwards, both, auto.
  final String fill;

  const TrackOptions({required this.duration, this.delay = 0, this.iterations = 1, this.easing, this.fill = 'none'});

  TrackOptions copyWith({double? delay}) => TrackOptions(duration: duration, delay: delay ?? this.delay, iterations: iterations, easing: easing, fill: fill);

  /// Every option, defaults filled in, infinity as -1 (the golden's form, normalised).
  Map<String, Object?> toJson() => {
        'duration': duration,
        'delay': delay,
        'iterations': iterations == double.infinity ? -1 : iterations,
        'easing': easing ?? 'linear',
        'fill': fill,
      };
}

/// One animation: its keyframes and options. `part` names what it moves (attention).
class Track {
  final List<Keyframe> keyframes;
  final TrackOptions options;
  final String? part;

  Track(this.keyframes, this.options, {this.part});

  /// A track built as the web writes `{ duration, delay?, iterations?, easing?, fill? }`.
  factory Track.of(List<Keyframe> keyframes, {required num duration, num? delay, num? iterations, String? easing, String? fill, String? part}) => Track(
        keyframes,
        TrackOptions(
          duration: duration.toDouble(),
          delay: (delay ?? 0).toDouble(),
          iterations: (iterations ?? 1).toDouble(),
          easing: easing,
          fill: fill ?? 'none',
        ),
        part: part,
      );

  /// The same track, its delay changed (or pushed later).
  Track withDelay(double delay) => Track(keyframes, options.copyWith(delay: delay), part: part);

  /// From the golden's JSON (iterations -1 = infinity).
  factory Track.fromJson(Map<String, dynamic> j) {
    final o = j['options'] as Map<String, dynamic>;
    final it = o['iterations'] as num?;
    return Track(
      (j['keyframes'] as List).map((k) => Map<String, Object?>.from(k as Map)).toList(),
      TrackOptions(
        duration: (o['duration'] as num).toDouble(),
        delay: ((o['delay'] as num?) ?? 0).toDouble(),
        iterations: it == null ? 1 : (it == -1 ? double.infinity : it.toDouble()),
        easing: o['easing'] as String?,
        fill: (o['fill'] as String?) ?? 'none',
      ),
      part: j['part'] as String?,
    );
  }

  /// As the golden stores it.
  Map<String, Object?> toJson() => {
        if (part != null) 'part': part,
        'keyframes': keyframes.map((k) => {for (final e in k.entries) if (e.value != null) e.key: e.value}).toList(),
        'options': options.toJson(),
      };

  late final _Compiled _compiled = _compile(this);
}

/// The animated channels: translate in px (tx, ty) plus a share of the
/// element's own box (txp, typ, in %), scale, rotate about z (r) and the 3D
/// turns (rx, ry) in degrees, opacity, offset-distance (od, %),
/// stroke-dashoffset (dash), clip-path inset from the bottom (clip, %) and
/// `left` (%).
const fxChannels = ['tx', 'ty', 'txp', 'typ', 'sx', 'sy', 'r', 'rx', 'ry', 'o', 'od', 'dash', 'clip', 'left'];
const _rest = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0];
final Map<String, int> _index = {for (var i = 0; i < fxChannels.length; i++) fxChannels[i]: i};

/// An element's values at a moment.
class FxValues {
  final List<double> v;
  FxValues._(this.v);

  /// At rest, with `base` (the element's own values) over it.
  factory FxValues.rest([Map<String, double>? base]) {
    final v = List<double>.of(_rest);
    base?.forEach((k, x) => v[_index[k]!] = x);
    return FxValues._(v);
  }

  FxValues copy() => FxValues._(List<double>.of(v));
  double operator [](String ch) => v[_index[ch]!];
  void operator []=(String ch, double x) => v[_index[ch]!] = x;

  double get tx => v[0];
  double get ty => v[1];
  double get txp => v[2];
  double get typ => v[3];
  double get sx => v[4];
  double get sy => v[5];
  double get r => v[6];
  double get rx => v[7];
  double get ry => v[8];
  double get o => v[9];
  double get od => v[10];
  double get dash => v[11];
  double get clip => v[12];
  double get left => v[13];

  /// Only the channels away from rest (as the golden stores a sample).
  Map<String, double> get moved => {
        for (var i = 0; i < v.length; i++)
          if ((v[i] - _rest[i]).abs() > 1e-9) fxChannels[i]: v[i],
      };
}

const Map<String, List<double>> _ease = {
  'linear': [0, 0, 1, 1],
  'ease': [0.25, 0.1, 0.25, 1],
  'ease-in': [0.42, 0, 1, 1],
  'ease-out': [0, 0, 0.58, 1],
  'ease-in-out': [0.42, 0, 0.58, 1],
};

/// A CSS easing as cubic-bezier control points (unknown: linear).
List<double> easingOf(String? e) {
  if (e == null) return _ease['linear']!;
  final s = e.trim();
  final named = _ease[s];
  if (named != null) return named;
  final m = RegExp(r'^cubic-bezier\(([^)]*)\)$').firstMatch(s);
  if (m != null) {
    final n = m.group(1)!.split(',').map((x) => jsParseFloat(x)).toList();
    if (n.length == 4 && n.every((x) => x.isFinite)) return n;
  }
  return _ease['linear']!;
}

bool _isLinear(List<double> e) => e[0] == 0 && e[1] == 0 && e[2] == 1 && e[3] == 1;
double _apply(List<double> e, double x) => _isLinear(e) ? x : LauncherMotion.cubicBezier(e, x);

/// JavaScript's parseFloat: the leading number of a string (NaN when none).
double jsParseFloat(Object? v) {
  if (v is num) return v.toDouble();
  final m = RegExp(r'^\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)').firstMatch('$v');
  return m == null ? double.nan : double.parse(m.group(1)!);
}

/// A number as JavaScript prints it (`${n}`): 1 not 1.0, -0 as 0.
String jsNum(num n) {
  if (n is int) return '$n';
  final d = n.toDouble();
  if (d == 0) return '0';
  if (d.isFinite && d == d.truncateToDouble() && d.abs() < 1e21) return d.toInt().toString();
  return d.toString();
}

const _groups = ['translate', 'scale', 'rotate', 'opacity', 'offsetDistance', 'strokeDashoffset', 'clipPath', 'left', 'transform'];
const Map<String, List<String>> _channelsOf = {
  'translate': ['tx', 'ty', 'txp', 'typ'],
  'scale': ['sx', 'sy'],
  'rotate': ['r', 'rx', 'ry'],
  'opacity': ['o'],
  'offsetDistance': ['od'],
  'strokeDashoffset': ['dash'],
  'clipPath': ['clip'],
  'left': ['left'],
  // Only "scaleY(n)" is used (the eyelids): it is the scale's y.
  'transform': ['sy'],
};

/// "12px", "-160%", "0", "calc(10% + 4px)": [px, %].
List<double> _length(String v) {
  final s = v.trim();
  if (s.startsWith('calc(')) {
    var px = 0.0, pc = 0.0;
    for (final m in RegExp(r'([+-]?)\s*([\d.]+)(px|%)').allMatches(s.substring(5, s.length - 1))) {
      final x = (m.group(1) == '-' ? -1 : 1) * double.parse(m.group(2)!);
      if (m.group(3) == '%') {
        pc += x;
      } else {
        px += x;
      }
    }
    return [px, pc];
  }
  final n = jsParseFloat(s);
  if (!n.isFinite) return [0, 0];
  return s.endsWith('%') ? [0, n] : [n, 0];
}

String _str(Object v) => v is num ? jsNum(v) : '$v';

/// One keyframe's value for a group, or null when it does not set it.
Map<String, double>? _parse(Keyframe k, String g) {
  final v = k[g];
  if (v == null) return null;
  final s = _str(v).trim();
  switch (g) {
    case 'translate':
      // Split on spaces outside calc().
      final parts = s.split(RegExp(r'\s+(?![^(]*\))'));
      final x = _length(parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : '0');
      final y = _length(parts.length > 1 ? parts[1] : '0');
      return {'tx': x[0], 'txp': x[1], 'ty': y[0], 'typ': y[1]};
    case 'scale':
      final parts = s.split(RegExp(r'\s+')).map(jsParseFloat).toList();
      return {'sx': parts[0], 'sy': parts.length > 1 ? parts[1] : parts[0]};
    case 'rotate':
      // "45deg", "y 180deg", "x 80deg".
      final m = RegExp(r'^(?:([xyz])\s+)?(-?[\d.]+)deg$').firstMatch(s);
      double a;
      if (m != null) {
        a = double.parse(m.group(2)!);
      } else {
        final f = jsParseFloat(s);
        a = f.isNaN ? 0 : f;
      }
      final axis = m?.group(1) ?? 'z';
      return {'r': axis == 'z' ? a : 0, 'rx': axis == 'x' ? a : 0, 'ry': axis == 'y' ? a : 0};
    case 'opacity':
      return {'o': v is num ? v.toDouble() : jsParseFloat(s)};
    case 'offsetDistance':
      return {'od': jsParseFloat(s)};
    case 'strokeDashoffset':
      return {'dash': v is num ? v.toDouble() : jsParseFloat(s)};
    case 'clipPath':
      // inset(top right bottom left): the bottom inset, in %.
      final m = RegExp(r'inset\(([^)]*)\)').firstMatch(s);
      final p = m == null ? <String>[] : m.group(1)!.trim().split(RegExp(r'\s+'));
      final b = p.length >= 3 ? jsParseFloat(p[2]) : 0.0;
      return {'clip': b.isNaN ? 0 : b};
    case 'left':
      return {'left': jsParseFloat(s)};
    case 'transform':
      final m = RegExp(r'scaleY\(([^)]*)\)').firstMatch(s);
      return m == null ? null : {'sy': jsParseFloat(m.group(1))};
  }
  return null;
}

/// Offsets as the browser computes them: missing ones spaced evenly between their neighbours.
List<double> computedOffsets(List<Keyframe> kfs) {
  final out = kfs.map((k) => k['offset'] is num ? (k['offset'] as num).toDouble() : null).toList();
  if (out.length == 1 && out[0] == null) out[0] = 1;
  if (out.length > 1) {
    out[0] ??= 0;
    out[out.length - 1] ??= 1;
  }
  var i = 0;
  while (i < out.length) {
    if (out[i] != null) {
      i += 1;
      continue;
    }
    final a = i - 1;
    var b = i;
    while (out[b] == null) {
      b += 1;
    }
    final from = out[a]!, to = out[b]!;
    for (var j = a + 1; j < b; j++) {
      out[j] = from + ((to - from) * (j - a)) / (b - a);
    }
    i = b;
  }
  return out.cast<double>();
}

/// The iteration progress (0..1, eased by the options' easing) at t ms, or null when the animation does not apply.
double? iterationProgress(TrackOptions o, double t) {
  final dur = o.duration;
  final iterations = o.iterations;
  final active = iterations == double.infinity ? double.infinity : dur * iterations;
  final local = t - o.delay;
  double p;
  if (local < 0) {
    if (o.fill != 'backwards' && o.fill != 'both') return null;
    p = 0;
  } else if (local >= active) {
    if (o.fill != 'forwards' && o.fill != 'both') return null;
    // Ended on a whole iteration: its end (1), else where it stopped.
    final whole = iterations - iterations.floorToDouble();
    p = iterations > 0 && whole == 0 ? 1 : whole;
  } else {
    if (dur <= 0) return null;
    p = (local % dur) / dur;
  }
  return _apply(easingOf(o.easing), p);
}

class _Pt {
  final double at;
  final Map<String, double>? v;
  final List<double> e;
  const _Pt(this.at, this.v, this.e);
}

class _Compiled {
  final List<(String, List<_Pt>, List<double>)> groups;
  final List<double> ease;
  const _Compiled(this.groups, this.ease);
}

_Compiled _compile(Track track) {
  final kfs = track.keyframes;
  final offs = computedOffsets(kfs);
  final first = offs.indexWhere((o) => o == 0);
  final firstEase = first >= 0 ? easingOf(kfs[first]['easing'] as String?) : _ease['linear']!;
  final groups = <(String, List<_Pt>, List<double>)>[];
  for (final g in _groups) {
    final pts = <_Pt>[];
    for (var i = 0; i < kfs.length; i++) {
      final v = _parse(kfs[i], g);
      if (v != null) pts.add(_Pt(offs[i], v, easingOf(kfs[i]['easing'] as String?)));
    }
    if (pts.isNotEmpty) groups.add((g, pts, firstEase));
  }
  return _Compiled(groups, easingOf(track.options.easing));
}

/// One track's values at t ms: only the channels it animates, or null when it does not apply.
Map<String, double>? trackValues(Track track, double t, [FxValues? base]) {
  final b = base ?? FxValues.rest();
  final p = iterationProgress(track.options, t);
  if (p == null) return null;
  final c = track._compiled;
  if (c.groups.isEmpty) return null;
  final out = <String, double>{};
  for (final (g, parsed, firstEase) in c.groups) {
    final chs = _channelsOf[g]!;
    // A missing 0% or 100% keyframe is the element's own value (null here); a missing 0% eases with the 0% keyframe's easing.
    final pts = [
      if (parsed.first.at != 0) _Pt(0, null, firstEase),
      ...parsed,
      if (parsed.last.at != 1) _Pt(1, null, _ease['linear']!),
    ];
    // The interval: the last keyframe at or before p (and before 1), and the next.
    var s = -1;
    for (var i = 0; i < pts.length; i++) {
      if (pts[i].at <= p && pts[i].at < 1) s = i;
    }
    if (s < 0) {
      for (var i = 0; i < pts.length; i++) {
        if (pts[i].at == 0) s = i;
      }
    }
    double at(_Pt x, String ch) => x.v?[ch] ?? b[ch];
    if (p >= 1 && pts.where((x) => x.at == 1).length > 1) {
      for (final ch in chs) {
        out[ch] = at(pts.last, ch);
      }
    } else if (s < 0 || s >= pts.length - 1) {
      final x = pts[math.max(0, math.min(pts.length - 1, s))];
      for (final ch in chs) {
        out[ch] = at(x, ch);
      }
    } else {
      final a = pts[s], z = pts[s + 1];
      final span = z.at - a.at;
      final local = span > 0 ? _apply(a.e, (p - a.at) / span) : 1.0;
      for (final ch in chs) {
        final va = at(a, ch), vb = at(z, ch);
        out[ch] = va + (vb - va) * local;
      }
    }
  }
  // The computed opacity is clamped (an overshooting easing goes past 1).
  final o = out['o'];
  if (o != null) out['o'] = o.clamp(0.0, 1.0).toDouble();
  return out;
}

/// An element's values at t ms under its animations, in order (the later wins), over its own `base`.
FxValues evaluate(List<Track> tracks, double t, [Map<String, double>? base]) {
  final b = FxValues.rest(base);
  final out = b.copy();
  for (final tr in tracks) {
    final v = trackValues(tr, t, b);
    if (v != null) v.forEach((k, x) => out[k] = x);
  }
  return out;
}

/// When a set of tracks is over (ms; infinity when one loops forever).
double tracksEnd(List<Track> tracks) =>
    tracks.fold(0.0, (m, tr) => math.max(m, tr.options.delay + tr.options.duration * tr.options.iterations));
