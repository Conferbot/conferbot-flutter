/// The rich steps' rules, the pure half - ported from the web widget
/// (conferbot-widget/src/ts/chat/richNodes.ts, via RN src/core/flow/rich.ts)
/// with its English texts: dynamic choices, hidden fields, consent, product
/// card, slider, date/time picker, ranking, verification code, address,
/// matrix, AI extract / route, knowledge-base answer, signature and payment.
/// What each node shows, the value it saves and the checks it runs - no UI.
///
/// Every rule here has a twin in embed-server
/// (services/omnichannel/nodeHandlers/richNodes.js), the server's save check
/// (server utils/richNodeSchemas.js) and the builder
/// (client builder/utils/richNodes.ts). Keep them in step.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'i18n_en.dart';
import 'js.dart';

// ignore_for_file: constant_identifier_names

const List<String> richNodeTypes = [
  'dynamic-choices-node',
  'hidden-fields-node',
  'consent-node',
  'product-card-node',
  'slider-node',
  'datetime-node',
  'ranking-node',
  'otp-node',
  'address-node',
  'matrix-node',
  'ai-extract-node',
  'ai-route-node',
  'kb-answer-node',
  'signature-node',
  'payment-node',
  // Loops and sub-flows (flowControl.ts): logic, nothing shown.
  'loop-node',
  'subflow-node',
  'run-subflow-node',
  'subflow-return-node',
];

/// Rich nodes that show nothing and move straight on.
const List<String> richLogicTypes = ['hidden-fields-node', 'loop-node', 'subflow-node', 'run-subflow-node', 'subflow-return-node'];

bool isRichNode(dynamic type) => richNodeTypes.contains(type);
bool isRichDisplayNode(dynamic type) => isRichNode(type) && !richLogicTypes.contains(type);

// ----- small readers -----

/// `data?.[key]` for a map (anything else reads nothing).
dynamic _f(dynamic data, String key) => data is Map ? data[key] : null;

/// `Number(data?.[key])`: NaN when the key is absent (JS undefined), else Number().
double _numField(dynamic data, String key) =>
    data is Map && data.containsKey(key) ? jsNumber(data[key]) : double.nan;

/// `String(v ?? "")`.
String _s(dynamic v) => v == null ? '' : jsString(v);

String _slice(String s, int start, [int? end]) {
  final e = end == null ? s.length : math.min(end, s.length);
  if (start >= e) return '';
  return s.substring(start, e);
}

/// Escape a string for HTML text or a double-quoted attribute.
String escHtml(dynamic value) => _s(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// Visible text of a stored HTML fragment.
String plainText(dynamic value) => _s(value)
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

// ---------------------------------------------------------------------------
// Paths into data ("data.items", "items[0].name")
// ---------------------------------------------------------------------------

/// A path the editor accepts: dotted keys, with [n] indexes. Empty is fine.
final RegExp pathRe = RegExp(r'^[A-Za-z_$][\w$-]*(\[\d+\])*(\.[A-Za-z_$][\w$-]*(\[\d+\])*)*$');

bool isValidPath(dynamic path) {
  final p = _s(path).trim();
  return p == '' || pathRe.hasMatch(p);
}

/// Read a dotted path; null (JS undefined) when any step is missing.
dynamic getPath(dynamic value, dynamic path) {
  final p = _s(path).trim();
  if (p.isEmpty) return value;
  final parts = p.replaceAllMapped(RegExp(r'\[(\d+)\]'), (m) => '.${m.group(1)}').split('.').where((x) => x.isNotEmpty);
  dynamic cur = value;
  for (final key in parts) {
    if (cur == null) return null;
    if (cur is Map) {
      cur = cur[key];
    } else if (cur is List) {
      final i = int.tryParse(key);
      if (key == 'length') {
        cur = cur.length;
      } else {
        cur = (i != null && i >= 0 && i < cur.length) ? cur[i] : null;
      }
    } else {
      return null;
    }
  }
  return cur;
}

/// A variable's value as data: JSON text (a webhook reply saved as text) is parsed.
dynamic asData(dynamic value) {
  if (value is! String) return value;
  final t = value.trim();
  if (!(t.startsWith('[') || t.startsWith('{'))) return value;
  try {
    return jsonDecode(t);
  } catch (_) {
    return value;
  }
}

// ---------------------------------------------------------------------------
// (1) Dynamic choices
// ---------------------------------------------------------------------------

const int dynamicMaxOptions = 50;
const int dynamicDefaultMax = 10;

class DynamicOption {
  final String id;
  final String label;

  /// What is saved: the item's value as it came (number, text, boolean).
  final dynamic value;

  const DynamicOption({required this.id, required this.label, required this.value});

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'value': value};
}

/// The variable a dynamic choice node reads its list from.
String dynamicSourceVariable(dynamic data) => _s(_f(data, 'sourceVariable')).trim();

bool _scalar(dynamic v) => v == null || v is String || v is num || v is bool;

/// The options a dynamic choice node offers, from the value of its source
/// variable (a list of strings or objects, or an object holding one at
/// `listPath`). Objects read their label and value from `labelField` /
/// `valueField`, or from the usual names (label, name, title, text / value,
/// id). Empty labels are dropped, repeats shown once, at most `maxOptions`.
List<DynamicOption> dynamicOptions(dynamic data, dynamic sourceValue) {
  final root = asData(sourceValue);
  var list = getPath(root, _f(data, 'listPath'));
  list = asData(list);
  if (list is! List) return [];
  final labelField = _s(_f(data, 'labelField')).trim();
  final valueField = _s(_f(data, 'valueField')).trim();
  final wanted = _numField(data, 'maxOptions').floorToDouble();
  final maxRaw = (wanted.isNaN || wanted == 0) ? dynamicDefaultMax.toDouble() : wanted;
  final max = math.max(1.0, math.min(dynamicMaxOptions.toDouble(), maxRaw));
  final seen = <String>{};
  final out = <DynamicOption>[];
  for (final item in list) {
    if (out.length >= max) break;
    dynamic label;
    dynamic value;
    if (_scalar(item)) {
      if (item == null) continue;
      label = item;
      value = item;
    } else if (item is Map || item is List) {
      final obj = item is Map ? item : const {};
      label = labelField.isNotEmpty ? getPath(item, labelField) : (obj['label'] ?? obj['name'] ?? obj['title'] ?? obj['text']);
      value = valueField.isNotEmpty ? getPath(item, valueField) : (obj['value'] ?? obj['id'] ?? label);
    } else {
      continue;
    }
    final text = plainText(_scalar(label) ? label : '');
    if (text.isEmpty) continue;
    if (!_scalar(value) || value == null) value = text;
    final key = '$text\u0000${jsString(value)}';
    if (seen.contains(key)) continue;
    seen.add(key);
    out.add(DynamicOption(id: 'opt-${out.length}', label: text, value: value));
  }
  return out;
}

/// The handle a dynamic choice leaves by: picked ("source") or empty list.
const String dynamicEmptyHandle = 'source-empty';

// ---------------------------------------------------------------------------
// (2) Hidden fields / URL parameters
// ---------------------------------------------------------------------------

const int hiddenMaxValue = 500;

class HiddenParam {
  final String name;
  final String variable;
  const HiddenParam({required this.name, required this.variable});
}

/// The parameters a hidden fields node reads (named, with a variable).
List<HiddenParam> hiddenParamsOf(dynamic data) {
  final params = _f(data, 'params');
  return (params is List ? params : const [])
      .map((p) => HiddenParam(name: _s(_f(p, 'name')).trim(), variable: _s(_f(p, 'variable')).trim()))
      .where((p) => p.name.isNotEmpty && p.variable.isNotEmpty)
      .toList();
}

String _clip(dynamic v) => _slice(_s(v).trim(), 0, hiddenMaxValue);

/// A page address worth keeping: http(s) only (not about:srcdoc, file:, blob:).
bool isWebAddress(dynamic v) => RegExp(r'^https?:\/\/', caseSensitive: false).hasMatch(_s(v));

/// `new URLSearchParams(search)` read as name -> first value.
Map<String, String> _searchParams(String search) {
  var s = search;
  if (s.startsWith('?')) s = s.substring(1);
  final out = <String, String>{};
  for (final part in s.split('&')) {
    if (part.isEmpty) continue;
    final i = part.indexOf('=');
    final rawName = i == -1 ? part : part.substring(0, i);
    final rawValue = i == -1 ? '' : part.substring(i + 1);
    String dec(String x) {
      final plus = x.replaceAll('+', ' ');
      try {
        return Uri.decodeComponent(plus);
      } catch (_) {
        return plus;
      }
    }

    out.putIfAbsent(dec(rawName), () => dec(rawValue));
  }
  return out;
}

