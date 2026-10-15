import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';

import '../core/customization/launcher_icons.dart';
import '../core/customization/svg_path.dart';

/// Draws a launcher icon (core/customization/launcher_icons.dart) filling
/// the canvas, in [ink] with its cut-outs in [bg], at rest: parts that only
/// show while animating stay hidden. Gradients sit in each shape's own
/// bounding box (SVG objectBoundingBox), as on the web.
class LauncherIconPainter extends CustomPainter {
  final LauncherIcon icon;
  final Color ink;
  final Color bg;

  LauncherIconPainter({required String? iconId, required this.ink, required this.bg}) : icon = LauncherIcons.byId(iconId);

  static final Map<String, Path> _paths = {};

  static Path _path(String d) => _paths.putIfAbsent(d, () {
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
      });

  Color _color(String c) {
    if (c == 'ink') return ink;
    if (c == 'bg') return bg;
    if (c.startsWith('#') && c.length == 7) {
      final n = int.tryParse(c.substring(1), radix: 16);
      if (n != null) return Color(0xFF000000 | n);
    }
    return const Color(0xFF000000);
  }

  Paint _paint(IconPaint p, Rect bounds, double opacity) {
    final paint = Paint()..isAntiAlias = true;
    if (p.g != null) {
      final g = icon.grads[p.g!];
      final colors = g.stops.map((s) {
        final c = _color(s.c);
        return c.withOpacity((c.opacity * s.a * p.a * opacity).clamp(0, 1).toDouble());
      }).toList();
      final stops = g.stops.map((s) => s.o).toList();
      // Built in a unit box and mapped onto the shape's bounds.
      final unit = Float64List.fromList([
        bounds.width, 0, 0, 0,
        0, bounds.height, 0, 0,
        0, 0, 1, 0,
        bounds.left, bounds.top, 0, 1,
      ]);
      paint.shader = g.t == 'r'
          ? ui.Gradient.radial(Offset(g.cx, g.cy), g.r, colors, stops, TileMode.clamp, unit)
          : ui.Gradient.linear(Offset(g.x1, g.y1), Offset(g.x2, g.y2), colors, stops, TileMode.clamp, unit);
    } else {
      final c = _color(p.c ?? '#000000');
      paint.color = c.withOpacity((c.opacity * p.a * opacity).clamp(0, 1).toDouble());
    }
    return paint;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    for (final o in icon.ops) {
      if (o.op == 0) continue;
      final path = _path(o.d);
      path.fillType = o.evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
      final bounds = path.getBounds();
      final opacity = o.op ?? 1;
      canvas.save();
      final m = o.m;
      if (m != null && m.length == 6) {
        canvas.transform(Float64List.fromList([m[0], m[1], 0, 0, m[2], m[3], 0, 0, 0, 0, 1, 0, m[4], m[5], 0, 1]));
      }
      if (o.clip != null) canvas.clipPath(_path(o.clip!));
      void fill() {
        if (o.fill != null) canvas.drawPath(path, _paint(o.fill!, bounds, opacity)..style = PaintingStyle.fill);
      }

      void stroke() {
        if (o.stroke == null) return;
        canvas.drawPath(
          path,
          _paint(o.stroke!, bounds, opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = o.sw
            ..strokeCap = switch (o.cap) { 'round' => StrokeCap.round, 'square' => StrokeCap.square, _ => StrokeCap.butt }
            ..strokeJoin = switch (o.join) { 'round' => StrokeJoin.round, 'bevel' => StrokeJoin.bevel, _ => StrokeJoin.miter },
        );
      }

      if (o.strokeFirst) {
        stroke();
        fill();
      } else {
        fill();
        stroke();
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LauncherIconPainter old) => old.icon != icon || old.ink != ink || old.bg != bg;
}
