/// Live chat beyond the messages, as the web widget has it: the visitor's
/// place in the queue, what happens when nobody can join (an email for the
/// reply, leave a message), read receipts both ways, a conversation locked
/// or its composer turned off by the agent, an agent's dropped connection,
/// an agent asking for a file, the AI's follow-up email card, and the
/// post-chat rating. Owned by ConferBotProvider (`provider.liveChat`); the
/// shapes are in live_chat.dart.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/message.dart';
import '../../services/socket_client.dart';
import '../state/chat_state.dart';
import 'live_chat.dart';

class LiveChatExtras extends ChangeNotifier {
  LiveChatExtras({
    required SocketClient? Function() socket,
    required String? Function() sessionId,
    required void Function(RecordItem item) addMessage,
    required void Function() sendRecord,
    void Function()? continueFlow,
  })  : _socket = socket,
        _sessionId = sessionId,
        _addMessage = addMessage,
        _sendRecord = sendRecord,
        _continueFlow = continueFlow ?? (() {});

  final SocketClient? Function() _socket;
  final String? Function() _sessionId;
  final void Function(RecordItem item) _addMessage;
  final void Function() _sendRecord;
  final void Function() _continueFlow;

  QueueStatus? queue;
  HandoverWaiting? handoverWaiting;
  bool noAgentsAvailable = false;
  String? lockedBy;
  bool visitorInputEnabled = true;
  String? agentConnectionLost;
  String? fileRequestedBy;
  ReceiptMarks receiptMarks = const ReceiptMarks();
  bool leadCardOpen = false;
  CsatConfig? csatConfig;
  bool csatOpen = false;
  // What the visitor already sent from a card (kept here, not in the card,
  // so a rebuild does not bring the form back).
  String? leftMessageTo;
  String? leadEmail;
  bool csatSent = false;

  Timer? _queueTimer;
  Timer? _waitTimer;
  String _reportedDelivered = '';
  String _reportedSeen = '';

  bool _own(dynamic data) {
    final id = data is Map ? data['chatSessionId']?.toString() ?? '' : '';
    final mine = _sessionId();
    return id.isEmpty || mine == null || id == mine;
  }

  /// fetched-chatbot-data: the bot's post-chat rating settings.
  void setChatbotData(Map<String, dynamic> chatbotData) {
    csatConfig = LiveChat.csatConfigOf(chatbotData['csatConfig']);
    notifyListeners();
  }

  void setupListeners() {
    final s = _socket();
    if (s == null) return;
    void on(String event, void Function(dynamic) fn) => s.on(event, fn);

    on('queue-status', (d) {
      if (!_own(d)) return;
      queue = LiveChat.queueStatusOf(d);
      notifyListeners();
    });
    on('handover-waiting', (d) {
      if (!_own(d)) return;
      queue = null;
      handoverWaiting = LiveChat.handoverWaitingOf(d);
      notifyListeners();
    });
    on('no-agents-available', (_) {
      queue = null;
      stopQueuePoll();
      noAgentsAvailable = true;
      notifyListeners();
    });
    on('agent-accepted', (d) {
      // A person (or the AI taking it back) answered: the wait is over.
      final details = d is Map ? d['agentDetails'] : null;
      queue = null;
      stopQueuePoll();
      noAgentsAvailable = false;
      if (details is Map && details['isAIAgent'] != true) handoverWaiting = null;
      notifyListeners();
    });
    on('conversation-locked', (d) {
      if (!_own(d)) return;
      final who = d is Map ? d['lockedByName']?.toString() ?? '' : '';
      lockedBy = who.isEmpty ? 'the team' : who;
      notifyListeners();
    });
    on('conversation-unlocked', (d) {
      if (!_own(d)) return;
      lockedBy = null;
      notifyListeners();
    });
    on('visitor-input-toggled', (d) {
      if (!_own(d)) return;
      visitorInputEnabled = !(d is Map && d['isInputEnabled'] == false);
      notifyListeners();
    });
    on('agent-connection-lost', (d) {
      if (!_own(d)) return;
      final who = d is Map ? d['agentName']?.toString() ?? '' : '';
      agentConnectionLost = who.isEmpty ? 'The agent' : who;
      notifyListeners();
    });
    on('agent-connection-restored', (d) {
      if (!_own(d)) return;
      agentConnectionLost = null;
      notifyListeners();
    });
    on('file-upload-requested', (d) {
      if (!_own(d)) return;
      final raw = d is Map ? d['agentName']?.toString().trim() ?? '' : '';
      final who = raw.isEmpty ? 'The team' : raw;
      fileRequestedBy = who;
      ChatState.instance.pushToRecord(RecordEntry(
        id: 'file-request-${DateTime.now().millisecondsSinceEpoch}',
        shape: 'agent-file-request',
        type: 'agent-file-request',
        data: {'agentName': who},
      ));
      notifyListeners();
    });
    on('agent-read-status', (d) {
      if (!_own(d)) return;
      receiptMarks = LiveChat.receiptMarksOf(d);
      notifyListeners();
    });
    on('chat-ended', (_) {
      queue = null;
      stopQueuePoll();
      lockedBy = null;
      fileRequestedBy = null;
      csatOpen = true;
      notifyListeners();
    });
    on('agent-message', (d) {
      // Buying intent and no email yet: the one-field follow-up card.
      if (d is! Map) return;
      final details = d['agentDetails'];
      if (details is Map && details['isAIAgent'] == true && d['leadCard'] == true) {
        leadCardOpen = true;
        notifyListeners();
      }
    });
  }