/// What a hidden fields node captures: { variable: value } for each
/// parameter present in the page's query (the current page first, then the
/// page the visitor landed on), plus the page URL and the referrer when asked
/// for. Missing parameters are left out, so "is empty" conditions work.
/// `page` keys: href, referrer, landingSearch.
Map<String, String> captureHiddenFields(dynamic data, Map<String, dynamic> page) {
  final out = <String, String>{};
  var current = <String, String>{};
  final href = page['href'];
  if (href is String && href.isNotEmpty) {
    final uri = Uri.tryParse(href);
    if (uri != null && uri.hasScheme) {
      // The query only (a URL's searchParams), never the hash.
      current = _searchParams(uri.hasQuery ? uri.query : '');
    }
  }
  final landing = _searchParams(_s(page['landingSearch']));
  for (final p in hiddenParamsOf(data)) {
    final v = current[p.name] ?? landing[p.name];
    if (v != null && _clip(v) != '') out[p.variable] = _clip(v);
  }
  final pageVar = _s(_f(data, 'pageUrlVariable')).trim();
  if (_f(data, 'capturePageUrl') != false && pageVar.isNotEmpty && isWebAddress(page['href'])) out[pageVar] = _clip(page['href']);
  final refVar = _s(_f(data, 'referrerVariable')).trim();
  if (_f(data, 'captureReferrer') != false && refVar.isNotEmpty && isWebAddress(page['referrer'])) out[refVar] = _clip(page['referrer']);
  return out;
}

// ---------------------------------------------------------------------------
// (3) Consent - markdown-lite text
// ---------------------------------------------------------------------------

/// A link the consent text may carry: http(s) or mailto only.
String safeLink(dynamic url) {
  final raw = _s(url).trim();
  if (RegExp(r'^(https?:\/\/|mailto:)\S+$', caseSensitive: false).hasMatch(raw)) return raw;
  if (RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+(\/\S*)?$', caseSensitive: false).hasMatch(raw)) return 'https://$raw';
  return '';
}

final RegExp _mdLink = RegExp(r'\[([^\]\n]{1,200})\]\(((?:[^()\s]|\([^()\s]*\)){1,500})\)');

/// Markdown-lite to HTML: [text](url) links (new tab), **bold**, *italic* or
/// _italic_, and line breaks. Everything else is escaped text, so the owner's
/// words can never inject markup; a link that isn't http(s)/mailto stays text.
String markdownLiteHtml(dynamic md) {
  final links = <String>[];
  // Links first (escaped separately), parked behind a placeholder.
  final parked = _s(md).replaceAllMapped(_mdLink, (m) {
    final href = safeLink(m.group(2));
    if (href.isEmpty) return m.group(0)!;
    links.add(
        '<a href="${escHtml(href)}" target="_blank" rel="noopener noreferrer">${escHtml(m.group(1))}<span class="cb-sr-only"> ${t('common.opensNewTab')}</span></a>');
    return '\u0000${links.length - 1}\u0000';
  });
  return escHtml(parked)
      .replaceAllMapped(RegExp(r'\*\*([^*\n]+)\*\*'), (m) => '<strong>${m.group(1)}</strong>')
      .replaceAllMapped(RegExp(r'(^|[\s(])\*([^*\n]+)\*(?=[\s).,!?:;]|$)'), (m) => '${m.group(1)}<em>${m.group(2)}</em>')
      .replaceAllMapped(RegExp(r'(^|[\s(])_([^_\n]+)_(?=[\s).,!?:;]|$)'), (m) => '${m.group(1)}<em>${m.group(2)}</em>')
      .replaceAll(RegExp(r'\r?\n'), '<br>')
      .replaceAllMapped(RegExp('\u0000(\\d+)\u0000'), (m) {
    final i = int.parse(m.group(1)!);
    return i < links.length ? links[i] : '';
  });
}

/// The text as plain words: "I agree to the Terms and Privacy Policy".
String markdownLitePlain(dynamic md) => _s(md)
    .replaceAllMapped(_mdLink, (m) => m.group(1)!)
    .replaceAllMapped(RegExp(r'\*\*([^*\n]+)\*\*'), (m) => m.group(1)!)
    .replaceAllMapped(RegExp(r'(^|[\s(])[*_]([^*_\n]+)[*_](?=[\s).,!?:;]|$)'), (m) => '${m.group(1)}${m.group(2)}')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The documents a consent text links to: ["Terms", "Privacy Policy"].
List<String> consentDocuments(dynamic md) {
  final out = <String>[];
  for (final m in _mdLink.allMatches(_s(md))) {
    final text = m.group(1)!.trim();
    if (text.isNotEmpty && safeLink(m.group(2)).isNotEmpty && !out.contains(text)) out.add(text);
  }
  return out;
}

/// "Terms and Privacy Policy", "A, B and C".
String joinAnd(List<String> items) => items.length <= 1
    ? items.join('')
    : '${items.sublist(0, items.length - 1).join(', ')} ${t('common.and')} ${items.last}';

/// What the visitor's reply says: "Agreed to Terms and Privacy Policy" / "Didn't agree".
String consentReply(dynamic md, bool agreed) {
  if (!agreed) return t('consent.declined');
  final docs = consentDocuments(md);
  return docs.isNotEmpty ? t('consent.agreedTo', {'docs': joinAnd(docs)}) : t('consent.agreed');
}

String consentContinueLabel(dynamic data) {
  final s = _s(_f(data, 'continueLabel')).trim();
  return s.isNotEmpty ? s : t('common.continue');
}

/// Required unless the owner made it optional.
bool consentRequired(dynamic data) => _f(data, 'required') != false;

// ---------------------------------------------------------------------------
// (4) Product card - one carousel card with a price
// ---------------------------------------------------------------------------

const String productCardId = 'product';

/// The product as carousel data, so the carousel's renderer draws it.
Map<String, dynamic> productCarouselData(dynamic data) {
  final buttons = _f(data, 'buttons');
  return {
    'cards': [
      {
        'id': productCardId,
        'image': _f(data, 'image') ?? '',
        'title': _f(data, 'title') ?? '',
        'description': _f(data, 'description') ?? '',
        'price': _f(data, 'price') ?? '',
        'buttons': buttons is List ? buttons.take(3).toList() : <dynamic>[],
      },
    ],
  };
}

/// A product card's text for the transcript: "Pro plan · $49/mo".
String productSummary(dynamic data) =>
    [_s(_f(data, 'title')).trim(), _s(_f(data, 'price')).trim()].where((x) => x.isNotEmpty).join(' · ');

// ---------------------------------------------------------------------------
// (5a) Slider
// ---------------------------------------------------------------------------

num _numOr(dynamic v, num d) {
  if (v == '' || v == null) return d;
  final n = jsNumber(v);
  return n.isFinite ? jsNum(n) : d;
}

class SliderConfig {
  final num min;
  final num max;
  final num step;
  final num start;
  final String unit;

  /// "prefix" or "suffix".
  final String unitPosition;

  const SliderConfig({
    required this.min,
    required this.max,
    required this.step,
    required this.start,
    required this.unit,
    required this.unitPosition,
  });

  Map<String, dynamic> toJson() =>
      {'min': min, 'max': max, 'step': step, 'start': start, 'unit': unit, 'unitPosition': unitPosition};
}

int _decimalsOf(num n) {
  final s = jsNumberText(n);
  return s.contains('.') ? s.split('.')[1].length : 0;
}

/// Onto the step grid (counted from min), inside the range.
num snapToStep(num value, {required num min, required num max, required num step}) {
  final steps = _jsRound((value - min) / step);
  final v = math.min(max, math.max(min, min + steps * step));
  return jsNum(double.parse(v.toDouble().toStringAsFixed(math.max(_decimalsOf(step), _decimalsOf(min)))));
}

/// JavaScript Math.round (halves go up).
double _jsRound(num x) => (x + 0.5).floorToDouble();

/// The slider's settings, made safe (max above min, a step that fits, a start on the grid).
SliderConfig sliderConfig(dynamic data) {
  final min = _numOr(_f(data, 'min'), 0);
  var max = _numOr(_f(data, 'max'), 100);
  if (max <= min) max = min + 1;
  var step = _numOr(_f(data, 'step'), 1);
  if (!(step > 0) || step > max - min) {
    final s = math.min(1, max - min);
    step = s == 0 ? 1 : s;
  }
  final wanted = _numOr(_f(data, 'defaultValue'), jsNum((min + max) / 2));
  final position = _f(data, 'unitPosition') == 'prefix' ? 'prefix' : 'suffix';
  return SliderConfig(
    min: min,
    max: max,
    step: step,
    start: snapToStep(wanted, min: min, max: max, step: step),
    unit: _s(_f(data, 'unit')).trim(),
    unitPosition: position,
  );
}

/// "50 kg", "$50".
String sliderLabel(dynamic value, {required String unit, required String unitPosition}) {
  if (unit.isEmpty) return jsString(value);
  return unitPosition == 'prefix' ? '$unit${jsString(value)}' : '${jsString(value)} $unit';
}

String submitLabel(dynamic data) {
  final s = _s(_f(data, 'submitLabel')).trim();
  return s.isNotEmpty ? s : t('common.send');
}

// ---------------------------------------------------------------------------
// (5b) Date / time picker
//
// The web reads "today" and weekdays on the visitor's local clock (Date
// getters). Here a DateTime's own fields are read (pass a UTC "today" for the
// UTC clock, or one already shifted to the visitor's zone), and calendar math
// runs in UTC so the device zone never shifts a day.
// ---------------------------------------------------------------------------

/// "date", "time" or "datetime".
String dateMode(dynamic data) {
  final m = _f(data, 'mode');
  return m == 'time' || m == 'datetime' ? m as String : 'date';
}

String _pad2(int n) => n.toString().padLeft(2, '0');

/// "YYYY-MM-DD" of a DateTime's own fields.
String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}-${_pad2(d.day)}';

