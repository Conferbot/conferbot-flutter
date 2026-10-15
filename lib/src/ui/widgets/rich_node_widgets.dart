/// The rich steps' cards (web ts/chat/richNodesView.ts): carousel and
/// product cards, a slider, a ranking, a rating matrix and an address.
/// The step's question is its own chat line; these draw what the visitor
/// answers with, and send the answer in the shape the step handlers read
/// (core/nodes/handlers).
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/nodes/node_ui_state.dart' as ui_state;
import '../../theme/conferbot_theme.dart';

EdgeInsets _indent(ConferBotTheme theme) => EdgeInsets.only(left: theme.layout.avatarSize + 10);

ButtonStyle _primary(Color color, ConferBotTheme theme) => ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.borderRadius.md)),
    );

ButtonStyle _option(ConferBotTheme theme) => OutlinedButton.styleFrom(
      backgroundColor: theme.colors.optionBubble,
      foregroundColor: theme.colors.optionBubbleText,
      side: BorderSide(color: theme.colors.border),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.borderRadius.md)),
    );

// ==================== CAROUSEL ====================

/// Cards side by side (carousel-node, product-card-node). A path button
/// answers `{buttonId, cardId}`; a link button opens its page and the step
/// keeps waiting; with no path button, Continue answers `{action: continue}`.
class CarouselNodeWidget extends StatefulWidget {
  final ui_state.CarouselUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const CarouselNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<CarouselNodeWidget> createState() => _CarouselNodeWidgetState();
}

class _CarouselNodeWidgetState extends State<CarouselNodeWidget> {
  bool _done = false;

  void _answer(dynamic response) {
    if (_done) return;
    setState(() => _done = true);
    widget.onResponse(response);
  }

  Widget _card(ui_state.CarouselCard card) {
    final theme = widget.theme;
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
        border: Border.all(color: theme.colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (card.imageUrl != null)
            SizedBox(
              height: 120,
              child: Image.network(card.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (card.title.isNotEmpty)
                  Text(card.title, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colors.text)),
                if (card.price != null) ...[
                  const SizedBox(height: 2),
                  Text(card.price!, style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.w600)),
                ],
                if (card.description != null) ...[
                  const SizedBox(height: 4),
                  Text(card.description!, style: TextStyle(fontSize: theme.typography.fontSizeSm, color: theme.colors.textSecondary)),
                ],
                for (final b in card.buttons) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: _option(theme),
                      onPressed: _done
                          ? null
                          : () {
                              if (b.url != null && b.url!.isNotEmpty) {
                                launchUrl(Uri.parse(b.url!), mode: LaunchMode.externalApplication);
                                return;
                              }
                              _answer({'buttonId': b.id, 'cardId': card.id, 'label': b.label});
                            },
                      child: Text(b.label),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _indent(widget.theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final c in widget.state.cards) _card(c)]),
          ),
          if (widget.state.showContinue) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              style: _primary(widget.primaryColor, widget.theme),
              onPressed: _done ? null : () => _answer(const {'action': 'continue', 'label': 'Continue'}),
              child: const Text('Continue'),
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

  num get _snapped {
    final s = widget.state;
    final step = s.step <= 0 ? 1 : s.step;
    final n = ((_value - s.min) / step).round();
    final v = s.min + n * step;
    final clamped = v.clamp(s.min, s.max);
    return clamped == clamped.roundToDouble() ? clamped.round() : double.parse(clamped.toStringAsFixed(6));
  }

  String get _label {
    final s = widget.state;
    final v = '$_snapped';
    if (s.unit.isEmpty) return v;
    return s.unitPosition == 'prefix' ? '${s.unit}$v' : '$v ${s.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final min = s.min.toDouble();
    final max = s.max.toDouble() > min ? s.max.toDouble() : min + 1;
    final steps = s.step > 0 ? ((max - min) / s.step).round() : null;
    return Padding(
      padding: _indent(widget.theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: widget.theme.colors.text)),
          Slider(
            value: _value.clamp(min, max),
            min: min,
            max: max,
            divisions: steps != null && steps > 0 && steps <= 1000 ? steps : null,
            activeColor: widget.primaryColor,
            onChanged: _done ? null : (v) => setState(() => _value = v),
          ),
          ElevatedButton(
            style: _primary(widget.primaryColor, widget.theme),
            onPressed: _done
                ? null
                : () {
                    setState(() => _done = true);
                    widget.onResponse({'value': _snapped, 'label': _label});
                  },
            child: Text(s.submitLabel),
          ),
        ],
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
      final t = _order[i];
      _order[i] = _order[j];
      _order[j] = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Padding(
      padding: _indent(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _order.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colors.surface,
                borderRadius: BorderRadius.circular(theme.borderRadius.md),
                border: Border.all(color: theme.colors.border),
              ),
              child: Row(
                children: [
                  Text('${i + 1}.', style: TextStyle(color: theme.colors.textSecondary)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_order[i].text, style: TextStyle(color: theme.colors.text))),
                  IconButton(
                    tooltip: 'Move up',
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    onPressed: _done || i == 0 ? null : () => _move(i, -1),
                  ),
                  IconButton(
                    tooltip: 'Move down',
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    onPressed: _done || i == _order.length - 1 ? null : () => _move(i, 1),
                  ),
                ],
              ),
            ),
          ElevatedButton(
            style: _primary(widget.primaryColor, theme),
            onPressed: _done
                ? null
                : () {
                    setState(() => _done = true);
                    widget.onResponse({
                      'order': [for (final o in _order) o.id],
                      'label': [for (var i = 0; i < _order.length; i++) '${i + 1}. ${_order[i].text}'].join(' · '),
                    });
                  },
            child: Text(widget.state.submitLabel),
          ),
        ],
      ),
    );
  }
}

