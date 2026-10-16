// While you wait, end to end: the handover lifecycle
// (lib/src/core/live_chat/handover_lifecycle.dart) says where a wait for a
// person begins and ends and sends the signals; WaitingExtras
// (lib/src/core/waiting/waiting_extras.dart) draws the help card (6s in),
// the games (2.5s after the waiting signal) and the server's queue-help pick
// with "That solved it", against a fake socket on a fake clock. Ported from
// the RN SDK's __tests__/context/useWaitingExtras.test.ts (#40, #64).
import 'package:conferbot_flutter/src/core/live_chat/handover_lifecycle.dart';
import 'package:conferbot_flutter/src/core/live_chat/handover_state.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:conferbot_flutter/src/core/waiting/games_card.dart';
import 'package:conferbot_flutter/src/core/waiting/waiting_extras.dart';
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

  /// As the real engine: its change tells the lifecycle the step waits.
  void Function(bool waiting)? onWaitAt;

  @override
  bool get atHandover => here;
  @override
  Map<String, dynamic>? get handoverNodeData => data;
  @override
  bool waitAt(String nodeId, {required bool waiting}) {
    calls.add('waitAt:$nodeId:${waiting ? 'card' : 'none'}');
    here = true;
    onWaitAt?.call(waiting);
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

const _kb = {
  'categories': [
    {
      'name': 'Billing',
      'articles': [
        {'_id': 'a1', 'title': 'Downloading invoices', 'description': 'Find every invoice in one place.'},
      ],
    },
  ],
  'recentArticles': [],
};

const sid = 'sess-1';

class _Setup {
  _Setup({Map<String, dynamic>? customizations, Map<String, dynamic>? answers}) {
    final state = ChatState.instance;
    state.reset();
    state.initialize(chatSessionId: sid, visitorId: 'v1', botId: 'b1');
    state.pushToRecord(RecordEntry(id: 'u1', shape: 'user-message', type: 'user-message', text: 'Where can I download my invoices?'));
    socket.mockIsConnected = true;
    socket.answers.addAll(answers ?? const {});
    final c = customizations ?? const {'enableKnowledgeBase': true};
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
      setTimer: clock.set,
      clearTimer: clock.clear,
      waitStart: () => w.startWait(),
      waitEnd: () => w.endWait(),
    );
    w = WaitingExtras(
      socket: () => socket,
      sessionId: () => sid,
      record: () => ChatState.instance.getRecordForServer(),
      customizations: () => c,
      personJoined: () => h.personInChat,
      leftQueueHelped: () => h.leftQueueHelped(),
      lastShownId: () => screen.isEmpty ? 'u1' : screen.last.id,
      reducedMotion: () => false,
      setTimer: clock.set,
      clearTimer: clock.clear,
      now: () => clock.now.toDouble(),
    );
    w.bind(h.onSignal);
    h.setupListeners();
    w.setupListeners();
    w.setKnowledgeBase(_kb);
  }

  final socket = _Socket();
  final flow = _Flow();
  final clock = _Clock();
  final screen = <RecordItem>[];
  late final HandoverLifecycle h;
  late final WaitingExtras w;

  void escalate() => h.onAgentLeft({'reason': 'escalated', 'agentDetails': {'name': 'Ava', 'isAIAgent': true}});

  List<SystemMessageRecord> lines() => screen.whereType<SystemMessageRecord>().toList();

  Map<String, dynamic>? recordOf(String type) =>
      ChatState.instance.getRecordForServer().where((r) => r['type'] == type || r['shape'] == type).firstOrNull;
}

