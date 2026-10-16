/// Launcher attention, as the web widget plays it (conferbot-widget
/// src/ts/launcher/attention.ts): an opt-in, continuous "look here" motion
/// on the closed launcher or the greeting card.
///
///   customizations.launcherAttention:
///     "off"    (default) nothing;
///     "pulse"  a soft ring grows out of the launcher every 3s;
///     "wobble" a jelly squash and twist every 5.5s;
///     "bounce" a hop with a contact shadow every 5s;
///     "wave"   the greeting card bobs and a waving hand waves on it, 6s;
///     "float"  the greeting card floats up and down, 4s;
///     "shine"  a gloss sweeps across the button every 5s;
///     "heartbeat" two beats (lub-dub) every 3s;
///     "orbit"  a spark runs two laps round the button every 5.2s.
///
/// The rules (widgets/launcher_fx_controllers.dart keeps them): the first beat
/// 1.5s after the launcher (or the card) shows; only while the chat is
/// closed; paused while the launcher plays an idle or message moment; over
/// for the app session once the chat is opened (and not started when it was
/// opened in the last 30 minutes); nothing with reduced motion. While a
/// launcher-moving mode runs, the launcher's idle moments hold off and the
/// three ripples after load give way (a new message's ripple still plays).
/// Nothing moves while an entrance is landing.
///
/// Ported from the React Native SDK's core/launcherAttention.ts. Pure.
library;

import 'dart:math' as math;

import 'keyframes.dart';

const launcherAttentions = ['off', 'pulse', 'wobble', 'bounce', 'wave', 'float', 'shine', 'heartbeat', 'orbit'];

String normalizeLauncherAttention(Object? value) => launcherAttentions.contains(value) ? value as String : 'off';

/// Which element a mode moves: 'launcher', 'greeting', or null.
String? attentionTarget(String mode) => mode == 'off' ? null : (mode == 'wave' || mode == 'float' ? 'greeting' : 'launcher');

/// The first beat waits this long after the launcher (or the card) shows.
const attentionStartMs = 1500;

/// While an entrance lands, attention looks again this often.
const attentionRetryMs = 400;

Track _loop(String part, List<Keyframe> kf, num duration, [num delay = attentionStartMs]) =>
    Track.of(kf, duration: duration, iterations: double.infinity, easing: 'linear', delay: delay, part: part);

/// The pulse ring (ATTENTION_CSS cb-attn-ring / cb-attn-ring-wide): a CSS
/// animation, so its timing function eases each step. The second ring is 350ms behind.
const _ringEase = 'cubic-bezier(0,0,.2,1)';
Track _ring(String part, bool wide) => _loop(
      part,
      wide
          ? [
              {'offset': 0, 'scale': '1', 'opacity': 0.42, 'easing': _ringEase},
              {'offset': 0.55, 'scale': '1.12 1.6', 'opacity': 0, 'easing': _ringEase},
              {'offset': 1, 'scale': '1.12 1.6', 'opacity': 0},
            ]
          : [
              {'offset': 0, 'scale': '1', 'opacity': 0.85, 'easing': _ringEase},
              {'offset': 0.6, 'scale': '1.85', 'opacity': 0, 'easing': _ringEase},
              {'offset': 1, 'scale': '1.85', 'opacity': 0},
            ],
      3000,
      part == 'ring' ? attentionStartMs : attentionStartMs + 350,
    );

