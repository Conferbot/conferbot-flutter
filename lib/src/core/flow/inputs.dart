/// Checks on what the visitor types or picks, ported from the web widget
/// (conferbot-widget/src/ts/chat/nodeKit.ts, nodeLogic.ts, utils/emailTypos.ts)
/// with its English messages (ts/i18n/en.ts), via the React Native SDK
/// (src/core/flow/inputs.ts). Pure.
library;

import 'i18n_en.dart';
import 'js.dart';
import 'text.dart';

/// The texts the steps say, in the active language (web i18n validation.*,
/// upload.*, common.*). The name stays from when they were English only.
class EnTexts {
  const EnTexts();
  String get emailInvalid => t('validation.email');
  String emailTypo(String email) => t('validation.emailTypo', {'email': email});
  String get phoneInvalid => t('validation.phone');
  String get numberLike => t('validation.numberLike');
  String numberBetween(dynamic min, dynamic max) =>
      t('validation.numberBetween', {'min': jsString(min), 'max': jsString(max)});
  String numberMin(dynamic min) => t('validation.numberMin', {'min': jsString(min)});
  String numberMax(dynamic max) => t('validation.numberMax', {'max': jsString(max)});
  String get link => t('validation.link');
  String get numberInvalid => t('validation.number');
  String get urlInvalid => t('validation.url');
  String uploadOverSize(num mb) => t('upload.overSize', {'mb': jsString(mb)});
  String uploadNotAllowed(String types) => t('upload.notAllowed', {'types': types});
  String get uploadRetry => t('upload.tapRetry');
  String get skipped => t('common.skipped');
  String get done => t('common.done');
  String get somethingWrong => t('common.somethingWrong');
}

const EnTexts en = EnTexts();

/// The keys of [EnTexts]' plain texts, so a fallback drawn in another
/// language still knows its English (stock too).
const List<String> _enKeys = [
  'validation.email', 'validation.phone', 'validation.numberLike', 'validation.link',
  'validation.number', 'validation.url', 'upload.tapRetry', 'common.skipped', 'common.done',
  'common.somethingWrong',
];

/// The owner's own error text, or the default when they left it empty or kept
/// the stock English (web i18n ownerTextOr). [fallback] is drawn in the
/// active language; its English is stock too.
String ownerTextOr(dynamic value, String fallback, [List<String> stockEnglish = const []]) {
  final v = value is String ? plainText(value) : '';
  final key = _enKeys.where((k) => t(k) == fallback).firstOrNull;
  final stock = [fallback, if (key != null) I18n.tFor(I18n.en, key), ...stockEnglish];
  if (v.isEmpty || stock.any((s) => plainText(s) == v)) return fallback;
  return value as String;
}

final RegExp _emailRe = RegExp(
    r'''^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$''');

String _str(dynamic v) => v == null ? '' : jsString(v);

bool isValidEmail(dynamic value) => _emailRe.hasMatch(_str(value).trim().toLowerCase());

/// "+1 (555) 123-4567" -> "+15551234567"; a leading "00" becomes "+".
String normalizePhone(dynamic value) {
  final raw = _str(value).trim();
  final plus = raw.startsWith('+') || raw.startsWith('00') ? '+' : '';
  var digits = raw.replaceAll(RegExp('[\\s().\\-/ ]'), '').replaceFirst(RegExp(r'^\+'), '');
  if (plus.isNotEmpty && digits.startsWith('00')) digits = digits.substring(2);
  return plus + digits;
}

bool isValidPhone(dynamic value) => RegExp(r'^\+?\d{6,15}$').hasMatch(normalizePhone(value));

