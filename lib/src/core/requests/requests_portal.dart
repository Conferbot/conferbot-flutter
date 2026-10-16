/// "Your requests": the screens as states (web conferbot-widget
/// src/ts/home/requests/view.ts mountRequestsView; RN
/// src/core/requestsPortal.ts). One thing at a time:
///
///   list      each request's question and where it stands, in words
///   request   a banner saying where it stands and what happens next, the
///             conversation, and a reply box with a Send button. A reply to
///             a solved request opens it again; the banner says so first.
///
/// Back always goes one step back. Team replies arrive live while a request
/// is open (`my-request-update`), keeping what the visitor was typing and
/// any reply that did not go out. The view draws [RequestsPortal.state] and
/// calls the actions; nothing here touches widgets.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'requests.dart';

enum PendingStatus { sending, failed, locked }

/// A reply on its way, or one that did not go (web `.cb-req__msg.is-pending`).
@immutable
class PendingReply {
  const PendingReply({required this.entryId, required this.text, required this.at, required this.status});
  final String entryId;
  final String text;
  final String at;
  final PendingStatus status;

  PendingReply withStatus(PendingStatus s) => PendingReply(entryId: entryId, text: text, at: at, status: s);
}

enum RequestsScreen { closed, list, request }

@immutable
class RequestsPortalState {
  const RequestsPortalState({
    this.screen = RequestsScreen.closed,
    this.title = '',
    this.loading = false,
    this.failed = false,
    this.list,
    this.seen = const {},
    this.request,
    this.requestState,
    this.banner,
    this.pending = const [],
    this.draft = '',
    String? placeholder,
    this.canSend = false,
  }) : _placeholder = placeholder;

  final RequestsScreen screen;

  /// The bar's title.
  final String title;
  final bool loading;

  /// It could not be read: "We couldn't load this just now." and Try again (`reload`).
  final bool failed;

  /// The list screen's requests, newest replies first; null until read.
  final List<RequestSummary>? list;

  /// When each was last read here, for "New reply".
  final Map<String, int> seen;

  /// The open request.
  final RequestDetail? request;
  final RequestState? requestState;

  /// The banner: where it stands and what happens next.
  final StateWords? banner;
  final List<PendingReply> pending;
  final String draft;
  final String? _placeholder;
  String get placeholder => _placeholder ?? RequestsText.replyPlaceholder;
  final bool canSend;

  bool get isOpen => screen != RequestsScreen.closed;

  static const _keep = Object();

  RequestsPortalState copyWith({
    RequestsScreen? screen,
    String? title,
    bool? loading,
    bool? failed,
    Object? list = _keep,
    Map<String, int>? seen,
    Object? request = _keep,
    Object? requestState = _keep,
    Object? banner = _keep,
    List<PendingReply>? pending,
    String? draft,
    String? placeholder,
    bool? canSend,
  }) =>
      RequestsPortalState(
        screen: screen ?? this.screen,
        title: title ?? this.title,
        loading: loading ?? this.loading,
        failed: failed ?? this.failed,
        list: identical(list, _keep) ? this.list : list as List<RequestSummary>?,
        seen: seen ?? this.seen,
        request: identical(request, _keep) ? this.request : request as RequestDetail?,
        requestState: identical(requestState, _keep) ? this.requestState : requestState as RequestState?,
        banner: identical(banner, _keep) ? this.banner : banner as StateWords?,
        pending: pending ?? this.pending,
        draft: draft ?? this.draft,
        placeholder: placeholder ?? _placeholder,
        canSend: canSend ?? this.canSend,
      );
}

class RequestsPortal extends ChangeNotifier {
  RequestsPortal({
    required RequestsApi api,
    required Map<String, int> Function() seen,
    required void Function(String id, int at) markSeen,
    required bool Function(String id) isCurrentChat,
    required void Function() openChat,
    void Function()? onChanged,
    int Function()? now,
    double Function()? rand,
  })  : _api = api,
        _seen = seen,
        _markSeen = markSeen,
        _isCurrentChat = isCurrentChat,
        _openChat = openChat,
        _onChanged = onChanged,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
        _rand = rand {
    // A team reply or "solved" while it is open: read it again, keeping
    // whatever they were typing and a reply that did not go out.
    _offUpdate = _api.onUpdate((id) async {
      if (id != _openId || _state.screen != RequestsScreen.request) return;
      final r = await _api.open(id);
      if (r == null || _openId != id || _state.screen != RequestsScreen.request || _state.pending.any((p) => p.status == PendingStatus.sending)) {
        return;
      }
      _draw(r, _state.pending);
    });
  }

  final RequestsApi _api;
  final Map<String, int> Function() _seen;
  final void Function(String id, int at) _markSeen;
  final bool Function(String id) _isCurrentChat;
  final void Function() _openChat;
  final void Function()? _onChanged;
  final int Function() _now;
  final double Function()? _rand;

  RequestsPortalState _state = const RequestsPortalState();
  String? _openId;
  bool _fromList = false;
  Map<String, String> _drafts = {};
  Future<void> Function()? _lastLoad;
  void Function()? _offUpdate;
  bool _disposed = false;

  RequestsPortalState get state => _state;
  bool get isOpen => _state.isOpen;

