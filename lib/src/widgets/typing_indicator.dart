import 'package:flutter/material.dart';
import '../core/customization/mascot_art.dart';
import '../core/customization/mascot_moods.dart';
import '../core/i18n/i18n.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';
import 'mascot/typing_mascot.dart';

/// Animated typing indicator widget
class TypingIndicator extends StatefulWidget {
  final bool visible;
  final Color? dotColor;
  final double dotSize;
  final int animationSpeed;
  final ConferBotTheme? theme;

  /// The owner's typing style (typingStyle, web chatChrome.ts): dots, an
  /// equaliser wave, a shimmering "Typing...", a pencil writing a line, or
  /// the bot's mascot swaying beside three thought dots.
  final String style;

  /// The owner's mascot, for the mascot style ("Pip is typing" when named); the classic blob when null.
  final MascotLook? mascot;

  /// The mascot's colour when the owner chose none, and the pencil's (the launcher's).
  final String? accent;

  /// Overrides the phone's reduce-motion setting (tests).
  final bool? reduceMotion;

  const TypingIndicator({
    super.key,
    this.visible = true,
    this.dotColor,
    this.dotSize = 8.0,
    this.animationSpeed = 600,
    this.theme,
    this.style = 'dots',
    this.mascot,
    this.accent,
    this.reduceMotion,
  });

  /// "Pip is typing" when the owner named their mascot (chatChrome.ts typingBubbleHtml), else "Agent is typing".
  String get label => style == 'mascot' && (mascot?.name.isNotEmpty ?? false) ? typingLabel('mascot', mascot!.name) : t('typing.named', {'name': t('agent.agent')});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;
  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    final duration = Duration(milliseconds: widget.animationSpeed);

    _controller1 = AnimationController(vsync: this, duration: duration)
      ..repeat(reverse: true);
    _controller2 = AnimationController(vsync: this, duration: duration)
      ..repeat(reverse: true);
    _controller3 = AnimationController(vsync: this, duration: duration)
      ..repeat(reverse: true);

    _animation1 = Tween<double>(begin: 0.3, end: 1.0).animate(_controller1);
    _animation2 = Tween<double>(begin: 0.3, end: 1.0).animate(_controller2);
    _animation3 = Tween<double>(begin: 0.3, end: 1.0).animate(_controller3);

    // Stagger the animations
    Future.delayed(Duration(milliseconds: widget.animationSpeed ~/ 3), () {
      if (mounted) _controller2.forward();
    });
    Future.delayed(Duration(milliseconds: widget.animationSpeed * 2 ~/ 3), () {
      if (mounted) _controller3.forward();
    });
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) {
      return const SizedBox.shrink();
    }

    final effectiveTheme = widget.theme ?? defaultTheme;
    final effectiveColor = widget.dotColor ?? effectiveTheme.colors.textSecondary;
    final reduced = widget.reduceMotion ?? MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final primary = effectiveTheme.colors.primary;
    final accent = widget.accent ?? '#${(primary.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

    if (widget.style == 'mascot') {
      return Semantics(
        label: widget.label,
        liveRegion: true,
        child: TypingMascot(look: widget.mascot ?? const MascotLook(), accent: accent, ink: effectiveColor, reduced: reduced),
      );
    }
    if (widget.style == 'pencil') {
      return Semantics(
        label: widget.label,
        liveRegion: true,
        child: TypingPencil(accent: accent, ink: effectiveColor, reduced: reduced),
      );
    }

    if (widget.style == 'shimmer') {
      return FadeTransition(
        opacity: _animation1,
        child: Text('${t('typing.typing')}...', style: TextStyle(color: effectiveColor, fontSize: 13, fontWeight: FontWeight.w600)),
      );
    }
    if (widget.style == 'wave') {
      final bars = [_animation1, _animation2, _animation3, _animation2, _animation1];
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < bars.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            AnimatedBuilder(
              animation: bars[i],
              builder: (_, __) => Container(
                width: 3,
                height: 16 * bars[i].value,
                decoration: BoxDecoration(color: effectiveColor.withOpacity(0.85), borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(_animation1, effectiveColor),
        SizedBox(width: effectiveTheme.spacing.xs),
        _buildDot(_animation2, effectiveColor),
        SizedBox(width: effectiveTheme.spacing.xs),
        _buildDot(_animation3, effectiveColor),
      ],
    );
  }

  Widget _buildDot(Animation<double> animation, Color color) {
    return FadeTransition(
      opacity: animation,
      child: Container(
        width: widget.dotSize,
        height: widget.dotSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