final RegExp _dateRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _timeRe = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
const List<String> weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/// A weekday's name in the visitor's language (0 = Sunday).
String weekdayName(int wd) => I18n.weekdayNames('long', weekdays)[wd];

/// "Saturdays" in English; the plain day name elsewhere ("zaterdag").
String _weekdaysName(int wd) => I18n.language == I18n.en ? '${weekdays[wd]}s' : weekdayName(wd);

bool validYmd(dynamic s) {
  final m = _dateRe.firstMatch(_s(s));
  if (m == null) return false;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final dt = DateTime.utc(y, mo, d);
  return dt.year == y && dt.month == mo && dt.day == d;
}

/// A bound as a date: "2026-10-05", "today", "+7" / "-3" (days from today).
String? resolveDateBound(dynamic bound, [DateTime? today]) {
  final now = today ?? DateTime.now();
  final b = _s(bound).trim().toLowerCase();
  if (b.isEmpty) return null;
  if (b == 'today') return ymd(now);
  final rel = RegExp(r'^([+-])(\d{1,4})$').firstMatch(b);
  if (rel != null) {
    final n = (rel.group(1) == '-' ? -1 : 1) * int.parse(rel.group(2)!);
    return ymd(DateTime.utc(now.year, now.month, now.day + n));
  }
  return validYmd(b) ? b : null;
}

List<int> disabledWeekdaysOf(dynamic data) {
  final list = _f(data, 'disabledWeekdays');
  return (list is List ? list : const [])
      .map((v) => jsNumber(v))
      .where((n) => n.isFinite && n == n.truncateToDouble() && n >= 0 && n <= 6)
      .map((n) => n.toInt())
      .toList();
}

/// Why an ISO value isn't allowed, or null. Same rules as the channels'.
String? dateTimeError(dynamic data, dynamic iso, [DateTime? today]) {
  final mode = dateMode(data);
  final s = _s(iso);
  String datePart;
  String timePart;
  if (mode == 'datetime') {
    final parts = s.split('T');
    datePart = parts[0];
    timePart = parts.length > 1 ? parts[1] : '';
  } else if (mode == 'time') {
    datePart = '';
    timePart = s;
  } else {
    datePart = s;
    timePart = '';
  }
  if (mode != 'time') {
    if (!validYmd(datePart)) return t('dates.pickDate');
    final min = resolveDateBound(_f(data, 'minDate'), today);
    final max = resolveDateBound(_f(data, 'maxDate'), today);
    if (min != null && datePart.compareTo(min) < 0) return t('dates.onOrAfter', {'date': min});
    if (max != null && datePart.compareTo(max) > 0) return t('dates.onOrBefore', {'date': max});
    final p = datePart.split('-').map(int.parse).toList();
    final wd = DateTime.utc(p[0], p[1], p[2]).weekday % 7;
    if (disabledWeekdaysOf(data).contains(wd)) return t('dates.dayUnavailable', {'day': _weekdaysName(wd)});
  }
  if (mode != 'date') {
    if (!_timeRe.hasMatch(timePart)) return t('dates.pickTime');
    final minTime = _f(data, 'minTime');
    final maxTime = _f(data, 'maxTime');
    if (minTime is String && minTime.isNotEmpty && _timeRe.hasMatch(minTime) && timePart.compareTo(minTime) < 0) {
      return t('dates.timeFrom', {'time': minTime});
    }
    if (maxTime is String && maxTime.isNotEmpty && _timeRe.hasMatch(maxTime) && timePart.compareTo(maxTime) > 0) {
      return t('dates.timeUntil', {'time': maxTime});
    }
  }
  return null;
}

/// A browser input's value as our ISO ("2026-10-05T14:30:00" -> "2026-10-05T14:30").
String isoFromInput(String mode, dynamic value) {
  final v = _s(value).trim();
  if (mode == 'time') return _slice(v, 0, 5);
  if (mode == 'datetime') return _slice(v, 0, 16);
  return _slice(v, 0, 10);
}

const List<String> _monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// en-US `timeStyle: "short"`: "2:30 PM".
String _shortTime(int h, int m) {
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '$hh:${_pad2(m)} ${h < 12 ? 'AM' : 'PM'}';
}

/// The picked value for people. The web formats it in the node's locale (or
/// the visitor's own); this port always writes en-US ("Oct 19, 2026",
/// "2:30 PM", "Oct 19, 2026, 2:30 PM").
String dateTimeDisplay(dynamic data, dynamic iso, [String? fallbackLocale]) {
  final mode = dateMode(data);
  final text = _s(iso);
  int? num0(String x) => int.tryParse(x.trim());
  if (mode == 'time') {
    final p = text.split(':');
    final h = num0(p[0]);
    final m = p.length > 1 ? num0(p[1]) : null;
    if (h == null || m == null) return text;
    final d = DateTime.utc(2000, 1, 1, h, m);
    return _shortTime(d.hour, d.minute);
  }
  final halves = text.split('T');
  final dp = halves[0].split('-');
  final tp = (halves.length > 1 ? halves[1] : '00:00').split(':');
  if (dp.length < 3 || tp.length < 2) return text;
  final y = num0(dp[0]), mo = num0(dp[1]), d = num0(dp[2]), h = num0(tp[0]), mi = num0(tp[1]);
  if (y == null || mo == null || d == null || h == null || mi == null) return text;
  final at = DateTime.utc(y, mo, d, h, mi);
  final date = '${_monthsShort[at.month - 1]} ${at.day}, ${at.year}';
  return mode == 'date' ? date : '$date, ${_shortTime(at.hour, at.minute)}';
}

/// The attributes the browser's own picker takes: min / max / step.
Map<String, String> dateInputAttrs(dynamic data, [DateTime? today]) {
  final mode = dateMode(data);
  final minD = resolveDateBound(_f(data, 'minDate'), today);
  final maxD = resolveDateBound(_f(data, 'maxDate'), today);
  final rawMinT = _f(data, 'minTime');
  final rawMaxT = _f(data, 'maxTime');
  final minT = _timeRe.hasMatch(jsTruthy(rawMinT) ? jsString(rawMinT) : '') ? jsString(rawMinT) : '';
  final maxT = _timeRe.hasMatch(jsTruthy(rawMaxT) ? jsString(rawMaxT) : '') ? jsString(rawMaxT) : '';
  final stepMin = math.min(720, math.max(1, _numOr(_f(data, 'timeStep'), 30).floor()));
  if (mode == 'date') return {'type': 'date', 'min': minD ?? '', 'max': maxD ?? '', 'step': ''};
  if (mode == 'time') return {'type': 'time', 'min': minT, 'max': maxT, 'step': '${stepMin * 60}'};
  return {
    'type': 'datetime-local',
    'min': minD != null ? '${minD}T${minT.isNotEmpty ? minT : '00:00'}' : '',
    'max': maxD != null ? '${maxD}T${maxT.isNotEmpty ? maxT : '23:59'}' : '',
    'step': '${stepMin * 60}',
  };
}

/// "Closed on Saturdays and Sundays" - said up front, under the picker.
String closedDaysNote(dynamic data) {
  // JS sort() compares as text; single digits sort the same.
  final days = disabledWeekdaysOf(data)..sort((a, b) => '$a'.compareTo('$b'));
  if (days.isEmpty || dateMode(data) == 'time') return '';
  return t('dates.closedOn', {'days': joinAnd(days.map(_weekdaysName).toList())});
}

// ---------------------------------------------------------------------------
// (6) Ranking
// ---------------------------------------------------------------------------

const int rankingMax = 10;