  /// Where the visitor stands: asked every 20s while a handover waits for a person.
  void startQueuePoll() {
    if (_queueTimer != null) return;
    _askQueue();
    _queueTimer = Timer.periodic(LiveChat.queuePoll, (_) => _askQueue());
  }

  void stopQueuePoll() {
    _queueTimer?.cancel();
    _queueTimer = null;
  }

  /// The handover step's max wait: once it passes with nobody joined, the
  /// server is asked to decide (handover-timeout) and answers with
  /// no-agents-available. Once per wait.
  void startWaitTimer(Map<String, dynamic>? nodeData, String? workspaceId) {
    if (_waitTimer != null) return;
    final minutes = LiveChat.waitMinutes(nodeData?['maxWaitTime']);
    _waitTimer = Timer(Duration(milliseconds: (minutes * 60000).round()), () {
      final id = _sessionId();
      if (id == null) return;
      _socket()?.emit('handover-timeout', LiveChat.handoverTimeoutPayload(id, nodeData, workspaceId));
    });
  }

  void stopWaitTimer() {
    _waitTimer?.cancel();
    _waitTimer = null;
  }

  Future<void> _askQueue() async {
    final id = _sessionId();
    final s = _socket();
    if (id == null || s == null) return;
    try {
      final res = await s.emitWithAck('queue-status', {'chatSessionId': id});
      final q = LiveChat.queueStatusOf(res);
      if (q != null) {
        queue = q;
        notifyListeners();
      }
    } catch (_) {
      // Offline or no answer: the next ask.
    }
  }

  /// The conversation as the receipt logic sees it: the server record, where
  /// a visitor's live message has its own shape and the same id as its bubble.
  static List<LiveEntry> entriesOf(List<Map<String, dynamic>> serverRecord) => serverRecord
      .map((e) => LiveEntry((e['id'] ?? e['_id'])?.toString() ?? '', (e['shape'] ?? e['type'])?.toString() ?? ''))
      .toList();

  /// The "Sent / Delivered / Seen" line, while a person is on the other end.
  VisitorReceipt? visitorReceipt({required bool personHere}) {
    if (!personHere) return null;
    return LiveChat.visitorReceiptOf(entriesOf(ChatState.instance.getRecordForServer()), receiptMarks);
  }

  /// The visitor's receipts for the agent's newest message: delivered when it
  /// arrives, seen while the chat is on screen.
  void reportReceipts({required bool chatVisible}) {
    final latest = LiveChat.latestAgentMessageId(entriesOf(ChatState.instance.getRecordForServer()));
    final id = _sessionId();
    final s = _socket();
    if (latest.isEmpty || id == null || s == null) return;
    if (_reportedDelivered != latest) {
      _reportedDelivered = latest;
      s.emit('visitor-read-receipt', {'chatSessionId': id, 'messageId': latest, 'state': 'delivered'});
    }
    if (chatVisible && _reportedSeen != latest) {
      _reportedSeen = latest;
      s.emit('visitor-read-receipt', {'chatSessionId': id, 'messageId': latest, 'state': 'seen'});
    }
  }

