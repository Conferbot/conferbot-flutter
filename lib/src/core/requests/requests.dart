/// "Your requests" (web conferbot-widget src/ts/home/requests/): a visitor's
/// own conversations with the team, where each one stands in plain words,
/// and a reply box that reaches the team. A reply to a solved request opens
/// it again. Ported from the React Native SDK (src/core/requests.ts).
///
/// Pure: the words (web words.ts), what the device remembers (web store.ts,
/// as values in and out; RequestsExtras keeps them in shared_preferences),
/// which visitor is asking (web api.ts `who`) and the socket calls with an
/// answer (web api.ts, embed-server socket/handlers/visitorRequestsHandler.js
/// and services/chatbot/visitorRequests.js). The screens are
/// requests_portal.dart.
///
/// Whose requests: the server lists a conversation only when its id is one
/// this device started AND its visitor id matches (the ids are random and
/// shown nowhere else), or when the app signed its user in (`user.hash`,
/// identity verification) - then their verified conversations on this bot
/// from any device. Only conversations a person on the team handles are
/// requests; a chat the AI answered alone is not one.
///
/// English only for now (the web's i18n `requests.*`, `when.*` keys).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../../models/user.dart';

// ------------------------------------------------------------ types

/// As the server sends them (visitorRequests.js `summary`).
class RequestSummary {
  const RequestSummary({
    required this.id,
    required this.title,
    required this.status,
    this.startedAt,
    this.lastAt,
    required this.lastFrom,
    required this.lastText,
    required this.teamName,
  });

  final String id;
  final String title;

  /// `open` or `solved`.
  final String status;
  final String? startedAt;
  final String? lastAt;

  /// `you` or `team`.
  final String lastFrom;
  final String lastText;
  final String teamName;

  bool get solved => status == 'solved';

  static String? _opt(dynamic v) => v?.toString();

  factory RequestSummary.fromJson(Map<String, dynamic> j) => RequestSummary(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        status: j['status'] == 'solved' ? 'solved' : 'open',
        startedAt: _opt(j['startedAt']),
        lastAt: _opt(j['lastAt']),
        lastFrom: j['lastFrom'] == 'team' ? 'team' : 'you',
        lastText: j['lastText']?.toString() ?? '',
        teamName: j['teamName']?.toString() ?? '',
      );

  RequestSummary copyWith({String? id, String? status, String? lastAt, String? lastFrom, String? teamName}) => RequestSummary(
        id: id ?? this.id,
        title: title,
        status: status ?? this.status,
        startedAt: startedAt,
        lastAt: lastAt ?? this.lastAt,
        lastFrom: lastFrom ?? this.lastFrom,
        lastText: lastText,
        teamName: teamName ?? this.teamName,
      );
}

/// visitorRequests.js `messagesOf`.
class RequestMessage {
  const RequestMessage({required this.id, required this.from, required this.name, required this.text, this.at});

  final String id;

  /// `you` or `team`.
  final String from;
  final String name;
  final String text;
  final String? at;

  bool get you => from != 'team';

  factory RequestMessage.fromJson(Map<String, dynamic> j) => RequestMessage(
        id: j['id']?.toString() ?? '',
        from: j['from'] == 'team' ? 'team' : 'you',
        name: j['name']?.toString() ?? '',
        text: j['text']?.toString() ?? '',
        at: j['at']?.toString(),
      );
}

class RequestDetail extends RequestSummary {
  const RequestDetail({
    required super.id,
    required super.title,
    required super.status,
    super.startedAt,
    super.lastAt,
    required super.lastFrom,
    required super.lastText,
    required super.teamName,
    this.messages = const [],
  });

  final List<RequestMessage> messages;

  factory RequestDetail.fromJson(Map<String, dynamic> j) {
    final s = RequestSummary.fromJson(j);
    final raw = j['messages'];
    return RequestDetail(
      id: s.id,
      title: s.title,
      status: s.status,
      startedAt: s.startedAt,
      lastAt: s.lastAt,
      lastFrom: s.lastFrom,
      lastText: s.lastText,
      teamName: s.teamName,
      messages: [
        if (raw is List)
          for (final m in raw)
            if (m is Map) RequestMessage.fromJson(Map<String, dynamic>.from(m)),
      ],
    );
  }
}