/// "1,200" -> 1200, "3,5" -> 3.5; anything else null.
num? parseNumberInput(dynamic value) {
  final raw = _str(value).trim().replaceAll(RegExp("[\\s_' ]"), '');
  if (!RegExp(r'^[-+]?(\d+|\d{1,3}(,\d{3})+)?([.,]\d+)?$').hasMatch(raw) || !RegExp(r'\d').hasMatch(raw)) return null;
  final normalized = RegExp(r'^[-+]?\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(raw) ? raw.replaceAll(',', '') : raw.replaceFirst(',', '.');
  final n = jsNumber(normalized);
  return n.isFinite ? jsNum(n) : null;
}

/// A link people would type: no spaces, a dot, a 2+ letter ending.
bool isValidLink(dynamic value) {
  final raw = _str(value).trim();
  if (raw.isEmpty || RegExp(r'\s').hasMatch(raw)) return false;
  final host = raw.replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*:\/\/', caseSensitive: false), '').split(RegExp(r'[/?#]'))[0];
  return RegExp(r'^[^.@]+(\.[^.]+)*\.[a-z]{2,}(:\d+)?$', caseSensitive: false).hasMatch(host.replaceFirst(RegExp(r'^[^@]*@'), ''));
}

/// "conferbot.com" -> "https://conferbot.com"; mailto/tel kept; other schemes refused.
String linkHref(dynamic value) {
  final raw = _str(value).trim();
  if (raw.isEmpty || RegExp(r'\s').hasMatch(raw)) return '';
  if (RegExp(r'^(https?:\/\/|mailto:|tel:)', caseSensitive: false).hasMatch(raw)) return raw;
  if (RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(raw) || raw.startsWith('//')) return '';
  return isValidLink(raw) ? 'https://$raw' : '';
}

num? _numOrNull(dynamic v) => v == '' || v == null || !jsNumber(v).isFinite ? null : jsNum(jsNumber(v));

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// ask-number-node: the refusal message, or null when the answer is fine.
String? numberProblem(dynamic value, dynamic data) {
  final d = _map(data);
  final cond = _map(d['enableConditions']);
  final n = parseNumberInput(value);
  final min = _numOrNull(cond['minVal']);
  final max = _numOrNull(cond['maxVal']);
  String? message;
  if (n == null) {
    message = en.numberLike;
  } else if (min != null && max != null && (n < min || n > max)) {
    message = en.numberBetween(min, max);
  } else if (min != null && n < min) {
    message = en.numberMin(min);
  } else if (max != null && n > max) {
    message = en.numberMax(max);
  }
  if (message == null) return null;
  final custom = _str(d['invalidNumberResponse']).replaceAll(RegExp(r'<\/?[^>]+(>|$)'), '').trim();
  if (custom.isEmpty) return message;
  String show(dynamic v) => v == null || v == '' ? '' : jsString(v);
  return custom.replaceAll('{min}', show(cond['minVal'])).replaceAll('{max}', show(cond['maxVal']));
}

/// The owner's phone error (new or older field name), or the default.
String phoneErrorText(dynamic data) {
  final d = _map(data);
  String textOf(dynamic v) => _str(v).replaceAll(RegExp(r'<\/?[^>]+(>|$)'), '').trim();
  final own = textOf(d['invalidPhoneResponse']);
  return ownerTextOr(own.isNotEmpty ? own : textOf(d['incorrectPhoneNumberResponse']), en.phoneInvalid);
}

// ----- e-mail typos (utils/emailTypos.ts) -----
const List<String> _domains = [
  'gmail.com', 'googlemail.com', 'yahoo.com', 'yahoo.co.uk', 'hotmail.com', 'hotmail.co.uk', 'outlook.com', 'live.com', 'msn.com',
  'icloud.com', 'me.com', 'aol.com', 'proton.me', 'protonmail.com', 'gmx.com', 'gmx.de', 'web.de', 'yandex.com', 'mail.com', 'zoho.com',
];
const Map<String, String> _tldFixes = {'con': 'com', 'cmo': 'com', 'ocm': 'com', 'comm': 'com', 'nt': 'net', 'orgg': 'org'};

int _distance(String a, String b) {
  final d = List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, 0)..[0] = i);
  for (var j = 1; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final x = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)];
      d[i][j] = x.reduce((p, q) => p < q ? p : q);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        final t = d[i - 2][j - 2] + 1;
        if (t < d[i][j]) d[i][j] = t;
      }
    }
  }
  return d[a.length][b.length];
}

