/// The handover's lifecycle on screen: the "Connecting you with the team…"
/// line and how it settles, the 20s waiting signal, leaving the queue, and
/// picking a live chat back up after the app restarts. The logic is in
/// handover_state.dart and handover_waiting.dart (ported from the React
/// Native SDK, itself from the web widget's handoverState.ts,
/// handoverWaiting.ts, special.ts and index.ts); this class applies it to
/// the record and the socket, as RN's useHandoverLifecycle does. Owned by
/// ConferBotProvider.
///
/// Every line is written twice with the same id: into ChatState's record
/// (what the server and a restart read) and onto the screen
/// ([SystemMessageRecord] with its kind, handover and settled marks).
library;

import 'dart:math';

import '../../models/message.dart';
import '../../services/socket_client.dart';
import '../state/chat_state.dart';
import '../waiting/wait_articles.dart' show WaitText;
import 'handover_state.dart';
import 'handover_waiting.dart';
import 'live_chat.dart';
import 'live_events.dart';

/// The flow, as the lifecycle needs it (NodeFlowEngine in the provider).
abstract class HandoverFlow {
  /// Waiting on its handover step (for a person, or after nobody came).
  bool get atHandover;

  /// The handover step's data while the flow is on it.
  Map<String, dynamic>? get handoverNodeData;

  /// Back on the handover step without running it again: its wait card
  /// ([waiting]), or no card while a person has the chat.
  bool waitAt(String nodeId, {required bool waiting});

  /// The flow carries on from its handover step.
  void continueFlow();

  /// Run the step again (its request never went out).
  void resumeFrom(String nodeId);

  /// The flow is over for good (the visitor was blocked): no step, no card.
  void stop();
}

class HandoverLifecycle {
  HandoverLifecycle({
    required SocketClient? Function() socket,
    required String? Function() sessionId,
    required bool Function() isOpen,
    required void Function(RecordItem line) addLine,
    required void Function(RecordItem? Function(RecordItem m) change) updateLines,
    required HandoverFlow flow,
    void Function(bool live)? setLive,
    void Function(RestoredAgent agent)? setAgent,
    void Function()? clearAgent,
    ChatState? state,
    SetTimer? setTimer,
    ClearTimer? clearTimer,
    void Function()? waitStart,
    void Function()? waitEnd,
    bool Function()? isAgentBot,
    String? Function()? workspaceId,
    void Function(int? remainingSeconds)? onRestoredWait,
  })  : _socket = socket,
        _sessionId = sessionId,
        _isOpen = isOpen,
        _addLine = addLine,
        _updateLines = updateLines,
        _flow = flow,
        _setLive = setLive ?? ((_) {}),
        _setAgent = setAgent ?? ((_) {}),
        _clearAgent = clearAgent ?? (() {}),
        _waitStart = waitStart ?? (() {}),
        _waitEnd = waitEnd ?? (() {}),
        _isAgentBot = isAgentBot ?? (() => false),
        _workspaceId = workspaceId ?? (() => null),
        _onRestoredWait = onRestoredWait ?? ((_) {}),
        _state = state {
    connecting = ConnectingSignal(
      () => bus.emit(WidgetSignals.waitingForHuman, WidgetSignals.waitingDetail({'offline': false, 'reason': 'busy'})),
      canFire: () => _isOpen(),
      setTimer: setTimer,
      clearTimer: clearTimer,
    );
    // After an AI escalates: its step's max wait plus 30s, then the server is
    // nudged to decide (handover-timeout). Nothing is drawn (web special.ts
    // _handleAIEscalationWait, handoverWaiting.ts armAIEscalationNudge).
    nudge = EscalationNudge(
      () {
        final id = _sessionId();
        if (id == null || id.isEmpty) return;
        _socket()?.emit('handover-timeout', LiveChat.handoverTimeoutPayload(id, _escalationStep(), _workspaceId() ?? ''));
      },
      setTimer: setTimer,
      clearTimer: clearTimer,
    );
  }

