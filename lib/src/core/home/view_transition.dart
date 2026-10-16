/// How the open chat moves between its views - the home screen, the
/// conversation and the help centre - from the owner's setting
/// (customizations.viewTransition, viewTransitionDirection). Ported from the
/// React Native SDK (src/core/viewTransition.ts), itself from the web
/// widget: conferbot-widget src/ts/layout/viewTransition.ts
/// (VIEW_TRANSITIONS, normalizeViewTransition, VIEW_DIRECTIONS,
/// normalizeViewDirection, sweepVector, directionBetween and the "reduced",
/// "fade" and "slide" tracks of playViewTransition).
///
/// The web lays a still copy of the old view (a "ghost") over the panel and
/// animates it away while the new view comes in. A native view has no ghost
/// to copy, so the app plays the new view's half only:
///
///   classic, none   the view switches at once (classic's header drop is the
///                   old widget's own and is not played);
///   fade            the new view fades up from 103.5% over 340ms, 40ms in;
///   slide           it slides in from the sweep's side over 420ms;
///   anything else   (honeycomb - the default -, iris, ripple, cards, blinds,
///                   pixels, flip, mosaic, diamonds, bubbles, stripes, wave,
///                   curtain, shutter): the slide, the calm move closest to
///                   the web's sweeps;
///   reduced motion  a 200ms fade, whatever the owner picked (as the web).
///
/// Pure.
library;

const viewTransitions = [
  'classic',
  'none',
  'slide',
  'fade',
  'iris',
  'ripple',
  'honeycomb',
  'cards',
  'blinds',
  'pixels',
  'flip',
  'mosaic',
  'diamonds',
  'bubbles',
  'stripes',
  'wave',
  'curtain',
  'shutter',
];

/// Unset: the sliding honeycomb ("classic" stays the widget as it always was).
const defaultViewTransition = 'honeycomb';

String normalizeViewTransition(dynamic value) => viewTransitions.contains(value) ? value as String : defaultViewTransition;

/// Which way a transition sweeps. "auto" goes sideways by where the views
/// sit (deeper is to the right); the others are fixed, and coming back
/// plays them in reverse. "tap" (out from the tap) has no tap point here and
/// goes sideways as "auto".
const viewDirections = ['auto', 'ltr', 'rtl', 'ttb', 'btt', 'tap'];

String normalizeViewDirection(dynamic value) => viewDirections.contains(value) ? value as String : 'auto';

/// The sweep as a unit vector for a move forward (+1) or back (-1).
({double x, double y}) sweepVector(dynamic sweep, int dir) {
  final s = normalizeViewDirection(sweep);
  final base = switch (s) {
    'rtl' => (x: -1.0, y: 0.0),
    'ttb' => (x: 0.0, y: 1.0),
    'btt' => (x: 0.0, y: -1.0),
    _ => (x: 1.0, y: 0.0),
  };
  // No negative zero.
  return (x: base.x * dir + 0.0, y: base.y * dir + 0.0);
}

/// Where the views sit, left to right (the web's VIEW_ORDER; the app's help centre is "kb").
const _viewOrder = {'home': 0, 'initial_page': 0, 'chat': 1, 'kb': 2, 'help': 2, 'articles': 2, 'list': 3, 'article': 4};

/// Forward (true) when [to] sits at or past [from].
bool isForward(String from, String to) => (_viewOrder[to] ?? 1) >= (_viewOrder[from] ?? 1);

/// How the new view comes in.
sealed class ViewMotion {
  const ViewMotion();
}

/// At once.
class NoMotion extends ViewMotion {
  const NoMotion();
  @override
  bool operator ==(Object other) => other is NoMotion;
  @override
  int get hashCode => 0;
  @override
  String toString() => 'NoMotion';
}

/// The new view's opacity 0 -> 1, linear.
class ReducedMotion extends ViewMotion {
  const ReducedMotion(this.duration);
  final int duration;
  @override
  bool operator ==(Object other) => other is ReducedMotion && other.duration == duration;
  @override
  int get hashCode => duration;
  @override
  String toString() => 'ReducedMotion($duration)';
}

/// Opacity 0 -> 1 and scale [scaleFrom] -> 1, after [delay].
class FadeMotion extends ViewMotion {
  const FadeMotion({required this.duration, required this.delay, required this.scaleFrom});
  final int duration;
  final int delay;
  final double scaleFrom;
  @override
  bool operator ==(Object other) => other is FadeMotion && other.duration == duration && other.delay == delay && other.scaleFrom == scaleFrom;
  @override
  int get hashCode => Object.hash(duration, delay, scaleFrom);
  @override
  String toString() => 'FadeMotion($duration, $delay, $scaleFrom)';
}

/// In from (dx, dy) times the view's size to its place.
class SlideMotion extends ViewMotion {
  const SlideMotion({required this.duration, required this.dx, required this.dy});
  final int duration;
  final double dx;
  final double dy;
  @override
  bool operator ==(Object other) => other is SlideMotion && other.duration == duration && other.dx == dx && other.dy == dy;
  @override
  int get hashCode => Object.hash(duration, dx, dy);
  @override
  String toString() => 'SlideMotion($duration, $dx, $dy)';
}

/// The web's easings (viewTransition.ts EASE, EASE_IO) as cubic-bezier points.
const viewEase = [0.22, 0.8, 0.24, 1.0];
const viewEaseInOut = [0.6, 0.0, 0.25, 1.0];

/// How the new view comes in when the chat moves from one view to another.
ViewMotion viewMotion(dynamic kind, dynamic sweep, String from, String to, {bool reduced = false}) {
  if (from == to) return const NoMotion();
  final k = normalizeViewTransition(kind);
  if (k == 'classic' || k == 'none') return const NoMotion();
  if (reduced) return const ReducedMotion(200);
  if (k == 'fade') return const FadeMotion(duration: 340, delay: 40, scaleFrom: 1.035);
  final v = sweepVector(sweep, isForward(from, to) ? 1 : -1);
  return SlideMotion(duration: 420, dx: v.x, dy: v.y);
}