enum RequestState { replied, waiting, solved }

// ------------------------------------------------------------ the words

/// The web's English strings (i18n en `requests.*`, `common.*`, `transcript.you`).
class RequestsText {
  RequestsText._();
  static const title = 'Your requests';
  static const one = 'Your request';
  static const back = 'Back';
  static const loading = 'Loading...';
  static const loadFailed = "We couldn't load this just now.";
  static const tryAgain = 'Try again';
  static const empty = 'Nothing here yet. When you ask us something, you can follow it here.';
  static const you = 'You';
  static const supportTeam = 'Support team';
  static const replyPlaceholder = 'Write your reply...';
  static const reopenPlaceholder = 'Write here to open it again...';
  static const yourReply = 'Your reply';
  static const send = 'Send';
  static const sending = 'Sending...';
  static const notSent = 'Not sent.';
  static const locked = 'This conversation is closed for replies.';
  static const newReply = 'New reply';
  static String newReplyFrom(String name) => 'New reply from $name';
  static String seeAll(int n) => 'See all ($n)';

  /// The chat menu's item (the web has the home card instead).
  static String menu(int unread) => unread > 0 ? '$title · $newReply' : title;
}

/// Each state in a few plain words, never a ticket status (web words.ts STATE_WORDS).
typedef StateWords = ({String label, String detail});

const Map<RequestState, StateWords> stateWords = {
  RequestState.replied: (label: 'We replied', detail: 'Read it below. If you need anything else, just write back.'),
  RequestState.waiting: (label: "We're on it", detail: "We'll reply right here. You can close this - your message is safe with us."),
  RequestState.solved: (label: 'Solved', detail: "Still need help with this? Write below and we'll pick it up again."),
};

int _ms(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is DateTime) return v.millisecondsSinceEpoch;
  final s = v.toString();
  if (s.isEmpty) return 0;
  final asInt = int.tryParse(s);
  if (asInt != null) return asInt;
  return DateTime.tryParse(s)?.millisecondsSinceEpoch ?? 0;
}

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

/// A reply from the team on an open request, not read on this device yet (web isNewReply).
bool isNewReply(RequestSummary r, Map<String, int> seen) =>
    // A solved one is done: its last word is "Solved", not a reply to read.
    r.status != 'solved' && r.lastFrom == 'team' && _ms(r.lastAt) > (seen[r.id] ?? 0);

RequestState stateOf(RequestSummary r) =>
    r.status == 'solved' ? RequestState.solved : (r.lastFrom == 'team' ? RequestState.replied : RequestState.waiting);

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// "Just now", "5 min ago", "3 hours ago", "Yesterday", "Monday", "3 Oct" (web whenWords, English).
String whenWords(dynamic v, [int? now]) {
  final n = now ?? _nowMs();
  final t = _ms(v);
  if (t == 0) return '';
  final diff = math.max(0, n - t);
  if (diff < 60 * 1000) return 'Just now';
  if (diff < 60 * 60 * 1000) return '${diff ~/ 60000} min ago';
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  final today = DateTime.fromMillisecondsSinceEpoch(n);
  final startOfToday = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
  if (t >= startOfToday) {
    final h = diff ~/ 3600000;
    return h <= 1 ? '1 hour ago' : '$h hours ago';
  }
  if (t >= startOfToday - 86400000) return 'Yesterday';
  if (t >= startOfToday - 6 * 86400000) return _days[d.weekday - 1];
  return '${d.day} ${_months[d.month - 1]}${d.year != today.year ? ' ${d.year}' : ''}';
}

/// The line under a request's title (web rowLine).
String rowLine(RequestSummary r, Map<String, int> seen, [int? now]) {
  final when = whenWords(r.lastAt, now);
  final head = isNewReply(r, seen)
      ? (r.teamName.isNotEmpty ? RequestsText.newReplyFrom(r.teamName) : RequestsText.newReply)
      : stateWords[stateOf(r)]!.label;
  return when.isNotEmpty ? '$head · $when' : head;
}

