// The handover lifecycle against a fake socket and a fake clock
// (lib/src/core/live_chat/handover_lifecycle.dart): the AI's inactivity
// close (#35), the AI escalation's max wait (#39) and a restored wait's time
// left (#38). The cases of the React Native SDK's
// __tests__/context/useHandoverLifecycle.test.ts (RN #39, #43, #42).
import 'package:conferbot_flutter/src/core/live_chat/handover_lifecycle.dart';
import 'package:conferbot_flutter/src/core/live_chat/handover_state.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_events.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:conferbot_flutter/src/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_socket_client.dart';

class _Socket extends MockSocketClient {
  final Map<String, dynamic> answers = {};

  @override
  Future<dynamic> emitWithAck(String event, dynamic data, {Duration timeout = const Duration(seconds: 10)}) async {
    emit(event, data);
    return answers[event];
  }
}

class _Flow implements HandoverFlow {
  bool here = false;
  Map<String, dynamic>? data;
  final List<String> calls = [];

  @override
  bool get atHandover => here;
  @override
  Map<String, dynamic>? get handoverNodeData => here ? data : null;
  @override
  bool waitAt(String nodeId, {required bool waiting}) {
    calls.add('waitAt:$nodeId:${waiting ? 'card' : 'none'}');
    here = true;
    return true;
  }

  @override
  void continueFlow() {
    calls.add('continue');
    here = false;
  }

  @override
  void resumeFrom(String nodeId) => calls.add('resumeFrom:$nodeId');

