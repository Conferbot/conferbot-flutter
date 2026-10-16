/// Live chat events beyond the handover line (handover_state.dart): the chat
/// going back to the queue, a transfer, the same end again, a blocked
/// visitor and the closed chat. Ported from the React Native SDK's
/// src/core/liveEvents.ts, itself from the web widget:
///
///   ts/chat/liveTakeover.ts   live-chat-requeued ("Connecting you to another
///                             agent..." / "Connecting you to Sales..."),
///                             live-chat-transferred (kept in the record)
///   utils/recordIds.ts        endedSinceLastLive: a repeated chat-ended is
///                             the same end, and draws nothing
///   ts/chat/closedState.ts    the closed chat ("This conversation has been
///                             closed."), index.ts _applyVisitorBlock
///
/// Pure Dart.
library;

import 'dart:math';

import '../i18n/i18n.dart';

/// The socket events (models/socket_events.dart has them too).
class LiveEventNames {
  LiveEventNames._();
  static const requeued = 'live-chat-requeued';
  static const transferred = 'live-chat-transferred';
  static const blocked = 'visitor-blocked';
}

enum ClosedKind { blocked, ended }

class ClosedState {
  final ClosedKind kind;
  final String text;

  /// Offer "Start a new chat" (never to a blocked visitor: the server refuses them).
  final bool newChat;

  /// The composer takes no more input.
  final bool inputOff;

  const ClosedState({required this.kind, required this.text, required this.newChat, required this.inputOff});

  @override
  bool operator ==(Object other) =>
      other is ClosedState && other.kind == kind && other.text == text && other.newChat == newChat && other.inputOff == inputOff;

  @override
  int get hashCode => Object.hash(kind, text, newChat, inputOff);

  @override
  String toString() => 'ClosedState($kind, $text, newChat: $newChat, inputOff: $inputOff)';
}

class LiveEvents {
  LiveEvents._();

  static final _random = Random();

  /// Its own id per event entry: two in the same millisecond must not merge (web liveEventId).
  static String eventId(String kind, {int? now, String? rand}) =>
      '$kind-${now ?? DateTime.now().millisecondsSinceEpoch}-${rand ?? _random.nextInt(1 << 32).toRadixString(36)}';

  // ---- Back in the queue (live-chat-requeued) ----

  /// The English words (the web's en takeover.requeued).
  static const requeuedDefault = 'Connecting you to another agent...';

  /// What the visitor reads when the chat goes back to the queue (web
  /// requeuedText), in the active language.
  static String requeuedText([Object? teamName]) {
    var team = teamName is String ? teamName.replaceAll(RegExp(r'[<>]'), '').trim() : '';
    if (team.length > 60) team = team.substring(0, 60);
    return team.isEmpty ? t('takeover.requeued') : t('takeover.requeuedTeam', {'team': team});
  }

  /// The requeued line's record entry (web: id, type, time, text).
  static Map<String, dynamic> requeuedEntry(dynamic data, {String? time}) {
    final id = eventId('requeued');
    return {
      'id': id,
      '_id': id,
      'type': 'live-chat-requeued',
      'shape': 'live-chat-requeued',
      'time': time ?? DateTime.now().toUtc().toIso8601String(),
      'text': requeuedText(data is Map ? data['teamName'] : null),
    };
  }

  // ---- Transferred (live-chat-transferred) ----

  /// The transfer line the server wrote into the record, as the widget keeps
  /// it in its own copy (so the next write keeps it). Null when malformed.
  /// Not drawn, as on the web: the requeued line or the next agent's join
  /// says what happened.
  static Map<String, dynamic>? transferEntry(dynamic data) {
    final e = data is Map ? data['entry'] : null;
    if (e is! Map || e['id'] is! String || e['text'] is! String) return null;
    final text = e['text'] as String;
    return {
      'id': e['id'],
      '_id': e['id'],
      'shape': 'live-chat-transfer',
      'type': 'live-chat-transfer',
      'time': e['time'] ?? DateTime.now().toUtc().toIso8601String(),
      'text': text.length > 200 ? text.substring(0, 200) : text,
      if (e['kind'] != null) 'kind': e['kind'].toString(),
    };
  }

  // ---- The same end again (chat-ended) ----

  /// A live chat going on again: someone joined, the AI came back, or a
  /// message went either way (web recordIds.ts LIVE_AGAIN).
  static const liveAgain = {
    'agent-joined-message',
    'agent-joined',
    'ai-agent-resumed',
    'agent-message',
    'agent-message-file',
    'agent-message-audio',
    'agent-message-rich',
    'user-live-message',
    'user-live-message-file',
  };

  /// Has the live chat already ended, with nothing live since? A repeated
  /// chat-ended is then the same end again: no second "Chat ended" line, no
  /// second survey (web endedSinceLastLive).
  static bool endedSinceLastLive(List<dynamic>? record) {
    final list = record ?? const [];
    for (var i = list.length - 1; i >= 0; i--) {
      final r = list[i];
      if (r is! Map) continue;
      final type = r['type']?.toString();
      final shape = r['shape']?.toString();
      final kind = (type != null && type.isNotEmpty) ? type : shape;
      if (kind == 'agent-chat-ended') return true;
      if (liveAgain.contains(kind) || liveAgain.contains(shape)) return false;
    }
    return false;
  }

  // ---- Blocked, and the closed chat ----

  /// The neutral line a blocked visitor sees (embed-server visitorBlock CLOSED_TEXT, web system.closed).
  static const closedText = 'This conversation has been closed.';
  static const chatEndedText = 'Chat ended';
  static const newChatText = 'Start a new chat';

  /// The same words in the active language (web system.closed,
  /// system.chatEnded; "Start a new chat" is the SDK's own button). The
  /// English constants above stay as what the record and the server say.
  static String get closedLabel => t('system.closed');
  static String get chatEndedLabel => t('system.chatEnded');
  static String get newChatLabel => t('sdk.live.newChat');

  /// The handshake refused a blocked visitor (connect_error "visitor_blocked").
  static bool isBlockedError(dynamic err) {
    if (err is String) return err == 'visitor_blocked';
    if (err is Map) return err['message'] == 'visitor_blocked';
    try {
      return (err as dynamic).message == 'visitor_blocked';
    } catch (_) {
      return false;
    }
  }

  /// The visitor-blocked event's line: the server's words, else ours.
  static String blockedText(dynamic data) {
    var m = data is Map && data['message'] is String ? (data['message'] as String).trim() : '';
    if (m.length > 200) m = m.substring(0, 200);
    return m.isEmpty ? closedLabel : m;
  }

  /// The chat's closed state, or null while it is open:
  ///   blocked  the workspace blocked the visitor: the neutral line, no
  ///            input, no new chat.
  ///   ended    the live chat ended and nothing is going on (no step
  ///            waiting, no person, nothing live since the end): the composer
  ///            is off, as the web turns it off on chat-ended, and a button
  ///            starts a new chat.
  static ClosedState? closedStateOf(List<dynamic>? record, {String? blocked, bool stepWaiting = false, bool live = false}) {
    if (blocked != null && blocked.isNotEmpty) {
      return ClosedState(kind: ClosedKind.blocked, text: blocked, newChat: false, inputOff: true);
    }
    if (stepWaiting || live) return null;
    if (!endedSinceLastLive(record)) return null;
    return ClosedState(kind: ClosedKind.ended, text: chatEndedLabel, newChat: true, inputOff: true);
  }
}
