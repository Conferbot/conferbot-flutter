import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/core/nodes/handlers/logic_handlers.dart';
import 'package:conferbot_flutter/src/core/nodes/node_result.dart';
import 'package:conferbot_flutter/src/core/nodes/node_types.dart';
import '../../mocks/mock_chat_state.dart';
import '../../fixtures/test_fixtures.dart';

void main() {
  late MockChatState mockState;

  setUp(() {
    mockState = MockChatState();
  });

  tearDown(() {
    mockState.reset();
  });

  group('ConditionNodeHandler', () {
    late ConditionNodeHandler handler;

    setUp(() {
      handler = ConditionNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.condition);
    });

    group('Numeric Conditions', () {
      test('should evaluate greater than correctly', () async {
        mockState.setVariable('score', 75);

        final nodeData = TestFixtures.conditionNode(
          leftValue: '{{score}}',
          rightValue: '50',
          operator: '>',
          isNumber: true,
        )['data'] as Map<String, dynamic>;

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should evaluate less than correctly', () async {
        mockState.setVariable('score', 25);

        final nodeData = TestFixtures.conditionNode(
          leftValue: '{{score}}',
          rightValue: '50',
          operator: '<',
          isNumber: true,
        )['data'] as Map<String, dynamic>;

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should evaluate equals correctly', () async {
        mockState.setVariable('score', 50);

        final nodeData = TestFixtures.conditionNode(
          leftValue: '{{score}}',
          rightValue: '50',
          operator: '=',
          isNumber: true,
        )['data'] as Map<String, dynamic>;

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should evaluate not equals correctly', () async {
        mockState.setVariable('score', 75);

        final nodeData = TestFixtures.conditionNode(
          leftValue: '{{score}}',
          rightValue: '50',
          operator: '!=',
          isNumber: true,
        )['data'] as Map<String, dynamic>;

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should evaluate >= correctly', () async {
        mockState.setVariable('score', 50);

        final nodeData = TestFixtures.conditionNode(
          leftValue: '{{score}}',
          rightValue: '50',
          operator: '>=',
          isNumber: true,
        )['data'] as Map<String, dynamic>;

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should evaluate <= correctly', () async {
        mockState.setVariable('score', 50);

        final nodeData = TestFixtures.conditionNode(
          leftValue: '{{score}}',
          rightValue: '50',
          operator: '<=',
          isNumber: true,
        )['data'] as Map<String, dynamic>;

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should route to source-1 when condition is false', () async {
        mockState.setVariable('score', 25);

        final nodeData = TestFixtures.conditionNode(
          leftValue: '{{score}}',
          rightValue: '50',
          operator: '>',
          isNumber: true,
        )['data'] as Map<String, dynamic>;

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-1');
      });

      test('should handle string numbers', () async {
        final nodeData = {
          'type': 'condition-node',
          'leftValue': '75',
          'rightValue': '50',
          'operator': '>',
          'isNumber': true,
        };

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });
    });

    group('String Conditions', () {
      test('should evaluate string equals correctly', () async {
        mockState.setVariable('name', 'John');

        final nodeData = {
          'type': 'condition-node',
          'leftValue': '{{name}}',
          'rightValue': 'John',
          'operator': '=',
          'isNumber': false,
        };

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should evaluate string equals case-insensitively', () async {
        mockState.setVariable('name', 'JOHN');

        final nodeData = {
          'type': 'condition-node',
          'leftValue': '{{name}}',
          'rightValue': 'john',
          'operator': 'equals',
          'isNumber': false,
        };

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should evaluate contains correctly', () async {
        mockState.setVariable('text', 'Hello World');

        final nodeData = {
          'type': 'condition-node',
          'leftValue': '{{text}}',
          'rightValue': 'World',
          'operator': 'contains',
          'isNumber': false,
        };

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should evaluate does not contain correctly', () async {
        mockState.setVariable('text', 'Hello World');

        final nodeData = {
          'type': 'condition-node',
          'leftValue': '{{text}}',
          'rightValue': 'Foo',
          'operator': 'does not contain',
          'isNumber': false,
        };

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should evaluate starts with correctly', () async {
        mockState.setVariable('text', 'Hello World');

        final nodeData = {
          'type': 'condition-node',
          'leftValue': '{{text}}',
          'rightValue': 'Hello',
          'operator': 'starts with',
          'isNumber': false,
        };

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should evaluate ends with correctly', () async {
        mockState.setVariable('text', 'Hello World');

        final nodeData = {
          'type': 'condition-node',
          'leftValue': '{{text}}',
          'rightValue': 'World',
          'operator': 'ends with',
          'isNumber': false,
        };

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should evaluate regex matches correctly', () async {
        mockState.setVariable('text', 'test@example.com');

        final nodeData = {
          'type': 'condition-node',
          'leftValue': '{{text}}',
          'rightValue': r'^[a-z]+@[a-z]+\.[a-z]+$',
          'operator': 'matches',
          'isNumber': false,
        };

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-0');
      });

      test('should handle invalid regex gracefully', () async {
        mockState.setVariable('text', 'test');

        final nodeData = {
          'type': 'condition-node',
          'leftValue': '{{text}}',
          'rightValue': '[invalid regex',
          'operator': 'matches',
          'isNumber': false,
        };

        final result = await handler.process(nodeData, 'condition_1');

        expect(result, isA<ProceedResult>());
        expect((result as ProceedResult).targetPort, 'source-1');
      });
    });
  });

  group('BooleanLogicNodeHandler', () {
    late BooleanLogicNodeHandler handler;

    setUp(() {
      handler = BooleanLogicNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.booleanLogic);
    });

    test('should evaluate AND correctly', () async {
      final nodeData = {
        'type': 'boolean-logic-node',
        'leftValue': 'true',
        'rightValue': 'true',
        'operator': 'AND',
      };

      final result = await handler.process(nodeData, 'bool_1');

      expect(result, isA<ProceedResult>());
      expect((result as ProceedResult).targetPort, 'source-0');
    });

    test('should evaluate AND false correctly', () async {
      final nodeData = {
        'type': 'boolean-logic-node',
        'leftValue': 'true',
        'rightValue': 'false',
        'operator': 'AND',
      };

      final result = await handler.process(nodeData, 'bool_1');

      expect(result, isA<ProceedResult>());
      expect((result as ProceedResult).targetPort, 'source-1');
    });

    test('should evaluate OR correctly', () async {
      final nodeData = {
        'type': 'boolean-logic-node',
        'leftValue': 'true',
        'rightValue': 'false',
        'operator': 'OR',
      };

      final result = await handler.process(nodeData, 'bool_1');

      expect(result, isA<ProceedResult>());
      expect((result as ProceedResult).targetPort, 'source-0');
    });

    test('should evaluate XOR correctly', () async {
      final nodeData = {
        'type': 'boolean-logic-node',
        'leftValue': 'true',
        'rightValue': 'false',
        'operator': 'XOR',
      };

      final result = await handler.process(nodeData, 'bool_1');

      expect(result, isA<ProceedResult>());
      expect((result as ProceedResult).targetPort, 'source-0');
    });

    test('should evaluate NAND correctly', () async {
      final nodeData = {
        'type': 'boolean-logic-node',
        'leftValue': 'true',
        'rightValue': 'true',
        'operator': 'NAND',
      };

      final result = await handler.process(nodeData, 'bool_1');

      expect(result, isA<ProceedResult>());
      expect((result as ProceedResult).targetPort, 'source-1');
    });

    test('should evaluate NOR correctly', () async {
      final nodeData = {
        'type': 'boolean-logic-node',
        'leftValue': 'false',
        'rightValue': 'false',
        'operator': 'NOR',
      };

      final result = await handler.process(nodeData, 'bool_1');

      expect(result, isA<ProceedResult>());
      expect((result as ProceedResult).targetPort, 'source-0');
    });

    test('should convert different types to boolean', () async {
      mockState.setVariable('num', 1);
      mockState.setVariable('str', 'yes');

      final nodeData = {
        'type': 'boolean-logic-node',
        'leftValue': '{{num}}',
        'rightValue': '{{str}}',
        'operator': 'AND',
      };

      final result = await handler.process(nodeData, 'bool_1');

      expect(result, isA<ProceedResult>());
      expect((result as ProceedResult).targetPort, 'source-0');
    });
  });

  group('MathOperationNodeHandler', () {
    late MathOperationNodeHandler handler;

    setUp(() {
      handler = MathOperationNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.mathOperation);
    });

    test('should perform addition', () async {
      final nodeData = TestFixtures.mathOperationNode(
        leftValue: '10',
        rightValue: '5',
        operator: '+',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'math_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.answerVariables['math_1']?['value'], 15.0);
    });

    test('should perform subtraction', () async {
      final nodeData = TestFixtures.mathOperationNode(
        leftValue: '10',
        rightValue: '5',
        operator: '-',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'math_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.answerVariables['math_1']?['value'], 5.0);
    });

    test('should perform multiplication', () async {
      final nodeData = TestFixtures.mathOperationNode(
        leftValue: '10',
        rightValue: '5',
        operator: '*',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'math_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.answerVariables['math_1']?['value'], 50.0);
    });

    test('should perform division', () async {
      final nodeData = TestFixtures.mathOperationNode(
        leftValue: '10',
        rightValue: '5',
        operator: '/',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'math_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.answerVariables['math_1']?['value'], 2.0);
    });

    test('should handle division by zero', () async {
      final nodeData = TestFixtures.mathOperationNode(
        leftValue: '10',
        rightValue: '0',
        operator: '/',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'math_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.answerVariables['math_1']?['value'], 0.0);
    });

    test('should perform modulo', () async {
      final nodeData = TestFixtures.mathOperationNode(
        leftValue: '10',
        rightValue: '3',
        operator: '%',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'math_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.answerVariables['math_1']?['value'], 1.0);
    });

    test('should resolve variable references', () async {
      mockState.setVariable('a', 20);
      mockState.setVariable('b', 4);

      final nodeData = {
        'type': 'math-operation-node',
        'leftValue': '{{a}}',
        'rightValue': '{{b}}',
        'operator': '*',
      };

      final result = await handler.process(nodeData, 'math_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.answerVariables['math_1']?['value'], 80.0);
    });
  });

  group('VariableNodeHandler', () {
    late VariableNodeHandler handler;

    setUp(() {
      handler = VariableNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.variable);
    });

    test('should set string variable', () async {
      final nodeData = TestFixtures.variableNode(
        name: 'testVar',
        value: 'testValue',
        isNumber: false,
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'var_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.variables['testVar'], 'testValue');
    });

    test('should set number variable', () async {
      final nodeData = TestFixtures.variableNode(
        name: 'count',
        value: '42',
        isNumber: true,
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'var_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.variables['count'], 42.0);
    });

    test('should use nodeId as name when customNameValue is true', () async {
      final nodeData = TestFixtures.variableNode(
        name: 'ignored',
        value: 'value',
        customNameValue: true,
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'custom_node_id');

      expect(result, isA<ProceedResult>());
      expect(mockState.variables['custom_node_id'], 'value');
    });

    test('should resolve variable references', () async {
      mockState.setVariable('existing', 'existingValue');

      final nodeData = {
        'type': 'variable-node',
        'name': 'newVar',
        'value': '{{existing}}',
        'isNumber': false,
        'customNameValue': false,
      };

      final result = await handler.process(nodeData, 'var_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.variables['newVar'], 'existingValue');
    });

    test('should store in answer variables', () async {
      final nodeData = TestFixtures.variableNode(
        name: 'answer',
        value: 'value',
      )['data'] as Map<String, dynamic>;

      await handler.process(nodeData, 'var_1');

      expect(mockState.answerVariables['var_1']?['value'], 'value');
    });
  });

  group('JumpToNodeHandler', () {
    late JumpToNodeHandler handler;

    setUp(() {
      handler = JumpToNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.jumpTo);
    });

    test('should return JumpToResult with target node id', () async {
      final nodeData = TestFixtures.jumpToNode(
        targetNodeId: 'target_node_123',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'jump_1');

      expect(result, isA<JumpToResult>());
      expect((result as JumpToResult).targetNodeId, 'target_node_123');
    });

    test('should use nodeId field as fallback', () async {
      final nodeData = {
        'type': 'jump-to-node',
        'nodeId': 'fallback_target',
      };

      final result = await handler.process(nodeData, 'jump_1');

      expect(result, isA<JumpToResult>());
      expect((result as JumpToResult).targetNodeId, 'fallback_target');
    });

    test('should return error when no target specified', () async {
      final nodeData = {
        'type': 'jump-to-node',
      };

      final result = await handler.process(nodeData, 'jump_1');

      expect(result, isA<ErrorResult>());
      expect((result as ErrorResult).message, 'No target node specified');
      expect(result.shouldProceed, true);
    });
  });

  group('RandomFlowNodeHandler', () {
    late RandomFlowNodeHandler handler;

    setUp(() {
      handler = RandomFlowNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.randomFlow);
    });

    test('should return ProceedResult with valid port', () async {
      final nodeData = TestFixtures.randomFlowNode(
        branches: [
          {'id': '0', 'weight': 50},
          {'id': '1', 'weight': 50},
        ],
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'random_1');

      expect(result, isA<ProceedResult>());
      final port = (result as ProceedResult).targetPort;
      expect(port, anyOf('source-0', 'source-1'));
    });

    test('should proceed without port when no branches', () async {
      final nodeData = TestFixtures.randomFlowNode(
        branches: [],
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'random_1');

      expect(result, isA<ProceedResult>());
      expect((result as ProceedResult).targetPort, isNull);
    });

    test('should handle weighted selection', () async {
      // Test multiple times to check distribution
      final nodeData = TestFixtures.randomFlowNode(
        branches: [
          {'id': '0', 'weight': 100},
          {'id': '1', 'weight': 0},
        ],
      )['data'] as Map<String, dynamic>;

      // With 100% weight on first option, should always select it
      for (int i = 0; i < 10; i++) {
        final result = await handler.process(nodeData, 'random_$i');
        expect((result as ProceedResult).targetPort, 'source-0');
      }
    });

    test('should handle string weights', () async {
      final nodeData = {
        'type': 'random-flow-node',
        'branches': [
          {'id': '0', 'weight': '50'},
          {'id': '1', 'weight': '50'},
        ],
      };

      final result = await handler.process(nodeData, 'random_1');

      expect(result, isA<ProceedResult>());
    });
  });

  group('BusinessHoursNodeHandler', () {
    late BusinessHoursNodeHandler handler;

    setUp(() {
      handler = BusinessHoursNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.businessHours);
    });

    test('should return ProceedResult', () async {
      final now = DateTime.now();
      final dayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][now.weekday - 1];

      final nodeData = {
        'type': 'business-hours-node',
        'timezone': DateTime.now().timeZoneName,
        'excludeDays': <String>[],
        'excludeDates': <String>[],
        'weeklyHours': [
          {
            'dayName': dayName,
            'available': true,
            'slots': [
              {'start': '00:00', 'end': '23:59'},
            ],
          },
        ],
      };

      final result = await handler.process(nodeData, 'bh_1');

      expect(result, isA<ProceedResult>());
    });

    test('should route to source-1 when day is excluded', () async {
      final now = DateTime.now();
      final dayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][now.weekday - 1];

      final nodeData = {
        'type': 'business-hours-node',
        'timezone': DateTime.now().timeZoneName,
        'excludeDays': [dayName],
        'excludeDates': <String>[],
        'weeklyHours': <Map<String, dynamic>>[],
      };

      final result = await handler.process(nodeData, 'bh_1');

      expect(result, isA<ProceedResult>());
      expect((result as ProceedResult).targetPort, 'source-1');
    });

    test('should route to source-1 when date is excluded', () async {
      final now = DateTime.now();
      final currentDate = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final nodeData = {
        'type': 'business-hours-node',
        'timezone': DateTime.now().timeZoneName,
        'excludeDays': <String>[],
        'excludeDates': [currentDate],
        'weeklyHours': <Map<String, dynamic>>[],
      };

      final result = await handler.process(nodeData, 'bh_1');

      expect(result, isA<ProceedResult>());
      expect((result as ProceedResult).targetPort, 'source-1');
    });

    test('should route to source-1 when not available', () async {
      final now = DateTime.now();
      final dayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][now.weekday - 1];

      final nodeData = {
        'type': 'business-hours-node',
        'timezone': DateTime.now().timeZoneName,
        'excludeDays': <String>[],
        'excludeDates': <String>[],
        'weeklyHours': [
          {
            'dayName': dayName,
            'available': false,
            'slots': <Map<String, dynamic>>[],
          },
        ],
      };

      final result = await handler.process(nodeData, 'bh_1');

      expect(result, isA<ProceedResult>());
      expect((result as ProceedResult).targetPort, 'source-1');
    });
  });

  group('LogicNodeHandlers Registry', () {
    test('should return all logic handlers', () {
      final handlers = LogicNodeHandlers.handlers;

      expect(handlers.length, 7);
      expect(handlers.any((h) => h.nodeType == NodeTypes.condition), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.booleanLogic), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.mathOperation), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.randomFlow), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.variable), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.jumpTo), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.businessHours), true);
    });

    test('should get handler by type', () {
      final handler = LogicNodeHandlers.getHandler(NodeTypes.condition);
      expect(handler, isA<ConditionNodeHandler>());
    });

    test('should throw for unknown type', () {
      expect(
        () => LogicNodeHandlers.getHandler('unknown-type'),
        throwsArgumentError,
      );
    });

    test('should check if handler exists', () {
      expect(LogicNodeHandlers.hasHandler(NodeTypes.condition), true);
      expect(LogicNodeHandlers.hasHandler('unknown-type'), false);
    });
  });
}
