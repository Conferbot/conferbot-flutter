/// The conversation's human touches, drawn (core/delight/delight.dart; web
/// ts/chat/delight/ and css/nodes/17-delight.css, 06-rating-fx.css). Ported
/// from the React Native SDK (components/Delight/Delight.tsx):
///
///   ReactionBadge     the bot's tapback on the corner of the visitor's
///                     answer facing the bot, popping in (cb-react-pop)
///   ConfettiBurst     a second of confetti in the bot's colours from the
///                     answer (cb-confetti-fly), transform and opacity only
///   RatingSparks      the rating's sparks on a pick (cbn-spark)
///   StallHint         "No rush - ..." under a question that has waited
///   ChangeAnswerLink  "Edit" under the visitor's latest answer
///
/// Nothing moves for visitors who ask for less motion
/// (MediaQuery.disableAnimations); the confetti and the sparks are not drawn
/// at all then. No haptics.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/delight/delight.dart';
import '../../core/i18n/i18n.dart';

// The web's easings (css/nodes/01-base.css --cbn-spring, --cbn-ease).
const Curve _spring = Cubic(0.34, 1.56, 0.64, 1);
const Curve _ease = Cubic(0.22, 1, 0.36, 1);

bool _reduced(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// A value on piecewise-linear stops (an Animated interpolate's input / output ranges).
double _lerpStops(double t, List<double> at, List<double> values) {
  if (t <= at.first) return values.first;
  for (var i = 1; i < at.length; i++) {
    if (t <= at[i]) {
      final f = (t - at[i - 1]) / (at[i] - at[i - 1]);
      return values[i - 1] + (values[i] - values[i - 1]) * f;
    }
  }
  return values.last;
}

/// The tapback: a 26 px round badge, start corner, 14 px below the bubble.
class ReactionBadge extends StatefulWidget {
  final String emoji;
  final Color card;
  final Color ring;
  const ReactionBadge({super.key, required this.emoji, required this.card, required this.ring});

  @override
  State<ReactionBadge> createState() => _ReactionBadgeState();
}

class _ReactionBadgeState extends State<ReactionBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced(context)) {
      _pop.value = 1;
    } else if (!_pop.isAnimating && _pop.value == 0) {
      _pop.forward();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: Delight.reactionLabel(widget.emoji),
      image: true,
      excludeSemantics: true,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pop,
          builder: (_, child) {
            final v = _spring.transform(_pop.value);
            final scale = _lerpStops(v, const [0, 0.6, 1], const [0.2, 1.18, 1]);
            final rotate = _lerpStops(v, const [0, 0.6, 1], const [-24, 6, 0]) * math.pi / 180;
            final opacity = _lerpStops(v, const [0, 0.6, 1], const [0, 1, 1]).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Transform.rotate(angle: rotate, child: Transform.scale(scale: scale, child: child)),
            );
          },
          child: Container(
            key: const ValueKey('cb-reaction-badge'),
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.card,
              shape: BoxShape.circle,
              border: Border.all(color: widget.ring, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x2E0F172A), blurRadius: 3, offset: Offset(0, 2))],
            ),
            child: Text(widget.emoji, style: const TextStyle(fontSize: 13, height: 1.2)),
          ),
        ),
      ),
    );
  }
}

/// A colour mixed with white (CSS color-mix(in srgb, c share, #fff)).
Color _mix(Color c, double share) => Color.lerp(Colors.white, c, share)!;

/// The burst, from the bubble's middle: each piece flies out to (dx, dy)
/// by 55% of 1.05 s, then on and down by its fall while it fades. Colours:
/// the bot's accent, the star gold, the accent lightened, a mint.
class ConfettiBurst extends StatefulWidget {
  final Color accent;
  final VoidCallback? onDone;

