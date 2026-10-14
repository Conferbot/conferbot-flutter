/// The chat background as the web widget draws it (conferbot-widget
/// ts/chatBackground/chatBackground.ts): solid, gradient (linear, radial,
/// mesh, blur), image with an optional mask, or one of 13 pattern tiles.
/// Pure: widgets/chat_background.dart draws it.
library;

import 'dart:math' as math;

sealed class ChatBackground {
  final String color;
  const ChatBackground(this.color);
}

class SolidBackground extends ChatBackground {
  const SolidBackground(super.color);
  @override
  bool operator ==(Object other) => other is SolidBackground && other.color == color;
  @override
  int get hashCode => color.hashCode;
}

class GradientBackground extends ChatBackground {
  final List<String> stops;
  final int angle;
  final String style;
  const GradientBackground(super.color, this.stops, this.angle, this.style);
}

class ImageBackground extends ChatBackground {
  final String url;
  final String? maskColor;
  final double maskAlpha;
  const ImageBackground(super.color, this.url, this.maskColor, this.maskAlpha);
}

class PatternBackground extends ChatBackground {
  final String pattern;
  final String ink;
  final double alpha;
  const PatternBackground(super.color, this.pattern, this.ink, this.alpha);
}

/// One shape of a tile: a path, circle or rect, filled or stroked, maybe rotated about a point.
class PatternShape {
  final String t;
  final bool fill;
  final double sw;
  final String? d;
  final double cx, cy, r, x, y, w, h, rx;
  final List<double>? rot;
  const PatternShape({required this.t, required this.fill, this.sw = 1.2, this.d, this.cx = 0, this.cy = 0, this.r = 0, this.x = 0, this.y = 0, this.w = 0, this.h = 0, this.rx = 0, this.rot});
}

class PatternTile {
  final double w;
  final double h;
  final bool noise;
  final List<PatternShape> shapes;
  const PatternTile(this.w, this.h, {this.noise = false, required this.shapes});
}

