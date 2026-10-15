/// The widget theme as the web widget applies it (conferbot-widget
/// src/ts/theme/themeTokens.ts, base.css and the theme sheets):
///
///   widgetTheme      one of 27 themes ("classic" when unset or unknown)
///   themeAppearance  light | dark | auto (auto follows the phone)
///   themeColors      brand (the owner's colours) | theme (the theme's palette)
///
/// Classic in light is the widget as it always was: no tokens, no shape.
/// Classic in dark repaints the surfaces only. Every other theme brings its
/// surfaces, text colours and shape; an owner setting (bubble radius, option
/// radius, a chat background of their own) still wins over the theme. Pure.
library;

import 'dart:math' as math;

import 'widget_themes_data.dart';

/// Surfaces and text, every value a six-digit hex (rgba flattened onto the surface).
class ThemeTokens {
  /// Panel, conversation, composer and footer.
  final String bg;

  /// Canvas: home screen, help centre.
  final String bg2;

  /// Cards, menus, chips.
  final String card;

  /// Quiet fills: search field, tags.
  final String card2;

  /// The composer's field.
  final String field;
  final String menu;
  final String ink;
  final String text;
  final String muted;
  final String faint;
  final String line;
  final String line2;

  const ThemeTokens({
    required this.bg,
    required this.bg2,
    required this.card,
    required this.card2,
    required this.field,
    required this.menu,
    required this.ink,
    required this.text,
    required this.muted,
    required this.faint,
    required this.line,
    required this.line2,
  });

  List<String> get all => [bg, bg2, card, card2, field, menu, ink, text, muted, faint, line, line2];
}

class BubbleBorder {
  final double width;
  final String color;

  const BubbleBorder(this.width, this.color);

  @override
  bool operator ==(Object other) => other is BubbleBorder && other.width == width && other.color == color;

  @override
  int get hashCode => Object.hash(width, color);
}

class ThemeShape {
  final double rBubble;
  final double rTail;

  /// Option buttons (999 is a pill).
  final double rCtl;

  /// The composer's field.
  final double rField;
  final double rCard;

  /// An outline round every bubble (cartoon, neo-brutal, sketch...), or null.
  final BubbleBorder? bubbleBorder;
  final int displayWeight;

  const ThemeShape({
    required this.rBubble,
    required this.rTail,
    required this.rCtl,
    required this.rField,
    required this.rCard,
    this.bubbleBorder,
    required this.displayWeight,
  });
}

class ResolvedWidgetTheme {
  final String id;
  final String label;
  final String appearance;
  final String scheme;
  final String colors;

  /// Null for classic in light: nothing changes.
  final ThemeTokens? tokens;

  /// Null for classic: radii stay the widget's.
  final ThemeShape? shape;

  /// The theme's font family (a Google Fonts name) and what it covers.
  final String? font;
  final String? fontRole;

  const ResolvedWidgetTheme({
    this.id = 'classic',
    this.label = 'Classic',
    this.appearance = 'light',
    this.scheme = 'light',
    this.colors = 'brand',
    this.tokens,
    this.shape,
    this.font,
    this.fontRole,
  });

  bool get isDark => scheme == 'dark';
}

/// r, g, b (0-255) and alpha (0-1).
class Rgba {
  final double r, g, b, a;
  const Rgba(this.r, this.g, this.b, [this.a = 1]);
  Rgba withAlpha(double alpha) => Rgba(r, g, b, alpha);
}

class WidgetTheme {
  WidgetTheme._();

  static List<String> get themes => widgetThemesData.keys.toList();

  static String _lower(dynamic v) => v is String ? v.trim().toLowerCase() : '';

  static String normalizeTheme(dynamic v) => widgetThemesData.containsKey(_lower(v)) ? _lower(v) : 'classic';

  static String normalizeAppearance(dynamic v) {
    final s = _lower(v);
    return s == 'dark' || s == 'auto' ? s : 'light';
  }

  static String normalizeThemeColors(dynamic v) => _lower(v) == 'theme' ? 'theme' : 'brand';

  /// Light or dark: always-dark themes, then the appearance (auto: the phone's setting).
  static String resolveScheme(String theme, String appearance, bool prefersDark) {
    if (widgetThemesData[theme]?.alwaysDark == true) return 'dark';
    if (appearance == 'dark') return 'dark';
    if (appearance == 'auto') return prefersDark ? 'dark' : 'light';
    return 'light';
  }

