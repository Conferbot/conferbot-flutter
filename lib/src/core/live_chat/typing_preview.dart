/// Typing preview ("sneak peek"): while a person is chatting with the
/// visitor, the agent sees what the visitor is typing before it is sent.
/// Ported from the React Native SDK (src/core/typingPreview.ts), itself from
/// conferbot-widget src/ts/chat/typingPreview.ts (cleanDraft,
/// createDraftSender) and its wiring in src/index.ts (updateVisitorDraft:
/// off when the owner set visitorDraftPreview to false, never for a secret
/// field, only while a person is in the chat).
///
/// The composer calls update() on every change; drafts go out as
/// `visitor-draft {chatSessionId, draft}` at most every [TypingPreview.throttleMs]
/// (the latest text always follows, trailing), trimmed and capped at
/// [TypingPreview.maxLength]. clear() sends one empty draft on send, or when
/// the field is emptied, so the agent's preview goes away at once. The
/// server relays drafts only to the conversation's agents and never keeps
/// them (embed-server liveChat/visitorDraft). Pure.
library;

import 'dart:async';

import 'package:flutter/services.dart' show TextInputType;

class TypingPreview {
  TypingPreview._();

  static const maxLength = 500;
  static const throttleMs = 300;

  static String cleanDraft(dynamic value) {
    if (value is! String) return '';
    final s = value.trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Never preview what looks like a secret or card data (a text field's
  /// settings, as the web reads the field): an obscured field, a password,
  /// a one-time code or a card's autofill hints.
  static bool isSensitiveField({bool obscureText = false, Iterable<String>? autofillHints, TextInputType? keyboardType}) {
    if (obscureText) return true;
    if (keyboardType == TextInputType.visiblePassword) return true;
    for (final raw in autofillHints ?? const <String>[]) {
      final h = raw.toLowerCase();
      if (h.contains('password') || h == 'onetimecode' || h == 'one-time-code' || h == 'sms-otp' || h.startsWith('creditcard') || h.startsWith('cc-')) {
        return true;
      }
    }
    return false;
  }

  /// Whether drafts go to the agent at all: the owner allows it and a person
  /// (not the AI) is in the chat.
  static bool draftPreviewOn(dynamic customizations, bool chattingWithPerson) =>
      !(customizations is Map && customizations['visitorDraftPreview'] == false) && chattingWithPerson;
}

/// Sends the composer's draft, throttled (web createDraftSender).
class DraftSender {
  DraftSender(
    this._send, {
    int intervalMs = TypingPreview.throttleMs,
    int Function()? now,
    Object Function(void Function() fn, int ms)? setTimer,
    void Function(Object timer)? clearTimer,
  })  : _intervalMs = intervalMs,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
        _setTimer = setTimer ?? ((fn, ms) => Timer(Duration(milliseconds: ms), fn)),
        _clearTimer = clearTimer ?? ((t) => (t as Timer).cancel());

  final void Function(String draft) _send;
  final int _intervalMs;
  final int Function() _now;
  final Object Function(void Function() fn, int ms) _setTimer;
  final void Function(Object timer) _clearTimer;

  String _lastSent = '';
  int? _lastSentAt;
  String? _pending;
  Object? _timer;

  void _flush() {
    _timer = null;
    final draft = _pending;
    if (draft == null) return;
    _pending = null;
    if (draft == _lastSent) return;
    _lastSent = draft;
    _lastSentAt = _now();
    _send(draft);
  }

  void update(String text) {
    final draft = TypingPreview.cleanDraft(text);
    if (draft.isEmpty) return clear();
    _pending = draft;
    if (_timer != null) return;
    final last = _lastSentAt;
    final wait = last == null ? 0 : _intervalMs - (_now() - last);
    if (wait <= 0) {
      _flush();
    } else {
      _timer = _setTimer(_flush, wait);
    }
  }

  void clear() {
    if (_timer != null) _clearTimer(_timer!);
    _timer = null;
    _pending = null;
    if (_lastSent.isEmpty) return;
    _lastSent = '';
    _lastSentAt = _now();
    _send('');
  }
}
