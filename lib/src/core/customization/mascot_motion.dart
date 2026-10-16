/// The greeting card's figure, alive (conferbot-widget src/ts/home/mascotMotion.ts
/// and css/polish-home.css .cb-mm): how the bot's figure on the greeting card
/// moves. The figure is the owner's mascot (mascotInGreeting) or the bot's
/// avatar; everything here moves it as a whole.
///
/// customizations.mascotMotion: "lively" (absent), "subtle" or "off".
///
/// Lively, from the moment the card shows (it springs up, cb-greet-spring):
///     0ms  the greeting's words start fading up, one after another (< 1s)
///   140ms  the figure pops in: stretch, squash, settle (620ms)
///   760ms  a friendly wave, rocking about its feet (900ms)
///   900ms  the "Online" dot sends out one soft ping
///  1660ms  a blink-like double squash (380ms)
///  1900ms  idle: a slow breath (2px), and a small gesture every 8-12s,
///          three at most; 3s after the last one the breath ends on its
///          next exhale and the figure stands still for good.
/// Subtle: a gentle rise, the ping, the breath and a single head tilt; the
/// card comes in as it always did (cb-greet-in). Off: nothing moves.
///
/// Leaving: opening the chat from the card hands off (the figure shrinks
/// toward the launcher as the card collapses, cb-greet-collapse); the x sends
/// it off with a small bow (the card cb-greet-out). A voice note makes it
/// talk (a rhythmic squash) while its waveform plays.
///
/// Calm by design: no gesture while the app is in the background, nothing
/// that loops for ever, and under reduced motion just a fade. Hovering (the
/// lean toward the pointer, the hop) has no counterpart on a touch screen,
/// as on the web, where touch pointers are ignored.
///
/// The director has no view: it calls a stage (tested on a fake clock). The
/// gestures are Web Animations keyframes (keyframes.dart evaluates them);
/// the card's own moves are CSS @keyframes, as the web wrote them. Ported
/// from the React Native SDK's core/mascotMotion.ts, line for line. Pure.
library;

import 'dart:async';
import 'dart:math' as math;

import 'keyframes.dart';

const mascotMotions = ['lively', 'subtle', 'off'];
const defaultMascotMotion = 'lively';

String normalizeMascotMotion(Object? value) => value is String && mascotMotions.contains(value) ? value : defaultMascotMotion;

/// When each part of the entrance plays, ms after the card shows.
class MascotEntrance {
  MascotEntrance._();
  static const livelyPop = 140, livelyWave = 760, livelyPing = 900, livelyNod = 1660, livelyIdle = 1900;
  static const subtleRise = 80, subtlePing = 600, subtleIdle = 900;
}

/// Idle gestures: one every 8-12s, at most this many, then still.
const idleGapMin = 8000;
const idleGapSpread = 4000;
const idleGestures = {
  'lively': ['tilt', 'wave', 'tilt'],
  'subtle': ['tilt'],
};

/// After the last idle gesture, the breath ends this much later.
const settleAfter = 3000;

/// The "Online" ping's class stays this long (one ring).
const pingMs = 1300;

/// Hover hops no closer together than this.
const hopGap = 1500;

/// What the director asks of the view. Every call is safe without a figure.
abstract class MascotStage {
  /// Play a one-off gesture on the figure (replacing one in flight).
  void play(String gesture, double amp, [double delay = 0]);

  /// Start the slow breath, or let it end on its next exhale.
  void breathe(bool on);

  /// Talk (a rhythmic squash) while a voice note plays.
  void talk(bool on, double amp);

  /// Lean toward the pointer: -1 (left) .. 1 (right), 0 upright.
  void lean(double x, double amp);

  /// The "Online" dot's single ping.
  void ping(bool on);

  /// The greeting's words fading up one by one.
  void words();

  /// Stop everything now, the figure as drawn.
  void reset();
}

/// Timers the director runs on (dart:async by default; a fake clock in tests).
abstract class MascotTimers {
  Object set(void Function() fn, int ms);
  void clear(Object id);
}

