/// A small SVG renderer for the launcher effects' drawings (the markup built
/// by core/customization/launcher_entrance.dart, mascot_art.dart and
/// fx_paint.dart, the same markup the React Native SDK hands to
/// react-native-svg). It covers what those drawings use: svg (viewBox,
/// preserveAspectRatio none), g (transform, clip-path, opacity), path,
/// ellipse, circle, rect (rx), polygon; fill / stroke as a colour, none or a
/// linear / radial gradient (object bounding box or user space, with a
/// gradientTransform), their opacities, stroke width, caps and joins; and
/// clipPath. No filters, as in RN.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../core/customization/fx_paint.dart' show parseCssColor;
import '../core/customization/svg_path.dart';

class _Node {
  final String tag;
  final Map<String, String> a;
  final List<_Node> kids = [];
  _Node(this.tag, this.a);
}

class _Doc {
  final _Node root;
  final Map<String, _Node> ids;
  final List<double> viewBox;
  final bool stretch;
  _Doc(this.root, this.ids, this.viewBox, this.stretch);
}

final Map<String, _Doc> _cache = {};
final Map<String, ui.Path> _paths = {};

final _tagRe = RegExp(r'<(/?)([a-zA-Z][\w-]*)((?:\s+[\w:-]+="[^"]*")*)\s*(/?)>');
final _attrRe = RegExp(r'([\w:-]+)="([^"]*)"');

_Doc _parse(String svg) {
  final root = _Node('#root', const {});
  final stack = [root];
  final ids = <String, _Node>{};
  for (final m in _tagRe.allMatches(svg)) {
    if (m.group(1) == '/') {
      if (stack.length > 1) stack.removeLast();
      continue;
    }
    final attrs = {for (final a in _attrRe.allMatches(m.group(3) ?? '')) a.group(1)!: a.group(2)!};
    final n = _Node(m.group(2)!, attrs);
    stack.last.kids.add(n);
    final id = attrs['id'];
    if (id != null) ids[id] = n;
    if (m.group(4) != '/') stack.add(n);
  }
  final svgNode = root.kids.firstWhere((k) => k.tag == 'svg', orElse: () => root);
  final vb = (svgNode.a['viewBox'] ?? '').trim().split(RegExp(r'[\s,]+')).map(double.tryParse).toList();
  final w = double.tryParse(svgNode.a['width'] ?? ''), h = double.tryParse(svgNode.a['height'] ?? '');
  final viewBox = vb.length == 4 && vb.every((x) => x != null) ? vb.cast<double>() : [0.0, 0.0, w ?? 100, h ?? 100];
  return _Doc(svgNode, ids, viewBox, svgNode.a['preserveAspectRatio'] == 'none');
}

double _d(Map<String, String> a, String k, [double fallback = 0]) => double.tryParse((a[k] ?? '').trim()) ?? fallback;

/// "rotate(a cx cy) translate(x y) scale(x y)": a 3x3 affine as Matrix4 storage.
Matrix4 _transform(String? t) {
  final m = Matrix4.identity();
  if (t == null) return m;
  for (final f in RegExp(r'(\w+)\(([^)]*)\)').allMatches(t)) {
    final n = f.group(2)!.trim().split(RegExp(r'[\s,]+')).map((x) => double.tryParse(x) ?? 0).toList();
    switch (f.group(1)) {
      case 'translate':
        m.translateByDouble(n[0], n.length > 1 ? n[1] : 0.0, 0, 1);
      case 'scale':
        m.scaleByDouble(n[0], n.length > 1 ? n[1] : n[0], 1, 1);
      case 'rotate':
        final cx = n.length > 2 ? n[1] : 0.0, cy = n.length > 2 ? n[2] : 0.0;
        m
          ..translateByDouble(cx, cy, 0, 1)
          ..rotateZ(n[0] * math.pi / 180)
          ..translateByDouble(-cx, -cy, 0, 1);
    }
  }
  return m;
}

