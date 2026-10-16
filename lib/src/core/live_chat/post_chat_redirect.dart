/// Post-chat redirect (Customize > Conversations > Post-chat redirect, the
/// bot's redirectUrl), ported from React Native's core/postChatRedirect.ts
/// and the web widget's ts/chat/postChatRedirect.ts
/// (docs/redirect-after-chat.md). When a conversation ends - the flow
/// reaches its end, or an agent ends a chat they took over - and the
/// post-chat rating is sent or put away (or there is none), a quiet line
/// counts down 10 seconds with Cancel, then the owner's URL opens outside
/// the chat.
///
///   - only http(s) URLs with a host: javascript:, data:, mailto:, a bare
///     domain and anything with a user:password@ part are ignored
///   - the app's `onPostChatRedirect(url)` is asked first: true means the
///     app handled it (or wants none), and no countdown is shown
///   - once per conversation: remembered when the countdown starts, so a
///     cancelled one, an agent ending the chat again or a restored ended
///     chat does not count down a second time
///   - it stops on Cancel, a new conversation, the chat closed or off the
///     conversation, a block, a person back in it, the app in the background
///   - when the system cannot open it, the line becomes "Continue to
///     example.com" the visitor can tap
///
/// Owned by ConferBotProvider (`provider.postChatRedirect`); no Flutter UI
/// here, the line is drawn by widgets/live_chat_cards.dart.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../i18n/i18n.dart';
import '../requests/requests_extras.dart' show RequestsStore;

/// Seconds the line counts down.
const int redirectSeconds = 10;

/// The rating shows 1.5 s after the end (web index.ts); the line waits for it.
const Duration redirectSettle = Duration(milliseconds: 1500);

/// The device remembers an offered conversation under this + chatSessionId.
const String redirectDoneKeyPrefix = 'conferbot_redirect_done_';

const int _maxUrlLength = 2048;

// A host may not hold these (WHATWG forbidden host code points).
final RegExp _forbiddenHost = RegExp(r'[\s#%/:<>?@\[\\\]^|\x00-\x1f\x7f]');
const Map<String, String> _defaultPort = {'http': '80', 'https': '443'};

class _Parts {
  final String scheme;
  final String host;
  final String port;
  final String rest;
  const _Parts(this.scheme, this.host, this.port, this.rest);
}

_Parts? _parse(String href) {
  final m = RegExp(r'^(https?)://([^/?#\\]*)([\s\S]*)$', caseSensitive: false).firstMatch(href);
  if (m == null) return null;
  final scheme = m.group(1)!.toLowerCase();
  final authority = m.group(2)!;
  // A user:password@ (or any user@) part.
  if (authority.contains('@')) return null;
  var host = authority;
  var port = '';
  final v6 = RegExp(r'^(\[[0-9a-fA-F:.]+\])(?::(\d*))?$').firstMatch(authority);
  if (v6 != null) {
    host = v6.group(1)!;
    port = v6.group(2) ?? '';
  } else {
    final at = authority.lastIndexOf(':');
    if (at >= 0) {
      port = authority.substring(at + 1);
      host = authority.substring(0, at);
      if (!RegExp(r'^\d*$').hasMatch(port)) return null;
    }
    if (host.isEmpty || _forbiddenHost.hasMatch(host) || RegExp(r'^\.+$').hasMatch(host)) return null;
  }
  if (port.isNotEmpty && int.parse(port) > 65535) return null;
  host = host.toLowerCase();
  port = port.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (port == _defaultPort[scheme]) port = '';
  // The path, query and fragment as a browser writes them.
  var rest = m.group(3)!.replaceAll('\\', '/').replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').replaceAll(' ', '%20');
  if (rest.isEmpty || rest[0] != '/') rest = '/$rest';
  return _Parts(scheme, host, port, rest);
}

/// The owner's URL when it is a plain http(s) address, else null.
String? safeRedirectUrl(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim();
  if (value.isEmpty || value.length > _maxUrlLength) return null;
  final u = _parse(value);
  if (u == null) return null;
  return '${u.scheme}://${u.host}${u.port.isNotEmpty ? ':${u.port}' : ''}${u.rest}';
}

/// "www.example.com" -> "example.com", for the line the visitor reads.
String redirectHost(String href) {
  final u = _parse(href.trim());
  return u == null ? '' : u.host.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
}