  final SocketClient? Function() _socket;
  final String? Function() _sessionId;
  final bool Function() _isOpen;
  final void Function(RecordItem line) _addLine;
  final void Function(RecordItem? Function(RecordItem m) change) _updateLines;
  final HandoverFlow _flow;
  final void Function(bool live) _setLive;
  final void Function(RestoredAgent agent) _setAgent;
  final void Function() _clearAgent;

  /// Where a wait for a person begins and ends, for what may help meanwhile
  /// (core/waiting/waiting_extras.dart, RN useHandoverLifecycle waitHooks).
  final void Function() _waitStart;
  final void Function() _waitEnd;
  final ChatState? _state;

  /// The chat is an AI agent bot's (no flow): an inactivity close only pauses it.
  final bool Function() _isAgentBot;

  /// The bot's workspace, for the escalation's handover-timeout.
  final String? Function() _workspaceId;

  /// A restored wait for a person: the server's seconds left of its max
  /// wait (LiveChatExtras' countdown and max-wait timer).
  final void Function(int? remainingSeconds) _onRestoredWait;

  /// The AI escalation's max wait (core/live_chat/handover_waiting.dart).
  late final EscalationNudge nudge;

  // The handover step an AI escalation waits on: the flow's, else the agent
  // bot's silent one in the record.
  Map<String, dynamic>? _escalationStep() => escalationHandoverData(_flow.handoverNodeData, record);

  // Back in the queue: the step waits again, but that is not a new wait for
  // the help card (web waitForPerson.start() is not called on a requeue).
  bool _requeueing = false;

  // Left this wait already: the server answers queue-self-resolve and also
  // sends queue-left, so one leave can arrive twice. A new wait clears it.
  bool _left = false;

  final WidgetSignalBus bus = WidgetSignalBus();
  late final ConnectingSignal connecting;
  bool _waitingForPerson = false;

  ChatState get state => _state ?? ChatState.instance;

  /// The conversation's record as the server and a restart read it.
  List<Map<String, dynamic>> get record => state.getRecordForServer();

  /// Nobody is coming or here: "Talk to a person" may be offered.
  bool get talkToPersonAllowed => HandoverRecord.talkToPersonAllowed(record);

  /// A person (not the AI) is in the chat.
  bool get personInChat => HandoverRecord.phase(record) == HandoverPhase.joined;

  bool _own(dynamic data) {
    final id = data is Map ? data['chatSessionId']?.toString() ?? '' : '';
    final mine = _sessionId();
    return id.isEmpty || mine == null || mine.isEmpty || id == mine;
  }

  // Its own id per entry: two lines in the same millisecond must not merge.
  static final _random = Random();
  static String _entryId(String kind) =>
      '$kind-${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(1 << 32).toRadixString(36)}';

  void _add(SystemMessageRecord line, RecordEntry entry) {
    state.pushToRecord(entry);
    _addLine(line);
  }

  /// The Connecting line has its answer: settled on screen and in the record.
  void settle(HandoverOutcome outcome) {
    for (final e in state.record) {
      if (HandoverRecord.isHandoverLeft(e.toJson()) && HandoverRecord.outcomeOf(e.data['settled']) == null) {
        state.pushToRecord(e.copyWith(data: {...e.data, 'settled': outcome.name}));
      }
    }
    _updateLines((m) => m is SystemMessageRecord && m.handoverPending
        ? m.copyWith(settled: outcome.name, text: HandoverRecord.lineText(outcome))
        : null);
  }

  /// The wait ended without a person: no waiting signal, and cb:wait-over.
  void _waitOver(String reason) {
    connecting.end();
    nudge.clear();
    _waitEnd();
    bus.emit(WidgetSignals.waitOver, {'reason': reason});
  }

  bool _inWait() => _waitingForPerson || connecting.pending || HandoverRecord.hasPendingLine(record);

  /// A flow's handover step is (or is no longer) waiting for a person: the
  /// 20s signal starts, unless an AI agent takes the chat first (web
  /// special.ts startHandover).
  void setWaitingForPerson(bool waiting, [Map<String, dynamic>? nodeData]) {
    if (waiting && !_waitingForPerson) {
      final ai = nodeData?['assignedAIAgents'];
      if (!(ai is List && ai.isNotEmpty)) {
        connecting.start();
        if (!_requeueing) {
          _left = false;
          _waitStart();
        }
      }
    }
    _waitingForPerson = waiting;
  }