class RankItem {
  final String id;
  final String text;
  const RankItem({required this.id, required this.text});

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

/// The items to rank, in their starting order (at most ten, each with text).
List<RankItem> rankingItems(dynamic data) {
  final items = _f(data, 'items');
  final list = items is List ? items : const [];
  final out = <RankItem>[];
  for (var i = 0; i < list.length; i++) {
    final it = list[i];
    final id = _f(it, 'id');
    out.add(RankItem(id: id == null ? '$i' : jsString(id), text: plainText(_f(it, 'text'))));
  }
  return out.where((it) => it.text.isNotEmpty).take(rankingMax).toList();
}

/// Move one item (by drag, arrow key or the move buttons); out-of-range is a no-op.
List<T> moveItem<T>(List<T> list, int from, int to) {
  if (from == to || from < 0 || to < 0 || from >= list.length || to >= list.length) return list;
  final next = List<T>.of(list);
  final item = next.removeAt(from);
  next.insert(to, item);
  return next;
}

/// "1. Price · 2. Speed · 3. Support" - the visitor's reply.
String rankingText(List<RankItem> order) {
  final parts = <String>[];
  for (var i = 0; i < order.length; i++) {
    parts.add('${i + 1}. ${order[i].text}');
  }
  return parts.join(' · ');
}

/// What a screen reader hears after a move.
String rankingAnnouncement(RankItem item, int index, int total) =>
    t('ranking.moved', {'item': item.text, 'n': index + 1, 'total': total});

/// A landing page's query worth remembering (it has parameters at all).
String landingSearchToKeep(dynamic search) =>
    search is String && search.length > 1 && search.startsWith('?') ? _slice(search, 0, 2000) : '';

// ---------------------------------------------------------------------------
// (7) Verification code (OTP) - the code is made and checked on the server
// (embed-server services/chatbot/otpService.js); these are the UI rules.
// ---------------------------------------------------------------------------

const int otpLength = 6;
const int otpResendSeconds = 30;

/// The code the builder's preview accepts (no email is sent there).
const String otpPreviewCode = '123456';

final RegExp _emailRe = RegExp(r'^[^\s@<>()[\],;:"]+@[^\s@<>()[\],;:"]+\.[^\s@<>()[\],;:"]{2,}$');

bool isEmailAddress(dynamic v) => v is String && v.length <= 254 && _emailRe.hasMatch(v.trim());

/// "p***@acme.io"
String maskEmail(dynamic email) {
  final e = _s(email).trim().toLowerCase();
  final at = e.lastIndexOf('@');
  return at < 1 ? '***' : '${e[0]}***${e.substring(at)}';
}

/// The digits of a pasted / typed code, at most six ("123 456" -> "123456").
String digitsFromPaste(dynamic text, [int length = otpLength]) {
  final s = _s(text)
      .replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m.group(0)!.codeUnitAt(0) - 0x0660}')
      .replaceAllMapped(RegExp('[۰-۹]'), (m) => '${m.group(0)!.codeUnitAt(0) - 0x06f0}')
      .replaceAll(RegExp(r'\D'), '');
  return _slice(s, 0, length);
}

class FilledDigits {
  final List<String> boxes;
  final int next;
  const FilledDigits(this.boxes, this.next);
}

/// Put `text`'s digits into the boxes from `start`; returns the boxes and where focus goes next.
FilledDigits fillDigits(List<String> boxes, int start, dynamic text) {
  final digits = digitsFromPaste(text, boxes.length);
  final out = List<String>.of(boxes);
  final from = digits.length >= boxes.length ? 0 : math.max(0, math.min(start, boxes.length - 1));
  var i = from;
  for (final d in digits.split('')) {
    if (i >= out.length) break;
    out[i++] = d;
  }
  return FilledDigits(out, math.min(i, out.length - 1));
}

/// "Resend in 0:27" / "Resend code"
String resendLabel(num seconds) {
  final n = jsNumber(seconds);
  final s = math.max(0, (n.isNaN ? 0 : n).ceil());
  return s > 0 ? t('otp.resendIn', {'time': '${s ~/ 60}:${_pad2(s % 60)}'}) : t('otp.resend');
}

/// "email" or "sms".
String otpChannel(dynamic data) => _f(data, 'channel') == 'sms' ? 'sms' : 'email';

/// The address to verify without asking, when the step takes it from a variable.
String otpPresetEmail(dynamic data, dynamic Function(String key) lookup) {
  if (_f(data, 'emailSource') != 'variable') return '';
  final key = _s(_f(data, 'emailVariable')).trim();
  final v = key.isNotEmpty ? _s(lookup(key)).trim() : '';
  return isEmailAddress(v) ? v.toLowerCase() : '';
}

/// What to tell the visitor for a server answer (send or verify).
/// `extra` keys: attemptsLeft, retryAfter.
String otpErrorText(dynamic code, [Map<String, dynamic> extra = const {}]) {
  switch (code) {
    case 'invalid_email':
      return t('otp.invalidEmail');
    case 'wrong_code':
      final n = _numField(extra, 'attemptsLeft');
      return n.isFinite ? t(n == 1 ? 'otp.wrongLeft.one' : 'otp.wrongLeft.other', {'n': jsNum(n)}) : t('otp.wrong');
    case 'invalid_code':
      return t('otp.allDigits', {'n': otpLength});
    case 'expired':
      return t('otp.expired');
    case 'no_code':
      return t('otp.noCode');
    case 'locked':
      return t('otp.locked');
    case 'resend_wait':
      final r = _numField(extra, 'retryAfter');
      final wait = (r.isNaN || r == 0) ? otpResendSeconds : r;
      return t('otp.resendWait', {'n': jsNum(math.max(1, wait).toDouble())});
    case 'too_many_sends':
    case 'rate_limited':
      return t('otp.tooMany');
    case 'sms_unavailable':
      return t('otp.smsUnavailable');
    default:
      return t('common.somethingWrong');
  }
}

/// Failures that end the step on its "not verified" path.
bool otpEndsStep(dynamic code) => const ['locked', 'sms_unavailable', 'node_not_found', 'send_failed'].contains(_s(code));

/// The visitor's reply bubble for a finished step.
String otpReplyText(bool verified, [String? email]) =>
    verified ? t('otp.verifiedAs', {'email': email ?? ''}) : t('otp.notVerified');

// ---------------------------------------------------------------------------
// (8) Address - search (server-proxied geocoder), my location, manual entry
// ---------------------------------------------------------------------------

const int addressDebounceMs = 300;
const int addressMinChars = 3;

class AddressValue {
  String formatted;
  String line1;
  String city;
  String region;
  String postal;
  String country;
  String countryCode;
  num? lat;
  num? lng;