class _AsyncTimers implements MascotTimers {
  const _AsyncTimers();
  @override
  Object set(void Function() fn, int ms) => Timer(Duration(milliseconds: ms), fn);
  @override
  void clear(Object id) => (id as Timer).cancel();
}

/// hidden, entering, living, settled, destroyed.
typedef DirectorState = String;

/// The web's director (mascotMotion.ts createMascotDirector), line for line.
class MascotDirector {
  final String mode;
  final MascotStage stage;

  /// Reduced motion, read each time the card shows.
  final bool Function()? reducedOf;

  /// How far the figure moves: 1 for a mascot, less for a photo ([figureAmp]).
  final double Function()? ampOf;

  /// The style reveals its own text (typewriter, text message): no word fade.
  final bool Function()? ownText;
  final MascotTimers timers;
  final double Function() random;
  final int Function() now;

  /// False once the card has gone: the director stops itself.
  final bool Function()? alive;

  MascotDirector({
    required this.mode,
    required this.stage,
    bool Function()? reduced,
    double Function()? amp,
    this.ownText,
    MascotTimers? timers,
    double Function()? random,
    int Function()? now,
    this.alive,
  })  : reducedOf = reduced,
        ampOf = amp,
        timers = timers ?? const _AsyncTimers(),
        random = random ?? math.Random().nextDouble,
        now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final Set<Object> _live = {};
  DirectorState _state = 'hidden';
  int _gestures = 0;
  bool _talking = false;
  bool _wantTalk = false;
  bool _reduced = false;
  double _amp = 1;
  double _lastHop = double.negativeInfinity;
  bool _hidden = false;
  Object? _idleTimer;
  Object? _talkTimer;

  DirectorState get state => _state;

  /// Idle gestures played since the card last showed.
  int get gestures => _gestures;

  /// Timers waiting (tests: none may outlive a hide / settle / destroy).
  int pending() => _live.length;

  bool get _lively => mode == 'lively';
  bool get _moving => mode != 'off' && !_reduced;

  Object _after(int ms, void Function() fn) {
    late final Object id;
    id = timers.set(() {
      _live.remove(id);
      if (alive != null && !alive!()) {
        destroy();
        return;
      }
      fn();
    }, ms);
    _live.add(id);
    return id;
  }

  void _cancel(Object? id) {
    if (id == null) return;
    timers.clear(id);
    _live.remove(id);
  }

  void _cancelAll() {
    for (final id in _live) {
      timers.clear(id);
    }
    _live.clear();
    _idleTimer = null;
    _talkTimer = null;
  }

  void _startTalking() {
    if (_talking) return;
    _talking = true;
    stage.talk(true, _lively ? _amp : _amp * 0.5);
  }

  void _stopTalking() {
    if (!_talking) return;
    _talking = false;
    stage.talk(false, _amp);
  }

  List<String> get _gestureList => idleGestures[_lively ? 'lively' : 'subtle']!;

  void _scheduleIdle() {
    _cancel(_idleTimer);
    _idleTimer = null;
    if (_state != 'living' || _hidden) return;
    if (_gestures >= _gestureList.length) {
      _idleTimer = _after(settleAfter, () {
        _idleTimer = null;
        _settle();
      });
      return;
    }
    _idleTimer = _after(idleGapMin + (random() * idleGapSpread).floor(), () {
      _idleTimer = null;
      // Talking: the gesture waits for a quiet moment (not counted).
      if (!_talking) {
        stage.play(_gestureList[_gestures], _amp);
        _gestures += 1;
      }
      _scheduleIdle();
    });
  }

  void _settle() {
    if (_state != 'living') return;
    _state = 'settled';
    stage.breathe(false);
  }

  void _goLive() {
    if (_state != 'entering') return;
    _state = 'living';
    stage.breathe(true);
    if (_wantTalk) _startTalking();
    _scheduleIdle();
  }

  void _pingOnce() {
    stage.ping(true);
    _after(pingMs, () => stage.ping(false));
  }

