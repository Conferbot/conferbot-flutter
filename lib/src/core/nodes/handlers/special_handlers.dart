import '../node_handler.dart';
import '../node_result.dart';
import '../node_types.dart';
import '../node_ui_state.dart';

/// Handler for delay-node
/// Delays before proceeding to next node
class DelayNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.delay;

  @override
  Future<NodeResult> process(
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final delaySeconds = getInt(nodeData, 'delay', 1);
    final delayMs = delaySeconds * 1000;

    return NodeResult.delayedProceed(
      delay: Duration(milliseconds: delayMs),
    );
  }
}

/// Handler for human-handover-node
/// Manages live agent handover flow with full support for:
/// - Pre-chat questions
/// - Waiting for agent state
/// - Agent connected state
/// - No agents available fallback
/// - Post-chat survey
class HumanHandoverNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.humanHandover;

  // Track pre-chat question index per node
  final Map<String, int> _preChatIndices = {};

  // Track post-chat survey question index per node
  final Map<String, int> _postChatIndices = {};

  // Track handover state per node
  final Map<String, HandoverState> _handoverState = {};

  // Track collected pre-chat answers per node
  final Map<String, Map<String, dynamic>> _preChatAnswers = {};

  @override
  Future<NodeResult> process(
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final enablePreChatQuestions = getBoolean(nodeData, 'enablePreChatQuestions', false);
    final preChatQuestions = getList<Map<String, dynamic>>(nodeData, 'preChatQuestions');

    // Initialize state for this node if not already set
    if (!_handoverState.containsKey(nodeId)) {
      if (enablePreChatQuestions && preChatQuestions.isNotEmpty) {
        _handoverState[nodeId] = HandoverState.preChatQuestions;
        _preChatIndices[nodeId] = 0;
        _preChatAnswers[nodeId] = {};
      } else {
        _handoverState[nodeId] = HandoverState.waitingForAgent;
      }
    }

    return switch (_handoverState[nodeId]) {
      HandoverState.preChatQuestions => _displayPreChatQuestion(nodeData, nodeId, preChatQuestions),
      HandoverState.waitingForAgent => _initiateHandover(nodeData, nodeId),
      _ => NodeResult.displayUI(_buildHandoverUIState(nodeData, nodeId)),
    };
  }

  /// Display the current pre-chat question
  NodeResult _displayPreChatQuestion(
    Map<String, dynamic> nodeData,
    String nodeId,
    List<Map<String, dynamic>> questions,
  ) {
    final currentIndex = _preChatIndices[nodeId] ?? 0;

    if (currentIndex >= questions.length) {
      // All pre-chat questions answered, start handover
      _handoverState[nodeId] = HandoverState.waitingForAgent;
      return _initiateHandover(nodeData, nodeId);
    }

    final question = questions[currentIndex];
    final questionText = question['questionText']?.toString() ?? 'Please answer';
    final answerType = question['answerVariable']?.toString() ?? 'text';
    final answerKey = question['id']?.toString() ?? 'prechat_$currentIndex';

    state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, answerKey);

    final preChatList = questions.asMap().entries.map((entry) {
      final i = entry.key;
      final q = entry.value;
      return PreChatQuestion(
        id: q['id']?.toString() ?? 'q$i',
        questionText: q['questionText']?.toString() ?? '',
        answerType: q['answerVariable']?.toString() ?? 'text',
        answerKey: q['id']?.toString() ?? 'prechat_$i',
      );
    }).toList();

    return NodeResult.displayUI(
      HumanHandoverUIState(
        state: HandoverState.preChatQuestions,
        preChatQuestions: preChatList,
        currentQuestionIndex: currentIndex,
        nodeId: nodeId,
      ),
    );
  }

  /// Initiate the handover to a live agent
  NodeResult _initiateHandover(
    Map<String, dynamic> nodeData,
    String nodeId,
  ) {
    final handoverMessage = getString(nodeData, 'handoverMessage', 'Connecting you to an agent...');
    final maxWaitTime = getInt(nodeData, 'maxWaitTime', 5); // minutes
    final priority = getString(nodeData, 'priority', 'normal');

    state.addToTranscript('bot', handoverMessage);

    recordResponse(
      nodeId: nodeId,
      shape: 'handover-initiated',
      text: handoverMessage,
      type: nodeType,
      additionalData: {
        'priority': priority,
        'maxWaitTime': maxWaitTime,
        'preChatAnswers': _preChatAnswers[nodeId] ?? {},
      },
    );

    return NodeResult.displayUI(
      HumanHandoverUIState(
        state: HandoverState.waitingForAgent,
        handoverMessage: handoverMessage,
        maxWaitTime: maxWaitTime,
        nodeId: nodeId,
      ),
    );
  }

  /// Build the current handover UI state
  HumanHandoverUIState _buildHandoverUIState(
    Map<String, dynamic> nodeData,
    String nodeId,
  ) {
    return HumanHandoverUIState(
      state: _handoverState[nodeId] ?? HandoverState.waitingForAgent,
      handoverMessage: getString(nodeData, 'handoverMessage', ''),
      maxWaitTime: getInt(nodeData, 'maxWaitTime', 5),
      nodeId: nodeId,
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    return switch (_handoverState[nodeId]) {
      HandoverState.preChatQuestions => _handlePreChatResponse(response, nodeData, nodeId),
      HandoverState.postChatSurvey => _handlePostChatResponse(response, nodeData, nodeId),
      HandoverState.agentConnected => _handleAgentChatMessage(response, nodeData, nodeId),
      _ => NodeResult.displayUI(_buildHandoverUIState(nodeData, nodeId)),
    };
  }

  /// Handle a response to a pre-chat question
  NodeResult _handlePreChatResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) {
    final questions = getList<Map<String, dynamic>>(nodeData, 'preChatQuestions');
    final currentIndex = _preChatIndices[nodeId] ?? 0;

    if (currentIndex >= questions.length) {
      _handoverState[nodeId] = HandoverState.waitingForAgent;
      return _initiateHandover(nodeData, nodeId);
    }

    final question = questions[currentIndex];
    final answerType = question['answerVariable']?.toString() ?? 'text';
    final value = response.toString().trim();

    // Validate based on type
    switch (answerType.toLowerCase()) {
      case 'email':
        if (!isValidEmail(value)) {
          final errorMsg = question['incorrectEmailResponse']?.toString() ?? 'Please enter a valid email';
          return NodeResult.error(message: errorMsg, shouldProceed: false);
        }
        state.setUserMetadata('email', value);
        break;

      case 'phone':
      case 'mobile':
        if (!isValidPhone(value)) {
          final errorMsg = question['incorrectPhoneNumberResponse']?.toString() ?? 'Please enter a valid phone number';
          return NodeResult.error(message: errorMsg, shouldProceed: false);
        }
        state.setUserMetadata('phone', value);
        break;

      case 'name':
        if (value.isEmpty) {
          return const NodeResult.error(message: 'Please enter your name', shouldProceed: false);
        }
        state.setUserMetadata('name', value);
        break;
    }

    // Store answer
    final answerKey = question['id']?.toString() ?? 'prechat_$currentIndex';
    state.setAnswerVariable(nodeId, value);
    state.setAnswerVariableByKey(answerKey, value);
    state.addToTranscript('user', value);

    // Store in pre-chat answers map for handover
    _preChatAnswers[nodeId] ??= {};
    _preChatAnswers[nodeId]![answerKey] = value;

    recordResponse(
      nodeId: nodeId,
      shape: 'prechat-question-response',
      text: value,
      type: nodeType,
      additionalData: {'questionIndex': currentIndex},
    );

    // Move to next question
    _preChatIndices[nodeId] = currentIndex + 1;

    // Check if more questions
    if (currentIndex + 1 < questions.length) {
      return _displayPreChatQuestion(nodeData, nodeId, questions);
    }

    // All pre-chat questions answered
    _handoverState[nodeId] = HandoverState.waitingForAgent;
    return _initiateHandover(nodeData, nodeId);
  }

  /// Handle a response to a post-chat survey question
  NodeResult _handlePostChatResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) {
    final questions = getList<Map<String, dynamic>>(nodeData, 'postChatSurveyQuestions');
    final currentIndex = _postChatIndices[nodeId] ?? 0;

    final value = response.toString().trim();

    // Store answer
    state.addToTranscript('user', value);
    recordResponse(
      nodeId: nodeId,
      shape: 'postchat-survey-response',
      text: value,
      type: nodeType,
      additionalData: {'questionIndex': currentIndex},
    );

    // Move to next question
    _postChatIndices[nodeId] = currentIndex + 1;

    // Check if more questions
    if (currentIndex + 1 < questions.length) {
      // Display next post-chat question
      final nextQuestion = questions[currentIndex + 1];
      state.addToTranscript('bot', nextQuestion['questionText']?.toString() ?? '');

      final preChatList = questions.asMap().entries.map((entry) {
        final i = entry.key;
        final q = entry.value;
        return PreChatQuestion(
          id: q['id']?.toString() ?? 'q$i',
          questionText: q['questionText']?.toString() ?? '',
          answerType: q['answerVariable']?.toString() ?? 'text',
          answerKey: q['id']?.toString() ?? 'postchat_$i',
        );
      }).toList();

      return NodeResult.displayUI(
        HumanHandoverUIState(
          state: HandoverState.postChatSurvey,
          preChatQuestions: preChatList,
          currentQuestionIndex: currentIndex + 1,
          nodeId: nodeId,
        ),
      );
    }

    // All post-chat questions answered, proceed to next node
    _cleanup(nodeId);
    return const NodeResult.proceed();
  }

  /// Handle a chat message during agent-connected state
  NodeResult _handleAgentChatMessage(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) {
    final message = response.toString().trim();

    if (message.isNotEmpty) {
      state.addToTranscript('user', message);
      recordResponse(
        nodeId: nodeId,
        shape: 'handover-user-message',
        text: message,
        type: nodeType,
      );
    }

    // Stay in agent connected state
    return NodeResult.displayUI(_buildHandoverUIState(nodeData, nodeId));
  }

  /// Called when an agent accepts the handover
  /// This should be called from the socket event handler
  void onAgentAccepted(String nodeId, String agentName, {String? agentId}) {
    _handoverState[nodeId] = HandoverState.agentConnected;
    state.addToTranscript('bot', '$agentName has joined the chat');
  }

  /// Called when no agents are available
  /// This should be called from the socket event handler
  NodeResult onNoAgentsAvailable(String nodeId, Map<String, dynamic> nodeData) {
    _handoverState[nodeId] = HandoverState.noAgentsAvailable;
    final fallbackMessage = getString(nodeData, 'fallbackMessage', 'No agents available at the moment.');
    final fallbackAction = getString(nodeData, 'fallbackAction', 'message');

    state.addToTranscript('bot', fallbackMessage);

    recordResponse(
      nodeId: nodeId,
      shape: 'no-agents-available',
      text: fallbackMessage,
      type: nodeType,
      additionalData: {'fallbackAction': fallbackAction},
    );

    // Check if we should proceed to fallback flow
    if (fallbackAction == 'proceed' || fallbackAction == 'flow') {
      _cleanup(nodeId);
      return const NodeResult.proceed(targetPort: 'source-fallback');
    }

    return NodeResult.displayUI(
      HumanHandoverUIState(
        state: HandoverState.noAgentsAvailable,
        handoverMessage: fallbackMessage,
        nodeId: nodeId,
      ),
    );
  }

  /// Called when the agent chat ends - start post-chat survey if enabled
  /// This should be called from the socket event handler
  NodeResult onChatEnded(String nodeId, Map<String, dynamic> nodeData) {
    final enablePostChatSurvey = getBoolean(nodeData, 'enablePostChatSurvey', false);
    final postChatQuestions = getList<Map<String, dynamic>>(nodeData, 'postChatSurveyQuestions');

    if (enablePostChatSurvey && postChatQuestions.isNotEmpty) {
      _handoverState[nodeId] = HandoverState.postChatSurvey;
      _postChatIndices[nodeId] = 0;

      final firstQuestion = postChatQuestions[0];
      state.addToTranscript('bot', firstQuestion['questionText']?.toString() ?? '');

      final preChatList = postChatQuestions.asMap().entries.map((entry) {
        final i = entry.key;
        final q = entry.value;
        return PreChatQuestion(
          id: q['id']?.toString() ?? 'q$i',
          questionText: q['questionText']?.toString() ?? '',
          answerType: q['answerVariable']?.toString() ?? 'text',
          answerKey: q['id']?.toString() ?? 'postchat_$i',
        );
      }).toList();

      return NodeResult.displayUI(
        HumanHandoverUIState(
          state: HandoverState.postChatSurvey,
          preChatQuestions: preChatList,
          currentQuestionIndex: 0,
          nodeId: nodeId,
        ),
      );
    }

    // No post-chat survey, proceed to next node
    _cleanup(nodeId);
    return const NodeResult.proceed();
  }

  /// Called when an agent sends a message during connected state
  /// This should be called from the socket event handler
  void onAgentMessage(String nodeId, String agentName, String message) {
    state.addToTranscript('agent', message);
    recordResponse(
      nodeId: nodeId,
      shape: 'handover-agent-message',
      text: message,
      type: nodeType,
      additionalData: {'agentName': agentName},
    );
  }

  /// Get the current handover state for a node
  HandoverState? getHandoverState(String nodeId) {
    return _handoverState[nodeId];
  }

  /// Check if handover is active for a node
  bool isHandoverActive(String nodeId) {
    final state = _handoverState[nodeId];
    return state == HandoverState.waitingForAgent || state == HandoverState.agentConnected;
  }

  /// Get collected pre-chat answers for a node
  Map<String, dynamic> getPreChatAnswers(String nodeId) {
    return Map<String, dynamic>.from(_preChatAnswers[nodeId] ?? {});
  }

  /// Clean up state for a node
  void _cleanup(String nodeId) {
    _handoverState.remove(nodeId);
    _preChatIndices.remove(nodeId);
    _postChatIndices.remove(nodeId);
    _preChatAnswers.remove(nodeId);
  }

  /// Reset all state (useful for testing or session reset)
  void reset() {
    _handoverState.clear();
    _preChatIndices.clear();
    _postChatIndices.clear();
    _preChatAnswers.clear();
  }
}