/// Newest replies first, then whatever moved last (web ordered). Stable.
List<RequestSummary> ordered(List<RequestSummary> list, Map<String, int> seen) {
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final fresh = (isNewReply(b.$2, seen) ? 1 : 0) - (isNewReply(a.$2, seen) ? 1 : 0);
    if (fresh != 0) return fresh;
    final moved = _ms(b.$2.lastAt) - _ms(a.$2.lastAt);
    if (moved != 0) return moved.sign;
    return a.$1 - b.$1;
  });
  return [for (final e in indexed) e.$2];
}

/// How many requests have a team reply not read here: the app's badge.
int unreadCount(List<RequestSummary>? list, Map<String, int> seen) =>
    (list ?? const []).where((r) => isNewReply(r, seen)).length;

/// Read up to the newest message, by the server's clock too (web view.ts seenAt).
int seenAt(String? lastAt, [int? now]) => math.max(now ?? _nowMs(), _ms(lastAt));

/// The home card shows two; "See all" when there are more (web card.ts ON_HOME).
const requestsOnHome = 2;

/// The list is read again at most this often when nothing forces it (web card.ts).
const requestsRefreshGap = Duration(seconds: 15);

/// The reply box's limit (web view.ts maxLength, the server's MAX_REPLY).
const requestsMaxReply = 4000;

// ------------------------------------------------------------ links in a message

final _urlRe = RegExp(r'''\bhttps?://[^\s<>"']+[^\s<>"'.,;:!?)\]]''', caseSensitive: false);

/// A piece of a message: text, or a link when [url] is set.
typedef LinkRun = ({String text, String? url});

/// Text with its links as their own runs, everything else text (web view.ts appendText).
List<LinkRun> linkRuns(String? text) {
  final s = text ?? '';
  final out = <LinkRun>[];
  var at = 0;
  for (final m in _urlRe.allMatches(s)) {
    if (m.start > at) out.add((text: s.substring(at, m.start), url: null));
    out.add((text: m[0]!, url: m[0]!));
    at = m.end;
  }
  if (at < s.length) out.add((text: s.substring(at), url: null));
  return out;
}

// ------------------------------------------------------------ what the device remembers

/// The ids of the chats this device started (newest first) and when each
/// request was last read here (request id -> ms, oldest mark first).
class RequestMemory {
  const RequestMemory({this.sessions = const [], this.seen = const {}});
  final List<String> sessions;
  final Map<String, int> seen;
}

const requestsMaxSessions = 30;

/// A conversation id the server accepts (visitorRequests.js SESSION).
final requestsSessionRe = RegExp(r'^[\w-]{6,64}$');
const _seenKept = 60;

/// Per bot (the web keeps `cb_req_<botId>` in localStorage).
String requestsStorageKey(String? botId) => '@conferbot:requests:${(botId ?? '').isEmpty ? 'default' : botId}';

/// What was stored, cleaned (web readRequests). Anything unreadable is nothing.
RequestMemory parseMemory(String? raw) {
  try {
    final m = jsonDecode(raw ?? 'null');
    if (m is! Map) return const RequestMemory();
    final sessions = [
      if (m['sessions'] is List)
        for (final s in m['sessions'] as List)
          if (s is String && requestsSessionRe.hasMatch(s)) s,
    ].take(requestsMaxSessions).toList();
    final seen = <String, int>{};
    final src = m['seen'];
    if (src is Map) {
      src.forEach((k, v) {
        if (k is! String || !requestsSessionRe.hasMatch(k)) return;
        final t = v is num ? v : (v is String ? num.tryParse(v) : null);
        if (t != null && t.isFinite) seen[k] = t.toInt();
      });
    }
    return RequestMemory(sessions: sessions, seen: seen);
  } catch (_) {
    return const RequestMemory();
  }
}

/// What to store (web store.ts write): 30 sessions, the last 60 read marks.
String serializeMemory(RequestMemory m) {
  final keys = m.seen.keys.toList();
  final kept = keys.length > _seenKept ? keys.sublist(keys.length - _seenKept) : keys;
  return jsonEncode({
    'sessions': m.sessions.take(requestsMaxSessions).toList(),
    'seen': {for (final k in kept) k: m.seen[k]},
  });
}

