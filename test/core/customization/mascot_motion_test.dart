// The mascot's moods, the typing mascot, the greeting card's figure (the
// web's director, on a fake clock) and the card's own moves, and the mascot
// settings resolved. Ported from the React Native SDK's
// __tests__/core/mascot.test.ts.
import 'package:conferbot_flutter/src/core/customization/customizations.dart';
import 'package:conferbot_flutter/src/core/customization/keyframes.dart';
import 'package:conferbot_flutter/src/core/customization/launcher.dart';
import 'package:conferbot_flutter/src/core/customization/mascot_art.dart';
import 'package:conferbot_flutter/src/core/customization/mascot_moods.dart';
import 'package:conferbot_flutter/src/core/customization/mascot_motion.dart';
import 'package:conferbot_flutter/src/core/home/home.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock implements MascotTimers {
  int t = 0;
  int _next = 1;
  final Map<int, (int, void Function())> queue = {};

  @override
  Object set(void Function() fn, int ms) {
    final id = _next++;
    queue[id] = (t + ms, fn);
    return id;
  }

  @override
  void clear(Object id) => queue.remove(id);

  int pending() => queue.length;

  void advance(int ms) {
    final end = t + ms;
    for (;;) {
      int? id;
      var at = 1 << 62;
      queue.forEach((k, v) {
        if (v.$1 <= end && v.$1 < at) {
          at = v.$1;
          id = k;
        }
      });
      if (id == null) break;
      final fn = queue.remove(id)!.$2;
      t = at;
      fn();
    }
    t = end;
  }
}

class _Stage implements MascotStage {
  final List<List<Object?>> log = [];
  @override
  void play(String gesture, double amp, [double delay = 0]) => log.add(['play:$gesture', amp, delay]);
  @override
  void breathe(bool on) => log.add([on ? 'breathe' : 'exhale']);
  @override
  void talk(bool on, double amp) => log.add([on ? 'talk' : 'quiet', amp]);
  @override
  void lean(double x, double amp) => log.add(['lean', x, amp]);
  @override
  void ping(bool on) => log.add([on ? 'ping' : 'ping-off']);
  @override
  void words() => log.add(['words']);
  @override
  void reset() => log.add(['reset']);
  List<String> get names => log.map((e) => e[0] as String).toList();
}

(MascotDirector, _Clock, _Stage) _make({String mode = 'lively', bool Function()? reduced, bool Function()? alive}) {
  final c = _Clock();
  final s = _Stage();
  final d = MascotDirector(mode: mode, stage: s, timers: c, now: () => c.t, random: () => 0.5, reduced: reduced, alive: alive);
  return (d, c, s);
}

const _idleGap = idleGapMin + idleGapSpread ~/ 2;

