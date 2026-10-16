// The launcher entrance, attention and idle call against Chrome: the React
// Native SDK's golden (scripts/parity/launcherfx/golden.json, copied by
// tool/sync_launcherfx_golden.sh) holds Chrome's own values of every track,
// paused at each sample. Each sample keeps only the channels away from rest;
// iterations -1 is infinity.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:conferbot_flutter/src/core/customization/keyframes.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_attention.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_entrance.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_idle_call.dart';
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
      for (final s in (c['samples'] as List).cast<Map<String, dynamic>>()) {
        final want = FxValues.rest(_map(s['v'])..removeWhere((k, _) => k == 'px' || k == 'py'));
        final t = (s['t'] as num).toDouble();
        final got = evaluate(tracks, t, base);
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
    expect(_cases.length, 447);
    expect(samples, 19275);
    for (final ch in ['tx', 'ty', 'txp', 'typ', 'r', 'rx', 'ry', 'od', 'dash', 'clip']) {
      expect(max[ch], lessThan(0.01), reason: ch);
    }
    for (final ch in ['sx', 'sy', 'o']) {
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
    // Every case in the golden is one this SDK builds.
    expect(checked, _cases.length);
  });
}
