/// Idle call, as the web widget plays it (conferbot-widget
/// src/ts/launcher/idleCall.ts and idlePacing.ts): when the chat has sat
/// unopened a while, the mascot slips out from behind the launcher and calls
/// the visitor over.
///
///   customizations.launcherIdleCall:
///     "off"   (default) nothing;
///     "psst"  it sidles out, cups a hand to its mouth: "Psst!";
///     "peek"  its head rises over the button, looks round, blinks;
///     "wave"  it hops out and waves;
///     "knock" it knocks on the button three times;
///     "tap"   it taps the button twice, which dips.
///   launcherIdleCallDelay: seconds before the call (5-120, default 12);
///   launcherIdleCallText: the speech bubble's line (24 characters; default
///     per style). Tapping the bubble opens the chat.
///
/// The rules (widgets/launcher_fx_controllers.dart keeps them): one call per
/// screen at most; two per app session, 3 minutes apart; a visitor who
/// opened the chat, or let both calls go by, is left alone for 3 days;
/// closing the greeting means no more calls this session. A call waits (4s,
/// then looks again) while the chat is open, the app is in the background,
/// the keyboard is up, an entrance is landing, or the greeting has been up
/// less than 15s; with the greeting up the mascot only calls (no bubble).
/// Nothing with reduced motion.
///
/// Ported from the React Native SDK's core/launcherIdleCall.ts. Pure.
library;

import 'dart:math' as math;

import '../i18n/i18n.dart';
import 'keyframes.dart';

const launcherIdleCalls = ['off', 'psst', 'peek', 'wave', 'knock', 'tap'];
const defaultIdleCallDelay = 12;
const idleCallTextMax = 24;

/// A blocked call looks again after this long.
const idleCallRetryMs = 4000;

/// A greeting on screen gets this long alone before the mascot may call.
const greetingFirstMs = 15000;

/// The bubble's line key per style (i18n idle.*), read in the active
/// language when drawn.
const idleCallLineKeys = {
  'psst': 'idle.psst',
  'peek': 'idle.peek',
  'wave': 'idle.wave',
  'knock': 'idle.knock',
  'tap': 'idle.tap',
};

String normalizeLauncherIdleCall(Object? value) => launcherIdleCalls.contains(value) ? value as String : 'off';

int normalizeIdleCallDelay(Object? value) {
  final n = value is num ? value.toDouble() : (value is String && value.trim().isNotEmpty ? double.tryParse(value.trim()) : null);
  if (n == null || !n.isFinite) return defaultIdleCallDelay;
  // Math.round: halves go up.
  return math.min(math.max((n + 0.5).floor(), 5), 120);
}

/// The bubble's line: the owner's, trimmed and capped, else the style's.
String idleCallLine(String mode, Object? text) {
  if (mode == 'off') return '';
  var own = text is String ? text.replaceAll(RegExp(r'\s+'), ' ').trim() : '';
  if (own.length > idleCallTextMax) own = own.substring(0, idleCallTextMax);
  if (own.isNotEmpty) return own;
  final key = idleCallLineKeys[mode];
  return key != null ? t(key) : '';
}

// ---- Pacing (idlePacing.ts): calling without nagging ----

const minGapMs = 3 * 60 * 1000;
const sessionMax = 2;
const restMs = 3 * 24 * 60 * 60 * 1000;

class VisitState {
  /// Calls played this session.
  final int n;

  /// When the last one played.
  final int at;

  /// "Not now" (the greeting was closed).
  final bool quiet;
  const VisitState({this.n = 0, this.at = 0, this.quiet = false});
  VisitState copyWith({int? n, int? at, bool? quiet}) => VisitState(n: n ?? this.n, at: at ?? this.at, quiet: quiet ?? this.quiet);
}

/// May a call play now?
bool callAllowed(VisitState visit, int restUntil, int now) =>
    !visit.quiet && now >= restUntil && visit.n < sessionMax && (visit.at == 0 || now - visit.at >= minGapMs);

/// A call just played: the new session state, and whether the visitor now rests (the last call).
({VisitState visit, bool rest}) afterCall(VisitState visit, int now) {
  final v = visit.copyWith(n: visit.n + 1, at: now);
  return (visit: v, rest: v.n >= sessionMax);
}