ui.Path _pathOf(String d) => _paths.putIfAbsent(d, () {
      final p = ui.Path();
      for (final s in parseSvgPath(d)) {
        switch (s) {
          case SvgMove(:final x, :final y):
            p.moveTo(x, y);
          case SvgLine(:final x, :final y):
            p.lineTo(x, y);
          case SvgCubic(:final x1, :final y1, :final x2, :final y2, :final x, :final y):
            p.cubicTo(x1, y1, x2, y2, x, y);
          case SvgClose():
            p.close();
        }
      }
      return p;
    });

/// The shape of an element, or null when it is not a shape.
ui.Path? _shape(_Node n) {
  final a = n.a;
  switch (n.tag) {
    case 'path':
      return _pathOf(a['d'] ?? '');
    case 'ellipse':
      final cx = _d(a, 'cx'), cy = _d(a, 'cy'), rx = _d(a, 'rx'), ry = _d(a, 'ry');
      return ui.Path()..addOval(Rect.fromLTRB(cx - rx, cy - ry, cx + rx, cy + ry));
    case 'circle':
      final cx = _d(a, 'cx'), cy = _d(a, 'cy'), r = _d(a, 'r');
      return ui.Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    case 'rect':
      final rect = Rect.fromLTWH(_d(a, 'x'), _d(a, 'y'), _d(a, 'width'), _d(a, 'height'));
      final rx = math.min(_d(a, 'rx', _d(a, 'ry')), rect.width / 2), ry = math.min(_d(a, 'ry', rx), rect.height / 2);
      return ui.Path()..addRRect(RRect.fromRectXY(rect, rx, ry));
    case 'polygon':
      final n0 = (a['points'] ?? '').trim().split(RegExp(r'[\s,]+')).map((x) => double.tryParse(x) ?? 0).toList();
      final p = ui.Path();
      for (var i = 0; i + 1 < n0.length; i += 2) {
        i == 0 ? p.moveTo(n0[i], n0[i + 1]) : p.lineTo(n0[i], n0[i + 1]);
      }
      return p..close();
  }
  return null;
}

Color _color(List<double> c, double opacity) =>
    Color.fromARGB((c[3] * opacity * 255).round().clamp(0, 255), c[0].round().clamp(0, 255), c[1].round().clamp(0, 255), c[2].round().clamp(0, 255));

/// A paint for a fill / stroke value over a shape's bounds, or null for none.
Paint? _paint(_Doc doc, String? value, double opacity, Rect bounds) {
  final v = (value ?? '').trim();
  if (v.isEmpty || v == 'none') return null;
  final url = RegExp(r'^url\(#([^)]+)\)$').firstMatch(v);
  if (url != null) {
    final g = doc.ids[url.group(1)];
    if (g == null) return null;
    final colors = <Color>[], at = <double>[];
    for (final s in g.kids.where((k) => k.tag == 'stop')) {
      final c = parseCssColor(s.a['stop-color'] ?? '#000') ?? [0, 0, 0, 1];
      colors.add(_color(c, _d(s.a, 'stop-opacity', 1) * opacity));
      at.add(_d(s.a, 'offset').clamp(0.0, 1.0));
    }
    if (colors.isEmpty) return null;
    if (colors.length == 1) {
      colors.add(colors.first);
      at.add(1);
    }
    final user = g.a['gradientUnits'] == 'userSpaceOnUse';
    // Object bounding box units: the unit square stretched over the shape.
    final m = user ? _transform(g.a['gradientTransform']) : (Matrix4.identity()..translateByDouble(bounds.left, bounds.top, 0, 1)..scaleByDouble(bounds.width, bounds.height, 1, 1));
    if (!user) m.multiply(_transform(g.a['gradientTransform']));
    final Shader shader;
    if (g.tag == 'linearGradient') {
      shader = ui.Gradient.linear(
        Offset(_d(g.a, 'x1'), _d(g.a, 'y1')),
        Offset(_d(g.a, 'x2', user ? 0 : 1), _d(g.a, 'y2')),
        colors,
        at,
        TileMode.clamp,
        m.storage,
      );
    } else {
      final cx = _d(g.a, 'cx', 0.5), cy = _d(g.a, 'cy', 0.5);
      shader = ui.Gradient.radial(Offset(cx, cy), _d(g.a, 'r', 0.5), colors, at, TileMode.clamp, m.storage);
    }
    return Paint()..shader = shader;
  }
  final c = parseCssColor(v);
  if (c == null) return null;
  return Paint()..color = _color(c, opacity);
}

