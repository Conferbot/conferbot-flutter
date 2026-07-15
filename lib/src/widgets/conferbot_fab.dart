library conferbot_fab;

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/conferbot_provider.dart';
import '../theme/conferbot_theme.dart';
import 'chat_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Part 1 – Config
// ─────────────────────────────────────────────────────────────────────────────

/// Optional compile-time overrides. Server values always take precedence.
class ConferBotFABConfig {
  /// Fallback size in logical pixels when the server does not provide one.
  final double size;

  /// Fallback position when the server does not provide one.
  final FabPosition position;

  /// Fallback horizontal offset (dp) from the edge of the screen.
  final double offsetX;

  /// Fallback vertical offset (dp) from the bottom of the screen.
  final double offsetBottom;

  const ConferBotFABConfig({
    this.size = 50.0,
    this.position = FabPosition.right,
    this.offsetX = 10.0,
    this.offsetBottom = 10.0,
  });
}

enum FabPosition { left, right }

// ─────────────────────────────────────────────────────────────────────────────
// Part 2 – Color helper
// ─────────────────────────────────────────────────────────────────────────────

Color _parseHexColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    final str = hex.startsWith('#') ? hex.substring(1) : hex;
    final fullHex = str.length == 3
        ? str.split('').map((c) => '$c$c').join()
        : str;
    return Color(int.parse('FF$fullHex', radix: 16));
  } catch (_) {
    return fallback;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Part 3 – Minimal SVG path parser
// ─────────────────────────────────────────────────────────────────────────────

class _PathParser {
  final String data;
  int _pos = 0;

  _PathParser(this.data);

  ui.Path parse() {
    final path = ui.Path();
    double cx = 0, cy = 0, mx = 0, my = 0;
    double prevCpX = 0, prevCpY = 0;
    String lastCmd = 'M';

    while (_pos < data.length) {
      _skipWs();
      if (_pos >= data.length) break;

      final ch = data[_pos];
      String cmd;
      if (RegExp(r'[a-zA-Z]').hasMatch(ch)) {
        cmd = ch;
        lastCmd = cmd;
        _pos++;
      } else if (ch == '-' ||
          ch == '+' ||
          (ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0) ||
          ch == '.') {
        // Implicit repeat: after M→L, after m→l, otherwise repeat last
        cmd = lastCmd == 'M'
            ? 'L'
            : lastCmd == 'm'
                ? 'l'
                : lastCmd;
      } else {
        _pos++;
        continue;
      }

      _skipWs();

      switch (cmd) {
        case 'M':
          final x = _num() ?? 0, y = _num() ?? 0;
          cx = x;
          cy = y;
          mx = cx;
          my = cy;
          path.moveTo(cx, cy);
          lastCmd = cmd;
          break;
        case 'm':
          final x = _num() ?? 0, y = _num() ?? 0;
          cx += x;
          cy += y;
          mx = cx;
          my = cy;
          path.moveTo(cx, cy);
          lastCmd = cmd;
          break;
        case 'L':
          final x = _num() ?? 0, y = _num() ?? 0;
          cx = x;
          cy = y;
          path.lineTo(cx, cy);
          lastCmd = cmd;
          break;
        case 'l':
          final x = _num() ?? 0, y = _num() ?? 0;
          cx += x;
          cy += y;
          path.lineTo(cx, cy);
          lastCmd = cmd;
          break;
        case 'H':
          final x = _num() ?? 0;
          cx = x;
          path.lineTo(cx, cy);
          lastCmd = cmd;
          break;
        case 'h':
          final x = _num() ?? 0;
          cx += x;
          path.lineTo(cx, cy);
          lastCmd = cmd;
          break;
        case 'V':
          final y = _num() ?? 0;
          cy = y;
          path.lineTo(cx, cy);
          lastCmd = cmd;
          break;
        case 'v':
          final y = _num() ?? 0;
          cy += y;
          path.lineTo(cx, cy);
          lastCmd = cmd;
          break;
        case 'C':
          {
            final x1 = _num() ?? 0, y1 = _num() ?? 0;
            final x2 = _num() ?? 0, y2 = _num() ?? 0;
            final x = _num() ?? 0, y = _num() ?? 0;
            prevCpX = x2;
            prevCpY = y2;
            cx = x;
            cy = y;
            path.cubicTo(x1, y1, x2, y2, x, y);
            lastCmd = cmd;
          }
          break;
        case 'c':
          {
            final x1r = _num() ?? 0, y1r = _num() ?? 0;
            final x2r = _num() ?? 0, y2r = _num() ?? 0;
            final xr = _num() ?? 0, yr = _num() ?? 0;
            final ax1 = cx + x1r, ay1 = cy + y1r;
            final ax2 = cx + x2r, ay2 = cy + y2r;
            final ax = cx + xr, ay = cy + yr;
            prevCpX = ax2;
            prevCpY = ay2;
            cx = ax;
            cy = ay;
            path.cubicTo(ax1, ay1, ax2, ay2, ax, ay);
            lastCmd = cmd;
          }
          break;
        case 'S':
          {
            // Smooth cubic: first control point is reflection of last
            final rx1 = 2 * cx - prevCpX;
            final ry1 = 2 * cy - prevCpY;
            final x2 = _num() ?? 0, y2 = _num() ?? 0;
            final x = _num() ?? 0, y = _num() ?? 0;
            prevCpX = x2;
            prevCpY = y2;
            cx = x;
            cy = y;
            path.cubicTo(rx1, ry1, x2, y2, x, y);
            lastCmd = cmd;
          }
          break;
        case 's':
          {
            final rx1 = 2 * cx - prevCpX;
            final ry1 = 2 * cy - prevCpY;
            final x2r = _num() ?? 0, y2r = _num() ?? 0;
            final xr = _num() ?? 0, yr = _num() ?? 0;
            final ax2 = cx + x2r, ay2 = cy + y2r;
            final ax = cx + xr, ay = cy + yr;
            prevCpX = ax2;
            prevCpY = ay2;
            cx = ax;
            cy = ay;
            path.cubicTo(rx1, ry1, ax2, ay2, ax, ay);
            lastCmd = cmd;
          }
          break;
        case 'Q':
          {
            final x1 = _num() ?? 0, y1 = _num() ?? 0;
            final x = _num() ?? 0, y = _num() ?? 0;
            prevCpX = x1;
            prevCpY = y1;
            cx = x;
            cy = y;
            path.quadraticBezierTo(x1, y1, x, y);
            lastCmd = cmd;
          }
          break;
        case 'q':
          {
            final x1r = _num() ?? 0, y1r = _num() ?? 0;
            final xr = _num() ?? 0, yr = _num() ?? 0;
            final ax1 = cx + x1r, ay1 = cy + y1r;
            final ax = cx + xr, ay = cy + yr;
            prevCpX = ax1;
            prevCpY = ay1;
            cx = ax;
            cy = ay;
            path.quadraticBezierTo(ax1, ay1, ax, ay);
            lastCmd = cmd;
          }
          break;
        case 'T':
          {
            // Smooth quadratic
            final rx1 = 2 * cx - prevCpX;
            final ry1 = 2 * cy - prevCpY;
            final x = _num() ?? 0, y = _num() ?? 0;
            prevCpX = rx1;
            prevCpY = ry1;
            cx = x;
            cy = y;
            path.quadraticBezierTo(rx1, ry1, x, y);
            lastCmd = cmd;
          }
          break;
        case 't':
          {
            final rx1 = 2 * cx - prevCpX;
            final ry1 = 2 * cy - prevCpY;
            final xr = _num() ?? 0, yr = _num() ?? 0;
            final ax = cx + xr, ay = cy + yr;
            prevCpX = rx1;
            prevCpY = ry1;
            cx = ax;
            cy = ay;
            path.quadraticBezierTo(rx1, ry1, ax, ay);
            lastCmd = cmd;
          }
          break;
        case 'A':
          {
            final rx = _num() ?? 0, ry = _num() ?? 0;
            final xRot = _num() ?? 0;
            final lg = (_num() ?? 0) != 0;
            final sw = (_num() ?? 0) != 0;
            final x = _num() ?? 0, y = _num() ?? 0;
            _arcTo(path, cx, cy, x, y, rx, ry, xRot * math.pi / 180, lg, sw);
            cx = x;
            cy = y;
            lastCmd = cmd;
          }
          break;
        case 'a':
          {
            final rx = _num() ?? 0, ry = _num() ?? 0;
            final xRot = _num() ?? 0;
            final lg = (_num() ?? 0) != 0;
            final sw = (_num() ?? 0) != 0;
            final xr = _num() ?? 0, yr = _num() ?? 0;
            final ex = cx + xr, ey = cy + yr;
            _arcTo(path, cx, cy, ex, ey, rx, ry, xRot * math.pi / 180, lg, sw);
            cx = ex;
            cy = ey;
            lastCmd = cmd;
          }
          break;
        case 'Z':
        case 'z':
          path.close();
          cx = mx;
          cy = my;
          prevCpX = cx;
          prevCpY = cy;
          lastCmd = cmd;
          break;
        default:
          _pos++;
      }
    }
    return path;
  }

  void _skipWs() {
    while (_pos < data.length && ' ,\t\r\n'.contains(data[_pos])) {
      _pos++;
    }
  }

  double? _num() {
    _skipWs();
    if (_pos >= data.length) return null;
    final start = _pos;
    if (_pos < data.length && '-+'.contains(data[_pos])) _pos++;
    while (_pos < data.length && '0123456789.'.contains(data[_pos])) {
      _pos++;
    }
    if (_pos < data.length && 'eE'.contains(data[_pos])) {
      _pos++;
      if (_pos < data.length && '-+'.contains(data[_pos])) _pos++;
      while (_pos < data.length && '0123456789'.contains(data[_pos])) {
        _pos++;
      }
    }
    if (_pos == start) return null;
    return double.tryParse(data.substring(start, _pos));
  }

  /// SVG arc-to → Flutter Path.arcTo conversion (standard algorithm).
  void _arcTo(
    ui.Path path,
    double x1,
    double y1,
    double x2,
    double y2,
    double rx,
    double ry,
    double phi,
    bool largeArc,
    bool sweep,
  ) {
    if (rx == 0 || ry == 0) {
      path.lineTo(x2, y2);
      return;
    }

    final cosP = math.cos(phi);
    final sinP = math.sin(phi);
    final dx = (x1 - x2) / 2;
    final dy = (y1 - y2) / 2;
    final x1p = cosP * dx + sinP * dy;
    final y1p = -sinP * dx + cosP * dy;

    rx = rx.abs();
    ry = ry.abs();

    // Ensure radii are large enough
    final lam =
        (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
    if (lam > 1) {
      final sqLam = math.sqrt(lam);
      rx *= sqLam;
      ry *= sqLam;
    }

    final rxSq = rx * rx, rySq = ry * ry;
    final x1pSq = x1p * x1p, y1pSq = y1p * y1p;
    final numVal =
        math.max(0.0, rxSq * rySq - rxSq * y1pSq - rySq * x1pSq);
    final denomVal = rxSq * y1pSq + rySq * x1pSq;
    final sq = denomVal == 0 ? 0.0 : math.sqrt(numVal / denomVal);
    final sgn = (largeArc == sweep) ? -1.0 : 1.0;

    final cxp = sgn * sq * (rx * y1p / ry);
    final cyp = sgn * sq * (-ry * x1p / rx);

    final cx = cosP * cxp - sinP * cyp + (x1 + x2) / 2;
    final cy = sinP * cxp + cosP * cyp + (y1 + y2) / 2;

    double startAngle =
        math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx);
    double dTheta =
        math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx) - startAngle;

    if (!sweep && dTheta > 0) dTheta -= 2 * math.pi;
    if (sweep && dTheta < 0) dTheta += 2 * math.pi;

    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );
    path.arcTo(rect, startAngle, dTheta, false);
  }
}

