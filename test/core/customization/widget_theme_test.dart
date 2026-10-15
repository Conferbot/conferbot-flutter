import 'package:conferbot_flutter/src/core/customization/customizations.dart';
import 'package:conferbot_flutter/src/core/customization/widget_theme.dart';
import 'package:flutter_test/flutter_test.dart';

final _hex = RegExp(r'^#[0-9a-f]{6}$');

void main() {
  test('knows the 27 web themes, classic first', () {
    expect(WidgetTheme.themes, hasLength(27));
    expect(WidgetTheme.themes.first, 'classic');
    expect(WidgetTheme.themes, containsAll(['minimal', 'glass', 'neobrutal', 'midnight', 'space']));
  });

  test('falls back to classic / light / brand', () {
    expect(WidgetTheme.normalizeTheme('NOPE'), 'classic');
    expect(WidgetTheme.normalizeTheme(' Minimal '), 'minimal');
    expect(WidgetTheme.normalizeAppearance('purple'), 'light');
    expect(WidgetTheme.normalizeAppearance('AUTO'), 'auto');
    expect(WidgetTheme.normalizeThemeColors('theme'), 'theme');
    expect(WidgetTheme.normalizeThemeColors(null), 'brand');
  });

  test('resolves the scheme', () {
    expect(WidgetTheme.resolveScheme('midnight', 'light', false), 'dark');
    expect(WidgetTheme.resolveScheme('classic', 'dark', false), 'dark');
    expect(WidgetTheme.resolveScheme('classic', 'auto', true), 'dark');
    expect(WidgetTheme.resolveScheme('classic', 'auto', false), 'light');
    expect(WidgetTheme.resolveScheme('minimal', 'light', true), 'light');
  });

  test('changes nothing for classic in light', () {
    final t = WidgetTheme.resolve({}, false);
    expect(t.id, 'classic');
    expect(t.tokens, isNull);
    expect(t.shape, isNull);
  });

  test('repaints only the surfaces for classic in dark', () {
    final t = WidgetTheme.resolve({'themeAppearance': 'dark'}, false);
    expect(t.tokens?.bg, '#14161c');
    expect(t.tokens?.ink, '#f1f3f7');
    expect(t.shape, isNull);
    expect(t.isDark, isTrue);
  });

  test('gives every theme and scheme concrete colours', () {
    for (final id in WidgetTheme.themes) {
      for (final appearance in ['light', 'dark']) {
        final t = WidgetTheme.resolve({'widgetTheme': id, 'themeAppearance': appearance, 'headerBgColor': '#0F766E'}, false);
        for (final v in t.tokens?.all ?? const <String>[]) {
          expect(_hex.hasMatch(v), isTrue, reason: '$id $appearance $v');
        }
      }
    }
  });

  test('brings the theme shape', () {
    final minimal = WidgetTheme.resolve({'widgetTheme': 'minimal'}, false).shape!;
    expect(minimal.rBubble, 14);
    expect(minimal.rCtl, 10);
    expect(minimal.rField, 12);
    expect(WidgetTheme.resolve({'widgetTheme': 'neobrutal'}, false).shape!.bubbleBorder, const BubbleBorder(2, '#000000'));
  });

  test('tints brand-mixed surfaces with the bot colour', () {
    final red = WidgetTheme.resolve({'widgetTheme': 'clay', 'headerBgColor': '#ff0000'}, false).tokens!.bg;
    final blue = WidgetTheme.resolve({'widgetTheme': 'clay', 'headerBgColor': '#0000ff'}, false).tokens!.bg;
    expect(_hex.hasMatch(red), isTrue);
    expect(red, isNot(blue));
  });

  test('makes glass opaque', () {
    expect(WidgetTheme.resolve({'widgetTheme': 'glass'}, false).tokens!.bg, '#fafbfd');
  });

  test('swaps in the palette only for theme colours', () {
    final owner = <String, dynamic>{'widgetTheme': 'minimal', 'headerBgColor': '#0F766E', 'chatBgType': 'pattern', 'logo': 'x'};
    expect(identical(WidgetTheme.withThemePalette(owner, false), owner), isTrue);
    final p = WidgetTheme.withThemePalette({...owner, 'themeColors': 'theme'}, false);
    expect(p['headerBgColor'], '#09090b');
    expect(p['userMsgColor'], '#2563eb');
    expect(p['chatBgType'], 'solid');
    expect(p['chatBgColor'], '#ffffff');
    expect(p['logo'], 'x');
    expect(WidgetTheme.withThemePalette({...owner, 'themeColors': 'theme', 'themeAppearance': 'dark'}, false)['headerBgColor'], '#18181b');
  });

  test('treats only plain white as the default background', () {
    expect(WidgetTheme.ownsChatBackground({}), isFalse);
    expect(WidgetTheme.ownsChatBackground({'chatBgColor': '#ffffff'}), isFalse);
    expect(WidgetTheme.ownsChatBackground({'chatBgColor': '#f8fafc'}), isTrue);
    expect(WidgetTheme.ownsChatBackground({'chatBgType': 'gradient'}), isTrue);
  });

  test('takes theme radii unless the owner set their own', () {
    final theme = WidgetTheme.resolve({'widgetTheme': 'minimal'}, false);
    final c = Customizations.resolve({'bubbleBorderRadius': 10, 'optionBubbleBorderRadius': 10}, theme: theme);
    expect(c.botBubble, const BubbleCorners.all(14));
    expect(c.optionRadius, 10);
    expect(c.fieldRadius, 12);
    final own = Customizations.resolve({'bubbleBorderRadius': 4, 'optionBubbleBorderRadius': 20}, theme: theme);
    expect(own.botBubble.bottomLeft, 4);
    expect(own.optionRadius, 20);
  });

  test('keeps classic without a theme', () {
    final c = Customizations.resolve({'optionBubbleBorderRadius': 10});
    expect(c.botBubble.bottomLeft, 6);
    expect(c.fieldRadius, 25);
    expect(c.surface, isNull);
    expect(c.bubbleBorder, isNull);
  });

  test('paints the theme surface unless the owner has a background', () {
    final theme = WidgetTheme.resolve({'widgetTheme': 'midnight'}, false);
    expect(Customizations.resolve({}, theme: theme).surface, theme.tokens!.bg);
    expect(Customizations.resolve({'chatBgType': 'gradient'}, theme: theme).surface, isNull);
  });

  test('uses the palette send colours', () {
    final raw = WidgetTheme.withThemePalette({'widgetTheme': 'aurora', 'themeColors': 'theme', 'themeAppearance': 'dark'}, false);
    final c = Customizations.resolve(raw);
    expect(c.accent, '#a78bfa');
    expect(c.accentInk, '#0c0d18');
    expect(Customizations.resolve({'headerBgColor': '#0F766E'}).accentInk, isNull);
  });
}
