import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';

import '../core/customization/launcher_icons.dart';
import '../core/customization/launcher_motion.dart';
import '../core/customization/svg_path.dart';

/// Draws a launcher icon (core/customization/launcher_icons.dart) filling
/// the canvas, in [ink] with its cut-outs in [bg], at rest: parts that only
/// show while animating stay hidden. Gradients sit in each shape's own
/// bounding box (SVG objectBoundingBox), as on the web. With a [frame]
/// (LauncherMotion.iconFrame) the moving parts are drawn mid-moment, an
/// animated opacity fading its whole group as one layer, as CSS opacity does.
class LauncherIconPainter extends CustomPainter {
  final LauncherIcon icon;
  final Color ink;
  final Color bg;
  final List<OpFrame?>? frame;

  LauncherIconPainter({required String? iconId, required this.ink, required this.bg, this.frame}) : icon = LauncherIcons.byId(iconId);

  static Float64List _m4(List<double> m) => Float64List.fromList([m[0], m[1], 0, 0, m[2], m[3], 0, 0, 0, 0, 1, 0, m[4], m[5], 0, 1]);

  static List<double> _invert(List<double> m) {
    final det = m[0] * m[3] - m[1] * m[2];
    if (det == 0) return const [1, 0, 0, 1, 0, 0];
    return [m[3] / det, -m[1] / det, -m[2] / det, m[0] / det, (m[2] * m[5] - m[3] * m[4]) / det, (m[1] * m[4] - m[0] * m[5]) / det];
  }

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
    final open = <int>[];
    for (var i = 0; i < icon.ops.length; i++) {
      final o = icon.ops[i];
      final f = frame != null && i < frame!.length ? frame![i] : null;
      final layers = f?.layers ?? const <(int, double)>[];
      // A layer that is the shape's own element replaces its own opacity.
      final ownGroup = o.self && o.parts.isNotEmpty ? o.parts.last.g : null;
      final ownLayer = layers.isNotEmpty && layers.last.$1 == ownGroup ? layers.last : null;
      final groupLayers = ownLayer != null ? layers.sublist(0, layers.length - 1) : layers;
      var keep = 0;
      while (keep < open.length && keep < groupLayers.length && open[keep] == groupLayers[keep].$1) {
        keep++;
      }
      while (open.length > keep) {
        canvas.restore();
        open.removeLast();
      }
      for (var k = keep; k < groupLayers.length; k++) {
        canvas.saveLayer(const Rect.fromLTWH(-24, -24, 72, 72), Paint()..color = Color.fromRGBO(0, 0, 0, groupLayers[k].$2));
        open.add(groupLayers[k].$1);
      }
      // At rest op; moving, an animated part's opacity replaces its own.
      var opacity = o.op ?? 1.0;
      if (layers.isNotEmpty) {
        final animated = layers.map((l) => l.$1).toSet();
        opacity = o.opRest ?? (o.parts.any((p) => p.o != null) ? 1.0 : (o.op ?? 1.0));
        for (final p in o.parts) {
          if (!animated.contains(p.g) && p.o != null) opacity *= p.o!;
        }
        if (ownLayer != null) opacity *= ownLayer.$2;
      }
      if (opacity == 0) continue;
      final path = _path(o.d);
      path.fillType = o.evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
      final bounds = path.getBounds();
      final m = f?.m ?? o.m;
      canvas.save();
      if (o.clip != null && f?.clipM != null && m != null) {
        // The clip in its own space, then the shape's transform.
        canvas.transform(_m4(f!.clipM!));
        canvas.clipPath(_path(o.clip!));
        canvas.transform(_m4(LauncherMotion.mul(_invert(f.clipM!), m)));
      } else {
        if (m != null && m.length == 6) canvas.transform(_m4(m));
        if (o.clip != null) canvas.clipPath(_path(o.clip!));
      }
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
    while (open.isNotEmpty) {
      canvas.restore();
      open.removeLast();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LauncherIconPainter old) => old.icon != icon || old.ink != ink || old.bg != bg || old.frame != frame;
}
