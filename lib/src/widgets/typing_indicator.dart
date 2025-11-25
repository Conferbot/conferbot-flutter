import 'package:flutter/material.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';

/// Animated typing indicator widget
class TypingIndicator extends StatefulWidget {
  final bool visible;
  final Color? dotColor;
  final double dotSize;
  final int animationSpeed;
  final ConferBotTheme? theme;

  const TypingIndicator({
    super.key,
    this.visible = true,
    this.dotColor,
    this.dotSize = 8.0,
    this.animationSpeed = 600,
    this.theme,
  });

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
