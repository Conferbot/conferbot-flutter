// The owner's font and the theme's (lib/src/core/customization/owner_font.dart):
// the React Native SDK's __tests__/core/ownerFont.test.ts ported (web
// ts/fonts/ownerFont.ts, ts/theme/themeTokens.ts, ts/theme/applyTheme.ts
// loadThemeFont), and the generated catalog checked against RN's and the
// widget's.
import 'dart:convert';
import 'dart:io';

import 'package:conferbot_flutter/src/core/customization/owner_font.dart';
import 'package:flutter_test/flutter_test.dart';

const googleTtf = '''
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/inter/v20/a.ttf) format('truetype');
}
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 700;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/inter/v20/b.ttf) format('truetype');
}
@font-face {
  font-family: 'Inter';
  font-style: italic;
  font-weight: 400;
  src: url(https://fonts.gstatic.com/s/inter/v20/c.ttf) format('truetype');
}
@font-face {
  font-family: 'Inter';
  font-weight: 400;
  src: url(https://fonts.gstatic.com/s/inter/v20/d.woff2) format('woff2');
}''';

void main() {
  test('knows the defaults that mean no font was picked', () {
    expect(isDefaultFont(''), isTrue);
    expect(isDefaultFont('Arial'), isTrue);
    expect(isDefaultFont('Gill Sans, sans-serif;'), isTrue);
    expect(isDefaultFont(null), isTrue);
    expect(isDefaultFont('Inter'), isFalse);
  });

  test('finds a catalog font by family, stack, id or our prefixed name', () {
    expect(findCatalogFont('Inter')?.id, 'inter');
    expect(findCatalogFont("'Plus Jakarta Sans', sans-serif")?.id, 'plus-jakarta-sans');
    expect(findCatalogFont('dm-sans')?.family, 'DM Sans');
    expect(findCatalogFont('CB Font Poppins')?.id, 'poppins');
    expect(findCatalogFont('Charlesworth'), isNull);
    expect(firstFamily('"Gill Sans", serif'), 'Gill Sans');
  });

  test("reads Google Fonts' TrueType faces, skipping italics only by style and woff2 entirely", () {
    expect(parseFontFaces(googleTtf), const [
      FontFace(weight: 400, style: 'normal', url: 'https://fonts.gstatic.com/s/inter/v20/a.ttf'),
      FontFace(weight: 700, style: 'normal', url: 'https://fonts.gstatic.com/s/inter/v20/b.ttf'),
      FontFace(weight: 400, style: 'italic', url: 'https://fonts.gstatic.com/s/inter/v20/c.ttf'),
    ]);
    expect(parseFontFaces(''), isEmpty);
    expect(googleFontUrl('Inter:wght@400;700'), 'https://fonts.googleapis.com/css2?family=Inter:wght@400;700&display=swap');
  });

  test("names faces so the app's own text never picks them up", () {
    expect(faceName('Inter', 400), 'CB Font Inter');
    expect(faceName('Inter', 700), 'CB Font Inter 700');
  });

  test("puts the owner's font over the theme's, everywhere", () {
    const inter = FontPick('Inter', 'Inter:wght@400;500;600;700');
    expect(chatFontsFor('Inter', themeFont: 'Fraunces', themeFontRole: 'display'), const ChatFonts(inter, inter));
    // A system font is used by name; system-ui is the platform's own.
    expect(chatFontsFor('Georgia'), const ChatFonts(FontPick('Georgia', null), FontPick('Georgia', null)));
    expect(chatFontsFor('system-ui'), const ChatFonts(null, null));
    // An older bot's unknown font stays a plain family name.
    expect(chatFontsFor('Charlesworth').body, const FontPick('Charlesworth', null));
  });

  test('uses a body theme font for all text, a display one for headings only', () {
    expect(
      chatFontsFor('Arial', themeFont: 'Manrope', themeFontRole: 'body'),
      const ChatFonts(FontPick('Manrope', 'Manrope:wght@400;500;600;700'), FontPick('Manrope', 'Manrope:wght@400;500;600;700')),
    );
    expect(chatFontsFor('', themeFont: 'Fraunces', themeFontRole: 'display'), ChatFonts(null, FontPick('Fraunces', themeFontQueries['Fraunces'])));
    expect(chatFontsFor(''), const ChatFonts(null, null));
  });

  test('draws each weight with the nearest face it has, nothing until one is loaded', () {
    const pick = FontPick('Inter', 'Inter');
    expect(fontFamilyFor(pick, [], 400), isNull);
    expect(fontFamilyFor(pick, [400, 700], 400), 'CB Font Inter');
    expect(fontFamilyFor(pick, [400, 700], 600), 'CB Font Inter 700');
    expect(fontFamilyFor(pick, [400, 600], 500), 'CB Font Inter');
    expect(fontFamilyFor(pick, [500], 400), 'CB Font Inter 500');
    expect(fontFamilyFor(const FontPick('Georgia', null), null, 700), 'Georgia');
    expect(fontFamilyFor(null, [400], 400), isNull);
    expect(weightOf('bold'), 700);
    expect(weightOf('600'), 600);
    expect(weightOf(null), 400);
  });

  test("carries RN's catalog and theme fonts unchanged (tool/sync_fonts.sh --check)", () {
    final rn = Directory('../conferbot-react-native');
    if (!rn.existsSync()) return; // RN is not checked out beside this SDK
    final r = Process.runSync('sh', ['tool/sync_fonts.sh', '--check']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  test("carries the widget's catalog and theme fonts unchanged", () {
    const web = '../../conferbot-widget/src/ts';
    final catalog = File('$web/fonts/catalog.ts');
    if (!catalog.existsSync()) return; // the widget is not checked out beside the SDK
    final block = jsonDecode(catalog.readAsStringSync().split('/* FONTS:BEGIN */')[1].split('/* FONTS:END */')[0]) as Map<String, dynamic>;
    final fonts = block['fonts'] as List;
    expect(fontCatalog.length, fonts.length);
    for (var i = 0; i < fonts.length; i++) {
      final f = fonts[i] as Map;
      final c = fontCatalog[i];
      expect([c.id, c.label, c.family, c.category, c.stack, c.google], [f['id'], f['label'], f['family'], f['category'], f['stack'], f['google']]);
    }
    final reg = File('$web/theme/registry.ts').readAsStringSync();
    final themes = {for (final m in RegExp(r'font: font\("([^"]+)", "([^"]+)"\)').allMatches(reg)) m.group(1)!: m.group(2)!};
    expect(themeFontQueries, themes);
  });
}
