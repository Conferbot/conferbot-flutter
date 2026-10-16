/// The owner's mascot drawn (the React Native SDK's components/Mascot
/// MascotFigure.tsx, useMascotMood.ts, Mascot.tsx): its layers
/// (core/customization/mascot_art.dart) stacked back to front in a
/// size x size box by widgets/fx_svg.dart, each moving part turned about its
/// own joint by the values the evaluator gives it at the clock's time, and
/// [Mascot], the public widget for an app's own screens, in one of its moods
/// (core/customization/mascot_moods.dart). Reduced motion: still, the happy
/// smile kept.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/customization/keyframes.dart';
import '../../core/customization/mascot_art.dart';
import '../../core/customization/mascot_moods.dart';
import '../fx_svg.dart';

/// A part's values at a moment and the order its transform list draws in (keyframes.dart transformOrder).
class MascotPart {
  final FxValues v;
  final String order;
  const MascotPart(this.v, [this.order = 'trs']);
}

/// Moves the canvas as CSS moves a box: about (ox, oy) px, the functions in
/// [order] ("t" translate, "r" rotate, "s" scale), translations in the
/// drawing's units times [k] px.
void applyFxTransform(Canvas c, FxValues v, String order, double ox, double oy, [double k = 1]) {
  c.translate(ox, oy);
  for (final op in order.split('')) {
    if (op == 't') {
      if (v.tx != 0 || v.ty != 0) c.translate(v.tx * k, v.ty * k);
    } else if (op == 'r') {
      if (v.r != 0) c.rotate(v.r * math.pi / 180);
    } else if (op == 's') {
      if (v.sx != 1 || v.sy != 1) c.scale(v.sx, v.sy);
    }
  }
  c.translate(-ox, -oy);
}

/// The same as a matrix, for a [Transform] (about (ox, oy) px in its child).
Matrix4 fxTransformMatrix(FxValues v, String order, double ox, double oy, [double k = 1]) {
  final m = Matrix4.identity()..translateByDouble(ox, oy, 0, 1);
  for (final op in order.split('')) {
    if (op == 't') m.translateByDouble(v.tx * k, v.ty * k, 0, 1);
    if (op == 'r') m.rotateZ(v.r * math.pi / 180);
    if (op == 's') m.scaleByDouble(v.sx, v.sy, 1, 1);
  }
  return m..translateByDouble(-ox, -oy, 0, 1);
}

/// A box moved and faded by its values (a card, the greeting's figure, a word), about [origin] px (its centre when null).
Widget fxBox(MascotPart? p, Widget child, {Offset? origin, Size? size}) {
  if (p == null) return child;
  final v = p.v;
  Widget out = child;
  final moved = v.tx != 0 || v.ty != 0 || v.r != 0 || v.sx != 1 || v.sy != 1;
  if (moved) {
    out = origin != null
        ? Transform(transform: fxTransformMatrix(v, p.order, origin.dx, origin.dy), child: out)
        : Transform(alignment: Alignment.center, transform: fxTransformMatrix(v, p.order, 0, 0), child: out);
  }
  if (v.o < 0.999) out = Opacity(opacity: v.o.clamp(0.0, 1.0).toDouble(), child: out);
  return out;
}

/// The drawing's parts at a moment: each part's values (body, arm, look, lid,
/// brow, shadow; the idle call also smile, o, grin) and the big smile.
class MascotPose {
  final Map<String, MascotPart> parts;
  final bool grin;
  const MascotPose([this.parts = const {}, this.grin = false]);

  /// The same pose (nothing to redraw).
  bool same(MascotPose? o) {
    if (o == null || o.grin != grin || o.parts.length != parts.length) return false;
    for (final e in parts.entries) {
      final b = o.parts[e.key];
      if (b == null || b.order != e.value.order) return false;
      for (var i = 0; i < e.value.v.v.length; i++) {
        if ((e.value.v.v[i] - b.v.v[i]).abs() > 1e-4) return false;
      }
    }
    return true;
  }
}

