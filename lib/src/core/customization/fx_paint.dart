/// The paints the launcher effects use on the web (CSS radial / linear /
/// conic gradients, as in conferbot-widget src/ts/launcher/entrance.ts and
/// attention.ts), written as SVG markup (drawn by widgets/fx_svg.dart); and a
/// motion path (CSS offset-path) as points along it. Ported from the React
/// Native SDK's core/fxPaint.ts. Pure.
library;

import 'dart:math' as math;

import 'keyframes.dart' show jsNum;

/// A CSS colour: #rgb, #rrggbb, rgb(), rgba(), "transparent" (null: unknown). [r, g, b, a].
List<double>? parseCssColor(String c) {
  final s = c.trim().toLowerCase();
  if (s == 'transparent') return [0, 0, 0, 0];
  var m = RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6})$').firstMatch(s);
  if (m != null) {
    final g = m.group(1)!;
    final h = g.length == 3 ? g.split('').map((x) => '$x$x').join() : g;
    return [
      int.parse(h.substring(0, 2), radix: 16).toDouble(),
      int.parse(h.substring(2, 4), radix: 16).toDouble(),
      int.parse(h.substring(4, 6), radix: 16).toDouble(),
      1,
    ];
  }
  m = RegExp(r'^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)(?:[\s,/]+([\d.]+))?\s*\)$').firstMatch(s);
  if (m != null) {
    return [double.parse(m.group(1)!), double.parse(m.group(2)!), double.parse(m.group(3)!), m.group(4) == null ? 1 : double.parse(m.group(4)!)];
  }
  return null;
}

class FxStop {
  final String color;

  /// 0..1; missing positions are spread evenly, as CSS does.
  final double? at;
  const FxStop(this.color, [this.at]);
}

/// "rgba(1,2,3,.5) 30%" pieces, as a CSS gradient lists them: a colour, or (colour, percent).
List<FxStop> stops(List<Object> list) => list.map((x) => x is (String, num) ? FxStop(x.$1, x.$2 / 100) : FxStop(x as String)).toList();

class _S {
  final List<double> c;
  double? at;
  _S(this.c, this.at);
}

List<_S> _spread(List<FxStop> list) {
  final out = list.map((s) => _S(parseCssColor(s.color) ?? [0, 0, 0, 0], s.at)).toList();
  out[0].at ??= 0;
  out[out.length - 1].at ??= 1;
  for (var i = 1; i < out.length - 1; i++) {
    if (out[i].at != null) continue;
    var j = i;
    while (out[j].at == null) {
      j++;
    }
    final a = out[i - 1].at!, b = out[j].at!;
    for (var k = i; k < j; k++) {
      out[k].at = a + ((b - a) * (k - i + 1)) / (j - i + 1);
    }
  }
  // A fully transparent stop fades its neighbour's colour (CSS interpolates
  // premultiplied; SVG does not, so the colour is borrowed).
  return [
    for (var i = 0; i < out.length; i++)
      () {
        final s = out[i];
        if (s.c[3] > 0) return s;
        final prev = i > 0 ? out[i - 1] : null, next = i < out.length - 1 ? out[i + 1] : null;
        final near = prev != null && prev.c[3] > 0 ? prev : (next != null && next.c[3] > 0 ? next : (prev ?? next));
        final n = near?.c ?? s.c;
        return _S([n[0], n[1], n[2], s.c[3]], s.at);
      }(),
  ];
}

String _fixed(double x, int d) => jsNum(double.parse(x.toStringAsFixed(d)));

String _stopTags(List<FxStop> list) => _spread(list)
    .map((s) => '<stop offset="${_fixed(s.at!, 4)}" stop-color="rgb(${s.c[0].round()},${s.c[1].round()},${s.c[2].round()})" stop-opacity="${_fixed(s.c[3], 3)}"/>')
    .join();

String _svg(num w, num h, String inner, [String? vb]) =>
    '<svg xmlns="http://www.w3.org/2000/svg" width="${_fixed(w.toDouble(), 2)}" height="${_fixed(h.toDouble(), 2)}" viewBox="${vb ?? '0 0 ${_fixed(w.toDouble(), 2)} ${_fixed(h.toDouble(), 2)}'}">$inner</svg>';

/// radial-gradient(closest-side, ...) filling an ellipse in a w x h box.
String radialDisc(num w, num h, List<FxStop> list) => _svg(w, h,
    '<defs><radialGradient id="g" cx="0.5" cy="0.5" r="0.5">${_stopTags(list)}</radialGradient></defs><ellipse cx="${jsNum(w / 2)}" cy="${jsNum(h / 2)}" rx="${jsNum(w / 2)}" ry="${jsNum(h / 2)}" fill="url(#g)"/>');