  void show() {
    if (_state == 'destroyed') return;
    _cancelAll();
    stage.reset();
    _talking = false;
    _gestures = 0;
    _lastHop = double.negativeInfinity;
    _reduced = reducedOf?.call() ?? false;
    _amp = (ampOf?.call() ?? 1).clamp(0.0, 1.0).toDouble();
    if (mode == 'off') {
      _state = 'settled';
      return;
    }
    if (_reduced) {
      // A plain fade, and nothing after it.
      stage.play('fadeIn', 0);
      _state = 'settled';
      return;
    }
    _state = 'entering';
    if (_lively) {
      if (!(ownText?.call() ?? false)) stage.words();
      stage.play('pop', _amp, MascotEntrance.livelyPop.toDouble());
      _after(MascotEntrance.livelyWave, () {
        if (_wantTalk) {
          _startTalking();
        } else {
          stage.play('wave', _amp);
        }
      });
      _after(MascotEntrance.livelyPing, _pingOnce);
      _after(MascotEntrance.livelyNod, () {
        if (!_talking) stage.play('nod', _amp);
      });
      _after(MascotEntrance.livelyIdle, _goLive);
    } else {
      stage.play('rise', _amp, MascotEntrance.subtleRise.toDouble());
      _after(MascotEntrance.subtlePing, _pingOnce);
      _after(MascotEntrance.subtleIdle, _goLive);
    }
  }

  /// [reason]: open (the chat from the card, or the chat opened), close (the x), away.
  void hide([String reason = 'open']) {
    if (_state == 'destroyed' || _state == 'hidden') return;
    _cancelAll();
    final wasMoving = _moving;
    stage.reset();
    _talking = false;
    _wantTalk = false;
    _state = 'hidden';
    if (wasMoving && reason != 'away') stage.play(reason == 'close' ? 'bow' : 'handoff', _lively ? _amp : _amp * 0.6);
  }

  void hover(bool on) {
    if (!_moving || (_state != 'living' && _state != 'settled' && _state != 'entering')) return;
    if (!on) {
      stage.lean(0, _amp);
      return;
    }
    if (_lively && _state != 'entering' && !_talking && now() - _lastHop >= hopGap) {
      _lastHop = now().toDouble();
      stage.play('hop', _amp);
    }
  }

  void point(double x) {
    if (!_moving || _state == 'hidden' || _state == 'destroyed') return;
    final clamped = (x.isFinite ? x : 0.0).clamp(-1.0, 1.0).toDouble();
    stage.lean(clamped, _lively ? _amp : _amp * 0.6);
  }

  void talk(bool on) {
    _wantTalk = on;
    if (!on) {
      _cancel(_talkTimer);
      _talkTimer = null;
      _stopTalking();
      return;
    }
    if (!_moving || _state == 'hidden' || _state == 'destroyed') return;
    // During the entrance it waits for the pop to land.
    if (_state == 'entering') return;
    _startTalking();
  }

  /// Talk for [ms], then stop (a voice note of known length).
  void talkFor(int ms) {
    if (!_moving || _state == 'hidden' || _state == 'destroyed') return;
    talk(true);
    _cancel(_talkTimer);
    _talkTimer = _after(math.max(0, ms), () {
      _talkTimer = null;
      talk(false);
    });
  }

  /// The app went to the background / came back.
  void pageHidden(bool isHidden) {
    if (_hidden == isHidden) return;
    _hidden = isHidden;
    if (_state != 'living') return;
    if (_hidden) {
      _cancel(_idleTimer);
      _idleTimer = null;
    } else {
      _scheduleIdle();
    }
  }

  void destroy() {
    if (_state == 'destroyed') return;
    _cancelAll();
    stage.reset();
    _talking = false;
    _state = 'destroyed';
  }
}

// ---------- The gestures: Web Animations on the figure ----------

