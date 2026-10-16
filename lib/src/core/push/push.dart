/// Push notifications (embed-server #189, docs/mobile-push.md), ported from
/// the React Native SDK's src/core/push.ts.
///
/// When an agent or the AI replies and the visitor has no live socket in
/// that chat, embed-server sends a push (FCM on Android, APNs on iOS) to the
/// tokens registered for that conversation. The SDK has no push plugin of
/// its own: the app gets the token (e.g. firebase_messaging), hands it to
/// `ConferBotProvider.setPushToken`, and forwards notifications it receives
/// or the visitor taps to `handlePushNotification`.
///
/// Pure: the payload's shape, the request bodies, how the server's answers
/// read, and the registrar that keeps one token registered with the current
/// conversation (again for each new one, unregistered on logout).
library;

import 'dart:async';

/// `data.source` of every Conferbot push.
const String pushSource = 'conferbot';

/// `data.type` of a new message.
const String pushTypeMessage = 'conferbot_message';

/// The Android channel the server names (`android.notification.channel_id`).
const String pushChannelId = 'conferbot_messages';

/// Under the mobile API base (ConferBotEndpoints.apiBaseUrl, ".../api/v1/mobile").
const String pushRegisterPath = '/push/register';
const String pushUnregisterPath = '/push/unregister';

/// FCM registration token or APNs device token.
enum PushTokenType {
  fcm,
  apns;

  String get wire => name;
}

/// A Conferbot notification's data (all strings, as the server sends them).
class ConferbotPush {
  final String botId;
  final String chatSessionId;

  /// The reply's id, may be "".
  final String messageId;

  /// "agent" (a person) or "bot" (the AI).
  final String senderType;
  final String senderName;
  final String body;

  const ConferbotPush({
    required this.botId,
    required this.chatSessionId,
    this.messageId = '',
    this.senderType = 'bot',
    this.senderName = '',
    this.body = '',
  });

  bool get fromPerson => senderType == 'agent';

  /// The data map from whatever the app's plugin hands over: the flat data
  /// (FCM `RemoteMessage.data`, APNs userInfo with the keys beside `aps`,
  /// a local notification's decoded payload) or a map holding it under
  /// `data` / `userInfo`.
  static Map? dataOf(Object? input) {
    if (input is! Map) return null;
    for (final c in [input, input['data'], input['userInfo']]) {
      if (c is Map && c['source'] == pushSource) return c;
    }
    return null;
  }

  /// The Conferbot notification in [input], or null when it is not one
  /// (another plugin's, another type, no conversation).
  static ConferbotPush? parse(Object? input) {
    final d = dataOf(input);
    if (d == null || d['type'] != pushTypeMessage) return null;
    String s(Object? v) => v == null ? '' : v.toString();
    final botId = s(d['botId']).trim();
    final chatSessionId = s(d['chatSessionId']).trim();
    if (botId.isEmpty || chatSessionId.isEmpty) return null;
    return ConferbotPush(
      botId: botId,
      chatSessionId: chatSessionId,
      messageId: s(d['messageId']),
      senderType: d['senderType'] == 'agent' ? 'agent' : 'bot',
      senderName: s(d['senderName']),
      body: s(d['body']),
    );
  }

  static bool isConferbot(Object? input) => parse(input) != null;

  @override
  bool operator ==(Object other) =>
      other is ConferbotPush &&
      other.botId == botId &&
      other.chatSessionId == chatSessionId &&
      other.messageId == messageId &&
      other.senderType == senderType &&
      other.senderName == senderName &&
      other.body == body;

  @override
  int get hashCode => Object.hash(botId, chatSessionId, messageId, senderType, senderName, body);

  @override
  String toString() => 'ConferbotPush($botId, $chatSessionId, $messageId, $senderType)';
}

final RegExp _apnsHex = RegExp(r'^[0-9a-f]{64}$', caseSensitive: false);

/// As the server decides when the SDK does not say: a 64-character hex
/// token is APNs, anything else FCM.
PushTokenType pushTokenTypeOf(String token, [PushTokenType? type]) =>
    type ?? (_apnsHex.hasMatch(token) ? PushTokenType.apns : PushTokenType.fcm);

/// The request body of `POST /push/register`.
Map<String, dynamic> pushRegisterBody(
  String token,
  String chatSessionId,
  PushTokenType tokenType, [
  Map<String, String>? deviceInfo,
]) =>
    {
      'token': token,
      'chatSessionId': chatSessionId,
      'tokenType': tokenType.wire,
      if (deviceInfo != null && deviceInfo.isNotEmpty) 'deviceInfo': deviceInfo,
    };

Map<String, dynamic> pushUnregisterBody(String token) => {'token': token};

/// The server's refusals (embed-server REGISTER_PUSH_FAILURES), the network
/// and anything else.
enum PushRegisterError {
  missingToken('MISSING_TOKEN'),
  invalidToken('INVALID_TOKEN'),
  missingSession('MISSING_SESSION'),
  sessionForbidden('SESSION_FORBIDDEN'),
  sessionNotFound('SESSION_NOT_FOUND'),
  network('NETWORK'),
  server('SERVER');

