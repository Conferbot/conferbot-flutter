/// The rich steps' cards (web ts/chat/richNodesView.ts): carousel and
/// product cards, a slider, a ranking and a rating matrix. The step's
/// question is its own chat line; these draw what the visitor answers
/// with, in the bot's option look (step_style.dart), and send the answer in
/// the shape the step handlers read (core/nodes/handlers).
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/flow/i18n_en.dart';
import '../../core/nodes/node_ui_state.dart' as ui_state;
import '../../theme/conferbot_theme.dart';
import 'step_style.dart';

/// Opens a card's link button in the browser.
void _open(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  launchUrl(uri, mode: LaunchMode.externalApplication).catchError((Object _) => false);
}

/// "conferbot.com" for a link button's subtitle.
String _host(String url) {
  final m = RegExp(r'^(?:[a-z][a-z0-9+.-]*:)?\/\/([^/?#:]+)', caseSensitive: false).firstMatch(url.trim());
  return m == null ? '' : m.group(1)!.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
}

// ==================== CAROUSEL ====================

/// Cards side by side (carousel-node, product-card-node). A path button
/// answers `{buttonId, cardId}`; a link button opens its page and the step
/// keeps waiting; with no path button, Continue answers `{action: continue}`.
class CarouselNodeWidget extends StatefulWidget {
  final ui_state.CarouselUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  /// Opens a link button (the browser; tests pass their own).
  final void Function(String url) onLink;

  const CarouselNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
    this.onLink = _open,
  });

  @override
  State<CarouselNodeWidget> createState() => _CarouselNodeWidgetState();
}

class _CarouselNodeWidgetState extends State<CarouselNodeWidget> {
  bool _done = false;
  String? _picked;

  void _answer(dynamic response, [String? picked]) {
    if (_done) return;
    setState(() {
      _done = true;
      _picked = picked;
    });
    widget.onResponse(response);
  }