  /// agent-left (web agentListeners.ts): an AI escalating draws one
  /// Connecting line and starts the wait; an idle pause draws nothing; a
  /// person leaving says so.
  AgentLeftKind onAgentLeft(dynamic data, {String? fallbackName}) {
    final kind = HandoverRecord.agentLeftKind(data);
    if (kind == AgentLeftKind.ignore) return kind;
    final details = data is Map && data['agentDetails'] is Map ? data['agentDetails'] as Map : const {};
    final name = (details['name']?.toString() ?? '').isNotEmpty ? details['name'].toString() : (fallbackName ?? '');
    final handover = kind == AgentLeftKind.handover;
    if (handover) {
      // The AI passed the visitor on: the wait for a person starts again.
      if (startsEscalationWait(data)) nudge.arm(_escalationStep()?['maxWaitTime']);
      connecting.start();
      // Passed on to a person: what may help while they wait (web special.ts agent-left).
      _waitStart();
      // A new wait: it can be left again.
      _left = false;
      // The same escalation again: one line is enough.
      if (HandoverRecord.hasPendingLine(record)) return kind;
    }
    final id = _entryId('agent-left');
    final text = HandoverRecord.agentLeftText(name, handover);
    final agentId = details['_id']?.toString();
    _add(
      SystemMessageRecord(id: id, time: DateTime.now(), text: text, kind: 'agent-left-chat', handover: handover, agentId: agentId),
      RecordEntry(id: id, shape: 'agent-left-chat', type: 'agent-left-chat', text: text, data: {
        'name': name,
        if (agentId != null) 'agentId': agentId,
        if (handover) 'handover': true,
      }),
    );
    if (!handover) state.addToTranscript('bot', text);
    return kind;
  }

  /// agent-accepted (web special.ts _handleHandoverAccepted): the wait is
  /// over - a person joined, or the AI took the chat back. Settles the line,
  /// ends the waiting signal, says cb:human-joined for a person.
  AcceptedPlan onAccepted(dynamic data) {
    final plan = HandoverRecord.acceptedPlan(record, data);
    connecting.end();
    nudge.clear();
    _waitEnd();
    settle(plan.outcome);
    if (plan.humanJoined) {
      final details = data is Map && data['agentDetails'] is Map ? data['agentDetails'] as Map : const {};
      bus.emit(WidgetSignals.humanJoined, {'name': details['name']?.toString()});
    }
    return plan;
  }

  /// The join line: "<name> joined the chat", with its note after an AI handover.
  void addJoin(Map details, AcceptedPlan plan) => _join(details, ai: plan.ai, afterAI: plan.afterAI);

  void _join(Map details, {required bool ai, required bool afterAI}) {
    final raw = details['name']?.toString() ?? '';
    final name = raw.isEmpty ? 'Agent' : raw;
    final id = _entryId('agent-joined');
    final text = HandoverRecord.joinedText(name);
    final agentId = details['_id']?.toString();
    _add(
      SystemMessageRecord(
        id: id,
        time: DateTime.now(),
        text: text,
        kind: 'agent-joined-message',
        agentId: agentId,
        note: afterAI ? HandoverRecord.handedOverNote : null,
      ),
      RecordEntry(id: id, shape: 'agent-joined-message', type: 'agent-joined-message', data: {
        'name': name,
        'agentDetails': Map<String, dynamic>.from(details),
        if (agentId != null) 'agentId': agentId,
        if (ai) 'ai': true,
        if (afterAI) 'afterAI': true,
      }),
    );
    state.addToTranscript('bot', text);
  }