/// Paints the mascot's layers in a size x size box at the canvas origin
/// (MascotFigure.tsx): the shadow; then, moving with the body, the tail, the
/// arm behind, the body, the pupils, the sleepy lids, the blinking lids
/// (resting open, scaleY 0: drawn only when a part moves them), the shades
/// and cheeks, the brows, the arm in front, the three mouths (the usual
/// smile, or the big one for `grin`; the o only when a part shows it) and
/// what it holds and wears.
void paintMascot(Canvas canvas, MascotLayers layers, double size, {bool bust = false, MascotJoints? joints, MascotPose pose = const MascotPose(), double shadowY = 95}) {
  final j = joints ?? mascotBlobOrigins;
  final k = mascotUnit(size, bust);
  final box = Size(size, size);
  void layer(String? svg, [String? part, (double, double)? pivot, FxValues? rest]) {
    if (svg == null) return;
    final p = part == null ? null : pose.parts[part];
    final v = p?.v ?? rest;
    if (v != null && (v.o <= 0.002 || v.sx.abs() < 1e-6 || v.sy.abs() < 1e-6)) return;
    canvas.save();
    if (v != null && p != null) {
      final at = mascotPoint(pivot ?? (50, 50), size, bust);
      applyFxTransform(canvas, v, p.order, at.$1, at.$2, k);
    }
    final fade = v != null && v.o < 0.998;
    if (fade) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, v.o));
    drawFxSvg(canvas, svg, box);
    if (fade) canvas.restore();
    canvas.restore();
  }

  layer(layers.shadow, 'shadow', (50, shadowY));
  canvas.save();
  final b = pose.parts['body'];
  if (b != null) {
    final at = mascotPoint(j.body, size, bust);
    applyFxTransform(canvas, b.v, b.order, at.$1, at.$2, k);
  }
  layer(layers.tail);
  layer(layers.armBack, 'arm', j.arm);
  layer(layers.body);
  layer(layers.look, 'look', j.look);
  layer(layers.face);
  if (pose.parts['lid'] != null) layer(layers.lids, 'lid', j.lid);
  layer(layers.cover);
  layer(layers.brows, 'brow', j.brow);
  layer(layers.armFront, 'arm', j.arm);
  layer(layers.smile, 'smile', null, FxValues.rest({'o': pose.grin ? 0 : 1}));
  if (pose.parts['o'] != null) layer(layers.o, 'o');
  if (pose.parts['grin'] != null || pose.grin) layer(layers.grin, 'grin');
  layer(layers.top);
  canvas.restore();
}

class MascotPainter extends CustomPainter {
  final MascotLayers layers;
  final bool bust;
  final MascotJoints joints;
  final double shadowY;
  final ValueListenable<MascotPose> pose;
  MascotPainter(this.layers, this.pose, {this.bust = false, required this.joints, this.shadowY = 95}) : super(repaint: pose);

  @override
  void paint(Canvas canvas, Size size) => paintMascot(canvas, layers, math.min(size.width, size.height), bust: bust, joints: joints, pose: pose.value, shadowY: shadowY);

  @override
  bool shouldRepaint(MascotPainter old) => old.layers != layers || old.pose != pose || old.bust != bust || old.joints != joints;
}

/// Time for the mascot's clocks (ms), from a ticker that runs only while
/// something moves; it carries on from where it was when it starts again.
class FxTime {
  FxTime(TickerProvider vsync, this.onFrame) {
    _ticker = vsync.createTicker(_tick);
  }
  late final Ticker _ticker;
  final VoidCallback onFrame;
  double _base = 0, _last = 0;

  double get now => _base + _last;
  bool get running => _ticker.isActive;

  void _tick(Duration d) {
    _last = d.inMicroseconds / 1000;
    onFrame();
  }

  void start() {
    if (_ticker.isActive) return;
    _base += _last;
    _last = 0;
    _ticker.start();
  }

  void stop() {
    if (_ticker.isActive) _ticker.stop();
  }

  void dispose() => _ticker.dispose();
}

/// A clock that runs once ([play]), or an intro then a loop forever
/// ([loop]), and stays where it is when stopped (fxAnimated.ts FxClock).
class FxClock {
  FxClock(this.time);
  final FxTime time;
  double _t0 = 0, _frozen = 0, _intro = 0, _period = 0;
  double? _end;
  bool _running = false, _looping = false;
  VoidCallback? _done;

  bool get running => _running;

  void play(double end, [VoidCallback? done]) {
    _t0 = time.now;
    _end = end;
    _looping = false;
    _running = true;
    _done = done;
    time.start();
  }

  void loop(double intro, double period) {
    _t0 = time.now;
    _intro = intro;
    _period = period;
    _looping = period > 0;
    _end = period > 0 ? null : intro;
    _running = true;
    _done = null;
    time.start();
  }

  void stop() {
    _frozen = t;
    _running = false;
  }

  /// A loop runs on to the end of its lap (an exhale, a syllable), then stops there.
  void finishLap([VoidCallback? done]) {
    if (!_running || !_looping) return;
    final cur = t;
    _t0 = time.now - cur;
    _end = cur < _intro ? _intro : _intro + _period;
    _looping = false;
    _done = done;
  }