/// The web's tiles (generated from chatBackground.ts PATTERNS).
const Map<String, PatternTile> chatPatterns = {
  'dots': PatternTile(18.0, 18.0, noise: false, shapes: [
      PatternShape(t: 'circle', fill: true, cx: 9.0, cy: 9.0, r: 1.6)
    ]),
  'grid': PatternTile(24.0, 24.0, noise: false, shapes: [
      PatternShape(t: 'path', fill: false, sw: 1.0, d: 'M24 .5H.5V24')
    ]),
  'diagonal': PatternTile(14.0, 14.0, noise: false, shapes: [
      PatternShape(t: 'path', fill: false, sw: 1.0, d: 'M-3.5 3.5l7-7M0 14L14 0M10.5 17.5l7-7')
    ]),
  'waves': PatternTile(40.0, 16.0, noise: false, shapes: [
      PatternShape(t: 'path', fill: false, sw: 1.2, d: 'M0 8q5-6 10 0t10 0 10 0 10 0')
    ]),
  'topography': PatternTile(220.0, 220.0, noise: false, shapes: [
      PatternShape(t: 'path', fill: false, sw: 1.0, d: 'M60 40c30-18 72-10 84 18s-8 58-40 64-70-6-74-36 6-32 30-46z'),
      PatternShape(t: 'path', fill: false, sw: 1.0, d: 'M70 58c20-10 48-4 56 14s-6 38-28 40-46-4-48-24 4-20 20-30z'),
      PatternShape(t: 'path', fill: false, sw: 1.0, d: 'M84 74c10-4 24 0 26 8s-4 16-14 16-20-2-20-10 2-10 8-14z'),
      PatternShape(t: 'path', fill: false, sw: 1.0, d: 'M150 150c26-6 58 6 62 30s-22 40-52 38-50-14-48-36 12-26 38-32z'),
      PatternShape(t: 'path', fill: false, sw: 1.0, d: 'M158 166c16-2 34 4 36 18s-14 24-30 22-30-8-28-20 8-18 22-20z'),
      PatternShape(t: 'path', fill: false, sw: 1.0, d: 'M-10 170c20-14 50-10 58 8s-8 40-32 44'),
      PatternShape(t: 'path', fill: false, sw: 1.0, d: 'M210 30c-6 20-2 44 16 52'),
      PatternShape(t: 'path', fill: false, sw: 1.0, d: 'M0 110c30 6 44 30 36 60M220 110c-30-4-50 10-56 34')
    ]),
  'confetti': PatternTile(90.0, 90.0, noise: false, shapes: [
      PatternShape(t: 'rect', fill: true, x: 10.0, y: 12.0, w: 7.0, h: 3.0, rx: 1.5, rot: [30.0, 13.0, 13.0]),
      PatternShape(t: 'rect', fill: true, x: 58.0, y: 8.0, w: 7.0, h: 3.0, rx: 1.5, rot: [-40.0, 61.0, 9.0]),
      PatternShape(t: 'rect', fill: true, x: 40.0, y: 52.0, w: 7.0, h: 3.0, rx: 1.5, rot: [70.0, 43.0, 53.0]),
      PatternShape(t: 'rect', fill: true, x: 72.0, y: 66.0, w: 7.0, h: 3.0, rx: 1.5, rot: [10.0, 75.0, 67.0]),
      PatternShape(t: 'circle', fill: true, cx: 34.0, cy: 26.0, r: 2.2),
      PatternShape(t: 'circle', fill: true, cx: 80.0, cy: 34.0, r: 1.6),
      PatternShape(t: 'circle', fill: true, cx: 16.0, cy: 70.0, r: 2.0),
      PatternShape(t: 'circle', fill: true, cx: 56.0, cy: 82.0, r: 1.4),
      PatternShape(t: 'path', fill: true, d: 'M24 44l3 5h-6z'),
      PatternShape(t: 'path', fill: true, d: 'M68 44l3 5h-6z', rot: [40.0, 68.0, 46.0])
    ]),
  'doodles': PatternTile(128.0, 128.0, noise: false, shapes: [
      PatternShape(t: 'path', fill: false, sw: 1.4, d: 'M14 14h26a5 5 0 0 1 5 5v12a5 5 0 0 1-5 5H26l-7 6v-6h-5a5 5 0 0 1-5-5V19a5 5 0 0 1 5-5z'),
      PatternShape(t: 'path', fill: false, sw: 1.4, d: 'M19 23h16M19 28h10'),
      PatternShape(t: 'path', fill: false, sw: 1.4, d: 'M92 26c-3-5-11-4-11 3 0 6 11 12 11 12s11-6 11-12c0-7-8-8-11-3z'),
      PatternShape(t: 'path', fill: false, sw: 1.4, d: 'M30 78l3 7 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1z'),
      PatternShape(t: 'circle', fill: false, sw: 1.4, cx: 96.0, cy: 92.0, r: 11.0),
      PatternShape(t: 'path', fill: false, sw: 1.4, d: 'M91 95q5 5 10 0'),
      PatternShape(t: 'path', fill: false, sw: 1.4, d: 'M92 88v1M100 88v1'),
      PatternShape(t: 'path', fill: false, sw: 1.4, d: 'M58 60l20-8-6 20-5-7zM67 65l11-13'),
      PatternShape(t: 'path', fill: false, sw: 1.4, d: 'M60 110h.01M112 60h.01M8 58h.01M70 12h.01')
    ]),
  'paper': PatternTile(180.0, 180.0, noise: true, shapes: [
      
    ]),
  'hexagons': PatternTile(24.0, 42.0, noise: false, shapes: [
      PatternShape(t: 'path', fill: false, sw: 1.0, d: 'M12 0l12 7v14l-12 7-12-7V7zM12 28v14')
    ]),
  'rings': PatternTile(36.0, 36.0, noise: false, shapes: [
      PatternShape(t: 'circle', fill: false, sw: 1.1, cx: 18.0, cy: 18.0, r: 9.0)
    ]),
  'plus': PatternTile(26.0, 26.0, noise: false, shapes: [
      PatternShape(t: 'path', fill: false, sw: 1.4, d: 'M13 9v8M9 13h8')
    ]),
  'zigzag': PatternTile(24.0, 14.0, noise: false, shapes: [
      PatternShape(t: 'path', fill: false, sw: 1.2, d: 'M0 10l6-6 6 6 6-6 6 6')
    ]),
  'sparkles': PatternTile(72.0, 72.0, noise: false, shapes: [
      PatternShape(t: 'path', fill: true, d: 'M18 8c1 6 3 8 9 9-6 1-8 3-9 9-1-6-3-8-9-9 6-1 8-3 9-9z'),
      PatternShape(t: 'path', fill: true, d: 'M54 42c.7 4 2 5.3 6 6-4 .7-5.3 2-6 6-.7-4-2-5.3-6-6 4-.7 5.3-2 6-6z'),
      PatternShape(t: 'circle', fill: true, cx: 52.0, cy: 14.0, r: 1.4),
      PatternShape(t: 'circle', fill: true, cx: 16.0, cy: 56.0, r: 1.6)
    ]),
};

