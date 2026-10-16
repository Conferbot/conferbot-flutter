/// The owner's font and the theme's font, as the web widget picks them.
/// Ported from the React Native SDK (src/core/ownerFont.ts), itself from
/// conferbot-widget src/ts/fonts/ownerFont.ts (findCatalogFont, the
/// "CB Font " prefixed family, ownerFontUrl), src/ts/theme/themeTokens.ts
/// (isDefaultFont, parseFontFaces, themeFontUrl, the owner's font over the
/// theme's: --cb-o-font) and src/ts/theme/applyTheme.ts (loadThemeFont).
///
/// Which font the chat's text uses:
///   - the owner's font (customizations.font) when it is not a default
///     ("", "Arial", "Gill Sans, sans-serif"): everything, body and headings;
///   - else the theme's font: a "body" theme font for all text, a "display"
///     one for headings only (the header's title, the home screen's title);
///   - else the platform's font.
/// A catalog web font (or a theme font) is fetched from Google Fonts at run
/// time and registered under a "CB Font <family>" name
/// (services/font_loader.dart), so the app's own text never picks it up; a
/// system or unknown font is used by its family name (the app may bundle
/// it), and the platform font when it has none.
///
/// Flutter registers every upright face of a family under the one name
/// "CB Font <family>" ([faceName] with 400), and picks the face nearest each
/// text's weight itself; [fontFamilyFor] keeps RN's per-weight names for the
/// shared tests. Pure.
library;

import 'fonts_data.dart';

export 'fonts_data.dart' show CatalogFont, fontCatalog, themeFontQueries;

const ownerFontPrefix = 'CB Font ';

/// Fonts that mean "the owner never picked one" (dashboard / model defaults).
const _defaultFonts = ['', 'arial', 'gill sans, sans-serif', 'gill sans'];
const _systemSans = "-apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";

String _bareFont(dynamic font) {
  var v = font is String ? font.trim().replaceAll(RegExp(r'[;\s]+$'), '').trim() : '';
  if (v == _systemSans) return '';
  if (v.endsWith(', $_systemSans')) v = v.substring(0, v.length - (_systemSans.length + 2)).trim();
  return v;
}

bool isDefaultFont(dynamic font) => font is! String || _defaultFonts.contains(_bareFont(font).replaceAll(RegExp('["\']'), '').toLowerCase());

String _unquote(String s) => s.trim().replaceAll(RegExp('^[\'"]+|[\'"]+\$'), '').trim();

/// The first family named in a font-family value, unquoted.
String firstFamily(dynamic value) => value is String ? _unquote(value.split(',').first) : '';

final Map<String, CatalogFont> _byName = {
  for (final f in fontCatalog) ...{f.family.toLowerCase(): f, f.id: f},
};

/// The catalog font a saved value names (by family, id, or our prefixed name), or null.
CatalogFont? findCatalogFont(dynamic value) {
  var name = firstFamily(value).toLowerCase();
  if (name.isEmpty) return null;
  final prefix = ownerFontPrefix.toLowerCase();
  if (name.startsWith(prefix)) name = name.substring(prefix.length);
  return _byName[name];
}

String googleFontUrl(String query) => 'https://fonts.googleapis.com/css2?family=$query&display=swap';

class FontFace {
  final int weight;

  /// "normal" or "italic".
  final String style;
  final String url;
  const FontFace({required this.weight, required this.style, required this.url});

  @override
  bool operator ==(Object other) => other is FontFace && other.weight == weight && other.style == style && other.url == url;

  @override
  int get hashCode => Object.hash(weight, style, url);

  @override
  String toString() => 'FontFace($weight, $style, $url)';
}

