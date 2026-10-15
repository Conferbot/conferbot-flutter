/// JavaScript value rules the flow code relies on, so the Dart ports of the
/// web widget's flow logic read values the way the widget does: `String(x)`,
/// `Number(x)`, truthiness and `JSON.stringify`. Pure.
library;

import 'dart:convert';

/// `String(value)` as JavaScript writes it: whole numbers without ".0",
/// null as "null", lists joined with ",".
String jsString(dynamic value) {
  if (value == null) return 'null';
  if (value is String) return value;
  if (value is bool) return value ? 'true' : 'false';
  if (value is int) return value.toString();
  if (value is double) return jsNumberText(value);
  if (value is List) return value.map((v) => v == null ? '' : jsString(v)).join(',');
  if (value is Map) return '[object Object]';
  return value.toString();
}

/// A number as JavaScript prints it ("2", "1.5", "NaN", "Infinity").
String jsNumberText(num n) {
  if (n is int) return n.toString();
  final d = n.toDouble();
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d > 0 ? 'Infinity' : '-Infinity';
  if (d == d.truncateToDouble() && d.abs() < 1e21) {
    // -0 prints as "0" in JavaScript.
    return d == 0 ? '0' : d.toInt().toString();
  }
  final s = d.toString();
  // Dart writes 1e-7 as "1e-7" like JavaScript; it already matches otherwise.
  return s;
}

/// `Number(value)`: "" and null are 0, booleans 1/0, text is parsed whole
/// (trimmed; hex allowed), anything else NaN.
double jsNumber(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is bool) return value ? 1 : 0;
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return 0;
    if (RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$').hasMatch(s)) {
      return double.parse(s);
    }
    if (RegExp(r'^0[xX][0-9a-fA-F]+$').hasMatch(s)) {
      return int.parse(s.substring(2), radix: 16).toDouble();
    }
    if (s == 'Infinity' || s == '+Infinity') return double.infinity;
    if (s == '-Infinity') return double.negativeInfinity;
    return double.nan;
  }
  if (value is List) {
    if (value.isEmpty) return 0;
    if (value.length == 1) return jsNumber(value.first is List ? jsString(value.first) : value.first);
    return double.nan;
  }
  return double.nan;
}

/// `Number.isFinite(Number(value))`.
bool jsIsFiniteNumber(dynamic value) => jsNumber(value).isFinite;

/// A JavaScript number kept as an int when it is whole (so it prints and
/// compares as the widget's value does).
num jsNum(double d) {
  if (d.isFinite && d == d.truncateToDouble() && d.abs() < 9007199254740992) return d.toInt();
  return d;
}

/// JavaScript truthiness.
bool jsTruthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return !(value == 0 || (value is double && value.isNaN));
  if (value is String) return value.isNotEmpty;
  return true;
}

/// `parseFloat(value)`: the leading number in the text, else NaN.
double jsParseFloat(dynamic value) {
  final s = jsString(value).trimLeft();
  final m = RegExp(r'^[+-]?(Infinity|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)').firstMatch(s);
  if (m == null) return double.nan;
  final t = m.group(0)!;
  if (t.endsWith('Infinity')) return t.startsWith('-') ? double.negativeInfinity : double.infinity;
  return double.parse(t);
}

/// `parseInt(value, 10)`: the leading whole number in the text, else NaN.
double jsParseInt(dynamic value) {
  final m = RegExp(r'^\s*([+-]?\d+)').firstMatch(jsString(value));
  return m == null ? double.nan : double.parse(m.group(1)!);
}

/// `JSON.stringify(value)`: whole doubles written without ".0".
String jsonStringify(dynamic value) => jsonEncode(_jsonSafe(value));

dynamic _jsonSafe(dynamic v) {
  if (v is double) {
    if (!v.isFinite) return null;
    return jsNum(v);
  }
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), _jsonSafe(val)));
  if (v is List) return v.map(_jsonSafe).toList();
  return v;
}

/// `date.toISOString()`: UTC with milliseconds ("2026-10-15T10:00:00.000Z").
String jsIsoString(DateTime date) {
  final d = date.toUtc();
  String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
  return '${p(d.year, 4)}-${p(d.month)}-${p(d.day)}T${p(d.hour)}:${p(d.minute)}:${p(d.second)}.${p(d.millisecond, 3)}Z';
}

/// `encodeURIComponent`.
String encodeUriComponent(String s) => Uri.encodeComponent(s);