  static String _entryId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32).toRadixString(36)}';

  /// "Leave a message" when nobody is available: by email.
  Future<bool> leaveMessage(String email, String message) async {
    final id = _sessionId();
    final s = _socket();
    if (id == null || s == null) return false;
    final entryId = _entryId('leave-message');
    bool ok = false;
    try {
      final res = await s.emitWithAck(
        'leave-message',
        {'chatSessionId': id, 'email': email, 'message': message, 'entryId': entryId, 'visitorId': ChatState.instance.visitorId ?? id},
        timeout: const Duration(seconds: 15),
      );
      ok = res is Map && res['ok'] == true;
    } catch (_) {
      ok = false;
    }
    if (!ok) return false;
    ChatState.instance.pushToRecord(RecordEntry(
      id: entryId,
      shape: 'user-message',
      type: 'user-message',
      text: message,
      data: {'via': 'email', 'data': {'leftMessage': true, 'email': email}},
    ));
    ChatState.instance.setUserMetadata('email', email);
    _addMessage(UserMessageRecord(id: entryId, time: DateTime.now(), text: message));
    leftMessageTo = email;
    noAgentsAvailable = false;
    notifyListeners();
    _continueFlow();
    return true;
  }

  /// "Not now" on leave a message: the flow carries on.
  void skipLeaveMessage() {
    noAgentsAvailable = false;
    notifyListeners();
    _continueFlow();
  }

  /// Prefill for leave a message: their email if known, and what they last asked.
  ({String email, String message}) leaveMessagePrefill() {
    final state = ChatState.instance;
    return (
      email: LiveChat.knownEmail(state.userMetadata.email, state.answerVariables.map((v) => v.value).toList()),
      message: LiveChat.lastQuestion(state.getRecordForServer()),
    );
  }

  /// The email the team replies to when nobody could join (handover-waiting).
  Future<bool> shareEmailForReply(String email) async {
    final id = _sessionId();
    final s = _socket();
    if (id == null || s == null) return false;
    final entryId = _entryId('handover-email');
    bool ok = false;
    try {
      final res = await s.emitWithAck(
        'handover-email',
        {'chatSessionId': id, 'email': email, 'entryId': entryId, 'visitorId': ChatState.instance.visitorId ?? id},
        timeout: const Duration(seconds: 15),
      );
      ok = res is Map && res['ok'] == true;
    } catch (_) {
      ok = false;
    }
    if (!ok) return false;
    ChatState.instance.pushToRecord(RecordEntry(
      id: entryId,
      shape: 'user-message',
      type: 'user-message',
      text: email,
      data: {'via': 'email', 'data': {'handoverEmail': true, 'email': email}},
    ));
    handoverWaiting = handoverWaiting?.copyWith(askEmail: false, email: email);
    notifyListeners();
    return true;
  }

  /// The AI's follow-up card: the email kept as the visitor's, the record sent.
  void captureLeadEmail(String email) {
    ChatState.instance.setUserMetadata('email', email);
    _sendRecord();
    leadEmail = email;
    leadCardOpen = false;
    notifyListeners();
  }

  /// The post-chat rating (value: int, or bool for thumbs).
  void submitRating(Object value, String? feedback) {
    final config = csatConfig;
    final id = _sessionId();
    if (config == null || id == null) return;
    _socket()?.emit('submit-chat-rating', LiveChat.ratingPayload(id, config.ratingType, value, feedback));
    csatSent = true;
    notifyListeners();
  }

  void dismissCsat() {
    csatOpen = false;
    notifyListeners();
  }

  /// The visitor's file in a live chat, uploaded already: recorded as the web widget does.
  void sendLiveFile(String url, {String? fileName, String? mimeType}) {
    final id = _entryId('user-file');
    ChatState.instance.pushToRecord(RecordEntry(id: id, shape: 'user-live-message-file', type: 'user-live-message-file', data: {'url': url}));
    _addMessage(UserLiveMessageFileRecord(id: id, time: DateTime.now(), url: url, fileName: fileName, mimeType: mimeType));
    _sendRecord();
    fileRequestedBy = null;
    notifyListeners();
  }

  void reset() {
    stopQueuePoll();
    stopWaitTimer();
    queue = null;
    handoverWaiting = null;
    noAgentsAvailable = false;
    lockedBy = null;
    visitorInputEnabled = true;
    agentConnectionLost = null;
    fileRequestedBy = null;
    receiptMarks = const ReceiptMarks();
    leadCardOpen = false;
    csatOpen = false;
    leftMessageTo = null;
    leadEmail = null;
    csatSent = false;
    _reportedDelivered = '';
    _reportedSeen = '';
    notifyListeners();
  }

  @override
  void dispose() {
    stopQueuePoll();
    stopWaitTimer();
    super.dispose();
  }
}