  @override
  void stop() {
    calls.add('stop');
    here = false;
  }
}

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
      timers.remove(due.first.key);
      now = due.first.value.at;
      due.first.value.fn();
    }
    now = until;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Socket socket;
  late _Flow flow;
  late _Clock clock;
  late List<RecordItem> screen;
  late HandoverLifecycle h;
  late bool agentBot;
  late List<int?> restored;
  bool? live;
  int agentCleared = 0;
  const sid = 'sess-1';
  final state = ChatState.instance;

  HandoverLifecycle make() => HandoverLifecycle(
        socket: () => socket,
        sessionId: () => sid,
        isOpen: () => true,
        addLine: screen.add,
        updateLines: (change) {
          for (var i = 0; i < screen.length; i++) {
            final next = change(screen[i]);
            if (next != null) screen[i] = next;
          }
        },
        flow: flow,
        setLive: (on) => live = on,
        clearAgent: () => agentCleared++,
        setTimer: clock.set,
        clearTimer: clock.clear,
        isAgentBot: () => agentBot,
        workspaceId: () => 'w1',
        onRestoredWait: restored.add,
      );

  setUp(() {
    state.reset();
    state.initialize(chatSessionId: sid, visitorId: 'v1', botId: 'b1');
    socket = _Socket()..mockIsConnected = true;
    flow = _Flow();
    clock = _Clock();
    screen = [];
    agentBot = false;
    restored = [];
    live = null;
    agentCleared = 0;
    h = make()..setupListeners();
  });

  tearDown(() => h.dispose());

  List<SystemMessageRecord> lines() => screen.whereType<SystemMessageRecord>().toList();
  List<Map<String, dynamic>> closes() =>
      state.getRecordForServer().where((r) => r['type'] == 'ai-agent-inactive-close').toList();
  List<dynamic> timeouts() => socket.getEmittedEvents('handover-timeout').map((e) => e.data).toList();

  group('AI inactivity (#35)', () {
    test('the AI pauses an idle visitor: "Chat paused" with its note, the live chat stays', () {
      flow.here = true;
      socket.simulateEvent('ai-agent-inactive-close', {'chatSessionId': sid, 'action': 'end_chat'});
      expect(lines().single.text, 'Chat paused');
      expect(lines().single.note, 'Send a message to pick up where you left off');
      expect(lines().single.kind, 'ai-agent-inactive-close');
      final entry = closes().single;
      expect(entry['paused'], isTrue);
      expect(entry['action'], 'end_chat');
      expect(entry.containsKey('shape'), isFalse);
      expect(entry['id'], lines().single.id);
      // The composer stays on: the chat is not closed, live mode untouched.
      expect(LiveEvents.closedStateOf(state.getRecordForServer()), isNull);
      expect(live, isNull);
      expect(flow.calls, isEmpty);
      // Another chat's close is not ours.
      socket.simulateEvent('ai-agent-inactive-close', {'chatSessionId': 'other', 'action': 'continue_flow'});
      expect(lines(), hasLength(1));
    });

    test('recorded once: a second pause is its own entry and line, never a merge', () {
      socket.simulateEvent('ai-agent-inactive-close', {'chatSessionId': sid});
      socket.simulateEvent('ai-agent-inactive-close', {'chatSessionId': sid});
      expect(closes(), hasLength(2));
      expect(closes()[0]['id'], isNot(closes()[1]['id']));
      expect(lines(), hasLength(2));
    });

    test('continue_flow: "Chat ended", nobody here, live off, the flow goes on from its handover step', () {
      flow.here = true;
      socket.simulateEvent('ai-agent-inactive-close', {'chatSessionId': sid, 'action': 'continue_flow'});
      expect(lines().single.text, 'Chat ended');
      expect(lines().single.note, isNull);
      expect(closes().single['paused'], isFalse);
      expect(agentCleared, 1);
      expect(live, isFalse);
      // The step's next edge (continueAfterHandover's action continue), no survey.
      expect(flow.calls, ['continue']);
    });

    test('continue_flow off the handover step: the line and live off, no flow move', () {
      socket.simulateEvent('ai-agent-inactive-close', {'chatSessionId': sid, 'action': 'continue_flow'});
      expect(lines().single.text, 'Chat ended');
      expect(live, isFalse);
      expect(flow.calls, isEmpty);
    });

    test('continue_flow on an agent bot only pauses: it has no flow', () {
      agentBot = true;
      flow.here = true;
      socket.simulateEvent('ai-agent-inactive-close', {'chatSessionId': sid, 'action': 'continue_flow'});
      expect(lines().single.text, 'Chat paused');
      expect(closes().single['paused'], isTrue);
      expect(live, isNull);
      expect(flow.calls, isEmpty);
    });

    test('a pending Connecting line settles as ended', () {
      h.onAgentLeft({'reason': 'escalated', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}});
      socket.simulateEvent('ai-agent-inactive-close', {'chatSessionId': sid});
      expect(lines().first.settled, HandoverOutcome.ended.name);
      expect(lines().last.text, 'Chat paused');
    });
  });

  group("the AI escalation's max wait (#39)", () {
    const step = {'maxWaitTime': 1, 'assignmentType': 'auto', 'agentAssignmentStrategy': 'round', 'assignedAgents': ['u1']};

    test("the step's max wait plus 30s, then handover-timeout, nothing drawn", () {
      flow
        ..here = true
        ..data = Map<String, dynamic>.from(step);
      h.onAgentLeft({'reason': 'escalated', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}});
      expect(h.nudge.pending, isTrue);
      clock.tick(60000 + 29999);
      expect(timeouts(), isEmpty);
      clock.tick(1);
      expect(timeouts(), [
        {
          'chatSessionId': sid,
          'assignmentData': {'assignmentType': 'auto', 'assignmentStrategy': 'round', 'assignedAgents': ['u1']},
          'workspaceId': 'w1',
        }
      ]);
      // Only the Connecting line: the nudge draws nothing.
      expect(screen, hasLength(1));
      clock.tick(10 * 60000);
      expect(timeouts(), hasLength(1));
    });

    test("an agent bot's escalation waits on its silent handover step in the record", () {
      state.pushToRecord(RecordEntry(id: 'agent-handover', shape: 'human-handover-node', type: 'human-handover-node', data: {'maxWaitTime': 3}));
      h.onAgentLeft({'agentDetails': {'name': 'Ava', 'isAIAgent': true}});
      clock.tick(3 * 60000 + 29000);
      expect(timeouts(), isEmpty);
      clock.tick(1000);
      expect((timeouts().single as Map)['chatSessionId'], sid);
    });

    test('no nudge once someone accepts, the server decides, the visitor leaves, or the chat ends', () async {
      for (final end in ['accepted', 'handover-waiting', 'no-agents-available', 'chat-ended', 'ai-agent-inactive-close', 'visitor-blocked', 'left']) {
        h.dispose();
        socket = _Socket()..mockIsConnected = true;
        flow = _Flow()
          ..here = true
          ..data = {'maxWaitTime': 1};
        h = make()..setupListeners();
        h.onAgentLeft({'reason': 'escalated', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}});
        if (end == 'accepted') {
          h.onAccepted({'agentDetails': {'_id': 'u1', 'name': 'Sam'}});
        } else if (end == 'left') {
          socket.answers['queue-self-resolve'] = {'ok': true};
          await h.leaveQueue();
        } else {
          socket.simulateEvent(end, {'chatSessionId': sid});
        }
        clock.tick(10 * 60000);
        expect([end, timeouts().length], [end, 0]);
      }
    });

    test('a person leaving or an idle pause is no escalation: no nudge', () {
      flow
        ..here = true
        ..data = {'maxWaitTime': 1};
      h.onAgentLeft({'agentDetails': {'name': 'Sam'}});
      h.onAgentLeft({'reason': 'visitor_inactive', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}});
      clock.tick(10 * 60000);
      expect(timeouts(), isEmpty);
    });

    test('a second escalation restarts the one timer', () {
      flow
        ..here = true
        ..data = {'maxWaitTime': 1};
      h.onAgentLeft({'reason': 'escalated', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}});
      clock.tick(80000);
      h.onAgentLeft({'reason': 'escalated', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}});
      clock.tick(80000);
      expect(timeouts(), isEmpty);
      clock.tick(10000);
      expect(timeouts(), hasLength(1));
    });
  });

  group('a restored wait (#38)', () {
    const steps = [
      {'id': 'h1', 'type': 'human-handover-node', 'data': {'type': 'human-handover-node', 'maxWaitTime': 5}},
    ];

    test("hands the server's seconds left to the countdown, before the step waits again", () async {
      state.setCurrentNodeId('h1');
      final ends = DateTime.now().millisecondsSinceEpoch + 42000;
      socket.answers['live-chat-state'] = {'status': 'waiting', 'waitEndsAt': ends};
      expect(await h.resumeRestored(steps: steps, agentBot: false), RestoreStep.wait);
      expect(restored, hasLength(1));
      expect(restored.single, inInclusiveRange(41, 42));
      expect(flow.calls, ['waitAt:h1:card']);
    });

    test('no waitEndsAt: the full max wait (null)', () async {
      state.setCurrentNodeId('h1');
      socket.answers['live-chat-state'] = {'status': 'waiting'};
      await h.resumeRestored(steps: steps, agentBot: false);
      expect(restored, [null]);
    });
  });
}
