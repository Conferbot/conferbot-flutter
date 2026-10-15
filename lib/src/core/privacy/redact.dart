/// Sensitive details visitors type, masked before anything is stored or sent:
/// payment cards (Luhn), bank accounts (IBAN, mod-97), government ids,
/// passwords and one-time codes said in a sentence, secret keys. Emails and
/// phone numbers are never masked.
///
/// A port of the web widget's conferbot-widget/src/ts/chat/privacy/redact.ts
/// and privacy/index.ts (maskRecordEntry, maskValue), via the React Native
/// SDK (src/core/privacy/redact.ts). The web applies it to the answer
/// variables (index.ts _setAnswerVariable / _setAnswerVariableByKey) and to
/// the visitor's own record entries (index.ts _pushDataToRecord). The
/// transcript keeps what was typed. Owners switch it off with
/// customizations.redactSensitive === false. The embed server runs the same
/// rules as a backstop - keep them in step.
library;

bool luhnOk(String digits) {
  var sum = 0;
  var dbl = false;
  for (var i = digits.length - 1; i >= 0; i -= 1) {
    var d = digits.codeUnitAt(i) - 48;
    if (dbl) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    dbl = !dbl;
  }
  return sum % 10 == 0;
}

bool ibanOk(String raw) {
  final s = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$').hasMatch(s)) return false;
  final moved = s.substring(4) + s.substring(0, 4);
  var rem = 0;
  for (final ch in moved.split('')) {
    final v = RegExp(r'[A-Z]').hasMatch(ch) ? (ch.codeUnitAt(0) - 55).toString() : ch;
    for (final c in v.split('')) {
      rem = (rem * 10 + (c.codeUnitAt(0) - 48)) % 97;
    }
  }
  return rem == 1;
}

class _Rule {
  final String kind;
  final RegExp re;
  final bool Function(String m)? test;
  final String Function(Match m) label;
  const _Rule(this.kind, this.re, this.label, [this.test]);
}

/// Rules in order: each replaces what it finds with a short label.
final List<_Rule> _rules = [
  // Payment cards: 13-19 digits, optionally in groups, passing Luhn.
  _Rule(
    'card',
    RegExp(r'\b(?:\d[ -]?){12,18}\d\b'),
    (m) {
      final d = m.group(0)!.replaceAll(RegExp(r'\D'), '');
      return '[card •••• ${d.substring(d.length - 4)}]';
    },
    (m) {
      final d = m.replaceAll(RegExp(r'\D'), '');
      return d.length >= 13 && d.length <= 19 && luhnOk(d) && !RegExp(r'^(\d)\1+$').hasMatch(d);
    },
  ),
  // Bank accounts (IBAN), with or without spaces.
  _Rule(
    'iban',
    RegExp(r'\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]{4}){2,7}(?:[ ]?[A-Z0-9]{1,4})?\b', caseSensitive: false),
    (_) => '[bank account hidden]',
    ibanOk,
  ),
  // CVV / security code said with its name.
  _Rule(
    'cvv',
    RegExp(r'\b(cvv2?|cvc2?|security code)\s*(?:is|:|=|-)?\s*\d{3,4}\b', caseSensitive: false),
    (m) => '${m.group(1)} [hidden]',
  ),
  // Passwords and PINs said in a sentence: "my password is hunter2".
  _Rule(
    'password',
    RegExp(r'''\b(password|passcode|passwd|pwd|pin)\b(\s*(?:is|was|:|=|-)\s*)("[^"]{3,64}"|'[^']{3,64}'|\S{2,63}[^\s.,;:!?)])''',
        caseSensitive: false),
    (m) => '${m.group(1)}${m.group(2)}[hidden]',
  ),
  // One-time codes said in a sentence: "the code is 482913".
  _Rule(
    'code',
    RegExp(r'\b((?:verification|one[- ]time|otp|2fa|login|security)\s+code|otp)\b(\s*(?:is|:|=|-)?\s*)(\d{4,8})\b',
        caseSensitive: false),
    (m) => '${m.group(1)}${m.group(2)}[hidden]',
  ),
  // US social security number.
  _Rule('id', RegExp(r'\b(?!000|666|9\d\d)\d{3}-(?!00)\d{2}-(?!0000)\d{4}\b'), (_) => '[id hidden]'),
  // UAE Emirates ID: 784-YYYY-NNNNNNN-N.
  _Rule('id', RegExp(r'\b784[- ]?\d{4}[- ]?\d{7}[- ]?\d\b'), (_) => '[id hidden]'),
  // India Aadhaar: 12 digits in groups of 4 (first digit 2-9).
  _Rule('id', RegExp(r'\b[2-9]\d{3}[ -]\d{4}[ -]\d{4}\b'), (_) => '[id hidden]'),
  // Secret keys and tokens people paste by mistake.
  _Rule(
    'secret',
    RegExp(
        r'\b(?:sk|rk|pk)_(?:live|test)_[A-Za-z0-9]{16,}\b|\bsk-[A-Za-z0-9_-]{20,}\b|\bAKIA[0-9A-Z]{16}\b|\bgh[pousr]_[A-Za-z0-9]{30,}\b|\bxox[abprs]-[A-Za-z0-9-]{10,}\b'),
    (_) => '[secret key hidden]',
  ),
];

