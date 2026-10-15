// The handover lifecycle against a fake socket (lib/src/core/live_chat/
// handover_lifecycle.dart): the cases of the RN SDK's
// __tests__/context/useHandoverLifecycle.test.ts - the Connecting line and
// its outcomes (#24, #27), the 20s signal, leaving the queue (#37) and a
// restart (#25).
import 'package:conferbot_flutter/src/core/live_chat/handover_lifecycle.dart';
import 'package:conferbot_flutter/src/core/live_chat/handover_state.dart';
import 'package:conferbot_flutter/src/core/live_chat/handover_waiting.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:conferbot_flutter/src/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_socket_client.dart';

class _Socket extends MockSocketClient {
  final Map<String, dynamic> answers = {};
  final List<String> asked = [];

  @override
  Future<dynamic> emitWithAck(String event, dynamic data, {Duration timeout = const Duration(seconds: 10)}) async {
    asked.add(event);
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
  Map<String, dynamic>? get handoverNodeData => data;
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
  late _Socket socket;
  late _Flow flow;
  late _Clock clock;
  late List<RecordItem> screen;
  late HandoverLifecycle h;
  late List<String> signals;
  bool? live;
  RestoredAgent? agent;
  const sid = 'sess-1';

  final state = ChatState.instance;

  setUp(() {
    state.reset();
    state.initialize(chatSessionId: sid, visitorId: 'v1', botId: 'b1');
    socket = _Socket()..mockIsConnected = true;
    flow = _Flow();
    clock = _Clock();
    screen = [];
    signals = [];
    live = null;
    agent = null;
    h = HandoverLifecycle(
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
      setAgent: (a) => agent = a,
      setTimer: clock.set,
      clearTimer: clock.clear,
    );
    for (final name in WidgetSignals.all) {
      h.onSignal(name, (d) => signals.add('$name ${d['reason'] ?? d['name'] ?? ''}'.trim()));
    }
    h.setupListeners();
  });

  List<SystemMessageRecord> lines() => screen.whereType<SystemMessageRecord>().toList();

  test('an AI escalating draws one Connecting line; an idle pause draws nothing (#24)', () {
    expect(h.onAgentLeft({'reason': 'visitor_inactive', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}}), AgentLeftKind.ignore);
    expect(screen, isEmpty);
    expect(h.onAgentLeft({'reason': 'escalated', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}}), AgentLeftKind.handover);
    h.onAgentLeft({'reason': 'escalated', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}});
    expect(lines().map((l) => l.text), ['Connecting you with the team…']);
    expect(lines().single.handoverPending, isTrue);
    expect(h.talkToPersonAllowed, isFalse);
    // A person leaving says so.
    expect(h.onAgentLeft({'agentDetails': {'name': 'Sam'}}), AgentLeftKind.left);
    expect(lines().last.text, 'Sam left the chat');
  });

  test('a person joining settles the line, says cb:human-joined, and no 20s signal fires (#27)', () {
    h.onAgentLeft({'reason': 'escalated', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}});
    clock.tick(10000);
    final plan = h.onAccepted({'agentDetails': {'_id': 'u1', 'name': 'Sam'}});
    if (plan.announce) h.addJoin({'_id': 'u1', 'name': 'Sam'}, plan);
    clock.tick(30000);
    expect(lines().map((l) => l.text), ['Connected with the team', 'Sam joined the chat']);
    expect(lines().last.note, HandoverRecord.handedOverNote);
    expect(signals, ['cb:human-joined Sam']);
    expect(h.personInChat, isTrue);
    // The record keeps the outcome for a restart.
    final line = state.record.firstWhere((e) => e.shape == 'agent-left-chat');
    expect(line.data['settled'], 'joined');
    // The same person again (a reconnect): nothing new.
    expect(h.onAccepted({'agentDetails': {'_id': 'u1', 'name': 'Sam'}}).announce, isFalse);
  });

  test("nobody joins in 20s: cb:waiting-for-human once; the server's handover-waiting settles unavailable", () {
    h.onAgentLeft({'reason': 'escalated', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}});
    clock.tick(20000);
    expect(signals, ['cb:waiting-for-human busy']);
    socket.simulateEvent('handover-waiting', {'chatSessionId': sid, 'offline': true});
    expect(lines().single.text, "The team couldn't join just now");
    expect(signals.last, 'cb:waiting-for-human offline');
  });

  test('chat ended first: the line says so and cb:wait-over ended', () {
    h.onAgentLeft({'reason': 'escalated', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}});
    socket.simulateEvent('chat-ended', {'chatSessionId': sid});
    expect(lines().single.text, 'Chat ended before the team joined');
    expect(signals, ['cb:wait-over ended']);
    clock.tick(30000);
    expect(signals, hasLength(1));
  });

  test('nobody available settles unavailable; another session is ignored', () {
    h.onAgentLeft({'reason': 'escalated', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}});
    socket.simulateEvent('chat-ended', {'chatSessionId': 'someone-else'});
    expect(lines().single.handoverPending, isTrue);
    socket.simulateEvent('no-agents-available', {});
    expect(lines().single.text, "The team couldn't join just now");
    expect(signals, ['cb:wait-over unavailable']);
  });

  test('a flow handover waiting for a person: the 20s signal, not with an AI agent first', () {
    h.setWaitingForPerson(true, {'assignedAIAgents': ['a1']});
    clock.tick(25000);
    expect(signals, isEmpty);
    h.setWaitingForPerson(false);
    h.setWaitingForPerson(true, {'assignedAIAgents': []});
    clock.tick(20000);
    expect(signals, ['cb:waiting-for-human busy']);
  });

  test('leaving the queue sends queue-self-resolve, then the flow moves on (#37)', () async {
    flow.here = true;
    h.setWaitingForPerson(true, const {});
    socket.answers['queue-self-resolve'] = {'ok': true};
    expect(await h.leaveQueue(), isTrue);
    expect(socket.getEmittedEvents('queue-self-resolve').single.data, {'chatSessionId': sid});
    expect(lines().single.text, 'You left the queue');
    expect(state.record.last.shape, 'queue-self-resolved');
    expect(flow.calls, ['continue']);
    expect(signals, ['cb:wait-over cancelled']);
    clock.tick(30000);
    expect(signals, hasLength(1));
  });

  test('a person accepted just before: not_waiting, live-chat-state live, the visitor stays', () async {
    flow.here = true;
    socket.answers['queue-self-resolve'] = {'ok': false, 'reason': 'not_waiting'};
    socket.answers['live-chat-state'] = {'status': 'live'};
    expect(await h.leaveQueue(), isFalse);
    expect(socket.asked, ['queue-self-resolve', 'live-chat-state']);
    expect(screen, isEmpty);
    expect(flow.calls, isEmpty);
  });

  test('a person already has it: the visitor stays', () async {
    flow.here = true;
    socket.answers['queue-self-resolve'] = {'ok': false, 'reason': 'agent_joined'};
    expect(await h.leaveQueue(), isFalse);
    expect(socket.asked, ['queue-self-resolve']);
  });

  test('left the queue on another device (queue-left self_service)', () {
    flow.here = true;
    h.setWaitingForPerson(true, const {});
    socket.simulateEvent('queue-left', {'chatSessionId': sid, 'reason': 'other'});
    expect(screen, isEmpty);
    socket.simulateEvent('queue-left', {'chatSessionId': sid, 'reason': 'self_service'});
    expect(lines().single.text, 'You left the queue');
    expect(flow.calls, ['continue']);
  });

  const steps = [
    {'id': 'n1', 'type': 'message-node', 'data': {'type': 'message-node'}},
    {'id': 'h1', 'type': 'human-handover-node', 'data': {'type': 'human-handover-node'}},
  ];

  test('restart: a live chat comes back live with its agent, the flow is not run again (#25)', () async {
    state.pushToRecord(RecordEntry(id: 'h1', shape: 'human-handover-node', type: 'human-handover-node'));
    state.setCurrentNodeId('h1');
    socket.answers['live-chat-state'] = {'status': 'live', 'agentDetails': {'_id': 'u1', 'name': 'Sam', 'email': 's@x.io'}};
    final step = await h.resumeRestored(steps: steps, agentBot: false);
    expect(step, RestoreStep.live);
    expect(socket.getEmittedEvents('join-chat-room-visitor'), isNotEmpty);
    expect(live, isTrue);
    expect(agent!.name, 'Sam');
    expect(lines().single.text, 'Sam joined the chat');
    expect(flow.calls, ['waitAt:h1:none']);
    expect(socket.wasEventEmitted('initiate-handover'), isFalse);
  });

  test('restart while still in the queue: back on the handover step, not asked again', () async {
    state.setCurrentNodeId('h1');
    socket.answers['live-chat-state'] = {'status': 'waiting'};
    expect(await h.resumeRestored(steps: steps, agentBot: false), RestoreStep.wait);
    expect(flow.calls, ['waitAt:h1:card']);
    expect(socket.wasEventEmitted('initiate-handover'), isFalse);
    clock.tick(20000);
    expect(signals, ['cb:waiting-for-human busy']);
  });

  test('restart after the chat ended: the line settles, the flow carries on', () async {
    final pending = RecordEntry(id: 'l1', shape: 'agent-left-chat', type: 'agent-left-chat', text: HandoverRecord.pendingText, data: {'handover': true});
    state.pushToRecord(pending);
    screen.add(SystemMessageRecord(id: 'l1', time: DateTime.now(), text: HandoverRecord.pendingText, kind: 'agent-left-chat', handover: true));
    state.setCurrentNodeId('h1');
    socket.answers['live-chat-state'] = {'status': 'ended'};
    expect(await h.resumeRestored(steps: steps, agentBot: false), RestoreStep.continueFlow);
    expect(lines().first.text, 'Chat ended before the team joined');
    expect(lines().last.text, 'Chat has ended');
    expect(live, isFalse);
    expect(flow.calls, ['waitAt:h1:none', 'continue']);
  });

  test('a restored record settles lines the record already knows, before asking', () async {
    state.pushToRecord(RecordEntry(id: 'l1', shape: 'agent-left-chat', type: 'agent-left-chat', text: HandoverRecord.pendingText, data: {'handover': true}));
    state.pushToRecord(RecordEntry(id: 'j1', shape: 'agent-joined-message', type: 'agent-joined-message', data: {'agentId': 'u1', 'name': 'Sam'}));
    screen
      ..add(SystemMessageRecord(id: 'l1', time: DateTime.now(), text: HandoverRecord.pendingText, kind: 'agent-left-chat', handover: true))
      ..add(SystemMessageRecord(id: 'j1', time: DateTime.now(), text: 'Sam joined the chat', kind: 'agent-joined-message'));
    socket.answers['live-chat-state'] = {'status': 'live', 'agentDetails': {'_id': 'u1', 'name': 'Sam'}};
    expect(await h.resumeRestored(steps: steps, agentBot: true), RestoreStep.live);
    expect(lines()[0].text, 'Connected with the team');
    expect(lines()[1].note, HandoverRecord.handedOverNote);
    // Already drawn: no second join line.
    expect(lines(), hasLength(2));
  });

  test('a restored chat with nothing live is not asked about', () async {
    state.pushToRecord(RecordEntry(id: 'n1', shape: 'message-node', type: 'message-node', text: 'hi'));
    state.setCurrentNodeId('n1');
    expect(await h.resumeRestored(steps: steps, agentBot: false), RestoreStep.start);
    expect(socket.asked, isEmpty);
  });
}