void _draw(Canvas canvas, _Doc doc, _Node n, double inherited) {
  final a = n.a;
  if (n.tag == 'defs' || n.tag == 'clipPath' || n.tag == 'linearGradient' || n.tag == 'radialGradient' || n.tag == 'stop') return;
  final own = _d(a, 'opacity', 1);
  final t = a['transform'];
  canvas.save();
  if (t != null) canvas.transform(_transform(t).storage);
  final clip = RegExp(r'^url\(#([^)]+)\)$').firstMatch(a['clip-path'] ?? '');
  if (clip != null) {
    final cp = doc.ids[clip.group(1)];
    if (cp != null) {
      final p = ui.Path();
      for (final k in cp.kids) {
        final s = _shape(k);
        if (s != null) p.addPath(s, Offset.zero, matrix4: k.a['transform'] == null ? null : _transform(k.a['transform']).storage);
      }
      canvas.clipPath(p);
    }
  }
  final shape = _shape(n);
  if (shape != null) {
    final o = inherited * own;
    final bounds = shape.getBounds();
    final fill = _paint(doc, a['fill'] ?? '#000', o * _d(a, 'fill-opacity', 1), bounds);
    if (fill != null) canvas.drawPath(shape, fill..style = PaintingStyle.fill);
    final stroke = _paint(doc, a['stroke'], o * _d(a, 'stroke-opacity', 1), bounds);
    if (stroke != null) {
      stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = _d(a, 'stroke-width', 1)
        ..strokeCap = switch (a['stroke-linecap']) { 'round' => StrokeCap.round, 'square' => StrokeCap.square, _ => StrokeCap.butt }
        ..strokeJoin = switch (a['stroke-linejoin']) { 'round' => StrokeJoin.round, 'bevel' => StrokeJoin.bevel, _ => StrokeJoin.miter };
      canvas.drawPath(shape, stroke);
    }
  } else if (n.kids.isNotEmpty) {
    // A group's opacity fades its drawing as one.
    final layer = own < 1 && n.tag == 'g';
    if (layer) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, own));
    for (final k in n.kids) {
      _draw(canvas, doc, k, layer ? inherited : inherited * own);
    }
    if (layer) canvas.restore();
  }
  canvas.restore();
}

/// Draws [svg] filling a box of [size] at the canvas origin.
void drawFxSvg(Canvas canvas, String svg, Size size) {
  final doc = _cache.putIfAbsent(svg, () => _parse(svg));
  final vb = doc.viewBox;
  if (vb[2] <= 0 || vb[3] <= 0 || size.isEmpty) return;
  var sx = size.width / vb[2], sy = size.height / vb[3];
  var dx = 0.0, dy = 0.0;
  if (!doc.stretch) {
    // xMidYMid meet.
    final s = math.min(sx, sy);
    dx = (size.width - vb[2] * s) / 2;
    dy = (size.height - vb[3] * s) / 2;
    sx = sy = s;
  }
  canvas.save();
  canvas.translate(dx, dy);
  canvas.scale(sx, sy);
  canvas.translate(-vb[0], -vb[1]);
  for (final k in doc.root.kids) {
    _draw(canvas, doc, k, 1);
  }
  canvas.restore();
  if (_cache.length > 400) _cache.clear();
}
