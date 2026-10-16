/// The launcher effects drawn (the React Native SDK's FxSprites.tsx and
/// IdleCallView.tsx): an entrance's sprites on their stage, the idle call's
/// mascot with its moving parts and rings, and its speech bubble. Each is
/// drawn at a time t (ms) the launcher's clock gives it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/customization/fx_paint.dart' show parseCssColor;
import '../core/customization/keyframes.dart';
import '../core/customization/launcher_attention.dart';
import '../core/customization/launcher_entrance.dart';
import '../core/customization/launcher_idle_call.dart';
import '../core/customization/mascot_art.dart';
import 'fx_svg.dart';
import 'launcher_fx_controllers.dart';

Color fxColor(String css, [Color fallback = Colors.transparent]) {
  final c = parseCssColor(css);
  if (c == null) return fallback;
  return Color.fromARGB((c[3] * 255).round(), c[0].round(), c[1].round(), c[2].round());
}

/// A box's transform as the web moves it: about `origin` (px in the box), translate, rotate, scale.
Matrix4 fxBoxMatrix(double ox, double oy, double tx, double ty, double r, double sx, double sy) => Matrix4.identity()
  ..translateByDouble(ox + tx, oy + ty, 0, 1)
  ..rotateZ(r * math.pi / 180)
  ..scaleByDouble(sx, sy, 1, 1)
  ..translateByDouble(-ox, -oy, 0, 1);

void _transform(Canvas c, double ox, double oy, double tx, double ty, double r, double sx, double sy) {
  c.translate(ox + tx, oy + ty);
  if (r != 0) c.rotate(r * math.pi / 180);
  if (sx != 1 || sy != 1) c.scale(sx, sy);
  c.translate(-ox, -oy);
}

/// One sprite and its children at t ms, in the stage's coordinates.
void paintSprite(Canvas c, FxSprite sp, double t) {
  final f = spriteFrame(sp, t);
  if (f.o <= 0.002) return;
  c.save();
  c.translate(sp.x, sp.y);
  _transform(c, sp.origin?[0] ?? sp.w / 2, sp.origin?[1] ?? sp.h / 2, f.tx, f.ty, f.r, f.sx, f.sy);
  final layer = f.o < 0.998;
  final leafFill = sp.fill != null && sp.children.isEmpty && sp.svg == null;
  if (layer && !leafFill) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, f.o));
  if (sp.svg != null && sp.w > 0 && sp.h > 0) {
    c.save();
    if (sp.wipe != null) {
      // A stroke drawn on: only what has been drawn so far shows.
      final p = f.reveal.clamp(0.0, 1.0);
      c.clipRect(sp.wipe == 'down' ? Rect.fromLTWH(0, 0, sp.w, sp.h * p) : Rect.fromLTWH(0, 0, sp.w * p, sp.h));
    }
    drawFxSvg(c, sp.svg!, Size(sp.w, sp.h));
    c.restore();
  } else if (sp.fill != null) {
    final col = fxColor(sp.fill!);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, sp.w, sp.h), Radius.circular(sp.radius ?? 0)),
      Paint()..color = leafFill && layer ? col.withValues(alpha: col.a * f.o) : col,
    );
  }
  if (sp.children.isNotEmpty) {
    c.save();
    if (sp.clip != null) c.clipRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, sp.w, sp.h), Radius.circular(sp.clip!)));
    for (final k in sp.children) {
      paintSprite(c, k, t);
    }
    c.restore();
  }
  if (layer && !leafFill) c.restore();
  c.restore();
}

/// An entrance's sprites over the launcher (the stage is the launcher's box; sprites reach past it).
class EntranceStagePainter extends CustomPainter {
  final EntrancePlan plan;
  final double t;
  EntranceStagePainter(this.plan, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final sp in plan.sprites) {
      paintSprite(canvas, sp, t);
    }
  }

  @override
  bool shouldRepaint(EntranceStagePainter old) => old.t != t || old.plan != plan;
}

