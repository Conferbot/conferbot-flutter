/// NodeFlowEngine against the shared flow-node spec (conferbot-react-native
/// scripts/parity/flows/nodes.spec.json, "engine"), as the chat UI uses it:
/// the lines it says, the step that waits and the answer it takes. The
/// spec's 156 fixtures run in test/parity/flows_test.dart; these cover the
/// engine's API around them (streams, handover hooks, customizations).
library;

import 'dart:async';

import 'package:conferbot_flutter/src/core/flow/flow_context.dart';
import 'package:conferbot_flutter/src/core/node_flow_engine.dart';
import 'package:conferbot_flutter/src/core/nodes/node_handler_registry.dart';
import 'package:conferbot_flutter/src/core/nodes/node_ui_state.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _Socket implements FlowSocket {
  final emits = <String>[];
  final listeners = <String, List<void Function(dynamic)>>{};
  int records = 0;

  void fire(String event, [dynamic payload]) {
    for (final l in List.of(listeners[event] ?? const <void Function(dynamic)>[])) {
      l(payload);
    }
  }

  @override
  void emit(String event, dynamic payload) => emits.add(event);

  @override
  void Function() on(String event, void Function(dynamic payload) listener) {
    listeners.putIfAbsent(event, () => []).add(listener);
    return () => listeners[event]?.remove(listener);
  }

  @override
  void sendResponseRecord(Map<String, dynamic> responseData) => records++;
}

Map<String, dynamic> _node(String id, String type, [Map<String, dynamic> data = const {}]) =>
    {'id': id, 'type': type, 'data': data, 'position': {'x': 0, 'y': 0}};

