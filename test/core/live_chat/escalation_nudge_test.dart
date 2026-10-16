// The AI escalation's max wait (lib/src/core/live_chat/handover_waiting.dart),
// the React Native SDK's __tests__/core/escalationNudge.test.ts ported: the
// web widget's handoverWaiting.ts armAIEscalationNudge and special.ts
// _handleAIEscalationWait - the step's max wait plus 30s, then
// handover-timeout, nothing drawn (#39).
import 'package:conferbot_flutter/src/core/live_chat/handover_waiting.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock {
  int now = 0;
  int _seq = 0;
  final Map<int, ({int at, void Function() fn})> timers = {};
  Object set(void Function() fn, Duration after) {
    timers[++_seq] = (at: now + after.inMilliseconds, fn: fn);
    return _seq;
  }

  void clear(Object id) => timers.remove(id);
  void advance(int ms) {
    now += ms;
    for (final e in timers.entries.toList()) {
      if (e.value.at <= now) {
        timers.remove(e.key);
        e.value.fn();
      }
    }
  }
}

void main() {
  group('aiEscalationNudgeAfter', () {
    test('the max wait in minutes plus 30s of grace', () {
      expect(serverGrace, const Duration(seconds: 30));
      expect(aiEscalationNudgeAfter(5).inMilliseconds, 5 * 60000 + 30000);
      expect(aiEscalationNudgeAfter('3').inMilliseconds, 3 * 60000 + 30000);
      expect(aiEscalationNudgeAfter(0.5).inMilliseconds, 30000 + 30000);
    });
    test('2 minutes when unset or not a positive number', () {
      for (final v in [null, 0, -1, 'x']) {
        expect(aiEscalationNudgeAfter(v).inMilliseconds, 2 * 60000 + 30000, reason: '$v');
      }
    });
  });

  group('startsEscalationWait', () {
    test('only an AI agent handing on', () {
      expect(startsEscalationWait({'agentDetails': {'isAIAgent': true}}), isTrue);
      expect(startsEscalationWait({'agentDetails': {'isAIAgent': true}, 'reason': 'escalated'}), isTrue);
    });
    test('not an inactivity close, not a person, not nothing', () {
      expect(startsEscalationWait({'agentDetails': {'isAIAgent': true}, 'reason': 'visitor_inactive'}), isFalse);
      expect(startsEscalationWait({'agentDetails': {'name': 'Sam'}}), isFalse);
      expect(startsEscalationWait(null), isFalse);
    });
  });

  group('escalationHandoverData', () {
    test('the flow step first', () {
      expect(
          escalationHandoverData({'maxWaitTime': 4}, [
            {'type': 'human-handover-node', 'data': {'maxWaitTime': 9}}
          ]),
          {'maxWaitTime': 4});
    });
    test('else the latest handover step in the record (an agent bot)', () {
      final record = [
        {'type': 'human-handover-node', 'data': {'maxWaitTime': 1}},
        {'type': 'user-live-message'},
        {'shape': 'human-handover-node', 'data': {'maxWaitTime': 7}},
        {'type': 'agent-message'},
      ];
      expect(escalationHandoverData(null, record), {'maxWaitTime': 7});
    });
    test('none', () {
      expect(escalationHandoverData(null, [{'type': 'agent-message'}]), isNull);
      expect(escalationHandoverData(null, null), isNull);
    });
  });

  group('EscalationNudge', () {
    test('nudges once, the max wait plus the grace after the AI left', () {
      final c = _Clock();
      var nudged = 0;
      final n = EscalationNudge(() => nudged++, setTimer: c.set, clearTimer: c.clear);
      n.arm(1);
      expect(n.pending, isTrue);
      c.advance(60000);
      expect(nudged, 0);
      c.advance(29999);
      expect(nudged, 0);
      c.advance(1);
      expect(nudged, 1);
      expect(n.pending, isFalse);
      c.advance(10 * 60000);
      expect(nudged, 1);
    });
    test('cleared (someone accepted, the server decided, the chat ended): never', () {
      final c = _Clock();
      var nudged = 0;
      final n = EscalationNudge(() => nudged++, setTimer: c.set, clearTimer: c.clear);
      n.arm(2);
      c.advance(60000);
      n.clear();
      c.advance(10 * 60000);
      expect(nudged, 0);
      expect(c.timers, isEmpty);
    });
    test('a second escalation restarts the one timer', () {
      final c = _Clock();
      var nudged = 0;
      final n = EscalationNudge(() => nudged++, setTimer: c.set, clearTimer: c.clear);
      n.arm(1);
      c.advance(80000);
      n.arm(1);
      expect(c.timers, hasLength(1));
      c.advance(80000);
      expect(nudged, 0);
      c.advance(10000);
      expect(nudged, 1);
    });
  });
}