// Email addresses are left whole: digits in one ("name+1791557018838@...")
// are not a card number.
final RegExp _emailSplit = RegExp(r'([A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,})');

String _maskPart(String part, List<String> found) {
  var out = part;
  for (final rule in _rules) {
    out = out.replaceAllMapped(rule.re, (m) {
      final whole = m.group(0)!;
      if (rule.test != null && !rule.test!(whole)) return whole;
      found.add(rule.kind);
      return rule.label(m);
    });
  }
  return out;
}

/// What [redactText] found and the masked text.
class RedactResult {
  final String text;
  final List<String> found;
  const RedactResult(this.text, this.found);
}

/// Mask what is sensitive in `text`: the masked text and the kinds masked.
RedactResult redactText(String text) {
  if (text.isEmpty) return RedactResult(text, const []);
  final found = <String>[];
  final out = StringBuffer();
  var last = 0;
  for (final m in _emailSplit.allMatches(text)) {
    out.write(_maskPart(text.substring(last, m.start), found));
    out.write(m.group(0));
    last = m.end;
  }
  out.write(_maskPart(text.substring(last), found));
  final unique = <String>[];
  for (final f in found) {
    if (!unique.contains(f)) unique.add(f);
  }
  return RedactResult(out.toString(), unique);
}

const List<String> _textFields = ['text', 'message', 'userInput', 'value', 'display', 'answer'];

bool _isVisitorEntry(Map entry) {
  final s = entry['shape'];
  final t = entry['type'];
  final v = (s != null && s != '' ? s : (t != null && t != '' ? t : '')).toString();
  return v.startsWith('user-');
}

/// The visitor's own record entry with its text fields masked (in place);
/// other entries untouched.
T maskRecordEntry<T>(T entry) {
  final e = entry;
  if (e is! Map || !_isVisitorEntry(e)) return entry;
  var found = <String>[];
  for (final f in _textFields) {
    final v = e[f];
    if (v is! String) continue;
    final r = redactText(v);
    if (r.found.isNotEmpty) {
      e[f] = r.text;
      found = [...found, ...r.found];
    }
  }
  if (found.isNotEmpty) {
    final merged = <String>[];
    for (final k in [...((e['redacted'] as List?)?.map((x) => x.toString()) ?? const <String>[]), ...found]) {
      if (!merged.contains(k)) merged.add(k);
    }
    e['redacted'] = merged;
  }
  return entry;
}

/// A value saved from an answer, masked when it is a string.
dynamic maskValue(dynamic value) => value is String ? redactText(value).text : value;