// ---- The performances ----

/// The geometry, from the launcher: its short side (unit), which way the
/// screen is (-1: the launcher is on the right), the x of its edge facing
/// the screen and its height, in the stage (the launcher's own box); and
/// whether the greeting card is up.
class IdleCallGeometry {
  final double unit, edgeX, width, height;
  final int inward;
  final bool card;
  const IdleCallGeometry({required this.unit, required this.inward, required this.edgeX, required this.width, required this.height, required this.card});
}

/// The idle call's geometry for a launcher of this size on this side.
IdleCallGeometry idleCallGeometry(double width, double height, String position, bool card) {
  final inward = position == 'right' ? -1 : 1;
  return IdleCallGeometry(unit: math.min(width, height), inward: inward, edgeX: inward == -1 ? 0 : width, width: width, height: height, card: card);
}

class IdleCallMascot {
  final double x, y, size;

  /// down, whisper, wave, reach, knock (mascot_art.dart).
  final String arm;

  /// Mirrored (sx -1) when the launcher is on the left.
  final Map<String, double> base;
  const IdleCallMascot(this.x, this.y, this.size, this.arm, this.base);
}

class IdleCallRipple {
  final double x, y, d;
  final Track track;
  const IdleCallRipple(this.x, this.y, this.d, this.track);
}

class IdleCallPerformance {
  final double total;

  /// When the speech bubble shows, and where it points (stage px).
  final double bubbleAt, sayX, sayY;
  final IdleCallMascot mascot;

  /// The box's own movement, and each part's (in the drawing's 100 x 100 units).
  final List<Track> self;
  final Map<String, List<Track>> parts;

  /// The launcher's jolt (knock, tap).
  final List<Track> launcher;

  /// White rings where a knock / tap lands (stage px, centre and diameter).
  final List<IdleCallRipple> ripples;

  /// The bubble's pop and fade (from bubbleAt).
  final Track bubble;

  /// It speaks (a bubble) only when the greeting is not up.
  final bool talks;

  /// Drawn in front of the launcher (its paw lands on the button); else just behind it.
  final bool front;

  const IdleCallPerformance({
    required this.total,
    required this.bubbleAt,
    required this.sayX,
    required this.sayY,
    required this.mascot,
    required this.self,
    required this.parts,
    this.launcher = const [],
    this.ripples = const [],
    required this.bubble,
    required this.talks,
    required this.front,
  });
}

const _pop = 'cubic-bezier(0.34, 1.56, 0.64, 1)';

String _px(num x, num y) => '${jsNum(x)}px ${jsNum(y)}px';

/// Slide out past the facing edge, hold, slide back - fading in from behind.
Track _slide(num dx, num dy, num total, [String rotate = '0deg']) {
  final inAt = 380 / total;
  return Track.of([
    {'translate': '0 0', 'rotate': '0deg', 'opacity': 0, 'scale': 0.7, 'easing': _pop},
    {'translate': _px(dx, dy), 'rotate': rotate, 'opacity': 1, 'scale': 1, 'offset': inAt},
    {'translate': _px(dx, dy), 'rotate': rotate, 'opacity': 1, 'scale': 1, 'offset': 1 - inAt, 'easing': 'ease-in'},
    {'translate': '0 0', 'rotate': '0deg', 'opacity': 0, 'scale': 0.7},
  ], duration: total, easing: 'linear', fill: 'forwards');
}

IdleCallRipple _ripple(num unit, num x, num y, num delay) => IdleCallRipple(
      x.toDouble(),
      y.toDouble(),
      unit * 0.55,
      Track.of([
        {'opacity': 0.95, 'scale': 0.35},
        {'opacity': 0, 'scale': 1.7},
      ], duration: 520, delay: delay, easing: 'ease-out', fill: 'forwards'),
    );

/// Blink (the lids are closed for ~70ms each time).
Track _blink(num total, List<double> at) => Track.of([
      {'transform': 'scaleY(0)'},
      for (final o in at) ...[
        {'transform': 'scaleY(0)', 'offset': o - 0.02},
        {'transform': 'scaleY(1)', 'offset': o},
        {'transform': 'scaleY(0)', 'offset': o + 0.02},
      ],
      {'transform': 'scaleY(0)'},
    ], duration: total, fill: 'forwards');

