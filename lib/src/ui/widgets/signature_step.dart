/// signature-node's card (web richNodesView.ts signatureCardHtml): a pad
/// to sign on with a finger (Undo, Clear), "Type instead" when the step
/// allows typed signatures, the full name when it asks for one, the
/// owner's consent line, then Sign. Sends `{action: sign, method: drawn,
/// dataUrl, width, height}` (a PNG of the strokes, trimmed, dark ink on
/// transparent), `{action: sign, method: drawn, strokes: 0}` for an empty
/// pad, or `{action: sign, method: typed, name}`; `fullName` is added when
/// the step asks for it. The step uploads it and says why one was refused.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/flow/i18n_en.dart';
import '../../core/flow/rich.dart' show cleanSignatureName;
import '../../core/nodes/node_ui_state.dart' as ui_state;
import '../../theme/conferbot_theme.dart';
import 'consent_step.dart' show markdownLiteSpans;
import 'step_style.dart';

/// One stroke, in pad units (x and y as fractions of the pad's width), so a
/// wider pad redraws it at its new size.
typedef SignatureStroke = List<Offset>;

const double _padHeight = 150;
const double _exportPad = 12;
const Color _exportInk = Color(0xFF111827);

Color? _hexOrNull(dynamic raw) {
  final s = '${raw ?? ''}'.trim().replaceFirst('#', '');
  if (s.length != 6 && s.length != 3) return null;
  final full = s.length == 3 ? s.split('').map((c) => '$c$c').join() : s;
  final v = int.tryParse(full, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

/// The smooth path through a stroke (a quadratic from midpoint to midpoint,
/// the real point as the control), as the web pad draws it.
Path signaturePath(SignatureStroke stroke, double scale) {
  final p = Path();
  if (stroke.isEmpty) return p;
  final pts = stroke.map((o) => o * scale).toList();
  p.moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 2) {
    p.lineTo(pts[1].dx, pts[1].dy);
    return p;
  }
  for (var i = 1; i < pts.length - 1; i++) {
    final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
    p.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  p.lineTo(pts.last.dx, pts.last.dy);
  return p;
}

void _paintStrokes(Canvas canvas, List<SignatureStroke> strokes, double scale, Color ink) {
  final line = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final dot = Paint()..color = ink;
  for (final s in strokes) {
    if (s.length == 1) {
      canvas.drawCircle(s.first * scale, 1.6, dot);
    } else if (s.length > 1) {
      canvas.drawPath(signaturePath(s, scale), line);
    }
  }
}

class _PadPainter extends CustomPainter {
  final List<SignatureStroke> strokes;
  final Color ink;
  final int version;

  _PadPainter(this.strokes, this.ink, this.version);

  @override
  void paint(Canvas canvas, Size size) => _paintStrokes(canvas, strokes, size.width, ink);

  @override
  bool shouldRepaint(_PadPainter old) => old.version != version || old.ink != ink;
}

/// The strokes as a PNG data URL, trimmed to the signature with a margin,
/// at twice the pad's size: `{dataUrl, width, height}`, or null with nothing drawn.
Future<Map<String, dynamic>?> exportSignaturePng(List<SignatureStroke> strokes, double padWidth, {Color ink = _exportInk}) async {
  final pts = [for (final s in strokes) ...s.map((o) => o * padWidth)];
  if (pts.isEmpty) return null;
  var minX = pts.first.dx, maxX = pts.first.dx, minY = pts.first.dy, maxY = pts.first.dy;
  for (final p in pts) {
    minX = math.min(minX, p.dx);
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  final left = math.max(0.0, minX - _exportPad);
  final top = math.max(0.0, minY - _exportPad);
  final w = math.max(24.0, maxX - minX + _exportPad * 2);
  final h = math.max(24.0, maxY - minY + _exportPad * 2);
  const k = 2.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(k);
  canvas.translate(-left, -top);
  _paintStrokes(canvas, strokes, padWidth, ink);
  final image = await recorder.endRecording().toImage((w * k).round(), (h * k).round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) return null;
  return {
    'dataUrl': 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}',
    'width': (w * k).round(),
    'height': (h * k).round(),
  };
}

class SignatureNodeWidget extends StatefulWidget {
  final ui_state.TextInputUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;
  final String? error;

  const SignatureNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
    this.error,
  });

  @override
  State<SignatureNodeWidget> createState() => _SignatureNodeWidgetState();
}