  AddressValue({
    this.formatted = '',
    this.line1 = '',
    this.city = '',
    this.region = '',
    this.postal = '',
    this.country = '',
    this.countryCode = '',
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson() => {
        'formatted': formatted,
        'line1': line1,
        'city': city,
        'region': region,
        'postal': postal,
        'country': country,
        'countryCode': countryCode,
        'lat': lat,
        'lng': lng,
      };
}

dynamic _addrField(dynamic v, String key) => v is AddressValue ? v.toJson()[key] : _f(v, key);

String _clip200(dynamic v) => _slice(_s(v).replaceAll(RegExp(r'\s+'), ' ').trim(), 0, 200);

num? _finiteOrNull(dynamic v) {
  if (v == null || v == '') return null;
  final n = jsNumber(v);
  return n.isFinite ? jsNum(n) : null;
}

/// "12 Al Marsa St, Dubai, Dubai 00000, United Arab Emirates" from the parts
/// (a map or an [AddressValue]).
String formatAddress(dynamic v) {
  final city = _clip200(_addrField(v, 'city'));
  final region = _clip200(_addrField(v, 'region'));
  final postal = _clip200(_addrField(v, 'postal'));
  final regionPostal = [region != city ? region : '', postal].where((x) => x.isNotEmpty).join(' ');
  final cityLine = [city, regionPostal].where((x) => x.isNotEmpty).join(', ');
  return [_clip200(_addrField(v, 'line1')), cityLine, _clip200(_addrField(v, 'country'))].where((x) => x.isNotEmpty).join(', ');
}

/// Any address the server or the visitor gave, cleaned into one shape.
AddressValue normalizeAddress(dynamic v) {
  final cc = _s(_addrField(v, 'countryCode')).trim();
  final out = AddressValue(
    formatted: _clip200(_addrField(v, 'formatted')),
    line1: _clip200(_addrField(v, 'line1')),
    city: _clip200(_addrField(v, 'city')),
    region: _clip200(_addrField(v, 'region')),
    postal: _clip200(_addrField(v, 'postal')),
    country: _clip200(_addrField(v, 'country')),
    countryCode: RegExp(r'^[a-z]{2}$', caseSensitive: false).hasMatch(cc) ? cc.toLowerCase() : '',
    lat: _finiteOrNull(_addrField(v, 'lat')),
    lng: _finiteOrNull(_addrField(v, 'lng')),
  );
  if (out.lat == null || out.lng == null || out.lat!.abs() > 90 || out.lng!.abs() > 180) {
    out.lat = null;
    out.lng = null;
  }
  if (out.formatted.isEmpty) out.formatted = formatAddress(out);
  return out;
}

/// The visitor's own entry (Street, City, Region, Postal code, Country); null when not enough.
/// `fields` keys: line1, city, region, postal, country.
AddressValue? manualAddress(Map<String, dynamic> fields) {
  final v = normalizeAddress({...fields, 'formatted': '', 'countryCode': '', 'lat': null, 'lng': null});
  if (v.line1.isEmpty) return null;
  v.formatted = formatAddress(v);
  return v;
}

const List<List<String>> _addressSuffixes = [
  ['line1', 'line1'],
  ['city', 'city'],
  ['region', 'region'],
  ['postal', 'postal'],
  ['country', 'country'],
  ['countryCode', 'country_code'],
  ['lat', 'lat'],
  ['lng', 'lng'],
];

/// The variables an address saves: { k: formatted, k_line1, k_city, ... } (empty parts left out).
Map<String, dynamic> addressVariables(dynamic key, AddressValue value) {
  final k = _s(key).trim();
  final out = <String, dynamic>{};
  if (k.isEmpty) return out;
  out[k] = value.formatted;
  final json = value.toJson();
  for (final pair in _addressSuffixes) {
    final v = json[pair[0]];
    if (v == null || v == '') continue;
    out['${k}_${pair[1]}'] = v;
  }
  return out;
}

/// The OpenStreetMap tile holding a point, and where the point sits in it
/// (Web Mercator, 256px tiles): to draw a small static map with a pin.
/// Keys: z, x, y, url, offsetX, offsetY.
Map<String, dynamic> osmTile(num lat, num lng, [num zoom = 16]) {
  final z = math.max(0, math.min(19, zoom.floor()));
  final n = math.pow(2, z).toInt();
  final la = math.max(-85.0511, math.min(85.0511, lat.toDouble()));
  final x = ((lng + 180) / 360) * n;
  final rad = (la * math.pi) / 180;
  final y = ((1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2) * n;
  final tx = math.min(n - 1, math.max(0, x.floor()));
  final ty = math.min(n - 1, math.max(0, y.floor()));
  return {
    'z': z,
    'x': tx,
    'y': ty,
    'url': 'https://tile.openstreetmap.org/$z/$tx/$ty.png',
    'offsetX': _jsRound((x - tx) * 256).toInt(),
    'offsetY': _jsRound((y - ty) * 256).toInt(),
  };
}

/// A map tile through our server (embed-server /api/v1/geo/tile): OSM blocks
/// tiles hot-linked from customer sites, and asks heavy users to cache.
String tileSrc(String backend, int z, int x, int y) => '${backend.replaceAll(RegExp(r'\/+$'), '')}/api/v1/geo/tile/$z/$x/$y.png';

/// "View on the map" link for a point.
String osmLink(num lat, num lng) {
  final a = lat.toStringAsFixed(6);
  final b = lng.toStringAsFixed(6);
  return 'https://www.openstreetmap.org/?mlat=$a&mlon=$b#map=17/$a/$b';
}

/// The builder preview's stand-in results (no network there).
List<AddressValue> get addressPreviewSamples => [
      AddressValue(formatted: 'Marina Walk, Dubai Marina, Dubai, United Arab Emirates', line1: 'Marina Walk', city: 'Dubai', region: 'Dubai', postal: '', country: 'United Arab Emirates', countryCode: 'ae', lat: 25.0805, lng: 55.1403),
      AddressValue(formatted: '1 Sheikh Mohammed bin Rashid Blvd, Downtown Dubai, Dubai, United Arab Emirates', line1: '1 Sheikh Mohammed bin Rashid Blvd', city: 'Dubai', region: 'Dubai', postal: '', country: 'United Arab Emirates', countryCode: 'ae', lat: 25.1972, lng: 55.2744),
      AddressValue(formatted: '221B Baker Street, London, NW1 6XE, United Kingdom', line1: '221B Baker Street', city: 'London', region: 'England', postal: 'NW1 6XE', country: 'United Kingdom', countryCode: 'gb', lat: 51.5238, lng: -0.1586),
      AddressValue(formatted: '350 5th Avenue, New York, NY 10118, United States', line1: '350 5th Avenue', city: 'New York', region: 'New York', postal: '10118', country: 'United States', countryCode: 'us', lat: 40.7484, lng: -73.9857),
    ];

/// Preview search: the samples matching any word of the query (all of them when none match).
List<AddressValue> previewAddressResults(dynamic q) {
  final words = _s(q).toLowerCase().split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
  final samples = addressPreviewSamples;
  final hits = samples.where((a) => words.any((w) => a.formatted.toLowerCase().contains(w))).toList();
  return hits.isNotEmpty ? hits : samples;
}

/// What to tell the visitor when a lookup fails.
String addressErrorText(dynamic code) {
  switch (code) {
    case 'denied':
      return t('address.denied');
    case 'unavailable':
      return t('address.unavailable');
    case 'busy':
    case 'rate_limited':
      return t('address.busy');
    case 'no_results':
      return t('address.noResults');
    default:
      return t('address.failed');
  }
}

// ---------------------------------------------------------------------------
// (9) Matrix / Likert grid
// ---------------------------------------------------------------------------

const int matrixMaxRows = 12;
const int matrixMaxColumns = 7;

class MatrixItem {
  final String id;
  final String text;
  const MatrixItem({required this.id, required this.text});

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

/// What the visitor ticked: row id -> column ids (one for single).
typedef MatrixSelection = Map<String, List<String>>;

List<MatrixItem> _matrixItems(dynamic list, int max, String prefix) {
  final seen = <String>{};
  final out = <MatrixItem>[];
  final items = list is List ? list : const [];
  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    final text = plainText(_f(it, 'text'));
    if (text.isEmpty || out.length >= max) continue;
    final rawId = _f(it, 'id');
    var id = rawId == null ? '$prefix$i' : jsString(rawId);
    if (seen.contains(id)) id = '${id}_$i';
    seen.add(id);
    out.add(MatrixItem(id: id, text: text));
  }
  return out;
}

/// The statements (rows), cleaned: text only, at most twelve.
List<MatrixItem> matrixRows(dynamic data) => _matrixItems(_f(data, 'rows'), matrixMaxRows, 'r');

/// The scale (columns), cleaned: text only, at most seven.
List<MatrixItem> matrixColumns(dynamic data) => _matrixItems(_f(data, 'columns'), matrixMaxColumns, 'c');

/// "single" or "multiple".
String matrixMode(dynamic data) => _f(data, 'mode') == 'multiple' ? 'multiple' : 'single';
bool matrixRequireAll(dynamic data) => _f(data, 'requireAll') != false;

/// Tick / untick one cell. Single mode keeps one column per row.
MatrixSelection matrixToggle(MatrixSelection sel, String rowId, String colId, String mode, [bool on = true]) {
  final cur = sel[rowId] ?? const <String>[];
  List<String> next;
  if (mode == 'single') {
    next = on ? [colId] : cur.where((c) => c != colId).toList();
  } else {
    next = on ? (cur.contains(colId) ? List.of(cur) : [...cur, colId]) : cur.where((c) => c != colId).toList();
  }
  final out = Map<String, List<String>>.of(sel);
  if (next.isNotEmpty) {
    out[rowId] = next;
  } else {
    out.remove(rowId);
  }
  return out;
}

/// The rows still without an answer.
List<MatrixItem> matrixMissing(MatrixSelection sel, List<MatrixItem> rows) =>
    rows.where((r) => !((sel[r.id] ?? const []).isNotEmpty)).toList();

List<String> _picked(MatrixSelection sel, MatrixItem r, List<MatrixItem> cols) =>
    cols.where((c) => (sel[r.id] ?? const []).contains(c.id)).map((c) => c.text).toList();

/// The saved value: { row: column } or { row: [columns] } (columns in scale order); unanswered rows left out.
Map<String, dynamic> matrixValue(MatrixSelection sel, List<MatrixItem> rows, List<MatrixItem> cols, String mode) {
  final out = <String, dynamic>{};
  for (final r in rows) {
    final picked = _picked(sel, r, cols);
    if (picked.isEmpty) continue;
    out[r.text] = mode == 'single' ? picked[0] : picked;
  }
  return out;
}

/// Per row, for the record: { id, text, answer }.
List<Map<String, dynamic>> matrixRowAnswers(MatrixSelection sel, List<MatrixItem> rows, List<MatrixItem> cols, String mode) =>
    rows.map((r) {
      final picked = _picked(sel, r, cols);
      return <String, dynamic>{
        'id': r.id,
        'text': r.text,
        'answer': picked.isNotEmpty ? (mode == 'single' ? picked[0] : picked) : null,
      };
    }).toList();

/// "Speed: Good · Price: Fair, Poor" - the visitor's reply.
String matrixDisplay(Map<String, dynamic>? value) =>
    (value ?? const {}).entries.map((e) => '${e.key}: ${e.value is List ? (e.value as List).join(', ') : e.value}').join(' · ');

/// "2 of 4 answered".
String matrixProgress(MatrixSelection sel, List<MatrixItem> rows) =>
    t('matrix.progress', {'n': rows.length - matrixMissing(sel, rows).length, 'total': rows.length});

/// What blocks Submit, or "".
String matrixError(MatrixSelection sel, List<MatrixItem> rows, bool requireAll) {
  final missing = matrixMissing(sel, rows);
  if (requireAll && missing.isNotEmpty) return t('matrix.everyRow', {'n': missing.length});
  if (missing.length == rows.length) return t('matrix.oneRow');
  return '';
}

// ---------------------------------------------------------------------------
// (10) AI extract / AI intent router - the server runs the AI with the
// owner's key (embed-server aiNodeService.js); these are the widget's rules.
// ---------------------------------------------------------------------------

const List<String> aiNodeTypes = ['ai-extract-node', 'ai-route-node'];
bool isAiNode(dynamic type) => aiNodeTypes.contains(type);

/// Least time the "thinking" dots show, so a fast answer doesn't flicker.
const int aiMinThinkMs = 500;

/// The widget gives up a little after the server's own 12 s timeout.
const int aiClientTimeoutMs = 15000;
const int aiMaxInput = 2000;

/// "ask", "last_message" or "variable".
String aiSourceOf(dynamic data) {
  final s = _f(data, 'source');
  return s == 'last_message' || s == 'variable' ? s as String : 'ask';
}

/// The text a step reads without asking: the visitor's latest message, or a
/// variable (objects as JSON). null = ask; "" = nothing there yet (ask too).
String? aiPresetText(dynamic data, dynamic lastUserText, dynamic variableValue) {
  final source = aiSourceOf(data);
  if (source == 'ask') return null;
  final v = source == 'variable' ? variableValue : lastUserText;
  if (v == null) return '';
  return _slice((v is Map || v is List ? jsonStringify(v) : jsString(v)).trim(), 0, aiMaxInput);
}

/// The visitor's latest message in the transcript ([{ by, message }]).
String lastUserMessage(dynamic transcript) {
  final list = transcript is List ? transcript : const [];
  for (var i = list.length - 1; i >= 0; i--) {
    final e = list[i];
    final msg = _f(e, 'message');
    if (_f(e, 'by') == 'user' && msg is String && plainText(msg).isNotEmpty) return plainText(msg);
  }
  return '';
}

class AiExtractResult {
  final Map<String, dynamic> values;
  final List<String> missing;
  final bool ok;
  final String? error;
  const AiExtractResult({required this.values, required this.missing, required this.ok, this.error});

  Map<String, dynamic> toJson() => {'values': values, 'missing': missing, 'ok': ok, if (error != null) 'error': error};
}

class AiRouteResult {
  final String? intentId;
  final String? intent;
  final num confidence;
  final bool fallback;
  final String? error;
  const AiRouteResult({this.intentId, this.intent, required this.confidence, required this.fallback, this.error});

  Map<String, dynamic> toJson() => {
        'intentId': intentId,
        'intent': intent,
        'confidence': confidence,
        'fallback': fallback,
        if (error != null) 'error': error,
      };
}

final RegExp _aiVarRe = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
const List<String> _aiFieldTypes = ['text', 'number', 'email', 'phone', 'date', 'boolean', 'list'];

/// The fields to extract: [{name, type, description, required}] (valid, unique names, at most 15).
List<Map<String, dynamic>> aiFieldsOf(dynamic data) {
  final fields = _f(data, 'fields');
  final mapped = (fields is List ? fields : const [])
      .map((f) => <String, dynamic>{
            'name': _s(_f(f, 'name')).trim(),
            'type': _aiFieldTypes.contains(_f(f, 'type')) ? _f(f, 'type') : 'text',
            'description': plainText(_f(f, 'description')),
            'required': _f(f, 'required') == true,
          })
      .toList();
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < mapped.length; i++) {
    final f = mapped[i];
    if (_aiVarRe.hasMatch(f['name'] as String) && mapped.indexWhere((g) => g['name'] == f['name']) == i) out.add(f);
  }
  return out.take(15).toList();
}

/// The intents to route between: [{id, name, description}] (named, at most 10).
List<Map<String, dynamic>> aiIntentsOf(dynamic data) {
  final intents = _f(data, 'intents');
  final list = intents is List ? intents : const [];
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < list.length; i++) {
    final it = list[i];
    final id = _f(it, 'id');
    out.add({
      'id': id == null ? '$i' : jsString(id),
      'name': _slice(plainText(_f(it, 'name')), 0, 40),
      'description': plainText(_f(it, 'description')),
    });
  }
  return out.where((it) => (it['name'] as String).isNotEmpty).take(10).toList();
}

/// What a server reply (or a failed request) means: always a path to follow.
AiExtractResult aiExtractResultOf(dynamic data, dynamic json, [String? failed]) {
  final required = aiFieldsOf(data).where((f) => f['required'] == true).map((f) => f['name'] as String).toList();
  if ((failed != null && failed.isNotEmpty) || json == null || !(json is Map || json is List)) {
    return AiExtractResult(values: {}, missing: required, ok: false, error: (failed != null && failed.isNotEmpty) ? failed : 'bad_reply');
  }
  final rawValues = _f(json, 'values');
  final values = rawValues is Map ? Map<String, dynamic>.from(rawValues) : <String, dynamic>{};
  final rawMissing = _f(json, 'missing');
  final missing = rawMissing is List ? rawMissing.map((m) => jsString(m)).toList() : required.where((n) => !values.containsKey(n)).toList();
  final error = _f(json, 'error');
  return AiExtractResult(
    values: values,
    missing: missing,
    ok: _f(json, 'ok') == true && missing.isEmpty,
    error: jsTruthy(error) ? jsString(error) : null,
  );
}

AiRouteResult aiRouteResultOf(dynamic json, [String? failed]) {
  final conf = jsNumber(_f(json, 'confidence') ?? double.nan);
  final confidence = (conf.isNaN || conf == 0) ? 0 : jsNum(conf);
  if ((failed != null && failed.isNotEmpty) || json == null || !(json is Map || json is List) || jsTruthy(_f(json, 'fallback')) || !jsTruthy(_f(json, 'intentId'))) {
    final err = (failed != null && failed.isNotEmpty) ? failed : (jsTruthy(_f(json, 'error')) ? jsString(_f(json, 'error')) : 'no_match');
    return AiRouteResult(intentId: null, intent: null, confidence: confidence, fallback: true, error: err);
  }
  return AiRouteResult(
    intentId: jsString(_f(json, 'intentId')),
    intent: _s(_f(json, 'intent')),
    confidence: confidence,
    fallback: false,
  );
}

/// The variables an extract saves: each field, the whole object, and what's missing.
Map<String, dynamic> aiExtractVariables(dynamic data, AiExtractResult r) {
  final out = <String, dynamic>{};
  final names = aiFieldsOf(data).map((f) => f['name']).toSet();
  r.values.forEach((k, v) {
    if (names.contains(k)) out[k] = v;
  });
  final key = _s(_f(data, 'answerVariable')).trim();
  if (key.isNotEmpty) {
    out[key] = Map<String, dynamic>.of(out);
    out['${key}_missing'] = r.missing;
  }
  return out;
}

/// The variables a route saves: the intent's name ("" on no match) and the confidence.
Map<String, dynamic> aiRouteVariables(dynamic data, AiRouteResult r) {
  final key = _s(_f(data, 'answerVariable')).trim();
  if (key.isEmpty) return {};
  return {
    key: r.fallback ? '' : (r.intent ?? ''),
    '${key}_confidence': jsNum(_jsRound(r.confidence * 100) / 100),
  };
}

// --- Builder preview: no server, a small local stand-in so it still branches.

final Map<String, RegExp> _previewPatterns = {
  'email': RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+'),
  'phone': RegExp(r'\+?\d[\d\s().-]{6,}\d'),
  'number': RegExp(r'-?\d+(?:\.\d+)?'),
  'date': RegExp(r'\d{4}-\d{2}-\d{2}'),
};

AiExtractResult previewExtract(dynamic data, String text) {
  final values = <String, dynamic>{};
  for (final f in aiFieldsOf(data)) {
    dynamic v;
    final type = f['type'];
    if (type == 'email' || type == 'phone' || type == 'date') {
      v = _previewPatterns[type]!.firstMatch(text)?.group(0);
    } else if (type == 'number') {
      final m = _previewPatterns['number']!.firstMatch(text);
      v = m != null ? jsNum(jsNumber(m.group(0))) : null;
    } else if (type == 'boolean') {
      v = RegExp(r'\b(yes|yeah|sure|ok)\b', caseSensitive: false).hasMatch(text)
          ? true
          : RegExp(r'\b(no|nope)\b', caseSensitive: false).hasMatch(text)
              ? false
              : null;
    } else if (RegExp('name', caseSensitive: false).hasMatch(f['name'] as String)) {
      v = RegExp(r"(?:i'm|i am|my name is|this is)\s+([A-Z][\w'-]+(?:\s[A-Z][\w'-]+)?)", caseSensitive: false).firstMatch(text)?.group(1);
    }
    if (v != null && v != '') values[f['name'] as String] = v is String ? v.trim() : v;
  }
  final missing = aiFieldsOf(data).where((f) => f['required'] == true && !values.containsKey(f['name'])).map((f) => f['name'] as String).toList();
  return AiExtractResult(values: values, missing: missing, ok: missing.isEmpty);
}

List<String> _words(String s) => s.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.length > 2).toList();

