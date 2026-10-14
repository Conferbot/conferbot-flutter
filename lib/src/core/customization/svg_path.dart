/// An SVG path's "d" attribute as move / line / cubic / close segments, for
/// drawing the chat background tiles without a vector library. Covers every
/// command: M L H V C S Q T A Z, absolute and relative; quadratics and
/// elliptical arcs become cubics. Pure (ported from the iOS SDK's parser).
library;

import 'dart:math' as math;

sealed class SvgSegment {
  const SvgSegment();
}

class SvgMove extends SvgSegment {
  final double x, y;
  const SvgMove(this.x, this.y);
}

class SvgLine extends SvgSegment {
  final double x, y;
  const SvgLine(this.x, this.y);
}

class SvgCubic extends SvgSegment {
  final double x1, y1, x2, y2, x, y;
  const SvgCubic(this.x1, this.y1, this.x2, this.y2, this.x, this.y);
}

class SvgClose extends SvgSegment {
  const SvgClose();
}

class _Tokens {
  final String s;
  int i = 0;
  _Tokens(this.s);

  void _skip() {
    while (i < s.length && ' ,\n\t\r'.contains(s[i])) {
      i++;
    }
  }

  String? peekCommand() {
    _skip();
    if (i >= s.length) return null;
    return 'MmLlHhVvCcSsQqTtAaZz'.contains(s[i]) ? s[i] : null;
  }

  bool atNumber() {
    _skip();
    return i < s.length && RegExp(r'[0-9.+\-]').hasMatch(s[i]);
  }

  bool? flag() {
    _skip();
    if (i < s.length && (s[i] == '0' || s[i] == '1')) return s[i++] == '1';
    return null;
  }

  double? number() {
    _skip();
    final start = i;
    if (i < s.length && (s[i] == '-' || s[i] == '+')) i++;
    var dot = false, exp = false;
    while (i < s.length) {
      final c = s[i];
      if (RegExp(r'[0-9]').hasMatch(c)) {
        i++;
      } else if (c == '.' && !dot && !exp) {
        dot = true;
        i++;
      } else if ((c == 'e' || c == 'E') && !exp && i > start) {
        exp = true;
        i++;
        if (i < s.length && (s[i] == '-' || s[i] == '+')) i++;
      } else {
        break;
      }
    }
    return double.tryParse(s.substring(start, i));
  }
}

/// The segments of a path's "d" attribute; an unreadable tail is dropped.
List<SvgSegment> parseSvgPath(String d) {
  final out = <SvgSegment>[];
  final t = _Tokens(d);
  var cx = 0.0, cy = 0.0, sx = 0.0, sy = 0.0;
  double? lcx, lcy, lqx, lqy;
  String? cmd;
  while (true) {
    final next = t.peekCommand();
    if (next != null) {
      t.i++;
      cmd = next;
    } else if (cmd == null || !t.atNumber()) {
      break;
    }
    final c = cmd;
    final rel = c.toLowerCase() == c;
    (double, double) pt(double x, double y) => rel ? (cx + x, cy + y) : (x, y);
    switch (c.toUpperCase()) {
      case 'M':
        final x = t.number(), y = t.number();
        if (x == null || y == null) return out;
        (cx, cy) = pt(x, y);
        sx = cx;
        sy = cy;
        out.add(SvgMove(cx, cy));
        cmd = rel ? 'l' : 'L';
        lcx = lcy = lqx = lqy = null;
      case 'L':
        final x = t.number(), y = t.number();
        if (x == null || y == null) return out;
        (cx, cy) = pt(x, y);
        out.add(SvgLine(cx, cy));
        lcx = lcy = lqx = lqy = null;
      case 'H':
        final x = t.number();
        if (x == null) return out;
        cx = rel ? cx + x : x;
        out.add(SvgLine(cx, cy));
        lcx = lcy = lqx = lqy = null;
      case 'V':
        final y = t.number();
        if (y == null) return out;
        cy = rel ? cy + y : y;
        out.add(SvgLine(cx, cy));
        lcx = lcy = lqx = lqy = null;
      case 'C':
        final n = List.generate(6, (_) => t.number());
        if (n.contains(null)) return out;
        final (x1, y1) = pt(n[0]!, n[1]!);
        final (x2, y2) = pt(n[2]!, n[3]!);
        final (x, y) = pt(n[4]!, n[5]!);
        out.add(SvgCubic(x1, y1, x2, y2, x, y));
        cx = x;
        cy = y;
        lcx = x2;
        lcy = y2;
        lqx = lqy = null;
      case 'S':
        final n = List.generate(4, (_) => t.number());
        if (n.contains(null)) return out;
        final x1 = lcx != null ? 2 * cx - lcx : cx, y1 = lcy != null ? 2 * cy - lcy : cy;
        final (x2, y2) = pt(n[0]!, n[1]!);
        final (x, y) = pt(n[2]!, n[3]!);
        out.add(SvgCubic(x1, y1, x2, y2, x, y));
        cx = x;
        cy = y;
        lcx = x2;
        lcy = y2;
        lqx = lqy = null;
      case 'Q':
        final n = List.generate(4, (_) => t.number());
        if (n.contains(null)) return out;
        final (qx, qy) = pt(n[0]!, n[1]!);
        final (x, y) = pt(n[2]!, n[3]!);
        out.add(_quad(cx, cy, qx, qy, x, y));
        cx = x;
        cy = y;
        lqx = qx;
        lqy = qy;
        lcx = lcy = null;
      case 'T':
        final x0 = t.number(), y0 = t.number();
        if (x0 == null || y0 == null) return out;
        final qx = lqx != null ? 2 * cx - lqx : cx, qy = lqy != null ? 2 * cy - lqy : cy;
        final (x, y) = pt(x0, y0);
        out.add(_quad(cx, cy, qx, qy, x, y));
        cx = x;
        cy = y;
        lqx = qx;
        lqy = qy;
        lcx = lcy = null;
      case 'A':
        final rx = t.number(), ry = t.number(), rot = t.number(), large = t.flag(), sweep = t.flag(), x0 = t.number(), y0 = t.number();
        if ([rx, ry, rot, large, sweep, x0, y0].contains(null)) return out;
        final (x, y) = pt(x0!, y0!);
        out.addAll(_arc(cx, cy, x, y, rx!, ry!, rot!, large!, sweep!));
        cx = x;
        cy = y;
        lcx = lcy = lqx = lqy = null;
      case 'Z':
        out.add(const SvgClose());
        cx = sx;
        cy = sy;
        lcx = lcy = lqx = lqy = null;
        cmd = null;
      default:
        return out;
    }
  }
  return out;
}

