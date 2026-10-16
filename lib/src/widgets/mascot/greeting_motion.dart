/// The greeting card alive (the React Native SDK's components/Mascot/
/// useGreetingMotion.ts): the web's director (core/customization/
/// mascot_motion.dart) on this card, its stage on clocks the card's ticker
/// drives. The card springs up (lively) or comes in as always; the figure
/// pops (or rises), waves, nods, breathes and gives at most three small
/// gestures, then stands still; the "Online" dot pings once; the words fade
/// up. When the card goes ([leave]), the figure hands off to the launcher
/// (opened) or bows (the x) as the card collapses or fades, then `onGone`. A
/// voice note talks while its waveform plays. Nothing while the app is in
/// the background; reduced motion: a fade.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/customization/keyframes.dart';
import '../../core/customization/mascot_motion.dart';
import 'mascot_view.dart';

class GreetingMotion implements MascotStage {
  GreetingMotion({
    required TickerProvider vsync,
    required this.mode,
    required this.style,
    required this.text,
    required this.figure,
    required this.figureSize,
    required this.reduced,
    required VoidCallback onFrame,
    this.toward,
  }) {
    _onFrame = onFrame;
    time = FxTime(vsync, _frame);
    enter = FxClock(time);
    leaveClock = FxClock(time);
    gestureClock = FxClock(time);
    breathClock = FxClock(time);
    talkClock = FxClock(time);
    pingClock = FxClock(time);
    wordsClock = FxClock(time);
  }

  /// lively, subtle or off; the card's style; its words.
  final String mode;
  final String style;
  final String text;

  /// mascot, avatar or null (no figure: the card and its words only).
  final String? figure;

  /// The figure's box (px): its pivot is its feet (50% 100%).
  final double figureSize;
  final bool reduced;

  /// Where the launcher's centre is from the figure's (the hand-off), when known.
  final (double, double)? Function()? toward;

  late final VoidCallback _onFrame;
  late final FxTime time;
  late final FxClock enter, leaveClock, gestureClock, breathClock, talkClock, pingClock, wordsClock;
  MascotDirector? _director;
  Track? _gesture, _talk;
  bool _breathing = false, _pinging = false, _words = false;
  Track? _enterTrack, _leaveTrack;
  Timer? _gone;

  bool get moving => mode != 'off' && !reduced;
  MascotDirector? get director => _director;

  List<FxClock> get _clocks => [enter, leaveClock, gestureClock, breathClock, talkClock, pingClock, wordsClock];

  void _frame() {
    for (final c in _clocks) {
      c.tick();
    }
    if (!_clocks.any((c) => c.running)) time.stop();
    _onFrame();
  }

  /// The card shows: its entrance, and the director's show (a voice note talks).
  void start() {
    final amp = figureAmp(figure);
    // The figure's first move, held from the first frame so it never shows before its pop.
    if (moving && figure != null) _gesture = mode == 'lively' ? gestureTrack('pop', amp, 140) : gestureTrack('rise', amp, 80);
    _enterTrack = cardEnterTrack(mode, style, reduced);
    if (_enterTrack != null) enter.play(trackEnd(_enterTrack!));
    final d = _director = MascotDirector(mode: mode, stage: this, reduced: () => reduced, amp: () => figureAmp(figure), ownText: () => ownsText(style));
    d.show();
    if (style == 'voice' && !reduced) d.talkFor(voicePlayMs());
  }

  /// The card goes: the figure's hand-off ([reason] open) or bow (close), the card's collapse or fade, then [onGone].
  void leave(String reason, VoidCallback onGone) {
    if (_leaveTrack != null || _gone != null) return;
    _director?.hide(reason);
    final figureEnd = moving && figure != null ? (reason == 'close' ? 300 : 280) : 0;
    _leaveTrack = cardLeaveTrack(mode, reason, reduced);
    final cardEnd = _leaveTrack != null ? trackEnd(_leaveTrack!) : 0.0;
    if (_leaveTrack != null) leaveClock.play(cardEnd);
    _gone = Timer(Duration(milliseconds: math.max(figureEnd.toDouble(), cardEnd).round() + 16), onGone);
    _onFrame();
  }

  bool get leaving => _leaveTrack != null || _gone != null;

  void pageHidden(bool hidden) => _director?.pageHidden(hidden);

  void dispose() {
    _gone?.cancel();
    _director?.destroy();
    for (final c in _clocks) {
      c.stop();
    }
    time.dispose();
  }

  // ---- The stage ----

  @override
  void play(String g, double amp, [double delay = 0]) {
    if (figure == null) return;
    final tr = gestureTrack(g, amp, delay, g == 'handoff' ? toward?.call() : null);
    talkClock.stop();
    _talk = null;
    _gesture = tr;
    gestureClock.play(trackEnd(tr));
    _onFrame();
  }

  @override
  void breathe(bool on) {
    if (on) {
      _breathing = true;
      breathClock.loop(0, breathMs.toDouble());
    } else {
      breathClock.finishLap(() => _breathing = false);
    }
  }

  @override
  void talk(bool on, double amp) {
    if (on) {
      gestureClock.stop();
      _gesture = null;
      _talk = talkTrack(amp);
      talkClock.loop(0, talkMs.toDouble());
    } else {
      talkClock.finishLap(() => _talk = null);
    }
  }

  // A touch screen has no pointer to lean toward.
  @override
  void lean(double x, double amp) {}

  @override
  void ping(bool on) {
    if (!on) return;
    _pinging = true;
    pingClock.play(trackEnd(Ping.ring));
  }

  @override
  void words() {
    if (wordFade(text) == null) return;
    _words = true;
    wordsClock.play(tracksEnd(wordFade(text)!.tracks));
  }

  @override
  void reset() {
    for (final c in [gestureClock, breathClock, talkClock, pingClock]) {
      c.stop();
    }
    _gesture = null;
    _talk = null;
    _breathing = false;
    _pinging = false;
  }

  // ---- What the card draws now ----

  MascotPart? _at(Track? tr, FxClock c, [Map<String, double>? base]) => tr == null ? null : MascotPart(evaluate([tr], c.t, base), transformOrder(tr));

  /// The card's entrance (about its centre).
  MascotPart? get enterPart => _at(_enterTrack, enter);

  /// The card leaving (about its centre).
  MascotPart? get leavePart => _at(_leaveTrack, leaveClock);

  /// The figure: its gesture, breath (outside) and talk, each about its feet.
  MascotPart? get gesturePart => _at(_gesture, gestureClock);
  MascotPart? get breathPart => _breathing ? _at(breathTrack, breathClock) : null;
  MascotPart? get talkPart => _at(_talk, talkClock);

  /// The "Online" dot swelling once, and its ring (none on the notification and postcard).
  MascotPart? get pingDot => _pinging ? _at(Ping.dot, pingClock) : null;
  MascotPart? get pingRing => _pinging && Ping.ringed(style) ? _at(Ping.ring, pingClock) : null;

  /// Each word fading up (null when the words are not fading).
  (List<String>, List<MascotPart>)? get wordParts {
    if (!_words) return null;
    final f = wordFade(text);
    if (f == null) return null;
    return (f.words, [for (final tr in f.tracks) MascotPart(evaluate([tr], wordsClock.t), transformOrder(tr))]);
  }

  /// The figure (the mascot or the avatar), breathing, gesturing and talking about its feet.
  Widget figureBox(Widget child) {
    final feet = Offset(figureSize / 2, figureSize);
    return fxBox(breathPart, fxBox(gesturePart, fxBox(talkPart, child, origin: feet), origin: feet), origin: feet);
  }
}
