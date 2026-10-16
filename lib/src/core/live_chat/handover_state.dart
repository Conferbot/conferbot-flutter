/// Where a live-chat handover stands, read from the record, and the
/// "Connecting you with the team…" line that marks it. Ported from the React
/// Native SDK (src/core/handoverState.ts), itself from the web widget:
/// conferbot-widget src/ts/chat/handoverState.ts (the record reading),
/// src/core/events/agentListeners.ts (agent-left reasons, agent-accepted),
/// src/ts/chat/handlers/special.ts (_handleHandoverAccepted, the queue's
/// leave) and src/index.ts (the restore path).
///
///   bot / AI  ->  connecting (an AI agent passed the visitor on: the line
///                 with its typing dots)  ->  one of
///     joined       a person accepted              "Connected with the team"
///     unavailable  nobody could (the AI took the  "The team couldn't join just now"
///                  chat back, or the fallback ran)
///     cancelled    the visitor left the queue     "You left the queue"
///     ended        the chat ended first           "Chat ended before the team joined"
///
/// The record is a list of maps: the web's entries, this SDK's server
/// record (`ChatState.getRecordForServer()`, where an entry's fields sit
/// under `data`), or display entries. A field is read at the top first,
/// then under `data`. Pure: functions that change entries return new maps
/// and leave the input alone.
library;

import '../i18n/i18n.dart';

enum HandoverOutcome { joined, unavailable, cancelled, ended }

enum HandoverPhase { none, connecting, joined }

/// What an agent-left means (web agentListeners.ts "agent-left").
enum AgentLeftKind {
  /// An AI pausing an idle visitor (reason visitor_inactive): draw nothing.
  ignore,

  /// An AI passing the visitor to a person: the Connecting line.
  handover,

  /// A person left: "<name> left the chat".
  left,
}

/// What a restored chat does next (see [HandoverRecord.restoreStep]).
enum RestoreStep { live, wait, continueFlow, ask, start }

/// agent-accepted, read against the record (web special.ts _handleHandoverAccepted).
class AcceptedPlan {
  final bool ai;

  /// How a pending Connecting line settles.
  final HandoverOutcome outcome;

  /// Draw the join line (not for the same person again).
  final bool announce;

  /// The person follows an AI handover: the join line's note.
  final bool afterAI;

  /// A person (never the AI) joined, for the first time: cb:human-joined.
  final bool humanJoined;

  const AcceptedPlan({required this.ai, required this.outcome, required this.announce, required this.afterAI, required this.humanJoined});
}

class RestoredAgent {
  final String id;
  final String name;
  final String? email;
  const RestoredAgent({required this.id, required this.name, this.email});
}

/// The server's live-chat-state applied to a restored record.
class RestoredLiveChat {
  /// live: a person has it; waiting: still in the queue; fallback: nobody
  /// joined in time; ended: the chat ended; none: no handover on the server.
  final String status;

  /// The person on the chat (live only).
  final RestoredAgent? agent;

  /// How a pending Connecting line settles now; null leaves it pending.
  final HandoverOutcome? settle;

  /// Draw the join line the closed app missed.
  final bool drawJoin;

  /// That join follows an AI handover (its note).
  final bool afterAI;

  /// Seconds left of the handover's max wait (waiting only).
  final int? remainingSeconds;

  const RestoredLiveChat({
    required this.status,
    this.agent,
    this.settle,
    this.drawJoin = false,
    this.afterAI = false,
    this.remainingSeconds,
  });
}

class HandoverRecord {
  HandoverRecord._();

  /// The web's English strings (ts/i18n/en.ts handover.*); `lineText` draws
  /// them in the active language.
  static const pendingText = 'Connecting you with the team…';
  static const outcomeText = {
    HandoverOutcome.joined: 'Connected with the team',
    HandoverOutcome.unavailable: "The team couldn't join just now",
    HandoverOutcome.cancelled: 'You left the queue',
    HandoverOutcome.ended: 'Chat ended before the team joined',
  };

  /// The note under a person's join after an AI handed the visitor on. Kept
  /// in English on the record entry (the web's HANDED_OVER_NOTE marker);
  /// `handedOverNoteText` draws it in the active language.
  static const handedOverNote = 'They can see your conversation so far';

  /// A join's note as drawn: the marker in the active language (web
  /// agentJoinedDivider.ts), else as written.
  static String handedOverNoteText(String note) => note == handedOverNote ? t('system.handedOverNote') : note;

  static const _outcomeKey = {
    HandoverOutcome.joined: 'handover.joined',
    HandoverOutcome.unavailable: 'handover.unavailable',
    HandoverOutcome.cancelled: 'handover.cancelled',
    HandoverOutcome.ended: 'handover.ended',
  };