/// This conversation already counted down (or was cancelled, or the app took it).
Future<bool> redirectAlreadyOffered(String chatSessionId, RequestsStore? store) async {
  if (chatSessionId.isEmpty || store == null) return false;
  try {
    return await store.read(redirectDoneKeyPrefix + chatSessionId) == '1';
  } catch (_) {
    return false;
  }
}

enum RedirectPhase { counting, going, continueLink }

/// The line under the conversation.
@immutable
class RedirectLine {
  final String href;
  final String host;

  /// counting: "Taking you to x in Ns" + Cancel; going: "Taking you to x…";
  /// continueLink: a "Continue to x" button.
  final RedirectPhase phase;
  final int secondsLeft;

  /// What the line shows now.
  final String text;

  /// What a screen reader hears: the first sentence, said once (not every tick).
  final String said;

  /// The Cancel button's text and its accessible label.
  final String cancelText;
  final String cancelLabel;

  const RedirectLine({
    required this.href,
    required this.host,
    required this.phase,
    required this.secondsLeft,
    required this.text,
    required this.said,
    required this.cancelText,
    required this.cancelLabel,
  });

  RedirectLine copyWith({RedirectPhase? phase, int? secondsLeft, String? text, String? said}) => RedirectLine(
        href: href,
        host: host,
        phase: phase ?? this.phase,
        secondsLeft: secondsLeft ?? this.secondsLeft,
        text: text ?? this.text,
        said: said ?? this.said,
        cancelText: cancelText,
        cancelLabel: cancelLabel,
      );
}

/// What [PostChatRedirect.start] did.
enum RedirectStart { none, handled, counting }

typedef RedirectPeriodic = Timer Function(Duration every, void Function(Timer t) tick);
typedef RedirectAfter = Timer Function(Duration after, void Function() fire);

/// One per chat: when to start, the countdown, the conversations already
/// offered, the line.
class PostChatRedirect extends ChangeNotifier {
  PostChatRedirect({
    required this.redirectUrl,
    required this.sessionId,
    required this.chatVisible,
    required this.blocked,
    required this.live,
    required this.ratingPending,
    required this.open,
    this.disabled,
    this.onPostChatRedirect,
    this.store,
    this.appInForeground,
    this.seconds = redirectSeconds,
    this.settle = redirectSettle,
    RedirectPeriodic? periodic,
    RedirectAfter? after,
  })  : _periodic = periodic ?? ((d, fn) => Timer.periodic(d, fn)),
        _after = after ?? ((d, fn) => Timer(d, fn));

  /// The bot's redirectUrl (fetched-chatbot-data).
  final Object? Function() redirectUrl;
  final String? Function() sessionId;

  /// The chat is open on the conversation (not the home screen).
  final bool Function() chatVisible;

  /// The workspace blocked this visitor.
  final bool Function() blocked;

  /// A person (or a handover) is in the conversation.
  final bool Function() live;

  /// The post-chat rating is up and not answered yet.
  final bool Function() ratingPending;

  /// Opens the URL outside the chat; false (or a throw) when the system refused.
  final Future<bool> Function(String href) open;

  /// The app's config: never redirect.
  final bool Function()? disabled;

  /// The app's hook, asked first: true = handled, no countdown.
  final bool Function(String url)? Function()? onPostChatRedirect;

  /// Where an offered conversation is remembered (null: only while the app runs).
  final RequestsStore? Function()? store;
  final bool Function()? appInForeground;
  final int seconds;
  final Duration settle;
  final RedirectPeriodic _periodic;
  final RedirectAfter _after;

  RedirectLine? _line;
  RedirectLine? get line => _line;

  final Set<String> _offeredHere = <String>{};
  // One try per end, as the web's _afterPostChat (an offered conversation
  // is never offered again: _offeredHere and the store).
  final Set<String> _tried = <String>{};
  String? _ended;
  String? _active;
  Timer? _timer;
  Timer? _settleTimer;
  bool _disposed = false;

  /// The conversation the countdown (or the line) is for.
  String? get activeSession => _active;

  void _set(RedirectLine? line) {
    _line = line;
    if (!_disposed) notifyListeners();
  }

  bool _canGo(String session) =>
      _ended == session &&
      (sessionId() ?? '') == session &&
      chatVisible() &&
      !blocked() &&
      !live() &&
      (appInForeground?.call() ?? true);

  /// The conversation on screen ended (the flow's end, an agent ending it).
  void conversationEnded() {
    final session = sessionId() ?? '';
    if (session.isEmpty) return;
    _ended = session;
    _tried.remove(session);
    _settleTimer?.cancel();
    _settleTimer = null;
    update();
  }

