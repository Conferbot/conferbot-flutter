import 'package:conferbot_flutter/src/core/flow/flow_control.dart';
import 'package:conferbot_flutter/src/core/flow/logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vars = <String, dynamic>{'plan': 'Pro', 'stars': 4, 'count': 2, 'list': 'a, b, c'};
  dynamic lookup(String k) => vars[k];
  bool condition(Map<String, dynamic> data) => evaluateCondition(data, lookup);

  group('evaluateCondition', () {
    test('reads leftValue as a variable name (bare, \${x} or {x})', () {
      for (final left in ['plan', r'${plan}', '{plan}']) {
        expect(condition({'leftValue': left, 'operator': '=', 'rightValue': 'Pro', 'customRightValue': true}), isTrue);
      }
    });

    test('is case-sensitive unless caseInsensitive', () {
      expect(condition({'leftValue': 'plan', 'operator': '=', 'rightValue': 'pro', 'customRightValue': true}), isFalse);
      expect(
        condition({'leftValue': 'plan', 'operator': '=', 'rightValue': 'pro', 'customRightValue': true, 'caseInsensitive': true}),
        isTrue,
      );
    });

    test('knows every operator and its aliases; anything else is false', () {
      bool t(String operator, String rightValue, [String leftValue = 'plan']) =>
          condition({'leftValue': leftValue, 'operator': operator, 'rightValue': rightValue, 'customRightValue': true});
      expect(t('!=', 'Basic'), isTrue);
      expect(t('not_equals', 'Pro'), isFalse);
      expect(t('contains', 'r'), isTrue);
      expect(t('does not contain', 'x'), isTrue);
      expect(t('not_contains', 'P'), isFalse);
      expect(t('starts with', 'P'), isTrue);
      expect(t('ends_with', 'o'), isTrue);
      expect(t('matches', r'^P.o$'), isTrue);
      expect(t('matches', '('), isFalse);
      expect(t('does_not_match', '^x'), isTrue);
      expect(t('is_set', ''), isTrue);
      expect(t('is_not_set', '', 'nobody'), isTrue);
      expect(t('>', '3', 'stars'), isTrue);
      expect(t('less_than_or_equal', '4', 'stars'), isTrue);
      expect(t('>', 'x'), isFalse);
      expect(t('between', 'x'), isFalse);
    });

    test('a number in the variable field is compared as typed; stars read as their number', () {
      expect(condition({'leftValue': '5', 'operator': '>', 'rightValue': '3', 'customRightValue': true}), isTrue);
      expect(condition({'leftValue': 'stars', 'operator': '>', 'rightValue': '⭐⭐⭐', 'customRightValue': true}), isTrue);
      expect(condition({'leftValue': 'stars', 'operator': '=', 'rightValue': '4.0', 'customRightValue': true}), isTrue);
      expect(condition({'leftValue': 'count', 'operator': '=', 'rightValue': '', 'isNumber': true}), isFalse);
    });

    test('a right value that is a variable name is looked up', () {
      vars['other'] = 'Pro';
      expect(condition({'leftValue': 'plan', 'operator': '=', 'rightValue': 'other'}), isTrue);
    });
  });

  group('math, boolean, variable', () {
    test('mathResult', () {
      expect(mathResult({'leftValue': 'count', 'operator': '+', 'rightValue': '1'}, lookup), 3);
      expect(mathResult({'leftValue': '7', 'operator': '/', 'rightValue': '2'}, lookup), 3.5);
      expect(mathResult({'leftValue': '4', 'operator': '/', 'rightValue': '2'}, lookup), isA<int>());
      expect(mathResult({'leftValue': '1', 'operator': '/', 'rightValue': '0'}, lookup), '');
      expect(mathResult({'leftValue': 'nobody', 'operator': '+', 'rightValue': '1'}, lookup), '');
      expect(mathResult({'leftValue': '0.1', 'operator': '+', 'rightValue': '0.2'}, lookup), 0.3);
      expect(mathVariableName({}), defaultMathVariable);
    });

    test('booleanResult', () {
      expect(booleanResult({'leftValue': 'yes', 'operator': 'AND', 'rightValue': 'no'}, lookup), isFalse);
      expect(booleanResult({'leftValue': 'yes', 'operator': 'NOT', 'rightValue': 'off'}, lookup), isTrue);
      expect(booleanResult({'leftValue': '1', 'operator': 'xor', 'rightValue': '0'}, lookup), isTrue);
      expect(booleanResult({'leftValue': '1', 'operator': 'nope', 'rightValue': '0'}, lookup), isFalse);
    });

    test('variableValue', () {
      expect(variableValue({'value': 'plan {plan}'}, lookup), 'plan Pro');
      expect(variableValue({'value': '1,000', 'isNumber': true}, lookup), 1000);
      expect(variableValue({'value': '{nobody}'}, lookup), '{nobody}');
    });

    test('saveVariableByName updates every entry, else adds one', () {
      final list = [LogicAnswerVariable(nodeId: 'a', key: 'n', value: 1)];
      saveVariableByName(list, 'n', 2);
      saveVariableByName(list, 'm', 3);
      expect(list.map((e) => e.toJson()).toList(), [
        {'nodeId': 'a', 'key': 'n', 'value': 2},
        {'nodeId': 'variable_m', 'key': 'm', 'value': 3},
      ]);
    });
  });

  group('random, jump', () {
    test('pickRandomHandle by id, skipping unwired branches, legacy positions', () {
      final branches = [
        {'id': 'a', 'weight': 50},
        {'id': 'b', 'weight': 50},
        {'id': 'c', 'weight': 50},
      ];
      expect(pickRandomHandle(branches, ['source-a', 'source-c'], 0.8), 'source-c');
      expect(pickRandomHandle(branches, ['source-a', 'source-c'], 0.2), 'source-a');
      expect(pickRandomHandle([{'weight': 1}, {'weight': 1}], ['source-1'], 0.1), 'source-1');
      expect(pickRandomHandle(branches, [], 0.1), isNull);
    });

    test('jumpTargetOf reads nodeId, then targetNodeId, then jumpTo', () {
      expect(jumpTargetOf({'targetNodeId': ' x ', 'jumpTo': 'y'}), 'x');
      expect(jumpTargetOf({'nodeId': '', 'jumpTo': 'y'}), 'y');
      expect(jumpTargetOf({}), '');
    });
  });

  group('business hours', () {
    final now = DateTime.utc(2026, 10, 15, 10);
    Map<String, dynamic> hours(String zone, List<Map<String, dynamic>> weekly, {List<String>? excludeDates}) =>
        {'timezone': zone, 'weeklyHours': weekly, if (excludeDates != null) 'excludeDates': excludeDates};

    test('open on the owner\'s clock (14:00 Asia/Dubai)', () {
      final data = hours('Asia/Dubai', [
        {'dayName': 'Thursday', 'available': true, 'slots': [{'start': '09:00', 'end': '17:00'}]},
      ]);
      expect(isWithinBusinessHours(data, now), isTrue);
      expect(isWithinBusinessHours({...data, 'excludeDates': ['15-10-2026']}, now), isFalse);
      expect(zonedNow(now, 'Asia/Dubai').time, '14:00');
    });

    test("yesterday's overnight slot is still open (Pacific/Kiritimati, Fri 00:00)", () {
      final data = hours('Pacific/Kiritimati', [
        {'dayName': 'Thursday', 'available': true, 'slots': [{'start': '22:00', 'end': '02:00'}]},
      ]);
      expect(zonedNow(now, 'Pacific/Kiritimati').dayName, 'Friday');
      expect(isWithinBusinessHours(data, now), isTrue);
    });

    test('DST: New York is UTC-4 in October', () {
      expect(zonedNow(now, 'America/New_York').time, '06:00');
      expect(zonedNow(DateTime.utc(2026, 12, 15, 10), 'America/New_York').time, '05:00');
    });

    test('normaliseDate', () {
      expect(normaliseDate('2026/1/5'), '2026-01-05');
      expect(normaliseDate('5.1.2026'), '2026-01-05');
      expect(normaliseDate('Jan 5'), isNull);
    });
  });

  group('loops and sub-flows', () {
    test('count loop runs N rounds then Done', () {
      final s = emptyFlowControl();
      final data = {'count': '{count}', 'variable': 'n'};
      final a = stepLoop('L', data, s, lookup);
      expect(a.handle, loopBodyHandle);
      expect(a.vars, {'n_index': 1, 'n_item': 1, 'n_count': 2});
      expect(loopTrailText(a.trail), 'Loop 1 of 2');
      stepLoop('L', data, s, lookup);
      final done = stepLoop('L', data, s, lookup);
      expect(done.handle, loopDoneHandle);
      expect(loopTrailText(done.trail), 'Loop done · 2 rounds');
      expect(s.loops, isEmpty);
    });

    test('each loop over a text list, capped', () {
      final s = emptyFlowControl();
      final data = {'mode': 'each', 'listVariable': '{list}', 'maxIterations': 2};
      final a = stepLoop('L', data, s, lookup);
      expect(a.vars['loop_item'], 'a');
      expect(loopTrailText(a.trail), 'Loop 1 of 2 · a');
      stepLoop('L', data, s, lookup);
      final done = stepLoop('L', data, s, lookup);
      expect(loopTrailText(done.trail), 'Loop stopped at the safety cap · 2 rounds');
      expect(listOf('[1,2]'), [1, 2]);
      expect(loopCap({'maxIterations': 500}), loopHardCap);
      expect(loopCap({}), loopDefaultCap);
    });

    test('callSubflow / returnFromSubflow', () {
      final s = emptyFlowControl();
      final nodes = [
        {'id': 'sf', 'type': subflowType, 'data': {'name': '<p>Checkout</p>'}},
      ];
      final run = {
        'id': 'run',
        'data': {
          'subflowId': 'sf',
          'inputs': [
            {'name': 'who', 'value': '{plan}'},
          ],
          'outputs': [
            {'name': 'total', 'variable': 'grand'},
          ],
        },
      };
      final call = callSubflow(run, nodes, s, lookup);
      expect(call.ok, isTrue);
      expect(call.name, 'Checkout');
      expect(call.vars, {'who': 'Pro'});
      expect(callSubflow(run, nodes, s, lookup).error, 'recursion');
      expect(callSubflow({'data': {'subflowId': 'x'}}, nodes, s, lookup).error, 'missing');
      final ret = returnFromSubflow(s, lookup)!;
      expect(ret.frame.runNodeId, 'run');
      expect(ret.vars, {'grand': ''});
      expect(returnFromSubflow(s, lookup), isNull);
      final restored = restoreFlowControl(FlowControlState(stack: [call.frame!]).toJson());
      expect(restored.stack.single.outputs, [
        {'from': 'total', 'to': 'grand'},
      ]);
    });
  });
}