  /// Out of the queue: the line, the record, the signal, the flow moves on
  /// (once per wait). [helped]: a help article solved it ("That solved it",
  /// web special.ts _wireQueue leave()): "You left the queue. Glad that
  /// helped.", recorded as "Resolved while waiting".
  void _leftQueue({bool helped = false}) {
    if (_left) return;
    _left = true;
    _waitOver('cancelled');
    settle(HandoverOutcome.cancelled);
    _waitingForPerson = false;
    final id = _entryId('queue-self-resolved');
    final text = helped ? WaitText.leftHelped : HandoverRecord.lineText(HandoverOutcome.cancelled);
    _add(
      SystemMessageRecord(id: id, time: DateTime.now(), text: text, kind: 'queue-self-resolved'),
      RecordEntry(
        id: id,
        shape: 'queue-self-resolved',
        type: 'queue-self-resolved',
        text: helped ? WaitText.recordText : text,
      ),
    );
    state.addToTranscript('bot', '{The visitor left the queue}');
    if (_flow.atHandover) _flow.continueFlow();
  }

  Future<dynamic> _ask(String event, Map<String, dynamic> payload, Duration timeout) async {
    final s = _socket();
    if (s == null) return null;
    try {
      final res = await s.emitWithAck(event, payload, timeout: timeout);
      return res is List && res.isNotEmpty ? res.first : res;
    } catch (_) {
      return null;
    }
  }

  /// The visitor leaves the queue (the wait card's Leave queue):
  /// queue-self-resolve, as the web widget does, so the team stops seeing
  /// them waiting. False when a person already picked the chat up (they stay).
  Future<bool> leaveQueue() async {
    final sid = _sessionId() ?? '';
    final res = await _ask('queue-self-resolve', HandoverRecord.queueSelfResolvePayload(sid), const Duration(seconds: 8));
    // not_waiting: no queued ticket - or a person just took it (in progress).
    final live = HandoverRecord.queueLeaveNeedsState(res)
        ? await _ask('live-chat-state', {'chatSessionId': sid}, const Duration(seconds: 8))
        : null;
    if (HandoverRecord.queueLeaveStays(res, live)) return false;
    _leftQueue();
    return true;
  }

  /// The server let them go because an article helped (queue-self-resolve
  /// with the article answered ok).
  void leftQueueHelped() => _leftQueue(helped: true);

  void setupListeners() {
    final s = _socket();
    if (s == null) return;
    // The server's own word on the wait (an AI escalation found nobody):
    // its cb:waiting-for-human, never ours as well.
    s.on('handover-waiting', (data) {
      if (!_own(data)) return;
      connecting.end();
      nudge.clear();
      _waitEnd();
      settle(HandoverOutcome.unavailable);
      bus.emit(WidgetSignals.waitingForHuman, WidgetSignals.waitingDetail(data));
    });
    s.on('no-agents-available', (_) {
      settle(HandoverOutcome.unavailable);
      _waitOver('unavailable');
    });
    void ended(dynamic data) {
      if (!_own(data)) return;
      nudge.clear();
      _waitEnd();
      final waiting = _inWait();
      settle(HandoverOutcome.ended);
      if (waiting) _waitOver('ended');
    }

    s.on('chat-ended', ended);
    // The AI let an idle visitor go (web agentListeners.ts, server
    // aiInactivityHandler.js): "Chat paused" (a message picks it back up)
    // or, for continue_flow on a flow bot, "Chat ended" and the flow carries
    // on from its handover step (core/live_chat/live_events.dart
    // inactiveClosePlan).
    s.on('ai-agent-inactive-close', (data) {
      if (!_own(data)) return;
      ended(data);
      onInactiveClose(data);
    });
    // The agent left and nobody else owns the chat: back in the queue (web
    // liveTakeover.ts). "Connecting you to another agent..." (or the team it
    // went to), and a flow at its handover step waits again.
    s.on(LiveEventNames.requeued, (data) {
      if (!_own(data)) return;
      onRequeued(data);
    });
    // A transfer the server wrote into the record: kept in this copy too, so
    // the next write keeps it. Not drawn (as on the web): the requeued line or
    // the next agent's join tells the visitor.
    s.on(LiveEventNames.transferred, (data) {
      if (!_own(data)) return;
      final entry = LiveEvents.transferEntry(data);
      if (entry != null) state.addRecord(entry);
    });
    // Blocked by the workspace (web closedState.ts): a Connecting line stops
    // its dots, the wait and the flow are over.
    s.on(LiveEventNames.blocked, (data) {
      if (!_own(data)) return;
      onBlocked();
    });
    // Left the queue from another device of this chat.
    s.on('queue-left', (data) {
      if (!_own(data) || data is! Map || data['reason'] != 'self_service') return;
      if (_flow.atHandover && _waitingForPerson) _leftQueue();
    });
  }

