// The rules round the launcher's entrance, attention loop and idle call
// (as the React Native SDK's hooks keep them), on a fake clock.
import 'package:conferbot_flutter/src/core/customization/launcher_entrance.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_idle_call.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_motion.dart';
import 'package:conferbot_flutter/src/widgets/launcher_fx_controllers.dart';
import 'package:flutter_test/flutter_test.dart';

class _Timer implements FxTimer {
  final int at;
  final void Function() fn;
  bool cancelled = false;
  _Timer(this.at, this.fn);
  @override
  void cancel() => cancelled = true;
}

class FakeClock implements FxScheduler {
  int t = 1000000000000;
  final List<_Timer> _timers = [];
  @override
  int now() => t;
  @override
  FxTimer after(int ms, void Function() fn) {
    final x = _Timer(t + ms, fn);
    _timers.add(x);
    return x;
  }

  /// Moves the clock on, firing the timers due in order.
  void advance(int ms) {
    final end = t + ms;
    while (true) {
      final due = _timers.where((x) => !x.cancelled && x.at <= end).toList()..sort((a, b) => a.at.compareTo(b.at));
      if (due.isEmpty) break;
      final x = due.first;
      _timers.remove(x);
      t = x.at;
      x.fn();
    }
    t = end;
  }
}

class MemoryRest implements IdleCallRestStore {
  final Map<String, int> until = {};
  @override
  Future<int> read(String botId) async => until[botId] ?? 0;
  @override
  void write(String botId, int at) => until[botId] = at;
}

EntranceStage _stage() =>
    entranceStage(width: 50, height: 50, position: 'right', screenWidth: 390, screenHeight: 844, side: 16, bottom: 16, accent: '#4f46e5');

