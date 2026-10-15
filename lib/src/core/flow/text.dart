/// Text helpers the flow steps share, ported from the web widget
/// (conferbot-widget/src/ts/chat/nodeLogic.ts, richNodes.ts plainText,
/// utils/helpers.ts _stripHtmlAndDecodeEntities) via the React Native SDK
/// (src/core/flow/text.ts). Pure: no state.
///
/// The flow-node spec (nodes.spec.json, engine.interpolation) is the
/// reference: {x}, ${x}, {{x}}, ${ANSWERS.x} and $${x} fill from the
/// answers; an unknown, null or "" value shows nothing and the gap it leaves
/// is tidied; values are HTML-escaped.
library;

import 'js.dart';

typedef VariableLookup = dynamic Function(String key);

bool _plainScalar(dynamic v) => v == null || v is String || v is num || v is bool;
bool _plainList(dynamic v) => v is List && v.every(_plainScalar);

/// A saved value as text: a list reads "a, b"; a matrix answer
/// ({ row: column } or a list of columns per row) "Row: Col · Row2: Col2";
/// any other object is JSON.
String variableText(dynamic value) {
  if (_plainList(value)) return (value as List).map((v) => v == null ? '' : jsString(v)).join(', ');
  if (value is Map) {
    final entries = value.entries.toList();
    if (entries.isNotEmpty && entries.every((e) => _plainScalar(e.value) || _plainList(e.value))) {
      return entries
          .map((e) => '${e.key}: ${e.value is List ? (e.value as List).map((v) => v == null ? '' : jsString(v)).join(', ') : jsString(e.value)}')
          .join(' · ');
    }
  }
  return (value is Map || value is List) ? jsonStringify(value) : jsString(value);
}

/// Text made safe inside HTML.
String escapeHtmlText(dynamic value) => (value == null ? '' : jsString(value))
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// {x}, ${x}, $${x}, {{x}} and ${ANSWERS.x}: group 1/3 the "$" prefix, 2/4 the key.
final RegExp _placeholder =
    RegExp(r'(\$\$|\$)?\{\{\s*((?:ANSWERS\.)?\w+)\s*\}\}|(\$\$|\$)?\{\s*((?:ANSWERS\.)?\w+)\s*\}');
const String _gap = '\u0000';

/// A gap left by an empty placeholder, tidied ("Hey ${name}, welcome" -> "Hey, welcome").
String _closeGaps(String text) {
  if (!text.contains(_gap)) return text;
  return text
      .replaceAllMapped(RegExp('(^|>)[ \\t]*\\u0000+[ \\t]*[,;:]?[ \\t]*'), (m) => m.group(1)!)
      .replaceAll(RegExp('[ \\t]*\\u0000+(?=[ \\t]*([,.!?;:)]|<|\$))'), '')
      .replaceAllMapped(RegExp('([ \\t])\\u0000+[ \\t]+'), (m) => m.group(1)!)
      .replaceAll(_gap, '');
}

dynamic _lookupKey(VariableLookup lookup, String key) {
  var value = lookup(key);
  if (value == null && key.startsWith('ANSWERS.')) value = lookup(key.substring(8));
  return value;
}

/// Fill the placeholders in owner text from the answers (web nodeLogic.fillVariables).
/// [mode] "html" (default) escapes the values; "raw" leaves them as they are.
String fillVariables(dynamic text, VariableLookup lookup, {String mode = 'html'}) {
  final raw = mode == 'raw';
  final filled = (text == null ? '' : jsString(text)).replaceAllMapped(_placeholder, (m) {
    final prefix = m.group(1) ?? m.group(3);
    final key = m.group(2) ?? m.group(4)!;
    final value = _lookupKey(lookup, key);
    if (value == null || value == '') return _gap;
    final shown = raw ? variableText(value) : escapeHtmlText(variableText(value));
    return prefix == r'$$' ? '\$$shown' : shown;
  });
  return _closeGaps(filled);
}

/// Fill the variables in a link: a value in the query or hash is URL-encoded,
/// one before it goes in as is; an unknown one stays as written.
String fillLinkVariables(dynamic link, VariableLookup lookup) {
  final text = (link == null ? '' : jsString(link)).trim();
  final out = StringBuffer();
  var last = 0;
  for (final m in _placeholder.allMatches(text)) {
    out.write(text.substring(last, m.start));
    last = m.end;
    final key = m.group(2) ?? m.group(4)!;
    final value = _lookupKey(lookup, key);
    if (value == null) {
      out.write(m.group(0));
      continue;
    }
    final shown = variableText(value).trim();
    final inQuery = RegExp(r'[?#]').hasMatch(out.toString());
    out.write(((m.group(1) ?? m.group(3)) == r'$$' ? r'$' : '') + (inQuery ? encodeUriComponent(shown) : shown));
  }
  out.write(text.substring(last));
  return out.toString();
}

