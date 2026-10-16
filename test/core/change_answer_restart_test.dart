// "Edit" and a restart (Android #88: after rewindTo, a restart brought back
// the removed messages because its stores only appended). This SDK writes
// its stores whole, as RN does: the chat state (answers, transcript, record,
// the step) is saved from a full copy after the rewind, and the screen's
// message store drops each cut message by id. Both are read back here as a
// restart reads them (#51).
import 'dart:io';

import 'package:conferbot_flutter/src/core/flow/flow_context.dart';
import 'package:conferbot_flutter/src/core/node_flow_engine.dart';
import 'package:conferbot_flutter/src/core/nodes/node_handler_registry.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:conferbot_flutter/src/core/state/message_pagination_controller.dart';
import 'package:conferbot_flutter/src/core/state/message_storage_service.dart';
import 'package:conferbot_flutter/src/models/message.dart';
import 'package:conferbot_flutter/src/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TempPaths(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

class _Socket implements FlowSocket {
  @override
  void emit(String event, dynamic payload) {}
  @override
  void Function() on(String event, void Function(dynamic payload) listener) => () {};
  @override
  void sendResponseRecord(Map<String, dynamic> responseData) {}
}

Map<String, dynamic> _node(String id, String type, [Map<String, dynamic> data = const {}]) =>
    {'id': id, 'type': type, 'data': data, 'position': {'x': 0, 'y': 0}};

Map<String, dynamic> _edge(String source, String target) =>
    {'id': 'e-$source-$target', 'source': source, 'sourceHandle': 'source', 'target': target};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = ChatState.instance;
  const bot = 'b88';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _TempPaths(Directory.systemTemp.createTempSync('cb_edit_').path);
    await StorageService.init();
  });

  tearDown(() async {
    state.reset(clearPersistence: true);
    state.disablePersistence();
  });

  test('the chat state saved after the rewind has no trace of the removed answer', () async {
    state.reset(clearPersistence: true);
    state.enablePersistence();
    state.initialize(chatSessionId: 's88', visitorId: 'v1', botId: bot);
    final engine = NodeFlowEngine(socket: _Socket(), registry: NodeHandlerRegistry.withAll(), config: const NodeFlowEngineConfig(typingDelay: 0));
    engine.loadFlow([
      _node('w', 'welcome-node', {'text': '<p>Hi</p>', 'disableImage': true}),
      _node('q1', 'ask-name-node', {'questionText': '<p>Your name?</p>', 'answerVariable': 'name'}),
      _node('q2', 'ask-email-node', {'questionText': '<p>Your email?</p>', 'answerVariable': 'email'}),
    ], [
      _edge('w', 'q1'),
      _edge('q1', 'q2'),
    ]);
    await engine.start();
    await pumpEventQueue();
    await engine.submitResponse('Jamie');
    await pumpEventQueue();
    expect(state.getAnswer('name'), 'Jamie');
    final recordBefore = state.record.length;

    expect(await engine.rewindTo(engine.questionPoints.first.id), isTrue);
    await pumpEventQueue();
    // The debounced save after the rewind (no explicit save: what the app does).
    await Future<void>.delayed(const Duration(milliseconds: 800));
    engine.dispose();

    // A restart: the state as the device has it.
    state.reset();
    expect(await state.restoreFromPersistence(bot), isTrue);
    expect(state.getAnswer('name'), isNull);
    expect(state.transcript.where((e) => e.by == 'user'), isEmpty);
    expect(state.record.length, lessThan(recordBefore));
    expect(state.record.any((r) => r.text == 'Jamie' || '${r.data}'.contains('Jamie')), isFalse);
    expect(state.currentNodeId, 'q1');
  });

  test("the screen's message store drops the cut messages: a restart does not bring them back", () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await MessageStorageFactory.createDefault();
    final screen = MessagePaginationController(storageService: storage);
    await screen.initialize('s88');
    final t = DateTime.utc(2026, 10, 16, 10);
    final rows = [
      BotMessageRecord(id: 'm1', time: t, text: 'Your name?'),
      UserMessageRecord(id: 'm2', time: t, text: 'Jamie'),
      BotMessageRecord(id: 'm3', time: t, text: 'Your email?'),
    ];
    for (final r in rows) {
      await screen.addMessage(r);
    }
    // "Edit" on the name: the answer and what came after it are cut
    // (ConferBotProvider._cutRecordFrom), the question is asked again.
    for (final id in ['m2', 'm3']) {
      await screen.deleteMessage(id);
    }
    await screen.addMessage(BotMessageRecord(id: 'm4', time: t, text: 'Your name?'));
    screen.dispose();

    // A restart: a new store and list read what the device kept.
    final again = MessagePaginationController(storageService: await MessageStorageFactory.createDefault());
    await again.initialize('s88');
    expect(again.state.visibleMessages.map((m) => m.id), ['m1', 'm4']);
    expect(again.state.totalMessages, 2);
    again.dispose();
  });
}
