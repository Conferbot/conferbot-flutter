// Requeued, transferred, the same end, blocked and closed (#44, #43), the
// cases of the React Native SDK's __tests__/core/liveEvents.test.ts.
import 'package:conferbot_flutter/src/core/live_chat/live_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('back in the queue (web liveTakeover.ts)', () {
    test('says which team, or another agent', () {
      expect(LiveEvents.requeuedText(), 'Connecting you to another agent...');
      expect(LiveEvents.requeuedText('  Sales <b> '), 'Connecting you to Sales b...');
      expect(LiveEvents.requeuedText(42), 'Connecting you to another agent...');
      expect(LiveEvents.requeuedText('x' * 80), 'Connecting you to ${'x' * 60}...');
    });

    test('is its own record entry', () {
      final e = LiveEvents.requeuedEntry({'teamName': 'Billing'}, time: '2026-10-16T10:00:00.000Z');
      expect(e['type'], 'live-chat-requeued');
      expect(e['text'], 'Connecting you to Billing...');
      expect(e['time'], '2026-10-16T10:00:00.000Z');
      expect(e['id'], matches(RegExp(r'^requeued-\d+-')));
      expect(e['_id'], e['id']);
      expect(LiveEvents.eventId('x', now: 5, rand: 'abc'), 'x-5-abc');
      expect(LiveEvents.eventId('x'), isNot(LiveEvents.eventId('x')));
    });
  });

  test("transferred: keeps the server's entry as it wrote it", () {
    expect(LiveEvents.transferEntry({'entry': {'id': 'transfer-1', 'text': 'Transferred from Maya to Sales', 'time': 't', 'kind': 'team'}}), {
      'id': 'transfer-1',
      '_id': 'transfer-1',
      'shape': 'live-chat-transfer',
      'type': 'live-chat-transfer',
      'time': 't',
      'text': 'Transferred from Maya to Sales',
      'kind': 'team',
    });
    expect(LiveEvents.transferEntry({'entry': {'id': 'x', 'text': 'y' * 300}})!['text'], hasLength(200));
    expect(LiveEvents.transferEntry({'entry': {'id': 1, 'text': 'x'}}), isNull);
    expect(LiveEvents.transferEntry({}), isNull);
  });

  test('the same end again: true only while nothing live came after the end', () {
    expect(LiveEvents.endedSinceLastLive([]), isFalse);
    expect(LiveEvents.endedSinceLastLive(null), isFalse);
    expect(LiveEvents.endedSinceLastLive([{'type': 'agent-message'}, {'type': 'agent-chat-ended'}]), isTrue);
    expect(LiveEvents.endedSinceLastLive([{'type': 'agent-chat-ended'}, {'type': 'bot-message'}]), isTrue);
    expect(LiveEvents.endedSinceLastLive([{'type': 'agent-chat-ended'}, {'type': 'agent-joined-message'}]), isFalse);
    expect(LiveEvents.endedSinceLastLive([{'type': 'agent-chat-ended'}, {'shape': 'user-live-message'}]), isFalse);
  });

  group('blocked and closed (web closedState.ts, _applyVisitorBlock)', () {
    test('reads the handshake refusal and the event', () {
      expect(LiveEvents.isBlockedError({'message': 'visitor_blocked'}), isTrue);
      expect(LiveEvents.isBlockedError('visitor_blocked'), isTrue);
      expect(LiveEvents.isBlockedError({'message': 'timeout'}), isFalse);
      expect(LiveEvents.isBlockedError(null), isFalse);
      expect(LiveEvents.blockedText({'message': 'This conversation has been closed.'}), LiveEvents.closedText);
      expect(LiveEvents.blockedText({}), LiveEvents.closedText);
    });

    test('a blocked visitor gets the closed line, no input and no new chat', () {
      expect(
        LiveEvents.closedStateOf([], blocked: LiveEvents.closedText),
        const ClosedState(kind: ClosedKind.blocked, text: LiveEvents.closedText, newChat: false, inputOff: true),
      );
    });

    test('an ended chat offers a new one once nothing is going on', () {
      final ended = [{'type': 'agent-message'}, {'type': 'agent-chat-ended'}];
      expect(LiveEvents.closedStateOf(ended), const ClosedState(kind: ClosedKind.ended, text: 'Chat ended', newChat: true, inputOff: true));
      expect(LiveEvents.closedStateOf(ended, stepWaiting: true), isNull);
      expect(LiveEvents.closedStateOf(ended, live: true), isNull);
      expect(LiveEvents.closedStateOf([{'type': 'agent-message'}]), isNull);
    });
  });
}
