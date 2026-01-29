import 'dart:math' as math;

import '../node_handler.dart';
import '../node_result.dart';
import '../node_types.dart';
import '../../state/chat_state.dart';

/// Handler for condition-node
/// Evaluates conditions and routes to different branches
class ConditionNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.condition;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final isNumber = getBoolean(nodeData, 'isNumber', false);
    final leftValue = getString(nodeData, 'leftValue', '');
    final rightValue = getString(nodeData, 'rightValue', '');
    final operator = getString(nodeData, 'operator', '=');

    // Resolve values (they might be variable references)
    final resolvedLeft = state.resolveValue(leftValue);
    final resolvedRight = state.resolveValue(rightValue);

    final result = isNumber
        ? _evaluateNumericCondition(resolvedLeft, resolvedRight, operator)
        : _evaluateStringCondition(resolvedLeft.toString(), resolvedRight.toString(), operator);

    // Route based on result
    return result
        ? const NodeResult.proceed(targetPort: 'source-0') // True branch
        : const NodeResult.proceed(targetPort: 'source-1'); // False branch
  }

  bool _evaluateNumericCondition(dynamic left, dynamic right, String operator) {
    final leftNum = _toNumber(left);
    final rightNum = _toNumber(right);

    switch (operator) {
      case '<':
        return leftNum < rightNum;
      case '>':
        return leftNum > rightNum;
      case '=':
      case '==':
        return leftNum == rightNum;
      case '!=':
        return leftNum != rightNum;
      case '<=':
        return leftNum <= rightNum;
      case '>=':
        return leftNum >= rightNum;
      default:
        return false;
    }
  }

  bool _evaluateStringCondition(String left, String right, String operator) {
    final lowercaseOperator = operator.toLowerCase();

    switch (lowercaseOperator) {
      case '=':
      case '==':
      case 'equals':
        return left.toLowerCase() == right.toLowerCase();
      case '!=':
        return left.toLowerCase() != right.toLowerCase();
      case 'contains':
        return left.toLowerCase().contains(right.toLowerCase());
      case 'does not contain':
        return !left.toLowerCase().contains(right.toLowerCase());
      case 'starts with':
        return left.toLowerCase().startsWith(right.toLowerCase());
      case 'ends with':
        return left.toLowerCase().endsWith(right.toLowerCase());
      case 'matches':
        try {
          return RegExp(right).hasMatch(left);
        } catch (e) {
          return false;
        }
      case 'does not match':
        try {
          return !RegExp(right).hasMatch(left);
        } catch (e) {
          return true;
        }
      default:
        return left == right;
    }
  }

  double _toNumber(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Handler for boolean-logic-node
/// Performs boolean operations on two values
class BooleanLogicNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.booleanLogic;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final leftValue = getString(nodeData, 'leftValue', 'false');
    final rightValue = getString(nodeData, 'rightValue', 'false');
    final operator = getString(nodeData, 'operator', 'AND');

    // Resolve and convert to boolean
    final left = _toBoolean(state.resolveValue(leftValue));
    final right = _toBoolean(state.resolveValue(rightValue));

    final result = _evaluateBooleanOperation(left, right, operator.toUpperCase());

    return result
        ? const NodeResult.proceed(targetPort: 'source-0') // True
        : const NodeResult.proceed(targetPort: 'source-1'); // False
  }

  bool _evaluateBooleanOperation(bool left, bool right, String operator) {
    switch (operator) {
      case 'AND':
        return left && right;
      case 'OR':
        return left || right;
      case 'NOT':
        return left && !right; // NOT as "left AND NOT right"
      case 'XOR':
        return left ^ right;
      case 'NAND':
        return !(left && right);
      case 'NOR':
        return !(left || right);
      case 'XNOR':
        return !(left ^ right);
      default:
        return left && right;
    }
  }

  bool _toBoolean(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lowercaseValue = value.toLowerCase();
      return lowercaseValue == 'true' || lowercaseValue == 'yes' || lowercaseValue == '1';
    }
    return false;
  }
}

/// Handler for math-operation-node
/// Performs mathematical operations
class MathOperationNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.mathOperation;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final leftValue = getString(nodeData, 'leftValue', '0');
    final rightValue = getString(nodeData, 'rightValue', '0');
    final operator = getString(nodeData, 'operator', '+');

    // Resolve values
    final left = _toNumber(state.resolveValue(leftValue));
    final right = _toNumber(state.resolveValue(rightValue));

    final result = _evaluateMathOperation(left, right, operator);

    // Store result in answer variable
    state.setAnswerVariable(nodeId, result);

    return const NodeResult.proceed();
  }

  double _evaluateMathOperation(double left, double right, String operator) {
    switch (operator) {
      case '+':
        return left + right;
      case '-':
        return left - right;
      case '*':
        return left * right;
      case '/':
        return right != 0 ? left / right : 0.0;
      case '%':
        return right != 0 ? left % right : 0.0;
      default:
        return left + right;
    }
  }

  double _toNumber(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Handler for random-flow-node
/// Routes randomly to different branches based on weights
class RandomFlowNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.randomFlow;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final branches = getList<Map<String, dynamic>>(nodeData, 'branches');

    if (branches.isEmpty) {
      return const NodeResult.proceed();
    }

    // Calculate weights
    final weights = branches.map((branch) {
      final w = branch['weight'];
      if (w is num) return w.toDouble();
      if (w is String) return double.tryParse(w) ?? 1.0;
      return 1.0;
    }).toList();

    final totalWeight = weights.fold<double>(0.0, (sum, weight) => sum + weight);
    final random = math.Random().nextDouble() * totalWeight;

    // Find selected branch
    var cumulative = 0.0;
    var selectedIndex = 0;
    for (var i = 0; i < weights.length; i++) {
      cumulative += weights[i];
      if (random < cumulative) {
        selectedIndex = i;
        break;
      }
    }

    return NodeResult.proceed(targetPort: 'source-$selectedIndex');
  }
}

