/// Headless driver for the shared flow-node fixtures
/// (conferbot-react-native scripts/parity/flows, README "Using the fixtures
/// in an SDK"; copied to test/fixtures/parity_flows by
/// tool/sync_flow_fixtures.sh). A port of RN __tests__/parity/flowDriver.ts.
///
/// One case = a reset ChatState, a fresh registry and NodeFlowEngine. The
/// clock is virtual: the case runs in a Zone whose timers this driver
/// fires in time order, and the engine reads the same clock (2026-10-15
/// 10:00 UTC). The bot API answers from the case's `server.http` (a
/// MockClient), and a fake socket answers `execute-integration` and
/// `initiate-handover` from `server.integration` / `server.handover`. Each
/// visitor action is played through engine.submitResponse with the answer
/// the SDK's chat UI sends for it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conferbot_flutter/src/core/flow/flow_context.dart';
import 'package:conferbot_flutter/src/core/flow/text.dart' show plainText;
import 'package:conferbot_flutter/src/core/node_flow_engine.dart';
import 'package:conferbot_flutter/src/core/nodes/node_handler_registry.dart';
import 'package:conferbot_flutter/src/core/nodes/node_ui_state.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 2026-10-15 10:00 UTC, a Thursday.
final DateTime base = DateTime.utc(2026, 10, 15, 10);

const String fixturesDir = 'test/fixtures/parity_flows';

/// A fixture by file name.
Map<String, dynamic> loadFixture(String file) =>
    jsonDecode(File('$fixturesDir/$file').readAsStringSync()) as Map<String, dynamic>;

/// The fixtures' index.
List<Map<String, dynamic>> fixtureIndex() =>
    ((jsonDecode(File('$fixturesDir/index.json').readAsStringSync()) as Map)['cases'] as List)
        .cast<Map<String, dynamic>>();

// ----- Virtual clock (web/env.js) -----

class _VTimer implements Timer {
  final _Clock clock;
  final int id;
  int at;
  final int every;
  final Zone zone;
  final Function callback;
  bool _active = true;
  int _tick = 0;

  _VTimer(this.clock, this.id, this.at, this.every, this.zone, this.callback);

  @override
  void cancel() {
    _active = false;
    clock.timers.remove(id);
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  void fire() {
    if (every > 0) {
      _tick++;
      zone.runUnaryGuarded<Timer>(callback as void Function(Timer), this);
    } else {
      _active = false;
      zone.runGuarded(callback as void Function());
    }
  }
}

class _Clock {
  int now = 0;
  int seq = 0;
  final Map<int, _VTimer> timers = {};
  final List<String> errors = [];