  /// "#abc", "#aabbcc", "#aabbccdd", "rgb(1,2,3)", "rgba(1,2,3,.5)", white, black.
  static Rgba? parseColor(dynamic value) {
    final v = _lower(value);
    if (v == 'white') return const Rgba(255, 255, 255);
    if (v == 'black') return const Rgba(0, 0, 0);
    var m = RegExp(r'^#([0-9a-f]{3,8})$').firstMatch(v);
    if (m != null) {
      var h = m.group(1)!;
      if (h.length == 3 || h.length == 4) h = h.split('').map((c) => '$c$c').join();
      if (h.length != 6 && h.length != 8) return null;
      double byte(int i) => int.parse(h.substring(i, i + 2), radix: 16).toDouble();
      return Rgba(byte(0), byte(2), byte(4), h.length == 8 ? byte(6) / 255 : 1);
    }
    m = RegExp(r'^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)(?:[\s,/]+([\d.]+))?\s*\)$').firstMatch(v);
    if (m != null) {
      double c(String s) => (double.tryParse(s) ?? 0).clamp(0, 255).roundToDouble();
      final a = m.group(4) == null ? 1.0 : (double.tryParse(m.group(4)!) ?? 1).clamp(0, 1).toDouble();
      return Rgba(c(m.group(1)!), c(m.group(2)!), c(m.group(3)!), a);
    }
    return null;
  }

  static String _hex(Rgba c) =>
      '#${[c.r, c.g, c.b].map((n) => n.round().clamp(0, 255).toRadixString(16).padLeft(2, '0')).join()}';