/// The idle call's mascot on its stage over the launcher (idleCall.ts
/// perform), each part of the drawing its own layer, and the white rings
/// where a knock or tap lands.
class IdleCallPainter extends CustomPainter {
  final IdleCallPerformance perf;
  final MascotLayers layers;
  final double t;
  IdleCallPainter(this.perf, this.layers, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final n = perf.mascot.size, k = n / 100;
    final box = evaluate(perf.self, t, perf.mascot.base);
    if (box.o > 0.002) {
      canvas.save();
      canvas.translate(perf.mascot.x, perf.mascot.y);
      _transform(canvas, n / 2, n / 2, box.tx, box.ty, box.r, box.sx, box.sy);
      if (box.o < 0.998) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, box.o));
      void layer(String? svg, [String? part, List<double>? origin]) {
        if (svg == null) return;
        final tracks = part == null ? null : perf.parts[part];
        final base = part == null ? null : mascotPartBase[part];
        final v = tracks != null ? evaluate(tracks, t, base) : FxValues.rest(base);
        if (v.o <= 0.002 || v.sx == 0 || v.sy == 0) return;
        canvas.save();
        final o = origin ?? const [50, 50];
        _transform(canvas, o[0] * k, o[1] * k, v.tx * k, v.ty * k, v.r, v.sx, v.sy);
        if (v.o < 0.998) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, v.o));
        drawFxSvg(canvas, svg, Size(n, n));
        if (v.o < 0.998) canvas.restore();
        canvas.restore();
      }

      layer(layers.shadow);
      // The body and everything on it move with the body.
      final b = perf.parts['body'] != null ? evaluate(perf.parts['body']!, t) : FxValues.rest();
      canvas.save();
      _transform(canvas, mascotOrigins['body']![0] * k, mascotOrigins['body']![1] * k, b.tx * k, b.ty * k, b.r, b.sx, b.sy);
      layer(layers.armBack, 'arm', mascotOrigins['arm']);
      layer(layers.body);
      layer(layers.look, 'look', mascotOrigins['look']);
      layer(layers.lids, 'lid', mascotOrigins['lid']);
      layer(layers.brows, 'brow', mascotOrigins['brow']);
      layer(layers.armFront, 'arm', mascotOrigins['arm']);
      layer(layers.smile, 'smile');
      layer(layers.o, 'o');
      layer(layers.grin, 'grin');
      canvas.restore();
      if (box.o < 0.998) canvas.restore();
      canvas.restore();
    }
    for (final r in perf.ripples) {
      final v = evaluate([r.track], t, const {'o': 0});
      if (v.o <= 0.002) continue;
      canvas.save();
      canvas.translate(r.x, r.y);
      canvas.scale(v.sx, v.sy);
      final rect = Rect.fromCircle(center: Offset.zero, radius: r.d / 2 - 1.25);
      canvas.drawOval(rect, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = Color.fromRGBO(15, 23, 42, 0.12 * v.o));
      canvas.drawOval(rect, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Color.fromRGBO(255, 255, 255, 0.9 * v.o));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(IdleCallPainter old) => old.t != t || old.perf != perf || old.layers != layers;
}

/// The speech bubble over the mascot (.cb-ic-bubble), its tail on the mascot.
const idleBubbleText = TextStyle(decoration: TextDecoration.none, color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.2);
const idleBubblePadH = 13.0, idleBubblePadV = 8.0;

/// The bubble's size for a line (one line, no wrapping).
Size idleBubbleSize(String line, [String? font]) {
  final tp = TextPainter(text: TextSpan(text: line, style: idleBubbleText.copyWith(fontFamily: font)), textDirection: TextDirection.ltr, maxLines: 1)..layout();
  return Size(tp.width + idleBubblePadH * 2, tp.height + idleBubblePadV * 2);
}

class IdleCallBubble extends StatelessWidget {
  final String line;