  /// Anything the chat shows changed: wait for the rating, try once after
  /// the settle; a countdown that can no longer go stops.
  void update() {
    final active = _active;
    if (active != null && !_canGo(active)) cancel();
    final ended = _ended;
    if (ended == null) return;
    if ((sessionId() ?? '') != ended) {
      _ended = null;
      _settleTimer?.cancel();
      _settleTimer = null;
      return;
    }
    if (_tried.contains(ended)) return;
    if (ratingPending()) {
      _settleTimer?.cancel();
      _settleTimer = null;
      return;
    }
    if (_settleTimer != null) return;
    _settleTimer = _after(settle, () {
      _settleTimer = null;
      if (_ended != ended || ratingPending()) return;
      _tried.add(ended);
      unawaited(start(ended));
    });
  }

  /// The app's hook, else the countdown. none when there is nothing to do
  /// (no valid URL, turned off, already offered, not on screen).
  Future<RedirectStart> start(String session) async {
    final href = safeRedirectUrl(redirectUrl());
    if (href == null || (disabled?.call() ?? false)) return RedirectStart.none;
    if (_offeredHere.contains(session) || _active != null) return RedirectStart.none;
    // Held while the store is read, so a second end in the meantime does nothing.
    _offeredHere.add(session);
    final s = store?.call();
    if (await redirectAlreadyOffered(session, s)) return RedirectStart.none;
    if (!_canGo(session)) {
      _offeredHere.remove(session);
      return RedirectStart.none;
    }
    if (s != null && session.isNotEmpty) {
      try {
        await s.write(redirectDoneKeyPrefix + session, '1');
      } catch (_) {
        /* storage refused: the in-memory guard still holds while the app runs */
      }
    }

    var handled = false;
    final hook = onPostChatRedirect?.call();
    if (hook != null) {
      try {
        handled = hook(href) == true;
      } catch (_) {
        handled = false;
      }
    }
    if (handled) return RedirectStart.handled;
    // The visitor left in the meantime (closed the chat, a new conversation).
    if (!_canGo(session) || _disposed) return RedirectStart.none;

    final host = redirectHost(href);
    var left = seconds < 1 ? 1 : seconds;
    final said = t('redirect.countdown', {'host': host, 'n': left});
    _active = session;
    _set(RedirectLine(
      href: href,
      host: host,
      phase: RedirectPhase.counting,
      secondsLeft: left,
      text: said,
      said: said,
      cancelText: t('common.cancel'),
      cancelLabel: t('redirect.cancel', {'host': host}),
    ));
    _timer = _periodic(const Duration(seconds: 1), (timer) {
      if (_active != session) {
        timer.cancel();
        return;
      }
      if (!_canGo(session)) {
        cancel();
        return;
      }
      left -= 1;
      if (left > 0) {
        _set(_line!.copyWith(secondsLeft: left, text: t('redirect.countdown', {'host': host, 'n': left})));
        return;
      }
      timer.cancel();
      _timer = null;
      unawaited(_go(href, host, session));
    });
    return RedirectStart.counting;
  }

  Future<void> _go(String href, String host, String session) async {
    var opened = false;
    try {
      opened = await open(href);
    } catch (_) {
      opened = false;
    }
    if (_active != session || _line == null) return;
    if (opened) {
      final going = t('redirect.going', {'host': host});
      _set(_line!.copyWith(phase: RedirectPhase.going, secondsLeft: 0, text: going, said: going));
    } else {
      final text = t('redirect.continue', {'host': host});
      _set(_line!.copyWith(phase: RedirectPhase.continueLink, secondsLeft: 0, text: text, said: text));
    }
  }

  /// "Continue to example.com" tapped: open it now.
  Future<bool> continueNow() async {
    final line = _line;
    if (line == null || line.phase != RedirectPhase.continueLink) return false;
    var opened = false;
    try {
      opened = await open(line.href);
    } catch (_) {
      opened = false;
    }
    if (opened && identical(_line, line)) cancel();
    return opened;
  }

  /// Stop a countdown and take the line away (Cancel, a restart, the chat
  /// closed, the app in the background).
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _active = null;
    if (_line != null) _set(null);
  }

  /// A restart: the countdown stops and the next conversation gets its own.
  void reset() {
    cancel();
    _settleTimer?.cancel();
    _settleTimer = null;
    _ended = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _settleTimer?.cancel();
    super.dispose();
  }
}