Map<String, dynamic> _edge(String source, String target, [String handle = 'source']) =>
    {'id': 'e-$source-$handle-$target', 'source': source, 'sourceHandle': handle, 'target': target};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Socket socket;
  late NodeFlowEngine engine;
  late List<Map<String, dynamic>> botLines;
  late List<Map<String, dynamic>> userLines;
  late List<FlowTraceEvent> trace;
  final subs = <StreamSubscription<dynamic>>[];

  NodeFlowEngine makeEngine({Map<String, dynamic>? customizations, int mediaAdvanceMs = 4000}) {
    final e = NodeFlowEngine(
      socket: socket,
      registry: NodeHandlerRegistry.withAll(),
      customizations: customizations,
      config: NodeFlowEngineConfig(typingDelay: 0, mediaAdvanceMs: mediaAdvanceMs, onTrace: trace.add),
    );
    subs.add(e.botMessageStream.listen(botLines.add));
    subs.add(e.userMessageStream.listen(userLines.add));
    return e;
  }

  Future<void> run(List<Map<String, dynamic>> nodes, List<Map<String, dynamic>> edges) async {
    engine.loadFlow(nodes, edges);
    // start() resolves once the flow waits or ends; a media step waits on
    // its picture, so it is not awaited here.
    unawaited(engine.start());
    await pumpEventQueue();
  }

  setUp(() {
    ChatState.instance.reset();
    ChatState.instance.initialize(chatSessionId: 's1', visitorId: 'v1', botId: 'b1');
    socket = _Socket();
    botLines = [];
    userLines = [];
    trace = [];
    engine = makeEngine();
  });

  tearDown(() async {
    for (final s in subs) {
      await s.cancel();
    }
    subs.clear();
    engine.dispose();
    ChatState.instance.reset();
  });

  test('starts at the first welcome-node and says each step, then the chat ends', () async {
    await run([
      _node('m0', 'message-node', {'text': '<p>not first</p>'}),
      _node('w', 'welcome-node', {'text': '<p>Hi</p>', 'image': 'https://cdn.test/w.gif'}),
      _node('m', 'message-node', {'text': '<p>Bye</p>'}),
    ], [
      _edge('w', 'm'),
    ]);
    expect(botLines.map((l) => l['text']), ['Hi', '', 'Bye']);
    expect(botLines[1]['imageUrl'], 'https://cdn.test/w.gif');
    expect(engine.isFlowComplete, isTrue);
    expect(socket.emits, ['chat-flow-completed']);
  });

  test('a choice step waits with its options and leaves by the picked id (#31)', () async {
    await run([
      _node('w', 'welcome-node', {'text': '<p>Hi</p>'}),
      _node('c', 'n-choices-node', {
        'choicePrompt': '<p>Pick</p>',
        'choices': [
          {'id': '1', 'choiceText': '<p>One</p>'},
          {'id': 'uuid-2', 'choiceText': '<p>Two</p>'},
        ],
        'answerVariable': 'picked',
      }),
      _node('two', 'message-node', {'text': '<p>You picked {picked}</p>'}),
    ], [
      _edge('w', 'c'),
      _edge('c', 'two', 'source-uuid-2'),
    ]);
    expect(engine.isWaitingForInput, isTrue);
    final ui = engine.currentUIState as SingleChoiceUIState;
    expect(ui.choices.map((c) => c.id), ['1', 'uuid-2']);
    await engine.submitResponse({'buttonId': 'uuid-2', 'label': 'Two'});
    await pumpEventQueue();
    expect(userLines.single['text'], 'Two');
    expect(botLines.last['text'], 'You picked Two');
    expect(ChatState.instance.getAnswer('picked'), 'Two');
  });

  test('an answer is ignored when no step waits, and a blank one always', () async {
    await run([
      _node('w', 'welcome-node', {'text': '<p>Hi</p>'}),
      _node('n', 'ask-name-node', {'questionText': '<p>Name?</p>', 'answerVariable': 'name'}),
    ], [
      _edge('w', 'n'),
    ]);
    await engine.submitResponse('   ');
    expect(engine.isWaitingForInput, isTrue);
    expect(userLines, isEmpty);
    await engine.submitResponse('ana gomez');
    await pumpEventQueue();
    expect(ChatState.instance.getAnswer('name'), 'ana gomez');
    expect(engine.isFlowComplete, isTrue);
    await engine.submitResponse('again');
    expect(userLines.length, 1);
  });

  test('an unknown step passes along its first edge; a missing exact handle ends the chat (#30)', () async {
    await run([
      _node('w', 'welcome-node', {'text': '<p>Hi</p>'}),
      _node('x', 'future-node'),
      _node('y', 'yes-or-no-choice-node', {'questionText': '<p>Ok?</p>'}),
      _node('z', 'message-node', {'text': '<p>never</p>'}),
    ], [
      _edge('w', 'x'),
      _edge('x', 'y', 'whatever'),
      _edge('y', 'z', 'source-1'),
    ]);
    expect(trace.where((e) => e.kind == 'unsupported').single.node, 'x');
    expect(engine.currentNodeId, 'y');
    await engine.submitResponse({'buttonId': '2'});
    await pumpEventQueue();
    final port = trace.where((e) => e.kind == 'port').single;
    expect([port.handle, port.wired], ['source-2', false]);
    expect(engine.isFlowComplete, isTrue);
    expect(botLines.map((l) => l['text']), isNot(contains('never')));
  });

  test("reads the step's type from the node, not its data (#31)", () async {
    await run([
      _node('w', 'welcome-node', {'text': '<p>Hi</p>'}),
      _node('u', 'user-input-node', {'type': 'email', 'inputPrompt': '<p>Email?</p>', 'answerVariable': 'email'}),
    ], [
      _edge('w', 'u'),
    ]);
    expect(engine.currentNodeType, 'user-input-node');
    expect(engine.isWaitingForInput, isTrue);
  });

  test('runs more than 100 steps without the visitor (no distinct-node cap, #30)', () async {
    final nodes = [_node('w', 'welcome-node', {'text': '<p>Hi</p>'})];
    final edges = <Map<String, dynamic>>[];
    var prev = 'w';
    for (var i = 0; i < 150; i++) {
      nodes.add(_node('m$i', 'message-node', {'text': '<p>$i</p>'}));
      edges.add(_edge(prev, 'm$i'));
      prev = 'm$i';
    }
    await run(nodes, edges);
    expect(engine.isFlowComplete, isTrue);
    expect(botLines.length, 151);
  });

  test('an image step moves on when its media settles, before the cap', () async {
    engine.dispose();
    engine = makeEngine(mediaAdvanceMs: 600000);
    await run([
      _node('w', 'welcome-node', {'text': '<p>Hi</p>'}),
      _node('i', 'image-node', {'image': 'https://cdn.test/a.png'}),
      _node('m', 'message-node', {'text': '<p>after</p>'}),
    ], [
      _edge('w', 'i'),
      _edge('i', 'm'),
    ]);
    expect(botLines.last['mediaNodeId'], 'i');
    expect(engine.isFlowComplete, isFalse);
    engine.mediaSettled('i');
    await pumpEventQueue();
    expect(botLines.last['text'], 'after');
    expect(engine.isFlowComplete, isTrue);
  });

  test('redactSensitive false keeps what the visitor typed (#33)', () async {
    engine.dispose();
    engine = makeEngine(customizations: {'redactSensitive': false});
    await run([
      _node('w', 'welcome-node', {'text': '<p>Hi</p>'}),
      _node('q', 'ask-custom-question-node', {'questionText': '<p>Card?</p>', 'answerVariable': 'card'}),
    ], [
      _edge('w', 'q'),
    ]);
    await engine.submitResponse('4242 4242 4242 4242');
    await pumpEventQueue();
    expect(ChatState.instance.getAnswer('card'), '4242 4242 4242 4242');
  });

  group('the handover step', () {
    final flow = [
      _node('w', 'welcome-node', {'text': '<p>Hi</p>'}),
      _node('ho', 'human-handover-node', {'handoverMessage': '<p>Connecting…</p>', 'fallbackMessage': '<p>Busy</p>'}),
      _node('after', 'message-node', {'text': '<p>after</p>'}),
    ];
    final edges = [_edge('w', 'ho'), _edge('ho', 'after')];

    test('asks for a person, waits, and carries on when the chat ends', () async {
      await run(flow, edges);
      // The handover message comes after a beat of typing.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await pumpEventQueue();
      expect(socket.emits, contains('initiate-handover'));
      expect(engine.isAtHandover, isTrue);
      expect((engine.currentUIState as HumanHandoverUIState).state, HandoverState.waitingForAgent);
      engine.handleAgentAccepted('Sam');
      expect((engine.currentUIState as HumanHandoverUIState).state, HandoverState.agentConnected);
      engine.handleChatEnded();
      await pumpEventQueue();
      expect(botLines.last['text'], 'after');
    });

    test('nobody free: the fallback, then on when leaving a message is off', () async {
      engine.dispose();
      engine = makeEngine(customizations: {'chatLeaveMessage': false});
      await run(flow, edges);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      socket.fire('no-agents-available');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await pumpEventQueue();
      expect(botLines.map((l) => l['text']), containsAllInOrder(['Busy', 'after']));
    });

    test('a restored chat waits on the step without asking again', () async {
      engine.loadFlow(flow, edges);
      expect(engine.waitAt('ho', const HumanHandoverUIState(state: HandoverState.waitingForAgent, nodeId: 'ho')), isTrue);
      expect(engine.isAtHandover, isTrue);
      expect(socket.emits, isEmpty);
      engine.continueAfterHandover();
      await pumpEventQueue();
      expect(botLines.last['text'], 'after');
      expect(engine.waitAt('missing', null), isFalse);
    });
  });
}
