/// The rules behind the logic steps, ported unchanged from the web widget:
/// conferbot-widget/src/ts/chat/handlers/conditionEval.ts (condition-node)
/// and handlers/logicValues.ts (math, boolean, variable, random split,
/// jump-to, business hours), via the React Native SDK's
/// src/core/flow/logic.ts. Pure: the variable lookup, clock and random
/// number are passed in. The embed server and the builder preview keep
/// copies too - keep them in step.
library;

import 'js.dart';
import 'zones.dart';

/// The condition step's settings (condition-node data).
class ConditionData {
  final bool? isNumber;
  final String? operator;
  final dynamic leftValue;
  final dynamic rightValue;
  final dynamic customLeftValue;
  final dynamic customRightValue;
  final bool? caseInsensitive;

  const ConditionData({
    this.isNumber,
    this.operator,
    this.leftValue,
    this.rightValue,
    this.customLeftValue,
    this.customRightValue,
    this.caseInsensitive,
  });

  /// From a node's data map.
  factory ConditionData.fromMap(Map<String, dynamic>? data) {
    final d = data ?? const <String, dynamic>{};
    return ConditionData(
      isNumber: jsTruthy(d['isNumber']),
      operator: d['operator'] == null ? null : jsString(d['operator']),
      leftValue: d['leftValue'],
      rightValue: d['rightValue'],
      customLeftValue: d['customLeftValue'],
      customRightValue: d['customRightValue'],
      caseInsensitive: jsTruthy(d['caseInsensitive']),
    );
  }
}

String _stringify(dynamic value) {
  if (value == null) return '';
  if (value is Map || value is List) return jsonStringify(value);
  return jsString(value);
}

// "${name}" / "{name}" typed into the variable field still means `name`
String _variableKey(dynamic raw) {
  final key = _stringify(raw).trim();
  final wrapped = RegExp(r'^\$?\{(\w+)\}$').firstMatch(key);
  return wrapped != null ? wrapped.group(1)! : key;
}

/// Fill `${name}` placeholders in a typed value; unknown names stay as written.
String interpolate(dynamic text, dynamic Function(String key) lookup) =>
    _stringify(text).replaceAllMapped(RegExp(r'\$\{(\w+)\}'), (m) {
      final value = lookup(m.group(1)!);
      return value == null ? m.group(0)! : _stringify(value);
    });

// A number or a quoted word, as typed: never an answer variable's name.
String? _literalOf(dynamic raw) {
  final text = _stringify(raw).trim();
  if (RegExp(r'^[-+]?\d+(?:\.\d+)?$').hasMatch(text)) return text;
  final quoted = RegExp(r'^"(.*)"$|' "^'(.*)'\$").firstMatch(text);
  return quoted == null ? null : (quoted.group(1) ?? quoted.group(2));
}

/// One side of the rule: the typed literal, or the variable's value. A plain
/// number (or a "quoted" word) left in the variable field is what the owner
/// meant to compare with - "greater than 3" - so when no answer has that
/// name it is taken as typed instead of as an empty variable.
dynamic resolveOperand(dynamic raw, dynamic isCustom, dynamic Function(String key) lookup) {
  if (jsTruthy(isCustom)) return interpolate(raw, lookup);
  final value = lookup(_variableKey(raw));
  if (value != null) return value;
  final literal = _literalOf(raw);
  return literal ?? value;
}

const Map<String, String> _operatorAliases = {
  '==': '=',
  'equals': '=',
  'not_equals': '!=',
  'greater_than': '>',
  'less_than': '<',
  'greater_than_or_equal': '>=',
  'less_than_or_equal': '<=',
  'not_contains': 'does not contain',
  'starts_with': 'starts with',
  'ends_with': 'ends with',
  'does_not_match': 'does not match',
};

double _asNumber(dynamic value) {
  if (value is num) return value.toDouble();
  // Keeps the long-standing Number(...) reading (empty/missing -> 0)
  return jsNumber(value is String ? value.trim() : value);
}

bool _isNumeric(dynamic value) {
  if (value is num) return value.isFinite;
  final text = _stringify(value).trim();
  return text != '' && jsNumber(text).isFinite;
}

RegExp? _safeRegExp(String pattern, {bool ignoreCase = false}) {
  try {
    return RegExp(pattern, caseSensitive: !ignoreCase);
  } catch (_) {
    return null;
  }
}

