/// The human-handover step (web ts/chat/handlers/special.ts; React Native
/// IntegrationNodeHandlers.ts HumanHandoverHandler):
///
/// - Pre-chat questions (enablePreChatQuestions) are asked one by one in the
///   composer, 2000 ms of typing each, checked like the web (email, phone)
///   and saved by the question's id.
/// - Then the handover message (1000 ms of typing; the wait card shows it),
///   the record, and `initiate-handover` with the step's settings
///   (core/agent/agent_handover.dart).
/// - Nobody free (`no-agents-available`): the owner's fallback as the bot's
///   message after 1000 ms of typing; with "leave a message" off
///   (chatLeaveMessage false) the flow carries on along the first edge.
/// - A person joins, the chat ends (a post-chat survey, else the flow
///   carries on), or the visitor leaves the queue: the provider tells the
///   engine, which tells this handler.
library;

import '../../agent/agent_handover.dart';
import '../../flow/inputs.dart';
import '../../flow/js.dart' show jsIsoString;
import '../../flow/text.dart';
import '../../live_chat/handover_state.dart' show HandoverRecord;
import '../../state/chat_state.dart';
import '../node_handler.dart';
import '../node_types.dart';
import '../node_ui_state.dart';

/// The handover step: pre-chat questions, the wait for a person, the
/// fallback when nobody is free and the post-chat survey.
class HumanHandoverNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.humanHandover;

  /// Where each step stands (wait, a person on it, the survey).
  final Map<String, HandoverState> _handoverState = {};

  /// The post-chat survey question each step is on.
  final Map<String, int> _postChatIndices = {};

  String _plain(ChatState state, dynamic html) =>
      bubbleText(state.resolveVariables(html == null ? '' : html.toString(), mode: 'html'));

  List<Map<String, dynamic>> _preChatQuestions(Map<String, dynamic> data) {
    if (data['enablePreChatQuestions'] != true) return const [];
    final list = data['preChatQuestions'];
    return list is List ? list.whereType<Map>().map((q) => Map<String, dynamic>.from(q)).toList() : const [];
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final data = node.data;
    final nodeId = node.id;
    final ctx = node.ctx;

    // The builder's pre-chat questions: asked before the handover.
    final preChat = _preChatQuestions(data);
    final preKey = '_preChat_$nodeId';
    if (preChat.isNotEmpty && state.getVariable(preKey) == null) {
      for (final q in preChat) {
        final key = q['answerVariable']?.toString() ?? '';
        if (key.isNotEmpty) state.registerAnswerVariable((q['id'] ?? '').toString(), key);
      }
      return _askPreChat(node, state, 0);
    }

    // The handover message, after a beat of typing (web: 1000 ms); the wait
    // card shows it. A message cleared in the builder shows nothing.
    final raw = getString(data, 'handoverMessage', getString(data, 'waitMessage', 'Please wait while we connect you with an agent...'));
    final message = _plain(state, raw);
    if (message.isNotEmpty) {
      await ctx.typing(1000);
      state.addToTranscript('bot', message);
    }

    // In the chat room, the record on the server, then the handover - in
    // that order on one socket, so the ticket finds the conversation.
    final sessionId = state.chatSessionId;
    if (sessionId != null) {
      ctx.emit('join-chat-room-visitor', {'chatSessionId': sessionId});
      ctx.emit('response-record', state.buildResponseData());
    }
    final payload = AgentHandover.payload(state, data);
    if (payload != null) ctx.emit('initiate-handover', payload);

    state.setVariable('_handoverInitiated', true);
    state.setVariable('_handoverStartTime', jsIsoString(ctx.now()));
    _handoverState[nodeId] = HandoverState.waitingForAgent;

    // Nobody free: the owner's fallback as the bot's message after a beat
    // of typing; with "leave a message" off the flow carries on.
    late final void Function() off;
    off = ctx.on('no-agents-available', (_) async {
      off();
      _handoverState[nodeId] = HandoverState.noAgentsAvailable;
      final fallbackRaw = data['fallbackMessage'];
      final fallback = _plain(state, fallbackRaw ?? '');
      if (fallback.isNotEmpty) {
        await ctx.typing(1000);
        if (ctx.isStale()) return;
        state.addBotMessage(fallback, nodeId, nodeType);
        state.addRecord({
          '_id': fallbackRaw.toString(),
          'id': fallbackRaw.toString(),
          'type': 'agent-declined-message',
          'message': fallback,
          'renderedText': fallback,
          'time': jsIsoString(ctx.now()),
        });
      }
      if (ctx.customizations['chatLeaveMessage'] == false) ctx.respond(const {'action': 'continue'});
    });

    return NodeResult.displayUI(HumanHandoverUIState(
      state: HandoverState.waitingForAgent,
      handoverMessage: message,
      maxWaitTime: getInt(data, 'maxWaitTime', 5),
      nodeId: nodeId,
    ));
  }

  /// Pre-chat question `index`, after 2000 ms of typing.
  Future<NodeResult> _askPreChat(FlowNode node, ChatState state, int index) async {
    final questions = _preChatQuestions(node.data);
    final q = index < questions.length ? questions[index] : const <String, dynamic>{};
    await node.ctx.typing(2000);
    state.setVariable('_preChat_${node.id}', index);
    final question = _plain(state, q['questionText'] ?? '');
    if (question.isNotEmpty) state.addBotMessage(question, node.id, nodeType);
    return NodeResult.displayUI(_preChatUI(node, q, question), awaitInput: true);
  }

  TextInputUIState _preChatUI(FlowNode node, Map<String, dynamic> q, String question) {
    final variable = (q['answerVariable'] ?? '').toString().toLowerCase();
    return TextInputUIState(
      questionText: question,
      inputType: variable == 'email'
          ? TextInputType.email
          : (variable == 'phone' || variable == 'mobile')
              ? TextInputType.phone
              : TextInputType.text,
      answerKey: q['answerVariable']?.toString(),
      nodeId: node.id,
    );
  }

  /// An answer to a pre-chat question: checked, saved, then the next one or the handover.
  Future<NodeResult> _answerPreChat(dynamic response, FlowNode node, ChatState state, int index) async {
    final questions = _preChatQuestions(node.data);
    final q = index < questions.length ? questions[index] : const <String, dynamic>{};
    final value = response is String
        ? response.trim()
        : (response is Map ? (response['value'] ?? response['text'] ?? '').toString().trim() : '');
    final ui = _preChatUI(node, q, _plain(state, q['questionText'] ?? ''));
    if (value.isEmpty) return NodeResult.displayUI(ui, awaitInput: true);
    final key = q['answerVariable'];
    if (key == 'email' && !isValidEmail(value)) {
      return NodeResult.invalid(ownerTextOr(q['incorrectEmailResponse'], en.emailInvalid, const ['Please enter a valid email']), uiState: ui);
    }
    if ((key == 'mobile' || key == 'phone') && !isValidPhone(value)) {
      return NodeResult.invalid(ownerTextOr(q['incorrectPhoneNumberResponse'], en.phoneInvalid), uiState: ui);
    }
    if (key == 'name') state.setUserName(value);
    if (key == 'email') state.setUserEmail(value);
    if (key == 'mobile' || key == 'phone') state.setUserPhone(normalizePhone(value));
    final entryId = 'pre-chat-answer-${node.id}-$index';
    state.addRecord({
      '_id': entryId,
      'id': entryId,
      'questionId': q['id'],
      'shape': 'pre-chat-question-response',
      'type': 'pre-chat-question-response',
      'text': value,
      'time': jsIsoString(node.ctx.now()),
    });
    state.addUserMessage(value, node.id);
    state.setAnswerVariable((q['id'] ?? '').toString(), value);
    if (index + 1 < questions.length) return _askPreChat(node, state, index + 1);
    state.setVariable('_preChat_${node.id}', 'done');
    return handle(node, state);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final nodeId = node.id;
    final preIndex = state.getVariable('_preChat_$nodeId');
    final isAction = response is Map && (response['action'] != null || response['status'] != null);
    if (preIndex is int && !isAction) return _answerPreChat(response, node, state, preIndex);

    if (response is Map) {
      switch (response['action']) {
        // The handover is over (nobody came and the visitor left a message
        // or skipped it): the flow carries on, as the web widget does.
        case 'continue':
          _cleanup(nodeId);
          return NodeResult.next({'handoverOver': true});
        case 'cancel':
          state.setVariable('_handoverCancelled', true);
          // Out of the queue (web special.ts, queue-self-resolve). The
          // provider sends it itself and waits for the answer (queueLeft).
          final sid = state.chatSessionId;
          if (response['queueLeft'] != true && sid != null) {
            node.ctx.emit('queue-self-resolve', HandoverRecord.queueSelfResolvePayload(sid));
          }
          _cleanup(nodeId);
          return NodeResult.next({'handoverCancelled': true});
      }
    }

    switch (_handoverState[nodeId]) {
      case HandoverState.postChatSurvey:
        return _handlePostChatResponse(response, node, state);
      case HandoverState.agentConnected:
        final message = response is String ? response.trim() : '';
        if (message.isNotEmpty) state.addToTranscript('user', message);
        return NodeResult.displayUI(_waitUI(node, state, HandoverState.agentConnected), awaitInput: true);
      default:
        return NodeResult.displayUI(_waitUI(node, state, _handoverState[nodeId] ?? HandoverState.waitingForAgent), awaitInput: true);
    }
  }

  HumanHandoverUIState _waitUI(FlowNode node, ChatState state, HandoverState stage) => HumanHandoverUIState(
        state: stage,
        handoverMessage: _plain(state, node.data['handoverMessage'] ?? ''),
        maxWaitTime: getInt(node.data, 'maxWaitTime', 5),
        nodeId: node.id,
      );

  List<PreChatQuestion> _surveyQuestions(List<dynamic> questions, String prefix) => [
        for (var i = 0; i < questions.length; i++)
          if (questions[i] is Map)
            PreChatQuestion(
              id: (questions[i] as Map)['id']?.toString() ?? 'q$i',
              questionText: (questions[i] as Map)['questionText']?.toString() ?? '',
              answerType: (questions[i] as Map)['answerVariable']?.toString() ?? 'text',
              answerKey: (questions[i] as Map)['id']?.toString() ?? '${prefix}_$i',
            ),
      ];

  /// An answer to a post-chat survey question: the next one, else on.
  NodeResult _handlePostChatResponse(dynamic response, FlowNode node, ChatState state) {
    final questions = getArray(node.data, 'postChatSurveyQuestions');
    final index = _postChatIndices[node.id] ?? 0;
    final value = response.toString().trim();
    state.addToTranscript('user', value);
    state.addRecord({
      '_id': node.id,
      'id': node.id,
      'shape': 'postchat-survey-response',
      'type': nodeType,
      'text': value,
      'questionIndex': index,
    });
    _postChatIndices[node.id] = index + 1;
    if (index + 1 < questions.length) {
      final next = questions[index + 1];
      state.addToTranscript('bot', next is Map ? next['questionText']?.toString() ?? '' : '');
      return NodeResult.displayUI(
        HumanHandoverUIState(
          state: HandoverState.postChatSurvey,
          preChatQuestions: _surveyQuestions(questions, 'postchat'),
          currentQuestionIndex: index + 1,
          nodeId: node.id,
        ),
        awaitInput: true,
      );
    }
    _cleanup(node.id);
    return NodeResult.next();
  }

  /// A restored chat back on this step (NodeFlowEngine.waitAt): it stands
  /// where the server says, without asking for a person again.
  void restoreAt(String nodeId, HandoverState stage) {
    _handoverState[nodeId] = stage;
  }

  /// A person accepted the handover.
  void onAgentAccepted(String nodeId, String agentName, {String? agentId}) {
    _handoverState[nodeId] = HandoverState.agentConnected;
    ChatState.instance.addToTranscript('bot', '$agentName has joined the chat');
  }

  /// The live chat ended: the post-chat survey when the step has one, else
  /// the flow carries on along the first edge. The builder saves the switch
  /// as `enablePostChatSurveyQuestions`, which is what the web reads (web
  /// core/events/agentListeners.ts, index.ts); the older
  /// `enablePostChatSurvey` still counts, as in the Android SDK.
  NodeResult onChatEnded(String nodeId, Map<String, dynamic> nodeData) {
    final questions = getArray(nodeData, 'postChatSurveyQuestions');
    final on = getBoolean(nodeData, 'enablePostChatSurveyQuestions') || getBoolean(nodeData, 'enablePostChatSurvey');
    if (on && questions.isNotEmpty) {
      _handoverState[nodeId] = HandoverState.postChatSurvey;
      _postChatIndices[nodeId] = 0;
      final first = questions.first;
      ChatState.instance.addToTranscript('bot', first is Map ? first['questionText']?.toString() ?? '' : '');
      return NodeResult.displayUI(
        HumanHandoverUIState(
          state: HandoverState.postChatSurvey,
          preChatQuestions: _surveyQuestions(questions, 'postchat'),
          currentQuestionIndex: 0,
          nodeId: nodeId,
        ),
        awaitInput: true,
      );
    }
    _cleanup(nodeId);
    return NodeResult.next();
  }

  /// Where a step stands.
  HandoverState? getHandoverState(String nodeId) => _handoverState[nodeId];

  /// Whether a step waits for, or has, a person.
  bool isHandoverActive(String nodeId) {
    final s = _handoverState[nodeId];
    return s == HandoverState.waitingForAgent || s == HandoverState.agentConnected;
  }

  void _cleanup(String nodeId) {
    _handoverState.remove(nodeId);
    _postChatIndices.remove(nodeId);
  }

  /// Forget every step's state (a new session).
  void reset() {
    _handoverState.clear();
    _postChatIndices.clear();
  }
}

/// The special steps.
final List<NodeHandler> specialHandlers = [HumanHandoverNodeHandler()];
