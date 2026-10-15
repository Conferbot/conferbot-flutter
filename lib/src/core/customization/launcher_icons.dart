/// The web widget's launcher icons as flat draw operations on a 24x24 grid
/// (generated from conferbot-widget src/svg/launcher): a path, its 2x3
/// transform, fill and stroke ("ink" = the launcher's icon colour, "bg" =
/// the launcher's own colour, or a hex; or a gradient), opacity, clip and the
/// motion part it belongs to. Pure data; the launcher's painter draws it.
library;

import 'dart:convert';

import 'launcher_icons_data.dart';

class IconPaint {
  final String? c;
  final int? g;
  final double a;
  const IconPaint({this.c, this.g, this.a = 1});
  factory IconPaint.fromJson(Map<String, dynamic> j) => IconPaint(c: j['c'] as String?, g: j['g'] as int?, a: (j['a'] as num?)?.toDouble() ?? 1);
}

class IconStop {
  final double o;
  final String c;
  final double a;
  const IconStop(this.o, this.c, this.a);
}

class IconGradient {
  final String t;
  final double x1, y1, x2, y2, cx, cy, r;
  final List<IconStop> stops;
  const IconGradient({required this.t, this.x1 = 0, this.y1 = 0, this.x2 = 1, this.y2 = 0, this.cx = .5, this.cy = .5, this.r = .5, required this.stops});
  factory IconGradient.fromJson(Map<String, dynamic> j) {
    double n(String k, double d) => (j[k] as num?)?.toDouble() ?? d;
    return IconGradient(
      t: j['t'] as String,
      x1: n('x1', 0), y1: n('y1', 0), x2: n('x2', 1), y2: n('y2', 0),
      cx: n('cx', .5), cy: n('cy', .5), r: n('r', .5),
      stops: (j['stops'] as List).map((s) => IconStop((s['o'] as num).toDouble(), s['c'] as String, (s['a'] as num).toDouble())).toList(),
    );
  }
}

/// An animated group a shape sits in, outer first (see launcher_motion.dart).
class IconPart {
  /// Its motion classes ("cbl-eye", "cbl-conf>*"...).
  final List<String> c;

  /// Group id: its box in LauncherIcon.boxes is the transform origin's box.
  final int g;
  final double? dx, dy;

  /// Its own transform attribute (an animation on it replaces this).
  final List<double>? t;

  /// No class of its own: it turns about the icon's origin.
  final bool unclassed;

  /// Its own opacity attribute (an animated opacity replaces this).
  final double? o;

  /// The static transform between the previous part and this one.
  final List<double>? pre;

  const IconPart({required this.c, required this.g, this.dx, this.dy, this.t, this.unclassed = false, this.o, this.pre});

  static List<double>? _m(dynamic v) => (v as List?)?.map((x) => (x as num).toDouble()).toList();

  factory IconPart.fromJson(Map<String, dynamic> j) => IconPart(
        c: (j['c'] as List).cast<String>(),
        g: j['g'] as int,
        dx: (j['dx'] as num?)?.toDouble(),
        dy: (j['dy'] as num?)?.toDouble(),
        t: _m(j['t']),
        unclassed: j['u'] == 1,
        o: (j['o'] as num?)?.toDouble(),
        pre: _m(j['pre']),
      );
}

class IconOp {
  final String d;
  final List<double>? m;
  final IconPaint? fill;
  final IconPaint? stroke;
  final double sw;
  final String? cap;
  final String? join;
  final double? op;
  final bool evenOdd;
  final bool strokeFirst;
  final String? clip;

  /// How many of the parts the clip moves with.
  final int clipDepth;

  /// The shape itself is the innermost animated element.
  final bool self;

  /// The opacity from elements that are not animated parts (when it differs from op).
  final double? opRest;

  /// The static transform after the last part, down to the shape.
  final List<double>? post;
  final List<IconPart> parts;

  const IconOp({required this.d, this.m, this.fill, this.stroke, this.sw = 1, this.cap, this.join, this.op, this.evenOdd = false, this.strokeFirst = false, this.clip, this.clipDepth = 0, this.self = false, this.opRest, this.post, this.parts = const []});

  factory IconOp.fromJson(Map<String, dynamic> j) => IconOp(
        d: j['d'] as String,
        m: (j['m'] as List?)?.map((v) => (v as num).toDouble()).toList(),
        fill: j['fill'] == null ? null : IconPaint.fromJson(j['fill'] as Map<String, dynamic>),
        stroke: j['stroke'] == null ? null : IconPaint.fromJson(j['stroke'] as Map<String, dynamic>),
        sw: (j['sw'] as num?)?.toDouble() ?? 1,
        cap: j['cap'] as String?,
        join: j['join'] as String?,
        op: (j['op'] as num?)?.toDouble(),
        evenOdd: j['rule'] == 'evenodd',
        strokeFirst: j['strokeFirst'] == true,
        clip: j['clip'] as String?,
        clipDepth: (j['clipDepth'] as int?) ?? 0,
        self: j['self'] == 1,
        opRest: (j['opRest'] as num?)?.toDouble(),
        post: (j['post'] as List?)?.map((x) => (x as num).toDouble()).toList(),
        parts: ((j['parts'] as List?) ?? const []).map((p) => IconPart.fromJson(p as Map<String, dynamic>)).toList(),
      );
}

class LauncherIcon {
  final String id;
  final String anim;
  final List<IconGradient> grads;
  final List<IconOp> ops;

  /// Each animated group's box (and 0, the whole icon): x, y, width, height.
  final Map<int, List<double>> boxes;
  const LauncherIcon(this.id, this.anim, this.grads, this.ops, [this.boxes = const {}]);
}

class LauncherIcons {
  LauncherIcons._();

  /// The icon a bot without one (or with an unknown id) draws, as on the web.
  static const defaultIcon = 'WidgetBubbleIcon40';

  static final List<LauncherIcon> all = (jsonDecode(launcherIconsJson) as List).map((i) {
    final j = i as Map<String, dynamic>;
    return LauncherIcon(
      j['id'] as String,
      j['anim'] as String,
      (j['grads'] as List).map((g) => IconGradient.fromJson(g as Map<String, dynamic>)).toList(),
      (j['ops'] as List).map((o) => IconOp.fromJson(o as Map<String, dynamic>)).toList(),
      ((j['boxes'] as Map?) ?? const {}).map((k, v) => MapEntry(int.parse(k as String), (v as List).map((x) => (x as num).toDouble()).toList())),
    );
  }).toList();

  static final Map<String, LauncherIcon> _byId = {for (final i in all) i.id: i};

  static LauncherIcon byId(String? id) => (id != null ? _byId[id] : null) ?? _byId[defaultIcon]!;
}