ui.Path _parsePath(String d) => _PathParser(d).parse();

// ─────────────────────────────────────────────────────────────────────────────
// Part 4 – SVG shape descriptors
// ─────────────────────────────────────────────────────────────────────────────

enum _ShapeType { path, circle, ellipse, rect }

enum _DrawMode { fill, stroke, fillAndStroke }

class _SvgShape {
  final _ShapeType type;
  final String? d;
  final double vbMinX, vbMinY, vbW, vbH;
  final _DrawMode drawMode;
  final double strokeWidth;
  // circle / ellipse
  final double cx, cy, r, rx, ry;
  // rect
  final double x, y, w, h;

  const _SvgShape._({
    required this.type,
    this.d,
    required this.vbMinX,
    required this.vbMinY,
    required this.vbW,
    required this.vbH,
    this.drawMode = _DrawMode.fill,
    this.strokeWidth = 2.0,
    this.cx = 0,
    this.cy = 0,
    this.r = 0,
    this.rx = 0,
    this.ry = 0,
    this.x = 0,
    this.y = 0,
    this.w = 0,
    this.h = 0,
  });

  const _SvgShape.path(
    String d, {
    double vbMinX = 0,
    double vbMinY = 0,
    required double vbW,
    required double vbH,
    _DrawMode drawMode = _DrawMode.fill,
    double strokeWidth = 2.0,
  }) : this._(
          type: _ShapeType.path,
          d: d,
          vbMinX: vbMinX,
          vbMinY: vbMinY,
          vbW: vbW,
          vbH: vbH,
          drawMode: drawMode,
          strokeWidth: strokeWidth,
        );