  /// Things that close a live-chat episode for good.
  static const closers = ['agent-chat-ended', 'agent-declined-message', 'queue-self-resolved', 'ai-agent-inactive-close'];

  static HandoverOutcome? outcomeOf(dynamic v) {
    if (v is HandoverOutcome) return v;
    for (final o in HandoverOutcome.values) {
      if (o.name == v) return o;
    }
    return null;
  }

  /// The line's words: pending, or how the wait ended.
  static String lineText([HandoverOutcome? outcome]) => t(outcome == null ? 'handover.pending' : _outcomeKey[outcome]!);

  /// "<name> joined the chat" (web agentJoinedDivider.ts).
  static String joinedText(String? name) {
    final n = (name ?? '').trim();
    return '${n.isEmpty ? t('agent.anAgent') : n}${t('system.joined')}';
  }

  /// "<name> left the chat", or the pending line for a handover (web agentLeftDivider.ts).
  static String agentLeftText(String? name, bool handover) {
    if (handover) return lineText();
    final n = (name ?? '').trim();
    return '${n.isEmpty ? t('agent.theAgent') : n}${t('system.left')}';
  }

  // ---------- reading the record ----------

  /// A field of an entry, at the top or under `data`.
  static dynamic field(dynamic r, String key) {
    if (r is! Map) return null;
    if (r.containsKey(key) && r[key] != null) return r[key];
    final d = r['data'];
    return d is Map ? d[key] : null;
  }

  static String typeOf(dynamic r) {
    if (r is! Map) return '';
    final t = r['type'] ?? r['shape'];
    return t == null ? '' : t.toString();
  }

  static bool _isJoin(String t) => t == 'agent-joined-message' || t == 'agent-joined';

  /// An AI agent's join (recorded by a flow bot's visible AI handover).
  static bool isAIJoin(dynamic r) => field(r, 'ai') == true || '${field(r, 'agentId') ?? ''}'.startsWith('ai-agent-');

  /// An agent-left entry that is an AI handing the visitor to the team.
  static bool isHandoverLeft(dynamic r) => typeOf(r) == 'agent-left-chat' && field(r, 'handover') == true;

  /// Where the latest live episode stands.
  static HandoverPhase phase(List<dynamic>? record) {
    final list = record ?? const [];
    for (var i = list.length - 1; i >= 0; i--) {
      final r = list[i];
      final t = typeOf(r);
      if (closers.contains(t)) return HandoverPhase.none;
      if (_isJoin(t)) {
        if (isAIJoin(r)) continue;
        return HandoverPhase.joined;
      }
      if (t == 'agent-left-chat') return field(r, 'handover') == true ? HandoverPhase.connecting : HandoverPhase.none;
    }
    return HandoverPhase.none;
  }

  /// "Talk to a person" is offered only when nobody is coming or here (web quickActions.ts).
  static bool talkToPersonAllowed(List<dynamic>? record) => phase(record) == HandoverPhase.none;

  /// The same person joining again (a repeat agent-accepted after a reconnect).
  static bool isRepeatJoin(List<dynamic>? record, dynamic agentId) {
    if (agentId == null || agentId == '') return false;
    final list = record ?? const [];
    for (var i = list.length - 1; i >= 0; i--) {
      final r = list[i];
      final t = typeOf(r);
      if (_isJoin(t)) return '${field(r, 'agentId') ?? ''}' == '$agentId';
      if (t == 'agent-left-chat' || closers.contains(t)) return false;
    }
    return false;
  }

  /// How the handover line at [index] ended, from what came after it; null
  /// while it is still pending. A `settled` already written wins.
  static HandoverOutcome? outcomeAt(List<dynamic> record, int index) {
    if (index < 0 || index >= record.length) return null;
    final written = outcomeOf(field(record[index], 'settled'));
    if (written != null) return written;
    for (var i = index + 1; i < record.length; i++) {
      final r = record[i];
      final t = typeOf(r);
      if (_isJoin(t)) return isAIJoin(r) ? HandoverOutcome.unavailable : HandoverOutcome.joined;
      if (t == 'agent-declined-message') return HandoverOutcome.unavailable;
      if (t == 'queue-self-resolved') return HandoverOutcome.cancelled;
      if (t == 'agent-chat-ended' || t == 'ai-agent-inactive-close') return HandoverOutcome.ended;
      // Escalated again: this earlier wait was over one way or another.
      if (isHandoverLeft(r)) return HandoverOutcome.unavailable;
    }
    return null;
  }

  static bool _pending(dynamic r) => isHandoverLeft(r) && outcomeOf(field(r, 'settled')) == null;

  /// Is a handover line still waiting (so a repeat escalation draws none)?
  static bool hasPendingLine(List<dynamic>? record) => (record ?? const []).any(_pending);