/// radial-gradient(ellipse rx ry at cx cy, ...) over a w x h box (a page wash): the ellipse's radii in px.
String radialWash(num w, num h, num cx, num cy, num rx, num ry, List<FxStop> list) => _svg(
      w,
      h,
      '<defs><radialGradient id="g" gradientUnits="userSpaceOnUse" cx="${jsNum(cx)}" cy="${jsNum(cy)}" r="${jsNum(rx)}" gradientTransform="translate(${jsNum(cx)} ${jsNum(cy)}) scale(1 ${jsNum(ry / rx)}) translate(${jsNum(-cx)} ${jsNum(-cy)})">${_stopTags(list)}</radialGradient></defs><rect width="${jsNum(w)}" height="${jsNum(h)}" fill="url(#g)"/>',
    );

/// linear-gradient(<angle>, ...) in a w x h box with rounded corners (CSS angles: 180deg = to bottom).
/// `radius`: one number, or [tl, tr, br, bl].
String linearBox(num w, num h, num angle, List<FxStop> list, [Object radius = 0]) {
  final a = angle * math.pi / 180;
  // The CSS gradient line: through the centre, long enough that the corners get the end colours.
  final len = (w * math.sin(a)).abs() + (h * math.cos(a)).abs();
  final dx = (math.sin(a) * len) / 2;
  final dy = (-math.cos(a) * len) / 2;
  final r = radius is List ? radius.cast<num>() : [radius as num, radius, radius, radius];
  final tl = r[0], tr = r[1], br = r[2], bl = r[3];
  final shape = tl != 0 || tr != 0 || br != 0 || bl != 0
      ? '<path d="M${jsNum(tl)} 0 H${jsNum(w - tr)} A${jsNum(tr)} ${jsNum(tr)} 0 0 1 ${jsNum(w)} ${jsNum(tr)} V${jsNum(h - br)} A${jsNum(br)} ${jsNum(br)} 0 0 1 ${jsNum(w - br)} ${jsNum(h)} H${jsNum(bl)} A${jsNum(bl)} ${jsNum(bl)} 0 0 1 0 ${jsNum(h - bl)} V${jsNum(tl)} A${jsNum(tl)} ${jsNum(tl)} 0 0 1 ${jsNum(tl)} 0 Z" fill="url(#g)"/>'
      : '<rect width="${jsNum(w)}" height="${jsNum(h)}" fill="url(#g)"/>';
  return _svg(w, h,
      '<defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="${jsNum(w / 2 - dx)}" y1="${jsNum(h / 2 - dy)}" x2="${jsNum(w / 2 + dx)}" y2="${jsNum(h / 2 + dy)}">${_stopTags(list)}</linearGradient></defs>$shape');
}

List<double> _mixAt(List<_S> list, double p) {
  if (p <= list[0].at!) return list[0].c;
  for (var i = 0; i < list.length - 1; i++) {
    final a = list[i], b = list[i + 1];
    if (p <= b.at!) {
      final f = b.at! > a.at! ? (p - a.at!) / (b.at! - a.at!) : 1.0;
      // Premultiplied, as CSS gradients interpolate.
      final al = a.c[3] + (b.c[3] - a.c[3]) * f;
      double ch(int k) => al > 0 ? (a.c[k] * a.c[3] + (b.c[k] * b.c[3] - a.c[k] * a.c[3]) * f) / al : 0;
      return [ch(0), ch(1), ch(2), al];
    }
  }
  return list.last.c;
}

/// conic-gradient(from <from>deg, ...) in a circle of diameter d, as thin
/// wedges; `ring` keeps only the band between two shares of the radius
/// (the portal's ring mask).
String conicDisc(num d, num from, List<FxStop> list, [(double, double)? ring, int slices = 48]) {
  final s = _spread(list);
  final r = d / 2;
  final ri = ring != null ? ring.$1 * r : 0.0, ro = ring != null ? ring.$2 * r : r.toDouble();
  final out = StringBuffer();
  for (var i = 0; i < slices; i++) {
    final p = (i + 0.5) / slices;
    final c = _mixAt(s, p);
    if (c[3] <= 0.003) continue;
    // CSS: 0deg points up, clockwise.
    final a0 = ((from + (i / slices) * 360 - 90) * math.pi) / 180;
    final a1 = ((from + ((i + 1.04) / slices) * 360 - 90) * math.pi) / 180;
    String pt(double rad, double a) => '${_fixed(r + rad * math.cos(a), 2)} ${_fixed(r + rad * math.sin(a), 2)}';
    final path = ri > 0
        ? 'M${pt(ro, a0)} A${jsNum(ro)} ${jsNum(ro)} 0 0 1 ${pt(ro, a1)} L${pt(ri, a1)} A${jsNum(ri)} ${jsNum(ri)} 0 0 0 ${pt(ri, a0)} Z'
        : 'M${jsNum(r)} ${jsNum(r)} L${pt(ro, a0)} A${jsNum(ro)} ${jsNum(ro)} 0 0 1 ${pt(ro, a1)} Z';
    out.write('<path d="$path" fill="rgb(${c[0].round()},${c[1].round()},${c[2].round()})" fill-opacity="${_fixed(c[3], 3)}"/>');
  }
  return _svg(d, d, out.toString());
}

