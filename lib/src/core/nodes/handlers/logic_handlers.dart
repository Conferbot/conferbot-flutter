/// The logic steps: condition, boolean-logic, math-operation, variable,
/// random-flow, jump-to and business-hours (React Native
/// src/core/nodes/handlers/LogicNodeHandlers.ts). They show nothing and
/// route at once. The rules are the web widget's, ported in
/// core/flow/logic.dart (handlers/conditionEval.ts, handlers/logicValues.ts);
/// the routing is handlers/logical.ts:
///
/// - condition / boolean: true leaves by source-0, false by source-1;
/// - business hours: open source-0, closed source-1;
/// - random split: "source-" + the picked branch id (legacy: its position);
///   no wired branch ends the chat;
/// - math and variable save by name and take the first edge;
/// - jump-to: data.nodeId, else targetNodeId, else jumpTo; a missing target
///   ends the chat.
library;

import '../../flow/js.dart';
import '../../flow/logic.dart';
import '../../state/chat_state.dart';
import '../node_handler.dart';

/// A variable read the way the web logic steps read it: the answers, first
/// entry by name.
dynamic Function(String key) answerLookup(ChatState state) =>
    (key) => state.hasAnswerVariable(key) ? state.getAnswer(key) : null;

/// Evaluates condition-node data against the answers.
class ConditionEvaluator {
  static bool evaluate(Map<String, dynamic> data, ChatState state) => evaluateCondition(data, answerLookup(state));
}

/// condition-node: true -> source-0, false -> source-1.
class ConditionHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'condition-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async =>
      NodeResult.port(ConditionEvaluator.evaluate(node.data, state) ? 'source-0' : 'source-1');
}

/// boolean-logic-node: "No", "off", "0" and empty are false; true -> source-0.
class BooleanConditionHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'boolean-logic-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async =>
      NodeResult.port(booleanResult(node.data, answerLookup(state)) ? 'source-0' : 'source-1');
}

/// math-operation-node: leftValue op rightValue, saved by name
/// (answerVariable, default "math_operations").
class MathOperationHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'math-operation-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final result = mathResult(node.data, answerLookup(state));
    state.saveVariableByName(mathVariableName(node.data), result, node.id);
    return NodeResult.next();
  }
}

/// random-flow-node: a wired branch by weight, leaving by "source-" + its id.
class RandomPathHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'random-flow-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ctx = node.ctx;
    final handles = ctx.edges().map((e) => e['sourceHandle']).toList();
    final handle = pickRandomHandle(node.data['branches'], handles, ctx.random());
    return NodeResult.port(handle ?? noPath);
  }
}

/// variable-node: data.value ({x} filled; a number with isNumber), saved by data.name.
class SetVariableHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'variable-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final raw = node.data['name'];
    final name = (raw == null ? '' : jsString(raw)).trim();
    final value = variableValue(node.data, answerLookup(state));
    if (name.isNotEmpty) {
      state.saveVariableByName(name, value, node.id);
      state.setVariable(name, value);
    }
    return NodeResult.next();
  }
}

/// jump-to-node: to data.nodeId / targetNodeId / jumpTo; a missing target ends the chat.
class JumpHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'jump-to-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async => NodeResult.jumpTo(jumpTargetOf(node.data));
}

/// business-hours-node: open now on the owner's clock -> source-0, closed -> source-1.
class BusinessHoursHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'business-hours-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final open = isWithinBusinessHours(node.data, node.ctx.now());
    return NodeResult.port(open ? 'source-0' : 'source-1');
  }
}

/// All logic node handlers.
final List<NodeHandler> logicHandlers = [
  ConditionHandler(),
  BooleanConditionHandler(),
  MathOperationHandler(),
  RandomPathHandler(),
  SetVariableHandler(),
  JumpHandler(),
  BusinessHoursHandler(),
];
