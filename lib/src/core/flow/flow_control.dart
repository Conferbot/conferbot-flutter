/// Loops and sub-flows, the pure half - ported unchanged from the web widget
/// (conferbot-widget/src/ts/chat/flowControl.ts) via the React Native SDK's
/// src/core/flow/flowControl.ts. The engine runs them (NodeFlowEngine
/// runFlowControl). Twins: embed-server
/// services/omnichannel/nodeHandlers/flowControl.js, the builder's
/// utils/flowControl.ts. Keep them in step.
library;

import 'dart:convert';

import 'js.dart';

const String loopType = 'loop-node';
const String subflowType = 'subflow-node';
const String runSubflowType = 'run-subflow-node';
const String subflowReturnType = 'subflow-return-node';
const List<String> flowControlTypes = [loopType, subflowType, runSubflowType, subflowReturnType];
bool isFlowControlType(dynamic type) => flowControlTypes.contains(type);

const String loopBodyHandle = 'source-loop';
const String loopDoneHandle = 'source-done';
const String runErrorHandle = 'source-error';

const int loopDefaultCap = 20;
const int loopHardCap = 100;
const int subflowMaxDepth = 5;
final RegExp _varRe = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

typedef Lookup = dynamic Function(String key);

class LoopState {
  /// Rounds started so far.
  int i;
  int total;
  List<dynamic>? items;

  /// The list or count was longer than the cap.
  bool capped;

  LoopState({required this.i, required this.total, this.items, this.capped = false});

  Map<String, dynamic> toJson() => {'i': i, 'total': total, 'items': items, 'capped': capped};
}

class CallFrame {
  final String runNodeId;
  final String subflowId;
  final String name;

  /// `{from, to}` pairs.
  final List<Map<String, String>> outputs;
  final int depth;

  const CallFrame({required this.runNodeId, required this.subflowId, required this.name, required this.outputs, required this.depth});

  Map<String, dynamic> toJson() => {'runNodeId': runNodeId, 'subflowId': subflowId, 'name': name, 'outputs': outputs, 'depth': depth};
}

class FlowControlState {
  final Map<String, LoopState> loops;
  List<CallFrame> stack;

  FlowControlState({Map<String, LoopState>? loops, List<CallFrame>? stack})
      : loops = loops ?? {},
        stack = stack ?? [];

  Map<String, dynamic> toJson() => {
        'loops': loops.map((k, v) => MapEntry(k, v.toJson())),
        'stack': stack.map((f) => f.toJson()).toList(),
      };
}

FlowControlState emptyFlowControl() => FlowControlState();

bool _finite(dynamic v) => v is num && v.isFinite;

/// A saved state, checked (it comes back from the visitor's storage).
FlowControlState restoreFlowControl(dynamic saved) {
  final out = emptyFlowControl();
  if (saved is! Map) return out;
  final loops = saved['loops'];
  if (loops is Map) {
    loops.forEach((id, s) {
      if (s is Map && _finite(s['i']) && _finite(s['total'])) {
        out.loops[id.toString()] = LoopState(
          i: (s['i'] as num).toInt(),
          total: (s['total'] as num).toInt(),
          items: s['items'] is List ? List<dynamic>.from(s['items'] as List) : null,
          capped: jsTruthy(s['capped']),
        );
      }
    });
  }
  final stack = saved['stack'];
  if (stack is List) {
    out.stack = stack
        .where((f) => f is Map && f['runNodeId'] is String && f['subflowId'] is String)
        .take(subflowMaxDepth)
        .map((f) {
      final m = f as Map;
      final depth = jsNumber(m['depth']);
      return CallFrame(
        runNodeId: m['runNodeId'] as String,
        subflowId: m['subflowId'] as String,
        name: jsTruthy(m['name']) ? jsString(m['name']) : '',
        outputs: m['outputs'] is List
            ? (m['outputs'] as List)
                .where((o) => o is Map && jsTruthy(o['from']) && jsTruthy(o['to']))
                .map((o) => {'from': jsString((o as Map)['from']), 'to': jsString(o['to'])})
                .toList()
            : <Map<String, String>>[],
        depth: (depth.isNaN || depth == 0) ? 1 : depth.toInt(),
      );
    }).toList();
  }
  return out;
}

String _str(dynamic v) => v == null ? '' : jsString(v);
String _clean(dynamic v) => _str(v).replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').trim();