/// Where the pupils look: [offset, x, y] in drawing units.
Track _look(num total, List<(num, num, num)> path) => Track.of([
      {'translate': '0 0'},
      for (final (o, x, y) in path) {'translate': _px(x, y), 'offset': o, 'easing': 'ease-in-out'},
      {'translate': '0 0'},
    ], duration: total, fill: 'forwards');

/// One mouth ("smile" rests) between two offsets.
Map<String, List<Track>> _mouth(num total, String name, double from, double to) => {
      name: [
        Track.of([
          {'opacity': 0},
          {'opacity': 0, 'offset': from},
          {'opacity': 1, 'offset': from + 0.02},
          {'opacity': 1, 'offset': to},
          {'opacity': 0, 'offset': to + 0.02},
          {'opacity': 0},
        ], duration: total, fill: 'forwards'),
      ],
      'smile': [
        Track.of([
          {'opacity': 1},
          {'opacity': 1, 'offset': from},
          {'opacity': 0, 'offset': from + 0.02},
          {'opacity': 0, 'offset': to},
          {'opacity': 1, 'offset': to + 0.02},
          {'opacity': 1},
        ], duration: total, fill: 'forwards'),
      ],
    };

Track _brows(num total, double from, double to) => Track.of([
      {'translate': '0 0'},
      {'translate': '0 0', 'offset': from},
      {'translate': '0 -3.5px', 'offset': from + 0.05},
      {'translate': '0 -3.5px', 'offset': to},
      {'translate': '0 0', 'offset': to + 0.05},
      {'translate': '0 0'},
    ], duration: total, fill: 'forwards');

Track _bubbleTrack(num total, num at) => Track.of([
      {'opacity': 0, 'scale': 0.6, 'translate': '0 8px', 'easing': _pop},
      {'opacity': 1, 'scale': 1, 'translate': '0 0', 'offset': 0.12},
      {'opacity': 1, 'scale': 1, 'translate': '0 0', 'offset': 0.88, 'easing': 'ease-in'},
      {'opacity': 0, 'scale': 0.9, 'translate': '0 4px'},
    ], duration: total - at, delay: at, fill: 'forwards');

/// The parts each mascot part starts from: closed-lid rest, the o and grin mouths hidden.
const Map<String, Map<String, double>> mascotPartBase = {
  'lid': {'sy': 0},
  'o': {'o': 0},
  'grin': {'o': 0},
};