/// A Google Fonts stylesheet's faces: each @font-face block's weight, style
/// and its TrueType / OpenType url (a woff2-only block is skipped: Flutter
/// does not register woff2). Variable ranges ("100 900") read as their start.
List<FontFace> parseFontFaces(String? css) {
  final faces = <FontFace>[];
  for (final m in RegExp(r'@font-face\s*{[^}]*}').allMatches(css ?? '')) {
    final block = m.group(0)!;
    final src = RegExp(r'src:\s*([^;]+);').firstMatch(block)?.group(1) ?? '';
    final url = RegExp(r'''url\(\s*['"]?([^'")]+)['"]?\s*\)\s*format\(\s*['"]?(truetype|opentype)['"]?\s*\)''', caseSensitive: false)
        .firstMatch(src)
        ?.group(1);
    if (url == null) continue;
    final weight = int.tryParse(RegExp(r'font-weight:\s*(\d+)').firstMatch(block)?.group(1) ?? '400') ?? 400;
    final style = RegExp(r'font-style:\s*italic').hasMatch(block) ? 'italic' : 'normal';
    faces.add(FontFace(weight: weight, style: style, url: url));
  }
  return faces;
}

/// The family name a face is registered under: the 400 face plain, others with their weight.
String faceName(String family, int weight) => weight == 400 ? '$ownerFontPrefix$family' : '$ownerFontPrefix$family $weight';

class FontPick {
  final String family;

  /// The Google Fonts query to fetch it, or null (a system or unknown font, used by name).
  final String? google;
  const FontPick(this.family, this.google);

  @override
  bool operator ==(Object other) => other is FontPick && other.family == family && other.google == google;

  @override
  int get hashCode => Object.hash(family, google);

  @override
  String toString() => 'FontPick($family, $google)';
}

class ChatFonts {
  /// The owner's or the body theme font: all of the chat's text.
  final FontPick? body;

  /// Headings: the owner's font, else the theme's (body or display).
  final FontPick? display;
  const ChatFonts(this.body, this.display);

  @override
  bool operator ==(Object other) => other is ChatFonts && other.body == body && other.display == display;

  @override
  int get hashCode => Object.hash(body, display);

  @override
  String toString() => 'ChatFonts($body, $display)';
}

// A system pick: "system-ui" is the platform font (nothing to set).
FontPick? _systemPick(String family) => family.isEmpty || family == 'system-ui' ? null : FontPick(family, null);

/// The fonts the chat uses for the owner's settings and the theme's font
/// (ResolvedWidgetTheme `font`, `fontRole`). The owner's own font wins over
/// the theme's for both (web themeTokens --cb-o-font / --cb-o-font-display).
ChatFonts chatFontsFor(dynamic ownerFont, {String? themeFont, String? themeFontRole}) {
  if (!isDefaultFont(ownerFont)) {
    final cat = findCatalogFont(ownerFont);
    final pick = cat != null ? (cat.google != null ? FontPick(cat.family, cat.google) : _systemPick(cat.family)) : _systemPick(firstFamily(ownerFont));
    if (pick != null) return ChatFonts(pick, pick);
  }
  final tf = themeFont == null || themeFont.isEmpty ? null : themeFont;
  if (tf == null) return const ChatFonts(null, null);
  final pick = FontPick(tf, themeFontQueries[tf] ?? findCatalogFont(tf)?.google);
  return themeFontRole == 'display' ? ChatFonts(null, pick) : ChatFonts(pick, pick);
}

/// The registered face to draw [weight] with: the loaded weight nearest to
/// it (ties go heavier for bold text, lighter for normal), as a family
/// name. null when nothing is loaded: the platform font draws it.
String? fontFamilyFor(FontPick? pick, List<int>? loaded, [int weight = 400]) {
  if (pick == null) return null;
  if (pick.google == null) return pick.family;
  if (loaded == null || loaded.isEmpty) return null;
  final sorted = [...loaded]..sort((a, b) {
      final d = (a - weight).abs() - (b - weight).abs();
      if (d != 0) return d;
      return weight >= 600 ? b - a : a - b;
    });
  return faceName(pick.family, sorted.first);
}

/// A style's weight as a number ("bold" 700, "normal" / unset 400).
int weightOf(dynamic w) {
  if (w == 'bold') return 700;
  return int.tryParse('${w ?? ''}') ?? 400;
}