AiRouteResult previewRoute(dynamic data, String text) {
  final said = _words(text).toSet();
  Map<String, dynamic>? best;
  var bestScore = 0;
  for (final it in aiIntentsOf(data)) {
    final score = _words('${it['name']} ${it['description']}')
        .where((w) => said.contains(w) || said.any((s) => s.length > 3 && (w.startsWith(s) || s.startsWith(w))))
        .length;
    if (score > bestScore) {
      best = it;
      bestScore = score;
    }
  }
  final mc = _numField(data, 'minConfidence');
  final min = mc.isFinite ? mc : 0.5;
  final confidence = best != null ? math.min(0.95, 0.6 + 0.15 * bestScore) : 0.2;
  if (best == null || confidence < min) {
    return AiRouteResult(intentId: null, intent: null, confidence: confidence, fallback: true, error: 'no_match');
  }
  return AiRouteResult(intentId: best['id'] as String, intent: best['name'] as String, confidence: confidence, fallback: false);
}

// ---------------------------------------------------------------------------
// (11) Knowledge-base answer - the server retrieves from the bot's published
// knowledge and writes a grounded answer (embed-server kbAnswerService.js);
// these are the widget's rules for what comes back.
// ---------------------------------------------------------------------------

const String kbNodeType = 'kb-answer-node';
bool isKbNode(dynamic type) => type == kbNodeType;