  /// live-chat-requeued: the line (in the record and on screen), nobody in
  /// the chat any more, and a flow on its handover step waits again.
  void onRequeued(dynamic data) {
    final entry = LiveEvents.requeuedEntry(data);
    final id = entry['id'] as String;
    final text = entry['text'] as String;
    state.addRecord(entry);
    _addLine(SystemMessageRecord(id: id, time: DateTime.now(), text: text, kind: 'live-chat-requeued'));
    state.addToTranscript('bot', text);
    _clearAgent();
    final nodeId = state.currentNodeId;
    if (_flow.atHandover && nodeId != null) {
      _setLive(false);
      _requeueing = true;
      try {
        if (_flow.waitAt(nodeId, waiting: true)) _waitingForPerson = true;
      } finally {
        _requeueing = false;
      }
    }
    connecting.start();
  }

  /// ai-agent-inactive-close: the paused or ended line (on screen and in
  /// the record, once), and for continue_flow nobody in the chat any more,
  /// live mode off and the flow on from its handover step (the step's next
  /// edge, no post-chat survey). A pause leaves live mode on: the visitor's
  /// next message goes the live way and the server answers ai-agent-resumed.
  void onInactiveClose(dynamic data) {
    final agentBot = _isAgentBot();
    final entry = LiveEvents.inactiveCloseEntry(data, agentBot);
    final line = LiveEvents.inactiveCloseLine(entry);
    final id = entry['id'] as String;
    state.addRecord({
      for (final e in entry.entries)
        if (e.key != '_id' && e.key != 'shape') e.key: e.value,
    });
    _addLine(SystemMessageRecord(id: id, time: DateTime.now(), text: line.text, kind: 'ai-agent-inactive-close', note: line.note));
    if (!LiveEvents.inactiveClosePlan(data, agentBot).continueFlow) return;
    _clearAgent();
    _setLive(false);
    if (_flow.atHandover) _flow.continueFlow();
  }

  /// visitor-blocked: the wait and the flow are over, nobody is coming.
  void onBlocked() {
    connecting.end();
    nudge.clear();
    _waitEnd();
    settle(HandoverOutcome.ended);
    _waitingForPerson = false;
    _flow.stop();
    _setLive(false);
  }

  /// Before a restored record is drawn: lines whose outcome the record knows
  /// settle, and a person's join after an AI handover gets its note.
  void _annotateRestored() {
    final entries = state.record;
    final a = HandoverRecord.annotateRestored(record);
    if (a.changed == 0) return;
    final byId = <String, Map>{};
    for (var i = 0; i < entries.length && i < a.record.length; i++) {
      final out = a.record[i] as Map;
      final d = out['data'] is Map ? out['data'] as Map : const {};
      final e = entries[i];
      final settled = d['settled'];
      final afterAI = d['afterAI'] == true;
      if (settled != e.data['settled'] || afterAI != (e.data['afterAI'] == true)) {
        state.pushToRecord(e.copyWith(data: {
          ...e.data,
          if (settled != null) 'settled': settled,
          if (afterAI) 'afterAI': true,
        }));
        byId[e.id] = d;
      }
    }
    _updateLines((m) {
      if (m is! SystemMessageRecord) return null;
      final d = byId[m.id];
      if (d == null) return null;
      final o = HandoverRecord.outcomeOf(d['settled']);
      if (m.handover && o != null && m.settled == null) return m.copyWith(settled: o.name, text: HandoverRecord.lineText(o));
      if (d['afterAI'] == true && m.note == null) return m.copyWith(note: HandoverRecord.handedOverNote);
      return null;
    });
  }