  void _set(RequestsPortalState next) {
    if (next.screen == RequestsScreen.request) {
      final draft = _openId != null ? (_drafts[_openId] ?? '') : '';
      next = next.copyWith(draft: draft, canSend: draft.trim().isNotEmpty);
    }
    _state = next;
    if (!_disposed) notifyListeners();
  }

  void _leave() {
    if (_openId != null) _api.close(_openId!);
    _openId = null;
    final was = _state.screen;
    _state = const RequestsPortalState();
    if (!_disposed) notifyListeners();
    if (was != RequestsScreen.closed) _onChanged?.call();
  }

  // ---------- All requests ----------

  Future<void> _showList() async {
    if (_openId != null) _api.close(_openId!);
    _openId = null;
    _lastLoad = _showList;
    _set(_state.copyWith(
      screen: RequestsScreen.list,
      title: RequestsText.title,
      loading: true,
      failed: false,
      request: null,
      requestState: null,
      banner: null,
      pending: const [],
    ));
    final list = await _api.list();
    if (_state.screen != RequestsScreen.list || _openId != null) return;
    if (list == null) return _set(_state.copyWith(loading: false, failed: true));
    final seen = Map<String, int>.of(_seen());
    _set(_state.copyWith(loading: false, failed: false, list: ordered(list, seen), seen: seen));
  }

  // ---------- One request ----------

  void _draw(RequestDetail r, List<PendingReply> pending) {
    final rs = stateOf(r);
    _markSeen(r.id, seenAt(r.lastAt, _now()));
    _set(_state.copyWith(
      loading: false,
      failed: false,
      request: r,
      requestState: rs,
      banner: stateWords[rs],
      pending: pending,
      placeholder: rs == RequestState.solved ? RequestsText.reopenPlaceholder : RequestsText.replyPlaceholder,
    ));
  }

  Future<void> _showRequest(String id) async {
    if (_isCurrentChat(id)) {
      _leave();
      _openChat();
      return;
    }
    _openId = id;
    _lastLoad = () => _showRequest(id);
    _set(_state.copyWith(
      screen: RequestsScreen.request,
      title: RequestsText.one,
      loading: true,
      failed: false,
      request: null,
      requestState: null,
      banner: null,
      pending: const [],
    ));
    final r = await _api.open(id);
    if (_openId != id || _state.screen != RequestsScreen.request) return;
    if (r == null) return _set(_state.copyWith(loading: false, failed: true));
    _draw(r, const []);
  }

  List<PendingReply> _withPending(String entryId, PendingStatus? status) => status == null
      ? _state.pending.where((p) => p.entryId != entryId).toList()
      : [for (final p in _state.pending) p.entryId == entryId ? p.withStatus(status) : p];

  Future<void> _sendText(String id, String entryId, String text) async {
    _set(_state.copyWith(pending: _withPending(entryId, PendingStatus.sending)));
    final out = await _api.reply(id, text, entryId);
    if (_openId != id || _state.screen != RequestsScreen.request) return;
    if (out.ok && out.request != null) {
      _drafts.remove(id);
      _draw(out.request!, _withPending(entryId, null));
      return;
    }
    _set(_state.copyWith(pending: _withPending(entryId, out.reason == 'locked' ? PendingStatus.locked : PendingStatus.failed)));
  }

  /// All requests (web openList). Back leaves the portal.
  Future<void> openList() {
    _fromList = false;
    return _showList();
  }

  /// One request (web openRequest). Back leaves the portal.
  Future<void> openRequest(String id) {
    _fromList = false;
    return _showRequest(id);
  }

  /// From the list: Back comes back to the list.
  Future<void> pick(String id) {
    _fromList = true;
    return _showRequest(id);
  }

  /// One step back: a request opened from the list goes to the list, else the portal closes.
  void back() {
    if (_state.screen == RequestsScreen.request && _fromList) {
      _fromList = false;
      unawaited(_showList());
    } else {
      _leave();
    }
  }

  /// Leave the portal.
  void close() => _leave();

  /// Try again after a failed load.
  void reload() {
    if (_state.failed && _lastLoad != null) unawaited(_lastLoad!());
  }

  void setDraft(String text) {
    if (_openId == null || _state.screen != RequestsScreen.request) return;
    _drafts[_openId!] = text;
    _set(_state);
  }

  /// Send the draft as a reply.
  void send() {
    final id = _openId;
    if (id == null || _state.screen != RequestsScreen.request || _state.request == null) return;
    final text = (_drafts[id] ?? '').trim();
    if (text.isEmpty) return;
    _drafts[id] = '';
    final entryId = replyEntryId(_now(), _rand);
    _set(_state.copyWith(pending: [
      ..._state.pending,
      PendingReply(
        entryId: entryId,
        text: text,
        at: DateTime.fromMillisecondsSinceEpoch(_now(), isUtc: true).toIso8601String(),
        status: PendingStatus.sending,
      ),
    ]));
    unawaited(_sendText(id, entryId, text));
  }

  /// Try again on a reply that did not go.
  void retry(String entryId) {
    final p = _state.pending.where((x) => x.entryId == entryId).firstOrNull;
    if (p == null || p.status != PendingStatus.failed || _openId == null) return;
    unawaited(_sendText(_openId!, entryId, p.text));
  }

  /// A new conversation: the drafts go.
  void reset() => _drafts = {};

  @override
  void dispose() {
    _disposed = true;
    _offUpdate?.call();
    super.dispose();
  }
}
