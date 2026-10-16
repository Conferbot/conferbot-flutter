/// "Your requests" in the SDK (web conferbot-widget src/ts/home/requests/
/// card.ts mountRequestsCard, store.ts, and index.ts `_sendResponse`
/// rememberSession; RN context/hooks/useRequestsPortal.ts). Holds:
///
///   - what the device remembers: the chats it started that the visitor
///     wrote in, and when each request was last read here, per bot in
///     shared_preferences (requests.dart; in memory without a store);
///   - the list as the home card has it, for the chat menu's item and the
///     app's badge ([unread]): read when the socket connects, when the chat
///     opens or closes (at most every 15s), when the portal closes, and when
///     a request changes while the portal is closed;
///   - the portal's screens ([portal], requests_portal.dart).
///
/// Nothing is asked for a visitor with no chat on this device and no
/// signed-in user (`user.hash`): a first-time visitor has no requests.
/// Owned by ConferBotProvider (`provider.requests`); drawn by
/// widgets/requests/requests_portal_view.dart.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';
import '../../services/socket_client.dart';
import 'requests.dart';
import 'requests_portal.dart';

/// Where the device keeps what it remembers.
abstract class RequestsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// The device's shared_preferences (the web's localStorage).
class SharedPreferencesRequestsStore implements RequestsStore {
  const SharedPreferencesRequestsStore();

  @override
  Future<String?> read(String key) async => (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async {
    await (await SharedPreferences.getInstance()).setString(key, value);
  }
}

/// The SDK's socket as the requests calls use it.
class SocketClientRequestsSocket implements RequestsSocket {
  SocketClientRequestsSocket(this.client);
  final SocketClient client;

  @override
  Future<dynamic> emitWithAck(String event, dynamic payload, Duration timeout) =>
      client.emitWithAck(event, payload, timeout: timeout);

  @override
  void emit(String event, dynamic payload) => client.emit(event, payload);

  @override
  void Function() on(String event, void Function(dynamic data) fn) {
    void listener(dynamic data) => fn(data);
    client.on(event, listener);
    return () => client.off(event, listener);
  }
}

class RequestsExtras extends ChangeNotifier {
  RequestsExtras({
    required String? Function() botId,
    required RequestsSocket? Function() socket,
    required bool Function() connected,
    required String? Function() visitorId,
    required ConferBotUser? Function() user,
    RequestsStore? Function()? store,
    required String? Function() chatSessionId,
    required bool Function() chatEnded,
    void Function()? openChat,
    int Function()? now,
    double Function()? rand,
  })  : _botId = botId,
        _socket = socket,
        _connected = connected,
        _visitorId = visitorId,
        _user = user,
        _store = store ?? (() => null),
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _client = SocketRequestsApi(_socket, () => requestsWho(_visitorId(), _memory, _user()));
    portal = RequestsPortal(
      api: _ForwardingApi(_client, _updateListeners),
      seen: () => _memory.seen,
      markSeen: (id, at) => _save(withSeen(_memory, id, at)),
      // The chat on screen, not yet over: that chat instead (web index.ts isCurrentChat).
      isCurrentChat: (id) => id == chatSessionId() && !chatEnded(),
      openChat: () => openChat?.call(),
      onChanged: () => unawaited(refresh(force: true)),
      now: _now,
      rand: rand,
    );
    portal.addListener(_changed);
    // A reply arrived while the portal is closed: the list says so.
    _updateListeners.add((_) {
      if (!portal.isOpen) unawaited(refresh(force: true));
    });
  }

  final String? Function() _botId;
  final RequestsSocket? Function() _socket;
  final bool Function() _connected;
  final String? Function() _visitorId;
  final ConferBotUser? Function() _user;
  final RequestsStore? Function() _store;
  final int Function() _now;

  late final SocketRequestsApi _client;
  late final RequestsPortal portal;

  RequestMemory _memory = const RequestMemory();
  String? _loadedFor;
  Future<void>? _loading;

  // Bumped on each sign-in or sign-out, so a list read for the last user is dropped.
  int _who = 0;
  int _lastLoad = 0;
  bool _listing = false;
  bool _disposed = false;

  // The portal and the list both hear the server's updates; the socket's
  // listeners are set up again with the SDK's, so [attach] moves the one
  // real subscription there.
  final List<void Function(String id)> _updateListeners = [];
  void Function()? _offSocket;

  List<RequestSummary>? _list;

  /// The visitor's requests (newest replies first), null until read.
  List<RequestSummary>? get list => _list;

  /// Requests with a team reply not read on this device: the app's badge.
  int get unread => unreadCount(_list, _memory.seen);