  const _SvgShape.circle(
    double cx,
    double cy,
    double r, {
    double vbMinX = 0,
    double vbMinY = 0,
    required double vbW,
    required double vbH,
    _DrawMode drawMode = _DrawMode.fill,
    double strokeWidth = 2.0,
  }) : this._(
          type: _ShapeType.circle,
          vbMinX: vbMinX,
          vbMinY: vbMinY,
          vbW: vbW,
          vbH: vbH,
          drawMode: drawMode,
          strokeWidth: strokeWidth,
          cx: cx,
          cy: cy,
          r: r,
        );

  const _SvgShape.ellipse(
    double cx,
    double cy,
    double rx,
    double ry, {
    double vbMinX = 0,
    double vbMinY = 0,
    required double vbW,
    required double vbH,
    _DrawMode drawMode = _DrawMode.fill,
    double strokeWidth = 2.0,
  }) : this._(
          type: _ShapeType.ellipse,
          vbMinX: vbMinX,
          vbMinY: vbMinY,
          vbW: vbW,
          vbH: vbH,
          drawMode: drawMode,
          strokeWidth: strokeWidth,
          cx: cx,
          cy: cy,
          rx: rx,
          ry: ry,
        );

  const _SvgShape.rect(
    double x,
    double y,
    double w,
    double h, {
    double vbMinX = 0,
    double vbMinY = 0,
    required double vbW,
    required double vbH,
    _DrawMode drawMode = _DrawMode.fill,
    double strokeWidth = 2.0,
  }) : this._(
          type: _ShapeType.rect,
          vbMinX: vbMinX,
          vbMinY: vbMinY,
          vbW: vbW,
          vbH: vbH,
          drawMode: drawMode,
          strokeWidth: strokeWidth,
          x: x,
          y: y,
          w: w,
          h: h,
        );
}

// ─────────────────────────────────────────────────────────────────────────────
// Part 5 – Icon data LUT
// ─────────────────────────────────────────────────────────────────────────────

// ignore_for_file: lines_longer_than_80_chars