/// Ratings used to be stored as their emoji ("⭐⭐⭐", "😊"); they are now
/// stored as the number. A rule an owner wrote against the old emoji keeps
/// working: a value made only of stars, or one of the five faces (same order
/// as nodeKit FACE_VALUES), reads as its number.
const List<String> _ratingFaces = ['😡', '😐', '😊', '😀', '😁'];

dynamic ratingAlias(dynamic value) {
  if (value is! String) return value;
  final v = value.trim();
  if (RegExp(r'^(⭐)+$', unicode: true).hasMatch(v)) return '${v.runes.length}';
  final face = _ratingFaces.indexOf(v);
  return face >= 0 ? '${face + 1}' : value;
}

/// true -> the "yes" branch (source-0), false -> "no" (source-1).
/// `data` is a [ConditionData] or the node's data map.
bool evaluateCondition(dynamic condition, dynamic Function(String key) lookup) {
  final data = condition is ConditionData
      ? condition
      : ConditionData.fromMap(condition is Map ? Map<String, dynamic>.from(condition) : null);
  final isNumber = data.isNumber == true;
  final rawOperator = _stringify((data.operator == null || data.operator == '') ? '=' : data.operator).trim();
  final operator = _operatorAliases[rawOperator] ?? rawOperator;

  final left = ratingAlias(resolveOperand(data.leftValue, data.customLeftValue, lookup));
  final right = ratingAlias(resolveOperand(data.rightValue, data.customRightValue, lookup));

  if (operator == 'is_set') return _stringify(left).trim() != '';
  if (operator == 'is_not_set') return _stringify(left).trim() == '';

  final ci = data.caseInsensitive == true;
  String text(dynamic value) => ci ? _stringify(value).toLowerCase() : _stringify(value);

  switch (operator) {
    case '=':
    case '!=':
      {
        final equal = isNumber
            ? _asNumber(left) == _asNumber(right)
            : _isNumeric(left) && _isNumeric(right)
                ? _asNumber(left) == _asNumber(right)
                : text(left) == text(right);
        return operator == '=' ? equal : !equal;
      }
    case '<':
    case '>':
    case '<=':
    case '>=':
      {
        // String mode only compares when both sides really are numbers
        if (!isNumber && !(_isNumeric(left) && _isNumeric(right))) return false;
        final l = _asNumber(left);
        final r = _asNumber(right);
        if (l.isNaN || r.isNaN) return false;
        if (operator == '<') return l < r;
        if (operator == '>') return l > r;
        if (operator == '<=') return l <= r;
        return l >= r;
      }
    case 'contains':
      return !isNumber && text(left).contains(text(right));
    case 'does not contain':
      return !isNumber && !text(left).contains(text(right));
    case 'starts with':
      return !isNumber && text(left).startsWith(text(right));
    case 'ends with':
      return !isNumber && text(left).endsWith(text(right));
    case 'matches':
      {
        final re = _safeRegExp(_stringify(right), ignoreCase: ci);
        return !isNumber && re != null && re.hasMatch(_stringify(left));
      }
    case 'does not match':
      {
        final re = _safeRegExp(_stringify(right), ignoreCase: ci);
        return !isNumber && re != null && !re.hasMatch(_stringify(left));
      }
    default:
      return false;
  }
}

// ----- handlers/logicValues.ts -----

/// A name that reads like a variable: "price", "order.total", "_tmp".
final RegExp _identifier = RegExp(r'^[A-Za-z_][\w.]*$');

/// Words that are typed values, never variable names.
const Set<String> _booleanWords = {'true', 'false', 'yes', 'no', 'on', 'off'};

/// A ${name} or {name} placeholder (the "$" is optional).
final RegExp _placeholder = RegExp(r'\$?\{([A-Za-z_][\w.]*)\}');

/// "${name}" or "{name}" as the whole text: the variable's name, else null.
String? _wholePlaceholder(String text) {
  final m = RegExp(r'^\$?\{([A-Za-z_][\w.]*)\}$').firstMatch(text);
  return m?.group(1);
}

/// A saved value as text: lists read "a, b", other objects stay JSON.
String _asText(dynamic value) {
  if (value is List && value.every((v) => v == null || (v is! Map && v is! List))) {
    return value.map((v) => v == null ? '' : jsString(v)).join(', ');
  }
  return (value is Map || value is List) ? jsonStringify(value) : jsString(value);
}

/// Fill ${name} and {name} from the variables; unknown ones stay as written.
String fillPlaceholders(dynamic text, dynamic Function(String key) lookup) =>
    (text == null ? '' : jsString(text)).replaceAllMapped(_placeholder, (m) {
      final value = lookup(m.group(1)!);
      return value != null ? _asText(value) : m.group(0)!;
    });