class ChatBackgrounds {
  ChatBackgrounds._();

  static const gradientStyles = ['linear', 'radial', 'mesh', 'blur'];
  static final _color = RegExp(r'^(#[0-9a-f]{3,8}|rgba?\([\d\s.,%/]+\)|hsla?\([\d\s.,%/a-z]+\)|[a-z]{3,20})$', caseSensitive: false);

  /// A colour we can use, else the fallback (as the web's safeColor).
  static String safeColor(dynamic value, String fallback) {
    final v = value is String ? value.trim() : '';
    return v.isNotEmpty && _color.hasMatch(v) && !RegExp('url|expression', caseSensitive: false).hasMatch(v) ? v : fallback;
  }

  static double _clamp(dynamic value, double min, double max, double fallback) {
    final n = value is num ? value.toDouble() : (value is String ? double.tryParse(value.trim()) : null);
    if (n == null || !n.isFinite) return fallback;
    return n.clamp(min, max).toDouble();
  }

  /// The gradient's colours: the saved stops (2-4), else the legacy two.
  static List<String> gradientStops(Map<String, dynamic> c) {
    final raw = c['chatBgGradientStops'] is List ? c['chatBgGradientStops'] as List : const [];
    final stops = raw.map((s) => safeColor(s, '')).where((s) => s.isNotEmpty).take(4).toList();
    return stops.length >= 2 ? stops : [safeColor(c['gradientBgOne'], '#fffcf1'), safeColor(c['gradientBgTwo'], '#1b55f3')];
  }

  static ChatBackground resolve(Map<String, dynamic>? raw) {
    final c = raw ?? const <String, dynamic>{};
    final type = (c['chatBgType'] is String ? c['chatBgType'] as String : 'solid').toLowerCase();
    final color = safeColor(c['chatBgColor'], '#ffffff');
    switch (type) {
      case 'gradient':
        return GradientBackground(
          color,
          gradientStops(c),
          _clamp(c['chatBgGradientAngle'], 0, 360, 180).round(),
          gradientStyles.contains(c['chatBgGradientStyle']) ? c['chatBgGradientStyle'] as String : 'linear',
        );
      case 'pattern':
        return PatternBackground(
          color,
          chatPatterns.containsKey(c['chatBgPattern']) ? c['chatBgPattern'] as String : 'dots',
          safeColor(c['chatBgPatternColor'], '#0f172a'),
          _clamp(c['chatBgPatternOpacity'], 0, 100, 12) / 100,
        );
      case 'image':
        final src = c['chatBgImage'] ?? c['chatBgImg'];
        final url = src is String ? src.trim() : '';
        if (url.isEmpty || url.toLowerCase().startsWith('javascript:')) return SolidBackground(color);
        final alpha = _clamp(c['chatBgMaskOpacity'], 0, 90, 0) / 100;
        return ImageBackground(color, url, alpha > 0 ? safeColor(c['chatBgMaskColor'], '#000000') : null, alpha);
      default:
        return SolidBackground(color);
    }
  }

  /// A point on the rim at deg (0 = top, clockwise), as a fraction of the box.
  static (double, double) rimPoint(double deg, [double reach = 50]) {
    final r = (deg - 90) * math.pi / 180;
    return ((50 + reach * math.cos(r)).round() / 100, (50 + reach * math.sin(r)).round() / 100);
  }

  /// Seeded speckles for the paper tile (the web uses an SVG noise filter): x, y, r, alpha factor.
  static final List<List<double>> paperSpeckles = () {
    var seed = 7;
    double rand() {
      seed = (seed * 16807) % 2147483647;
      return seed / 2147483647;
    }
    return List.generate(260, (_) => [rand() * 180, rand() * 180, 0.4 + rand() * 0.7, 0.3 + rand() * 0.7]);
  }();
}