const Map<String, List<_SvgShape>> _kIconShapes = {
  // ── Default ────────────────────────────────────────────────────────────────
  'default': [
    _SvgShape.path(
      'M21.5 18C21.5 18 20.5 18.5 20.5 20.1453V21.2858V22.5287V23.3572C20.5 24.131 20.0184 24.1046 19.3517 23.7118L18.75 23.3572L13.5 20C12.8174 19.6587 12.6007 19.5504 12.3729 19.516C12.267 19.5 12.1587 19.5 12 19.5H7.5C2.5 19.5 0 17.5 0 12.5V7.5C0 2.5 2.5 0 7.5 0H16.5C21.5 0 24 2.5 24 7.5V12.5C24 17.5 21.5 18 21.5 18Z',
      vbMinX: 0,
      vbMinY: -1,
      vbW: 24,
      vbH: 25,
    ),
  ],

  // ── WidgetBubbleIcon1 ──────────────────────────────────────────────────────
  'WidgetBubbleIcon1': [
    _SvgShape.path(
      'M16 19a6.99 6.99 0 0 1-5.833-3.129l1.666-1.107a5 5 0 0 0 8.334 0l1.666 1.107A6.99 6.99 0 0 1 16 19m4-11a2 2 0 1 0 2 2a1.98 1.98 0 0 0-2-2m-8 0a2 2 0 1 0 2 2a1.98 1.98 0 0 0-2-2',
      vbW: 30,
      vbH: 30,
    ),
    _SvgShape.path(
      'M17.736 30L16 29l4-7h6a1.997 1.997 0 0 0 2-2V6a1.997 1.997 0 0 0-2-2H6a1.997 1.997 0 0 0-2 2v14a1.997 1.997 0 0 0 2 2h9v2H6a4 4 0 0 1-4-4V6a3.999 3.999 0 0 1 4-4h20a3.999 3.999 0 0 1 4 4v14a4 4 0 0 1-4 4h-4.835Z',
      vbW: 30,
      vbH: 30,
    ),
  ],

  // ── WidgetBubbleIcon2 ──────────────────────────────────────────────────────
  'WidgetBubbleIcon2': [
    _SvgShape.path(
      'M11.999 0c-2.25 0-4.5.06-6.6.21a5.57 5.57 0 0 0-5.19 5.1c-.24 3.21-.27 6.39-.06 9.6a5.644 5.644 0 0 0 5.7 5.19h3.15v-3.9h-3.15c-.93.03-1.74-.63-1.83-1.56c-.18-3-.15-6 .06-9c.06-.84.72-1.47 1.56-1.53c2.04-.15 4.2-.21 6.36-.21s4.32.09 6.36.18c.81.06 1.5.69 1.56 1.53c.24 3 .24 6 .06 9c-.12.93-.9 1.62-1.83 1.59h-3.15l-6 3.9V24l6-3.9h3.15c2.97.03 5.46-2.25 5.7-5.19c.21-3.18.18-6.39-.03-9.57a5.57 5.57 0 0 0-5.19-5.1c-2.13-.18-4.38-.24-6.63-.24m-5.04 8.76c-.36 0-.66.3-.66.66v2.34c0 .33.18.63.48.78c1.62.78 3.42 1.2 5.22 1.26c1.8-.06 3.6-.48 5.22-1.26c.3-.15.48-.45.48-.78V9.42c0-.09-.03-.15-.09-.21a.648.648 0 0 0-.87-.36c-1.5.66-3.12 1.02-4.77 1.05c-1.65-.03-3.27-.42-4.77-1.08a.566.566 0 0 0-.24-.06',
      vbW: 24,
      vbH: 24,
    ),
  ],

  // ── WidgetBubbleIcon3 ──────────────────────────────────────────────────────
  'WidgetBubbleIcon3': [
    _SvgShape.path(
      'M7.5 5a1.5 1.5 0 1 0 0 3a1.5 1.5 0 0 0 0-3',
      vbMinY: 1,
      vbW: 15,
      vbH: 15,
    ),
    _SvgShape.path(
      'M9 2H8V0H7v2H6a6 6 0 0 0 0 12h3c.13 0 .26-.004.389-.013l3.99.998a.5.5 0 0 0 .606-.606l-.577-2.309A6 6 0 0 0 9 2M5 6.5a2.5 2.5 0 1 1 5 0a2.5 2.5 0 0 1-5 0M7.5 12a4.483 4.483 0 0 1-2.813-.987l.626-.78c.599.48 1.359.767 2.187.767c.828 0 1.588-.287 2.187-.767l.626.78A4.483 4.483 0 0 1 7.5 12',
      vbMinY: 1,
      vbW: 15,
      vbH: 15,
    ),
  ],

  // ── WidgetBubbleIcon4 ──────────────────────────────────────────────────────
  'WidgetBubbleIcon4': [
    _SvgShape.path(
      'M9 2.5V2zm-3 0V3zm6.856 9.422l-.35-.356l-.205.2l.07.277zM13.5 14.5l-.121.485a.5.5 0 0 0 .606-.606zm-4-1l-.354-.354l-.624.625l.857.214zm.025-.025l.353.354a.5.5 0 0 0-.4-.852zM.5 8H0zM7 0v2.5h1V0zm2 2H6v1h3zm6 6a6 6 0 0 0-6-6v1a5 5 0 0 1 5 5zm-1.794 4.279A5.983 5.983 0 0 0 15 7.999h-1a4.983 4.983 0 0 1-1.495 3.567zm.78 2.1L13.34 11.8l-.97.242l.644 2.578zm-4.607-.394l4 1l.242-.97l-4-1zm-.208-.863l-.025.024l.708.707l.024-.024zM9 14c.193 0 .384-.01.572-.027l-.094-.996A5.058 5.058 0 0 1 9 13zm-3 0h3v-1H6zM0 8a6 6 0 0 0 6 6v-1a5 5 0 0 1-5-5zm6-6a6 6 0 0 0-6 6h1a5 5 0 0 1 5-5zm1.5 6A1.5 1.5 0 0 1 6 6.5H5A2.5 2.5 0 0 0 7.5 9zM9 6.5A1.5 1.5 0 0 1 7.5 8v1A2.5 2.5 0 0 0 10 6.5zM7.5 5A1.5 1.5 0 0 1 9 6.5h1A2.5 2.5 0 0 0 7.5 4zm0-1A2.5 2.5 0 0 0 5 6.5h1A1.5 1.5 0 0 1 7.5 5zm0 8c1.064 0 2.042-.37 2.813-.987l-.626-.78c-.6.48-1.359.767-2.187.767zm-2.813-.987c.77.617 1.75.987 2.813.987v-1a3.483 3.483 0 0 1-2.187-.767z',
      vbMinY: 1,
      vbW: 15,
      vbH: 15,
    ),
  ],

  // ── WidgetBubbleIcon5 ──────────────────────────────────────────────────────
  'WidgetBubbleIcon5': [
    _SvgShape.path(
      'M18 4a3 3 0 0 1 3 3v8a3 3 0 0 1-3 3h-5l-5 3v-3H6a3 3 0 0 1-3-3V7a3 3 0 0 1 3-3zM9.5 9h.01m4.99 0h.01',
      vbW: 24,
      vbH: 24,
      drawMode: _DrawMode.stroke,
      strokeWidth: 2.0,
    ),
    _SvgShape.path(
      'M9.5 13a3.5 3.5 0 0 0 5 0',
      vbW: 24,
      vbH: 24,
      drawMode: _DrawMode.stroke,
      strokeWidth: 2.0,
    ),
  ],

  // ── WidgetBubbleIcon6 ──────────────────────────────────────────────────────
  'WidgetBubbleIcon6': [
    _SvgShape.path(
      'M768 1024H640V896h128zm512 0h-128V896h128zm512-128v256h-128v320q0 40-15 75t-41 61t-61 41t-75 15h-264l-440 376v-376H448q-40 0-75-15t-61-41t-41-61t-15-75v-320H128V896h128V704q0-40 15-75t41-61t61-41t75-15h448V303q-29-17-46-47t-18-64q0-27 10-50t27-40t41-28t50-10q27 0 50 10t40 27t28 41t10 50q0 34-17 64t-47 47v209h448q40 0 75 15t61 41t41 61t15 75v192zm-256-192q0-26-19-45t-45-19H448q-26 0-45 19t-19 45v768q0 26 19 45t45 19h448v226l264-226h312q26 0 45-19t19-45zm-851 462q55 55 126 84t149 30q78 0 149-29t126-85l90 91q-73 73-167 112t-198 39q-103 0-197-39t-168-112z',
      vbMinX: 0,
      vbMinY: 200,
      vbW: 1900,
      vbH: 1900,
    ),
  ],

  // ── WidgetBubbleIcon7 ──────────────────────────────────────────────────────
  'WidgetBubbleIcon7': [
    _SvgShape.path(
      'M408 64H104a56.16 56.16 0 0 0-56 56v192a56.16 56.16 0 0 0 56 56h40v80l93.72-78.14a8 8 0 0 1 5.13-1.86H408a56.16 56.16 0 0 0 56-56V120a56.16 56.16 0 0 0-56-56Z',
      vbW: 512,
      vbH: 512,
      drawMode: _DrawMode.stroke,
      strokeWidth: 32,
    ),
  ],

  // ── WidgetBubbleIcon8 ──────────────────────────────────────────────────────
  'WidgetBubbleIcon8': [
    _SvgShape.path(
      'M456 48H56a24 24 0 0 0-24 24v288a24 24 0 0 0 24 24h72v80l117.74-80H456a24 24 0 0 0 24-24V72a24 24 0 0 0-24-24M160 248a32 32 0 1 1 32-32a32 32 0 0 1-32 32m96 0a32 32 0 1 1 32-32a32 32 0 0 1-32 32m96 0a32 32 0 1 1 32-32a32 32 0 0 1-32 32',
      vbW: 512,
      vbH: 512,
    ),
  ],

  // ── WidgetBubbleIcon9 ──────────────────────────────────────────────────────
  'WidgetBubbleIcon9': [
    _SvgShape.path(
      'M408 64H104a56.16 56.16 0 0 0-56 56v192a56.16 56.16 0 0 0 56 56h40v80l93.72-78.14a8 8 0 0 1 5.13-1.86H408a56.16 56.16 0 0 0 56-56V120a56.16 56.16 0 0 0-56-56Z',
      vbW: 512,
      vbH: 512,
      drawMode: _DrawMode.stroke,
      strokeWidth: 32,
    ),
    _SvgShape.circle(160, 216, 32, vbW: 512, vbH: 512),
    _SvgShape.circle(256, 216, 32, vbW: 512, vbH: 512),
    _SvgShape.circle(352, 216, 32, vbW: 512, vbH: 512),
  ],

  // ── WidgetBubbleIcon10 ─────────────────────────────────────────────────────
  'WidgetBubbleIcon10': [
    _SvgShape.path(
      'M408 48H104a72.08 72.08 0 0 0-72 72v192a72.08 72.08 0 0 0 72 72h24v64a16 16 0 0 0 26.25 12.29L245.74 384H408a72.08 72.08 0 0 0 72-72V120a72.08 72.08 0 0 0-72-72M160 248a32 32 0 1 1 32-32a32 32 0 0 1-32 32m96 0a32 32 0 1 1 32-32a32 32 0 0 1-32 32m96 0a32 32 0 1 1 32-32a32 32 0 0 1-32 32',
      vbW: 512,
      vbH: 512,
    ),
  ],

  // ── WidgetBubbleIcon11 ─────────────────────────────────────────────────────
  'WidgetBubbleIcon11': [
    _SvgShape.path(
      'M144 464a16 16 0 0 1-16-16v-64h-24a72.08 72.08 0 0 1-72-72V120a72.08 72.08 0 0 1 72-72h304a72.08 72.08 0 0 1 72 72v192a72.08 72.08 0 0 1-72 72H245.74l-91.49 76.29A16.05 16.05 0 0 1 144 464',
      vbW: 512,
      vbH: 512,
    ),
  ],

  // ── WidgetBubbleIcon12 ─────────────────────────────────────────────────────
  'WidgetBubbleIcon12': [
    _SvgShape.path(
      'M21.928 11.607c-.202-.488-.635-.605-.928-.633V8c0-1.103-.897-2-2-2h-6V4.61c.305-.274.5-.668.5-1.11a1.5 1.5 0 0 0-3 0c0 .442.195.836.5 1.11V6H5c-1.103 0-2 .897-2 2v2.997l-.082.006A1 1 0 0 0 1.99 12v2a1 1 0 0 0 1 1H3v5c0 1.103.897 2 2 2h14c1.103 0 2-.897 2-2v-5a1 1 0 0 0 1-1v-1.938a1.006 1.006 0 0 0-.072-.455M5 20V8h14l.001 3.996L19 12v2l.001.005l.001 5.995z',
      vbMinY: 2,
      vbW: 24,
      vbH: 24,
    ),
    _SvgShape.ellipse(8.5, 12, 1.5, 2, vbMinY: 2, vbW: 24, vbH: 24),
    _SvgShape.ellipse(15.5, 12, 1.5, 2, vbMinY: 2, vbW: 24, vbH: 24),
    _SvgShape.rect(8, 16, 8, 2, vbMinY: 2, vbW: 24, vbH: 24),
  ],

  // ── WidgetBubbleIcon13 ─────────────────────────────────────────────────────
  'WidgetBubbleIcon13': [
    _SvgShape.path(
      'M12 8V4H8',
      vbMinY: 2,
      vbW: 24,
      vbH: 24,
      drawMode: _DrawMode.stroke,
      strokeWidth: 2.0,
    ),
    _SvgShape.rect(4, 8, 16, 12, vbMinY: 2, vbW: 24, vbH: 24),
    _SvgShape.path(
      'M2 14h2m16 0h2m-7-1v2m-6-2v2',
      vbMinY: 2,
      vbW: 24,
      vbH: 24,
      drawMode: _DrawMode.stroke,
      strokeWidth: 2.0,
    ),
  ],

  // ── WidgetBubbleIcon14 ─────────────────────────────────────────────────────
  'WidgetBubbleIcon14': [
    _SvgShape.rect(10.125, 13, 4, 2, vbMinY: 1, vbW: 23, vbH: 23),
    _SvgShape.path(
      'M8.125 13a2 2 0 1 0 0-4a2 2 0 0 0 0 4m0-1.5a.5.5 0 1 0 0-1a.5.5 0 0 0 0 1m10-.5a2 2 0 1 1-4 0a2 2 0 0 1 4 0m-1.5 0a.5.5 0 1 1-1 0a.5.5 0 0 1 1 0',
      vbMinY: 1,
      vbW: 23,
      vbH: 23,
    ),
    _SvgShape.path(
      'M2.749 14.666A6 6 0 0 0 8.125 18h8c2.44 0 4.54-1.456 5.478-3.547A2.997 2.997 0 0 0 22.875 12c0-1.013-.503-1.91-1.272-2.452A6.001 6.001 0 0 0 16.125 6h-8A6 6 0 0 0 2.75 9.334a3 3 0 0 0 0 5.332M8.125 8h8c1.384 0 2.603.702 3.322 1.77c.276.69.428 1.442.428 2.23s-.152 1.54-.428 2.23A3.996 3.996 0 0 1 16.125 16h-8a4 4 0 0 1 0-8',
      vbMinY: 1,
      vbW: 23,
      vbH: 23,
    ),
  ],

  // ── WidgetBubbleIcon15 ─────────────────────────────────────────────────────
  'WidgetBubbleIcon15': [
    _SvgShape.path(
      'M21 10.975V8a2 2 0 0 0-2-2h-6V4.688c.305-.274.5-.668.5-1.11a1.5 1.5 0 0 0-3 0c0 .442.195.836.5 1.11V6H5a2 2 0 0 0-2 2v2.998l-.072.005A.999.999 0 0 0 2 12v2a1 1 0 0 0 1 1v5a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-5a1 1 0 0 0 1-1v-1.938a1.004 1.004 0 0 0-.072-.455c-.202-.488-.635-.605-.928-.632M7 12c0-1.104.672-2 1.5-2s1.5.896 1.5 2s-.672 2-1.5 2S7 13.104 7 12m8.998 6c-1.001-.003-7.997 0-7.998 0v-2s7.001-.002 8.002 0zm-.498-4c-.828 0-1.5-.896-1.5-2s.672-2 1.5-2s1.5.896 1.5 2s-.672 2-1.5 2',
      vbMinY: 2,
      vbW: 24,
      vbH: 24,
    ),
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// Part 6 – Icon painter
// ─────────────────────────────────────────────────────────────────────────────

class _IconPainter extends CustomPainter {
  final String iconName;
  final Color color;

  const _IconPainter({required this.iconName, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final shapes = _kIconShapes[iconName] ?? _kIconShapes['default']!;

    for (final shape in shapes) {
      _drawShape(shape, canvas, size);
    }
  }

  void _drawShape(_SvgShape shape, Canvas canvas, Size canvasSize) {
    final vbW = shape.vbW;
    final vbH = shape.vbH;

    final scale = math.min(canvasSize.width / vbW, canvasSize.height / vbH);
    final scaledW = vbW * scale;
    final scaledH = vbH * scale;
    final dx = (canvasSize.width - scaledW) / 2 - shape.vbMinX * scale;
    final dy = (canvasSize.height - scaledH) / 2 - shape.vbMinY * scale;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = shape.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (shape.type) {
      case _ShapeType.path:
        if (shape.d == null) break;
        final p = _parsePath(shape.d!);
        _applyDraw(canvas, p, shape.drawMode, fillPaint, strokePaint);
        break;

      case _ShapeType.circle:
        final p = ui.Path()
          ..addOval(Rect.fromCircle(
            center: Offset(shape.cx, shape.cy),
            radius: shape.r,
          ));
        _applyDraw(canvas, p, shape.drawMode, fillPaint, strokePaint);
        break;

      case _ShapeType.ellipse:
        final p = ui.Path()
          ..addOval(Rect.fromCenter(
            center: Offset(shape.cx, shape.cy),
            width: shape.rx * 2,
            height: shape.ry * 2,
          ));
        _applyDraw(canvas, p, shape.drawMode, fillPaint, strokePaint);
        break;

      case _ShapeType.rect:
        final p = ui.Path()
          ..addRect(Rect.fromLTWH(shape.x, shape.y, shape.w, shape.h));
        _applyDraw(canvas, p, shape.drawMode, fillPaint, strokePaint);
        break;
    }

    canvas.restore();
  }

  void _applyDraw(
    Canvas canvas,
    ui.Path p,
    _DrawMode mode,
    Paint fill,
    Paint stroke,
  ) {
    switch (mode) {
      case _DrawMode.fill:
        canvas.drawPath(p, fill);
        break;
      case _DrawMode.stroke:
        canvas.drawPath(p, stroke);
        break;
      case _DrawMode.fillAndStroke:
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke);
        break;
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.iconName != iconName || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Part 7 – Close icon painter
// ─────────────────────────────────────────────────────────────────────────────

class _CloseIconPainter extends CustomPainter {
  final Color color;

  const _CloseIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final pad = size.width * 0.2;
    canvas.drawLine(
      Offset(pad, pad),
      Offset(size.width - pad, size.height - pad),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - pad, pad),
      Offset(pad, size.height - pad),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CloseIconPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Part 8 – CTA tooltip
// ─────────────────────────────────────────────────────────────────────────────

class _CtaTooltip extends StatefulWidget {
  final String text;
  final Color bgColor;
  final double borderRadius;
  final VoidCallback onClose;

  const _CtaTooltip({
    required this.text,
    required this.bgColor,
    required this.borderRadius,
    required this.onClose,
  });

  @override
  State<_CtaTooltip> createState() => _CtaTooltipState();
}

class _CtaTooltipState extends State<_CtaTooltip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Auto-show after 2 s
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _foreground {
    // Always white text on CTA, matching web widget
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 212),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: widget.bgColor,
            child: InkWell(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.text,
                        style: TextStyle(
                          color: _foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: _foreground.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Part 9 – Unread badge
// ─────────────────────────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Part 10 – ConferBotFAB  (main widget)
// ─────────────────────────────────────────────────────────────────────────────

/// Floating Action Button that wraps your app content.
///
/// Usage:
/// ```dart
/// ConferBotFAB(
///   child: MyApp(),
/// )
/// ```
///
/// The widget reads all visual parameters from [ConferBotProvider] via
/// `serverCustomizations`, falling back to [config] values, and ultimately to
/// hard-coded defaults that match the web widget.
class ConferBotFAB extends StatefulWidget {
  /// The rest of your app's widget tree.
  final Widget child;

  /// Optional compile-time overrides (server values always win).
  final ConferBotFABConfig config;

  /// Optional theme override forwarded to [ChatWidget].
  final ConferBotTheme? theme;

  const ConferBotFAB({
    super.key,
    required this.child,
    this.config = const ConferBotFABConfig(),
    this.theme,
  });

  @override
  State<ConferBotFAB> createState() => _ConferBotFABState();
}

class _ConferBotFABState extends State<ConferBotFAB>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  bool _ctaDismissed = false;

  // FAB press animation
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
    _pressScale = _pressCtrl;
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  // ── Resolve server config values ──────────────────────────────────────────

  Map<String, dynamic>? _sc(ConferBotProvider p) => p.serverCustomizations;

  Color _resolveColor(ConferBotProvider p) {
    final sc = _sc(p);
    return _parseHexColor(
      sc?['widgetIconBgColor']?.toString() ??
          sc?['headerBgColor']?.toString(),
      const Color(0xFF1B55F3),
    );
  }

  double _resolveSize(ConferBotProvider p) {
    final raw = _sc(p)?['widgetSize'];
    if (raw == null) return widget.config.size;
    return (raw is num) ? raw.toDouble() : widget.config.size;
  }

  FabPosition _resolvePosition(ConferBotProvider p) {
    final raw = _sc(p)?['widgetPosition']?.toString();
    return raw == 'left' ? FabPosition.left : widget.config.position;
  }

  double _resolveOffsetX(ConferBotProvider p) {
    final sc = _sc(p);
    final pos = _resolvePosition(p);
    final raw = pos == FabPosition.left
        ? (sc?['widgetOffsetLeft'])
        : (sc?['widgetOffsetRight']);
    if (raw == null) return widget.config.offsetX;
    return (raw is num) ? raw.toDouble() : widget.config.offsetX;
  }

  double _resolveOffsetBottom(ConferBotProvider p) {
    final raw = _sc(p)?['widgetOffsetBottom'];
    if (raw == null) return widget.config.offsetBottom;
    return (raw is num) ? raw.toDouble() : widget.config.offsetBottom;
  }

  double _resolveBorderRadius(ConferBotProvider p, double size) {
    final raw = _sc(p)?['widgetBorderRadius'];
    if (raw == null) return size / 2;
    return (raw is num) ? raw.toDouble() : size / 2;
  }

  String _resolveIconName(ConferBotProvider p) {
    final raw = _sc(p)?['widgetIconSVG']?.toString();
    if (raw != null && _kIconShapes.containsKey(raw)) return raw;
    return 'default';
  }

  String? _resolveCtaText(ConferBotProvider p) {
    final raw = _sc(p)?['chatIconCtaText']?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  // ── Open chat sheet ───────────────────────────────────────────────────────

  Future<void> _openChat(BuildContext context, ConferBotProvider provider) async {
    setState(() => _isOpen = true);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return ChangeNotifierProvider<ConferBotProvider>.value(
          value: provider,
          child: DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.5,
            maxChildSize: 0.92,
            expand: false,
            builder: (_, scrollController) {
              return ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: ChatWidget(
                  theme: widget.theme,
                ),
              );
            },
          ),
        );
      },
    );

    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConferBotProvider>(context);

    final fabColor = _resolveColor(provider);
    final size = _resolveSize(provider);
    final position = _resolvePosition(provider);
    final offsetX = _resolveOffsetX(provider);
    final offsetBottom = _resolveOffsetBottom(provider);
    final borderRadius = _resolveBorderRadius(provider, size);
    final iconName = _resolveIconName(provider);
    final ctaText = _resolveCtaText(provider);
    final unreadCount = provider.unreadCount;
    final iconSize = size * 0.6;

    final isLeft = position == FabPosition.left;

    // CTA border radius: min(widgetBorderRadius ?? 50, 20)
    final ctaBorderRadius = math.min(
      _sc(provider)?['widgetBorderRadius'] != null
          ? ((_sc(provider)?['widgetBorderRadius'] as num?)?.toDouble() ?? 50.0)
          : 50.0,
      20.0,
    );

    // CTA horizontal offset from edge: offsetX + size + 10
    final ctaEdgeOffset = offsetX + size + 10;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── App content ───────────────────────────────────────────────────
        widget.child,

        // ── CTA tooltip ───────────────────────────────────────────────────
        if (ctaText != null && !_ctaDismissed && !_isOpen)
          Positioned(
            bottom: offsetBottom,
            left: isLeft ? ctaEdgeOffset : null,
            right: isLeft ? null : ctaEdgeOffset,
            child: Align(
              alignment: isLeft
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: _CtaTooltip(
                text: ctaText,
                bgColor: fabColor,
                borderRadius: ctaBorderRadius,
                onClose: () => setState(() => _ctaDismissed = true),
              ),
            ),
          ),

        // ── FAB ───────────────────────────────────────────────────────────
        Positioned(
          bottom: offsetBottom,
          left: isLeft ? offsetX : null,
          right: isLeft ? null : offsetX,
          child: GestureDetector(
            onTapDown: (_) => _pressCtrl.reverse(),
            onTapUp: (_) {
              _pressCtrl.forward();
              _openChat(context, provider);
            },
            onTapCancel: () => _pressCtrl.forward(),
            child: ScaleTransition(
              scale: _pressScale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Shadow + pill container
                  Material(
                    elevation: 8,
                    shadowColor: fabColor.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(borderRadius),
                    color: fabColor,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: fabColor,
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _isOpen
                              ? CustomPaint(
                                  key: const ValueKey('close'),
                                  size: Size(iconSize, iconSize),
                                  painter: _CloseIconPainter(Colors.white),
                                )
                              : CustomPaint(
                                  key: ValueKey(iconName),
                                  size: Size(iconSize, iconSize),
                                  painter: _IconPainter(
                                    iconName: iconName,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),

                  // Unread count badge (top-right of FAB)
                  if (unreadCount > 0 && !_isOpen)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: _UnreadBadge(count: unreadCount),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Part 11 – ConferBotFABScope convenience wrapper
// ─────────────────────────────────────────────────────────────────────────────

/// Convenience widget that creates a [ConferBotProvider] and wraps the child
/// in a [ConferBotFAB].
///
/// Example:
/// ```dart
/// ConferBotFABScope(
///   apiKey: 'YOUR_API_KEY',
///   botId: 'YOUR_BOT_ID',
///   child: MaterialApp(home: MyHomePage()),
/// )
/// ```
class ConferBotFABScope extends StatelessWidget {
  final String apiKey;
  final String botId;
  final Widget child;
  final ConferBotFABConfig fabConfig;
  final ConferBotConfig providerConfig;
  final ConferBotCustomization? customization;
  final ConferBotUser? user;
  final String? baseUrl;
  final String? socketUrl;

  const ConferBotFABScope({
    super.key,
    required this.apiKey,
    required this.botId,
    required this.child,
    this.fabConfig = const ConferBotFABConfig(),
    this.providerConfig = const ConferBotConfig(),
    this.customization,
    this.user,
    this.baseUrl,
    this.socketUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ConferBotProvider>(
      create: (_) => ConferBotProvider(
        apiKey: apiKey,
        botId: botId,
        config: providerConfig,
        customization: customization,
        user: user,
        baseUrl: baseUrl,
        socketUrl: socketUrl,
      ),
      child: Builder(
        builder: (ctx) => ConferBotFAB(
          config: fabConfig,
          child: child,
        ),
      ),
    );
  }
}