void main() {
  setUp(LauncherFxSession.reset);

  group('entrance', () {
    test('holds the launcher, plays, keeps the card hidden until it lands, then fades it up 150ms later', () {
      final clock = FakeClock();
      final c = LauncherEntranceController(clock: clock);
      c.decide(mode: 'rocket', botId: 'b1', reduced: false, chatOpen: false);
      expect(c.phase, 'hold');
      expect(c.busy, isTrue);
      expect(c.lookAt(0)!.o, 0);
      expect(c.lookAt(0)!.greetingO, 0);
      c.laidOut(_stage);
      clock.advance(entranceStartMs);
      expect(c.phase, 'play');
      final tl = entranceTimeline(c.plan!);
      // Before the reveal the launcher is still hidden; the card stays hidden until the landing settles.
      expect(c.lookAt(tl.landAt - 1)!.o, 0);
      expect(c.lookAt(tl.landedAt)!.greetingO, 0);
      expect(c.lookAt(tl.settleAt + 450)!.greetingO, greaterThan(0.5));
      clock.advance(tl.settleAt.ceil());
      expect(c.busy, isFalse);
      clock.advance((tl.endAt - tl.settleAt).ceil() + 1);
      expect(c.phase, 'done');
      expect(c.lookAt(0), isNull);
    });

    test('plays once per app session per bot and entrance', () {
      final clock = FakeClock();
      final a = LauncherEntranceController(clock: clock)..decide(mode: 'drop', botId: 'b1', reduced: false, chatOpen: false);
      a.laidOut(_stage);
      clock.advance(5000);
      expect(LauncherFxSession.entrancePlayed['b1'], 'drop');
      final again = LauncherEntranceController(clock: clock)..decide(mode: 'drop', botId: 'b1', reduced: false, chatOpen: false);
      expect(again.phase, 'none');
      final other = LauncherEntranceController(clock: clock)..decide(mode: 'drop', botId: 'b2', reduced: false, chatOpen: false);
      expect(other.phase, 'hold');
      final changed = LauncherEntranceController(clock: clock)..decide(mode: 'coin', botId: 'b1', reduced: false, chatOpen: false);
      expect(changed.phase, 'hold');
    });

    test('never over an open chat, with reduced motion, or for classic; opening the chat ends it', () {
      final clock = FakeClock();
      expect((LauncherEntranceController(clock: clock)..decide(mode: 'ufo', botId: 'x', reduced: false, chatOpen: true)).phase, 'none');
      expect((LauncherEntranceController(clock: clock)..decide(mode: 'ufo', botId: 'x', reduced: true, chatOpen: false)).phase, 'none');
      expect((LauncherEntranceController(clock: clock)..decide(mode: 'classic', botId: 'x', reduced: false, chatOpen: false)).phase, 'none');
      final c = LauncherEntranceController(clock: clock)..decide(mode: 'ufo', botId: 'x', reduced: false, chatOpen: false);
      c.laidOut(_stage);
      clock.advance(200);
      c.chatOpened();
      expect(c.phase, 'done');
      expect(c.busy, isFalse);
    });

    test('the launcher simply appears if it is never laid out', () {
      final clock = FakeClock();
      final c = LauncherEntranceController(clock: clock)..decide(mode: 'egg', botId: 'x', reduced: false, chatOpen: false);
      clock.advance(LauncherEntranceController.revealFailsafeMs);
      expect(c.phase, 'done');
    });
  });

  group('attention', () {
    void feed(LauncherAttentionController c,
            {String mode = 'heartbeat', bool chatOpen = false, bool card = false, bool moment = false, bool busy = false, bool size = true, bool reduced = false}) =>
        c.update(mode: mode, enabled: true, reduced: reduced, chatOpen: chatOpen, cardShown: card, moment: moment, entranceBusy: busy, hasSize: size, wide: false);

    test('waits for the entrance, then runs its loop from the start', () {
      final clock = FakeClock();
      final c = LauncherAttentionController(clock: clock);
      feed(c, busy: true);
      expect(c.onLauncher, isTrue);
      expect(c.running, isFalse);
      clock.advance(3000);
      feed(c);
      expect(c.running, isTrue);
      expect(c.elapsed, 0);
      clock.advance(1600);
      expect(c.elapsed, 1600);
      // Laps after the 1.5s intro.
      clock.advance(3000);
      expect(c.elapsed, closeTo(1600, 1e-9));
    });

    test('pauses for a launcher moment and resumes where it was', () {
      final clock = FakeClock();
      final c = LauncherAttentionController(clock: clock);
      feed(c);
      clock.advance(500);
      feed(c, moment: true);
      clock.advance(2600);
      expect(c.elapsed, 500);
      feed(c);
      clock.advance(100);
      expect(c.elapsed, 600);
    });

    test('over once the chat opens; not started within 30 minutes of an opening', () {
      final clock = FakeClock();
      final c = LauncherAttentionController(clock: clock);
      feed(c);
      feed(c, chatOpen: true);
      expect(c.running, isFalse);
      feed(c);
      expect(c.running, isFalse);
      LauncherFxSession.openedAt = clock.now();
      clock.advance(LauncherMotion.openedRestMs - 1);
      final d = LauncherAttentionController(clock: clock);
      feed(d);
      expect(d.active, isFalse);
      clock.advance(2);
      final e = LauncherAttentionController(clock: clock);
      feed(e);
      expect(e.running, isTrue);
    });

    test('a card mode runs only while the card shows; nothing with reduced motion', () {
      final clock = FakeClock();
      final c = LauncherAttentionController(clock: clock);
      feed(c, mode: 'wave');
      expect(c.target, 'greeting');
      expect(c.onLauncher, isFalse);
      expect(c.running, isFalse);
      feed(c, mode: 'wave', card: true);
      expect(c.running, isTrue);
      expect(c.has('hand'), isTrue);
      final r = LauncherAttentionController(clock: clock);
      feed(r, reduced: true);
      expect(r.active, isFalse);
    });
  });

  group('idle call', () {
    Future<(LauncherIdleCallController, FakeClock, MemoryRest)> started({String mode = 'knock', int delay = 12, String bot = 'b1', FakeClock? clock, MemoryRest? rest}) async {
      final k = clock ?? FakeClock();
      final r = rest ?? MemoryRest();
      final c = LauncherIdleCallController(clock: k, store: r)
        ..width = 50
        ..height = 50;
      await c.start(mode: mode, delay: delay, botId: bot, reduced: false);
      return (c, k, r);
    }

    test('calls after the delay, and is over after its performance', () async {
      final (c, clock, _) = await started();
      clock.advance(11999);
      expect(c.perf, isNull);
      clock.advance(1);
      expect(c.perf, isNotNull);
      expect(c.perf!.front, isTrue);
      clock.advance(c.perf!.total.ceil() + 80);
      expect(c.perf, isNull);
    });

    test('waits 4s at a time while blocked: chat open, background, keyboard, entrance, greeting up under 15s', () async {
      final (c, clock, _) = await started();
      c.keyboard = true;
      clock.advance(12000);
      expect(c.perf, isNull);
      c.keyboard = false;
      c.appActive = false;
      clock.advance(idleCallRetryMs);
      expect(c.perf, isNull);
      c.appActive = true;
      c.entranceBusy = true;
      clock.advance(idleCallRetryMs);
      expect(c.perf, isNull);
      c.entranceBusy = false;
      c.cardShown = true;
      clock.advance(idleCallRetryMs);
      expect(c.perf, isNull);
      // The card has had 15s alone: the mascot calls, without a bubble.
      clock.advance(12000);
      expect(c.perf, isNotNull);
      expect(c.perf!.talks, isFalse);
    });

    test('twice per session, 3 minutes apart, then 3 days of rest', () async {
      final clock = FakeClock();
      final rest = MemoryRest();
      final (a, _, _) = await started(clock: clock, rest: rest);
      clock.advance(12000);
      expect(a.perf, isNotNull);
      expect(rest.until['b1'], isNull);
      // A second screen this session, too soon: nothing.
      final (b, _, _) = await started(clock: clock, rest: rest);
      clock.advance(60000);
      expect(b.perf, isNull);
      clock.advance(minGapMs);
      final (c, _, _) = await started(clock: clock, rest: rest);
      clock.advance(12000);
      expect(c.perf, isNotNull);
      expect(rest.until['b1'], greaterThan(clock.now() + restMs - 20000));
      // A third: the session's two are spent.
      clock.advance(minGapMs * 2);
      final (d, _, _) = await started(clock: clock, rest: rest);
      clock.advance(12000);
      expect(d.perf, isNull);
      // Next session (the rest stays in storage).
      LauncherFxSession.reset();
      final (e, _, _) = await started(clock: clock, rest: rest);
      clock.advance(12000);
      expect(e.perf, isNull);
      clock.advance(restMs);
      LauncherFxSession.reset();
      final (f, _, _) = await started(clock: clock, rest: rest);
      clock.advance(12000);
      expect(f.perf, isNotNull);
    });

    test('opening the chat ends the call and rests 3 days; closing the greeting stops calls for the session', () async {
      final (c, clock, rest) = await started();
      clock.advance(12000);
      c.chatOpened();
      expect(c.perf, isNull);
      expect(rest.until['b1'], clock.now() + restMs);
      final (g, clock2, _) = await started(bot: 'b2');
      g.greetingClosed();
      clock2.advance(60000);
      expect(g.perf, isNull);
      expect(LauncherFxSession.visits['b2']!.quiet, isTrue);
    });

    test('nothing for off or with reduced motion, nor within 30 minutes of an opening', () async {
      final (off, k1, _) = await started(mode: 'off');
      k1.advance(60000);
      expect(off.perf, isNull);
      final clock = FakeClock();
      final reduced = LauncherIdleCallController(clock: clock, store: MemoryRest())
        ..width = 50
        ..height = 50;
      await reduced.start(mode: 'wave', delay: 5, botId: 'b3', reduced: true);
      clock.advance(60000);
      expect(reduced.perf, isNull);
      LauncherFxSession.openedAt = clock.now();
      final (opened, _, _) = await started(clock: clock, bot: 'b4');
      clock.advance(60000);
      expect(opened.perf, isNull);
    });
  });
}
