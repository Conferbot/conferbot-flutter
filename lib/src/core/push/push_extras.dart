/// Push notifications wired into the chat (core/push/push.dart; React
/// Native's context/hooks/usePushNotifications.ts). Opt-in: nothing happens
/// until the app passes its FCM or APNs token to `setPushToken`; the SDK
/// never loads Firebase.
///
///   - The token is registered with the current conversation, again for
///     each new one, and tried again as the conversation goes on while the
///     server does not have it yet (a local session is stored when the
///     visitor answers).
///   - Unregistered on a logout (`identify(null)`) or another user, on
///     clearing the visitor's data, or `unregisterPush()`.
///   - `handle(data)` recognises a Conferbot notification for this bot and
///     opens its conversation: the chat when it is the one on the device,
///     else that conversation in "Your requests".
///
/// Owned by ConferBotProvider (`provider.push`); no Flutter UI here.
library;

import 'dart:async';

import 'push.dart';

/// A burst of messages is one retry.
const Duration pushRetryDebounce = Duration(seconds: 1);

class PushExtras {
  final String Function() botId;
  final PushRegisterCall register;
  final PushUnregisterCall unregister;
  final String? Function() chatSessionId;
  final int Function() recordLength;
  final bool Function() initialized;

  /// The chat is open on the conversation (not the home screen).
  final bool Function() chatOnScreen;
  final Future<void> Function() openChat;
  final void Function() showChat;
  final Future<void> Function(String requestId) openRequest;
  final void Function() bumpUnread;
  final Map<String, String>? Function()? deviceInfo;

  /// How long a burst of messages waits before the retry (tests: zero).
  final Duration retryDelay;

  late final PushRegistrar registrar;

  PushExtras({
    required this.botId,
    required this.register,
    required this.unregister,
    required this.chatSessionId,
    required this.recordLength,
    required this.initialized,
    required this.chatOnScreen,
    required this.openChat,
    required this.showChat,
    required this.openRequest,
    required this.bumpUnread,
    this.deviceInfo,
    this.retryDelay = pushRetryDebounce,
  }) {
    registrar = PushRegistrar(register: register, unregister: unregister, deviceInfo: deviceInfo);
  }

  String? _session;
  int _records = 0;
  String? _userId;
  bool _userKnown = false;
  Timer? _retry;
  ConferbotPush? _pending;

  /// The app's token; null unregisters.
  Future<void> setToken(String? token, [PushTokenType? type]) {
    _session = chatSessionId();
    registrar.setSession(_session);
    return registrar.setToken(token, type);
  }

  /// Stop this device's pushes. The token is kept for the next conversation.
  Future<void> stop() => registrar.unregister();

  /// Whatever the provider shows changed: a new conversation is registered,
  /// a grown one tries again, a pending tap opens once the SDK is ready.
  void update() {
    final s = chatSessionId();
    if (s != _session) {
      _session = s;
      _records = recordLength();
      unawaited(registrar.setSession(s));
    } else {
      final n = recordLength();
      if (n > _records) {
        _records = n;
        _retry?.cancel();
        _retry = Timer(retryDelay, () => unawaited(registrar.poke()));
      } else {
        _records = n;
      }
    }
    final p = _pending;
    if (p != null && initialized()) {
      _pending = null;
      unawaited(_open(p));
    }
  }

  /// The signed-in user: a logout or another user stops the old pushes.
  void userChanged(String? userId) {
    final before = _userId;
    final known = _userKnown;
    _userId = userId;
    _userKnown = true;
    if (known && before != null && before != userId) unawaited(registrar.unregister());
  }

  Future<void> _open(ConferbotPush push) async {
    final current = chatSessionId();
    await openChat();
    if (current == null || current == push.chatSessionId) {
      showChat();
    } else {
      // Another of the visitor's conversations: that one, in "Your requests".
      await openRequest(push.chatSessionId);
    }
  }

  /// A notification the app received or the visitor tapped: true when it is
  /// this bot's Conferbot message, and its conversation is opened
  /// ([open] false: only counted as unread unless it is on screen).
  bool handle(Object? data, {bool open = true}) {
    final push = ConferbotPush.parse(data);
    if (push == null || push.botId != botId()) return false;
    if (!open) {
      if (!(chatOnScreen() && chatSessionId() == push.chatSessionId)) bumpUnread();
      return true;
    }
    if (!initialized()) {
      _pending = push;
    } else {
      unawaited(_open(push));
    }
    return true;
  }

  void dispose() {
    _retry?.cancel();
    _retry = null;
  }
}