/// Handler for variable-node
/// Creates or updates variables
class VariableNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.variable;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final customNameValue = getBoolean(nodeData, 'customNameValue', false);
    final name = getString(nodeData, 'name', '');
    final isNumber = getBoolean(nodeData, 'isNumber', false);
    final value = nodeData['value'];

    // Resolve the value (might reference another variable)
    final resolvedValue = value is String ? state.resolveValue(value) : value ?? '';

    // Convert to number if needed
    dynamic finalValue;
    if (isNumber) {
      if (resolvedValue is num) {
        finalValue = resolvedValue.toDouble();
      } else if (resolvedValue is String) {
        finalValue = double.tryParse(resolvedValue) ?? 0.0;
      } else {
        finalValue = 0.0;
      }
    } else {
      finalValue = resolvedValue;
    }

    // Store the variable
    final varName = customNameValue ? nodeId : name;

    if (varName.isNotEmpty) {
      state.setVariable(varName, finalValue);
      state.setAnswerVariable(nodeId, finalValue);
      state.setAnswerVariableByKey(varName, finalValue);
    }

    return const NodeResult.proceed();
  }
}

/// Handler for jump-to-node
/// Jumps to a specific node in the flow
class JumpToNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.jumpTo;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    var targetNodeId = getString(nodeData, 'targetNodeId', '');
    if (targetNodeId.isEmpty) {
      targetNodeId = getString(nodeData, 'nodeId', '');
    }

    if (targetNodeId.isEmpty) {
      return const NodeResult.error(
        message: 'No target node specified',
        shouldProceed: true,
      );
    }

    return NodeResult.jumpTo(targetNodeId);
  }
}