  Widget _card(ui_state.CarouselCard card, StepLook style, double width) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: style.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.line),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 6, offset: Offset(0, 2), spreadRadius: -2)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (card.imageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                color: const Color(0xFFF1F5F9),
                child: Image.network(card.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (card.title.isNotEmpty) Text(card.title, style: style.bold),
                if (card.price != null) ...[
                  const SizedBox(height: 2),
                  Text(card.price!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: style.text)),
                ],
                if (card.description != null) ...[
                  const SizedBox(height: 4),
                  Text(card.description!, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.4, color: style.muted)),
                ],
                for (final b in card.buttons) ...[
                  const SizedBox(height: 8),
                  _button(card, b, style),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(ui_state.CarouselCard card, ui_state.CarouselButton b, StepLook style) {
    final link = b.url != null && b.url!.isNotEmpty;
    if (link) {
      // A link button: opens its page (its site under the label); the step waits.
      final host = _host(b.url!);
      return Material(
        color: style.option,
        borderRadius: BorderRadius.circular(style.radius),
        child: InkWell(
          key: ValueKey('card-btn-${b.id}'),
          borderRadius: BorderRadius.circular(style.radius),
          onTap: () => widget.onLink(b.url!),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.label, style: TextStyle(fontSize: style.fontSize - 0.5, fontWeight: FontWeight.w500, color: style.optionInk)),
                      if (host.isNotEmpty) Text(host, style: TextStyle(fontSize: 11.5, color: style.optionInk.withOpacity(0.7))),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, size: 16, color: style.optionInk.withOpacity(0.8), semanticLabel: t('common.opensNewTab')),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: StepOption(
        key: ValueKey('card-btn-${b.id}'),
        label: b.label,
        style: style,
        expand: true,
        picked: _picked == b.id,
        onPressed: _done ? null : () => _answer({'buttonId': b.id, 'cardId': card.id, 'label': b.label}, b.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = StepLook.of(context, widget.theme, widget.primaryColor);
    final cards = widget.state.cards;
    final width = cards.length == 1 ? 260.0 : 228.0;
    return Padding(
      padding: stepIndent(widget.theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final c in cards) _card(c, style, width)]),
          ),
          if (widget.state.showContinue) ...[
            const SizedBox(height: 10),
            StepButton(
              key: const ValueKey('card-continue'),
              label: t('common.continue'),
              style: style,
              primary: true,
              onPressed: _done ? null : () => _answer({'action': 'continue', 'label': t('common.continue')}),
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== SLIDER ====================

/// A value on a scale (slider-node), sent with its button as `{value}`.
class SliderNodeWidget extends StatefulWidget {
  final ui_state.SliderUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const SliderNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<SliderNodeWidget> createState() => _SliderNodeWidgetState();
}

class _SliderNodeWidgetState extends State<SliderNodeWidget> {
  late double _value = widget.state.defaultValue.toDouble();
  bool _done = false;

  num _snap(num raw) {
    final s = widget.state;
    final step = s.step <= 0 ? 1 : s.step;
    final n = ((raw - s.min) / step).round();
    final v = (s.min + n * step).clamp(s.min, s.max);
    return v == v.roundToDouble() ? v.round() : double.parse(v.toStringAsFixed(6));
  }

  String _label(num v) {
    final s = widget.state;
    if (s.unit.isEmpty) return '$v';
    return s.unitPosition == 'prefix' ? '${s.unit}$v' : '$v ${s.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final style = StepLook.of(context, widget.theme, widget.primaryColor);
    final s = widget.state;
    final min = s.min.toDouble();
    final max = s.max.toDouble() > min ? s.max.toDouble() : min + 1;
    final steps = s.step > 0 ? ((max - min) / s.step).round() : null;
    final shown = _label(_snap(_value));
    return Padding(
      padding: stepIndent(widget.theme),
      child: StepCard(
        style: style,
        done: _done,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(shown,
                key: const ValueKey('slider-value'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: style.text, fontFeatures: const [FontFeature.tabularFigures()])),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: style.accent,
                inactiveTrackColor: style.accent.withOpacity(0.18),
                thumbColor: style.accent,
                overlayColor: style.accent.withOpacity(0.12),
                trackHeight: 4,
                showValueIndicator: ShowValueIndicator.never,
                tickMarkShape: SliderTickMarkShape.noTickMark,
              ),
              child: Slider(
                key: const ValueKey('slider'),
                value: _value.clamp(min, max),
                min: min,
                max: max,
                divisions: steps != null && steps > 0 && steps <= 1000 ? steps : null,
                semanticFormatterCallback: (v) => _label(_snap(v)),
                onChanged: _done ? null : (v) => setState(() => _value = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(_label(_snap(min)), style: style.hint), Text(_label(_snap(max)), style: style.hint)],
              ),
            ),
            StepActions(children: [
              StepButton(
                key: const ValueKey('slider-go'),
                label: s.submitLabel.isNotEmpty ? s.submitLabel : t('common.send'),
                style: style,
                primary: true,
                onPressed: _done
                    ? null
                    : () {
                        setState(() => _done = true);
                        widget.onResponse({'value': _snap(_value), 'label': shown});
                      },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ==================== RANKING ====================

/// Items put in order with up / down buttons, sent as `{order: [ids]}`.
class RankingNodeWidget extends StatefulWidget {
  final ui_state.RankingUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const RankingNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<RankingNodeWidget> createState() => _RankingNodeWidgetState();
}

class _RankingNodeWidgetState extends State<RankingNodeWidget> {
  late final List<ui_state.ChoiceOption> _order = List.of(widget.state.items);
  bool _done = false;

  void _move(int i, int dir) {
    final j = i + dir;
    if (j < 0 || j >= _order.length) return;
    setState(() {
      final t0 = _order[i];
      _order[i] = _order[j];
      _order[j] = t0;
    });
  }

  Widget _arrow(Color color, IconData icon, String tip, Key key, VoidCallback? onTap) => SizedBox(
        width: 34,
        height: 34,
        child: IconButton(
          key: key,
          tooltip: tip,
          padding: EdgeInsets.zero,
          iconSize: 20,
          color: color,
          disabledColor: color.withOpacity(0.3),
          onPressed: onTap,
          icon: Icon(icon),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final style = StepLook.of(context, widget.theme, widget.primaryColor);
    return Padding(
      padding: stepIndent(widget.theme),
      child: StepCard(
        style: style,
        done: _done,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_done) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t('ranking.help'), style: style.hint)),
            for (var i = 0; i < _order.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.only(left: 10, right: 2),
                decoration: BoxDecoration(
                  color: style.option,
                  borderRadius: BorderRadius.circular(style.radius),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: style.optionInk.withOpacity(0.12), shape: BoxShape.circle),
                      child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: style.optionInk)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(_order[i].text, style: TextStyle(fontSize: style.fontSize - 0.5, color: style.optionInk)),
                      ),
                    ),
                    if (!_done) ...[
                      _arrow(style.optionInk, Icons.keyboard_arrow_up, t('ranking.moveUp', {'item': _order[i].text}),
                          ValueKey('rank-up-${_order[i].id}'), i == 0 ? null : () => _move(i, -1)),
                      _arrow(style.optionInk, Icons.keyboard_arrow_down, t('ranking.moveDown', {'item': _order[i].text}),
                          ValueKey('rank-down-${_order[i].id}'), i == _order.length - 1 ? null : () => _move(i, 1)),
                    ],
                  ],
                ),
              ),
            StepActions(children: [
              StepButton(
                key: const ValueKey('rank-go'),
                label: widget.state.submitLabel.isNotEmpty ? widget.state.submitLabel : t('common.send'),
                style: style,
                primary: true,
                onPressed: _done
                    ? null
                    : () {
                        setState(() => _done = true);
                        widget.onResponse({
                          'order': [for (final o in _order) o.id],
                          'label': [for (var i = 0; i < _order.length; i++) '${i + 1}. ${_order[i].text}'].join(' · '),
                        });
                      },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ==================== MATRIX ====================

/// Rows rated against columns: one column per row, or several with mode
/// "multiple". Sent as `{cells: {rowId: colId | [colIds]}}`; the step says
/// when rows are missing, and the picks stay for the next try.
class MatrixNodeWidget extends StatefulWidget {
  final ui_state.MatrixUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;
  final String? error;

  const MatrixNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
    this.error,
  });

  @override
  State<MatrixNodeWidget> createState() => _MatrixNodeWidgetState();
}

class _MatrixNodeWidgetState extends State<MatrixNodeWidget> {
  final Map<String, Set<String>> _cells = {};
  bool _sent = false;

  bool get _multiple => widget.state.mode == 'multiple';

  @override
  void didUpdateWidget(MatrixNodeWidget old) {
    super.didUpdateWidget(old);
    if (!identical(old.state, widget.state) || old.error != widget.error) _sent = false;
  }

  void _toggle(String row, String col) {
    setState(() {
      final set = _cells.putIfAbsent(row, () => <String>{});
      if (_multiple) {
        set.contains(col) ? set.remove(col) : set.add(col);
      } else {
        set
          ..clear()
          ..add(col);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = StepLook.of(context, widget.theme, widget.primaryColor);
    final s = widget.state;
    final answered = s.rows.where((r) => (_cells[r.id] ?? const {}).isNotEmpty).length;
    return Padding(
      padding: stepIndent(widget.theme),
      child: StepCard(
        style: style,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_multiple) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t('matrix.pickAny'), style: style.hint)),
            for (final row in s.rows) ...[
              Text(row.text, style: style.bold),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final col in s.columns)
                    StepOption(
                      key: ValueKey('mx-${row.id}-${col.id}'),
                      label: col.text,
                      style: style,
                      picked: _cells[row.id]?.contains(col.id) ?? false,
                      icon: (_cells[row.id]?.contains(col.id) ?? false)
                          ? (_multiple ? Icons.check_box : Icons.radio_button_checked)
                          : (_multiple ? Icons.check_box_outline_blank : Icons.radio_button_unchecked),
                      onPressed: _sent ? null : () => _toggle(row.id, col.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            StepStatus(style: style, error: widget.error),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(child: Text(t('matrix.progress', {'n': answered, 'total': s.rows.length}), style: style.hint)),
                  StepButton(
                    key: const ValueKey('mx-go'),
                    label: s.submitLabel.isNotEmpty ? s.submitLabel : t('common.submit'),
                    style: style,
                    primary: true,
                    onPressed: _sent
                        ? null
                        : () {
                            setState(() => _sent = true);
                            widget.onResponse({
                              'cells': <String, dynamic>{
                                for (final r in s.rows)
                                  if ((_cells[r.id] ?? const {}).isNotEmpty)
                                    r.id: _multiple
                                        ? [for (final c in s.columns) if (_cells[r.id]!.contains(c.id)) c.id]
                                        : _cells[r.id]!.first,
                              },
                            });
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