double _fixed(double x, int d) => double.parse(x.toStringAsFixed(d));
num _sc(double a, double x) => _fixed(1 + (x - 1) * a, 4);
String _dg(double a, double x) => '${jsNum(_fixed(x * a, 2))}deg';
String _px(double a, double x) => '${jsNum(_fixed(x * a, 2))}px';
String _s(num x) => jsNum(x);

class GestureFrames {
  final List<Keyframe> frames;
  final double ms;
  final String easing;
  const GestureFrames(this.frames, this.ms, this.easing);
}

/// Each gesture's keyframes at a given amplitude (1 = the mascot's full swing), as the web passes them to element.animate().
GestureFrames gestureFrames(String g, double a, [(double, double) toward = (0, 30)]) {
  switch (g) {
    case 'pop':
      return GestureFrames([
        {'transform': 'translateY(${_px(a, 6)}) scale(0.3)', 'opacity': 0, 'offset': 0},
        {'transform': 'translateY(${_px(a, -3)}) scale(${_s(_sc(a, 0.92))}, ${_s(_sc(a, 1.14))})', 'opacity': 1, 'offset': 0.42},
        {'transform': 'translateY(0px) scale(${_s(_sc(a, 1.1))}, ${_s(_sc(a, 0.9))})', 'offset': 0.64},
        {'transform': 'translateY(${_px(a, -1)}) scale(${_s(_sc(a, 0.97))}, ${_s(_sc(a, 1.03))})', 'offset': 0.82},
        {'transform': 'none', 'opacity': 1, 'offset': 1},
      ], 620, 'cubic-bezier(.3,.7,.4,1)');
    case 'rise':
      return const GestureFrames([
        {'transform': 'translateY(4px) scale(0.85)', 'opacity': 0},
        {'transform': 'none', 'opacity': 1},
      ], 420, 'cubic-bezier(.22,1,.36,1)');
    case 'fadeIn':
      return const GestureFrames([
        {'opacity': 0},
        {'opacity': 1},
      ], 220, 'ease-out');
    case 'wave':
      return GestureFrames([
        {'transform': 'rotate(0deg)', 'offset': 0},
        {'transform': 'rotate(${_dg(a, -10)})', 'offset': 0.2},
        {'transform': 'rotate(${_dg(a, 8)})', 'offset': 0.42},
        {'transform': 'rotate(${_dg(a, -6)})', 'offset': 0.62},
        {'transform': 'rotate(${_dg(a, 3)})', 'offset': 0.8},
        {'transform': 'rotate(0deg)', 'offset': 1},
      ], 900, 'ease-in-out');
    case 'tilt':
      return GestureFrames([
        {'transform': 'none', 'offset': 0},
        {'transform': 'rotate(${_dg(a, -7)}) translateX(${_px(a, -1)})', 'offset': 0.25},
        {'transform': 'rotate(${_dg(a, -6)}) translateX(${_px(a, -1)})', 'offset': 0.7},
        {'transform': 'none', 'offset': 1},
      ], 1300, 'cubic-bezier(.45,0,.25,1)');
    case 'nod':
      return GestureFrames([
        {'transform': 'none', 'offset': 0},
        {'transform': 'scale(${_s(_sc(a, 1.03))}, ${_s(_sc(a, 0.9))})', 'offset': 0.3},
        {'transform': 'none', 'offset': 0.55},
        {'transform': 'scale(${_s(_sc(a, 1.02))}, ${_s(_sc(a, 0.93))})', 'offset': 0.75},
        {'transform': 'none', 'offset': 1},
      ], 380, 'ease-in-out');
    case 'hop':
      return GestureFrames([
        {'transform': 'none', 'offset': 0},
        {'transform': 'scale(${_s(_sc(a, 1.08))}, ${_s(_sc(a, 0.92))})', 'offset': 0.18},
        {'transform': 'translateY(${_px(a, -6)}) scale(${_s(_sc(a, 0.96))}, ${_s(_sc(a, 1.05))})', 'offset': 0.45},
        {'transform': 'scale(${_s(_sc(a, 1.05))}, ${_s(_sc(a, 0.95))})', 'offset': 0.72},
        {'transform': 'none', 'offset': 1},
      ], 560, 'cubic-bezier(.3,.7,.4,1)');
    case 'handoff':
      // Toward the launcher, shrinking, gone as the card collapses.
      return GestureFrames([
        {'transform': 'none', 'opacity': 1},
        {'transform': 'translate(${_px(a, toward.$1 * 0.2)}, ${_px(a, toward.$2 * 0.12)}) scale(${_s(_sc(a, 1.08))}, ${_s(_sc(a, 0.94))})', 'opacity': 1, 'offset': 0.25},
        {'transform': 'translate(${_px(a, toward.$1 * 0.6)}, ${_px(a, toward.$2 * 0.6)}) scale(0.25)', 'opacity': 0},
      ], 280, 'cubic-bezier(.5,0,.75,0)');
    case 'bow':
      return GestureFrames([
        {'transform': 'none', 'opacity': 1},
        {'transform': 'rotate(${_dg(a, 6)}) translateY(${_px(a, 1)}) scale(${_s(_sc(a, 1.02))}, ${_s(_sc(a, 0.9))})', 'opacity': 1, 'offset': 0.4},
        {'transform': 'rotate(${_dg(a, 6)}) scale(0.5)', 'opacity': 0},
      ], 300, 'ease-in');
  }
  throw ArgumentError.value(g, 'gesture');
}

