/// The shared flow-node spec, run through this SDK's NodeFlowEngine and
/// handlers (conferbot-react-native scripts/parity/flows: nodes.spec.json +
/// 156 fixtures whose outcomes come from running the web widget's own
/// code; copied here by tool/sync_flow_fixtures.sh). A port of RN
/// __tests__/parity/flows.test.ts.
///
/// Compared, per the fixtures README ("SDK tests should"): path (node,
/// type, via), ports, variables (key + value), end, errors (count + node),
/// answers (shape + value fields), rendered plain text, emits,
/// unsupported, http (path + body keys), flowVariables, and the typing
/// pace between shown steps (+-50 ms) where it is not skipped on purpose
/// ([timingSkip]).
///
/// Cases for node types this SDK does not run yet are listed in
/// [pendingTypes] and skipped - every other case must pass.
library;

import 'dart:convert';

import 'package:conferbot_flutter/src/core/nodes/node_handler_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flow_driver.dart';

/// Node types not run by this SDK yet: their cases are pending.
const Set<String> pendingTypes = {};

/// Cases whose typing pace differs on purpose, with the reason. Everything
/// else in them is still compared.
///
/// In the web harness the visitor's next action is played once every
/// timer has run, the card's own UI timers included (focus 30-50 ms, a
/// debounce, an animation). They move the web clock, not the flow; this
/// SDK's cards are native widgets with no such timers.
const Map<String, String> timingSkip = {
  'navigate.links-then-done': 'web link-click timers before Done (420 ms)',
  'rating-choice.smiley-and-ten': 'web rating animation before the next pick (300 ms)',
  'otp.verified': 'web OTP card focus timers (50 + 30 ms)',
  'otp.wrong-code-then-locked': 'web OTP card focus timers (50 + 30 ms)',
  'address.search-and-pick': 'web address search debounce and focus (300 + 50 ms)',
  'payment.paid': 'web payment card focus timer (60 ms)',
  'real.qa-all-nodes-tour': 'the card timers above, added up over the tour',
};

String? _pendingReason(Map<String, dynamic> fx) {
  final types = <String>{
    ...((fx['covers'] as List?) ?? const []).map((e) => '$e'),
    ...((fx['flow']['nodes'] as List).map((n) => '${n['type']}')),
  };
  final pending = types.where(pendingTypes.contains).toList();
  return pending.isEmpty ? null : pending.join(', ');
}

Map<String, dynamic> _pick(dynamic o, List<String> keys) => {for (final k in keys) k: o is Map ? o[k] : null};

/// A time the visitor acted at ("consent_at", "signature_at"): it depends on
/// when the driver plays the action, so it is compared as a timestamp.
final _isoTime = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$');
final _isoTimes = RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z');
dynamic _stamp(dynamic v) => v is String && _isoTime.hasMatch(v) ? '<timestamp>' : v;
dynamic _stampsIn(dynamic text) => text is String ? text.replaceAll(_isoTimes, '<timestamp>') : text;

/// JSON with whole doubles as ints and map keys sorted, so a Dart value and
/// the web's compare as JSON.stringify would.
dynamic _canon(dynamic v) {
  if (v is double && v.isFinite && v == v.truncateToDouble()) return v.toInt();
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return {for (final k in keys) k: _canon(v[k])};
  }
  if (v is List) return v.map(_canon).toList();
  return v;
}

String _json(dynamic v) => jsonEncode(_canon(v));