SvgCubic _quad(double x0, double y0, double qx, double qy, double x, double y) =>
    SvgCubic(x0 + 2 / 3 * (qx - x0), y0 + 2 / 3 * (qy - y0), x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y), x, y);

/// An elliptical arc as cubic Beziers (SVG implementation notes, F.6).
List<SvgSegment> _arc(double x0, double y0, double x1, double y1, double rxIn, double ryIn, double rotation, bool large, bool sweep) {
  var rx = rxIn.abs(), ry = ryIn.abs();
  if (x0 == x1 && y0 == y1) return const [];
  if (rx == 0 || ry == 0) return [SvgLine(x1, y1)];
  final phi = rotation * math.pi / 180;
  final cp = math.cos(phi), sp = math.sin(phi);
  final dx = (x0 - x1) / 2, dy = (y0 - y1) / 2;
  final x1p = cp * dx + sp * dy, y1p = -sp * dx + cp * dy;
  final lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
  if (lambda > 1) {
    rx *= math.sqrt(lambda);
    ry *= math.sqrt(lambda);
  }
  final num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
  final den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
  var coef = den == 0 ? 0.0 : math.sqrt(math.max(0, num / den));
  if (large == sweep) coef = -coef;
  final cxp = coef * (rx * y1p / ry), cyp = coef * -(ry * x1p / rx);
  final cx = cp * cxp - sp * cyp + (x0 + x1) / 2, cy = sp * cxp + cp * cyp + (y0 + y1) / 2;
  double angle(double ux, double uy, double vx, double vy) {
    final dot = ux * vx + uy * vy;
    final len = math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
    var a = math.acos((dot / len).clamp(-1.0, 1.0));
    if (ux * vy - uy * vx < 0) a = -a;
    return a;
  }

  final t1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
  var delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
  if (!sweep && delta > 0) delta -= 2 * math.pi;
  if (sweep && delta < 0) delta += 2 * math.pi;
  final parts = math.max(1, (delta.abs() / (math.pi / 2)).ceil());
  final step = delta / parts;
  final k = 4 / 3 * math.tan(step / 4);
  (double, double) point(double a) => (cx + rx * math.cos(a) * cp - ry * math.sin(a) * sp, cy + rx * math.cos(a) * sp + ry * math.sin(a) * cp);
  (double, double) deriv(double a) => (-rx * math.sin(a) * cp - ry * math.cos(a) * sp, -rx * math.sin(a) * sp + ry * math.cos(a) * cp);
  final out = <SvgSegment>[];
  var a1 = t1;
  for (var i = 0; i < parts; i++) {
    final a2 = a1 + step;
    final (sx, sy) = point(a1);
    final (ex, ey) = i == parts - 1 ? (x1, y1) : point(a2);
    final (d1x, d1y) = deriv(a1);
    final (d2x, d2y) = deriv(a2);
    out.add(SvgCubic(sx + k * d1x, sy + k * d1y, ex - k * d2x, ey - k * d2y, ex, ey));
    a1 = a2;
  }
  return out;
}