  static Rgba _mix(Rgba a, Rgba b, double t) =>
      Rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);

  /// A colour with alpha laid over an opaque one.
  static Rgba _over(Rgba top, Rgba under) => _mix(under, top.withAlpha(1), top.a);

  static double _channel(double c) {
    final s = c / 255;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  static double _luminance(Rgba c) => 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

  static double _contrast(Rgba a, Rgba b) {
    final x = _luminance(a), y = _luminance(b);
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
  }

  /// The brand lightened until it reads on a dark surface (4.5:1 on #14161c), as the web's accentOnDark.
  static Rgba accentOnDark(Rgba brand) {
    const surface = Rgba(20, 22, 28);
    var c = brand;
    for (var t = 0.0; t <= 1.0001 && _contrast(c, surface) < 4.5; t += 0.05) {
      final m = _mix(brand, const Rgba(255, 255, 255), t);
      c = Rgba(m.r.roundToDouble(), m.g.roundToDouble(), m.b.roundToDouble());
    }
    return c;
  }

  /// A token value: hex / rgb(a), "mix:N:<colour>" or "accent:<alpha>".
  static Rgba? _tokenColor(String? value, Rgba brand) {
    if (value == null) return null;
    var m = RegExp(r'^mix:([\d.]+):(.+)$').firstMatch(value);
    if (m != null) {
      final base = parseColor(m.group(2));
      return base == null ? null : _mix(base, brand, double.parse(m.group(1)!) / 100);
    }
    m = RegExp(r'^accent:([\d.]+)$').firstMatch(value);
    if (m != null) return accentOnDark(brand).withAlpha(double.parse(m.group(1)!));
    return parseColor(value);
  }

  /// The owner's chat background counts as theirs (the theme leaves it
  /// alone) unless it is the default plain white; gradients, patterns and
  /// images always are.
  static bool ownsChatBackground(Map<String, dynamic>? c) {
    final type = _lower(c?['chatBgType']).isEmpty ? 'solid' : _lower(c?['chatBgType']);
    if (type == 'image' || type == 'gradient' || type == 'pattern') return true;
    final color = parseColor(c?['chatBgColor']);
    if (color == null) return false;
    return !(color.r >= 250 && color.g >= 250 && color.b >= 250);
  }

  static Map<String, String>? _palette(String theme, String colors, String scheme) {
    if (theme == 'classic' || colors != 'theme') return null;
    final d = widgetThemesData[theme];
    if (d == null) return null;
    return (scheme == 'dark' ? d.paletteDark : d.paletteLight) ?? d.paletteLight;
  }

  /// The customizations with the theme's palette in place of the owner's
  /// colours (themeColors "theme", any theme but classic); otherwise the same
  /// map back. The chat background goes back to plain white, which the theme
  /// paints with its own surface. Logo, avatar and texts stay the owner's.
  static Map<String, dynamic> withThemePalette(Map<String, dynamic> c, bool prefersDark) {
    final theme = normalizeTheme(c['widgetTheme']);
    final scheme = resolveScheme(theme, normalizeAppearance(c['themeAppearance']), prefersDark);
    final p = _palette(theme, normalizeThemeColors(c['themeColors']), scheme);
    if (p == null) return c;
    return {
      ...c,
      'headerBgColor': p['headerBg'],
      'headerTextColor': p['headerText'],
      'botMsgColor': p['botBg'],
      'botTextColor': p['botText'],
      'userMsgColor': p['userBg'],
      'userTextColor': p['userText'],
      'optionBubbleMsgColor': p['optionBg'],
      'optionBubbleTextColor': p['optionText'],
      'chatBgType': 'solid',
      'chatBgColor': '#ffffff',
      'widgetIconThemeType': p['launcher2'] != null ? 'Gradient' : 'Solid',
      'widgetIconBgColor': p['launcher'],
      'widgetGradientBgOne': p['launcher'],
      'widgetGradientBgTwo': p['launcher2'] ?? p['launcher'],
      'themeAccent': p['accent'],
      'themeOnAccent': p['onAccent'],
    };
  }

  /// The theme in force for these customizations, with every colour concrete.
  static ResolvedWidgetTheme resolve(Map<String, dynamic>? c, bool prefersDark) {
    final theme = normalizeTheme(c?['widgetTheme']);
    final appearance = normalizeAppearance(c?['themeAppearance']);
    final colors = normalizeThemeColors(c?['themeColors']);
    final scheme = resolveScheme(theme, appearance, prefersDark);
    final data = widgetThemesData[theme]!;
    final p = _palette(theme, colors, scheme);
    final brand = parseColor(p?['brand']) ?? parseColor(c?['headerBgColor']) ?? parseColor(c?['botMsgColor']) ?? const Rgba(27, 85, 243);

    final raw = theme == 'classic' && scheme == 'light' ? null : (scheme == 'dark' ? data.dark : (data.light ?? data.dark));
    ThemeTokens? tokens;
    if (raw != null) {
      final fallback = scheme == 'dark' ? const Rgba(20, 22, 28) : const Rgba(255, 255, 255);
      final surface = _over(_tokenColor(raw['bg'], brand) ?? fallback, fallback);
      String flat(String k) => _hex(_over(_tokenColor(raw[k], brand) ?? surface, surface));
      tokens = ThemeTokens(
        bg: _hex(surface),
        bg2: flat('bg2'),
        card: flat('card'),
        card2: flat('card2'),
        field: flat('field'),
        menu: flat('menu'),
        ink: flat('ink'),
        text: flat('text'),
        muted: flat('muted'),
        faint: flat('faint'),
        line: flat('line'),
        line2: flat('line2'),
      );
    }

    ThemeShape? shape;
    final s = data.shape;
    if (s != null) {
      BubbleBorder? border;
      final b = s.bubbleBorderWidth > 0 ? parseColor(s.bubbleBorderColor) : null;
      if (b != null) {
        final under = tokens != null ? parseColor(tokens.bg)! : const Rgba(255, 255, 255);
        border = BubbleBorder(s.bubbleBorderWidth, _hex(_over(b, under)));
      }
      shape = ThemeShape(
        rBubble: s.rBubble ?? 18,
        rTail: s.rTail ?? 6,
        rCtl: s.rCtl ?? 12,
        rField: s.rField ?? 22,
        rCard: s.rCard ?? 16,
        bubbleBorder: border,
        displayWeight: s.displayWeight,
      );
    }

    return ResolvedWidgetTheme(
      id: theme,
      label: data.label,
      appearance: appearance,
      scheme: scheme,
      colors: colors,
      tokens: tokens,
      shape: shape,
      font: data.font,
      fontRole: data.fontRole,
    );
  }
}