/// Steps that read the visitor's reply from the normal composer.
bool isComposerRichNode(dynamic type) => isAiNode(type) || isKbNode(type);

/// A little after the server's own 15 s timeout.
const int kbClientTimeoutMs = 18000;
const int kbMaxAnswer = 700;
const String kbDefaultNotFound = "<p>I couldn't find that in our help articles.</p>";

class KbSource {
  final String title;
  final String url;
  final String? articleId;

  /// "article" or "page".
  final String type;
  const KbSource({required this.title, required this.url, this.articleId, required this.type});

  Map<String, dynamic> toJson() => {'title': title, 'url': url, if (articleId != null) 'articleId': articleId, 'type': type};
}

class KbResult {
  final bool found;
  final String answer;
  final List<KbSource> sources;
  final String? error;
  const KbResult({required this.found, required this.answer, required this.sources, this.error});

  Map<String, dynamic> toJson() =>
      {'found': found, 'answer': answer, 'sources': sources.map((s) => s.toJson()).toList(), if (error != null) 'error': error};
}

final RegExp _objectIdRe = RegExp(r'^[a-f0-9]{24}$', caseSensitive: false);

int kbMaxSources(dynamic data) {
  final n = _numField(data, 'maxSources').floorToDouble();
  return n.isFinite ? math.min(5, math.max(1, n.toInt())) : 3;
}

/// The server's reply, made safe: plain answer text, at most maxSources https / article sources.
KbResult kbResultOf(dynamic data, dynamic json, [String? errorCode]) {
  final answer = _slice(plainText(_f(json, 'answer')), 0, kbMaxAnswer + 1);
  if (json == null || _f(json, 'found') != true || answer.isEmpty) {
    final err = _f(json, 'error');
    return KbResult(
      found: false,
      answer: '',
      sources: const [],
      error: (errorCode != null && errorCode.isNotEmpty) ? errorCode : (err is String ? err : 'not_found'),
    );
  }
  final seen = <String>{};
  final sources = <KbSource>[];
  if (_f(data, 'showSources') != false) {
    final raw = _f(json, 'sources');
    for (final s in raw is List ? raw : const []) {
      if (sources.length >= kbMaxSources(data)) break;
      final rawUrl = _f(s, 'url');
      final urlText = jsTruthy(rawUrl) ? jsString(rawUrl) : '';
      final url = RegExp(r'^https?:\/\/', caseSensitive: false).hasMatch(urlText) ? urlText : '';
      final rawId = _f(s, 'articleId');
      final idText = jsTruthy(rawId) ? jsString(rawId) : '';
      final articleId = _objectIdRe.hasMatch(idText) ? idText : '';
      final key = articleId.isNotEmpty ? 'a:$articleId' : url;
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      final title = _slice(plainText(_f(s, 'title')), 0, 160);
      sources.add(KbSource(
        title: title.isNotEmpty ? title : (url.isNotEmpty ? url.replaceFirst(RegExp(r'^https?:\/\/', caseSensitive: false), '') : t('kb.helpArticle')),
        url: url,
        articleId: articleId.isNotEmpty ? articleId : null,
        type: articleId.isNotEmpty ? 'article' : 'page',
      ));
    }
  }
  return KbResult(found: true, answer: answer, sources: sources);
}

/// What the step saves: {k} the answer, {k}_found, {k}_sources [{ title, url }].
Map<String, dynamic> kbVariables(dynamic data, KbResult r) {
  final k = _s(_f(data, 'answerVariable')).trim();
  if (k.isEmpty) return {};
  return {
    k: r.found ? r.answer : '',
    '${k}_found': r.found,
    '${k}_sources': r.found ? r.sources.map((s) => <String, dynamic>{'title': s.title, 'url': s.url}).toList() : <dynamic>[],
  };
}

/// The bot's not-found words (the owner's HTML is rendered like any bot text).
String kbNotFoundHtml(dynamic data) =>
    plainText(_f(data, 'notFoundMessage')).isNotEmpty ? jsString(_f(data, 'notFoundMessage')) : '<p>${t('kb.notFound')}</p>';

/// Builder preview: no network. A clearly simulated answer with one sample
/// source, or not found when the question says "xyzzy" (so both paths can be tried).
KbResult previewKb(dynamic data, String text) {
  final q = text.trim();
  if (q.isEmpty || RegExp('xyzzy', caseSensitive: false).hasMatch(q)) {
    return const KbResult(found: false, answer: '', sources: [], error: 'no_match');
  }
  return kbResultOf(data, {
    'found': true,
    'answer':
        "Here's what our help articles say about \"${_slice(q, 0, 60)}${q.length > 60 ? '…' : ''}\". On the live bot this answer comes from your published knowledge base.",
    'sources': [
      {'title': 'Getting started with Conferbot', 'url': 'https://www.conferbot.com/'},
    ],
  });
}

// ---------------------------------------------------------------------------
// (12) Signature - a pad (or a typed name), saved as a PNG
// ---------------------------------------------------------------------------

const int sigExportMaxW = 1200;
const int sigExportPad = 16;
const String sigExportInk = '#111827';

/// Script-like faces most systems have, then a cursive fallback.
const String sigFontStack = '"Segoe Script", "Bradley Hand", "Brush Script MT", "Snell Roundhand", "Apple Chancery", "URW Chancery L", cursive';

class SigPoint {
  final num x;
  final num y;
  final num p;
  const SigPoint(this.x, this.y, [this.p = 0.5]);
}

typedef SigStroke = List<SigPoint>;

bool isHexColor(dynamic v) => RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6})$', caseSensitive: false).hasMatch(_s(v).trim());

/// {allowTyped, requireName, penColor, submitLabel, consentText}.
Map<String, dynamic> signatureConfig(dynamic data) {
  final label = _slice(_s(_f(data, 'submitLabel')).trim(), 0, 30);
  return {
    'allowTyped': _f(data, 'allowTyped') != false,
    'requireName': _f(data, 'requireName') == true,
    'penColor': isHexColor(_f(data, 'penColor')) ? _s(_f(data, 'penColor')).trim() : 'auto',
    'submitLabel': label.isNotEmpty ? label : t('signature.sign'),
    'consentText': _s(_f(data, 'consentText')).trim(),
  };
}

final RegExp _letterRe = RegExp(r'\p{L}', unicode: true);

/// A name that can stand as a signature: 2+ characters with at least one letter.
bool isSignatureName(dynamic v) {
  final s = _s(v).replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.length >= 2 && s.length <= 120 && _letterRe.hasMatch(s);
}

String cleanSignatureName(dynamic v) => _slice(_s(v).replaceAll(RegExp(r'\s+'), ' ').trim(), 0, 120);

/// Line width for a point: pen pressure when the device reports it, else the base.
num strokeWidthAt(num pressure, [num base = 2.4]) {
  final p = pressure.isFinite && pressure > 0 && pressure != 0.5 ? pressure : 0.5;
  return jsNum(_jsRound(base * (0.55 + p * 0.9) * 100) / 100);
}

/// The smooth path through a stroke's points: a quadratic curve from each
/// midpoint to the next, with the real point as the control. A one-point
/// stroke is a dot. Returns {start: {x, y} | null, segs: [{cx, cy, x, y}]}.
Map<String, dynamic> smoothSegments(List<SigPoint> pts) {
  if (pts.isEmpty) return {'start': null, 'segs': <Map<String, num>>[]};
  if (pts.length < 3) {
    return {
      'start': {'x': pts[0].x, 'y': pts[0].y},
      'segs': pts.skip(1).map((q) => <String, num>{'cx': q.x, 'cy': q.y, 'x': q.x, 'y': q.y}).toList(),
    };
  }
  final segs = <Map<String, num>>[];
  for (var i = 1; i < pts.length - 1; i++) {
    final mx = (pts[i].x + pts[i + 1].x) / 2;
    final my = (pts[i].y + pts[i + 1].y) / 2;
    segs.add({'cx': pts[i].x, 'cy': pts[i].y, 'x': mx, 'y': my});
  }
  final last = pts.last;
  segs.add({'cx': last.x, 'cy': last.y, 'x': last.x, 'y': last.y});
  return {
    'start': {'x': pts[0].x, 'y': pts[0].y},
    'segs': segs,
  };
}

/// The ink's bounding box (with half the widest line), or null when empty.
/// Keys: minX, minY, maxX, maxY.
Map<String, num>? strokeBounds(List<SigStroke> strokes, [num lineWidth = 3]) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final s in strokes) {
    for (final pt in s) {
      minX = math.min(minX, pt.x.toDouble());
      minY = math.min(minY, pt.y.toDouble());
      maxX = math.max(maxX, pt.x.toDouble());
      maxY = math.max(maxY, pt.y.toDouble());
    }
  }
  if (!minX.isFinite) return null;
  final h = lineWidth / 2;
  return {'minX': minX - h, 'minY': minY - h, 'maxX': maxX + h, 'maxY': maxY + h};
}

