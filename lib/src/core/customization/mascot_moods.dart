/// The mascot's moods and the typing mascot, as the web plays them: CSS
/// @keyframes on the drawing's parts, kept here as the web wrote them and
/// turned into tracks for the evaluator (keyframes.dart cssKeyframes).
///
/// Moods (conferbot-widget src/ts/launcher/art3d.ts MASCOT_ANIM_CSS,
/// mascotState): a class on the drawing.
///   idle   a natural blink now and then (cb-m--blink, always on)
///   wave   the arm waves; a resting arm ("down") lifts first. Repeats, or
///          `waveCount` times (the greeting card: 2) and rests
///   think  a gentle bob with a head tilt, eyes looking around, brows up
///   happy  a happy bounce (twice) and a big smile, kept while the mood is
/// Each part turns about its own joint (mascot_art.dart mascotOrigins).
/// Reduced motion turns every movement off; the happy smile, which is not
/// motion, stays.
///
/// Typing ("mascot" typing style, src/css/polish.css .cb-typing--mascot):
/// the bust, 32 x 32, swaying about 50% 90% of its box, blinking and
/// glancing at three thought dots rising beside it. Still under reduced
/// motion.
///
/// Ported from the React Native SDK's core/mascotMoods.ts. Pure.
library;

import '../i18n/i18n.dart';
import 'keyframes.dart';

const mascotMoods = ['idle', 'wave', 'think', 'happy'];

/// How long the happy bounce plays (two hops).
const mascotHappyMs = 1800;

/// The launcher's mascot keeps its smile this long after a reply (launcherStyle.ts cheerLauncherMascot).
const mascotCheerMs = mascotHappyMs + 600;

/// The web's @keyframes bodies (art3d.ts MASCOT_ANIM_CSS, polish.css), verbatim.
const mascotKeyframes = {
  'cb-m-blink': '0%,41%,44.4%,86%,88.4%,90.4%,92.8%,100%{transform:scaleY(0)}42.6%,87.2%,91.6%{transform:scaleY(1)}',
  'cb-m-wave': '0%,52%,100%{transform:rotate(0)}60%{transform:rotate(-18deg)}68%{transform:rotate(8deg)}76%{transform:rotate(-16deg)}84%{transform:rotate(6deg)}92%{transform:rotate(-4deg)}',
  'cb-m-wave-up': '0%,100%{transform:rotate(0)}14%{transform:rotate(-118deg)}24%{transform:rotate(-132deg)}34%{transform:rotate(-104deg)}44%{transform:rotate(-132deg)}54%{transform:rotate(-108deg)}62%{transform:rotate(-118deg)}78%{transform:rotate(0)}',
  'cb-m-bob': '0%,100%{transform:translateY(0) rotate(0)}25%{transform:translateY(-1.6px) rotate(-3deg)}50%{transform:translateY(0) rotate(0)}75%{transform:translateY(-1.2px) rotate(2deg)}',
  'cb-m-glance': '0%,8%,92%,100%{transform:translate(0,0)}16%,38%{transform:translate(-2px,-1.6px)}46%,70%{transform:translate(2px,-1.8px)}78%,86%{transform:translate(.6px,.8px)}',
  'cb-m-ponder': '0%,100%{transform:translateY(-1px)}25%{transform:translateY(-2.4px)}',
  'cb-m-hop': '0%,100%{transform:translateY(0) scale(1,1)}18%{transform:translateY(0) scale(1.07,.92)}45%{transform:translateY(-8px) scale(.96,1.05)}70%{transform:translateY(0) scale(1.05,.95)}85%{transform:translateY(0) scale(.99,1.01)}',
  'cb-m-hop-shadow': '0%,18%,70%,100%{transform:scale(1);opacity:1}45%{transform:scale(.78);opacity:.55}',
  'cb-m-cheer': '0%,100%{transform:rotate(0)}45%{transform:rotate(-24deg)}',
  'cb-typing-sway': '0%, 100% { transform: rotate(-4deg) translateY(0.5px); } 50% { transform: rotate(4deg) translateY(-1px); }',
  'cb-typing-glance': '0%, 35%, 100% { transform: translate(0, 0); } 45%, 85% { transform: translate(2.2px, -1.6px); }',
  'cb-typing-blink': '0%, 92%, 100% { transform: scaleY(0); } 95% { transform: scaleY(1); }',
  'cb-typing-dot': '0%, 100% { opacity: 0.25; } 50% { opacity: 1; }',
  'cb-typing-write': '0% { stroke-dashoffset: 60; opacity: 1; } 75% { stroke-dashoffset: 0; opacity: 1; } 90% { stroke-dashoffset: 0; opacity: 1; } 100% { stroke-dashoffset: 0; opacity: 0; }',
  'cb-typing-pencil':
      '0% { transform: translate(2px, 11px); } 9% { transform: translate(6px, 6.5px); } 19% { transform: translate(11px, 10px); } 28% { transform: translate(16px, 13px); } 37% { transform: translate(19px, 9px); } 46% { transform: translate(24px, 5px); } 54% { transform: translate(27px, 10px); } 64% { transform: translate(32px, 12.5px); } 75%, 90% { transform: translate(36px, 8px); } 100% { transform: translate(2px, 11px); }',
};

/// A CSS animation (name duration timing iterations delay) as a track.
Track cssTrack(String name, num duration, String timing, [num iterations = 1, num delay = 0]) =>
    Track(cssKeyframes(mascotKeyframes[name]!, timing), TrackOptions(duration: duration.toDouble(), iterations: iterations.toDouble(), delay: delay.toDouble()));