/// The movement for a mode, as the web's tracks. Parts: "self" = the target
/// (launcher or card), "hand" = the card's waving hand, "shadow" = the
/// bounce's contact shadow, "shine" = the gloss band, "orbit" = the spark,
/// "ring" / "ring2" = the pulse's two rings. `clipped`: the button clips its
/// own outline, so the pulse throbs the button instead of a ring. `wide`:
/// the label pill, whose ring grows less sideways.
List<Track> attentionTracks(String mode, [bool clipped = false, bool wide = false]) {
  const e = 'ease-in-out';
  switch (mode) {
    case 'pulse':
      return clipped
          ? [
              _loop('self', [
                {'scale': '1', 'offset': 0, 'easing': e},
                {'scale': '1.08', 'offset': 0.1, 'easing': e},
                {'scale': '1', 'offset': 0.2, 'easing': e},
                {'scale': '1.05', 'offset': 0.28, 'easing': e},
                {'scale': '1', 'offset': 0.36},
                {'scale': '1', 'offset': 1},
              ], 3000),
            ]
          : [_ring('ring', wide), _ring('ring2', wide)];
    case 'wobble':
      return [
        _loop('self', [
          {'scale': '1', 'rotate': '0deg', 'offset': 0, 'easing': e},
          {'scale': '1.14 0.86', 'rotate': '-4deg', 'offset': 0.04, 'easing': e},
          {'scale': '0.88 1.12', 'rotate': '4deg', 'offset': 0.08, 'easing': e},
          {'scale': '1.07 0.94', 'rotate': '-2.5deg', 'offset': 0.12, 'easing': e},
          {'scale': '0.96 1.04', 'rotate': '1.5deg', 'offset': 0.16, 'easing': e},
          {'scale': '1.02 0.98', 'rotate': '0deg', 'offset': 0.2, 'easing': e},
          {'scale': '1', 'rotate': '0deg', 'offset': 0.24},
          {'scale': '1', 'rotate': '0deg', 'offset': 1},
        ], 5500),
      ];
    case 'bounce':
      return [
        _loop('self', [
          {'translate': '0 0', 'scale': '1', 'offset': 0},
          {'translate': '0 0', 'scale': '1.12 0.88', 'offset': 0.04, 'easing': 'cubic-bezier(.2,.7,.3,1)'},
          {'translate': '0 -14px', 'scale': '0.92 1.1', 'offset': 0.1, 'easing': 'cubic-bezier(.3,0,.7,1)'},
          {'translate': '0 -18px', 'scale': '1 1', 'offset': 0.13, 'easing': 'cubic-bezier(.6,0,.8,.4)'},
          {'translate': '0 0', 'scale': '1.16 0.84', 'offset': 0.19, 'easing': 'cubic-bezier(.2,.7,.3,1)'},
          {'translate': '0 -5px', 'scale': '0.97 1.03', 'offset': 0.24, 'easing': 'cubic-bezier(.6,0,.8,.4)'},
          {'translate': '0 0', 'scale': '1.04 0.96', 'offset': 0.28},
          {'translate': '0 0', 'scale': '1', 'offset': 0.31},
          {'translate': '0 0', 'scale': '1', 'offset': 1},
        ], 5000),
        _loop('shadow', [
          {'scale': '1', 'opacity': 0.35, 'offset': 0},
          {'scale': '1.12 1', 'opacity': 0.4, 'offset': 0.04},
          {'scale': '0.55 0.7', 'opacity': 0.14, 'offset': 0.13},
          {'scale': '1.2 1', 'opacity': 0.42, 'offset': 0.19},
          {'scale': '0.9 0.9', 'opacity': 0.3, 'offset': 0.24},
          {'scale': '1', 'opacity': 0.35, 'offset': 0.31},
          {'scale': '1', 'opacity': 0.35, 'offset': 1},
        ], 5000),
      ];
    case 'wave':
      return [
        _loop('self', [
          {'translate': '0 0', 'offset': 0, 'easing': e},
          {'translate': '0 -6px', 'offset': 0.08, 'easing': e},
          {'translate': '0 0', 'offset': 0.17, 'easing': e},
          {'translate': '0 -2px', 'offset': 0.23, 'easing': e},
          {'translate': '0 0', 'offset': 0.3},
          {'translate': '0 0', 'offset': 1},
        ], 6000),
        _loop('hand', [
          {'rotate': '0deg', 'offset': 0, 'easing': e},
          {'rotate': '16deg', 'offset': 0.05, 'easing': e},
          {'rotate': '-10deg', 'offset': 0.1, 'easing': e},
          {'rotate': '16deg', 'offset': 0.15, 'easing': e},
          {'rotate': '-6deg', 'offset': 0.2, 'easing': e},
          {'rotate': '10deg', 'offset': 0.25, 'easing': e},
          {'rotate': '0deg', 'offset': 0.3},
          {'rotate': '0deg', 'offset': 1},
        ], 6000),
      ];
    case 'float':
      return [
        _loop('self', [
          {'translate': '0 0', 'offset': 0, 'easing': e},
          {'translate': '0 -5px', 'offset': 0.5, 'easing': e},
          {'translate': '0 0', 'offset': 1},
        ], 4000),
      ];
    case 'shine':
      return [
        _loop('shine', [
          {'translate': '-160% 0', 'offset': 0},
          {'translate': '-160% 0', 'offset': 0.02, 'easing': 'cubic-bezier(.4,0,.2,1)'},
          {'translate': '260% 0', 'offset': 0.16},
          {'translate': '260% 0', 'offset': 1},
        ], 5000),
        _loop('self', [
          {'scale': '1', 'offset': 0},
          {'scale': '1.04', 'offset': 0.08, 'easing': e},
          {'scale': '1', 'offset': 0.18},
          {'scale': '1', 'offset': 1},
        ], 5000),
      ];
    case 'heartbeat':
      return [
        _loop('self', [
          {'scale': '1', 'offset': 0},
          {'scale': '1.14', 'offset': 0.06, 'easing': e},
          {'scale': '1', 'offset': 0.12, 'easing': e},
          {'scale': '1.08', 'offset': 0.18, 'easing': e},
          {'scale': '1', 'offset': 0.28},
          {'scale': '1', 'offset': 1},
        ], 3000),
      ];
    case 'orbit':
      return [
        _loop('orbit', [
          {'offsetDistance': '0%', 'opacity': 0, 'offset': 0},
          {'offsetDistance': '8%', 'opacity': 1, 'offset': 0.05},
          {'offsetDistance': '192%', 'opacity': 1, 'offset': 0.4, 'easing': 'cubic-bezier(.4,0,.6,1)'},
          {'offsetDistance': '200%', 'opacity': 0, 'offset': 0.45},
          {'offsetDistance': '200%', 'opacity': 0, 'offset': 1},
        ], 5200),
      ];
  }
  return const [];
}