  /// The visitor has a request: the chat menu offers "Your requests".
  bool get hasRequests => (_list ?? const []).isNotEmpty;

  /// The portal is up.
  bool get isOpen => portal.isOpen;

  /// What the device remembers (for tests and apps that show it).
  RequestMemory get memory => _memory;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Listen to the server's updates on the SDK's socket (set up, or set up again).
  void attach() {
    _offSocket?.call();
    _offSocket = _client.onUpdate((id) {
      for (final fn in List.of(_updateListeners)) {
        fn(id);
      }
    });
  }

  void _save(RequestMemory? next) {
    if (next == null) return;
    _memory = next;
    _changed();
    final store = _store();
    if (store == null) return;
    try {
      unawaited(store.write(requestsStorageKey(_botId()), serializeMemory(next)).catchError((_) {}));
    } catch (_) {
      // storage full or blocked: this app session still remembers
    }
  }

  /// What the device remembers, once per bot.
  Future<void> load() {
    final bot = _botId() ?? '';
    if (_loadedFor == bot && _loading != null) return _loading!;
    _loadedFor = bot;
    _list = null;
    return _loading = () async {
      String? raw;
      try {
        raw = await _store()?.read(requestsStorageKey(bot));
      } catch (_) {
        raw = null;
      }
      // Anything remembered meanwhile (a chat written in) is kept.
      final read = parseMemory(raw);
      final sessions = [..._memory.sessions, ...read.sessions.where((s) => !_memory.sessions.contains(s))];
      _memory = RequestMemory(
        sessions: sessions.take(requestsMaxSessions).toList(),
        seen: {...read.seen, ..._memory.seen},
      );
      _changed();
    }();
  }

  /// Read the list again (at most every 15s unless [force]).
  Future<void> refresh({bool force = false}) async {
    await load();
    if (_listing || (!force && _now() - _lastLoad < requestsRefreshGap.inMilliseconds)) return;
    if (!canAskForRequests(_memory, _user())) return;
    if (!_connected()) return;
    _listing = true;
    _lastLoad = _now();
    final who = _who;
    try {
      final list = await _client.list();
      // A list asked for the user before a sign-in or sign-out is not shown.
      if (list != null && !_disposed && who == _who) {
        _list = ordered(list, _memory.seen);
        _changed();
      }
    } finally {
      _listing = false;
    }
    // Someone else now: ask again for them.
    if (who != _who && !_disposed) await refresh(force: true);
  }

  /// A response record went out: a chat the visitor wrote in may become a
  /// request (web _sendResponse).
  Future<void> onRecord(String? sessionId, List<dynamic>? record) async {
    if (sessionId == null || sessionId.isEmpty || !hasVisitorEntry(record)) return;
    await load();
    _save(withSession(_memory, sessionId));
  }

  /// Connected with something to ask about (every connect).
  Future<void> onConnected() => refresh(force: true);

  /// Someone signed in or out (the provider's identify): the list read for
  /// the last user is dropped, and read again for this one.
  Future<void> onUserChanged() {
    _who++;
    _list = null;
    _lastLoad = 0;
    _changed();
    return refresh(force: true);
  }

  /// The chat opening or closing is the app's "home comes back into view"
  /// (web card.ts): read again, at most every 15s.
  Future<void> onChatShown() => refresh();

  /// Open the list, or one request by its id.
  Future<void> open([String? requestId]) async {
    await load();
    if (requestId != null) {
      await portal.openRequest(requestId);
    } else {
      await portal.openList();
    }
  }

  void close() => portal.close();
  void back() => portal.back();

  /// A new conversation: the drafts go.
  void reset() => portal.reset();

  @override
  void dispose() {
    _disposed = true;
    _offSocket?.call();
    portal.removeListener(_changed);
    portal.dispose();
    super.dispose();
  }
}

/// The socket's calls, with the updates heard through [RequestsExtras.attach].
class _ForwardingApi implements RequestsApi {
  _ForwardingApi(this._inner, this._listeners);
  final RequestsApi _inner;
  final List<void Function(String id)> _listeners;

  @override
  Future<List<RequestSummary>?> list() => _inner.list();
  @override
  Future<RequestDetail?> open(String id) => _inner.open(id);
  @override
  void close(String id) => _inner.close(id);
  @override
  Future<ReplyResult> reply(String id, String text, String entryId) => _inner.reply(id, text, entryId);
  @override
  void Function() onUpdate(void Function(String id) fn) {
    _listeners.add(fn);
    return () => _listeners.remove(fn);
  }
}
