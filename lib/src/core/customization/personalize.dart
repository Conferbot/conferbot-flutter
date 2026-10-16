/// Personalised texts: "Hi {{first_name|there}} 👋" -> "Hi Sam 👋" (or
/// "Hi there 👋"). Ported from the React Native SDK (src/core/personalize.ts),
/// itself from the web widget: conferbot-widget src/ts/layout/ownerLayout.ts
/// (visitorVars, personalize, PERSONALIZED_KEYS, personalizeCustomizations),
/// applied in index.ts right after the bot's data arrives. This is the
/// dashboard's "Greet by name" (Customize > Welcome).
///
/// One difference, on purpose: the web HTML-escapes the values because it
/// draws these texts as markup; Flutter draws them as text, so they stay as
/// typed. Pure.
library;

String _firstString(List<dynamic> values) {
  for (final v in values) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

/// What a visitor is known by: the app's user (its name and metadata, as
/// the web's identify data) and a name the chat already asked for.
Map<String, String> visitorVars(Map<String, dynamic>? context, [dynamic name]) {
  final c = context ?? const <String, dynamic>{};
  final parts = [c['firstName'] ?? c['first_name'], c['lastName'] ?? c['last_name']]
      .where((v) => v != null && v.toString().isNotEmpty)
      .join(' ');
  final full = _firstString([c['name'], c['fullName'], c['full_name'], name, parts]);
  return {
    'name': full,
    'first_name': _firstString([c['firstName'], c['first_name'], full.split(RegExp(r'\s+')).first]),
    'company': _firstString([c['company'], c['companyName'], c['company_name'], c['organization']]),
  };
}

final _token = RegExp(r'\{\{\s*([a-z_]+)\s*(?:\|([^}]*))?\}\}', caseSensitive: false);

/// Fill the tokens. A token with no value and no fallback is dropped along
/// with the space before it ("Hi {{name}}!" -> "Hi!"); the fallback is the
/// owner's own text. Anything that is not a string comes back as it was.
dynamic personalize(dynamic text, Map<String, String> vars) {
  if (text is! String || !text.contains('{{')) return text;
  return text
      .replaceAllMapped(_token, (m) {
        final key = m.group(1)!.toLowerCase();
        final k = key == 'firstname' ? 'first_name' : key;
        final v = vars[k];
        if (v != null && v.isNotEmpty) return v;
        final fallback = m.group(2);
        return fallback != null ? fallback.trim() : '\u0000';
      })
      .replaceAll(RegExp('[ \\t]*\u0000'), '')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ');
}

/// The visitor-facing texts that take {{name}} / {{first_name}} / {{company}}.
const personalizedKeys = ['chatIconCtaText', 'initialPageTitle', 'initialPageDescription', 'initialPageCardButtonText'];

/// The bot's settings with those texts (and each greeting rule's text)
/// filled in. A copy: the settings passed in are left as they were.
Map<String, dynamic>? personalizeCustomizations(Map<String, dynamic>? c, Map<String, String> vars) {
  if (c == null) return null;
  final out = Map<String, dynamic>.from(c);
  for (final k in personalizedKeys) {
    if (out[k] is String) out[k] = personalize(out[k], vars);
  }
  final rules = out['greetingRules'];
  if (rules is List) {
    out['greetingRules'] = [
      for (final r in rules)
        r is Map && r['text'] is String && (r['text'] as String).contains('{{')
            ? {...Map<String, dynamic>.from(r), 'text': personalize(r['text'], vars)}
            : r,
    ];
  }
  return out;
}