/// The bits each part starts from (CSS): the shadow at .35, the ring and spark hidden, the gloss parked off the button.
const Map<String, Map<String, double>> attentionBase = {
  'shadow': {'o': 0.35},
  'ring': {'o': 0},
  'ring2': {'o': 0},
  'orbit': {'o': 0},
  'shine': {'txp': -160, 'r': 18},
};

/// The orbit's track: a rounded rectangle 7px outside the button (a circle
/// round a round launcher, a stadium round a pill), clockwise from the top
/// edge's left end - the web's orbitPath, as a point at a share of its
/// length (wrapping, so 2 is two laps). Relative to the button's top-left.
({double x, double y}) orbitPoint(double w, double h, double fraction, [double margin = 7]) {
  final x0 = -margin, y0 = -margin;
  final W = w + margin * 2, H = h + margin * 2;
  final R = math.min(W, H) / 2;
  final sw = W - 2 * R, sh = H - 2 * R;
  final arc = (math.pi * R) / 2;
  final total = 2 * sw + 2 * sh + 4 * arc;
  // JavaScript's % keeps the sign; ((f % 1) + 1) % 1 is the share into the lap.
  double jsMod(double a, double b) => a - b * (a / b).truncateToDouble();
  var d = jsMod(jsMod(fraction, 1) + 1, 1) * total;
  if (fraction > 0 && jsMod(fraction, 1) == 0) d = 0;
  ({double x, double y}) corner(double cx, double cy, double from, double len) {
    final a = from + len / R;
    return (x: cx + R * math.cos(a), y: cy + R * math.sin(a));
  }

  // Top edge, top-right corner, right edge, bottom-right, bottom, bottom-left, left, top-left.
  if (d <= sw) return (x: x0 + R + d, y: y0);
  d -= sw;
  if (d <= arc) return corner(x0 + W - R, y0 + R, -math.pi / 2, d);
  d -= arc;
  if (d <= sh) return (x: x0 + W, y: y0 + R + d);
  d -= sh;
  if (d <= arc) return corner(x0 + W - R, y0 + H - R, 0, d);
  d -= arc;
  if (d <= sw) return (x: x0 + W - R - d, y: y0 + H);
  d -= sw;
  if (d <= arc) return corner(x0 + R, y0 + H - R, math.pi / 2, d);
  d -= arc;
  if (d <= sh) return (x: x0, y: y0 + H - R - d);
  d -= sh;
  return corner(x0 + R, y0 + R, math.pi, d);
}

/// The waving hand: the web's sticker, unless the card's own text has one.
const wavingHand = '\u{1F44B}';