class _SignatureNodeWidgetState extends State<SignatureNodeWidget> {
  final List<SignatureStroke> _strokes = [];
  final _typed = TextEditingController();
  final _name = TextEditingController();
  final List<TapGestureRecognizer> _recognizers = [];
  int _version = 0;
  int? _pointer;
  double _padWidth = 280;
  bool _typing = false;
  bool _busy = false;

  Map<String, dynamic> get _cfg => widget.state.extra;
  bool get _allowTyped => _cfg['allowTyped'] != false;
  bool get _requireName => _cfg['requireName'] == true;

  @override
  void didUpdateWidget(SignatureNodeWidget old) {
    super.didUpdateWidget(old);
    // Refused (or the upload failed): the signature stays, Sign works again.
    if (!identical(old.state, widget.state) || old.error != widget.error) _busy = false;
  }

  @override
  void dispose() {
    _typed.dispose();
    _name.dispose();
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Offset _unit(Offset local) => Offset(local.dx.clamp(0, _padWidth) / _padWidth, local.dy.clamp(0, _padHeight) / _padWidth);

  void _down(PointerDownEvent e) {
    if (_busy || _pointer != null) return;
    _pointer = e.pointer;
    setState(() {
      _strokes.add([_unit(e.localPosition)]);
      _version++;
    });
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer || _strokes.isEmpty) return;
    final p = _unit(e.localPosition);
    final last = _strokes.last.last;
    // Points closer than about half a pixel are skipped: smoother lines.
    if ((p - last).distance * _padWidth < 0.6) return;
    setState(() {
      _strokes.last.add(p);
      _version++;
    });
  }

  void _up(PointerEvent e) {
    if (e.pointer == _pointer) _pointer = null;
  }

  Future<void> _sign() async {
    if (_busy) return;
    setState(() => _busy = true);
    final name = _requireName ? {'fullName': cleanSignatureName(_name.text)} : const <String, dynamic>{};
    if (_typing) {
      widget.onResponse({'action': 'sign', 'method': 'typed', 'name': cleanSignatureName(_typed.text), ...name});
      return;
    }
    if (_strokes.isEmpty) {
      widget.onResponse({'action': 'sign', 'method': 'drawn', 'strokes': 0, ...name});
      return;
    }
    final ink = _hexOrNull(_cfg['penColor']) ?? _exportInk;
    final png = await exportSignaturePng(_strokes, _padWidth, ink: ink);
    if (!mounted) return;
    if (png == null) {
      setState(() => _busy = false);
      return;
    }
    widget.onResponse({'action': 'sign', 'method': 'drawn', 'strokes': _strokes.length, ...png, ...name});
  }

