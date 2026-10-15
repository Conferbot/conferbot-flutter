/// The closed chat button as the web widget draws it on a phone
/// (conferbot-widget templates/shared.ts generateWidgetIcon,
/// ts/launcher/launcherStyle.ts, launcherShape.ts, layout/ownerLayout.ts and
/// the phone rules in css/liveChat/responsive*.css). Pure: the floating
/// launcher reads the result.
library;

import 'dart:math' as math;

import 'customizations.dart';
import 'widget_theme.dart';

class ResolvedLauncher {
  final String position;

  /// The button's height (and width, except for tab, peek and the label pill).
  final double size;

  /// Width of the button: the size, or the tab's narrower width.
  final double width;

  /// Distance from the bottom and from the screen side (0 for tab and peek).
  final double bottom;
  final double side;

  /// Peek: how far the tab is tucked off screen.
  final double tucked;
  final String shape;
  final BubbleCorners corners;

  /// The two stops of a left-to-right gradient, or null for a solid launcher.
  final List<String>? gradient;

  /// The launcher's own colour as one solid (a gradient's first stop).
  final String solid;

  /// Icon ink: dark on a light launcher, else white.
  final String ink;

  /// The soft glow round the button: the header colour.
  final String glow;

  /// The style drawn: an uploaded image or a missing avatar fall back to the icon.
  final String style;
  final String label;
  final String? avatar;
  final String? imageUrl;
  final String? iconId;

  /// Icon size inside the button.
  final double glyph;
  final String animation;

  /// The greeting next to the button, when the owner turned it on.
  final String? ctaText;

  const ResolvedLauncher({
    required this.position,
    required this.size,
    required this.width,
    required this.bottom,
    required this.side,
    required this.tucked,
    required this.shape,
    required this.corners,
    required this.gradient,
    required this.solid,
    required this.ink,
    required this.glow,
    required this.style,
    required this.label,
    required this.avatar,
    required this.imageUrl,
    required this.iconId,
    required this.glyph,
    required this.animation,
    required this.ctaText,
  });
}

class Launcher {
  Launcher._();

  static const shapes = ['circle', 'squircle', 'bubble', 'tab', 'peek'];
  static const styles = ['icon', 'label', 'avatar', 'mascot'];
  static const labelMax = 24;
  static const defaultLabel = 'Chat with us';

  /// The web folds the label back to the round button at this width and under.
  static const labelMinWidth = 480.0;

  static String _str(dynamic v) => v is String ? v.trim() : '';

  static double? _num(dynamic v) {
    if (v == null || v is bool) return null;
    if (v is num) return v.isFinite ? v.toDouble() : null;
    if (v is String && v.trim().isNotEmpty) return double.tryParse(v.trim());
    return null;
  }

  /// A number in [lo, hi] (clamped, rounded), or null when unset / junk (ownerLayout ownerRange).
  static double? _range(dynamic v, double lo, double hi) {
    final n = _num(v);
    return n == null ? null : n.roundToDouble().clamp(lo, hi).toDouble();
  }

  /// The shape: unset is the speech bubble, unless the owner rounded the button (a radius under 50) themselves.
  static String normalizeShape(dynamic value, dynamic radius) {
    if (value is String && shapes.contains(value)) return value;
    final r = _num(radius);
    return r != null && r < 50 ? 'circle' : 'bubble';
  }

  static String normalizeLabel(dynamic value) {
    if (value is! String) return '';
    final s = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.length > labelMax ? s.substring(0, labelMax) : s;
  }

