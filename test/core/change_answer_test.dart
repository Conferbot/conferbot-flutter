// "Edit" on an answer (web index.ts _noteQuestionPoint / _rewindToQuestion,
// ts/chat/delight/index.ts), the React Native SDK's
// __tests__/core/changeAnswer.test.ts ported: the engine keeps a point for
// each question, says what ran since, and goes back to it - the
// conversation's state as it was, the question asked again.
import 'package:conferbot_flutter/src/core/delight/delight.dart';
import 'package:conferbot_flutter/src/core/flow/flow_context.dart';
import 'package:conferbot_flutter/src/core/node_flow_engine.dart';
import 'package:conferbot_flutter/src/core/nodes/node_handler_registry.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _Socket implements FlowSocket {
  int records = 0;
  @override
  void emit(String event, dynamic payload) {}
  @override
  void Function() on(String event, void Function(dynamic payload) listener) => () {};
  @override
  void sendResponseRecord(Map<String, dynamic> responseData) => records++;
}

Map<String, dynamic> _node(String id, String type, [Map<String, dynamic> data = const {}]) =>
    {'id': id, 'type': type, 'data': data, 'position': {'x': 0, 'y': 0}};

Map<String, dynamic> _edge(String source, String target) =>
    {'id': 'e-$source-$target', 'source': source, 'sourceHandle': 'source', 'target': target};

final _nodes = [
  _node('w', 'welcome-node', {'text': '<p>Hi</p>', 'disableImage': true}),
  _node('q1', 'ask-name-node', {'questionText': '<p>Your name?</p>', 'answerVariable': 'name'}),
  _node('m', 'message-node', {'text': '<p>Thanks {name}</p>'}),
  _node('q2', 'ask-email-node', {'questionText': '<p>Your email?</p>', 'answerVariable': 'email'}),
  _node('q3', 'ask-file-node', {'questionText': '<p>A file?</p>'}),
];
final _edges = [_edge('w', 'q1'), _edge('q1', 'm'), _edge('m', 'q2'), _edge('q2', 'q3')];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Socket socket;

  setUp(() {
    ChatState.instance.reset();
    ChatState.instance.initialize(chatSessionId: 's1', visitorId: 'v1', botId: 'b1');
    socket = _Socket();
  });

  Future<NodeFlowEngine> start() async {
    final engine = NodeFlowEngine(socket: socket, registry: NodeHandlerRegistry.withAll(), config: const NodeFlowEngineConfig(typingDelay: 0));
    engine.loadFlow(_nodes, _edges);
    await engine.start();
    await pumpEventQueue();
    return engine;
  }

  Future<void> answer(NodeFlowEngine engine, String text) async {
    await engine.submitResponse(text);
    await pumpEventQueue();
  }

  final state = ChatState.instance;

  test('keeps a point for each question, before it is drawn', () async {
    final engine = await start();
    final points = engine.questionPoints;
    expect(points.map((p) => p.nodeId), ['q1']);
    // Taken before the question's own record entry.
    expect(state.record[points[0].recordLen].id, 'q1');
    expect(state.transcript.any((e) => e.nodeId == 'q1'), isTrue);
    engine.dispose();
  });

  test('says what ran since a question; a message is safe to undo, a file step is not', () async {
    final engine = await start();
    await answer(engine, 'Jamie');
    final p1 = engine.questionPoints[0];
    final p2 = engine.questionPoints[1];
    expect(p2.nodeId, 'q2');
    expect(engine.typesSince(p1), ['message-node', 'ask-email-node']);
    final since = engine.typesSince(p1);
    expect(Delight.canChangeAnswer(p1.type, since.sublist(0, since.length - 1)), isTrue);
    await answer(engine, 'jamie@example.com');
    // The file step acts on the world: the email can no longer be changed.
    expect(engine.typesSince(engine.questionPoints[1]), ['ask-file-node']);
    expect(Delight.canChangeAnswer('ask-email-node', ['ask-file-node']), isFalse);
    engine.dispose();
  });

  test('goes back: the state as it was, the question asked again, a new answer taken', () async {
    final engine = await start();
    await answer(engine, 'Jamie');
    expect(state.getAnswer('name'), 'Jamie');
    expect(engine.currentNodeId, 'q2');
    final transcriptBefore = state.transcript.length;
    final recordsBefore = socket.records;

    final p1 = engine.questionPoints[0];
    expect(await engine.rewindTo(p1.id), isTrue);
    await pumpEventQueue();

    expect(engine.currentNodeId, 'q1');
    expect(engine.isWaitingForInput, isTrue);
    expect(state.getAnswer('name'), isNull);
    // The answer and everything after it are gone; the question is asked again.
    expect(state.transcript.length, lessThan(transcriptBefore));
    expect(state.transcript.where((e) => e.by == 'user'), isEmpty);
    // The record goes to the server as it is now.
    expect(socket.records, greaterThan(recordsBefore));
    // Points after it are gone; the question has a new one.
    expect(engine.questionPoints.map((p) => p.nodeId), ['q1']);
    expect(engine.questionPoints[0].id, isNot(p1.id));

    await answer(engine, 'Sam');
    expect(state.getAnswer('name'), 'Sam');
    expect(engine.currentNodeId, 'q2');
    engine.dispose();
  });

  test('refuses a point that is gone, and once the chat is over', () async {
    final engine = await start();
    expect(await engine.rewindTo(999), isFalse);
    // A flow that ended (q2's answer, the file step skipped) cannot go back.
    final ended = NodeFlowEngine(socket: socket, registry: NodeHandlerRegistry.withAll(), config: const NodeFlowEngineConfig(typingDelay: 0));
    ended.loadFlow([_nodes[0], _nodes[1]], [_edges[0]]);
    await ended.start();
    await pumpEventQueue();
    final point = ended.questionPoints.single;
    await answer(ended, 'Jamie');
    expect(ended.isFlowComplete, isTrue);
    expect(await ended.rewindTo(point.id), isFalse);
    engine.dispose();
    ended.dispose();
  });

  test('counts a person in the conversation since as not safe', () async {
    final engine = await start();
    final p1 = engine.questionPoints[0];
    state.pushToRecord(RecordEntry(id: 'a1', shape: 'agent-message', type: 'agent-message', text: 'Hi'));
    expect(engine.typesSince(p1), contains('agent'));
    expect(Delight.canChangeAnswer('ask-name-node', engine.typesSince(p1)), isFalse);
    engine.dispose();
  });

  test('puts a saved state back in place, keeping its listeners', () {
    state.saveVariableByName('name', 'Jamie', 'q1');
    final snap = state.snapshot();
    state.saveVariableByName('name', 'Sam', 'q1');
    state.addUserMessage('Sam', 'q1');
    var heard = 0;
    void listener() => heard++;
    state.addListener(listener);
    state.restore(snap);
    state.removeListener(listener);
    expect(state.getAnswer('name'), 'Jamie');
    expect(state.transcript, isEmpty);
    expect(state.chatSessionId, 's1');
    expect(heard, greaterThan(0));
  });
}