  /// The clock's time (ms).
  double get t {
    if (!_running) return _frozen;
    final e = time.now - _t0;
    if (_looping) return e < _intro + _period ? e : _intro + (e - _intro) % _period;
    return math.min(e, _end ?? e);
  }

  /// Each frame: a run that has reached its end stops there and says so.
  void tick() {
    if (!_running || _looping || _end == null) return;
    if (time.now - _t0 >= _end!) {
      _frozen = _end!;
      _running = false;
      final d = _done;
      _done = null;
      d?.call();
    }
  }
}

/// Each mood part's own value at rest: the lids open (scaleY 0, as drawn on the web).
const _moodBase = {
  'lid': {'sy': 0.0},
};

/// A mood plan's parts at [t] ms.
MascotPose moodPose(MoodPlan plan, double t) => MascotPose({
      for (final e in plan.parts.entries)
        if (e.value.isNotEmpty) e.key: MascotPart(evaluate(e.value, t, _moodBase[e.key]), transformOrder(e.value.first)),
    }, plan.grin);

/// The owner's mascot (web art3d.ts mascot()) for an app's own screens -
/// the home screen's `mascotBuilder`, say - in one of its moods: idle
/// (blinks), wave, think or happy. One clock plays the mood's finite part,
/// then loops a lap of what goes on (the blink). Reduced motion (the
/// phone's, or [reduceMotion]): still, the happy smile kept.
class Mascot extends StatefulWidget {
  /// The owner's mascot (`ConferBotProvider.customizations.mascot`, or `HomeModel.mascot.look`).
  final MascotLook look;

  /// The colour it is drawn in when the owner chose none (the launcher's).
  final String accent;

  /// The box's side (px).
  final double size;

  /// idle, wave, think or happy.
  final String mood;

  /// The arm's pose (the whole figure only): wave when waving, else down.
  final String? arm;

  /// Head and body only, framed tight.
  final bool bust;

  /// How many waves before it rests (wave); on and on when null.
  final double? waveCount;

  /// False: drawn still, the mood's clock off.
  final bool enabled;

  /// Overrides the phone's reduce-motion setting (tests).
  final bool? reduceMotion;

  const Mascot({
    super.key,
    required this.look,
    required this.accent,
    this.size = 64,
    this.mood = 'idle',
    this.arm,
    this.bust = false,
    this.waveCount,
    this.enabled = true,
    this.reduceMotion,
  });

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final FxTime _time = FxTime(this, _frame);
  late final FxClock _clock = FxClock(_time);
  final ValueNotifier<MascotPose> _pose = ValueNotifier(const MascotPose());
  MascotLayers? _layers;
  String _layersKey = '';
  MoodPlan? _plan;
  String _planKey = '';

  String get _arm => widget.arm ?? (widget.mood == 'wave' ? 'wave' : 'down');

  void _frame() {
    final p = _plan;
    if (p == null) return;
    _clock.tick();
    final next = moodPose(p, _clock.t);
    if (!next.same(_pose.value)) _pose.value = next;
  }

  void _sync(bool reduced) {
    final key = '${widget.mood} $_arm ${widget.bust} ${widget.waveCount} $reduced ${widget.enabled}';
    if (key == _planKey) return;
    _planKey = key;
    final plan = moodPlan(widget.mood, arm: _arm, bust: widget.bust, waveCount: widget.waveCount ?? double.infinity, reduced: reduced);
    _plan = plan;
    final moving = widget.enabled && plan.parts.isNotEmpty;
    if (moving) {
      _clock.loop(plan.settle, plan.period);
      _pose.value = moodPose(plan, 0);
    } else {
      _clock.stop();
      _time.stop();
      _pose.value = MascotPose(const {}, plan.grin);
    }
  }

  @override
  void dispose() {
    _time.dispose();
    _pose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = widget.reduceMotion ?? MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sync(reduced);
    final key = '${widget.accent} $_arm ${widget.look.hashCode} ${widget.bust}';
    if (key != _layersKey || _layers == null) {
      _layersKey = key;
      _layers = mascotLayers(widget.accent, _arm, widget.look, widget.bust);
    }
    return IgnorePointer(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          key: const ValueKey('cb-mascot'),
          painter: MascotPainter(_layers!, _pose, bust: widget.bust, joints: mascotOrigins(widget.look), shadowY: widget.look.shape == 'ghost' ? 99 : 95),
        ),
      ),
    );
  }
}