  /// Where its tail points, from its left edge.
  final double tail;
  final String? font;
  final VoidCallback onTap;
  const IdleCallBubble({super.key, required this.line, required this.tail, required this.onTap, this.font});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$line Open the chat',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: idleBubblePadH, vertical: idleBubblePadV),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x380F172A), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: Text(line, maxLines: 1, softWrap: false, style: idleBubbleText.copyWith(fontFamily: font)),
          ),
          // The tail: a white square turned 45deg, half under the box.
          Positioned(
            left: tail - 6,
            bottom: -6,
            child: Transform.rotate(angle: math.pi / 4, child: Container(width: 12, height: 12, color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}

/// The attention loop's parts at a moment: the target's own values ("self")
/// and the extra pieces (hand, shadow, shine, orbit, ring, ring2).
class AttentionFrame {
  final String? target;
  final Map<String, FxValues> parts;
  const AttentionFrame(this.target, this.parts);
  FxValues? operator [](String part) => parts[part];
}

/// The parts of [mode] at [t] ms on its loop.
AttentionFrame attentionFrameAt(String mode, double t, {bool wide = false}) => AttentionFrame(
      attentionTarget(mode),
      {for (final tr in attentionTracks(mode, false, wide)) tr.part!: evaluate([tr], t, attentionBase[tr.part])},
    );

Widget _moved(FxValues? v, double w, double h, Widget child, {double? ox, double? oy, double txpOf = 0}) {
  if (v == null) return child;
  Widget out = Transform(
    transform: fxBoxMatrix(ox ?? w / 2, oy ?? h / 2, v.tx + v.txp / 100 * txpOf, v.ty, v.r, v.sx, v.sy),
    child: child,
  );
  if (v.o < 0.998) out = Opacity(opacity: v.o.clamp(0.0, 1.0), child: out);
  return out;
}

class _TopClipper extends CustomClipper<Rect> {
  final double shown;
  _TopClipper(this.shown);
  @override
  Rect getClip(Size size) => Rect.fromLTWH(-size.width, -size.height, size.width * 3, size.height * (1 + shown.clamp(0.0, 1.0)));
  @override
  bool shouldReclip(_TopClipper old) => old.shown != shown;
}

/// The launcher with its effects round it, in the order the RN SDK stacks
/// them: the bounce's shadow, the idle call's mascot behind the button, the
/// portal behind it; the button (held, moved and wiped by the entrance,
/// moved by the attention loop and jolted by a knock or tap) over the
/// ripple and pulse rings, with the gloss and the orbit's spark; then a
/// knock / tap mascot and every other entrance in front.
class FxLauncherStack extends StatelessWidget {
  final Widget button;
  final Size size;
  final BorderRadius radius;
  final Color color;

  /// Under the button and moving with it (the motion's ripple rings).
  final List<Widget> under;
  final EntrancePlan? plan;
  final double entranceT;
  final EntranceLook? look;
  final AttentionFrame? attention;
  final IdleCallPerformance? perf;
  final MascotLayers? layers;
  final double idleT;

  const FxLauncherStack({
    super.key,
    required this.button,
    required this.size,
    required this.radius,
    required this.color,
    this.under = const [],
    this.plan,
    this.entranceT = 0,
    this.look,
    this.attention,
    this.perf,
    this.layers,
    this.idleT = 0,
  });

  @override
  Widget build(BuildContext context) {
    final w = size.width, h = size.height;
    final a = attention;
    final onLauncher = a?.target == 'launcher';
    Widget stage(bool behind) => plan != null && plan!.behind == behind
        ? Positioned(left: 0, top: 0, width: w, height: h, child: IgnorePointer(child: CustomPaint(painter: EntranceStagePainter(plan!, entranceT))))
        : const SizedBox.shrink();
    Widget mascot(bool front) => perf != null && layers != null && perf!.front == front
        ? Positioned(left: 0, top: 0, width: w, height: h, child: IgnorePointer(child: CustomPaint(painter: IdleCallPainter(perf!, layers!, idleT))))
        : const SizedBox.shrink();

    // The button, with the gloss sweeping across it and the spark circling it.
    final shine = onLauncher ? a!['shine'] : null;
    final orbit = onLauncher ? a!['orbit'] : null;
    Widget body = Stack(clipBehavior: Clip.none, children: [
      button,
      if (shine != null)
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: 0,
                  top: h * glossTop,
                  width: w * glossWidth,
                  height: h * glossHeight,
                  child: _moved(
                    shine,
                    w * glossWidth,
                    h * glossHeight,
                    CustomPaint(painter: _GlossPainter()),
                    txpOf: w * glossWidth,
                  ),
                ),
              ]),
            ),
          ),
        ),
      if (orbit != null && orbit.o > 0.002)
        () {
          final p = orbitPoint(w, h, orbit.od / 100);
          return Positioned(
            left: p.x - orbitDot / 2,
            top: p.y - orbitDot / 2,
            child: IgnorePointer(
              child: Opacity(
                opacity: orbit.o.clamp(0.0, 1.0),
                child: Container(
                  width: orbitDot,
                  height: orbitDot,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 6)]),
                ),
              ),
            ),
          );
        }(),
    ]);

    // Under it: the ripple, and the pulse's two rings in the launcher's colour.
    Widget launcher = Stack(clipBehavior: Clip.none, children: [
      ...under,
      for (final part in const ['ring', 'ring2'])
        if (onLauncher && a![part] != null && a[part]!.o > 0.002)
          Positioned.fill(
            child: IgnorePointer(
              child: _moved(
                a[part],
                w,
                h,
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: color, width: 2.5),
                  ),
                ),
              ),
            ),
          ),
      body,
    ]);
    // A knock or a tap jolts it.
    if (perf != null && perf!.launcher.isNotEmpty) launcher = _moved(evaluate(perf!.launcher, idleT), w, h, launcher);
    if (onLauncher) launcher = _moved(a!['self'], w, h, launcher, txpOf: w);
    // The entrance: hidden until its reveal, then its arrival (the saucer's beam draws it top to bottom).
    final l = look;
    if (l != null) {
      if (l.shown < 0.999) launcher = ClipRect(clipper: _TopClipper(l.shown), child: launcher);
      launcher = Transform(transform: fxBoxMatrix(w / 2, h / 2, l.tx, l.ty, l.r, l.sx, l.sy), child: launcher);
      launcher = Opacity(opacity: l.o.clamp(0.0, 1.0), child: launcher);
    }

    final shadow = onLauncher ? a!['shadow'] : null;
    final sw = w * 0.76, sh = math.max(6.0, h * 0.2);
    return Stack(clipBehavior: Clip.none, children: [
      // The bounce's contact shadow on the screen under it.
      if (shadow != null)
        Positioned(
          left: w * 0.12,
          top: h * 0.9,
          width: sw,
          height: sh,
          child: IgnorePointer(child: _moved(shadow, sw, sh, CustomPaint(painter: _ShadowPainter()))),
        ),
      mascot(false),
      stage(true),
      launcher,
      mascot(true),
      stage(false),
    ]);
  }
}

