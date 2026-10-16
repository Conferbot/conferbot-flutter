// The launcher entrance, attention and idle call, and the mascot (its moods,
// the typing mascot and pencil, the greeting card's moves and its figure's
// gestures) against Chrome: the React Native SDK's golden
// (scripts/parity/launcherfx/golden.json, copied by
// tool/sync_launcherfx_golden.sh) holds Chrome's own values of every track,
// paused at each sample. Each sample keeps only the channels away from rest;
// iterations -1 is infinity. A transform list (`matrix`) is read back as its
// CSS matrix (ma..mf) and compared as one, with the opacity and the dash.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:conferbot_flutter/src/core/customization/keyframes.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_attention.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_entrance.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_idle_call.dart';
import 'package:conferbot_flutter/src/core/customization/mascot_moods.dart';
import 'package:conferbot_flutter/src/core/customization/mascot_motion.dart';
import 'package:flutter_test/flutter_test.dart';

final _golden = jsonDecode(File('test/fixtures/launcherfx_golden.json').readAsStringSync()) as Map<String, dynamic>;
List<Map<String, dynamic>> get _cases => (_golden['cases'] as List).cast<Map<String, dynamic>>();

Map<String, double> _map(Object? m) => {for (final e in ((m as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble()};

/// Keyframes and options in one comparable form: options with their defaults filled in.
Object? _norm(Object? tracks) => (tracks as List).map((t) {
      final j = t as Map;
      final o = j['options'] as Map;
      return {
        if (j['part'] != null) 'part': j['part'],
        'keyframes': (j['keyframes'] as List).map((k) => {for (final e in (k as Map).entries) if (e.value != null) e.key: e.value}).toList(),
        'options': {
          'duration': o['duration'],
          'delay': o['delay'] ?? 0,
          'iterations': o['iterations'] ?? 1,
          'easing': o['easing'] ?? 'linear',
          'fill': o['fill'] ?? 'none',
        },
      };
    }).toList();

const _m = ['ma', 'mb', 'mc', 'md', 'me', 'mf'];

final _number = RegExp(r'-?\d+(?:\.\d+)?(?:e[-+]?\d+)?');

/// Deep equality, numbers (also inside strings such as "12.5px 3px") within
/// a hair: Dart's sin / cos can differ from V8's in the last bit.
bool _same(Object? a, Object? b) {
  if (a is num && b is num) return (a - b).abs() <= 1e-9 * math.max(1, a.abs());
  if (a is String && b is String) {
    if (a.replaceAll(_number, '#') != b.replaceAll(_number, '#')) return false;
    final x = _number.allMatches(a).map((m) => double.parse(m.group(0)!)).toList();
    final y = _number.allMatches(b).map((m) => double.parse(m.group(0)!)).toList();
    return _same(x, y);
  }
  if (a is List && b is List) return a.length == b.length && List.generate(a.length, (i) => _same(a[i], b[i])).every((x) => x);
  if (a is Map && b is Map) return a.length == b.length && a.keys.every((k) => b.containsKey(k) && _same(a[k], b[k]));
  return a == b;
}

void main() {
  test('evaluates every golden case within a hair of Chrome', () {
    final max = <String, double>{};
    var samples = 0;
    for (final c in _cases) {
      final tracks = (c['tracks'] as List).map((t) => Track.fromJson(t as Map<String, dynamic>)).toList();
      final base = _map(c['base']);
      final box = c['box'] as Map<String, dynamic>;
      final matrix = c['matrix'] == true;
      final order = transformOrder(tracks.first);
      for (final s in (c['samples'] as List).cast<Map<String, dynamic>>()) {
        final raw = _map(s['v']);
        final t = (s['t'] as num).toDouble();
        final got = evaluate(tracks, t, base);
        if (matrix) {
          // Chrome's matrix against the list's own, in its order.
          final m = transformMatrix(got, order);
          for (var i = 0; i < 6; i++) {
            final ch = _m[i];
            final want = raw[ch] ?? (i == 0 || i == 3 ? 1.0 : 0.0);
            final k = i < 4 ? 'matrix' : 'matrix px';
            max[k] = math.max(max[k] ?? 0, (m[i] - want).abs());
          }
          for (final ch in ['o', 'dash']) {
            final want = raw[ch] ?? (ch == 'o' ? 1.0 : 0.0);
            max[ch] = math.max(max[ch] ?? 0, (got[ch] - want).abs());
          }
          samples += 1;
          continue;
        }
        final want = FxValues.rest(raw..removeWhere((k, _) => k == 'px' || k == 'py'));
        for (final ch in fxChannels) {
          max[ch] = math.max(max[ch] ?? 0, (got[ch] - want[ch]).abs());
        }
        final v = s['v'] as Map<String, dynamic>;
        if (c['path'] != null && v['px'] != null) {
          final x = (box['x'] as num).toDouble(), y = (box['y'] as num).toDouble();
          final w = (box['w'] as num).toDouble(), h = (box['h'] as num).toDouble();
          final f = spriteFrame(FxSprite(x: x, y: y, w: w, h: h, tracks: tracks, path: c['path'] as String), t, got);
          final ex = x + w / 2 + f.tx - (v['px'] as num), ey = y + h / 2 + f.ty - (v['py'] as num);
          max['path'] = math.max(max['path'] ?? 0, math.sqrt(ex * ex + ey * ey));
        }
        samples += 1;
      }
    }
    // ignore: avoid_print
    print('launcherfx golden: ${_cases.length} cases, $samples samples; max error ${max.map((k, v) => MapEntry(k, double.parse(v.toStringAsFixed(5))))}');
    expect(_cases.length, 499);
    expect(_cases.where((c) => (c['src'] as String).startsWith('mascot:')).length, 52);
    expect(samples, 22123);
    for (final ch in ['tx', 'ty', 'txp', 'typ', 'r', 'rx', 'ry', 'od', 'dash', 'clip', 'matrix px']) {
      expect(max[ch], lessThan(0.01), reason: ch);
    }
    for (final ch in ['sx', 'sy', 'o', 'matrix']) {
      expect(max[ch], lessThan(0.001), reason: ch);
    }
    // Chrome lays `left` out on a 1/64 px grid; the motion path is flattened.
    expect(max['left'], lessThan(0.05));
    expect(max['path'], lessThan(0.6));
  });

  test('builds the same tracks the golden was sampled from', () {
    final want = {for (final c in _cases) c['src'] as String: c['tracks']};
    final g = (_golden['geometry'] as Map)['right'] as Map<String, dynamic>;
    final seed = _golden['seed'] as int;
    var checked = 0;
    void check(String src, List<Track> tracks) {
      expect(want.containsKey(src), isTrue, reason: src);
      final ours = _norm(jsonDecode(jsonEncode(tracks.map((t) => t.toJson()).toList())));
      expect(_same(ours, _norm(want[src])), isTrue, reason: '$src\nours:   ${jsonEncode(ours)}\nchrome: ${jsonEncode(_norm(want[src]))}');
      checked += 1;
    }

    for (final m in launcherAttentions) {
      if (m == 'off') continue;
      for (final t in attentionTracks(m)) {
        check('attention:$m:${t.part}', [t]);
      }
    }
    for (final t in attentionTracks('pulse', true)) {
      check('attention:pulse-clipped:${t.part}', [t]);
    }
    for (final t in attentionTracks('pulse', false, true)) {
      check('attention:pulse-wide:${t.part}', [t]);
    }
    for (final (label, pos) in [('right', 'right'), ('left', 'left')]) {
      for (final card in [false, true]) {
        for (final m in launcherIdleCalls) {
          if (m == 'off') continue;
          if ((label == 'left' || card) && m != 'peek' && m != 'knock') continue;
          final p = idleCallPerformance(m, idleCallGeometry((g['width'] as num).toDouble(), (g['height'] as num).toDouble(), pos, card));
          final tag = 'idle:$m@$label${card ? '+card' : ''}';
          check('$tag:self', p.self);
          p.parts.forEach((part, tracks) => check('$tag:$part', tracks));
          for (var i = 0; i < p.launcher.length; i++) {
            check('$tag:launcher$i', [p.launcher[i]]);
          }
          for (var i = 0; i < p.ripples.length; i++) {
            check('$tag:ripple$i', [p.ripples[i].track]);
          }
          check('$tag:bubble', [p.bubble]);
        }
      }
    }
    for (final label in ['right', 'left']) {
      final geo = (_golden['geometry'] as Map)[label] as Map<String, dynamic>;
      final stage = entranceStage(
        width: (geo['width'] as num).toDouble(),
        height: (geo['height'] as num).toDouble(),
        position: geo['position'] as String,
        screenWidth: (geo['screenWidth'] as num).toDouble(),
        screenHeight: (geo['screenHeight'] as num).toDouble(),
        side: (geo['side'] as num).toDouble(),
        bottom: (geo['bottom'] as num).toDouble(),
        accent: geo['accent'] as String,
      );
      for (final m in launcherEntrances) {
        if (m == 'classic') continue;
        if (label == 'left' && !['ufo', 'confetti', 'magic', 'plane', 'meteor'].contains(m)) continue;
        final p = entrancePlan(m, stage, seed)!;
        check('entrance:$m@$label:arrive', [p.arrive.withDelay(p.revealAt)]);
        void walk(FxSprite sp, String at) {
          if (sp.tracks.isNotEmpty) check('entrance:$m@$label:$at', sp.tracks);
          for (var i = 0; i < sp.children.length; i++) {
            walk(sp.children[i], '$at.$i');
          }
        }

        for (var i = 0; i < p.sprites.length; i++) {
          walk(p.sprites[i], 's$i');
        }
      }
    }
    check('entrance:settle', [settleReveal]);
    // The mascot: its moods, the typing mascot and pencil, the card's moves, the figure's gestures.
    for (final (mood, arm, waveCount) in [('wave', 'wave', 2.0), ('wave', 'down', double.infinity), ('think', null, double.infinity), ('happy', 'down', double.infinity)]) {
      final plan = moodPlan(mood, arm: arm, waveCount: waveCount);
      plan.parts.forEach((part, tracks) {
        if (part == 'lid' && mood != 'wave') return;
        check('mascot:mood-$mood${arm != null ? '@$arm' : ''}:$part', tracks);
      });
    }
    check('mascot:typing:sway', [TypingMascotSpec.sway]);
    check('mascot:typing:blink', [TypingMascotSpec.blink]);
    check('mascot:typing:glance', [TypingMascotSpec.glance]);
    for (var i = 0; i < TypingMascotSpec.dots.length; i++) {
      check('mascot:typing:dot$i', [TypingMascotSpec.dots[i].track]);
    }
    check('mascot:pencil:line', [TypingPencilSpec.write]);
    check('mascot:pencil:pencil', [TypingPencilSpec.pencil]);
    check('mascot:card:spring', [cardEnterTrack('lively', 'card')!]);
    check('mascot:card:in', [cardEnterTrack('subtle', 'card')!]);
    check('mascot:card:collapse', [cardLeaveTrack('lively', 'open')!]);
    check('mascot:card:out', [cardLeaveTrack('off', 'close')!]);
    check('mascot:card:ping-dot', [Ping.dot]);
    check('mascot:card:ping-ring', [Ping.ring]);
    check('mascot:card:word3', [wordFade('Hi there, how can we help you today?')!.tracks[3]]);
    for (final amp in [1.0, 0.75, 0.55]) {
      final a = jsNum(amp);
      for (final g in ['pop', 'rise', 'fadeIn', 'wave', 'tilt', 'nod', 'hop', 'handoff', 'bow']) {
        if (amp != 1 && (g == 'rise' || g == 'fadeIn')) continue;
        check('mascot:gesture:$g@$a', [gestureTrack(g, g == 'fadeIn' ? 0 : amp, g == 'pop' ? 140 : g == 'rise' ? 80 : 0, g == 'handoff' ? (-40, 60) : null)]);
      }
      check('mascot:gesture:talk@$a', [talkTrack(amp)]);
    }
    check('mascot:gesture:breath', [breathTrack]);
    // Every case in the golden is one this SDK builds.
    expect(checked, _cases.length);
  });
}