void main() {
  test('an AI passes them on: 6s in, the articles for their question, after the conversation so far', () {
    final t = _Setup();
    t.escalate();
    t.clock.tick(5999);
    expect(t.w.helpCard, isNull);
    t.clock.tick(1);
    final card = t.w.helpCard!;
    expect(card.solvable, isFalse);
    expect(card.items.map((i) => (i.id, i.title)), [('a1', 'Downloading invoices')]);
    // Drawn after the Connecting line, the newest thing on screen.
    expect(t.w.helpAfter, t.lines().last.id);
    // Never in the record.
    expect(ChatState.instance.getRecordForServer().any((r) => '${r['type']}'.contains('wait-help')), isFalse);
  });

  test('20s in the waiting signal, 2.5s later the games; a person joining folds the unused offer away', () {
    final t = _Setup();
    t.escalate();
    t.clock.tick(20000);
    expect(t.w.gamesCard, isNull);
    t.clock.tick(2500);
    expect(t.w.gamesCard!.state.view, 'menu');
    expect(t.w.gamesCard!.state.title, 'While you wait - fancy a quick game? 🎮');
    expect(t.w.gamesAfter, isNotNull);
    t.h.onAccepted({'agentDetails': {'_id': 'p1', 'name': 'Sam'}});
    expect(t.w.gamesCard, isNull);
    expect(t.w.gamesAfter, isNull);
    // The help card stays, as history.
    expect(t.w.helpCard!.settled, isTrue);
  });

  test('a game under way when a person joins: saved and folded away, "Finish my game"', () {
    final t = _Setup();
    t.escalate();
    t.clock.tick(22500);
    t.w.gamesCard!.open('ttt');
    t.h.onAccepted({'agentDetails': {'_id': 'p1', 'name': 'Sam'}});
    final s = t.w.gamesCard!.state;
    expect(s.view, 'paused');
    expect(s.title, "Sam's here!");
    expect(s.foot.single.label, 'Finish my game');
  });

  test('the games off: no offer; typing "play" is sent as words', () {
    final t = _Setup(customizations: const {
      'enableKnowledgeBase': true,
      'waitingGames': {'enabled': false},
    });
    t.escalate();
    t.clock.tick(30000);
    expect(t.w.gamesCard, isNull);
    expect(t.w.interceptPlay('play'), isFalse);
  });

  test('typing "play" while waiting opens the menu', () {
    final t = _Setup();
    t.escalate();
    expect(t.w.interceptPlay('play'), isFalse);
    t.clock.tick(20000);
    expect(t.w.interceptPlay("let's play"), isTrue);
    expect(t.w.gamesCard!.state.title, 'Pick a game');
  });

  test("the server's queue-help: That solved it leaves the queue, the article named, once", () async {
    final t = _Setup(answers: {
      'queue-self-resolve': {'ok': true},
    });
    t.escalate();
    t.socket.simulateEvent('queue-help', {
      'chatSessionId': sid,
      'items': [
        {'kind': 'article', 'id': 'k9', 'title': 'Invoices'},
      ],
      'offer': 1,
    });
    expect(t.w.helpCard!.solvable, isTrue);
    expect(t.w.helpCard!.items.single.id, 'k9');
    expect(await t.w.solveWait(), isTrue);
    expect(t.socket.getEmittedEvents('queue-self-resolve').single.data, {'chatSessionId': sid, 'articleId': 'k9'});
    expect(t.w.helpCard!.done, isTrue);
    expect(t.w.helpCard!.settled, isTrue);
    final left = t.lines().where((l) => l.kind == 'queue-self-resolved').toList();
    expect(left.single.text, 'You left the queue. Glad that helped.');
    expect(ChatState.instance.record.firstWhere((e) => e.shape == 'queue-self-resolved').text, 'Resolved while waiting');
    // The Connecting line settled as left.
    expect(t.lines().firstWhere((l) => l.kind == 'agent-left-chat').settled, 'cancelled');
    // The server's own queue-left after it: nothing twice.
    t.flow.here = true;
    t.socket.simulateEvent('queue-left', {'chatSessionId': sid, 'reason': 'self_service'});
    t.h.leftQueueHelped();
    expect(t.lines().where((l) => l.kind == 'queue-self-resolved'), hasLength(1));
  });

  test('That solved it refused: the button comes back, nothing recorded', () async {
    final t = _Setup(answers: {
      'queue-self-resolve': {'ok': false, 'reason': 'agent_joined'},
    });
    t.escalate();
    t.socket.simulateEvent('queue-help', {
      'items': [
        {'id': 'k9', 'title': 'Invoices'},
      ],
    });
    expect(await t.w.solveWait(), isFalse);
    final c = t.w.helpCard!;
    expect((c.busy, c.done, c.solvable), (false, false, true));
    expect(t.lines().any((l) => l.kind == 'queue-self-resolved'), isFalse);
  });

  test('a waiting queue-status: the server picks the help, ours stays out', () {
    final t = _Setup();
    t.escalate();
    t.w.onQueueStatus({'chatSessionId': sid, 'status': 'waiting', 'position': 2});
    t.clock.tick(6000);
    expect(t.w.helpCard, isNull);
    t.w.onQueueStatus({
      'chatSessionId': 'other',
      'status': 'waiting',
      'help': {
        'items': [
          {'id': 'x', 'title': 'X'},
        ],
      },
    });
    expect(t.w.helpCard, isNull);
    // Its own help comes as a card, with That solved it.
    t.w.onQueueStatus({
      'chatSessionId': sid,
      'status': 'waiting',
      'help': {
        'items': [
          {'id': 'x', 'title': 'X'},
        ],
      },
    });
    expect(t.w.helpCard!.items.single.id, 'x');
    expect(t.w.helpCard!.solvable, isTrue);
  });

  test('a help article: found in the help centre data, else null (the chat fetches it by id)', () {
    final t = _Setup();
    expect(t.w.articleById('a1')!['title'], 'Downloading invoices');
    expect(t.w.articleById('zz'), isNull);
  });

  test('the chat ending before 6s: no card, no games', () {
    final t = _Setup();
    t.escalate();
    t.socket.simulateEvent('chat-ended', {'chatSessionId': sid});
    t.clock.tick(30000);
    expect(t.w.helpCard, isNull);
    expect(t.w.gamesCard, isNull);
  });

  test('a new conversation: the cards go', () {
    final t = _Setup();
    t.escalate();
    t.clock.tick(22500);
    expect(t.w.helpCard, isNotNull);
    expect(t.w.gamesCard, isNotNull);
    final card = t.w.gamesCard!;
    t.w.reset();
    expect(t.w.helpCard, isNull);
    expect(t.w.gamesCard, isNull);
    expect(card.up, isFalse);
  });

  test('a flow handover with no AI agents starts the timer; with one it does not', () {
    final t = _Setup();
    t.h.setWaitingForPerson(true, {'assignedAIAgents': ['a1']});
    t.clock.tick(7000);
    expect(t.w.helpCard, isNull);
    t.h.setWaitingForPerson(false);
    t.h.setWaitingForPerson(true, const {});
    t.clock.tick(6000);
    expect(t.w.helpCard!.items.single.id, 'a1');
  });

  test('back in the queue (live-chat-requeued): the step waits again, no new help card', () {
    final t = _Setup();
    t.flow.here = true;
    t.flow.onWaitAt = (waiting) => t.h.setWaitingForPerson(waiting, const {});
    ChatState.instance.setCurrentNodeId('h1');
    t.socket.simulateEvent('live-chat-requeued', {'chatSessionId': sid});
    expect(t.flow.calls, ['waitAt:h1:card']);
    t.clock.tick(6000);
    expect(t.w.helpCard, isNull);
  });

  test('a restore that finds the step still waiting starts the timer', () async {
    final t = _Setup();
    ChatState.instance.setCurrentNodeId('h1');
    t.socket.answers['live-chat-state'] = {'status': 'waiting'};
    const steps = [
      {'id': 'h1', 'type': 'human-handover-node', 'data': {'type': 'human-handover-node'}},
    ];
    expect(await t.h.resumeRestored(steps: steps, agentBot: false), RestoreStep.wait);
    t.clock.tick(6000);
    expect(t.w.helpCard!.items.single.id, 'a1');
  });

  test('a restore with an AI agent on the step: no timer', () async {
    final t = _Setup();
    ChatState.instance.setCurrentNodeId('h1');
    t.socket.answers['live-chat-state'] = {'status': 'waiting'};
    const steps = [
      {
        'id': 'h1',
        'type': 'human-handover-node',
        'data': {
          'type': 'human-handover-node',
          'assignedAIAgents': ['ai1'],
        },
      },
    ];
    await t.h.resumeRestored(steps: steps, agentBot: false);
    t.clock.tick(6000);
    expect(t.w.helpCard, isNull);
  });

  test('the games card is never saved: no record entry, the view gone on Not now', () {
    final t = _Setup();
    t.escalate();
    t.clock.tick(22500);
    final card = t.w.gamesCard!;
    card.press('notNow');
    expect(card.state.view, 'gone');
    expect(t.w.gamesCard, isNull);
    expect(ChatState.instance.getRecordForServer().any((r) => '${r['type']}'.contains('games')), isFalse);
    expect(card, isA<GamesCard>());
  });
}
