/// The open chat's views - the home screen, the conversation, the help
/// centre - switching in the owner's transition (core/home/view_transition.dart;
/// web ts/layout/viewTransition.ts; RN components/Home/ViewSwitch.tsx).
///
/// An AnimatedSwitcher that draws the new view only (a native view has no
/// still copy of the old one to animate away, so the old view goes at once):
/// fade (opacity and 103.5% -> 100% over 340ms, 40ms in), slide (in from the
/// sweep's side over 420ms; every other kind slides too), at once for
/// classic and none, and a 200ms fade with the phone's animations off
/// (`MediaQuery.disableAnimations`), whatever the owner picked.
library;

import 'package:flutter/material.dart';

import '../../core/home/home.dart' show HomeView;
import '../../core/home/view_transition.dart';

class ViewSwitch extends StatefulWidget {
  const ViewSwitch({
    super.key,
    required this.view,
    required this.child,
    this.transition,
    this.direction,
  });

  /// The view on screen; a change plays the transition.
  final HomeView view;

  /// That view, drawn.
  final Widget child;

  /// The owner's `viewTransition` and `viewTransitionDirection`.
  final dynamic transition;
  final dynamic direction;

  @override
  State<ViewSwitch> createState() => _ViewSwitchState();
}

class _ViewSwitchState extends State<ViewSwitch> {
  ViewMotion _motion = const NoMotion();

  static String _name(HomeView v) => switch (v) {
        HomeView.home => 'home',
        HomeView.chat => 'chat',
        HomeView.help => 'help',
      };

  @override
  void didUpdateWidget(ViewSwitch old) {
    super.didUpdateWidget(old);
    if (old.view != widget.view) {
      _motion = viewMotion(widget.transition, widget.direction, _name(old.view), _name(widget.view),
          reduced: MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    }
  }

  Duration get _duration => switch (_motion) {
        NoMotion() => Duration.zero,
        ReducedMotion(:final duration) => Duration(milliseconds: duration),
        FadeMotion(:final duration, :final delay) => Duration(milliseconds: duration + delay),
        SlideMotion(:final duration) => Duration(milliseconds: duration),
      };

  Widget _transition(Widget child, Animation<double> animation) {
    final m = _motion;
    switch (m) {
      case NoMotion():
        return child;
      case ReducedMotion():
        return FadeTransition(opacity: animation, child: child);
      case FadeMotion():
        final t = CurvedAnimation(
          parent: animation,
          curve: Interval(m.delay / (m.duration + m.delay), 1, curve: Cubic(viewEase[0], viewEase[1], viewEase[2], viewEase[3])),
        );
        return FadeTransition(
          opacity: t,
          child: ScaleTransition(scale: Tween<double>(begin: m.scaleFrom, end: 1).animate(t), child: child),
        );
      case SlideMotion():
        final t = CurvedAnimation(parent: animation, curve: Cubic(viewEaseInOut[0], viewEaseInOut[1], viewEaseInOut[2], viewEaseInOut[3]));
        return ClipRect(
          child: SlideTransition(position: Tween<Offset>(begin: Offset(m.dx, m.dy), end: Offset.zero).animate(t), child: child),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _duration,
      reverseDuration: Duration.zero,
      transitionBuilder: _transition,
      // Only the new view: the old one is gone at once.
      layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
      child: KeyedSubtree(key: ValueKey(widget.view), child: widget.child),
    );
  }
}