class _GlossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0x00FFFFFF), Color(0xBFFFFFFF), Color(0x00FFFFFF)]).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_GlossPainter old) => false;
}

class _ShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1, size.height / size.width);
    canvas.drawCircle(
      Offset.zero,
      size.width / 2,
      Paint()..shader = const RadialGradient(colors: [Color(0x8C0F172A), Color(0x000F172A)]).createShader(Rect.fromCircle(center: Offset.zero, radius: size.width / 2)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => false;
}

/// The greeting card under the entrance (hidden until the launcher lands,
/// then fading up) and the attention loop (wave: it bobs with a waving hand
/// on its corner, unless its text has its own; float: it floats).
Widget fxGreeting(Widget card, {EntranceLook? look, AttentionFrame? attention, bool handOnCard = true}) {
  Widget out = card;
  final a = attention;
  if (a?.target == 'greeting') {
    final self = a!['self'];
    final hand = a['hand'];
    out = Stack(clipBehavior: Clip.none, children: [
      out,
      if (hand != null && handOnCard)
        Positioned(
          top: -13,
          left: -9,
          width: handW,
          height: handH,
          child: IgnorePointer(
            child: Transform(
              transform: fxBoxMatrix(handOx, handOy, 0, 0, hand.r, 1, 1),
              child: const Text(wavingHand, style: TextStyle(fontSize: 20, height: 1, decoration: TextDecoration.none)),
            ),
          ),
        ),
    ]);
    if (self != null) out = Transform.translate(offset: Offset(self.tx, self.ty), child: out);
  }
  final l = look;
  if (l != null) {
    out = Transform.translate(offset: Offset(0, l.greetingTy), child: out);
    out = Opacity(opacity: l.greetingO.clamp(0.0, 1.0), child: out);
  }
  return out;
}

/// The idle call's bubble at [t] ms: (opacity, drop, scale x, scale y), or null while it is not showing.
(double, double, double, double)? evaluateBubble(IdleCallPerformance perf, double t) {
  final v = evaluate([perf.bubble], t, const {'o': 0});
  if (v.o <= 0.002) return null;
  return (v.o.clamp(0.0, 1.0), v.ty, v.sx, v.sy);
}
