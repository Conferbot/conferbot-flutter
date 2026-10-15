import 'dart:convert';
import 'dart:io';

import 'package:conferbot_flutter/src/core/customization/launcher_icons.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paces idle moments like the web', () {
    expect(LauncherMotion.nextIdleDelay('subtle', 0), LauncherMotion.firstIdleMs);
    expect(LauncherMotion.nextIdleDelay('subtle', 1), 30000);
    expect(LauncherMotion.nextIdleDelay('subtle', 4), isNull);
    expect(LauncherMotion.nextIdleDelay('lively', 3, () => 0.5), 24000);
    expect(LauncherMotion.nextIdleDelay('lively', 10), isNull);
    expect(LauncherMotion.nextIdleDelay('off', 0), isNull);
  });

  test('solves CSS cubic-bezier, overshoot included', () {
    expect(LauncherMotion.cubicBezier(const [0.42, 0, 0.58, 1], 0.5), closeTo(0.5, 1e-3));
    expect(LauncherMotion.cubicBezier(const [0, 0, 1, 1], 0.3), closeTo(0.3, 1e-3));
    expect(LauncherMotion.cubicBezier(const [0.2, 1.4, 0.4, 1], 0.5), greaterThan(1));
  });

  test('ripples two rings, then stops', () {
    expect(LauncherMotion.rippleRing(2.0, 0), isNull);
    final a = LauncherMotion.rippleRing(3.4, 0)!;
    expect(a.scale, greaterThan(1));
    expect(a.opacity, lessThan(0.45));
    expect(LauncherMotion.rippleRing(2.7, 1), isNull);
    expect(LauncherMotion.rippleRing(2.5 + 1.8 * 3 + 0.1, 0), isNull);
  });

  test('rests after the moment', () {
    expect(LauncherMotion.iconFrame(LauncherIcons.byId('WidgetBubbleIcon40'), 'idle', 9).every((f) => f == null), isTrue);
  });

  // The same frames as the RN SDK's evaluator, which is checked against Chrome's own animation of the web icons.
  test('matches the verified evaluator', () {
    final cases = jsonDecode(File('test/fixtures/launcher_motion_golden.json').readAsStringSync()) as List;
    for (final c in cases.cast<Map<String, dynamic>>()) {
      final id = c['id'] as String;
      final frame = LauncherMotion.iconFrame(LauncherIcons.byId(id), c['st'] as String, (c['t'] as num).toDouble());
      final ops = c['ops'] as List;
      expect(frame.length, ops.length, reason: id);
      for (var i = 0; i < ops.length; i++) {
        final want = ops[i] as Map<String, dynamic>?;
        final got = frame[i];
        if (want == null) {
          expect(got, isNull, reason: '$id op $i');
          continue;
        }
        expect(got, isNotNull, reason: '$id op $i');
        final m = (want['m'] as List).cast<num>();
        for (var k = 0; k < 6; k++) {
          expect(got!.m[k], closeTo(m[k].toDouble(), 1e-3), reason: '$id op $i m[$k]');
        }
        final layers = (want['layers'] as List).cast<List>();
        expect(got!.layers.length, layers.length, reason: '$id op $i layers');
        for (var k = 0; k < layers.length; k++) {
          expect(got.layers[k].$1, layers[k][0]);
          expect(got.layers[k].$2, closeTo((layers[k][1] as num).toDouble(), 1e-3));
        }
      }
    }
  });
}