/// "jamie@gmial.com" -> "jamie@gmail.com"; null when the address looks right.
String? suggestEmailFix(String? email) {
  final m = RegExp(r'^([^\s@]+)@([^\s@]+)$').firstMatch((email ?? '').trim().toLowerCase());
  if (m == null) return null;
  final user = m.group(1)!;
  final domain = m.group(2)!;
  if (_domains.contains(domain)) return null;
  String? best;
  var bestD = 3;
  for (final d in _domains) {
    final dist = _distance(domain, d);
    if (dist < bestD && dist <= (d.length > 8 ? 2 : 1)) {
      bestD = dist;
      best = d;
    }
  }
  if (best != null) return '$user@$best';
  final parts = domain.split('.');
  final tld = parts.last;
  if (parts.length >= 2 && _tldFixes[tld] != null) {
    return '$user@${[...parts.sublist(0, parts.length - 1), _tldFixes[tld]].join('.')}';
  }
  return null;
}

// ----- files -----
const int defaultMaxFileMb = 5;

/// The allowed types in words: "PNG or IMAGE/JPEG", "images or PDF".
String fileTypesWords(dynamic types) {
  final list = (types is List ? types : const [])
      .map((v) => _str(v).trim().toLowerCase())
      .where((x) => x.isNotEmpty)
      .map((x) => x.endsWith('/')
          ? x == 'image/'
              ? t('file.images')
              : x == 'video/'
                  ? t('file.videos')
                  : x.replaceFirst('/', '')
          : x.replaceFirst(RegExp(r'^\.'), '').replaceFirst(RegExp(r'^application\/'), '').toUpperCase())
      .map((x) => x == 'JPEG' ? 'JPG' : x);
  final unique = <String>[];
  for (final x in list) {
    if (!unique.contains(x)) unique.add(x);
  }
  if (unique.isEmpty) return '';
  return unique.length == 1 ? unique[0] : '${unique.sublist(0, unique.length - 1).join(', ')} ${t('common.or')} ${unique.last}';
}

/// Why a picked file can't be sent, or null (web nodeLogic.fileUploadProblem).
/// [file] is a map with name, type and size.
String? fileUploadProblem(dynamic file, [dynamic data]) {
  final f = _map(file);
  final d = _map(data);
  final num maxMb = jsNumber(d['maxFileSizeMB']) > 0 ? jsNum(jsNumber(d['maxFileSizeMB'])) : defaultMaxFileMb;
  if (jsNumber(f['size']) > maxMb * 1024 * 1024) return en.uploadOverSize(maxMb);
  final allowed = d['allowedFileTypes'] is List
      ? (d['allowedFileTypes'] as List).map((t) => _str(t).trim().toLowerCase()).where((t) => t.isNotEmpty).toList()
      : <String>[];
  if (allowed.isEmpty) return null;
  final name = (jsTruthy(f['name']) ? _str(f['name']) : '').toLowerCase();
  final ext = name.contains('.') ? name.split('.').last : '';
  final mime = (jsTruthy(f['type']) ? _str(f['type']) : '').toLowerCase();
  final ok = allowed.any((t) => t.contains('/')
      ? (t.endsWith('/') || t.endsWith('/*') ? mime.startsWith(t.replaceFirst(RegExp(r'\*$'), '')) : mime == t)
      : ext == t.replaceFirst(RegExp(r'^\.'), ''));
  if (ok) return null;
  final words = fileTypesWords(allowed);
  return en.uploadNotAllowed(words.isNotEmpty ? words : allowed.join(', '));
}

/// Optional upload: flagged, or "(optional)" in the question.
bool isOptionalUpload(dynamic data) {
  final d = _map(data);
  return d['optional'] == true || RegExp(r'\(optional\)', caseSensitive: false).hasMatch(_str(d['questionText']));
}