  static double _channel(double c) {
    final s = c / 255;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  static ResolvedLauncher resolve(Map<String, dynamic>? raw, {double screenWidth = 0}) {
    final c = raw ?? const <String, dynamic>{};
    final position = c['widgetPosition'] == 'left' ? 'left' : 'right';
    // Phones: the owner's phone size and offsets, else the launcher's size at 16px from the edges.
    final widgetSize = _num(c['widgetSize']);
    final size = _range(c['mobileWidgetSize'], 36, 80) ?? (widgetSize != null && widgetSize > 0 ? widgetSize : 50.0);
    final bottom = _range(c['mobileOffsetBottom'], 0, 400) ?? 16.0;
    final sideOffset = _range(c['mobileOffsetSide'], 0, 400) ?? 16.0;
    final shape = normalizeShape(c['launcherShape'], c['widgetBorderRadius']);

    final isGradient = c['widgetIconThemeType'] == 'Gradient' && _str(c['widgetGradientBgOne']).isNotEmpty && _str(c['widgetGradientBgTwo']).isNotEmpty;
    final solidRaw = isGradient ? c['widgetGradientBgOne'] : c['widgetIconBgColor'];
    final solid = WidgetTheme.parseColor(solidRaw) != null
        ? _str(solidRaw)
        : (_str(c['headerBgColor']).isEmpty ? '#1b55f3' : _str(c['headerBgColor']));
    final rgb = WidgetTheme.parseColor(solid);
    final lum = rgb == null ? 0.0 : 0.2126 * _channel(rgb.r) + 0.7152 * _channel(rgb.g) + 0.0722 * _channel(rgb.b);
    final ink = lum > 0.6 ? '#111827' : '#ffffff';

    final imageUrl = c['widgetIconType'] == 'Image' && _str(c['widgetIconImage']).isNotEmpty ? _str(c['widgetIconImage']) : null;
    final avatarRaw = _str(c['avatar']).isNotEmpty ? _str(c['avatar']) : _str(c['logo']);
    final avatar = avatarRaw.isEmpty ? null : avatarRaw;
    var style = styles.contains(c['launcherStyle']) ? c['launcherStyle'] as String : 'icon';
    if (imageUrl != null || (style == 'avatar' && avatar == null)) style = 'icon';
    // The label folds back to the round button on phones, as on the web.
    if (style == 'label' && !(screenWidth > labelMinWidth)) style = 'icon';

    final half = (size / 2).roundToDouble();
    var width = size;
    var side = sideOffset;
    var tucked = 0.0;
    BubbleCorners corners;
    if (shape == 'squircle') {
      corners = BubbleCorners.all((size * 0.3).roundToDouble());
    } else if (shape == 'bubble') {
      // The corner nearest the screen corner pinched into a tail.
      final tail = math.max(4.0, (size * 0.12).roundToDouble());
      corners = position == 'left' ? BubbleCorners(half, half, half, tail) : BubbleCorners(half, half, tail, half);
    } else if (shape == 'tab' || shape == 'peek') {
      // Flush to the screen edge, rounded on its inner side.
      width = (size * 0.82).roundToDouble();
      side = 0;
      final round = (size * 0.3).roundToDouble();
      if (shape == 'peek') tucked = (width * 0.42).roundToDouble();
      corners = position == 'left' ? BubbleCorners(0, round, round, 0) : BubbleCorners(round, 0, 0, round);
    } else {
      // The round button: the owner's corner radius, capped at half the size.
      final r = _num(c['widgetBorderRadius']);
      corners = BubbleCorners.all(r == null ? half : r.clamp(0, half).toDouble());
    }

    final label = normalizeLabel(c['launcherLabel']);
    return ResolvedLauncher(
      position: position,
      size: size,
      width: width,
      bottom: bottom,
      side: side,
      tucked: tucked,
      shape: shape,
      corners: corners,
      gradient: isGradient ? [_str(c['widgetGradientBgOne']), _str(c['widgetGradientBgTwo'])] : null,
      solid: solid,
      ink: ink,
      glow: _str(c['headerBgColor']).isEmpty ? solid : _str(c['headerBgColor']),
      style: style,
      label: label.isEmpty ? defaultLabel : label,
      avatar: avatar,
      imageUrl: imageUrl,
      iconId: _str(c['widgetIconSVG']).isEmpty ? null : _str(c['widgetIconSVG']),
      glyph: (size * (shape == 'tab' || shape == 'peek' ? 0.5 : 0.6)).roundToDouble(),
      animation: c['launcherAnimation'] == 'lively' || c['launcherAnimation'] == 'off' ? c['launcherAnimation'] as String : 'subtle',
      // Only when the owner turned the greeting on (templates/shared.ts: no chatIconCta, no bubble).
      ctaText: c['chatIconCta'] == true && _str(c['chatIconCtaText']).isNotEmpty ? _str(c['chatIconCtaText']) : null,
    );
  }
}