/// The performance for a mode in this geometry (PERFORMANCES): the mascot,
/// a touch bigger than the button, is centred just inside the facing edge
/// (behind the button) and moves out from there.
IdleCallPerformance idleCallPerformance(String mode, IdleCallGeometry g) {
  final w = g.unit * 1.2;
  IdleCallMascot place(double dy, String arm) =>
      IdleCallMascot(g.edgeX - g.inward * (math.min(w, g.width) / 2) - w / 2, g.height / 2 + dy - w / 2, w, arm, {'sx': g.inward == 1 ? -1.0 : 1.0});
  final front = mode == 'tap' || mode == 'knock';
  final talks = !g.card;
  if (mode == 'psst') {
    const total = 3600;
    final dx = g.inward * (w * 0.5);
    return IdleCallPerformance(
      total: total.toDouble(),
      bubbleAt: 360,
      sayX: g.edgeX + dx,
      sayY: g.height / 2 - g.unit * 0.1 - w * 0.42,
      mascot: place(-g.unit * 0.1, 'whisper'),
      self: [_slide(dx, -g.unit * 0.06, total, '${jsNum(g.inward * -6)}deg')],
      parts: {
        ..._mouth(total, 'o', 0.14, 0.82),
        'brow': [_brows(total, 0.14, 0.8)],
        'look': [
          _look(total, const [(0.16, 0, 0), (0.32, -2.5, -0.5), (0.44, -2.5, -0.5), (0.52, 1.5, 0), (0.72, 0, 0.5)]),
        ],
        'arm': [
          Track.of([
            {'rotate': '0deg'},
            {'rotate': '0deg', 'offset': 0.3},
            {'rotate': '-8deg', 'offset': 0.36},
            {'rotate': '0deg', 'offset': 0.42},
            {'rotate': '-8deg', 'offset': 0.48},
            {'rotate': '0deg', 'offset': 0.54},
            {'rotate': '0deg'},
          ], duration: total, fill: 'forwards'),
        ],
        'lid': [_blink(total, const [0.62])],
      },
      bubble: _bubbleTrack(total, 360),
      talks: talks,
      front: front,
    );
  }
  if (mode == 'peek') {
    const total = 3800;
    final dx = g.card ? g.inward * (w * 0.55) : -g.inward * w * 0.15;
    final dy = g.card ? -g.unit * 0.05 : -(g.height * 0.5 + w * 0.08);
    return IdleCallPerformance(
      total: total.toDouble(),
      bubbleAt: 560,
      sayX: g.edgeX + dx,
      sayY: g.height / 2 + dy - w * 0.35,
      mascot: place(g.card ? 0 : g.height * 0.05, 'down'),
      self: [
        Track.of([
          {'translate': '0 0', 'opacity': 0, 'easing': 'cubic-bezier(0.34, 1.56, 0.64, 1)'},
          {'translate': _px(dx, dy), 'opacity': 1, 'offset': 0.12},
          {'translate': _px(dx, dy + 3), 'offset': 0.5},
          {'translate': _px(dx, dy), 'opacity': 1, 'offset': 0.86, 'easing': 'ease-in'},
          {'translate': '0 0', 'opacity': 0},
        ], duration: total, fill: 'forwards'),
      ],
      parts: {
        'look': [
          _look(total, const [(0.18, 0, 0), (0.28, -3, 0), (0.4, -3, 0), (0.5, 3, 0), (0.62, 3, 0), (0.7, 0, 1)]),
        ],
        'brow': [_brows(total, 0.2, 0.36)],
        'lid': [_blink(total, const [0.46, 0.76])],
      },
      bubble: _bubbleTrack(total, 560),
      talks: talks,
      front: front,
    );
  }
  if (mode == 'wave') {
    const total = 3500;
    final dx = g.inward * (w * 0.62 + g.unit * 0.05);
    return IdleCallPerformance(
      total: total.toDouble(),
      bubbleAt: 320,
      sayX: g.edgeX + dx,
      sayY: g.height / 2 - g.unit * 0.1 - w * 0.46,
      mascot: place(-g.unit * 0.08, 'wave'),
      self: [_slide(dx, -g.unit * 0.1, total)],
      parts: {
        'body': [
          Track.of([
            {'scale': '1 1'},
            {'scale': '1.12 0.88', 'offset': 0.06},
            {'scale': '0.92 1.1', 'offset': 0.12},
            {'scale': '1.04 0.96', 'offset': 0.18},
            {'scale': '1 1', 'offset': 0.24},
            {'scale': '1 1'},
          ], duration: total, fill: 'forwards'),
        ],
        ..._mouth(total, 'grin', 0.12, 0.84),
        'arm': [
          Track.of([
            {'rotate': '0deg'},
            {'rotate': '0deg', 'offset': 0.14},
            {'rotate': '-24deg', 'offset': 0.24},
            {'rotate': '18deg', 'offset': 0.36},
            {'rotate': '-24deg', 'offset': 0.48},
            {'rotate': '18deg', 'offset': 0.6},
            {'rotate': '-10deg', 'offset': 0.7},
            {'rotate': '0deg', 'offset': 0.78},
            {'rotate': '0deg'},
          ], duration: total, fill: 'forwards'),
        ],
        'look': [_look(total, const [(0.2, 0, 1)])],
        'lid': [_blink(total, const [0.66])],
      },
      bubble: _bubbleTrack(total, 320),
      talks: talks,
      front: front,
    );
  }
  if (mode == 'knock') {
    const total = 3500;
    final dx = g.inward * (w * 0.9);
    const beats = [0.3, 0.41, 0.52];
    return IdleCallPerformance(
      total: total.toDouble(),
      bubbleAt: 320,
      sayX: g.edgeX + dx,
      sayY: g.height / 2 - g.unit * 0.08 - w * 0.42,
      mascot: place(-g.unit * 0.04, 'knock'),
      self: [_slide(dx, -g.unit * 0.08, total)],
      parts: {
        'arm': [
          Track.of([
            {'translate': '0 0', 'rotate': '0deg'},
            for (final o in beats) ...[
              {'translate': '0 0', 'rotate': '0deg', 'offset': o - 0.045},
              {'translate': '4px 0.5px', 'rotate': '5deg', 'offset': o, 'easing': 'cubic-bezier(.5,0,.9,.4)'},
              {'translate': '0 0', 'rotate': '0deg', 'offset': o + 0.05, 'easing': 'cubic-bezier(.2,.8,.4,1)'},
            ],
            {'translate': '0 0', 'rotate': '0deg'},
          ], duration: total, fill: 'forwards'),
        ],
        'body': [
          Track.of([
            {'rotate': '0deg'},
            for (final o in beats) ...[
              {'rotate': '0deg', 'offset': o - 0.045},
              {'rotate': '2.5deg', 'offset': o},
              {'rotate': '0deg', 'offset': o + 0.05},
            ],
            {'rotate': '0deg'},
          ], duration: total, fill: 'forwards'),
        ],
        'lid': [
          Track.of([
            {'transform': 'scaleY(0)'},
            for (final o in beats) ...[
              {'transform': 'scaleY(0)', 'offset': o - 0.03},
              {'transform': 'scaleY(0.5)', 'offset': o},
              {'transform': 'scaleY(0)', 'offset': o + 0.04},
            ],
            {'transform': 'scaleY(0)'},
          ], duration: total, fill: 'forwards'),
        ],
        ..._mouth(total, 'grin', 0.26, 0.8),
        'look': [_look(total, const [(0.2, 0, 1)])],
      },
      launcher: [
        for (final o in beats)
          Track.of([
            {'translate': '0 0'},
            {'translate': '${jsNum(-g.inward * 2)}px 0', 'offset': 0.35},
            {'translate': '0 0'},
          ], duration: 200, delay: o * total, easing: 'ease-out'),
      ],
      ripples: [for (final o in beats) _ripple(g.unit, g.edgeX - g.inward * g.unit * 0.08, g.height / 2 - g.unit * 0.12, o * total)],
      bubble: _bubbleTrack(total, 320),
      talks: talks,
      front: front,
    );
  }
  // tap
  const total = 3300;
  final dx = g.inward * (w * 0.98);
  const taps = [0.32, 0.46];
  return IdleCallPerformance(
    total: total.toDouble(),
    bubbleAt: 320,
    sayX: g.edgeX + dx,
    sayY: g.height / 2 - w * 0.42,
    mascot: place(-g.unit * 0.02, 'reach'),
    self: [_slide(dx, 0, total)],
    parts: {
      'arm': [
        Track.of([
          {'translate': '0 0'},
          for (final o in taps) ...[
            {'translate': '0 0', 'offset': o - 0.05},
            {'translate': '5px 1px', 'offset': o, 'easing': 'cubic-bezier(.5,0,.9,.4)'},
            {'translate': '0 0', 'offset': o + 0.06, 'easing': 'cubic-bezier(.2,.8,.4,1)'},
          ],
          {'translate': '0 0'},
        ], duration: total, fill: 'forwards'),
      ],
      'look': [
        _look(total, const [(0.16, 3, 1), (0.52, 3, 1), (0.62, 0, 0)]),
      ],
      ..._mouth(total, 'grin', 0.58, 0.84),
      'lid': [_blink(total, const [0.7])],
    },
    launcher: [
      for (final o in taps)
        Track.of([
          {'scale': 1},
          {'scale': 0.92, 'offset': 0.4},
          {'scale': 1},
        ], duration: 240, delay: o * total, easing: 'ease-out'),
    ],
    ripples: [for (final o in taps) _ripple(g.unit, g.edgeX - g.inward * g.unit * 0.18, g.height / 2, o * total)],
    bubble: _bubbleTrack(total, 320),
    talks: talks,
    front: front,
  );
}
