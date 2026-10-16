/// otp-node's card (web richNodesView.ts otpCardHtml): the e-mail with Send
/// code, then six digit boxes with Verify, Resend (after a countdown),
/// Change email and Skip when the step allows it. Sends `{action: send,
/// email}`, `{action: verify, code}` (on its own once six digits are in),
/// `{action: resend}` and `{action: skip}`; the step checks them with the
/// server and the card shows why one was refused.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/flow/i18n_en.dart';
import '../../core/flow/rich.dart' show digitsFromPaste, otpLength, otpResendSeconds, resendLabel;
import '../../core/nodes/node_ui_state.dart' as ui_state;
import '../../theme/conferbot_theme.dart';
import 'step_style.dart';

class OtpNodeWidget extends StatefulWidget {
  final ui_state.TextInputUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;
  final String? error;

  const OtpNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
    this.error,
  });

  @override
  State<OtpNodeWidget> createState() => _OtpNodeWidgetState();
}

class _OtpNodeWidgetState extends State<OtpNodeWidget> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _editEmail = false;
  bool _busy = false;
  bool _wrong = false;
  String _last = '';
  Timer? _timer;
  int _left = 0;

  Map<String, dynamic> get _extra => widget.state.extra;
  bool get _codeStage => _extra['stage'] == 'code' && !_editEmail;
  bool get _allowSkip => _extra['allowSkip'] == true;
  String get _skipLabel => (_extra['skipLabel'] ?? t('common.skip')).toString();

  @override
  void initState() {
    super.initState();
    if (_extra['stage'] == 'code') _countdown();
  }

  @override
  void didUpdateWidget(OtpNodeWidget old) {
    super.didUpdateWidget(old);
    if (identical(old.state, widget.state) && old.error == widget.error) return;
    _busy = false;
    final stage = _extra['stage'];
    if (stage == 'code' && (_last == 'send' || _last == 'resend' || old.state.extra['stage'] != 'code')) {
      // A code went out (or the step asked again): fresh boxes, a new countdown.
      _editEmail = false;
      _code.clear();
      _wrong = false;
      _countdown();
    } else if (stage == 'code' && _last == 'verify' && (widget.error ?? '').isNotEmpty) {
      // A wrong code: the boxes empty and stay red until the visitor types.
      _code.clear();
      _wrong = true;
    }
  }

  void _countdown() {
    final n = _extra['resendIn'];
    _left = n is num && n > 0 ? n.ceil() : otpResendSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left = _left > 0 ? _left - 1 : 0);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _send(Map<String, dynamic> answer) {
    if (_busy) return;
    setState(() {
      _busy = true;
      _last = '${answer['action']}';
    });
    widget.onResponse(answer);
  }

  void _verify() {
    final code = digitsFromPaste(_code.text);
    _send({'action': 'verify', 'code': code, 'label': code});
  }

  Widget _emailPane(StepLook style) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StepLabel(t('otp.emailLabel'), style: style),
        TextField(
          key: const ValueKey('otp-email'),
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          textInputAction: TextInputAction.send,
          style: TextStyle(fontSize: 15, color: style.text),
          decoration: style.field(hint: t('otp.emailPlaceholder'), invalid: (widget.error ?? '').isNotEmpty),
          onSubmitted: (v) => _send({'action': 'send', 'email': v.trim()}),
        ),
        StepStatus(style: style, hint: t('otp.willEmail', {'n': otpLength}), error: widget.error),
        StepActions(children: [
          if (_allowSkip) StepButton(key: const ValueKey('otp-skip'), label: _skipLabel, style: style, onPressed: () => _send({'action': 'skip'})),
          StepButton(
            key: const ValueKey('otp-send'),
            label: t('otp.send'),
            style: style,
            primary: true,
            busy: _busy && _last == 'send',
            onPressed: () => _send({'action': 'send', 'email': _email.text.trim()}),
          ),
        ]),
      ],
    );
  }

  Widget _boxes(StepLook style) {
    final digits = _code.text.split('');
    final focused = _codeFocus.hasFocus;
    return GestureDetector(
      onTap: () => _codeFocus.requestFocus(),
      child: Stack(
        children: [
          // One field takes the code (typing, paste, the keyboard's
          // one-time-code autofill, backspace); the boxes draw it.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                key: const ValueKey('otp-code'),
                controller: _code,
                focusNode: _codeFocus,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  TextInputFormatter.withFunction((o, n) {
                    final d = digitsFromPaste(n.text);
                    return TextEditingValue(text: d, selection: TextSelection.collapsed(offset: d.length));
                  }),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                onChanged: (v) {
                  setState(() => _wrong = false);
                  if (v.length == otpLength) _verify();
                },
                onSubmitted: (_) => _verify(),
              ),
            ),
          ),
          IgnorePointer(
            child: Row(
              children: [
                for (var i = 0; i < otpLength; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Semantics(
                      label: t('otp.digit', {'n': i + 1, 'total': otpLength}),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: style.text.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _wrong
                                ? const Color(0xFFD92D20)
                                : (focused && i == digits.length.clamp(0, otpLength - 1)
                                    ? style.accent
                                    : style.text.withOpacity(0.24)),
                            width: focused && i == digits.length.clamp(0, otpLength - 1) && !_wrong ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          i < digits.length ? digits[i] : '',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: style.text,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
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

  Widget _codePane(StepLook style) {
    final sentTo = (_extra['sentTo'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(t('otp.sentTo', {'n': otpLength, 'email': sentTo.isNotEmpty ? sentTo : '***'}),
              style: TextStyle(fontSize: 14, height: 1.4, color: style.text)),
        ),
        _boxes(style),
        StepStatus(style: style, hint: t('otp.checkInbox', {'min': 10}), error: widget.error),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 6,
          spacing: 12,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StepLink(
                  key: const ValueKey('otp-resend'),
                  label: resendLabel(_left),
                  style: style,
                  onPressed: _left > 0 || _busy ? null : () => _send({'action': 'resend'}),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(width: 3, height: 3, decoration: BoxDecoration(color: style.text.withOpacity(0.35), shape: BoxShape.circle)),
                ),
                StepLink(
                  key: const ValueKey('otp-change'),
                  label: t('otp.changeEmail'),
                  style: style,
                  onPressed: _busy ? null : () => setState(() => _editEmail = true),
                ),
              ],
            ),
            Wrap(spacing: 8, children: [
              if (_allowSkip) StepButton(key: const ValueKey('otp-skip'), label: _skipLabel, style: style, onPressed: () => _send({'action': 'skip'})),
              StepButton(
                key: const ValueKey('otp-verify'),
                label: t('otp.verify'),
                style: style,
                primary: true,
                busy: _busy && _last == 'verify',
                onPressed: _verify,
              ),
            ]),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = StepLook.of(context, widget.theme, widget.primaryColor);
    return Padding(
      padding: stepIndent(widget.theme),
      child: StepCard(style: style, child: _codeStage ? _codePane(style) : _emailPane(style)),
    );
  }
}