void main() {
  group('the moods (art3d MASCOT_ANIM_CSS)', () {
    test('blinks always, and adds the mood\'s own moves', () {
      expect(moodPlan('idle').parts.keys, ['lid']);
      expect(moodPlan('wave', arm: 'wave').parts.keys.toList()..sort(), ['arm', 'lid']);
      expect(moodPlan('think').parts.keys.toList()..sort(), ['body', 'brow', 'lid', 'look']);
      expect(moodPlan('happy', arm: 'down').parts.keys.toList()..sort(), ['arm', 'body', 'lid', 'shadow']);
      expect(moodPlan('happy').grin, isTrue);
      // The bust (launcher, typing) has no arm.
      expect(moodPlan('happy', bust: true).parts['arm'], isNull);
    });

    test('lifts a resting arm before it waves, and waves a set number of times', () {
      final up = moodPlan('wave', arm: 'down').parts['arm']![0];
      expect(up.options.duration, 3200);
      expect(evaluate([up], 3200 * 0.24).r, closeTo(-132, 1e-4));
      final two = moodPlan('wave', arm: 'wave', waveCount: 2);
      expect(tracksEnd(two.parts['arm']!), 5600);
      // The loop starts on a whole blink after the two waves.
      expect(two.settle, 6400);
      expect(two.period, 6400);
    });

    test('hops twice when happy, then blinks on', () {
      final p = moodPlan('happy', arm: 'down');
      expect(evaluate(p.parts['body']!, 900 * 0.45).ty, closeTo(-8, 1e-4));
      expect(tracksEnd(p.parts['body']!), 1800);
      expect(transformOrder(p.parts['body']!.first), 'tsr');
    });

    test('loops think as one lap of all its parts', () {
      expect(moodPlan('think').period, 19200);
    });

    test('keeps the smile and nothing else under reduced motion', () {
      final p = moodPlan('happy', reduced: true);
      expect([p.parts, p.grin, p.settle, p.period], [isEmpty, true, 0, 0]);
    });

    test('types: sways about 50% 90%, blinks, glances, three dots 0.2s apart', () {
      expect(TypingMascotSpec.origin, (16.0, 28.8));
      expect(evaluate([TypingMascotSpec.sway], 1200).r, closeTo(4, 1e-6));
      expect(transformOrder(TypingMascotSpec.sway), 'rts');
      expect(TypingMascotSpec.dots.map((d) => d.track.options.delay), [0, 200, 400]);
      expect(TypingMascotSpec.period % 2400, 0);
      expect(TypingMascotSpec.period % 3400, 0);
      expect(mascotKeyframes['cb-typing-blink'], contains('95%'));
      expect(typingLabel('mascot', 'Pip'), 'Pip is typing');
      expect(typingLabel('mascot', ''), 'Typing');
      expect(typingLabel('dots', 'Pip'), 'Typing');
    });

    test('writes the pencil\'s line in 1.5s and fades it at the end', () {
      expect(evaluate([TypingPencilSpec.write], 0, {'dash': 60}).dash, 60);
      expect(evaluate([TypingPencilSpec.write], 1500, {'dash': 60}).dash, closeTo(0, 1e-9));
      expect(evaluate([TypingPencilSpec.write], 1999, {'dash': 60}).o, lessThan(0.01));
      final at = evaluate([TypingPencilSpec.pencil], 1500);
      expect([at.tx, at.ty], [closeTo(36, 1e-9), closeTo(8, 1e-9)]);
    });
  });

  group('the greeting card\'s figure, alive (home/mascotMotion.ts)', () {
    test('is lively unless the owner chose subtle or off', () {
      expect(normalizeMascotMotion(null), 'lively');
      expect(normalizeMascotMotion('wild'), 'lively');
      expect(normalizeMascotMotion('subtle'), 'subtle');
      expect(normalizeMascotMotion('off'), 'off');
    });

    test('lively: words, pop, wave, ping, nod, then a breath', () {
      final (d, c, s) = _make();
      d.show();
      expect(s.names, ['reset', 'words', 'play:pop']);
      expect(s.log[2][2], MascotEntrance.livelyPop);
      c.advance(MascotEntrance.livelyWave);
      expect(s.names.last, 'play:wave');
      c.advance(MascotEntrance.livelyPing - MascotEntrance.livelyWave);
      expect(s.names.last, 'ping');
      c.advance(MascotEntrance.livelyNod - MascotEntrance.livelyPing);
      expect(s.names.last, 'play:nod');
      c.advance(MascotEntrance.livelyIdle - MascotEntrance.livelyNod);
      expect(d.state, 'living');
      expect(s.names, contains('breathe'));
      c.advance(pingMs);
      expect(s.names, contains('ping-off'));
    });

    test('three idle gestures at most, then still for good with no timer left', () {
      final (d, c, s) = _make();
      d.show();
      c.advance(MascotEntrance.livelyIdle);
      for (var i = 0; i < 6; i++) {
        c.advance(_idleGap);
      }
      expect(d.gestures, 3);
      c.advance(settleAfter);
      expect(d.state, 'settled');
      expect(s.names.last, 'exhale');
      expect(c.pending(), 0);
      c.advance(120000);
      expect(d.gestures, 3);
    });

    test('subtle: a rise, the ping, one tilt; no words, no wave', () {
      final (d, c, s) = _make(mode: 'subtle');
      d.show();
      c.advance(MascotEntrance.subtleIdle);
      for (var i = 0; i < 4; i++) {
        c.advance(_idleGap);
      }
      c.advance(settleAfter);
      expect(s.names, containsAll(['play:rise', 'ping', 'play:tilt']));
      expect(s.names, isNot(contains('words')));
      expect(s.names, isNot(contains('play:wave')));
      expect(d.state, 'settled');
    });

    test('reduced motion: a fade, nothing else; off: nothing at all', () {
      final (d, c, s) = _make(reduced: () => true);
      d.show();
      d.hide('open');
      c.advance(60000);
      expect(s.names, ['reset', 'play:fadeIn', 'reset']);
      final (off, oc, os) = _make(mode: 'off');
      off.show();
      oc.advance(60000);
      expect(os.names, ['reset']);
    });

    test('a voice note: talks in place of the wave, then quiet', () {
      final (d, c, s) = _make();
      d.show();
      d.talkFor(3600);
      c.advance(MascotEntrance.livelyWave);
      expect(s.names.last, 'talk');
      c.advance(3600 - MascotEntrance.livelyWave);
      expect(s.names.last, 'quiet');
    });

    test('hands off when the chat opens from the card, bows at the x, nothing more after', () {
      final (open, oc, os) = _make();
      open.show();
      open.hide('open');
      expect(os.names.last, 'play:handoff');
      expect(oc.pending(), 0);
      final (close, _, cs) = _make(mode: 'subtle');
      close.show();
      close.hide('close');
      expect(cs.log.last, ['play:bow', 0.6, 0]);
    });

    test('waits in the background, and gives way to the card leaving', () {
      final (d, c, _) = _make();
      d.show();
      c.advance(MascotEntrance.livelyIdle);
      d.pageHidden(true);
      c.advance(60000);
      expect(d.gestures, 0);
      d.pageHidden(false);
      c.advance(_idleGap);
      expect(d.gestures, 1);
      var alive = true;
      final (gone, gc, _) = _make(alive: () => alive);
      gone.show();
      alive = false;
      gc.advance(MascotEntrance.livelyWave);
      expect(gone.state, 'destroyed');
      expect(gc.pending(), 0);
    });

    test('moves a mascot all the way, a photo and initials less', () {
      expect([figureAmp('mascot'), figureAmp('avatar'), figureAmp('initials'), figureAmp(null)], [1, 0.75, 0.55, 1]);
      expect(ownsText('typewriter') && ownsText('imessage') && !ownsText('card'), isTrue);
    });
  });

  group('the greeting card\'s own moves (polish-home.css)', () {
    test('springs up when lively, comes in as always otherwise; the notification and neon keep theirs', () {
      expect(cardEnterTrack('lively', 'card')!.options.duration, 620);
      expect(cardEnterTrack('subtle', 'card')!.options.duration, 450);
      expect(cardEnterTrack('off', 'note')!.options.duration, 450);
      expect(cardEnterTrack('lively', 'notification'), isNull);
      expect(cardEnterTrack('lively', 'neon'), isNull);
      expect(cardEnterTrack('lively', 'card', true), isNull);
      final spring = cardEnterTrack('lively', 'card')!;
      final a = evaluate([spring], 0), z = evaluate([spring], 620);
      expect([a.o, a.ty, a.sx], [0, 14, 0.94]);
      expect([z.o, z.ty, z.sx], [1, 0, 1]);
    });

    test('collapses toward the launcher when opened from the card, fades when closed', () {
      final open = cardLeaveTrack('lively', 'open')!.options;
      expect([open.duration, open.delay], [240, 40]);
      expect(cardLeaveTrack('off', 'open')!.options.duration, 220);
      expect(cardLeaveTrack('subtle', 'close')!.options.duration, 220);
      expect(cardLeaveTrack('lively', 'open', true), isNull);
    });

    test('fades the words up within a second', () {
      expect(wordFade('Hi'), isNull);
      final f = wordFade('Hi there, how can we help you today?')!;
      expect(f.words, hasLength(8));
      expect(f.step, 55);
      final long = wordFade(List.generate(40, (i) => 'w$i').join(' '))!;
      expect(long.step, 13);
      expect(tracksEnd([long.tracks[39]]), lessThan(1250));
      expect(voicePlayMs(), 3660);
    });

    test('plays each gesture as the web does: the leaving ones hold their end', () {
      expect(gestureTrack('handoff', 1).options.fill, 'forwards');
      final pop = gestureTrack('pop', 1, 140);
      expect([pop.options.delay, pop.options.fill], [140, 'backwards']);
      final v = evaluate([pop], 0);
      expect([v.o, v.sx], [0, 0.3]);
      // A photo's handoff toward the launcher, as Chrome reads it.
      expect(gestureFrames('handoff', 0.75, (-40, 60)).frames[1]['transform'], 'translate(-6px, 5.4px) scale(1.06, 0.955)');
    });
  });

  group('the mascot settings, resolved', () {
    test('reads them into the customizations, the launcher and the home', () {
      final c = <String, dynamic>{'mascotShape': 'owl', 'mascotInGreeting': true, 'mascotMotion': 'subtle', 'mascotLauncherScale': 130, 'widgetIconBgColor': '#123456', 'launcherStyle': 'mascot'};
      final r = Customizations.resolve(c);
      expect(r.mascot.shape, 'owl');
      expect([r.mascotInGreeting, r.mascotMotion, r.mascotLauncherScale, r.mascotAccent], [true, 'subtle', 130, '#123456']);
      final d = Customizations.resolve({});
      expect([d.mascotInGreeting, d.mascotMotion, d.mascotLauncherScale, d.mascotAccent], [false, 'lively', 112, '#4f46e5']);
      final l = Launcher.resolve(c, screenWidth: 390);
      expect(l.style, 'mascot');
      expect([l.mascot.scale, l.mascot.accent, l.mascot.light], [130, '#123456', mixColor('#123456', 14, '#ffffff')]);
      expect(l.mascot.look.shape, 'owl');
      // An uploaded launcher image wins.
      expect(Launcher.resolve({...c, 'widgetIconType': 'Image', 'widgetIconImage': 'https://x.test/a.png'}).style, 'icon');
      final h = homeModel(c: {...c, 'enableInitialPage': true, 'mascotName': 'Hoot'})!;
      expect([h.mascot.look.shape, h.mascot.look.name, h.mascot.accent], ['owl', 'Hoot', '#123456']);
    });
  });
}
