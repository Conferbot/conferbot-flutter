/// address-node's card (web richNodesView.ts addressCardHtml): a search
/// with suggestions as the visitor types (the words they typed in bold),
/// a picked address confirmed on a small map with a pin, or the address
/// typed by hand. Sends `{action: search, q}`, `{action: pick, index}`
/// (after Confirm) and `{action: manual, line1, city, region, postal,
/// country}`; the step searches on the server and says why one was refused.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/constants.dart' show ConferBotEndpoints;
import '../../core/flow/i18n_en.dart';
import '../../core/flow/rich.dart' show osmLink, osmTile, tileSrc;
import '../../core/nodes/node_ui_state.dart' as ui_state;
import '../../theme/conferbot_theme.dart';
import 'consent_step.dart' show openStepLink;
import 'step_style.dart';

/// Search after the visitor stops typing for this long (web ADDRESS_DEBOUNCE_MS).
const Duration addressDebounce = Duration(milliseconds: 300);
const int _minChars = 3;

/// The text with the typed words (two letters or more) in bold.
List<TextSpan> highlightMatch(String text, String query, TextStyle bold) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'[\s,]+'))
      .where((w) => w.length >= 2)
      .map(RegExp.escape)
      .toList();
  if (words.isEmpty) return [TextSpan(text: text)];
  final re = RegExp('(${words.join('|')})', caseSensitive: false);
  final out = <TextSpan>[];
  var at = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > at) out.add(TextSpan(text: text.substring(at, m.start)));
    out.add(TextSpan(text: m.group(0), style: bold));
    at = m.end;
  }
  if (at < text.length) out.add(TextSpan(text: text.substring(at)));
  return out;
}

/// A small static map: the 3x3 map tiles around the point, the point in the
/// middle under a pin, the map's credit and a link to the full map.
class AddressMap extends StatelessWidget {
  final num lat;
  final num lng;
  final String label;
  final StepLook style;
  final String tileOrigin;

  const AddressMap({super.key, required this.lat, required this.lng, required this.label, required this.style, required this.tileOrigin});

