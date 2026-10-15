// The connecting wait's signal (lib/src/core/live_chat/handover_waiting.dart),
// the same cases as the RN SDK's __tests__/core/handoverWaiting.test.ts (and
// the web widget's tests/waitingSignal.test.js), on a fake clock.
import 'package:conferbot_flutter/src/core/live_chat/handover_waiting.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock {
  int now = 0;
  int _id = 0;
  final Map<int, ({void Function() fn, int at})> timers = {};

  Object set(void Function() fn, Duration after) {
    timers[++_id] = (fn: fn, at: now + after.inMilliseconds);
    return _id;
  }

  void clear(Object t) => timers.remove(t);

  void tick(int ms) {
    final until = now + ms;
    while (true) {
      final due = timers.entries.where((e) => e.value.at <= until).toList()..sort((a, b) => a.value.at.compareTo(b.value.at));
      if (due.isEmpty) break;
      final next = due.first;
      timers.remove(next.key);
      now = next.value.at;
      next.value.fn();
    }
    now = until;
  }
}

void main() {
  group('ConnectingSignal (web handoverWaiting.ts)', () {
    test('signals after 20s, once', () {
      final c = _Clock();
      var fired = 0;
      final sig = ConnectingSignal(() => fired++, setTimer: c.set, clearTimer: c.clear);
      expect(connectingSignalDelay, const Duration(seconds: 20));
      sig.start();
      sig.start();
      c.tick(19999);
      expect(fired, 0);
      c.tick(1);
      expect(fired, 1);
      expect(sig.pending, isFalse);
      c.tick(60000);
      expect(fired, 1);
    });

    test('a join, nobody available, leaving the queue or the chat ending: no signal', () {
      final c = _Clock();
      var fired = 0;
      final sig = ConnectingSignal(() => fired++, setTimer: c.set, clearTimer: c.clear);
      sig.start();
      c.tick(10000);
      sig.end();
      c.tick(60000);
      expect(fired, 0);
      expect(c.timers, isEmpty);
      sig.start();
      c.tick(20000);
      expect(fired, 1);
    });

    test('due while the chat is closed: held until it opens', () {
      final c = _Clock();
      var fired = 0;
      var open = false;
      final sig = ConnectingSignal(() => fired++, canFire: () => open, setTimer: c.set, clearTimer: c.clear);
      sig.start();
      c.tick(30000);
      expect(fired, 0);
      open = true;
      c.tick(connectingRecheck.inMilliseconds);
      expect(fired, 1);
      open = false;
      sig.start();
      c.tick(25000);
      sig.end();
      open = true;
      c.tick(10000);
      expect(fired, 1);
    });

    test('runs on real timers by default', () async {
      var fired = 0;
      final sig = ConnectingSignal(() => fired++);
      sig.start();
      expect(sig.pending, isTrue);
      sig.end();
      expect(sig.pending, isFalse);
      expect(fired, 0);
    });
  });

  group('signals', () {
    test('names as on the web; details carry no personal data', () {
      expect(WidgetSignals.waitingForHuman, 'cb:waiting-for-human');
      expect(WidgetSignals.humanJoined, 'cb:human-joined');
      expect(WidgetSignals.waitOver, 'cb:wait-over');
      expect(WidgetSignals.waitingDetail({'offline': false, 'reason': 'busy', 'email': 'a@b.co'}),
          {'offline': false, 'reason': 'busy', 'backAt': null, 'emailCaptured': true});
      expect(WidgetSignals.waitingDetail({'reason': 'offline', 'backAt': '2026-10-16T09:00:00Z'}),
          {'offline': false, 'reason': 'offline', 'backAt': '2026-10-16T09:00:00Z', 'emailCaptured': false});
    });

    test('the bus: listeners get the detail, unsubscribe works, a throwing listener is contained', () {
      final bus = WidgetSignalBus();
      final got = <Map<String, dynamic>>[];
      final off = bus.on(WidgetSignals.waitOver, got.add);
      bus.on(WidgetSignals.waitOver, (_) => throw StateError('x'));
      expect(bus.emit(WidgetSignals.waitOver, {'reason': 'cancelled'}), 1);
      expect(got, [
        {'reason': 'cancelled'}
      ]);
      off();
      bus.emit(WidgetSignals.waitOver, {'reason': 'ended'});
      expect(got, hasLength(1));
      expect(bus.emit(WidgetSignals.humanJoined, {'name': 'Sam'}), 0);
    });
  });
}