/// The visitor's first name, capitalised: "deepak gopal" -> "Deepak".
String firstNameOf(dynamic value) {
  final parts = (value == null ? '' : jsString(value)).trim().split(RegExp(r'\s+'));
  final first = parts.isEmpty ? '' : parts[0];
  return first.isNotEmpty ? first[0].toUpperCase() + first.substring(1) : '';
}

/// True when owner HTML shows nothing ("<p><br></p>").
bool isBlankHtml(dynamic html) {
  final s = html == null ? '' : jsString(html);
  if (RegExp(r'<(img|iframe|video|audio|svg)\b', caseSensitive: false).hasMatch(s)) return false;
  return s
          .replaceAll(RegExp(r'<\/?[^>]+(>|$)'), '')
          .replaceAll(RegExp('&nbsp;|&#160;| |\ufeff|&#xFEFF;', caseSensitive: false), '')
          .trim() ==
      '';
}

/// The ask-name greeting by first name: none set at all is the default
/// "Nice to meet you, X"; one cleared in the builder is "" (no bubble).
String nameGreetingHtml(dynamic template, dynamic name) {
  final first = escapeHtmlText(firstNameOf(name));
  if (template == null) return first.isNotEmpty ? 'Nice to meet you, $first' : '';
  if (isBlankHtml(template)) return '';
  return _closeGaps(jsString(template).replaceAll(RegExp(r'\$?\{\{?\s*name\s*\}?\}'), first.isNotEmpty ? first : _gap));
}

/// Owner HTML as one line of plain text (web richNodes.plainText).
String plainText(dynamic value) => (value == null ? '' : jsString(value))
    .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'<\/?[^>]+(>|$)'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Tags stripped and entities decoded, trimmed (web helpers _stripHtmlAndDecodeEntities).