// ---- A motion path (offset-path: path("M ... C ... a ...")) ----

/// The path flattened to points (M, L, C and a / A arcs, absolute or relative).
List<(double, double)> flattenPath(String d, [int steps = 24]) {
  final tok = RegExp(r'[a-zA-Z]|-?\d*\.?\d+(?:e[-+]?\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
  final pts = <(double, double)>[];
  var i = 0;
  var cur = (0.0, 0.0);
  var cmd = '';
  final isCmd = RegExp(r'[a-zA-Z]');
  double n() => double.parse(tok[i++]);
  while (i < tok.length) {
    if (isCmd.hasMatch(tok[i])) cmd = tok[i++];
    final rel = cmd == cmd.toLowerCase();
    final c = cmd.toUpperCase();
    if (c == 'M' || c == 'L') {
      final x = n() + (rel ? cur.$1 : 0);
      final y = n() + (rel ? cur.$2 : 0);
      cur = (x, y);
      pts.add(cur);
      if (c == 'M') cmd = rel ? 'l' : 'L';
    } else if (c == 'C') {
      final o = rel ? cur : (0.0, 0.0);
      final p1 = (n() + o.$1, n() + o.$2);
      final p2 = (n() + o.$1, n() + o.$2);
      final p3 = (n() + o.$1, n() + o.$2);
      final p0 = cur;
      for (var k = 1; k <= steps; k++) {
        final t = k / steps;
        final u = 1 - t;
        pts.add((
          u * u * u * p0.$1 + 3 * u * u * t * p1.$1 + 3 * u * t * t * p2.$1 + t * t * t * p3.$1,
          u * u * u * p0.$2 + 3 * u * u * t * p1.$2 + 3 * u * t * t * p2.$2 + t * t * t * p3.$2,
        ));
      }
      cur = p3;
    } else if (c == 'A') {
      var rx = n().abs();
      var ry = n().abs();
      final phi = (n() * math.pi) / 180;
      final large = n() != 0;
      final sweep = n() != 0;
      final x2 = n() + (rel ? cur.$1 : 0);
      final y2 = n() + (rel ? cur.$2 : 0);
      final (x1, y1) = cur;
      // Endpoint to centre parameterisation (SVG implementation notes F.6.5).
      final cp = math.cos(phi), sp = math.sin(phi);
      final dx = (x1 - x2) / 2, dy = (y1 - y2) / 2;
      final x1p = cp * dx + sp * dy;
      final y1p = -sp * dx + cp * dy;
      final lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
      if (lam > 1) {
        rx *= math.sqrt(lam);
        ry *= math.sqrt(lam);
      }
      final num0 = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
      final den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
      var co = math.sqrt(math.max(0, num0 / den));
      if (large == sweep) co = -co;
      final cxp = (co * rx * y1p) / ry;
      final cyp = (-co * ry * x1p) / rx;
      final cx = cp * cxp - sp * cyp + (x1 + x2) / 2;
      final cy = sp * cxp + cp * cyp + (y1 + y2) / 2;
      double ang(double ux, double uy, double vx, double vy) => math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
      final t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
      var dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
      if (!sweep && dt > 0) dt -= 2 * math.pi;
      if (sweep && dt < 0) dt += 2 * math.pi;
      final k = math.max(steps, ((dt.abs() / (2 * math.pi)) * steps * 3).ceil());
      for (var j = 1; j <= k; j++) {
        final t = t1 + (dt * j) / k;
        pts.add((cx + rx * math.cos(t) * cp - ry * math.sin(t) * sp, cy + rx * math.cos(t) * sp + ry * math.sin(t) * cp));
      }
      cur = (x2, y2);
    } else {
      i++;
    }
  }
  return pts;
}

/// A point at a share (0..1) of a flattened path's length, and the path's direction there (deg).
({double x, double y, double angle}) pointAlong(List<(double, double)> pts, double share) {
  final seg = <double>[];
  var total = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final l = math.sqrt(math.pow(pts[i].$1 - pts[i - 1].$1, 2) + math.pow(pts[i].$2 - pts[i - 1].$2, 2));
    seg.add(l);
    total += l;
  }
  var d = share.clamp(0.0, 1.0) * total;
  for (var i = 0; i < seg.length; i++) {
    if (d <= seg[i] || i == seg.length - 1) {
      final f = seg[i] > 0 ? math.min(1.0, d / seg[i]) : 0.0;
      final a = pts[i], b = pts[i + 1];
      return (x: a.$1 + (b.$1 - a.$1) * f, y: a.$2 + (b.$2 - a.$2) * f, angle: (math.atan2(b.$2 - a.$2, b.$1 - a.$1) * 180) / math.pi);
    }
    d -= seg[i];
  }
  final last = pts.isEmpty ? (0.0, 0.0) : pts.last;
  return (x: last.$1, y: last.$2, angle: 0);
}