  /// The pieces' randomness (tests give a fixed one).
  final double Function()? random;
  const ConfettiBurst({super.key, required this.accent, this.onDone, this.random});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final List<ConfettiPiece> _pieces = Delight.confettiPieces(widget.random);
  // The longest delay plus the flight; the burst is let go at confettiMs.
  late final AnimationController _clock;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: const Duration(milliseconds: Delight.confettiMs));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduced(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
      return;
    }
    _clock.forward().whenComplete(() {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return const SizedBox.shrink();
    final tones = [widget.accent, const Color(0xFFF5A524), _mix(widget.accent, 0.45), const Color(0xFF34D399)];
    const curve = Cubic(0.2, 0.7, 0.3, 1);
    return IgnorePointer(
      child: AnimatedBuilder(
        key: const ValueKey('cb-confetti'),
        animation: _clock,
        builder: (_, __) {
          final ms = _clock.value * Delight.confettiMs;
          return CustomPaint(
            painter: _ConfettiPainter(_pieces, tones, (p) => curve.transform(((ms - p.delay) / 1050).clamp(0.0, 1.0))),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.tones, this.progress);
  final List<ConfettiPiece> pieces;
  final List<Color> tones;
  final double Function(ConfettiPiece p) progress;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);
    for (final p in pieces) {
      final v = progress(p);
      final op = _lerpStops(v, const [0, 0.01, 0.55, 1], const [0, 1, 1, 0]);
      if (op <= 0) continue;
      final tx = _lerpStops(v, const [0, 0.55, 1], [0, p.dx.toDouble(), p.dx * 1.15]);
      final ty = _lerpStops(v, const [0, 0.55, 1], [0, p.dy.toDouble(), (p.dy + p.fall).toDouble()]);
      final rot = _lerpStops(v, const [0, 0.55, 1], [0, p.rot * 0.6, p.rot.toDouble()]) * math.pi / 180;
      final sc = _lerpStops(v, const [0, 0.55, 1], const [0.6, 1, 0.9]);
      canvas.save();
      canvas.translate(origin.dx + tx, origin.dy + ty);
      canvas.rotate(rot);
      canvas.scale(sc);
      final paint = Paint()..color = tones[p.tone].withValues(alpha: op);
      final h = p.round ? 6.0 : 9.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 6, height: h), Radius.circular(p.round ? 3 : 1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}

/// Sparks round the picked star or face: out from its edge, 12 px to 36 px, fading.
class RatingSparks extends StatefulWidget {
  final bool top;
  final Color color;
  const RatingSparks({super.key, required this.top, required this.color});

  @override
  State<RatingSparks> createState() => _RatingSparksState();
}

class _RatingSparksState extends State<RatingSparks> with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  late final List<double> _angles = Delight.ratingSparks(widget.top);

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: const Duration(milliseconds: 830));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_reduced(context) && !_clock.isAnimating && _clock.value == 0) _clock.forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return const SizedBox.shrink();
    const curve = Cubic(0.2, 0.8, 0.3, 1);
    return IgnorePointer(
      child: AnimatedBuilder(
        key: const ValueKey('cb-rating-sparks'),
        animation: _clock,
        builder: (_, __) => CustomPaint(
          painter: _SparksPainter(_angles, widget.color, (i) {
            final ms = _clock.value * 830 - 80;
            return curve.transform((ms / (i.isOdd ? 600 : 750)).clamp(0.0, 1.0));
          }),
        ),
      ),
    );
  }
}

class _SparksPainter extends CustomPainter {
  _SparksPainter(this.angles, this.color, this.progress);
  final List<double> angles;
  final Color color;
  final double Function(int i) progress;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < angles.length; i++) {
      final v = progress(i);
      final op = _lerpStops(v, const [0, 0.15, 0.65, 1], const [0, 1, 1, 0]);
      if (op <= 0) continue;
      final size = i.isOdd ? 4.0 : 6.0;
      final ty = _lerpStops(v, const [0, 1], const [-12, -36]);
      final sc = _lerpStops(v, const [0, 1], const [0.4, 0.3]);
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(angles[i] * math.pi / 180);
      canvas.translate(0, ty);
      canvas.scale(sc);
      canvas.drawCircle(Offset.zero, size / 2, Paint()..color = color.withValues(alpha: op));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SparksPainter old) => true;
}