/// A chat on this device was saved: it may become a request (web rememberSession). Null when nothing changes.
RequestMemory? withSession(RequestMemory m, String? session) {
  final s = session ?? '';
  if (!requestsSessionRe.hasMatch(s) || (m.sessions.isNotEmpty && m.sessions.first == s)) return null;
  return RequestMemory(
    sessions: [s, ...m.sessions.where((x) => x != s)].take(requestsMaxSessions).toList(),
    seen: m.seen,
  );
}

/// They read this request up to [at] (web markSeen). Null when nothing changes.
RequestMemory? withSeen(RequestMemory m, String id, int at) {
  if (id.isEmpty || (m.seen[id] ?? 0) >= at) return null;
  // Re-inserted last, so the newest read marks are the ones kept.
  final seen = Map<String, int>.of(m.seen)..remove(id);
  seen[id] = at;
  return RequestMemory(sessions: m.sessions, seen: seen);
}

/// The visitor wrote in this chat: remember it (web index.ts `_sendResponse`, a `user-` entry in the record).
bool hasVisitorEntry(List<dynamic>? record) => (record ?? const []).any((e) {
      if (e is! Map) return false;
      final v = (e['shape'] ?? e['type'] ?? '').toString();
      return v.startsWith('user-');
    });

// ------------------------------------------------------------ who is asking

/// Every call says which visitor this is (web api.ts `who`): only what the server checks.
Map<String, dynamic> requestsWho(String? visitorId, RequestMemory memory, ConferBotUser? user) => {
      'visitorId': visitorId ?? '',
      'sessions': memory.sessions,
      if (user != null)
        'user': {
          if (user.id.isNotEmpty) 'id': user.id,
          if (user.email != null) 'email': user.email,
          if (user.hash != null) 'hash': user.hash,
        },
    };

/// Nothing on this device and nobody signed in: nothing to ask about (web card.ts refresh).
bool canAskForRequests(RequestMemory memory, ConferBotUser? user) =>
    memory.sessions.isNotEmpty || (user?.hash ?? '').isNotEmpty;

// ------------------------------------------------------------ the server

/// What the SDK's socket offers (services/socket_client.dart).
abstract class RequestsSocket {
  Future<dynamic> emitWithAck(String event, dynamic payload, Duration timeout);
  void emit(String event, dynamic payload);

  /// Listen; returns the unsubscribe.
  void Function() on(String event, void Function(dynamic data) fn);
}

/// A reply's outcome: the request as it is now, or why it did not go
/// (`locked`, `not_found`, `empty`, `error`, or `offline` when no answer came).
class ReplyResult {
  const ReplyResult({required this.ok, this.request, this.reason});
  final bool ok;
  final RequestDetail? request;
  final String? reason;
}

abstract class RequestsApi {
  Future<List<RequestSummary>?> list();
  Future<RequestDetail?> open(String id);

  /// No more live updates for it.
  void close(String id);
  Future<ReplyResult> reply(String id, String text, String entryId);

  /// A request changed on the server (a team reply, solved). Returns the unsubscribe.
  void Function() onUpdate(void Function(String id) fn);
}

/// web api.ts TIMEOUT_MS
const requestsTimeout = Duration(seconds: 10);

/// The socket events (embed-server visitorRequestsHandler.js).
class RequestEvents {
  RequestEvents._();
  static const list = 'my-requests';
  static const open = 'my-request-open';
  static const close = 'my-request-close';
  static const reply = 'my-request-reply';
  static const update = 'my-request-update';
}

Map<String, dynamic>? _answerOf(dynamic a) {
  if (a is List) a = a.isEmpty ? null : a.first;
  return a is Map ? Map<String, dynamic>.from(a) : null;
}

/// The calls (web api.ts requestsApi). [who] is read at each call. The
/// socket's 'connect' fires on every connect: the server forgets a
/// request's live updates when the connection drops, so the open one is
/// read (and joined) again.
class SocketRequestsApi implements RequestsApi {
  SocketRequestsApi(this._socket, this._who);

  final RequestsSocket? Function() _socket;
  final Map<String, dynamic> Function() _who;
  String? _current;