/// The parts a mood moves (art3d classes): .cb-m-lid, -arm, -body, -look, -brow, -shadow.
const moodParts = ['lid', 'arm', 'body', 'look', 'brow', 'shadow'];

class MoodPlan {
  /// Each part's tracks (lid, arm, body, look, brow, shadow), in the order the web adds them.
  final Map<String, List<Track>> parts;

  /// The big smile in place of the usual one (happy; kept under reduced motion).
  final bool grin;

  /// When every finite part is over (ms); the blink goes on.
  final double settle;

  /// The blink's period: the loop after [settle] repeats it.
  final double period;
  const MoodPlan(this.parts, this.grin, this.settle, this.period);
}

const _blinkMs = 6400;
int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// A mood's tracks per part (mascotState: blink always, plus the mood's own).
/// [arm]: the arm's pose as drawn ("down" lifts before it waves); [bust]: no
/// arm; [waveCount]: --cb-m-wave-count, how many waves (infinity: on and on).
MoodPlan moodPlan(String mood, {String? arm, bool bust = false, double waveCount = double.infinity, bool reduced = false}) {
  final grin = mood == 'happy';
  if (reduced) return MoodPlan(const {}, grin, 0, 0);
  final parts = <String, List<Track>>{
    'lid': [cssTrack('cb-m-blink', _blinkMs, 'linear', double.infinity)],
  };
  final hasArm = !bust;
  if (mood == 'wave' && hasArm) {
    parts['arm'] = [arm == 'down' || arm == null ? cssTrack('cb-m-wave-up', 3200, 'ease-in-out', waveCount) : cssTrack('cb-m-wave', 2800, 'ease-in-out', waveCount)];
  }
  if (mood == 'think') {
    parts['body'] = [cssTrack('cb-m-bob', 3200, 'ease-in-out', double.infinity)];
    parts['look'] = [cssTrack('cb-m-glance', 4800, 'ease-in-out', double.infinity)];
    parts['brow'] = [cssTrack('cb-m-ponder', 3200, 'ease-in-out', double.infinity)];
  }
  if (mood == 'happy') {
    const hop = 'cubic-bezier(.3,.7,.4,1)';
    parts['body'] = [cssTrack('cb-m-hop', 900, hop, 2)];
    parts['shadow'] = [cssTrack('cb-m-hop-shadow', 900, hop, 2)];
    if (hasArm) parts['arm'] = [cssTrack('cb-m-cheer', 900, 'ease-in-out', 2)];
  }
  var settle = 0.0;
  var loops = false;
  final laps = <int>[];
  for (final tracks in parts.values) {
    for (final t in tracks) {
      if (t.options.iterations == double.infinity) {
        if (t.options.duration != _blinkMs) loops = true;
        laps.add(t.options.duration.round());
      } else {
        final end = t.options.delay + t.options.duration * t.options.iterations;
        if (end > settle) settle = end;
      }
    }
  }
  // Loops of their own (think, an endless wave): one lap of all of them together.
  final period = loops ? laps.fold(1, (m, x) => m * x ~/ _gcd(m, x)).toDouble() : _blinkMs.toDouble();
  // The finite part done, the loop starts on a whole blink.
  return MoodPlan(parts, grin, (settle / _blinkMs).ceil() * _blinkMs.toDouble(), period);
}

class TypingDot {
  /// Its size and how far up it sits (px).
  final double d, up;
  final Track track;
  const TypingDot(this.d, this.up, this.track);
}

/// The typing mascot (polish.css): the whole bust sways, the lids blink, the pupils glance; the three dots rise.
class TypingMascotSpec {
  TypingMascotSpec._();

  /// The bust's box, and its pivot (transform-origin 50% 90%).
  static const size = 32.0;
  static const origin = (16.0, 28.8);
  static final sway = cssTrack('cb-typing-sway', 2400, 'ease-in-out', double.infinity);
  static final blink = cssTrack('cb-typing-blink', 3400, 'ease-in-out', double.infinity);
  static final glance = cssTrack('cb-typing-glance', 2400, 'ease-in-out', double.infinity);

  /// The thought dots: 4, 5 and 7 across, 0, 3 and 7 up, each 0.2s after the last.
  static final dots = [
    TypingDot(4, 0, cssTrack('cb-typing-dot', 1200, 'ease-in-out', double.infinity)),
    TypingDot(5, 3, cssTrack('cb-typing-dot', 1200, 'ease-in-out', double.infinity, 200)),
    TypingDot(7, 7, cssTrack('cb-typing-dot', 1200, 'ease-in-out', double.infinity, 400)),
  ];

  /// One lap of all of it (the clock loops this).
  static const period = 40800.0;
}

/// The pencil (polish.css .cb-typing--pencil): the line writes itself in 2s, the pencil riding its tip.
class TypingPencilSpec {
  TypingPencilSpec._();
  static final write = cssTrack('cb-typing-write', 2000, 'linear', double.infinity);
  static final pencil = cssTrack('cb-typing-pencil', 2000, 'linear', double.infinity);
  static const line = 'M2 11 C 6 5, 9 5, 11 10 S 16 14, 19 9 S 25 4, 27 10 S 33 13, 36 8';
  static const dash = 60.0;
  static const period = 2000.0;
}

/// "Pip is typing" when the owner named their mascot (chatChrome.ts typingBubbleHtml), else "Typing".
String typingLabel(String style, String mascotName) =>
    style == 'mascot' && mascotName.isNotEmpty ? t('typing.named', {'name': mascotName}) : t('typing.typing');
