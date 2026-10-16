import 'package:conferbot_flutter/src/core/customization/keyframes.dart';
import 'package:conferbot_flutter/src/core/customization/launcher.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_attention.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_entrance.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_idle_call.dart';
import 'package:conferbot_flutter/src/core/customization/mascot_art.dart';
import 'package:flutter_test/flutter_test.dart';

EntranceStage _stage() =>
    entranceStage(width: 50, height: 50, position: 'right', screenWidth: 390, screenHeight: 844, side: 16, bottom: 16, accent: '#4f46e5');

void main() {
  group('the Web Animations evaluator', () {
    test('spaces missing offsets evenly', () {
      expect(computedOffsets([{}, {}, {'offset': 0.5}, {}, {}]), [0, 0.25, 0.5, 0.75, 1]);
    });

    test('keeps delay, iterations and fill', () {
      const o = TrackOptions(duration: 1000, delay: 500, iterations: 2);
      expect(iterationProgress(o, 100), isNull);
      expect(iterationProgress(const TrackOptions(duration: 1000, delay: 500, iterations: 2, fill: 'backwards'), 100), 0);
      expect(iterationProgress(o, 1750), closeTo(0.25, 1e-6));
      expect(iterationProgress(o, 2600), isNull);
      expect(iterationProgress(const TrackOptions(duration: 1000, delay: 500, iterations: 2, fill: 'forwards'), 9000), 1);
      expect(iterationProgress(const TrackOptions(duration: 1000, iterations: double.infinity), 123456), closeTo(0.456, 1e-6));
    });

    test('lets the later animation win, over the element’s own values', () {
      final a = Track.of([
        {'scale': 1},
        {'scale': 2},
      ], duration: 100, fill: 'forwards');
      final b = Track.of([
        {'scale': 3},
        {'scale': 3},
      ], duration: 100, delay: 50);
      expect(evaluate([a, b], 75).sx, 3);
      expect(evaluate([a, b], 200).sx, 2);
      final v = evaluate([b], 0, {'sx': -1, 'o': 0});
      expect([v.sx, v.o], [-1, 0]);
    });

    test('prints numbers as JavaScript does', () {
      expect(jsNum(1.0), '1');
      expect(jsNum(-0.0), '0');
      expect(jsNum(2.5), '2.5');
      expect(jsNum(-6), '-6');
    });
  });

  group('settings, defaults and rules', () {
    test('defaults to off / classic and normalises junk', () {
      expect(normalizeLauncherEntrance(null), 'classic');
      expect(normalizeLauncherEntrance('rocket'), 'rocket');
      expect(normalizeLauncherAttention('spin'), 'off');
      expect(normalizeLauncherIdleCall('knock'), 'knock');
      expect(normalizeIdleCallDelay(null), 12);
      expect(normalizeIdleCallDelay(1), 5);
      expect(normalizeIdleCallDelay('500'), 120);
      final l = Launcher.resolve({});
      expect([l.entrance, l.attention, l.idleCall, l.idleCallDelay], ['classic', 'off', 'off', 12]);
      final on = Launcher.resolve({'launcherEntrance': 'portal', 'launcherAttention': 'orbit', 'launcherIdleCall': 'tap', 'launcherIdleCallText': '  Need   a hand?  '});
      expect([on.entrance, on.attention, on.idleCall, on.idleCallText], ['portal', 'orbit', 'tap', 'Need a hand?']);
    });

    test('picks the bubble line: the owner’s (24 characters) or the style’s', () {
      expect(idleCallLine('psst', ''), 'Psst!');
      expect(idleCallLine('wave', 'x' * 40), hasLength(24));
      expect(idleCallLine('off', 'hi'), '');
    });

    test('plays an entrance once, never over an open chat or with reduced motion', () {
      expect(shouldPlayEntrance(mode: 'drop', reducedMotion: false, chatOpen: false, played: false), isTrue);
      expect(shouldPlayEntrance(mode: 'classic', reducedMotion: false, chatOpen: false, played: false), isFalse);
      expect(shouldPlayEntrance(mode: 'drop', reducedMotion: false, chatOpen: false, played: true), isFalse);
      expect(shouldPlayEntrance(mode: 'drop', reducedMotion: false, chatOpen: true, played: false), isFalse);
      expect(shouldPlayEntrance(mode: 'drop', reducedMotion: true, chatOpen: false, played: false), isFalse);
    });

    test('lands, then fades the rest up 150ms later for 0.9s', () {
      final p = entrancePlan('rocket', _stage(), 1)!;
      final tl = entranceTimeline(p);
      expect([tl.landAt, tl.landedAt, tl.settleAt, tl.endAt], [1330, 1850, 2000, 2960]);
      final s = evaluate([settleReveal], 0);
      expect([s.o, s.ty], [0, 10]);
      final rest = evaluate([p.arrive], p.arrive.options.duration + 1);
      expect([rest.o, rest.sx, rest.tx], [1, 1, 0]);
    });

    test('paces idle calls: twice a session, 3 minutes apart, then rest', () {
      const t = 1000000;
      expect(callAllowed(const VisitState(), 0, t), isTrue);
      final one = afterCall(const VisitState(), t);
      expect(one.rest, isFalse);
      expect(callAllowed(one.visit, 0, t + 1000), isFalse);
      expect(callAllowed(one.visit, 0, t + minGapMs), isTrue);
      expect(afterCall(one.visit, t + minGapMs).rest, isTrue);
      expect(callAllowed(const VisitState(quiet: true), 0, t), isFalse);
      expect(callAllowed(const VisitState(), t + 1, t), isFalse);
    });

    test('moves the launcher or the card, per mode', () {
      expect(attentionTarget('off'), isNull);
      expect(attentionTarget('float'), 'greeting');
      expect(attentionTarget('heartbeat'), 'launcher');
      // Each loop is one beat then stillness: the last third of a lap is at rest.
      final self = attentionTracks('heartbeat').first;
      final v = evaluate([self], 1500 + 3000 * 0.7);
      expect([v.sx, v.sy], [1, 1]);
      expect(attentionBase['shine'], {'txp': -160, 'r': 18});
    });

    test('runs the orbit round the button, 7px outside it', () {
      final top = orbitPoint(50, 50, 0);
      expect([top.x, top.y], [25, -7]);
      final right = orbitPoint(50, 50, 0.25);
      expect(right.x, closeTo(57, 1e-6));
      expect(right.y, closeTo(25, 1e-6));
      final two = orbitPoint(50, 50, 2);
      expect([two.x, two.y], [25, -7]);
    });

    test('slides the mascot out from behind the launcher, toward the screen', () {
      final right = idleCallPerformance('wave', idleCallGeometry(50, 50, 'right', false));
      expect(right.mascot.size, 60);
      expect(right.front, isFalse);
      expect(right.talks, isTrue);
      final out = evaluate(right.self, right.total / 2, right.mascot.base);
      expect(out.tx, lessThan(0));
      expect(out.o, 1);
      expect(evaluate(right.self, right.total, right.mascot.base).o, 0);
      final tap = idleCallPerformance('tap', idleCallGeometry(50, 50, 'left', true));
      expect(tap.front, isTrue);
      expect(tap.talks, isFalse);
      expect(tap.ripples, hasLength(2));
      expect(mascotPartBase['lid'], {'sy': 0});
    });

    test('draws the blob mascot in layers, its arm in front when it reaches', () {
      expect(mixColor('#000000', 50, '#ffffff'), '#808080');
      expect(mascotLayers('#4f46e5', 'knock').armFront, contains('<svg'));
      expect(mascotLayers('#4f46e5', 'knock').armBack, isNull);
      expect(mascotLayers('#4f46e5', 'wave').armBack, contains('<svg'));
    });

    test('builds every entrance on a stage, and ends it with nothing left on screen', () {
      final stage = _stage();
      expect([stage.unit, stage.inward, stage.left, stage.top], [50, -1, 324, 778]);
      expect(entrancePlan('classic', stage), isNull);
      for (final m in launcherEntrances) {
        if (m == 'classic') continue;
        final p = entrancePlan(m, stage, 7)!;
        expect(p.sprites, isNotEmpty, reason: m);
        final tl = entranceTimeline(p);
        bool shown(FxSprite sp) {
          final f = spriteFrame(sp, tl.endAt);
          return f.o > 0.02 && (sp.svg != null || sp.fill != null) && sp.y + f.ty + sp.h > -stage.top;
        }

        expect(p.sprites.where(shown), isEmpty, reason: m);
      }
    });
  });
}