/// The export rectangle: the ink plus padding, kept inside the pad. Keys: x, y, w, h.
Map<String, int> trimRect(Map<String, num> b, num pad, num w, num h) {
  final x = math.max(0, (b['minX']! - pad).floor());
  final y = math.max(0, (b['minY']! - pad).floor());
  final x2 = math.min(w, (b['maxX']! + pad).ceil()).toInt();
  final y2 = math.min(h, (b['maxY']! + pad).ceil()).toInt();
  return {'x': x, 'y': y, 'w': math.max(1, x2 - x), 'h': math.max(1, y2 - y)};
}

/// Scale for the exported PNG: crisp (2x) but never wider than the max.
num exportScale(num w, [num maxW = sigExportMaxW, num want = 2]) => math.max(0.1, math.min(want, maxW / math.max(1, w)));

/// A typed name drawn as a signature: the size that fits the pad. Keys: size, font.
Map<String, dynamic> typedSignatureFont(String name, num width, num height) {
  final len = math.max(1, cleanSignatureName(name).length);
  final size = _jsRound(math.max(18, math.min(math.min(height * 0.42, 54), (width * 0.86 * 1.9) / len))).toInt();
  return {'size': size, 'font': 'italic ${size}px $sigFontStack'};
}

/// The variables a signature fills. `v` keys: url, at, name?, method ("drawn" | "typed").
Map<String, dynamic> signatureVariables(String k, Map<String, dynamic> v) {
  final key = k.trim();
  if (key.isEmpty) return {};
  final out = <String, dynamic>{key: v['url'], '${key}_at': v['at'], '${key}_method': v['method']};
  if (jsTruthy(v['name'])) out['${key}_name'] = v['name'];
  return out;
}

// ---------------------------------------------------------------------------
// Payment (payment-node) - Stripe Checkout, run on the server
// (embed-server services/chatbot/paymentService.js). The widget shows a pay
// card, opens Checkout in a new tab and waits for the server to say how it
// ended: paid -> "source", cancelled / failed -> "source-failed", timed out
// -> "source-timeout". The amount is the server's, never the page's.
// ---------------------------------------------------------------------------

const String paymentNodeType = 'payment-node';
const String paymentFailedHandle = 'source-failed';
const String paymentTimeoutHandle = 'source-timeout';
const int paymentDefaultTimeoutMin = 15;

/// How often the open card asks the server (our record only, no Stripe call).
const int paymentPeekMs = 5000;

/// At most one "ask Stripe" per this, when the visitor comes back to the tab.
const int paymentCheckGapMs = 10000;

const List<String> _payZeroDecimal = ['bif', 'clp', 'djf', 'gnf', 'jpy', 'kmf', 'krw', 'mga', 'pyg', 'rwf', 'ugx', 'vnd', 'vuv', 'xaf', 'xof', 'xpf'];
const List<String> _payThreeDecimal = ['bhd', 'jod', 'kwd', 'omr', 'tnd'];

int paymentDecimals(dynamic currency) {
  final c = _s(currency).toLowerCase();
  return _payZeroDecimal.contains(c) ? 0 : _payThreeDecimal.contains(c) ? 3 : 2;
}

/// en-US currency symbols (Intl.NumberFormat("en-US", {style: "currency"})).
const Map<String, String> _enUsCurrencySymbols = {
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'CNY': 'CN¥',
  'INR': '₹',
  'KRW': '₩',
  'CAD': r'CA$',
  'AUD': r'A$',
  'MXN': r'MX$',
  'BRL': r'R$',
  'HKD': r'HK$',
  'NZD': r'NZ$',
  'TWD': r'NT$',
  'XCD': r'EC$',
  'ILS': '₪',
  'VND': '₫',
  'PHP': '₱',
  'XAF': 'FCFA',
  'XOF': 'F CFA',
  'XPF': 'CFPF',
};

/// A number with en-US grouping and fixed decimals: 1234.5 -> "1,234.50".
String _groupedFixed(double n, int decimals) {
  final fixed = n.abs().toStringAsFixed(decimals);
  final dot = fixed.indexOf('.');
  final whole = dot == -1 ? fixed : fixed.substring(0, dot);
  final frac = dot == -1 ? '' : fixed.substring(dot);
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '$buf$frac';
}

/// Minor units -> "$25.00". The web formats in the visitor's locale; this
/// port always writes en-US (symbol, else the code and a no-break space:
/// "AED 25.00"), with the currency's own decimals.
String paymentAmountText(dynamic minor, dynamic currency, [String? locale]) {
  final c = _s(currency).trim().toUpperCase();
  final n = jsNumber(minor);
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(c) || !n.isFinite) return '';
  final digits = paymentDecimals(c);
  final major = n / math.pow(10, digits);
  final sign = major < 0 ? '-' : '';
  final amount = _groupedFixed(major, digits);
  final symbol = _enUsCurrencySymbols[c];
  return symbol != null ? '$sign$symbol$amount' : '$sign$c $amount';
}

/// Major units the builder stored ("25", 19.99) -> minor units, for the preview.
int? paymentMinorOf(dynamic amount, dynamic currency) {
  final raw = _s(amount);
  if (raw.contains('-')) return null;
  final n = jsNumber(raw.replaceAll(RegExp(r'[^\d.]'), ''));
  if (!n.isFinite || n <= 0) return null;
  return _jsRound(n * math.pow(10, paymentDecimals(currency))).toInt();
}

int paymentTimeoutMs(dynamic data) {
  final n = _numField(data, 'timeoutMinutes').floorToDouble();
  return (n.isFinite && n >= 1 ? math.min(n.toInt(), 1440) : paymentDefaultTimeoutMin) * 60 * 1000;
}

const Map<String, String> _payOutcome = {'paid': 'paid', 'failed': 'failed', 'cancelled': 'failed', 'timeout': 'timeout', 'expired': 'timeout'};

/// "paid", "failed" or "timeout"; null for a status that isn't an end.
String? paymentOutcomeOf(dynamic status) => _payOutcome[_s(status)];

String paymentHandleOf(String outcome) =>
    outcome == 'paid' ? 'source' : outcome == 'timeout' ? paymentTimeoutHandle : paymentFailedHandle;

/// "12:05" / "0:42" left before the step times out.
String paymentCountdown(num ms) {
  final s = math.max(0, (ms / 1000).ceil());
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = _pad2(s % 60);
  return h > 0 ? '$h:${_pad2(m)}:$sec' : '$m:$sec';
}

/// Only a Stripe-hosted page may be opened from the card.
bool isCheckoutUrl(dynamic url) => RegExp(r'^https:\/\/([a-z0-9-]+\.)*stripe\.com\/', caseSensitive: false).hasMatch(_s(url));
bool isReceiptUrl(dynamic url) => RegExp(r'^https:\/\/([a-z0-9-]+\.)*stripe\.com\/', caseSensitive: false).hasMatch(_s(url));

class PaymentResult {
  final String status;
  final num? amount;
  final String currency;
  final String receiptUrl;
  final String paymentId;
  const PaymentResult({required this.status, this.amount, this.currency = '', this.receiptUrl = '', this.paymentId = ''});

  Map<String, dynamic> toJson() =>
      {'status': status, 'amount': amount, 'currency': currency, 'receiptUrl': receiptUrl, 'paymentId': paymentId};
}

/// The variables a settled payment writes (mirror of paymentService.paymentVariables).
Map<String, dynamic> paymentVariables(dynamic key, PaymentResult r) {
  final k = _s(key).trim();
  if (k.isEmpty) return {};
  final num? amount = r.amount == null || !r.amount!.isFinite ? null : jsNum(r.amount! / math.pow(10, paymentDecimals(r.currency)));
  final currency = r.currency.toUpperCase();
  final receiptUrl = isReceiptUrl(r.receiptUrl) ? r.receiptUrl : '';
  return {
    k: {'status': r.status, 'amount': amount, 'currency': currency, 'receiptUrl': receiptUrl, 'paymentId': r.paymentId},
    '${k}_status': r.status,
    '${k}_amount': amount,
    '${k}_currency': currency,
    '${k}_receipt_url': receiptUrl,
  };
}

const Map<String, String> _payDone = {'paid': 'pay.paid', 'failed': 'pay.cancelled', 'timeout': 'pay.timedOut'};

/// The visitor's side of the transcript once the payment ended.
String paymentReplyText(String outcome, [String amountText = '']) =>
    outcome == 'paid' && amountText.isNotEmpty ? t('pay.paidAmount', {'amount': amountText}) : t(_payDone[outcome] ?? 'pay.cancelled');

/// Server error codes -> what the card says.
String paymentErrorText(dynamic code) => code == 'not_configured'
    ? t('pay.notConfigured')
    : code == 'invalid_amount'
        ? t('pay.invalidAmount')
        : code == 'rate_limited'
            ? t('pay.rateLimited')
            : code == 'network' || code == 'timeout'
                ? t('pay.network')
                : t('pay.failed');