// ==================== MATRIX ====================

/// Rows rated against columns: one column per row, or several with mode
/// "multiple". Sent as `{cells: {rowId: colId | [colIds]}}`; the step says
/// when rows are missing.
class MatrixNodeWidget extends StatefulWidget {
  final ui_state.MatrixUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const MatrixNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<MatrixNodeWidget> createState() => _MatrixNodeWidgetState();
}

class _MatrixNodeWidgetState extends State<MatrixNodeWidget> {
  final Map<String, Set<String>> _cells = {};
  bool _done = false;

  bool get _multiple => widget.state.mode == 'multiple';

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
    final theme = widget.theme;
    final s = widget.state;
    return Padding(
      padding: _indent(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in s.rows) ...[
            Text(row.text, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colors.text)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final col in s.columns)
                  ChoiceChip(
                    label: Text(col.text),
                    selected: _cells[row.id]?.contains(col.id) ?? false,
                    selectedColor: widget.primaryColor.withOpacity(0.2),
                    onSelected: _done ? null : (_) => _toggle(row.id, col.id),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton(
            style: _primary(widget.primaryColor, theme),
            onPressed: _done
                ? null
                : () {
                    final cells = <String, dynamic>{
                      for (final e in _cells.entries)
                        if (e.value.isNotEmpty) e.key: _multiple ? e.value.toList() : e.value.first,
                    };
                    final answered = cells.length;
                    // The step refuses a missing row and keeps waiting.
                    if (!s.requireAll || answered == s.rows.length) setState(() => _done = true);
                    widget.onResponse({'cells': cells});
                  },
            child: Text(s.submitLabel),
          ),
        ],
      ),
    );
  }
}

// ==================== ADDRESS ====================

/// An address: searched and picked (`{action: search, q}`, then
/// `{action: pick, index}`), or typed field by field (`{action: manual,
/// line1, city, region, postal, country}`).
class AddressNodeWidget extends StatefulWidget {
  final ui_state.AddressUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const AddressNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<AddressNodeWidget> createState() => _AddressNodeWidgetState();
}

class _AddressNodeWidgetState extends State<AddressNodeWidget> {
  final _search = TextEditingController();
  final _fields = {
    'line1': TextEditingController(),
    'city': TextEditingController(),
    'region': TextEditingController(),
    'postal': TextEditingController(),
    'country': TextEditingController(),
  };
  bool _manual = false;
  bool _done = false;

  static const _labels = {
    'line1': 'Street address',
    'city': 'City',
    'region': 'State / region',
    'postal': 'Postal code',
    'country': 'Country',
  };

  @override
  void dispose() {
    _search.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(widget.theme.borderRadius.md)),
      );

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final results = widget.state.results;
    return Padding(
      padding: _indent(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_manual) ...[
            TextField(
              controller: _search,
              enabled: !_done,
              decoration: _decoration('Search your address'),
              textInputAction: TextInputAction.search,
              onSubmitted: (q) {
                if (q.trim().length >= 3) widget.onResponse({'action': 'search', 'q': q.trim()});
              },
            ),
            for (var i = 0; i < results.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text('${results[i]['formatted'] ?? results[i]['display'] ?? results[i]['line1'] ?? ''}'),
                onTap: _done
                    ? null
                    : () {
                        setState(() => _done = true);
                        widget.onResponse({'action': 'pick', 'index': i});
                      },
              ),
            if (widget.state.allowManualEntry)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: _done ? null : () => setState(() => _manual = true), child: const Text('Enter it manually')),
              ),
          ] else ...[
            for (final e in _fields.entries) ...[
              TextField(controller: e.value, enabled: !_done, decoration: _decoration(_labels[e.key]!)),
              const SizedBox(height: 6),
            ],
            ElevatedButton(
              style: _primary(widget.primaryColor, theme),
              onPressed: _done
                  ? null
                  : () => widget.onResponse({
                        'action': 'manual',
                        for (final e in _fields.entries) e.key: e.value.text.trim(),
                      }),
              child: const Text('Send'),
            ),
          ],
        ],
      ),
    );
  }
}
