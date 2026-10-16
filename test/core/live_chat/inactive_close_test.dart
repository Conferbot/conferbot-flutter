// The AI letting an idle visitor go (lib/src/core/live_chat/live_events.dart),
// the React Native SDK's __tests__/core/inactiveClose.test.ts ported: the web
// widget's agentListeners.ts ai-agent-inactive-close and the server's
// aiInactivityHandler.js closeInactiveWebChat / resumeInactiveChat (#35).
import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => I18n.setWidgetLanguage('en'));

  group('inactiveClosePlan', () {
    test('continue_flow on a flow bot: ended, the flow carries on', () {
      expect(LiveEvents.inactiveClosePlan({'action': 'continue_flow'}, false), (paused: false, continueFlow: true));
    });
    test('any other action on a flow bot: only paused, the flow waits', () {
      expect(LiveEvents.inactiveClosePlan({'action': 'end_chat'}, false), (paused: true, continueFlow: false));
      expect(LiveEvents.inactiveClosePlan(<String, dynamic>{}, false), (paused: true, continueFlow: false));
      expect(LiveEvents.inactiveClosePlan(null, false), (paused: true, continueFlow: false));
    });
    test('an agent bot is always paused (it has no flow to go on with)', () {
      expect(LiveEvents.inactiveClosePlan({'action': 'continue_flow'}, true), (paused: true, continueFlow: false));
    });
  });

  group('inactiveCloseEntry', () {
    test('keeps the action and whether it paused, under its own id', () {
      final a = LiveEvents.inactiveCloseEntry({'action': 'continue_flow'}, false, time: '2026-10-16T10:00:00.000Z');
      final b = LiveEvents.inactiveCloseEntry({'action': 'continue_flow'}, false, time: '2026-10-16T10:00:00.000Z');
      expect(a, containsPair('type', 'ai-agent-inactive-close'));
      expect(a, containsPair('shape', 'ai-agent-inactive-close'));
      expect(a, containsPair('action', 'continue_flow'));
      expect(a, containsPair('paused', false));
      expect(a, containsPair('time', '2026-10-16T10:00:00.000Z'));
      expect(a['id'], a['_id']);
      expect(a['id'] as String, startsWith('ai-agent-inactive-close-'));
      expect(a['id'], isNot(b['id']));
    });
    test('no action: no action field, paused', () {
      final e = LiveEvents.inactiveCloseEntry(<String, dynamic>{}, false);
      expect(e.containsKey('action'), isFalse);
      expect(e['paused'], isTrue);
    });
  });

  group('inactiveCloseLine', () {
    test('paused: "Chat paused" and how to pick it up', () {
      expect(LiveEvents.inactiveCloseLine({'paused': true}),
          (text: 'Chat paused', note: 'Send a message to pick up where you left off', paused: true));
    });
    test('an older entry without the flag is a pause', () {
      expect(LiveEvents.inactiveCloseLine({'type': 'ai-agent-inactive-close'}).paused, isTrue);
    });
    test('ended: "Chat ended", no note', () {
      expect(LiveEvents.inactiveCloseLine({'paused': false}), (text: 'Chat ended', note: null, paused: false));
    });
    test("in the visitor's language", () {
      I18n.setWidgetLanguage('de');
      final line = LiveEvents.inactiveCloseLine({'paused': true});
      expect(line.text, isNot('Chat paused'));
      expect(line.note, isNot('Send a message to pick up where you left off'));
    });
  });
}
