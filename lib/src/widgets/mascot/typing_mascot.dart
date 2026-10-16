/// The "mascot" and "pencil" typing styles (the React Native SDK's
/// components/Mascot/TypingMascot.tsx; web chatChrome.ts, polish.css
/// .cb-typing--mascot, .cb-typing--pencil), on core/customization/
/// mascot_moods.dart's keyframes.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/customization/keyframes.dart';
import '../../core/customization/mascot_art.dart';
import '../../core/customization/mascot_moods.dart';
import '../../core/customization/svg_path.dart';
import '../fx_svg.dart';
import 'mascot_view.dart';

/// The bot's mascot, its head framed tight (32 x 32), gently swaying about
/// 50% 90% of its box, blinking and glancing at three thought dots rising
/// beside it in the bubble's text colour. Still under reduced motion.
class TypingMascot extends StatefulWidget {
  final MascotLook look;
  final String accent;
  final Color ink;
  final bool reduced;
  const TypingMascot({super.key, required this.look, required this.accent, required this.ink, this.reduced = false});

  @override
  State<TypingMascot> createState() => _TypingMascotState();
}

class _TypingMascotState extends State<TypingMascot> with SingleTickerProviderStateMixin {
  late final FxTime _time = FxTime(this, () {
    if (mounted) setState(() {});
  });
  final ValueNotifier<MascotPose> _pose = ValueNotifier(const MascotPose());
  MascotLayers? _layers;
  String _key = '';

  @override
  void dispose() {
    _time.dispose();
    _pose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const n = TypingMascotSpec.size;
    if (widget.reduced) {
      _time.stop();
    } else {
      _time.start();
    }
    // One lap of all of it, as the web's three loops line up again.
    final t = widget.reduced ? null : _time.now % TypingMascotSpec.period;
    final key = '${widget.accent} ${widget.look.hashCode}';
    if (key != _key || _layers == null) {
      _key = key;
      _layers = mascotLayers(widget.accent, 'down', widget.look, true);
    }
    final pose = t == null
        ? const MascotPose()
        : MascotPose({
            'lid': MascotPart(evaluate([TypingMascotSpec.blink], t, const {'sy': 0})),
            'look': MascotPart(evaluate([TypingMascotSpec.glance], t), transformOrder(TypingMascotSpec.glance)),
          });
    if (!pose.same(_pose.value)) _pose.value = pose;
    final sway = t == null ? null : evaluate([TypingMascotSpec.sway], t);
    Widget figure = SizedBox(
      width: n,
      height: n,
      child: CustomPaint(painter: MascotPainter(_layers!, _pose, bust: true, joints: mascotOrigins(widget.look))),
    );
    if (sway != null) {
      figure = Transform(transform: fxTransformMatrix(sway, transformOrder(TypingMascotSpec.sway), TypingMascotSpec.origin.$1, TypingMascotSpec.origin.$2), child: figure);
    }
    return Semantics(
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
        figure,
        const SizedBox(width: 6),
        SizedBox(
          height: 16,
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < TypingMascotSpec.dots.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Padding(
                padding: EdgeInsets.only(bottom: TypingMascotSpec.dots[i].up),
                child: Container(
                  width: TypingMascotSpec.dots[i].d,
                  height: TypingMascotSpec.dots[i].d,
                  decoration: BoxDecoration(
                    color: widget.ink.withValues(alpha: widget.ink.a * (t == null ? 0.25 : evaluate([TypingMascotSpec.dots[i].track], t, const {'o': 0.25}).o)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// The pencil in the launcher colour (polish.css), in its own 20 x 20 box.
String typingPencilSvg(String accent, String ink) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -6 20 20"><path d="M0 0 L4 -4 L14 6 L10 10 Z" fill="$accent"/><path d="M0 0 L2.6 -2.6 L1.2 1.2 Z" fill="$ink"/><path d="M10 10 L14 6 L15.6 7.6 L11.6 11.6 Z" fill="#f59e9e"/></svg>';

class _LinePainter extends CustomPainter {
  final Color ink;
  final double dash;
  _LinePainter(this.ink, this.dash);

  static final Path _line = () {
    final p = Path();
    for (final s in parseSvgPath(TypingPencilSpec.line)) {
      switch (s) {
        case SvgMove(): p.moveTo(s.x, s.y);
        case SvgLine(): p.lineTo(s.x, s.y);
        case SvgCubic(): p.cubicTo(s.x1, s.y1, s.x2, s.y2, s.x, s.y);
        case SvgClose(): p.close();
      }
    }
    return p;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 44, size.height / 16);
    canvas.drawPath(
      dashPath(_line, const [TypingPencilSpec.dash, TypingPencilSpec.dash], dash),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.ink != ink || old.dash != dash;
}

class _SvgPainter extends CustomPainter {
  final String svg;
  _SvgPainter(this.svg);
  @override
  void paint(Canvas canvas, Size size) => drawFxSvg(canvas, svg, size);
  @override
  bool shouldRepaint(_SvgPainter old) => old.svg != svg;
}

/// A 44 x 16 line that writes itself in 2s (stroke-dashoffset 60 to 0,
/// then fades), the pencil in the launcher colour riding its tip. Still
/// under reduced motion (the line drawn, the pencil at rest).
class TypingPencil extends StatefulWidget {
  final String accent;
  final Color ink;
  final bool reduced;
  const TypingPencil({super.key, required this.accent, required this.ink, this.reduced = false});

  @override
  State<TypingPencil> createState() => _TypingPencilState();
}

class _TypingPencilState extends State<TypingPencil> with SingleTickerProviderStateMixin {
  late final FxTime _time = FxTime(this, () {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    if (widget.reduced) {
      _time.stop();
    } else {
      _time.start();
    }
    const p = TypingPencilSpec.period;
    // Linear keyframes, looping: the line's 100% fades it, the pencil's 100% is back at the start.
    final t = widget.reduced ? null : math.min(_time.now % p, p - 0.001);
    final line = t == null ? null : evaluate([TypingPencilSpec.write], t, const {'dash': TypingPencilSpec.dash});
    final pen = t == null ? null : evaluate([TypingPencilSpec.pencil], t);
    return Semantics(
      excludeSemantics: true,
      child: SizedBox(
        width: 44,
        height: 16,
        child: Stack(clipBehavior: Clip.none, children: [
          Opacity(
            opacity: line == null ? 1 : line.o.clamp(0.0, 1.0).toDouble(),
            child: CustomPaint(size: const Size(44, 16), painter: _LinePainter(widget.ink, line?.dash ?? 0)),
          ),
          Positioned(
            left: -2,
            top: -6,
            width: 20,
            height: 20,
            child: Transform.translate(
              offset: Offset(pen?.tx ?? 2, pen?.ty ?? 11),
              child: CustomPaint(size: const Size(20, 20), painter: _SvgPainter(typingPencilSvg(widget.accent, _hex(widget.ink)))),
            ),
          ),
        ]),
      ),
    );
  }
}
