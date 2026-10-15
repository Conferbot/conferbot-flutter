// The handover lifecycle (lib/src/core/live_chat/handover_state.dart), the
// same cases as the RN SDK's __tests__/core/handoverState.test.ts (and the
// web widget's tests/handoverLifecycle.test.js), plus this SDK's server
// record, where an entry's fields sit under `data`.
import 'package:conferbot_flutter/src/core/live_chat/handover_state.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

typedef H = HandoverRecord;

Map<String, dynamic> m(Map<String, dynamic> base, [Map<String, dynamic> extra = const {}]) => {...base, ...extra};

const aiJoin = {'type': 'agent-joined-message', 'agentId': 'ai-agent-1', 'name': 'Ava'};
const escalated = {'type': 'agent-left-chat', 'name': 'Ava', 'handover': true};
const human = {'type': 'agent-joined-message', 'agentId': 'u1', 'name': 'admin'};
const humanLeft = {'type': 'agent-left-chat', 'name': 'admin'};
const ended = {'type': 'agent-chat-ended'};
const reply = {'shape': 'agent-message', 'text': 'hi'};

void main() {
  group('handover state (web handoverState.ts)', () {
    test('phase: bot, connecting, a person joined, left, ended', () {
      expect(H.phase([]), HandoverPhase.none);
      expect(H.phase(null), HandoverPhase.none);
      expect(H.phase([reply]), HandoverPhase.none);
      expect(H.phase([aiJoin, reply]), HandoverPhase.none);
      expect(H.phase([aiJoin, reply, escalated]), HandoverPhase.connecting);
      expect(H.phase([escalated, m(aiJoin, {'ai': true}), reply]), HandoverPhase.connecting);
      expect(H.phase([escalated, human, reply]), HandoverPhase.joined);
      expect(H.phase([escalated, human, humanLeft]), HandoverPhase.none);
      expect(H.phase([escalated, human, ended]), HandoverPhase.none);
      expect(H.phase([escalated, {'type': 'agent-declined-message'}]), HandoverPhase.none);
      expect(H.phase([escalated, {'type': 'queue-self-resolved'}]), HandoverPhase.none);
      expect(H.phase([{'type': 'agent-joined-message', 'agentId': 'u2', 'takeover': true}]), HandoverPhase.joined);
    });

    test('Talk to a person is offered only when nobody is coming or here', () {
      expect(H.talkToPersonAllowed([aiJoin, reply]), isTrue);
      expect(H.talkToPersonAllowed([aiJoin, escalated]), isFalse);
      expect(H.talkToPersonAllowed([escalated, human]), isFalse);
      expect(H.talkToPersonAllowed([escalated, human, humanLeft, reply]), isTrue);
    });

    test('the same agent joining again is a repeat; another agent (a transfer) is news', () {
      expect(H.isRepeatJoin([escalated, human], 'u1'), isTrue);
      expect(H.isRepeatJoin([escalated, human, reply], 'u1'), isTrue);
      expect(H.isRepeatJoin([escalated, human], 'u2'), isFalse);
      expect(H.isRepeatJoin([escalated, human, humanLeft], 'u1'), isFalse);
      expect(H.isRepeatJoin([escalated], 'u1'), isFalse);
      expect(H.isRepeatJoin([escalated, human], null), isFalse);
    });

    test('outcome of a handover line, from what came after it', () {
      expect(H.outcomeAt([escalated], 0), isNull);
      expect(H.outcomeAt([escalated, reply], 0), isNull);
      expect(H.outcomeAt([escalated, human], 0), HandoverOutcome.joined);
      expect(H.outcomeAt([escalated, {'type': 'agent-joined-message', 'agentId': 'u2', 'takeover': true}], 0), HandoverOutcome.joined);
      expect(H.outcomeAt([escalated, aiJoin], 0), HandoverOutcome.unavailable);
      expect(H.outcomeAt([escalated, {'type': 'agent-declined-message'}], 0), HandoverOutcome.unavailable);
      expect(H.outcomeAt([escalated, {'type': 'queue-self-resolved'}], 0), HandoverOutcome.cancelled);
      expect(H.outcomeAt([escalated, ended], 0), HandoverOutcome.ended);
      expect(H.outcomeAt([escalated, {'type': 'ai-agent-inactive-close'}], 0), HandoverOutcome.ended);
      expect(H.outcomeAt([escalated, reply, m(escalated)], 0), HandoverOutcome.unavailable);
      expect(H.outcomeAt([m(escalated, {'settled': 'unavailable'}), human], 0), HandoverOutcome.unavailable);
    });

    test('a restored record: finished waits settle, a join after an AI handover keeps its note', () {
      final rec = [aiJoin, m(escalated, {'text': H.pendingText}), m(human), reply, m(humanLeft)];
      final a = H.annotateRestored(rec);
      expect(a.changed, 2);
      final out = a.record.cast<Map>();
      expect(out[1]['settled'], 'joined');
      expect(out[1]['text'], 'Connected with the team');
      expect(out[2]['afterAI'], isTrue);
      expect(out[2]['note'], H.handedOverNote);
      expect(out[0]['afterAI'], isNull);
      // The input is left alone.
      expect(rec[1]['settled'], isNull);

      final waiting = [aiJoin, m(escalated), reply];
      final w = H.annotateRestored(waiting);
      expect(w.changed, 0);
      expect(identical(w.record, waiting), isTrue);

      final later = [m(escalated), {'type': 'agent-chat-ended'}, {'type': 'agent-joined-message', 'agentId': 'u3'}];
      final l = H.annotateRestored(later).record.cast<Map>();
      expect(l[0]['settled'], 'ended');
      expect(l[2]['afterAI'], isNull);
    });

    test('settling touches only pending handover entries', () {
      final rec = [m(escalated, {'settled': 'unavailable'}), m(escalated, {'text': 'x'}), m(humanLeft)];
      final a = H.settleEntries(rec, HandoverOutcome.joined);
      expect(a.settled, 1);
      final out = a.record.cast<Map>();
      expect(out[0]['settled'], 'unavailable');
      expect(out[1]['settled'], 'joined');
      expect(out[1]['text'], 'Connected with the team');
      expect(out[2]['settled'], isNull);
      expect(H.settleEntries(a.record, HandoverOutcome.joined).settled, 0);
      expect(identical(H.settleEntries(a.record, HandoverOutcome.joined).record, a.record), isTrue);
      expect(H.hasPendingLine(rec), isTrue);
      expect(H.hasPendingLine(a.record), isFalse);
      expect(H.outcomeOf('bogus'), isNull);
    });

    test('the line: pending words, then each of the four outcomes', () {
      expect(H.lineText(), 'Connecting you with the team…');
      expect(H.lineText(HandoverOutcome.joined), 'Connected with the team');
      expect(H.lineText(HandoverOutcome.unavailable), "The team couldn't join just now");
      expect(H.lineText(HandoverOutcome.cancelled), 'You left the queue');
      expect(H.lineText(HandoverOutcome.ended), 'Chat ended before the team joined');
      expect(H.agentLeftText('Ava', true), 'Connecting you with the team…');
      expect(H.agentLeftText('Sam', false), 'Sam left the chat');
      expect(H.agentLeftText('', false), 'The agent left the chat');
      expect(H.joinedText('Sam'), 'Sam joined the chat');
      expect(H.joinedText(null), 'An agent joined the chat');
    });

    test('reads this SDK\'s server record, where the fields sit under data', () {
      final line = RecordEntry(id: 'l1', shape: 'agent-left-chat', type: 'agent-left-chat', text: H.pendingText, data: {'handover': true, 'name': 'Ava'});
      final join = RecordEntry(id: 'j1', shape: 'agent-joined-message', type: 'agent-joined-message', data: {'agentId': 'u1', 'name': 'Sam'});
      final record = [line.toJson(), join.toJson()];
      expect(H.phase([line.toJson()]), HandoverPhase.connecting);
      expect(H.phase(record), HandoverPhase.joined);
      expect(H.isRepeatJoin(record, 'u1'), isTrue);
      expect(H.pendingLineIds([line.toJson()]), ['l1']);
      final a = H.annotateRestored(record);
      expect(a.changed, 2);
      final out = a.record.cast<Map>();
      expect(out[0]['data']['settled'], 'joined');
      expect(out[1]['data']['afterAI'], isTrue);
    });
  });

  group('socket readings (web agentListeners.ts / special.ts)', () {
    test('agent-left: an AI escalating is a handover, an idle pause is nothing, a person leaves', () {
      expect(H.agentLeftKind({'reason': 'escalated', 'agentDetails': {'name': 'Ava'}}), AgentLeftKind.handover);
      expect(H.agentLeftKind({'handover': true, 'agentDetails': {'name': 'Ava'}}), AgentLeftKind.handover);
      expect(H.agentLeftKind({'agentDetails': {'name': 'Ava', 'isAIAgent': true}}), AgentLeftKind.handover);
      expect(H.agentLeftKind({'reason': 'visitor_inactive', 'agentDetails': {'isAIAgent': true}}), AgentLeftKind.ignore);
      expect(H.agentLeftKind({'agentDetails': {'name': 'Sam'}}), AgentLeftKind.left);
      expect(H.agentLeftKind(null), AgentLeftKind.left);
    });

    test('agent-accepted: a person settles joined; the AI taking it back settles unavailable; a repeat is not announced', () {
      final p = H.acceptedPlan([aiJoin, escalated], {'agentDetails': {'_id': 'u1', 'name': 'Sam'}});
      expect([p.ai, p.outcome, p.announce, p.afterAI, p.humanJoined], [false, HandoverOutcome.joined, true, true, true]);
      final back = H.acceptedPlan([aiJoin, escalated], {'agentDetails': {'_id': 'ai-agent-1', 'name': 'Ava', 'isAIAgent': true}});
      expect(back.outcome, HandoverOutcome.unavailable);
      expect(back.humanJoined, isFalse);
      expect(back.afterAI, isFalse);
      final again = H.acceptedPlan([escalated, human], {'agentDetails': {'_id': 'u1', 'name': 'admin'}});
      expect(again.announce, isFalse);
      expect(again.humanJoined, isFalse);
      // A flow handover with no AI before it: no note.
      expect(H.acceptedPlan([], {'agentDetails': {'_id': 'u1'}}).afterAI, isFalse);
    });

    test('leaving the queue: queue-self-resolve, and stay only when a person already has it', () {
      expect(H.queueSelfResolvePayload('s1'), {'chatSessionId': 's1'});
      expect(H.queueSelfResolvePayload('s1', 'a9'), {'chatSessionId': 's1', 'articleId': 'a9'});
      expect(H.queueLeaveStays({'ok': true}), isFalse);
      expect(H.queueLeaveStays({'ok': false, 'reason': 'not_waiting'}), isFalse);
      expect(H.queueLeaveStays(null), isFalse);
      expect(H.queueLeaveStays({'ok': false, 'reason': 'agent_joined'}), isTrue);
      // A person accepted (ticket in progress): not_waiting, then live.
      expect(H.queueLeaveNeedsState({'ok': false, 'reason': 'not_waiting'}), isTrue);
      expect(H.queueLeaveNeedsState({'ok': true}), isFalse);
      expect(H.queueLeaveStays({'ok': false, 'reason': 'not_waiting'}, {'status': 'live'}), isTrue);
      expect(H.queueLeaveStays({'ok': false, 'reason': 'not_waiting'}, {'status': 'ended'}), isFalse);
    });
  });

  group('restore (web index.ts live-chat-state)', () {
    test('asks the server only for a chat in a live episode or at its handover', () {
      expect(H.restoreNeedsLiveChatState([]), isFalse);
      expect(H.restoreNeedsLiveChatState([{'type': 'bot-message'}]), isFalse);
      expect(H.restoreNeedsLiveChatState([{'type': 'bot-message'}], atHandover: true), isTrue);
      expect(H.restoreNeedsLiveChatState([human, {'type': 'agent-message'}]), isTrue);
      expect(H.restoreNeedsLiveChatState([aiJoin, escalated]), isTrue);
      // The episode ended: over.
      expect(H.restoreNeedsLiveChatState([human, {'type': 'agent-message'}, ended]), isFalse);
      expect(H.restoreNeedsLiveChatState([human, ended], atHandover: true), isFalse);
      // A new episode after an ended one.
      expect(H.restoreNeedsLiveChatState([human, ended, {'type': 'user-message', 'shape': 'user-live-message'}]), isTrue);
    });

    test('live: the person, the join line it missed, the line settled', () {
      final r = H.restoredLiveChat({'status': 'live', 'agentDetails': {'_id': 'u1', 'name': 'Sam', 'email': 's@x.io'}}, [aiJoin, escalated]);
      expect(r.status, 'live');
      expect([r.agent!.id, r.agent!.name, r.agent!.email], ['u1', 'Sam', 's@x.io']);
      expect(r.settle, HandoverOutcome.joined);
      expect(r.drawJoin, isTrue);
      expect(r.afterAI, isTrue);
      expect(r.remainingSeconds, isNull);
      // Already drawn before the restart: not again.
      expect(H.restoredLiveChat({'status': 'live', 'agentDetails': {'_id': 'u1', 'name': 'Sam'}}, [escalated, human]).drawJoin, isFalse);
      // The AI on the chat is not a person.
      expect(H.restoredLiveChat({'status': 'live', 'agentDetails': {'_id': 'ai-agent-1', 'isAIAgent': true}}, [escalated]).status, 'none');
    });

    test('waiting keeps the line pending with the time left; ended and fallback settle it', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1000000);
      final w = H.restoredLiveChat({'status': 'waiting', 'waitEndsAt': 1000000 + 61000}, [escalated], now: now);
      expect(w.status, 'waiting');
      expect(w.settle, isNull);
      expect(w.remainingSeconds, 61);
      expect(H.restoredLiveChat({'status': 'waiting', 'waitEndsAt': 1000000 - 5000}, [], now: now).remainingSeconds, 5);
      expect(H.restoredLiveChat({'status': 'ended'}, [escalated]).settle, HandoverOutcome.ended);
      expect(H.restoredLiveChat({'status': 'fallback'}, [escalated]).status, 'fallback');
      expect(H.restoredLiveChat({'status': 'fallback'}, [escalated]).settle, HandoverOutcome.unavailable);
      expect(H.restoredLiveChat({'status': 'none'}, [reply]).settle, isNull);
      expect(H.restoredLiveChat({'status': 'none'}, [escalated]).settle, HandoverOutcome.unavailable);
      expect(H.restoredLiveChat(null, []).status, 'none');
    });

    test('what a restored chat does next', () {
      RestoredLiveChat at(String status) => H.restoredLiveChat({'status': status}, []);
      final live = H.restoredLiveChat({'status': 'live', 'agentDetails': {'_id': 'u1', 'name': 'Sam'}}, []);
      expect(H.restoreStep(live, true), RestoreStep.live);
      expect(H.restoreStep(live, false), RestoreStep.live);
      expect(H.restoreStep(at('waiting'), true), RestoreStep.wait);
      // Waiting after an AI escalation: the AI keeps the chat meanwhile.
      expect(H.restoreStep(at('waiting'), false), RestoreStep.live);
      expect(H.restoreStep(at('ended'), true, [human]), RestoreStep.continueFlow);
      expect(H.restoreStep(at('fallback'), true, []), RestoreStep.continueFlow);
      expect(H.restoreStep(at('none'), true, [{'type': 'bot-message'}]), RestoreStep.ask);
      expect(H.restoreStep(at('none'), true, [human, reply]), RestoreStep.continueFlow);
      expect(H.restoreStep(at('ended'), false), RestoreStep.start);
      expect(H.restoreStep(at('none'), false), RestoreStep.start);
    });
  });
}