  static String? _typeOf(Map step) => (step['type'] ?? (step['data'] is Map ? (step['data'] as Map)['type'] : null))?.toString();

  /// A chat restored from the device: ask the server where its live chat
  /// stands (live-chat-state) and pick it back up - the person and the join
  /// line it missed, still in the queue, or over - instead of running the
  /// flow again. Returns what was done; [RestoreStep.start] leaves the chat
  /// to start as any restored chat. The flow must be loaded already.
  Future<RestoreStep> resumeRestored({required List<Map<String, dynamic>> steps, required bool agentBot}) async {
    final sid = _sessionId();
    final s = _socket();
    if (sid == null || s == null) return RestoreStep.start;
    _annotateRestored();

    final nodeId = state.currentNodeId;
    Map<String, dynamic>? handoverNode;
    if (!agentBot && nodeId != null) {
      for (final step in steps) {
        if (step['id'] == nodeId && _typeOf(step) == 'human-handover-node') handoverNode = step;
      }
    }
    final atHandover = handoverNode != null;
    if (!HandoverRecord.restoreNeedsLiveChatState(record, atHandover: atHandover)) return RestoreStep.start;

    // Back in the room first: the server answers only its own session.
    s.joinChatRoomVisitor(sid);
    final res = await _ask('live-chat-state', {'chatSessionId': sid}, const Duration(seconds: 10));
    final r = HandoverRecord.restoredLiveChat(res ?? const {'status': 'none'}, record);
    if (r.settle != null) settle(r.settle!);
    final step = HandoverRecord.restoreStep(r, atHandover, record);
    final id = handoverNode?['id']?.toString();

    switch (step) {
      case RestoreStep.live:
        _setLive(true);
        final agent = r.agent;
        if (agent != null) {
          _setAgent(agent);
          if (r.drawJoin) _join({'_id': agent.id, 'name': agent.name}, ai: false, afterAI: r.afterAI);
        }
        // Still in the queue after an AI escalation: the AI has it meanwhile.
        if (r.status == 'waiting') connecting.start();
        // On the handover step with no card: the chat ending moves the flow on.
        if (id != null) _flow.waitAt(id, waiting: false);
      case RestoreStep.wait:
        // The countdown and the max wait go on from where the server is.
        _onRestoredWait(r.remainingSeconds);
        final before = _waitingForPerson;
        if (id != null && _flow.waitAt(id, waiting: true)) {
          // Still in the queue: what may help meanwhile, unless an AI agent
          // takes the step (the engine's own change may have started it).
          final ai = handoverNode?['data'] is Map ? (handoverNode!['data'] as Map)['assignedAIAgents'] : null;
          if (!before && !_waitingForPerson && !(ai is List && ai.isNotEmpty)) {
            _left = false;
            _waitStart();
          }
          _waitingForPerson = true;
          connecting.start();
        }
      case RestoreStep.continueFlow:
        // Ended while the app was closed: say so, as the live event would.
        if (r.status == 'ended') {
          final lineId = _entryId('chat-ended');
          _add(
            SystemMessageRecord(id: lineId, time: DateTime.now(), text: 'Chat has ended', kind: 'agent-chat-ended'),
            RecordEntry(id: lineId, shape: 'agent-chat-ended', type: 'agent-chat-ended', text: 'Chat has ended'),
          );
        }
        _setLive(false);
        if (id != null && _flow.waitAt(id, waiting: false)) _flow.continueFlow();
      case RestoreStep.ask:
        if (id != null) _flow.resumeFrom(id);
      case RestoreStep.start:
        break;
    }
    return step;
  }

  /// Listen to a widget signal (cb:waiting-for-human, cb:human-joined,
  /// cb:wait-over); call the returned function to stop.
  void Function() onSignal(String name, void Function(Map<String, dynamic> detail) fn) => bus.on(name, fn);

  void reset() {
    connecting.end();
    nudge.clear();
    _waitingForPerson = false;
    _left = false;
  }

  void dispose() {
    connecting.end();
    nudge.clear();
  }
}