  _VTimer add(Zone zone, Duration d, Function f, bool periodic) {
    final id = ++seq;
    final wait = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
    final t = _VTimer(this, id, now + wait, periodic ? (wait < 1 ? 1 : wait) : 0, zone, f);
    timers[id] = t;
    return t;
  }
}

Future<void> _flush([int n = 3]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// ----- The fake socket (web/fakeSocket.js) -----

class _FakeSocket implements FlowSocket {
  final Map<String, dynamic> server;
  final List<String> emits = [];
  final Map<String, List<void Function(dynamic)>> listeners = {};

  _FakeSocket(this.server);

  void fire(String event, dynamic payload) {
    for (final fn in List.of(listeners[event] ?? const <void Function(dynamic)>[])) {
      fn(payload);
    }
  }

  @override
  void Function() on(String event, void Function(dynamic payload) listener) {
    listeners.putIfAbsent(event, () => []).add(listener);
    return () => listeners[event]?.remove(listener);
  }

  @override
  void emit(String event, dynamic payload) {
    // The record resend and the room join are transport, not flow events.
    if (event != 'response-record' && event != 'join-chat-room-visitor') emits.add(event);
    if (event == 'execute-integration') {
      final p = payload is Map ? payload : const {};
      final integration = server['integration'] is Map ? server['integration'] as Map : const {};
      final r = integration[p['nodeId']] ?? integration[p['nodeType']] ?? const {'success': true};
      if (r != 'none') {
        final m = Map<String, dynamic>.from(r as Map);
        final delay = m['delayMs'] is num ? (m['delayMs'] as num).toInt() : 50;
        Timer(Duration(milliseconds: delay), () => fire('integration-result', {'nodeId': p['nodeId'], ...m}));
      }
    }
    if (event == 'initiate-handover' && server['handover'] == 'no-agents') {
      final sid = payload is Map ? payload['chatSessionId'] : null;
      Timer(const Duration(milliseconds: 1000), () => fire('no-agents-available', {'chatSessionId': sid}));
    }
  }

  @override
  void sendResponseRecord(Map<String, dynamic> responseData) {}
}

// ----- The bot API, scripted by server.http (web/driver.js) -----

MockClient _mockClient(Map<String, dynamic> server, List<Map<String, dynamic>> http_) {
  final calls = <String, int>{};
  return MockClient((req) async {
    final u = req.url.toString();
    final m = RegExp(r'/api/v1/bot/[^/]+/(.+?)(\?|$)').firstMatch(u);
    final key = m != null ? m.group(1)! : u;
    calls[key] = (calls[key] ?? 0) + 1;
    dynamic body;
    if (key != 'media') {
      try {
        body = req.body.isEmpty ? null : jsonDecode(req.body);
      } catch (_) {
        body = null;
      }
    }
    http_.add({'path': key, if (key != 'media' && body != null) 'body': body});
    final scripted = server['http'] is Map ? server['http'] as Map : const {};
    dynamic r = scripted[key];
    if (r is List) r = r[(calls[key]! - 1).clamp(0, r.length - 1)];
    if (r == null && key == 'media') {
      r = {
        'status': 200,
        'body': {'url': 'https://api.test/media/qa-file'}
      };
    }
    if (r == null || r == 'network') throw http.ClientException('Failed to fetch');
    final status = (r['status'] as num?)?.toInt() ?? 200;
    return http.Response(jsonEncode(r['body']), status, headers: {'content-type': 'application/json'});
  });
}

// ----- Visitor actions -> the answer the chat UI sends -----

/// The buttons / options a UI state shows: {id, label, value}.
List<Map<String, dynamic>> optionsOf(dynamic ui) {
  if (ui is SingleChoiceUIState) {
    return [for (final c in ui.choices) {'id': c.id, 'label': c.text, 'value': c.value}];
  }
  if (ui is MultipleChoiceUIState) {
    return [for (final o in ui.options) {'id': o.id, 'label': o.text, 'value': o.text}];
  }
  if (ui is DropdownUIState) {
    return [for (final o in ui.options) {'id': o.id, 'label': o.text, 'value': o.text}];
  }
  if (ui is ImageChoiceUIState) {
    return [for (final o in ui.images) {'id': o.id, 'label': o.label, 'value': o.label}];
  }
  if (ui is RankingUIState) {
    return [for (final o in ui.items) {'id': o.id, 'label': o.text, 'value': o.value}];
  }
  if (ui is QuizUIState) {
    return [
      for (var i = 0; i < ui.options.length; i++) {'id': (ui.extra['optionIds'] as List?)?[i] ?? 'option${i + 1}', 'label': ui.options[i], 'value': ui.options[i]}
    ];
  }
  return const [];
}

class _Answer {
  final dynamic response;
  final bool local;
  const _Answer(this.response, {this.local = false});
}

_Answer _answerFor(Map<String, dynamic> a, dynamic ui, Map<String, dynamic> memo, String nodeId) {
  switch (a['do']) {
    case 'text':
      return _Answer('${a['value']}');
    case 'choose':
      if (a.containsKey('buttonId')) return _Answer({'buttonId': a['buttonId']});
      if (a.containsKey('value')) return _Answer({'value': a['value']});
      final list = optionsOf(ui);
      if (a.containsKey('id')) {
        final b = list.where((x) => '${x['id']}' == '${a['id']}').firstOrNull;
        if (b == null) throw StateError('no shown option with id ${a['id']}');
        return _Answer({'buttonId': b['id'], 'label': b['label'], 'value': b['value']});
      }
      if (a.containsKey('index')) {
        final i = (a['index'] as num).toInt();
        if (i >= list.length) throw StateError('no shown option at index $i');
        final b = list[i];
        return _Answer({'buttonId': b['id'], 'label': b['label'], 'value': b['value'], 'index': i});
      }
      // carousel / product card: Continue
      return const _Answer({'action': 'continue'});
    case 'check':
      return _Answer({'buttonIds': a['ids']});
    case 'file':
      return _Answer({
        'file': {'name': a['name'], 'size': a['size'], 'type': a['type'], 'uri': 'file:///tmp/${a['name']}'}
      });
    case 'skip':
      return const _Answer({'skip': true});
    case 'navigateLink':
      return _Answer({'action': 'link', 'index': a['index']});
    case 'navigateDone':
      return const _Answer({'action': 'done'});
    case 'date':
      return _Answer('${a['value']}');
    case 'calendar':
      return _Answer({'date': a['date'], 'slot': a['slot']});
    case 'consent':
      return _Answer({'agreed': a['agreed'] == true});
    case 'slider':
    case 'datetime':
      return _Answer({'value': a['value']});
    case 'rankingMove':
      final order = List<String>.from(memo[nodeId]?['order'] ?? optionsOf(ui).map((x) => '${x['id']}'));
      final i = order.indexOf('${a['id']}');
      final j = i + (a['dir'] as num).toInt();
      if (i >= 0 && j >= 0 && j < order.length) {
        final t = order[i];
        order[i] = order[j];
        order[j] = t;
      }
      memo[nodeId] = {'order': order};
      return const _Answer(null, local: true);
    case 'rankingSubmit':
      return _Answer({'order': memo[nodeId]?['order'] ?? optionsOf(ui).map((x) => '${x['id']}').toList()});
    case 'matrix':
      final cells = Map<String, dynamic>.from(memo[nodeId]?['cells'] ?? const {});
      final multiple = ui is MatrixUIState && ui.mode == 'multiple';
      (a['cells'] as Map? ?? const {}).forEach((row, cols) {
        final list = cols is List ? cols : [cols];
        if (multiple) {
          cells['$row'] = {...(cells['$row'] as List? ?? const []), ...list}.toList();
        } else {
          cells['$row'] = list.last;
        }
      });
      memo[nodeId] = {'cells': cells};
      if (a['submit'] == false) return const _Answer(null, local: true);
      return _Answer({'cells': cells});
    case 'otpEmail':
      return _Answer({'action': 'send', 'email': a['email']});
    case 'otpCode':
      return _Answer({'action': 'verify', 'code': '${a['code']}'});
    case 'otpSkip':
      return const _Answer({'action': 'skip'});
    case 'addressManual':
      return _Answer({
        'action': 'manual',
        'line1': a['line1'],
        'city': a['city'],
        'region': a['region'],
        'postal': a['postal'],
        'country': a['country'],
      });
    case 'addressSearch':
      return _Answer({'action': 'search', 'q': a['q']});
    case 'addressPick':
      return _Answer({'action': 'pick', 'index': a['index']});
    case 'signTyped':
      return _Answer({'action': 'sign', 'method': 'typed', 'name': a['name'], 'fullName': a['fullName']});
    case 'signEmpty':
      return const _Answer({'action': 'sign', 'method': 'drawn', 'strokes': 0});
    case 'payOpen':
      return const _Answer({'action': 'open'});
    case 'payCancel':
      return const _Answer({'action': 'cancel'});
    case 'wait':
      return const _Answer(null, local: true);
  }
  throw StateError('unknown action ${a['do']}');
}

// ----- Outcome (web/driver.js `outcome`) -----

const _strip = {'time', 'at', 'agreedAt', 'options', 'choices', 'images', 'carousel', '_id'};

dynamic _clean(dynamic o) {
  if (o is List) return o.map(_clean).toList();
  if (o is! Map) return o;
  final out = <String, dynamic>{};
  // A key that is there keeps its null (JavaScript's null, not undefined).
  o.forEach((k, v) {
    if (!_strip.contains(k)) out['$k'] = _clean(v);
  });
  return out;
}

/// What the run produced, in the fixtures' `expect` shape, plus the
/// driver's own problems (an action the engine was not waiting for...).
class RunResult {
  final Map<String, dynamic> outcome;
  final List<String> problems;
  const RunResult(this.outcome, this.problems);
}

/// A visitor action as a step's card sends it (test/widgets/step_views_test.dart):
/// called before each action with the waiting step's UI state, its visit and
/// its refusal; returns the card's answer (`local`: the card kept it to
/// itself), or null for the driver's own.
typedef ViewAnswer = ({dynamic response, bool local})? Function(
    int index, Map<String, dynamic> action, dynamic ui, int visit, String? error);

/// Plays one fixture through the engine; [answer] plays the actions as the cards send them.
Future<RunResult> runFixture(Map<String, dynamic> fx, {ViewAnswer? answer}) async {
  final clock = _Clock();
  final problems = <String>[];
  final trace = <(FlowTraceEvent, int)>[];
  final httpCalls = <Map<String, dynamic>>[];
  final server = Map<String, dynamic>.from(fx['server'] as Map? ?? const {});
  final socket = _FakeSocket(server);
  final randoms = List<num>.from(fx['random'] as List? ?? const []);

  final zone = Zone.current.fork(
    specification: ZoneSpecification(
      createTimer: (self, parent, zone, d, f) => clock.add(zone, d, f, false),
      createPeriodicTimer: (self, parent, zone, d, f) => clock.add(zone, d, f, true),
      handleUncaughtError: (self, parent, zone, e, st) => clock.errors.add('$e\n$st'),
      print: (self, parent, zone, line) {
        if (Platform.environment['FLOW_DEBUG'] != null) parent.print(zone, line);
      },
    ),
  );

  /// Run until the engine waits for the visitor: every timeout in time
  /// order; when only repeating timers are left (a resend countdown, a
  /// status poll) it stops. With `waitMs`, time runs on - intervals
  /// included - that long.
  Future<void> settle([int? waitMs]) async {
    final explicit = waitMs != null;
    final limit = clock.now + (explicit ? waitMs : 30 * 60 * 1000);
    for (var guard = 0; guard < 200000; guard++) {
      await _flush();
      _VTimer? next;
      for (final t in clock.timers.values) {
        if (!explicit && t.every > 0) continue;
        if (next == null || t.at < next.at || (t.at == next.at && t.id < next.id)) next = t;
      }
      if (next == null || next.at > limit) {
        if (explicit && clock.now < limit) clock.now = limit;
        await _flush();
        return;
      }
      if (next.at > clock.now) clock.now = next.at;
      if (next.every > 0) {
        next.at = clock.now + next.every;
      } else {
        clock.timers.remove(next.id);
      }
      next.fire();
    }
  }

  final state = ChatState.instance;
  late NodeFlowEngine engine;
  zone.run(() {
    state.reset();
    state.initialize(chatSessionId: 'qa-session', visitorId: 'qa-visitor', botId: 'qa-bot');
    engine = NodeFlowEngine(
      socket: socket,
      registry: NodeHandlerRegistry.withAll(),
      customizations: Map<String, dynamic>.from(fx['customizations'] as Map? ?? const {}),
      config: NodeFlowEngineConfig(
        apiOrigin: 'https://api.test',
        httpClient: _mockClient(server, httpCalls),
        visitorTimeZone: (fx['visitorTimeZone'] ?? 'UTC').toString(),
        page: const {
          'url': 'https://shop.example/pricing?utm_source=newsletter&utm_campaign=fall',
          'referrer': 'https://www.google.com/',
        },
        random: () => (randoms.length > 1 ? randoms.removeAt(0) : (randoms.isNotEmpty ? randoms.first : 0.5)).toDouble(),
        now: () => base.add(Duration(milliseconds: clock.now)),
        onTrace: (e) => trace.add((e, clock.now)),
      ),
    );
    final flow = jsonDecode(jsonEncode(fx['flow'])) as Map<String, dynamic>;
    engine.loadFlow(flow['nodes'] as List, flow['edges'] as List);
    engine.start().catchError((Object e) => problems.add('start: $e'));
  });
  await settle();

  final memo = <String, dynamic>{};
  final inputs = (fx['inputs'] as List? ?? const []).cast<Map<String, dynamic>>();
  for (var i = 0; i < inputs.length; i++) {
    final a = inputs[i];
    final at = engine.currentNodeId;
    if (a['do'] != 'serverEvent') {
      if (a['at'] != null && a['at'] != at) problems.add('input $i: waiting at $at, fixture expected ${a['at']}');
      if (!engine.isWaitingForInput && a['do'] != 'wait') problems.add('input $i (${a['do']}): engine is not waiting (at $at)');
    }
    try {
      if (a['do'] == 'serverEvent') {
        zone.run(() => socket.fire('${a['event']}', a['payload']));
      } else {
        final view = answer?.call(i, a, engine.currentUIState, engine.stepVisit, engine.validationMessage);
        final ans = view != null ? _Answer(view.response, local: view.local) : _answerFor(a, engine.currentUIState, memo, '$at');
        if (!ans.local) {
          zone.run(() => engine.submitResponse(ans.response).catchError((Object e) => problems.add('input $i: $e')));
        }
      }
    } catch (e) {
      problems.add('input $i (${a['do']}): $e');
    }
    final waitMs = a['waitMs'] is num ? (a['waitMs'] as num).toInt() : null;
    await settle(waitMs);
    if (waitMs != null) await settle();
  }

  final shownAt = <String, int>{};
  final shownOrder = <String>[];
  for (final (e, t) in trace) {
    if (e.kind == 'shown' && !shownAt.containsKey(e.node)) {
      shownAt[e.node!] = t;
      shownOrder.add(e.node!);
    }
  }
  final record = state.getRecord();
  final nodeRecords = record.where((r) => r['type'] != null && r['shape'] == null && r['source'] == null && r['renderedText'] != null);
  final flowVariables = <String, dynamic>{};
  state.variables.forEach((k, v) {
    if (!k.startsWith('_')) flowVariables[k] = v;
  });
  final crash = trace.where((x) => x.$1.kind == 'crash').firstOrNull;
  final endEvent = trace.where((x) => x.$1.kind == 'end').firstOrNull;
  final waitingAt = engine.currentNodeId;
  final outcome = <String, dynamic>{
    'path': [
      for (final (e, t) in trace)
        if (e.kind == 'enter') {'node': e.node, 'type': e.type, 'via': e.via, 't': t}
    ],
    'shown': [for (final n in shownOrder) {'node': n, 't': shownAt[n]}],
    'rendered': [
      for (final r in nodeRecords) {'node': r['id'], 'html': r['renderedText'], 'plain': plainText(r['renderedText'])}
    ],
    'ports': [
      for (final (e, _) in trace)
        if (e.kind == 'port') {'node': e.node, 'handle': e.handle, 'wired': e.wired}
    ],
    'answers': [
      for (final r in record)
        if (r['shape'] != null
            ? '${r['shape']}'.startsWith('user')
            : '${r['type'] ?? ''}'.startsWith('user') && r['data'] == null && r['position'] == null)
          _clean(r)
    ],
    'variables': [for (final v in state.answerVariables) {'key': v.key, 'value': v.value, 'nodeId': v.nodeId}],
    if (flowVariables.isNotEmpty) 'flowVariables': flowVariables,
    'errors': [
      for (final (e, _) in trace)
        if (e.kind == 'error') {'node': e.node, 'message': e.message}
    ],
    'http': httpCalls,
    'emits': socket.emits,
    'unsupported': [
      for (final (e, _) in trace)
        if (e.kind == 'unsupported') {'node': e.node, 'type': e.type}
    ],
    'end': engine.isEnded()
        ? {'ended': true, 't': endEvent?.$2}
        : {'ended': false, 'waitingAt': waitingAt, 'type': waitingAt == null ? null : engine.getNode(waitingAt)?['type']},
    'transcript': [for (final x in state.transcript) {'by': x.by, 'message': x.message}],
  };
  if (crash != null) outcome['end'] = {'ended': false, 'crashed': true, 'at': crash.$1.node, 'reason': crash.$1.reason};
  problems.addAll(clock.errors.map((e) => 'uncaught: $e'));
  zone.run(() {
    engine.dispose();
    for (final t in List.of(clock.timers.values)) {
      t.cancel();
    }
  });
  return RunResult(outcome, problems);
}