/// The differences between what the web did and what this SDK did.
List<String> compare(Map<String, dynamic> fx, Map<String, dynamic> got) {
  final exp = fx['expect'] as Map<String, dynamic>;
  final diffs = <String>[];
  void eq(String label, dynamic a, dynamic b) {
    final ja = _json(a);
    final jb = _json(b);
    if (ja != jb) diffs.add('$label\n    web: $ja\n    sdk: $jb');
  }

  List<dynamic> list(dynamic v) => v is List ? v : const [];

  eq('path', [for (final p in list(exp['path'])) _pick(p, ['node', 'type', 'via'])],
      [for (final p in list(got['path'])) _pick(p, ['node', 'type', 'via'])]);
  eq('ports', exp['ports'], got['ports']);
  List<dynamic> vars(dynamic l) => [for (final v in list(l)) {'key': v['key'], 'value': _stamp(v['value'])}];
  eq('variables', vars(exp['variables']), vars(got['variables']));
  final end = exp['end'] as Map;
  final endKeys = end['crashed'] == true
      ? ['ended', 'crashed', 'at']
      : end['ended'] == true
          ? ['ended']
          : ['ended', 'waitingAt'];
  eq('end', _pick(end, endKeys), _pick(got['end'], endKeys));
  eq('errors (node)', [for (final e in list(exp['errors'])) e['node']], [for (final e in list(got['errors'])) e['node']]);
  final ea = list(exp['answers']);
  final ga = list(got['answers']);
  if (ea.length != ga.length) {
    eq('answers', ea, ga);
  } else {
    for (var i = 0; i < ea.length; i++) {
      eq('answers[$i]', ea[i], _pick(ga[i], (ea[i] as Map).keys.map((k) => '$k').toList()));
    }
  }
  List<dynamic> plainOf(dynamic l) => [for (final r in list(l)) {'node': r['node'], 'plain': _stampsIn(r['plain'])}];
  eq('rendered', plainOf(exp['rendered']), plainOf(got['rendered']));
  eq('emits', exp['emits'], got['emits']);
  eq('unsupported', exp['unsupported'], got['unsupported']);
  List<dynamic> bodyKeys(dynamic l) => [
        for (final h in list(l))
          {'path': h['path'], 'keys': h['body'] is Map ? ((h['body'] as Map).keys.map((k) => '$k').toList()..sort()) : []}
      ];
  eq('http', bodyKeys(exp['http']), bodyKeys(got['http']));
  if (exp['flowVariables'] != null) eq('flowVariables', exp['flowVariables'], got['flowVariables']);

  if (!timingSkip.containsKey(fx['id'])) {
    eq('shown (order)', [for (final s in list(exp['shown'])) s['node']], [for (final s in list(got['shown'])) s['node']]);
    List<num> gaps(List<dynamic> l) => [for (var i = 1; i < l.length; i++) (l[i]['t'] as num) - (l[i - 1]['t'] as num)];
    final ge = gaps(list(exp['shown']));
    final gg = gaps(list(got['shown']));
    var off = false;
    if (ge.length == gg.length) {
      for (var i = 0; i < ge.length; i++) {
        if ((ge[i] - gg[i]).abs() > 50) off = true;
      }
    }
    if (off) diffs.add('shown (pace)\n    web: ${_json(exp['shown'])}\n    sdk: ${_json(got['shown'])}');
  }
  return diffs;
}

void main() {
  // The engine's analytics reach platform services.
  TestWidgetsFlutterBinding.ensureInitialized();
  final all = [for (final c in fixtureIndex()) loadFixture('${c['file']}')];

  group('flow-node spec fixtures', () {
    for (final fx in all) {
      final reason = _pendingReason(fx);
      final id = '${fx['id']}';
      test(reason == null ? id : '$id (pending: $reason)', () async {
        final r = await runFixture(fx);
        final diffs = [...r.problems.map((p) => 'problem: $p'), ...compare(fx, r.outcome)];
        if (diffs.isNotEmpty) fail('$id\n  ${diffs.join('\n  ')}');
      }, skip: reason != null);
    }

    test('every pending type is still missing from the registry', () {
      final registry = NodeHandlerRegistry.withAll();
      for (final t in pendingTypes) {
        expect(registry.hasHandler(t), isFalse, reason: t);
      }
      expect(all.length, fixtureIndex().length);
    });
  });
}