  final String code;
  const PushRegisterError(this.code);

  /// Worth trying again for the same token and conversation: the
  /// conversation is not on the server yet (a new chat is stored when the
  /// visitor first answers), or the network or server failed.
  bool get retryable => this == sessionNotFound || this == network || this == server;
}

class PushRegisterResult {
  final bool ok;
  final PushRegisterError? error;
  const PushRegisterResult.registered()
      : ok = true,
        error = null;
  const PushRegisterResult.failed(PushRegisterError this.error) : ok = false;

  /// Registered only on a 2xx with `success: true`; else the server's error code.
  factory PushRegisterResult.of(int status, Object? data) {
    final map = data is Map ? data : const {};
    if (status >= 200 && status < 300 && map['success'] == true) return const PushRegisterResult.registered();
    final code = map['error'];
    for (final e in PushRegisterError.values) {
      if (e.code == code && e != PushRegisterError.network && e != PushRegisterError.server) {
        return PushRegisterResult.failed(e);
      }
    }
    if (status == 404) return const PushRegisterResult.failed(PushRegisterError.sessionNotFound);
    return const PushRegisterResult.failed(PushRegisterError.server);
  }

  @override
  bool operator ==(Object other) => other is PushRegisterResult && other.ok == ok && other.error == error;

  @override
  int get hashCode => Object.hash(ok, error);

  @override
  String toString() => ok ? 'PushRegisterResult(ok)' : 'PushRegisterResult(${error!.code})';
}

typedef PushRegisterCall = Future<PushRegisterResult> Function(Map<String, dynamic> body);
typedef PushUnregisterCall = Future<bool> Function(String token);

/// One token registered with the current conversation: again for every new
/// conversation, once per (token, conversation) pair, and again on the next
/// [poke] while the server does not have the conversation yet.
class PushRegistrar {
  final PushRegisterCall register;
  final PushUnregisterCall unregisterCall;
  final Map<String, String>? Function()? deviceInfo;

  PushRegistrar({required this.register, required PushUnregisterCall unregister, this.deviceInfo})
      : unregisterCall = unregister;

  String? _token;
  PushTokenType _type = PushTokenType.fcm;
  String? _session;
  (String, String)? _done;
  // A pair the server refused for good (bad token, another visitor's chat),
  // or the pair a logout stopped.
  String? _refused;
  Future<void>? _inFlight;
  bool _again = false;

  String? get token => _token;

  /// The token and conversation registered last, if any.
  (String, String)? get registered => _done;

  String get _key => '$_token\u0000$_session';

  Future<void> _attempt() async {
    final t = _token;
    final s = _session;
    if (t == null || s == null) return;
    if (_done == (t, s)) return;
    if (_refused == _key) return;
    PushRegisterResult r;
    try {
      r = await register(pushRegisterBody(t, s, _type, deviceInfo?.call()));
    } catch (_) {
      r = const PushRegisterResult.failed(PushRegisterError.network);
    }
    if (t != _token || s != _session) return; // moved on meanwhile: the next run has it
    if (r.ok) {
      _done = (t, s);
    } else if (!r.error!.retryable) {
      _refused = _key;
    }
  }

  Future<void> _run() {
    final running = _inFlight;
    if (running != null) {
      _again = true;
      return running;
    }
    final f = () async {
      do {
        _again = false;
        await _attempt();
      } while (_again);
    }();
    _inFlight = f.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  /// The app's token (null clears it: unregistered with the server).
  Future<void> setToken(String? token, [PushTokenType? type]) async {
    final clean = token?.trim() ?? '';
    if (clean.isEmpty) {
      await unregister();
      _token = null;
      return;
    }
    final old = _done?.$1;
    _token = clean;
    _type = pushTokenTypeOf(clean, type);
    _refused = null;
    // A refreshed token: the old one goes.
    if (old != null && old != clean) {
      _done = null;
      try {
        await unregisterCall(old);
      } catch (_) {}
    }
    await _run();
  }

  /// The conversation now on screen (null: none yet).
  Future<void> setSession(String? chatSessionId) {
    _session = (chatSessionId == null || chatSessionId.isEmpty) ? null : chatSessionId;
    return _run();
  }

  /// Something happened in the conversation: a registration that waits for
  /// it to reach the server tries again.
  Future<void> poke() => _run();

  /// Logout / the visitor cleared: unregister, and do not register this
  /// conversation again (a new one, or [setToken], does). The token is kept.
  Future<void> unregister() async {
    final t = _done?.$1 ?? _token;
    _done = null;
    _refused = (_token != null && _session != null) ? _key : null;
    if (t == null) return;
    try {
      await unregisterCall(t);
    } catch (_) {
      // Best effort: the server deactivates dead tokens on its own.
    }
  }
}