  /// The ids of the handover lines still pending.
  static List<String> pendingLineIds(List<dynamic>? record) =>
      (record ?? const []).where(_pending).map((r) => '${(r as Map)['id'] ?? r['_id'] ?? ''}').toList();

  static Map<String, dynamic> _with(Map r, Map<String, dynamic> marks) {
    final out = Map<String, dynamic>.from(r);
    if (r['data'] is Map && !r.containsKey('handover') && !r.containsKey('agentId')) {
      out['data'] = {...Map<String, dynamic>.from(r['data'] as Map), ...marks};
    } else {
      out.addAll(marks);
    }
    return out;
  }

  static Map<String, dynamic> _settledEntry(Map r, HandoverOutcome o) {
    final out = _with(r, {'settled': o.name});
    if (r.containsKey('text')) out['text'] = lineText(o);
    return out;
  }

  /// Settle every pending handover line: `settled` is written, and an entry
  /// that carries display `text` gets the settled words. Returns the same
  /// list when nothing was pending.
  static ({List<dynamic> record, int settled}) settleEntries(List<dynamic> record, HandoverOutcome outcome) {
    var settled = 0;
    final next = record.map((r) {
      if (!_pending(r)) return r;
      settled++;
      return _settledEntry(r as Map, outcome);
    }).toList();
    return (record: settled > 0 ? next : record, settled: settled);
  }

  /// Before a restored record is drawn: settle every handover line whose
  /// outcome the record already knows, and mark a person's join that
  /// followed an AI handover (it draws "They can see your conversation so far").
  static ({List<dynamic> record, int changed}) annotateRestored(List<dynamic> record) {
    var changed = 0;
    var handedOver = false;
    final next = <dynamic>[];
    for (var i = 0; i < record.length; i++) {
      final r = record[i];
      if (isHandoverLeft(r)) {
        handedOver = true;
        if (outcomeOf(field(r, 'settled')) != null) {
          next.add(r);
          continue;
        }
        final o = outcomeAt(record, i);
        if (o == null) {
          next.add(r);
          continue;
        }
        changed++;
        next.add(_settledEntry(r as Map, o));
        continue;
      }
      final t = typeOf(r);
      var out = r;
      if (_isJoin(t) && handedOver && !isAIJoin(r) && field(r, 'afterAI') != true) {
        changed++;
        out = _with(r as Map, {'afterAI': true, 'note': handedOverNote});
      }
      if (closers.contains(t)) handedOver = false;
      next.add(out);
    }
    return (record: changed > 0 ? next : record, changed: changed);
  }

  /// Did an AI agent hand this chat to a person (so the person has read it)?
  static bool aiHandedOver(List<dynamic>? record) => (record ?? const []).any(isHandoverLeft);

  // ---------- socket events ----------

  static Map? _details(dynamic data) => data is Map && data['agentDetails'] is Map ? data['agentDetails'] as Map : null;

  static AgentLeftKind agentLeftKind(dynamic data) {
    final m = data is Map ? data : const {};
    if (m['reason'] == 'visitor_inactive') return AgentLeftKind.ignore;
    if (m['reason'] == 'escalated' || m['handover'] == true || _details(data)?['isAIAgent'] == true) return AgentLeftKind.handover;
    return AgentLeftKind.left;
  }

  /// An agent-accepted from an AI agent (taking the chat, or taking it back).
  static bool isAIAccept(dynamic data) {
    final d = _details(data);
    return d?['isAIAgent'] == true || '${d?['_id'] ?? ''}'.startsWith('ai-agent-');
  }

  static AcceptedPlan acceptedPlan(List<dynamic>? record, dynamic data) {
    final ai = isAIAccept(data);
    final repeat = isRepeatJoin(record, _details(data)?['_id']);
    return AcceptedPlan(
      ai: ai,
      outcome: ai ? HandoverOutcome.unavailable : HandoverOutcome.joined,
      announce: !repeat,
      afterAI: !ai && aiHandedOver(record),
      humanJoined: !ai && !repeat,
    );
  }

  // ---------- leaving the queue ----------

  /// queue-self-resolve: the visitor leaves the queue (embed-server handoverHandler.js).
  static Map<String, dynamic> queueSelfResolvePayload(String chatSessionId, [String? articleId]) => {
        'chatSessionId': chatSessionId,
        if (articleId != null && articleId.isNotEmpty) 'articleId': articleId,
      };

  /// The server's answer to queue-self-resolve: leave the wait, or stay
  /// because a person already picked the chat up. The server says
  /// agent_joined only while the ticket is open; once a person accepted it
  /// answers not_waiting, so ask live-chat-state and pass it as [state].
  static bool queueLeaveStays(dynamic res, [dynamic state]) {
    final r = res is Map ? res : const {};
    final s = state is Map ? state : const {};
    return r['reason'] == 'agent_joined' || (r['ok'] != true && s['status'] == 'live');
  }