/// "No rush - ...": a soft line under the question, a breathing dot, rising in.
class StallHint extends StatefulWidget {
  final String text;
  final Color accent;
  final Color muted;
  final double indent;
  final TextStyle? font;
  const StallHint({super.key, required this.text, required this.accent, required this.muted, this.indent = 0, this.font});

  @override
  State<StallHint> createState() => _StallHintState();
}

class _StallHintState extends State<StallHint> with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _breathe = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced(context)) {
      _enter.value = 1;
      _breathe.stop();
    } else {
      if (_enter.value == 0 && !_enter.isAnimating) _enter.forward();
      if (!_breathe.isAnimating) _breathe.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = _reduced(context);
    return Semantics(
      liveRegion: true,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _breathe]),
        builder: (_, __) {
          final e = _ease.transform(_enter.value);
          final b = Curves.easeInOut.transform(_breathe.value);
          return Opacity(
            opacity: e,
            child: Transform.translate(
              offset: Offset(0, 4 * (1 - e)),
              child: Padding(
                key: const ValueKey('cb-stall-hint'),
                padding: EdgeInsets.only(top: 8, bottom: 4, left: widget.indent),
                child: Row(
                  children: [
                    Transform.scale(
                      scale: reduced ? 1 : 0.85 + 0.25 * b,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: reduced ? 1 : 0.35 + 0.65 * b),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.text, style: (widget.font ?? const TextStyle()).copyWith(fontSize: 12.5, color: widget.muted))),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Edit": a small muted link right under the latest answer, at its edge.
class ChangeAnswerLink extends StatefulWidget {
  final VoidCallback onPressed;
  final Color muted;
  final TextStyle? font;
  const ChangeAnswerLink({super.key, required this.onPressed, required this.muted, this.font});

  @override
  State<ChangeAnswerLink> createState() => _ChangeAnswerLinkState();
}

class _ChangeAnswerLinkState extends State<ChangeAnswerLink> with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced(context)) {
      _enter.value = 1;
    } else if (_enter.value == 0 && !_enter.isAnimating) {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _enter, curve: _ease),
        child: Padding(
          padding: const EdgeInsets.only(top: 2, right: 18, bottom: 6),
          child: Semantics(
            button: true,
            label: t('chat.changeAnswer'),
            excludeSemantics: true,
            child: InkWell(
              key: const ValueKey('cb-change-answer'),
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(6),
              child: Opacity(
                opacity: 0.85,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('✎', style: TextStyle(fontSize: 11, color: widget.muted)),
                      const SizedBox(width: 3),
                      Text(t('chat.edit'), style: (widget.font ?? const TextStyle()).copyWith(fontSize: 11.5, fontWeight: FontWeight.w500, color: widget.muted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The badge and the burst over the visitor's answer bubble.
class AnswerTouchOverlay extends StatelessWidget {
  final String? reaction;

  /// A new value restarts the burst; null draws none.
  final int? celebrate;
  final Color accent;
  final Color card;

  /// The badge's ring: the chat's background, so it sits cut into the bubble.
  final Color ring;
  final VoidCallback? onBurstDone;
  const AnswerTouchOverlay({super.key, this.reaction, this.celebrate, required this.accent, required this.card, required this.ring, this.onBurstDone});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (celebrate != null) Positioned.fill(child: ConfettiBurst(key: ValueKey('burst-$celebrate'), accent: accent, onDone: onBurstDone)),
        if (reaction != null) Positioned(left: -8, bottom: -14, child: ReactionBadge(emoji: reaction!, card: card, ring: ring)),
      ],
    );
  }
}