/// Fill {var} placeholders from the lookup ("" for unknown ones).
String fillText(dynamic text, Lookup lookup) => _str(text).replaceAllMapped(RegExp(r'\$?\{(\w+)\}'), (m) {
      final v = lookup(m.group(1)!);
      if (v == null) return '';
      return (v is Map || v is List) ? jsonStringify(v) : jsString(v);
    });

/// The loop's variable name: data.variable, else "loop".
String loopVarName(dynamic data) {
  final v = _clean(data is Map ? data['variable'] : null);
  return _varRe.hasMatch(v) ? v : 'loop';
}

/// The cap: data.maxIterations, 1..100, default 20.
int loopCap(dynamic data) {
  final raw = data is Map ? data['maxIterations'] : null;
  // Number(undefined) is NaN; null reads 0 - both fall back to the default.
  final n = jsNumber(raw).floorToDouble();
  if (!n.isFinite || n < 1) return loopDefaultCap;
  return n < loopHardCap ? n.toInt() : loopHardCap;
}

/// A list from a variable's value: an array, a JSON array, or a comma /
/// new-line separated text. Anything else is no list.
List<dynamic> listOf(dynamic value) {
  if (value is List) return value;
  if (value == null) return [];
  if (value is Map) return [];
  final t = jsString(value).trim();
  if (t.isEmpty) return [];
  if (t.startsWith('[')) {
    try {
      final parsed = jsonDecode(t);
      if (parsed is List) return parsed;
    } catch (_) {
      // not JSON: a plain list below
    }
  }
  return t.split(RegExp(r'\s*(?:,|\n)\s*')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

/// How many rounds: a number, or a {var} holding one.
int loopCount(dynamic data, Lookup lookup) {
  final raw = data is Map ? data['count'] : null;
  final n = raw is num ? raw.toDouble() : jsNumber(fillText(raw, lookup).trim());
  return n.isFinite && n > 0 ? n.floor() : 0;
}

/// First arrival: how many rounds and over which items.
LoopState startLoop(dynamic data, Lookup lookup) {
  final cap = loopCap(data);
  final d = data is Map ? data : const {};
  if (d['mode'] == 'each') {
    final key = _clean(d['listVariable']).replaceAll(RegExp(r'^\{|\}$'), '');
    final items = listOf(key.isNotEmpty ? lookup(key) : null);
    return LoopState(
      i: 0,
      total: items.length < cap ? items.length : cap,
      items: items.take(cap).toList(),
      capped: items.length > cap,
    );
  }
  final n = loopCount(data, lookup);
  return LoopState(i: 0, total: n < cap ? n : cap, items: null, capped: n > cap);
}

/// An item as variable text ({x_item}): plain values as they are, objects as JSON.
dynamic itemValue(dynamic item) => (item is Map || item is List) ? jsonStringify(item) : item;

/// What the inbox shows for one loop arrival.
class LoopTrail {
  final int iteration;
  final int total;
  final dynamic item;
  final bool? done;
  final bool? capped;
  final String variable;

  const LoopTrail({required this.iteration, required this.total, this.item, this.done, this.capped, required this.variable});

  Map<String, dynamic> toJson() => {
        'iteration': iteration,
        'total': total,
        if (item != null) 'item': item,
        if (done != null) 'done': done,
        if (capped != null) 'capped': capped,
        'variable': variable,
      };
}

class LoopStep {
  /// [loopBodyHandle] or [loopDoneHandle].
  final String handle;

  /// Variables to set (empty on Done).
  final Map<String, dynamic> vars;
  final LoopTrail trail;

  const LoopStep({required this.handle, required this.vars, required this.trail});
}

/// The loop step: start the next round or leave by Done. Mutates `state`
/// (the per-loop entry is created, advanced, then dropped on Done).
LoopStep stepLoop(String nodeId, dynamic data, FlowControlState state, Lookup lookup) {
  final name = loopVarName(data);
  final s = state.loops[nodeId] ??= startLoop(data, lookup);
  if (s.i < s.total) {
    s.i += 1;
    final dynamic item = s.items != null ? s.items![s.i - 1] : s.i;
    return LoopStep(
      handle: loopBodyHandle,
      vars: {'${name}_index': s.i, '${name}_item': itemValue(item), '${name}_count': s.total},
      trail: LoopTrail(iteration: s.i, total: s.total, item: s.items != null ? itemValue(item) : null, variable: name),
    );
  }
  state.loops.remove(nodeId);
  return LoopStep(
    handle: loopDoneHandle,
    vars: {},
    trail: LoopTrail(iteration: s.i, total: s.total, done: true, capped: s.capped ? true : null, variable: name),
  );
}

/// "Loop 3 of 5 · Apples", "Loop done · 5 rounds", for trails.
String loopTrailText(LoopTrail t) {
  if (t.done == true) {
    final rounds = '${t.total} round${t.total == 1 ? '' : 's'}';
    return t.capped == true ? 'Loop stopped at the safety cap · $rounds' : 'Loop done · $rounds';
  }
  String item = '';
  if (!(t.item == null || t.item == '')) {
    final text = jsString(t.item);
    item = ' · ${text.length > 60 ? text.substring(0, 60) : text}';
  }
  return 'Loop ${t.iteration} of ${t.total}$item';
}

// ---------------------------------------------------------------------------
// Sub-flows
// ---------------------------------------------------------------------------

String subflowName(dynamic node) {
  final data = node is Map ? node['data'] : null;
  final n = _clean(data is Map ? data['name'] : null);
  return n.isNotEmpty ? n : 'Sub-flow';
}

class SubflowCall {
  final bool ok;

  /// "missing" (no such start), "depth" (too deep), "recursion" (calls itself).
  final String? error;
  final String? startId;
  final String? name;
  final Map<String, dynamic> vars;
  final CallFrame? frame;

  const SubflowCall({required this.ok, this.error, this.startId, this.name, required this.vars, this.frame});
}

/// Run sub-flow: find the start, check depth / recursion, fill the inputs.
/// Pushes the call frame onto `state.stack` when it can run.
SubflowCall callSubflow(dynamic runNode, List<dynamic>? nodes, FlowControlState state, Lookup lookup) {
  final rn = runNode is Map ? runNode : const {};
  final d = rn['data'] is Map ? rn['data'] as Map : const {};
  Map? target;
  for (final n in nodes ?? const []) {
    if (n is Map && jsString(n['id']) == _str(d['subflowId']) && n['type'] == subflowType) {
      target = n;
      break;
    }
  }
  if (target == null) return const SubflowCall(ok: false, error: 'missing', vars: {});
  final name = subflowName(target);
  final targetId = jsString(target['id']);
  if (state.stack.length >= subflowMaxDepth) return SubflowCall(ok: false, error: 'depth', name: name, vars: const {});
  if (state.stack.any((f) => f.subflowId == targetId)) {
    return SubflowCall(ok: false, error: 'recursion', name: name, vars: const {});
  }
  final vars = <String, dynamic>{};
  for (final m in (d['inputs'] is List ? d['inputs'] as List : const [])) {
    final key = _clean(m is Map ? m['name'] : null);
    if (_varRe.hasMatch(key)) vars[key] = fillText(m is Map ? m['value'] : null, lookup);
  }
  final outputs = <Map<String, String>>[];
  for (final m in (d['outputs'] is List ? d['outputs'] as List : const [])) {
    final from = _clean(m is Map ? m['name'] : null);
    final variable = _clean(m is Map ? m['variable'] : null);
    final to = variable.isNotEmpty ? variable : from;
    if (_varRe.hasMatch(from) && _varRe.hasMatch(to)) outputs.add({'from': from, 'to': to});
  }
  final frame = CallFrame(
    runNodeId: jsString(rn['id']),
    subflowId: targetId,
    name: name,
    outputs: outputs,
    depth: state.stack.length + 1,
  );
  state.stack.add(frame);
  return SubflowCall(ok: true, startId: targetId, name: name, vars: vars, frame: frame);
}

class SubflowReturn {
  final CallFrame frame;
  final Map<String, dynamic> vars;

  const SubflowReturn({required this.frame, required this.vars});
}

/// The sub-flow ended: pop the frame and read its outputs. null when not in one.
SubflowReturn? returnFromSubflow(FlowControlState state, Lookup lookup) {
  if (state.stack.isEmpty) return null;
  final frame = state.stack.removeLast();
  final vars = <String, dynamic>{};
  for (final o in frame.outputs) {
    final v = lookup(o['from']!);
    vars[o['to']!] = v ?? '';
  }
  return SubflowReturn(frame: frame, vars: vars);
}

const Map<String, String> subflowErrors = {
  'missing': 'The sub-flow it runs no longer exists',
  'depth': 'Sub-flows can call each other at most $subflowMaxDepth deep',
  'recursion': "A sub-flow can't run itself",
};
