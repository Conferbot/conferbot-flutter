import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/customization/chat_background.dart';
import '../core/customization/svg_path.dart';

/// A CSS colour from the bot's settings (hex, short hex, rgb[a]) as a Flutter colour.
Color cssColor(String value, [Color fallback = Colors.white]) {
  var h = value.trim();
  final rgb = RegExp(r'rgba?\((\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?').firstMatch(h);
  if (rgb != null) {
    return Color.fromRGBO(int.parse(rgb[1]!), int.parse(rgb[2]!), int.parse(rgb[3]!), double.tryParse(rgb[4] ?? '1') ?? 1);
  }
  if (!h.startsWith('#')) return fallback;
  h = h.substring(1);
  if (h.length == 3 || h.length == 4) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'ff$h';
  if (h.length == 8 && value.trim().length == 9) h = h.substring(6) + h.substring(0, 6); // #rrggbbaa -> aarrggbb
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// The bot's chat background behind the messages, as the web widget draws
/// it (core/customization/chat_background.dart): solid, gradient (linear,
/// radial, mesh, blur), image with its mask, or a pattern tile repeated.
class ChatBackgroundLayer extends StatelessWidget {
  final ChatBackground background;
  const ChatBackgroundLayer({super.key, required this.background});

  @override
  Widget build(BuildContext context) {
    final bg = background;
    return switch (bg) {
      SolidBackground() => Container(color: cssColor(bg.color)),
      ImageBackground() => Stack(fit: StackFit.expand, children: [
          Container(color: cssColor(bg.color)),
          Image.network(bg.url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          if (bg.maskColor != null) Container(color: cssColor(bg.maskColor!, Colors.black).withOpacity(bg.maskAlpha)),
        ]),
      GradientBackground() => CustomPaint(painter: _GradientPainter(bg), child: const SizedBox.expand()),
      PatternBackground() => CustomPaint(painter: _PatternPainter(bg), child: const SizedBox.expand()),
    };
  }
}

class _GradientPainter extends CustomPainter {
  final GradientBackground bg;
  _GradientPainter(this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stops = bg.stops.map((s) => cssColor(s)).toList();
    final w = size.width, h = size.height;
    switch (bg.style) {
      case 'radial':
        final (x, y) = ChatBackgrounds.rimPoint(bg.angle.toDouble(), 35);
        final far = [math.sqrt(x * x + y * y), math.sqrt((1 - x) * (1 - x) + y * y), math.sqrt(x * x + (1 - y) * (1 - y)), math.sqrt((1 - x) * (1 - x) + (1 - y) * (1 - y))].reduce(math.max);
        canvas.drawRect(rect, Paint()..shader = RadialGradient(colors: stops).createShader(Rect.fromCircle(center: Offset(x * w, y * h), radius: far * math.max(w, h))));
      case 'mesh':
      case 'blur':
        // Soft colour fields over a base: the web's mesh (and, approximately, its blur).
        final mesh = bg.style == 'mesh';
        canvas.drawRect(rect, Paint()..color = mesh ? stops.last : stops.first);
        final fields = mesh ? stops : (stops.length > 1 ? stops.sublist(1) : [stops.first]);
        for (var i = 0; i < fields.length; i++) {
          final (x, y) = ChatBackgrounds.rimPoint(bg.angle + i * 360 / fields.length + (mesh ? 0 : 20), mesh ? 50 : 34);
          final r = (mesh ? 0.6 : 0.75) * math.max(w, h);
          canvas.drawRect(rect, Paint()..shader = RadialGradient(colors: [fields[i], fields[i].withOpacity(0)]).createShader(Rect.fromCircle(center: Offset(x * w, y * h), radius: r)));
        }
      default:
        // The CSS angle (0 = to top, 180 = to bottom) across the box.
        final a = bg.angle * math.pi / 180;
        final dx = math.sin(a) / 2, dy = -math.cos(a) / 2;
        canvas.drawRect(rect, Paint()..shader = LinearGradient(colors: stops, begin: Alignment(-dx * 2, -dy * 2), end: Alignment(dx * 2, dy * 2)).createShader(rect));
    }
  }

  @override
  bool shouldRepaint(_GradientPainter old) => old.bg != bg;
}

class _PatternPainter extends CustomPainter {
  final PatternBackground bg;
  final PatternTile tile;
  final List<Path?> paths;

  _PatternPainter(this.bg)
      : tile = chatPatterns[bg.pattern] ?? chatPatterns['dots']!,
        paths = (chatPatterns[bg.pattern] ?? chatPatterns['dots']!).shapes.map((s) => s.d == null ? null : _toPath(s.d!)).toList();

  static Path _toPath(String d) {
    final p = Path();
    for (final s in parseSvgPath(d)) {
      switch (s) {
        case SvgMove(): p.moveTo(s.x, s.y);
        case SvgLine(): p.lineTo(s.x, s.y);
        case SvgCubic(): p.cubicTo(s.x1, s.y1, s.x2, s.y2, s.x, s.y);
        case SvgClose(): p.close();
      }
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = cssColor(bg.color));
    final ink = cssColor(bg.ink, const Color(0xFF0F172A));
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var y = 0.0; y < size.height; y += tile.h) {
      for (var x = 0.0; x < size.width; x += tile.w) {
        canvas.save();
        canvas.translate(x, y);
        _tile(canvas, ink);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  void _tile(Canvas canvas, Color ink) {
    if (tile.noise) {
      for (final p in ChatBackgrounds.paperSpeckles) {
        canvas.drawCircle(Offset(p[0], p[1]), p[2], Paint()..color = ink.withOpacity(math.min(1, bg.alpha * 1.6 * p[3])));
      }
      return;
    }
    for (var i = 0; i < tile.shapes.length; i++) {
      final s = tile.shapes[i];
      final paint = Paint()
        ..color = ink.withOpacity(bg.alpha)
        ..style = s.fill ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = s.sw
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
      canvas.save();
      if (s.rot != null) {
        canvas.translate(s.rot![1], s.rot![2]);
        canvas.rotate(s.rot![0] * math.pi / 180);
        canvas.translate(-s.rot![1], -s.rot![2]);
      }
      switch (s.t) {
        case 'circle':
          canvas.drawCircle(Offset(s.cx, s.cy), s.r, paint);
        case 'rect':
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.x, s.y, s.w, s.h), Radius.circular(s.rx)), paint);
        default:
          if (paths[i] != null) canvas.drawPath(paths[i]!, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.bg.pattern != bg.pattern || old.bg.ink != bg.ink || old.bg.alpha != bg.alpha || old.bg.color != bg.color;
}