  Future<Map<String, dynamic>?> _call(String event, Map<String, dynamic> payload) async {
    final s = _socket();
    if (s == null) return null;
    try {
      return _answerOf(await s.emitWithAck(event, payload, requestsTimeout).timeout(requestsTimeout));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<RequestSummary>?> list() async {
    final a = await _call(RequestEvents.list, _who());
    final raw = a?['requests'];
    if (a?['ok'] != true || raw is! List) return null;
    return [
      for (final r in raw)
        if (r is Map) RequestSummary.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  @override
  Future<RequestDetail?> open(String id) async {
    _current = id;
    final a = await _call(RequestEvents.open, {..._who(), 'chatSessionId': id});
    final r = a?['request'];
    return a?['ok'] == true && r is Map ? RequestDetail.fromJson(Map<String, dynamic>.from(r)) : null;
  }

  @override
  void close(String id) {
    if (_current == id) _current = null;
    try {
      _socket()?.emit(RequestEvents.close, {'chatSessionId': id});
    } catch (_) {
      // nothing to stop
    }
  }

  @override
  Future<ReplyResult> reply(String id, String text, String entryId) async {
    final a = await _call(RequestEvents.reply, {..._who(), 'chatSessionId': id, 'text': text, 'entryId': entryId});
    if (a == null) return const ReplyResult(ok: false, reason: 'offline');
    final r = a['request'];
    return ReplyResult(
      ok: a['ok'] == true,
      request: r is Map ? RequestDetail.fromJson(Map<String, dynamic>.from(r)) : null,
      reason: a['reason']?.toString(),
    );
  }

  @override
  void Function() onUpdate(void Function(String id) fn) {
    final s = _socket();
    if (s == null) return () {};
    final offUpdate = s.on(RequestEvents.update, (data) {
      final id = data is Map ? data['chatSessionId'] : null;
      if (id is String) fn(id);
    });
    final offConnect = s.on('connect', (_) {
      final c = _current;
      if (c != null) fn(c);
    });
    return () {
      offUpdate();
      offConnect();
    };
  }
}

/// A reply's id, so a retry is one message on the server (web view.ts; the
/// server accepts `request-reply-[\w-]{1,60}`): base36 time and 6 random.
String replyEntryId([int? now, double Function()? rand]) {
  final t = now ?? _nowMs();
  final r = ((rand ?? math.Random().nextDouble)() * 2176782336).floor().clamp(0, 2176782335);
  return 'request-reply-${t.toRadixString(36)}${r.toRadixString(36).padLeft(6, '0')}';
}

// ------------------------------------------------------------ the look

String? _hex(dynamic v) {
  if (v is! String) return null;
  final s = v.trim();
  return RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6})$', caseSensitive: false).hasMatch(s) ? s : null;
}

double _lightness(String h) {
  var s = h.substring(1);
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  double ch(int i) {
    final c = int.parse(s.substring(i, i + 2), radix: 16) / 255;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * ch(0) + 0.7152 * ch(2) + 0.0722 * ch(4);
}

/// The accent for the Back link, the visitor's bubbles and Send (web
/// firstImpression.ts accentFor, brand/brand.ts brandColorOf): the brand
/// colour (not with a theme palette), the header colour, the launcher's,
/// unless too light to read (homeUtils.ts isLight, luminance over 0.55),
/// then indigo.
String requestsAccent(Map<String, dynamic>? c) {
  final brand = (c?['_themePalette'] == null || c?['_themePalette'] == false ? _hex(c?['brandColor']) : null) ?? c?['headerBgColor'];
  final launcher = c?['widgetIconThemeType'] == 'Gradient' && c?['widgetGradientBgOne'] != null && c?['widgetGradientBgTwo'] != null
      ? [c!['widgetGradientBgOne'], c['widgetGradientBgTwo']]
      : [c?['widgetIconBgColor'] ?? c?['headerBgColor']];
  for (final v in [brand, c?['headerBgColor'], ...launcher]) {
    final h = _hex(v);
    if (h != null && _lightness(h) <= 0.55) return h;
  }
  return '#4F46E5';
}