  @override
  Widget build(BuildContext context) {
    final t0 = osmTile(lat, lng, 16);
    final z = t0['z'] as int;
    final n = 1 << z;
    final tx = t0['x'] as int, ty = t0['y'] as int;
    final ox = (t0['offsetX'] as num).toDouble(), oy = (t0['offsetY'] as num).toDouble();
    return Semantics(
      label: t('address.mapOf', {'address': label}),
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 148,
          color: const Color(0xFFE5E3DF),
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            final left = w / 2 - 256 - ox;
            final top = 148 / 2 - 256 - oy;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (var dy = -1; dy <= 1; dy++)
                  for (var dx = -1; dx <= 1; dx++)
                    if (ty + dy >= 0 && ty + dy < n)
                      Positioned(
                        left: left + (dx + 1) * 256,
                        top: top + (dy + 1) * 256,
                        width: 256,
                        height: 256,
                        child: Image.network(
                          tileSrc(tileOrigin, z, ((tx + dx) % n + n) % n, ty + dy),
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                Positioned(
                  left: w / 2 - 14,
                  top: 148 / 2 - 28,
                  child: Icon(Icons.location_on, size: 28, color: style.accent, shadows: const [Shadow(color: Color(0x55000000), blurRadius: 3)]),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Material(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => openStepLink(osmLink(lat, lng)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Text(t('address.viewMap'),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.white.withOpacity(0.75),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    child: const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 9, color: Color(0xFF334155))),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class AddressStepWidget extends StatefulWidget {
  final ui_state.AddressUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;
  final String? error;

  /// The server the map tiles come from (embed-server /api/v1/geo/tile).
  final String? tileOrigin;

  const AddressStepWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
    this.error,
    this.tileOrigin,
  });

  @override
  State<AddressStepWidget> createState() => _AddressStepWidgetState();
}

enum _Pane { search, manual, confirm }

class _AddressStepWidgetState extends State<AddressStepWidget> {
  final _search = TextEditingController();
  final Map<String, TextEditingController> _fields = {
    for (final f in const ['line1', 'city', 'region', 'postal', 'country']) f: TextEditingController(),
  };
  _Pane _pane = _Pane.search;
  int? _picked;
  Timer? _debounce;
  String _asked = '';
  bool _searching = false;
  bool _sent = false;

  static const _labels = {
    'line1': 'address.street',
    'city': 'address.city',
    'region': 'address.region',
    'postal': 'address.postal',
    'country': 'address.country',
  };

  List<Map<String, dynamic>> get _results => widget.state.results;

  @override
  void didUpdateWidget(AddressStepWidget old) {
    super.didUpdateWidget(old);
    if (!identical(old.state, widget.state) || old.error != widget.error) {
      _searching = false;
      _sent = false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ask(String q) {
    _debounce?.cancel();
    final query = q.trim();
    if (query.length < _minChars || query == _asked) return;
    setState(() {
      _asked = query;
      _searching = true;
    });
    widget.onResponse({'action': 'search', 'q': query});
  }

  void _typed(String q) {
    _debounce?.cancel();
    if (q.trim().length < _minChars) {
      setState(() => _asked = '');
      return;
    }
    _debounce = Timer(addressDebounce, () => _ask(q));
  }

  void _send(Map<String, dynamic> answer) {
    if (_sent) return;
    setState(() => _sent = true);
    widget.onResponse(answer);
  }

  String _formatted(Map<String, dynamic> r) =>
      '${r['formatted'] ?? r['display'] ?? r['line1'] ?? ''}';

  Widget _lines(String formatted, StepLook style, {String query = '', bool big = false}) {
    final parts = formatted.split(', ');
    final first = parts.first;
    final rest = parts.skip(1).join(', ');
    final strong = TextStyle(fontWeight: FontWeight.w700, color: style.text);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.location_on, size: big ? 20 : 18, color: style.accent.withOpacity(big ? 1 : 0.8)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(
                style: TextStyle(fontSize: 14, fontWeight: big ? FontWeight.w600 : FontWeight.w500, color: style.text, height: 1.3),
                children: highlightMatch(first, query, strong),
              )),
              if (rest.isNotEmpty)
                Text.rich(TextSpan(
                  style: TextStyle(fontSize: 12.5, color: style.muted, height: 1.3),
                  children: highlightMatch(rest, query, strong.copyWith(color: style.muted)),
                )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchPane(StepLook style) {
    final error = widget.error ?? '';
    final status = _searching
        ? t('address.searching')
        : (_results.isNotEmpty
            ? t(_results.length == 1 ? 'address.suggestions.one' : 'address.suggestions.other', {'n': _results.length})
            : '');
    final placeholder = '${widget.state.extra['placeholder'] ?? ''}'.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StepLabel(t('address.label'), style: style),
        TextField(
          key: const ValueKey('ad-input'),
          controller: _search,
          enabled: !_sent,
          autofocus: true,
          autocorrect: false,
          keyboardType: TextInputType.streetAddress,
          autofillHints: const [AutofillHints.fullStreetAddress],
          textInputAction: TextInputAction.search,
          style: TextStyle(fontSize: 15, color: style.text),
          decoration: style.field(
            hint: placeholder.isNotEmpty ? placeholder : t('address.placeholder'),
            invalid: error.isNotEmpty,
            suffix: Icon(Icons.search, size: 20, color: style.muted),
          ),
          onChanged: _typed,
          onSubmitted: (q) {
            _asked = '';
            _ask(q);
          },
        ),
        if (_results.isNotEmpty && !_searching)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: style.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: style.text.withOpacity(0.14)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _results.length && i < 5; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: style.text.withOpacity(0.07)),
                  InkWell(
                    key: ValueKey('ad-opt-$i'),
                    onTap: _sent
                        ? null
                        : () => setState(() {
                              _picked = i;
                              _pane = _Pane.confirm;
                            }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      child: _lines(_formatted(_results[i]), style, query: _search.text),
                    ),
                  ),
                ],
              ],
            ),
          ),
        StepStatus(style: style, hint: status, error: error),
        if (widget.state.allowManualEntry)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: StepLink(
                key: const ValueKey('ad-manual'),
                label: t('address.manual'),
                style: style,
                icon: Icons.edit_outlined,
                onPressed: _sent
                    ? null
                    : () => setState(() {
                          if (_fields['line1']!.text.isEmpty) _fields['line1']!.text = _search.text.trim();
                          _pane = _Pane.manual;
                        }),
              ),
            ),
          ),
      ],
    );
  }

  Widget _manualPane(StepLook style) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in _fields.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text.rich(TextSpan(style: style.label, children: [
              TextSpan(text: t(_labels[e.key]!)),
              if (e.key != 'line1') TextSpan(text: ' ${t('common.optional')}', style: const TextStyle(fontWeight: FontWeight.w400)),
            ])),
          ),
          TextField(
            key: ValueKey('ad-m-${e.key}'),
            controller: e.value,
            enabled: !_sent,
            autofillHints: [
              switch (e.key) {
                'line1' => AutofillHints.streetAddressLine1,
                'city' => AutofillHints.addressCity,
                'region' => AutofillHints.addressState,
                'postal' => AutofillHints.postalCode,
                _ => AutofillHints.countryName,
              }
            ],
            style: TextStyle(fontSize: 15, color: style.text),
            decoration: style.field(invalid: e.key == 'line1' && (widget.error ?? '').isNotEmpty),
          ),
          const SizedBox(height: 10),
        ],
        StepStatus(style: style, error: widget.error),
        StepActions(children: [
          StepButton(
            key: const ValueKey('ad-back'),
            label: t('common.back'),
            style: style,
            onPressed: _sent ? null : () => setState(() => _pane = _Pane.search),
          ),
          StepButton(
            key: const ValueKey('ad-manual-go'),
            label: t('action.confirm'),
            style: style,
            primary: true,
            onPressed: () => _send({
              'action': 'manual',
              for (final e in _fields.entries) e.key: e.value.text.trim(),
            }),
          ),
        ]),
      ],
    );
  }

  Widget _confirmPane(StepLook style) {
    final i = _picked ?? 0;
    final r = i < _results.length ? _results[i] : const <String, dynamic>{};
    final formatted = _formatted(r);
    final lat = r['lat'], lng = r['lng'];
    final showMap = widget.state.extra['showMap'] != false && lat is num && lng is num;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _lines(formatted, style, big: true),
        if (showMap) ...[
          const SizedBox(height: 10),
          AddressMap(
            lat: lat,
            lng: lng,
            label: formatted,
            style: style,
            tileOrigin: widget.tileOrigin ?? ConferBotEndpoints.apiOrigin,
          ),
        ],
        StepStatus(style: style, error: widget.error),
        StepActions(children: [
          StepButton(
            key: const ValueKey('ad-change'),
            label: t('common.change'),
            style: style,
            onPressed: _sent ? null : () => setState(() => _pane = _Pane.search),
          ),
          StepButton(
            key: const ValueKey('ad-confirm'),
            label: t('action.confirm'),
            style: style,
            primary: true,
            onPressed: () => _send({'action': 'pick', 'index': i, 'label': formatted}),
          ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = StepLook.of(context, widget.theme, widget.primaryColor);
    final pane = switch (_pane) {
      _Pane.search => _searchPane(style),
      _Pane.manual => _manualPane(style),
      _Pane.confirm => _confirmPane(style),
    };
    return Padding(padding: stepIndent(widget.theme), child: StepCard(style: style, child: pane));
  }
}