/// Handler for business-hours-node
/// Routes based on current time vs business hours
class BusinessHoursNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.businessHours;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final timezone = getString(nodeData, 'timezone', DateTime.now().timeZoneName);
    final excludeDays = getList<String>(nodeData, 'excludeDays');
    final excludeDates = getList<String>(nodeData, 'excludeDates');
    final weeklyHours = getList<Map<String, dynamic>>(nodeData, 'weeklyHours');

    // Get current time in specified timezone
    final now = _getCurrentTimeInTimezone(timezone);

    // Check excluded dates (format: yyyy-MM-dd)
    final currentDate = _formatDate(now);
    if (excludeDates.contains(currentDate)) {
      return const NodeResult.proceed(targetPort: 'source-1'); // Outside business hours
    }

    // Check excluded days
    // DateTime.weekday: Monday=1, Tuesday=2, ..., Sunday=7
    // Convert to match Java's Calendar.DAY_OF_WEEK: Sunday=0, Monday=1, ..., Saturday=6
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentDayName = dayNames[now.weekday - 1];
    if (excludeDays.contains(currentDayName)) {
      return const NodeResult.proceed(targetPort: 'source-1'); // Outside business hours
    }

    // Check weekly hours
    final dayHours = weeklyHours.firstWhere(
      (hours) => hours['dayName']?.toString().toLowerCase() == currentDayName.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );

    if (dayHours.isEmpty || getBoolean(dayHours, 'available', false) == false) {
      return const NodeResult.proceed(targetPort: 'source-1'); // Not available this day
    }

    // Check time slots
    final slots = getList<Map<String, dynamic>>(dayHours, 'slots');
    final currentTime = _formatTime(now);

    final withinBusinessHours = slots.any((slot) {
      final start = slot['start']?.toString() ?? '00:00';
      final end = slot['end']?.toString() ?? '23:59';
      return currentTime.compareTo(start) >= 0 && currentTime.compareTo(end) <= 0;
    });

    return withinBusinessHours
        ? const NodeResult.proceed(targetPort: 'source-0') // Within business hours
        : const NodeResult.proceed(targetPort: 'source-1'); // Outside business hours
  }

  /// Get current time in the specified timezone
  /// Falls back to local time if timezone parsing fails
  DateTime _getCurrentTimeInTimezone(String timezone) {
    try {
      // Parse common timezone offset formats (e.g., "UTC+5:30", "GMT-8", etc.)
      final offsetPattern = RegExp(r'(?:UTC|GMT)?([+-])(\d{1,2}):?(\d{2})?', caseSensitive: false);
      final match = offsetPattern.firstMatch(timezone);

      if (match != null) {
        final sign = match.group(1) == '+' ? 1 : -1;
        final hours = int.parse(match.group(2) ?? '0');
        final minutes = int.parse(match.group(3) ?? '0');
        final offset = Duration(hours: hours * sign, minutes: minutes * sign);

        return DateTime.now().toUtc().add(offset);
      }

      // Try common timezone abbreviations
      final tzOffsets = _getTimezoneOffsets();
      if (tzOffsets.containsKey(timezone.toUpperCase())) {
        return DateTime.now().toUtc().add(tzOffsets[timezone.toUpperCase()]!);
      }

      // Try IANA timezone names (e.g., "America/New_York", "Asia/Kolkata")
      final ianaOffset = _getIanaTimezoneOffset(timezone);
      if (ianaOffset != null) {
        return DateTime.now().toUtc().add(ianaOffset);
      }
    } catch (e) {
      // Fall back to local time
    }

    return DateTime.now();
  }

  /// Get common timezone abbreviation offsets
  Map<String, Duration> _getTimezoneOffsets() {
    return {
      'UTC': Duration.zero,
      'GMT': Duration.zero,
      'EST': const Duration(hours: -5),
      'EDT': const Duration(hours: -4),
      'CST': const Duration(hours: -6),
      'CDT': const Duration(hours: -5),
      'MST': const Duration(hours: -7),
      'MDT': const Duration(hours: -6),
      'PST': const Duration(hours: -8),
      'PDT': const Duration(hours: -7),
      'IST': const Duration(hours: 5, minutes: 30),
      'CET': const Duration(hours: 1),
      'CEST': const Duration(hours: 2),
      'JST': const Duration(hours: 9),
      'AEST': const Duration(hours: 10),
      'AEDT': const Duration(hours: 11),
    };
  }

  /// Get offset for IANA timezone names
  Duration? _getIanaTimezoneOffset(String timezone) {
    // Common IANA timezone mappings (approximate, not accounting for DST)
    final ianaOffsets = {
      'America/New_York': const Duration(hours: -5),
      'America/Chicago': const Duration(hours: -6),
      'America/Denver': const Duration(hours: -7),
      'America/Los_Angeles': const Duration(hours: -8),
      'America/Toronto': const Duration(hours: -5),
      'America/Vancouver': const Duration(hours: -8),
      'Europe/London': Duration.zero,
      'Europe/Paris': const Duration(hours: 1),
      'Europe/Berlin': const Duration(hours: 1),
      'Europe/Rome': const Duration(hours: 1),
      'Europe/Madrid': const Duration(hours: 1),
      'Europe/Amsterdam': const Duration(hours: 1),
      'Europe/Brussels': const Duration(hours: 1),
      'Europe/Stockholm': const Duration(hours: 1),
      'Europe/Moscow': const Duration(hours: 3),
      'Asia/Dubai': const Duration(hours: 4),
      'Asia/Kolkata': const Duration(hours: 5, minutes: 30),
      'Asia/Mumbai': const Duration(hours: 5, minutes: 30),
      'Asia/Karachi': const Duration(hours: 5),
      'Asia/Dhaka': const Duration(hours: 6),
      'Asia/Bangkok': const Duration(hours: 7),
      'Asia/Singapore': const Duration(hours: 8),
      'Asia/Hong_Kong': const Duration(hours: 8),
      'Asia/Shanghai': const Duration(hours: 8),
      'Asia/Tokyo': const Duration(hours: 9),
      'Asia/Seoul': const Duration(hours: 9),
      'Australia/Sydney': const Duration(hours: 10),
      'Australia/Melbourne': const Duration(hours: 10),
      'Australia/Perth': const Duration(hours: 8),
      'Pacific/Auckland': const Duration(hours: 12),
    };

    return ianaOffsets[timezone];
  }

  /// Format date as yyyy-MM-dd
  String _formatDate(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Format time as HH:mm
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Registry for all logic node handlers
class LogicNodeHandlers {
  LogicNodeHandlers._();

  /// Get all logic node handlers
  static List<NodeHandler> get handlers => [
        ConditionNodeHandler(),
        BooleanLogicNodeHandler(),
        MathOperationNodeHandler(),
        RandomFlowNodeHandler(),
        VariableNodeHandler(),
        JumpToNodeHandler(),
        BusinessHoursNodeHandler(),
      ];

  /// Get handler by node type
  static NodeHandler? getHandler(String nodeType) {
    return handlers.firstWhere(
      (handler) => handler.nodeType == nodeType,
      orElse: () => throw ArgumentError('No handler found for node type: $nodeType'),
    );
  }

  /// Check if a handler exists for the given node type
  static bool hasHandler(String nodeType) {
    return handlers.any((handler) => handler.nodeType == nodeType);
  }
}
