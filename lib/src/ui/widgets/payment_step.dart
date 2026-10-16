/// payment-node's card (web richNodesView.ts paymentCardHtml): what is paid
/// for and how much, "Secure checkout by Stripe", then Cancel, "I've paid"
/// once the checkout is open, and Pay now, which opens Stripe Checkout in
/// the browser. Sends `{action: open}`, `{action: check}` and `{action:
/// cancel}`; the step watches for the payment itself and says why a check
/// or a start failed.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/flow/i18n_en.dart';
import '../../core/nodes/node_ui_state.dart' as ui_state;
import '../../theme/conferbot_theme.dart';
import 'step_style.dart';

void _openCheckout(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  launchUrl(uri, mode: LaunchMode.externalApplication).catchError((Object _) => false);
}

class PaymentStepWidget extends StatefulWidget {
  final ui_state.PaymentUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;
  final String? error;

  /// Opens the checkout (the browser; tests pass their own).
  final void Function(String url) onOpen;

  const PaymentStepWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
    this.error,
    this.onOpen = _openCheckout,
  });

  @override
  State<PaymentStepWidget> createState() => _PaymentStepWidgetState();
}

class _PaymentStepWidgetState extends State<PaymentStepWidget> {
  String? _busy;

  @override
  void didUpdateWidget(PaymentStepWidget old) {
    super.didUpdateWidget(old);
    if (!identical(old.state, widget.state) || old.error != widget.error) _busy = null;
  }

  Map<String, dynamic> get _extra => widget.state.extra;

  List<Map> get _buttons {
    final list = (_extra['buttons'] is List ? _extra['buttons'] as List : const []).whereType<Map>().toList();
    return list.isEmpty ? [{'id': 'open', 'label': widget.state.buttonLabel ?? t('pay.payNow')}] : list;
  }

  void _tap(String id) {
    if (_busy != null && id != 'open') return;
    if (id == 'open') {
      final url = '${_extra['checkoutUrl'] ?? widget.state.paymentUrl}'.trim();
      if (url.isNotEmpty && url != 'null') widget.onOpen(url);
    } else {
      setState(() => _busy = id);
    }
    widget.onResponse({'action': id});
  }

  @override
  Widget build(BuildContext context) {
    final style = StepLook.of(context, widget.theme, widget.primaryColor);
    final amount = '${_extra['amountText'] ?? ''}'.trim();
    final name = '${_extra['productName'] ?? ''}'.trim();
    final desc = '${_extra['description'] ?? ''}'.trim();
    final waiting = _extra['waiting'] == true;
    final byId = {for (final b in _buttons) '${b['id']}': b};
    String label(String id) {
      final l = '${byId[id]?['label'] ?? ''}';
      // The amount is in the card's head: Pay now on its own.
      return amount.isNotEmpty && l.endsWith(' · $amount') ? l.substring(0, l.length - amount.length - 3) : l;
    }

    return Padding(
      padding: stepIndent(widget.theme),
      child: StepCard(
        style: style,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: style.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.credit_card, size: 20, color: style.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isNotEmpty ? name : t('pay.payment'), style: style.bold),
                      if (desc.isNotEmpty) Text(desc, style: TextStyle(fontSize: 12.5, color: style.muted, height: 1.35)),
                    ],
                  ),
                ),
                if (amount.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(amount,
                        key: const ValueKey('pay-amount'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: style.text, fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
              ],
            ),
            if (waiting)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: style.accent.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: style.accent, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t('pay.waiting'), style: TextStyle(fontSize: 13, color: style.text))),
                ]),
              ),
            if ((widget.error ?? '').isNotEmpty)
              StepStatus(style: style, error: widget.error)
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.lock_outline, size: 13, color: style.muted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(t('pay.secure'), style: style.hint)),
                ]),
              ),
            StepActions(children: [
              if (byId.containsKey('cancel'))
                StepButton(
                  key: const ValueKey('pay-cancel'),
                  label: label('cancel'),
                  style: style,
                  busy: _busy == 'cancel',
                  onPressed: () => _tap('cancel'),
                ),
              if (byId.containsKey('check'))
                StepButton(
                  key: const ValueKey('pay-check'),
                  label: label('check'),
                  style: style,
                  busy: _busy == 'check',
                  onPressed: () => _tap('check'),
                ),
              if (byId.containsKey('open'))
                StepButton(
                  key: const ValueKey('pay-open'),
                  label: label('open'),
                  style: style,
                  primary: true,
                  icon: Icons.open_in_new,
                  onPressed: () => _tap('open'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
