/// The visitor's language, sent with every response record as the web
/// widget's `visitorInsights.language.browser` (navigator.language,
/// conferbot-widget ts/visitors/insights.ts). The server reads it
/// (embed-server socket/handlers/messageHandler.js, `browserLanguage`) so the
/// AI answers a message too short to tell ("ok", "hi") in the visitor's own
/// language. An app has no page, so `language.page` and the browsing history
/// the web also sends are never set. Ported from the React Native SDK's
/// src/core/deviceLanguage.ts.
library;

import 'dart:ui' show PlatformDispatcher;

class DeviceLanguage {
  DeviceLanguage._();

  // The web's own cut: whitespace collapsed, trimmed, at most n characters.
  static String _cut(Object? v, int n) {
    final s = (v ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.length > n ? s.substring(0, n) : s;
  }

  /// A locale as the browser writes it: BCP 47 ("en-US"), not "en_US",
  /// "en_US@calendar=..." or "en-US-u-ca-..."; '' when it is not one.
  static String normalize(Object? raw) {
    final s = _cut(raw, 64).split('@').first.replaceAll('_', '-');
    if (!RegExp(r'^[A-Za-z]{2,3}(-|$)').hasMatch(s)) return '';
    // "und" is Flutter's tag for a locale it does not know: no language.
    if (RegExp(r'^und(-|$)', caseSensitive: false).hasMatch(s)) return '';
    final ext = s.toLowerCase().indexOf('-u-');
    return _cut(ext > 0 ? s.substring(0, ext) : s, 16);
  }

  /// The first of [candidates] that is a locale, or ''.
  static String firstOf(Iterable<Object?> candidates) {
    for (final c in candidates) {
      final locale = normalize(c);
      if (locale.isNotEmpty) return locale;
    }
    return '';
  }

  /// The response record's `visitorInsights`: the web's snapshot shape with
  /// only the language. Null when the language is unknown.
  static Map<String, dynamic>? visitorInsightsOf(String locale) {
    final browser = _cut(locale, 16);
    return browser.isEmpty
        ? null
        : {
            'v': 1,
            'language': {'browser': browser},
          };
  }

  /// The phone's preferred language, most preferred first; the app's locale
  /// when the list is empty.
  static String read([PlatformDispatcher? dispatcher]) {
    try {
      final d = dispatcher ?? PlatformDispatcher.instance;
      return firstOf([...d.locales.map((l) => l.toLanguageTag()), d.locale.toLanguageTag()]);
    } catch (_) {
      return '';
    }
  }

  static String? _cached;

  /// The device's language, read once per app run.
  static String get current => _cached ??= read();

  /// Tests: read the device again, or use [locale] instead of it.
  static void debugReset([String? locale]) => _cached = locale;
}