String stripHtmlAndDecode(dynamic html) {
  if (!jsTruthy(html)) return '';
  return jsString(html)
      .replaceAll(RegExp(r'<\/?[^>]+(>|$)'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)))
      .replaceAllMapped(RegExp(r'&#x([0-9A-Fa-f]+);'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
      .trim();
}

/// Owner HTML as the text a native bubble shows: paragraphs and <br> keep
/// their line breaks, tags go, entities are decoded.
String bubbleText(dynamic html) => (html == null ? '' : jsString(html))
    .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<\/p>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// Owner HTML for the HTML step, made safe: no <script>, no on* handlers,
/// no javascript:/vbscript: URLs (web nodeLogic.sanitizeOwnerHtml).
String sanitizeOwnerHtml(dynamic html) => (html == null ? '' : jsString(html))
    .replaceAll(RegExp(r'<script\b[\s\S]*?<\/script\s*>', caseSensitive: false), '')
    .replaceAll(RegExp(r'<script\b[^>]*\/?>', caseSensitive: false), '')
    .replaceAll(RegExp(r'<(object|embed|base|meta|link)\b[^>]*>', caseSensitive: false), '')
    .replaceAll(RegExp(r'''\s+on[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)''', caseSensitive: false), '')
    .replaceAllMapped(
      RegExp(r'''\s(href|src|action|formaction|xlink:href)\s*=\s*("|')?\s*(javascript|vbscript|data:text\/html)[^"'\s>]*("|')?''',
          caseSensitive: false),
      (m) => ' ${m.group(1)}="#"',
    );

/// The field holding the text a step shows, by type (web nodeLogic PROMPT_FIELD).
const Map<String, String> promptField = {
  'welcome-node': 'text',
  'message-node': 'text',
  'ask-name-node': 'questionText',
  'ask-email-node': 'questionText',
  'ask-phone-number-node': 'questionText',
  'ask-number-node': 'questionText',
  'ask-url-node': 'questionText',
  'ask-location-node': 'questionText',
  'ask-custom-question-node': 'questionText',
  'ask-file-node': 'questionText',
  'ask-multiple-questions-node': 'message',
  'calendar-node': 'calendarPrompt',
  'n-choices-node': 'choicePrompt',
  'n-select-option-node': 'selectPrompt',
  'n-check-options-node': 'checkOptionsPrompt',
  'image-choice-node': 'questionText',
  'carousel-node': 'questionText',
  'rating-choice-node': 'questionText',
  'yes-or-no-choice-node': 'questionText',
  'opinion-scale-choice-node': 'questionText',
  'user-redirect-node': 'redirectPrompt',
  'navigate-node': 'navigatePrompt',
  'quiz-node': 'quizPrompt',
  'human-handover-node': 'handoverMessage',
  'dynamic-choices-node': 'questionText',
  'consent-node': 'questionText',
  'product-card-node': 'questionText',
  'slider-node': 'questionText',
  'datetime-node': 'questionText',
  'ranking-node': 'questionText',
  'otp-node': 'questionText',
  'address-node': 'questionText',
  'matrix-node': 'questionText',
  'ai-extract-node': 'questionText',
  'ai-route-node': 'questionText',
  'kb-answer-node': 'questionText',
  'signature-node': 'questionText',
};

Map<String, dynamic> _dataOf(dynamic node) {
  if (node is Map && node['data'] is Map) return Map<String, dynamic>.from(node['data'] as Map);
  return const {};
}

String? _typeOf(dynamic node) => node is Map ? node['type']?.toString() : null;

/// A step's own text with the variables filled in; null when it shows none.
/// [node] is the saved node map ({id, type, data}).
String? renderedTextFor(dynamic node, VariableLookup lookup) {
  final field = promptField[_typeOf(node)];
  final raw = field != null ? _dataOf(node)[field] : null;
  if (raw is! String || raw.trim() == '') return null;
  return fillVariables(raw, lookup);
}

/// A message with no text or an image with no picture is skipped (no typing).
bool isEmptyContentStep(dynamic step) {
  final type = _typeOf(step);
  if (type == 'message-node') return isBlankHtml(_dataOf(step)['text']);
  if (type == 'image-node') {
    final image = _dataOf(step)['image'];
    return (image == null ? '' : jsString(image)).trim() == '';
  }
  return false;
}

/// Ticked options in list order, not click order.
List<dynamic> inListOrder(List<dynamic>? picked, List<dynamic>? list) {
  final order = (list ?? const []).map((v) => jsString(v)).toList();
  int rank(dynamic v) {
    final i = order.indexOf(jsString(v));
    return i == -1 ? 9007199254740991 : i;
  }

  final indexed = <MapEntry<int, dynamic>>[];
  final p = picked ?? const [];
  for (var i = 0; i < p.length; i++) {
    indexed.add(MapEntry(i, p[i]));
  }
  indexed.sort((a, b) {
    final r = rank(a.value).compareTo(rank(b.value));
    return r != 0 ? r : a.key.compareTo(b.key);
  });
  return indexed.map((e) => e.value).toList();
}

double _clamp(double n, double lo, double hi) => n < lo ? lo : (n > hi ? hi : n);

/// A step's length for pacing: its message or question, tags stripped.
int _wordsOf(dynamic step) {
  final d = _dataOf(step);
  final raw = d['text'] ?? d['questionText'] ?? d['calendarPrompt'] ?? d['message'] ?? '';
  return jsString(raw)
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .length;
}

/// JavaScript Math.round (halves round up).
int _round(double x) => (x + 0.5).floor();

/// How long the typing dots show before a bot step (web nodeLogic.paceFor):
/// after the visitor spoke, clamp(500 + len*12, 700, 1800); right after a
/// step that moved on by itself, time to read it, then a shorter beat.
int paceFor(dynamic previous, dynamic next, bool followsBotStep) {
  final nextLen = _wordsOf(next);
  if (!followsBotStep) return _round(_clamp(500.0 + nextLen * 12, 700, 1800));
  final read = _clamp(_wordsOf(previous) * 22.0, 350, 2200);
  return _round(read + _clamp(250.0 + nextLen * 6, 300, 900));
}

const Set<String> _autoAdvanceTypes = {
  'welcome-node',
  'message-node',
  'image-node',
  'video-node',
  'audio-node',
  'file-node',
  'html-node',
  'user-redirect-node',
};

/// True when the step before was a bot step that moved on by itself.
bool followsAutoAdvanceStep(dynamic previousType) =>
    _autoAdvanceTypes.contains(previousType == null ? '' : jsString(previousType));