  /// Ask live-chat-state before leaving on this answer to queue-self-resolve?
  static bool queueLeaveNeedsState(dynamic res) => res is Map && res['ok'] != true && res['reason'] == 'not_waiting';

  // ---------- restore (live-chat-state) ----------

  static const _restoreLiveTypes = [
    'agent-joined-message',
    'agent-message',
    'agent-message-file',
    'agent-message-audio',
    'agent-message-rich',
    'user-live-message',
    'user-live-message-file',
    'agent-left-chat',
  ];
  static const _episodeClosers = ['agent-declined-message', 'agent-chat-ended', 'queue-self-resolved'];

  static bool _liveEntry(dynamic r) =>
      r is Map && (_restoreLiveTypes.contains('${r['type'] ?? ''}') || _restoreLiveTypes.contains('${r['shape'] ?? ''}'));

  /// A restored chat: should the server be asked where it stands
  /// (live-chat-state)? Only the latest live episode counts.
  /// [atHandover]: the flow was waiting on its handover step.
  static bool restoreNeedsLiveChatState(List<dynamic>? record, {bool atHandover = false}) {
    final list = record ?? const [];
    var start = 0;
    for (var i = 0; i < list.length; i++) {
      final r = list[i];
      final t = '${r is Map ? r['type'] ?? '' : ''}';
      if ((t == 'agent-left-chat' && field(r, 'takeover') == true) || _episodeClosers.contains(t)) start = i + 1;
    }
    final ongoing = list.skip(start).any(_liveEntry);
    final ended = list.any((r) => r is Map && _episodeClosers.contains('${r['type'] ?? ''}')) && !ongoing;
    return ongoing || (atHandover && !ended);
  }

  /// The server's live-chat-state (embed-server getLiveChatState: status
  /// live | waiting | fallback | ended | none, agentDetails, waitEndsAt)
  /// applied to a restored record (web index.ts _applyRestoredLiveChatState).
  static RestoredLiveChat restoredLiveChat(dynamic state, List<dynamic>? record, {DateTime? now}) {
    final s = state is Map ? state : const {};
    final raw = '${s['status'] ?? 'none'}';
    final details = s['agentDetails'] is Map ? s['agentDetails'] as Map : null;
    final person = details != null && details['isAIAgent'] != true ? details : null;
    if (raw == 'live' && person != null) {
      final email = person['email']?.toString();
      return RestoredLiveChat(
        status: 'live',
        agent: RestoredAgent(id: '${person['_id'] ?? ''}', name: '${person['name'] ?? ''}', email: email == null || email.isEmpty ? null : email),
        settle: HandoverOutcome.joined,
        drawJoin: phase(record) != HandoverPhase.joined,
        afterAI: aiHandedOver(record),
      );
    }
    if (raw == 'waiting') {
      final ends = s['waitEndsAt'];
      final endsMs = ends is num ? ends.toDouble() : double.tryParse('${ends ?? ''}');
      final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
      int? remaining;
      if (endsMs != null && endsMs.isFinite && endsMs > 0) {
        final secs = ((endsMs - nowMs) / 1000).round();
        remaining = secs < 5 ? 5 : secs;
      }
      return RestoredLiveChat(status: 'waiting', remainingSeconds: remaining);
    }
    if (raw == 'ended') return const RestoredLiveChat(status: 'ended', settle: HandoverOutcome.ended);
    if (raw == 'fallback') return const RestoredLiveChat(status: 'fallback', settle: HandoverOutcome.unavailable);
    // Live with nobody in it (every agent left), or no handover at all.
    return RestoredLiveChat(status: 'none', settle: hasPendingLine(record) ? HandoverOutcome.unavailable : null);
  }

  /// What a restored chat does next, from the server's answer:
  ///   live      a person (or, still waiting after an AI escalation, the AI)
  ///             has the chat: live mode, the flow is not run again;
  ///   wait      still in the queue at the flow's handover step: back on that
  ///             step's wait, without asking for a person a second time;
  ///   continueFlow  the wait or the live chat is over: the flow carries on
  ///             from its handover step;
  ///   ask       the flow was at its handover step but the request never went
  ///             out: run the step again;
  ///   start     nothing live to rejoin: as for any restored chat.
  static RestoreStep restoreStep(RestoredLiveChat r, bool atHandover, [List<dynamic>? record]) {
    if (r.status == 'live') return RestoreStep.live;
    if (r.status == 'waiting') return atHandover ? RestoreStep.wait : RestoreStep.live;
    if (!atHandover) return RestoreStep.start;
    final list = record ?? const [];
    final asked = list.any(_liveEntry);
    return r.status == 'none' && !asked && !hasPendingLine(list) ? RestoreStep.ask : RestoreStep.continueFlow;
  }
}