  Widget _baseline(StepLook style) => Positioned(
        left: 18,
        right: 18,
        bottom: 30,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('×', style: TextStyle(fontSize: 16, height: 1, color: style.muted)),
            const SizedBox(width: 6),
            Expanded(child: Container(height: 1, color: style.text.withOpacity(0.25))),
          ],
        ),
      );

  Widget _pad(StepLook style) {
    final ink = _hexOrNull(_cfg['penColor']) ?? style.text;
    return LayoutBuilder(builder: (context, c) {
      _padWidth = c.maxWidth.isFinite && c.maxWidth > 0 ? c.maxWidth : 280;
      return Semantics(
        label: t('signature.pad'),
        image: true,
        child: RawGestureDetector(
          // The pad keeps the finger: the chat doesn't scroll while signing.
          gestures: {
            EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
              (_) {},
            ),
          },
          child: Listener(
            key: const ValueKey('sig-pad'),
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            child: Container(
              height: _padHeight,
              decoration: BoxDecoration(
                color: style.text.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: style.text.withOpacity(0.18)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    _baseline(style),
                    if (_strokes.isEmpty)
                      Center(child: Text(t('signature.here'), style: TextStyle(fontSize: 13, color: style.muted))),
                    Positioned.fill(child: CustomPaint(painter: _PadPainter(_strokes, ink, _version))),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _typedPane(StepLook style) {
    final name = cleanSignatureName(_typed.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StepLabel(t('signature.typeToSign'), style: style),
        TextField(
          key: const ValueKey('sig-typed'),
          controller: _typed,
          enabled: !_busy,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          style: TextStyle(fontSize: 15, color: style.text),
          decoration: style.field(hint: t('signature.namePlaceholder')),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _sign(),
        ),
        const SizedBox(height: 8),
        Container(
          height: 104,
          decoration: BoxDecoration(
            color: style.text.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: style.text.withOpacity(0.18)),
          ),
          child: Stack(
            children: [
              _baseline(style),
              Positioned(
                left: 34,
                right: 18,
                bottom: 34,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 34,
                      fontStyle: FontStyle.italic,
                      color: _hexOrNull(_cfg['penColor']) ?? style.text,
                      fontFamilyFallback: const ['Snell Roundhand', 'Bradley Hand', 'Segoe Script', 'cursive'],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = StepLook.of(context, widget.theme, widget.primaryColor);
    final consent = '${_cfg['consentText'] ?? ''}'.trim();
    final submit = '${_cfg['submitLabel'] ?? ''}'.trim();
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    return Padding(
      padding: stepIndent(widget.theme),
      child: StepCard(
        style: style,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_requireName) ...[
              StepLabel(t('signature.fullName'), style: style),
              TextField(
                key: const ValueKey('sig-name'),
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                style: TextStyle(fontSize: 15, color: style.text),
                decoration: style.field(hint: t('signature.namePlaceholder')),
              ),
              const SizedBox(height: 10),
            ],
            if (_typing) _typedPane(style) else _pad(style),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: [
                if (!_typing)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                  StepLink(
                    key: const ValueKey('sig-undo'),
                    label: t('signature.undo'),
                    icon: Icons.undo_rounded,
                    style: style,
                    onPressed: _strokes.isEmpty || _busy
                        ? null
                        : () => setState(() {
                              _strokes.removeLast();
                              _version++;
                            }),
                  ),
                  const SizedBox(width: 10),
                  StepLink(
                    key: const ValueKey('sig-clear'),
                    label: t('signature.clear'),
                    icon: Icons.backspace_outlined,
                    style: style,
                    onPressed: _strokes.isEmpty || _busy
                        ? null
                        : () => setState(() {
                              _strokes.clear();
                              _version++;
                            }),
                  ),
                  ]),
                if (_allowTyped)
                  StepLink(
                    key: const ValueKey('sig-mode'),
                    label: _typing ? t('signature.drawInstead') : t('signature.typeInstead'),
                    icon: _typing ? Icons.draw_outlined : Icons.keyboard_outlined,
                    style: style,
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _typing = !_typing;
                              if (_typing && _typed.text.isEmpty && _name.text.isNotEmpty) _typed.text = _name.text;
                            }),
                  ),
              ],
            ),
            if (consent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text.rich(TextSpan(
                  style: style.hint,
                  children: markdownLiteSpans(
                    consent,
                    linkStyle: const TextStyle(fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                    recognizers: _recognizers,
                  ),
                )),
              ),
            StepStatus(style: style, error: widget.error),
            StepActions(children: [
              StepButton(
                key: const ValueKey('sig-go'),
                label: submit.isNotEmpty ? submit : t('signature.sign'),
                style: style,
                primary: true,
                busy: _busy,
                onPressed: _sign,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