/// A gesture as the track the web plays (fill backwards; forwards for the two that leave).
Track gestureTrack(String g, double amp, [double delay = 0, (double, double)? toward]) {
  final f = gestureFrames(g, amp, toward ?? (0, 30));
  final leaving = g == 'handoff' || g == 'bow';
  return Track(f.frames, TrackOptions(duration: f.ms, delay: delay, easing: f.easing, fill: leaving ? 'forwards' : 'backwards'));
}

const talkMs = 640;
List<Keyframe> talkFrames(double a) => [
      {'transform': 'none', 'offset': 0},
      {'transform': 'scale(${_s(_sc(a, 1.025))}, ${_s(_sc(a, 0.965))})', 'offset': 0.2},
      {'transform': 'scale(${_s(_sc(a, 0.99))}, ${_s(_sc(a, 1.03))})', 'offset': 0.45},
      {'transform': 'scale(${_s(_sc(a, 1.03))}, ${_s(_sc(a, 0.96))})', 'offset': 0.7},
      {'transform': 'none', 'offset': 1},
    ];

/// The talk, one syllable per lap.
Track talkTrack(double a) => Track(talkFrames(a), const TrackOptions(duration: talkMs * 1.0, iterations: double.infinity, easing: 'ease-in-out'));

const breathMs = 3400;

/// The slow breath, on the individual translate / scale (it sits under the gestures' transform).
final breathTrack = Track(
  const [
    {'translate': '0 0', 'scale': '1'},
    {'translate': '0 -2px', 'scale': '1.012'},
    {'translate': '0 0', 'scale': '1'},
  ],
  const TrackOptions(duration: breathMs * 1.0, iterations: double.infinity, easing: 'ease-in-out'),
);

/// How far the figure leans toward the pointer at full amplitude.
const leanDeg = 6;

/// How far each figure moves: the mascot all the way, a photo 0.75, initials 0.55.
double figureAmp(String? figure) => figure == 'initials' ? 0.55 : figure == 'avatar' ? 0.75 : 1;

/// The styles that reveal their own words (typewriter, the text message): no word fade.
bool ownsText(String style) => style == 'typewriter' || style == 'imessage';

// ---------- The card (polish-home.css), as the web wrote it ----------