/// Drop one pair of matching quotes around a typed value.
String _unquote(String text) {
  final m = RegExp(r'''^(["'])([\s\S]*)\1$''').firstMatch(text);
  return m != null ? m.group(2)! : text;
}

/// One side of a rule. A variable's value when `raw` names one that has a
/// value; null when it names a variable with no answer yet; otherwise the
/// typed text, with any placeholders inside it filled in.
dynamic valueOf(dynamic raw, dynamic Function(String key) lookup) {
  if (raw == null) return null;
  if (raw is! String) return raw;
  final text = raw.trim();

  final wrapped = _wholePlaceholder(text);
  final name = wrapped ?? text;
  if (name != '') {
    final value = lookup(name);
    if (value != null) return value;
  }

  // "${plan}" with no answer yet, or a bare name like "price": unanswered.
  if (wrapped != null) return null;
  if (_identifier.hasMatch(text) && !_booleanWords.contains(text.toLowerCase())) return null;

  return fillPlaceholders(_unquote(text), lookup);
}

/// A value as a number: NaN when it isn't one (never 0 for empty).
double toNumber(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  if (v == null || v is! String) return double.nan;
  var text = v.trim().replaceAll(RegExp(r'\s+'), '');
  if (text == '') return double.nan;
  if (RegExp(r'^[-+]?\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(text)) text = text.replaceAll(',', '');
  if (!RegExp(r'^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$').hasMatch(text)) return double.nan;
  return jsNumber(text);
}

const Set<String> _falseWords = {'false', 'no', 'n', '0', 'off', 'none', 'null', 'undefined', ''};

/// A value as true / false: "No", "off", "0" and empty are false.
bool toBool(dynamic v) {
  if (v == null || v == '') return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return !_falseWords.contains(v.trim().toLowerCase());
  if (v is List) return v.isNotEmpty;
  return true;
}

// ----- Math step -----

const String defaultMathVariable = 'math_operations';

/// The variable a math step saves its result under.
String mathVariableName(dynamic data) {
  final raw = data is Map ? data['answerVariable'] : null;
  final name = (raw == null ? '' : jsString(raw)).trim();
  return name.isNotEmpty ? name : defaultMathVariable;
}

/// The math step's result (a num), or "" when it can't be worked out (a side
/// that isn't a number, an unanswered variable, a divide by zero).
dynamic mathResult(dynamic data, dynamic Function(String key) lookup) {
  final d = data is Map ? data : const {};
  final l = toNumber(valueOf(d['leftValue'], lookup));
  final r = toNumber(valueOf(d['rightValue'], lookup));
  if (l.isNaN || r.isNaN) return '';
  final rawOp = d['operator'];
  final opText = (rawOp == null ? '' : jsString(rawOp)).trim();
  final op = opText.isNotEmpty ? opText : '+';
  double x;
  if (op == '+') {
    x = l + r;
  } else if (op == '-') {
    x = l - r;
  } else if (op == '*') {
    x = l * r;
  } else if (op == '/') {
    if (r == 0) return '';
    x = l / r;
  } else {
    return '';
  }
  if (!x.isFinite) return '';
  // Number(x.toFixed(10))
  return jsNum(double.parse(x.toStringAsFixed(10)));
}

// ----- Boolean step -----

/// The boolean step's answer: true takes source-0, false source-1.
bool booleanResult(dynamic data, dynamic Function(String key) lookup) {
  final d = data is Map ? data : const {};
  final l = toBool(valueOf(d['leftValue'], lookup));
  final r = toBool(valueOf(d['rightValue'], lookup));
  final rawOp = d['operator'];
  final opText = (rawOp == null ? '' : jsString(rawOp)).trim().toUpperCase();
  final op = opText.isNotEmpty ? opText : 'AND';
  switch (op) {
    case 'AND':
      return l && r;
    case 'OR':
      return l || r;
    case 'NOT':
      // "left NOT right": true when left is true and right is false
      return l && !r;
    case 'XOR':
      return l != r;
    case 'NAND':
      return !(l && r);
    case 'NOR':
      return !(l || r);
    case 'XNOR':
      return l == r;
    default:
      return false;
  }
}

// ----- Variable step -----

/// The value a variable step stores: placeholders filled, a number when asked.
dynamic variableValue(dynamic data, dynamic Function(String key) lookup) {
  final d = data is Map ? data : const {};
  final text = fillPlaceholders(d['value'] ?? '', lookup);
  if (jsTruthy(d['isNumber'])) {
    final n = toNumber(text);
    if (!n.isNaN) return jsNum(n);
  }
  return text;
}

// ----- Saving a variable -----

class LogicAnswerVariable {
  dynamic nodeId;
  String key;
  dynamic value;

  LogicAnswerVariable({this.nodeId, required this.key, this.value});

  Map<String, dynamic> toJson() => {'nodeId': nodeId, 'key': key, 'value': value};
}

/// Save a value under a variable's name: every entry with that name gets the
/// new value (so every read sees it); with none, one entry is added. Never a
/// duplicate, so "total = total + 1" in a loop counts 1, 2, 3...
List<LogicAnswerVariable> saveVariableByName(List<LogicAnswerVariable> list, String key, dynamic value, [dynamic nodeId]) {
  final matches = list.where((item) => item.key == key).toList();
  if (matches.isNotEmpty) {
    for (final item in matches) {
      item.value = value;
    }
  } else {
    list.add(LogicAnswerVariable(nodeId: nodeId ?? 'variable_$key', key: key, value: value));
  }
  return list;
}

// ----- Random split -----

/// A handle no edge uses: routing to it ends the flow.
const String noPath = '__no_path__';

double _weightOf(dynamic b) {
  final n = toNumber(b is Map ? b['weight'] : null);
  return n.isFinite && n > 0 ? n : 0;
}

/// Pick one of `items` by weight; all zero is an even split. `rand` in [0, 1).
T _pickWeighted<T>(List<T> items, List<double> weights, double rand) {
  final total = weights.fold<double>(0, (a, b) => a + b);
  if (total <= 0) {
    final i = (rand * items.length).floor();
    return items[i < items.length - 1 ? i : items.length - 1];
  }
  final target = rand * total;
  double acc = 0;
  for (var i = 0; i < items.length; i++) {
    acc += weights[i];
    if (weights[i] > 0 && target < acc) return items[i];
  }
  // rand at the very top: the last branch with any weight
  for (var i = items.length - 1; i >= 0; i--) {
    if (weights[i] > 0) return items[i];
  }
  return items[items.length - 1];
}

/// The handle a random split leaves by, or null when no branch has a line
/// (the flow ends). Branches are matched by id (source-<id>); a branch with
/// no line is skipped and the others share its weight. Position handles
/// (source-0..n) are only used by flows saved before branches had ids, when
/// no edge from this node uses an id handle.
String? pickRandomHandle(dynamic branches, List<dynamic>? edgeHandles, double rand) {
  final List<dynamic> list = branches is List ? branches : const [];
  final wired = (edgeHandles ?? const []).where((h) => h != null).map(jsString).toSet();
  String? idOf(dynamic b) {
    final id = b is Map ? b['id'] : null;
    return (id != null && id != '') ? jsString(id) : null;
  }

  final byId = list.where((b) => idOf(b) != null && wired.contains('source-${idOf(b)}')).toList();
  if (byId.isNotEmpty) {
    final picked = _pickWeighted(byId, byId.map(_weightOf).toList(), rand);
    return 'source-${idOf(picked)}';
  }

  // Legacy: every edge uses the branch's position.
  final byPosition = <int>[];
  for (var i = 0; i < list.length; i++) {
    if (wired.contains('source-$i')) byPosition.add(i);
  }
  if (byPosition.isNotEmpty) {
    final picked = _pickWeighted(byPosition, byPosition.map((i) => _weightOf(list[i])).toList(), rand);
    return 'source-$picked';
  }
  return null;
}

// ----- Jump to -----

/// The step a jump-to goes to ("" when none is set).
String jumpTargetOf(dynamic data) {
  final d = data is Map ? data : const {};
  for (final v in [d['nodeId'], d['targetNodeId'], d['jumpTo']]) {
    if (v != null && jsString(v).trim() != '') return jsString(v).trim();
  }
  return '';
}

// ----- Business hours -----

const List<String> _dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

String? _validZone(dynamic zone) {
  final z = (zone == null ? '' : jsString(zone)).trim();
  if (z.isEmpty) return null;
  return isValidZone(z) ? z : null;
}

/// The visitor's own zone, or UTC when the device won't say.
String _localZone() => _validZone(deviceTimeZone()) ?? 'UTC';

/// "9:00" -> "09:00"; null when it isn't a time.
String? _hhmm(dynamic t) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch((t == null ? '' : jsString(t)).trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 24 || min > 59) return null;
  return '${(h % 24).toString().padLeft(2, '0')}:${m.group(2)}';
}

/// "25-12-2026", "2026-12-25" (or with / or .) -> "2026-12-25"; else null.
String? normaliseDate(dynamic d) {
  final text = (d == null ? '' : jsString(d)).trim();
  var m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(text);
  if (m != null) return '${m.group(1)}-${m.group(2)!.padLeft(2, '0')}-${m.group(3)!.padLeft(2, '0')}';
  m = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$').firstMatch(text);
  if (m != null) return '${m.group(3)}-${m.group(2)!.padLeft(2, '0')}-${m.group(1)!.padLeft(2, '0')}';
  return null;
}

/// The time, date and weekday in a zone.
class ZonedNow {
  final String zone;

  /// YYYY-MM-DD
  final String date;

  /// HH:MM, 00:00 - 23:59
  final String time;

  /// 0 = Sunday
  final int dayIndex;
  final String dayName;

  const ZonedNow({required this.zone, required this.date, required this.time, required this.dayIndex, required this.dayName});
}

/// The time, date and weekday in a zone (an empty or invalid zone uses the fallback).
ZonedNow zonedNow(DateTime now, dynamic zone, [String? fallbackZone]) {
  final z = _validZone(zone) ?? _validZone(fallbackZone) ?? _localZone();
  final p = partsIn(now, z);
  return ZonedNow(zone: z, date: p.ymd, time: p.hhmm, dayIndex: p.weekday, dayName: _dayNames[p.weekday]);
}

String _previousDate(String ymd) {
  final parts = ymd.split('-').map(int.parse).toList();
  final d = DateTime.utc(parts[0], parts[1], parts[2] - 1);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Whether the business is open at `now`, read in the owner's timezone.
/// Slot times are the owner's clock and are compared as "HH:MM" in that
/// zone. An overnight slot (22:00 - 02:00) is open from its start until
/// midnight and, the next day, until its end.
bool isWithinBusinessHours(dynamic data, [DateTime? now, String? fallbackZone]) {
  final d = data is Map ? data : const {};
  final at = zonedNow(now ?? DateTime.now(), d['timezone'], fallbackZone);
  final List<dynamic> weekly = d['weeklyHours'] is List ? d['weeklyHours'] as List : const [];
  final excludedDays = (d['excludeDays'] is List ? d['excludeDays'] as List : const [])
      .map((x) => jsString(x).trim().toLowerCase())
      .toSet();
  final excludedDates = (d['excludeDates'] is List ? d['excludeDates'] as List : const [])
      .map(normaliseDate)
      .whereType<String>()
      .toSet();

  bool isClosedDay(String dayName, String date) =>
      excludedDays.contains(dayName.toLowerCase()) || excludedDates.contains(date);
  dynamic hoursFor(int dayIndex) {
    for (final w in weekly) {
      final name = w is Map ? w['dayName'] : null;
      if ((name == null ? '' : jsString(name)).trim().toLowerCase() == _dayNames[dayIndex].toLowerCase()) return w;
    }
    for (final w in weekly) {
      final day = w is Map ? w['day'] : null;
      if (jsNumber(day) == dayIndex && day != null && day != '') return w;
    }
    return null;
  }

  List<List<String>> slotsOf(dynamic day) {
    if (day is! Map || !jsTruthy(day['available']) || day['slots'] is! List) return const [];
    final out = <List<String>>[];
    for (final s in day['slots'] as List) {
      final start = _hhmm(s is Map ? s['start'] : null);
      final end = _hhmm(s is Map ? s['end'] : null);
      if (start != null && end != null) out.add([start, end]);
    }
    return out;
  }

  if (at.dayIndex < 0 || isClosedDay(at.dayName, at.date)) return false;

  // Today's slots
  for (final s in slotsOf(hoursFor(at.dayIndex))) {
    final start = s[0], end = s[1];
    if (start.compareTo(end) <= 0
        ? start.compareTo(at.time) <= 0 && at.time.compareTo(end) <= 0
        : at.time.compareTo(start) >= 0) {
      return true;
    }
  }

  // Yesterday's overnight slots running past midnight
  final yIndex = (at.dayIndex + 6) % 7;
  final yDate = _previousDate(at.date);
  if (!isClosedDay(_dayNames[yIndex], yDate)) {
    for (final s in slotsOf(hoursFor(yIndex))) {
      if (s[1].compareTo(s[0]) < 0 && at.time.compareTo(s[1]) <= 0) return true;
    }
  }
  return false;
}