const cardKeyframes = {
  'cb-greet-in': 'from { opacity: 0; transform: translateY(10px) scale(0.98); } to { opacity: 1; transform: none; }',
  'cb-greet-out': 'from { opacity: 1; transform: none; } to { opacity: 0; transform: translateY(6px) scale(0.98); }',
  'cb-greet-spring': '0% { opacity: 0; transform: translateY(14px) scale(0.94); } 55% { opacity: 1; transform: translateY(-3px) scale(1.01); } 78% { transform: translateY(1px) scale(0.998); } 100% { opacity: 1; transform: none; }',
  'cb-greet-collapse': 'from { opacity: 1; transform: none; } to { opacity: 0; transform: translateY(16px) scale(0.86); }',
  'cb-mm-word': 'from { opacity: 0; transform: translateY(5px); filter: blur(2px); } to { opacity: 1; transform: none; filter: none; }',
  'cb-mm-dot': '0%, 100% { transform: scale(1); } 40% { transform: scale(1.35); }',
  'cb-mm-ring': 'from { opacity: 0.55; transform: scale(1); } to { opacity: 0; transform: scale(3.2); }',
};

Track _cardTrack(String name, num duration, String timing, [num delay = 0, String fill = 'forwards']) =>
    Track(cssKeyframes(cardKeyframes[name]!, timing), TrackOptions(duration: duration.toDouble(), delay: delay.toDouble(), fill: fill));

/// How the card comes in: lively springs up (cb-greet-spring 0.62s), the
/// others as always (cb-greet-in 0.45s). The notification and neon keep their
/// own entrance (the style's rule wins), as does reduced motion (none): null.
Track? cardEnterTrack(String mode, String style, [bool reduced = false]) {
  if (reduced || style == 'notification' || style == 'neon') return null;
  return mode == 'lively' ? _cardTrack('cb-greet-spring', 620, 'cubic-bezier(0.2, 0.9, 0.3, 1)') : _cardTrack('cb-greet-in', 450, 'cubic-bezier(0.22, 1, 0.36, 1)');
}

/// How the card goes: opened from the card with the figure moving, it
/// collapses toward the launcher (cb-greet-collapse 0.24s after 0.04s);
/// otherwise it fades down (cb-greet-out 0.22s). Reduced motion: at once.
Track? cardLeaveTrack(String mode, String reason, [bool reduced = false]) {
  if (reduced) return null;
  return reason == 'open' && mode != 'off' ? _cardTrack('cb-greet-collapse', 240, 'cubic-bezier(0.55, 0, 0.75, 0.2)', 40) : _cardTrack('cb-greet-out', 220, 'ease-in');
}

/// The "Online" dot's ping: the dot swells once (cb-mm-dot 0.5s) and one ring goes out (cb-mm-ring 1.1s). No ring on the notification and postcard.
class Ping {
  Ping._();
  static final dot = _cardTrack('cb-mm-dot', 500, 'cubic-bezier(0.3, 1.6, 0.5, 1)', 0, 'none');
  static final ring = _cardTrack('cb-mm-ring', 1100, 'cubic-bezier(0.2, 0.7, 0.3, 1)');
  static bool ringed(String style) => style != 'notification' && style != 'postcard';
}

class WordFade {
  final List<String> words;
  final int step;
  final List<Track> tracks;
  const WordFade(this.words, this.step, this.tracks);
}

/// The greeting's words fading up (mascotMotion.ts stage.words): each word
/// 0.32s, from 380ms, a step apart that shrinks for a longer message so all
/// of it is up within about a second. Null for fewer than two words (left as
/// it is).
WordFade? wordFade(String text) {
  final words = text.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (words.length < 2) return null;
  final step = math.min(55, 520 ~/ (words.length - 1));
  return WordFade(words, step, [for (var i = 0; i < words.length; i++) _cardTrack('cb-mm-word', 320, 'cubic-bezier(0.22, 1, 0.36, 1)', 380 + i * step, 'both')]);
}

/// How long a voice note "plays" as the card shows: 22 bars, each 1.2s twice, 60ms apart (polish-home.css cb-wave).
int voicePlayMs([int bars = 22]) => (bars - 1) * 60 + 1200 * 2;

/// When a track is over: its end, or one lap (a loop).
double trackEnd(Track t) => t.options.iterations == double.infinity ? t.options.delay + t.options.duration : tracksEnd([t]);
