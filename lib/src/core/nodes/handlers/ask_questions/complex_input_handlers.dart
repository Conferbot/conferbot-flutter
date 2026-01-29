/// Complex input handlers for ask question nodes
///
/// Handlers for complex input types:
/// - AskFileNodeHandler (file upload)
/// - AskMultipleQuestionsNodeHandler (sequential questions)
/// - CalendarNodeHandler (date/time picker)
library;

import '../../node_types.dart';
import '../../node_result.dart';
import '../../node_ui_state.dart';
import 'base_ask_handler.dart';

/// Handler for ask-file-node
/// Asks user to upload a file
class AskFileNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.askFile;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = getString(nodeData, 'questionText', 'Please upload a file');
    final answerKey = getString(nodeData, 'answerVariable', 'file');
    final maxSizeMb = getInt(nodeData, 'maxSize', 5);

    state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      FileUploadUIState(
        questionText: questionText,
        maxSizeMb: maxSizeMb,
        nodeId: nodeId,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    // Response should be a map with url and fileName
    Map<String, dynamic> responseMap;
    if (response is Map<String, dynamic>) {
      responseMap = response;
    } else if (response is Map) {
      responseMap = Map<String, dynamic>.from(response);
    } else {
      responseMap = {'url': response.toString()};
    }

    final fileUrl = responseMap['url']?.toString();
    if (fileUrl == null || fileUrl.isEmpty) {
      return const NodeResult.error(
        message: 'Invalid file upload',
        shouldProceed: false,
      );
    }

    final fileName = responseMap['fileName']?.toString() ?? 'uploaded_file';

    state.setAnswerVariable(nodeId, fileUrl);
    state.addToTranscript('user', '[File: $fileName]');

    recordResponse(
      nodeId: nodeId,
      shape: 'user-ask-file-response',
      text: fileName,
      type: nodeType,
      additionalData: {'url': fileUrl, 'fileName': fileName},
    );

    return const NodeResult.proceed();
  }
}

/// Question model for multiple questions handler
class Question {
  final String questionText;
  final String answerType;
  final String answerKey;

  const Question({
    required this.questionText,
    required this.answerType,
    required this.answerKey,
  });
}

/// UI State for multiple questions
class MultipleQuestionsUIState extends NodeUIState {
  final List<Question> questions;
  final int currentIndex;
  final String nodeId;

  const MultipleQuestionsUIState({
    required this.questions,
    required this.currentIndex,
    required this.nodeId,
  });
}

/// Handler for ask-multiple-questions-node
/// Asks multiple questions in sequence
class AskMultipleQuestionsNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.askMultiple;

  // Track current question index per node
  final Map<String, int> _questionIndices = {};

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questions = getList<Map<String, dynamic>>(nodeData, 'questions');

    if (questions.isEmpty) {
      return const NodeResult.proceed();
    }

    // Initialize question index for this node
    if (!_questionIndices.containsKey(nodeId)) {
      _questionIndices[nodeId] = 0;
    }

    return _displayCurrentQuestion(nodeData, nodeId, questions);
  }

  NodeResult _displayCurrentQuestion(
    Map<String, dynamic> nodeData,
    String nodeId,
    List<Map<String, dynamic>> questions,
  ) {
    final currentIndex = _questionIndices[nodeId] ?? 0;

    if (currentIndex >= questions.length) {
      _questionIndices.remove(nodeId);
      return const NodeResult.proceed();
    }

    final question = questions[currentIndex];
    final questionText = question['questionText']?.toString() ?? 'Please answer';

    state.addToTranscript('bot', questionText);

    final answerKey = '${nodeId}_q$currentIndex';
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      MultipleQuestionsUIState(
        questions: questions.asMap().entries.map((entry) {
          final i = entry.key;
          final q = entry.value;
          return Question(
            questionText: q['questionText']?.toString() ?? '',
            answerType: q['answerVariable']?.toString() ?? 'text',
            answerKey: '${nodeId}_q$i',
          );
        }).toList(),
        currentIndex: currentIndex,
        nodeId: nodeId,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final questions = getList<Map<String, dynamic>>(nodeData, 'questions');
    final currentIndex = _questionIndices[nodeId] ?? 0;

    if (currentIndex >= questions.length) {
      _questionIndices.remove(nodeId);
      return const NodeResult.proceed();
    }

    final question = questions[currentIndex];
    final answerType = question['answerVariable']?.toString() ?? 'text';
    final value = response.toString().trim();

    // Validate based on answer type
    switch (answerType.toLowerCase()) {
      case 'email':
        if (!isValidEmail(value)) {
          final errorMsg = question['incorrectEmailResponse']?.toString() ??
              nodeData['incorrectEmailResponse']?.toString() ??
              'Please enter a valid email';
          return NodeResult.error(message: errorMsg, shouldProceed: false);
        }
        state.setUserMetadata('email', value);
        break;

      case 'phone':
      case 'mobile':
        if (!isValidPhone(value)) {
          final errorMsg = question['incorrectPhoneNumberResponse']?.toString() ??
              nodeData['incorrectPhoneNumberResponse']?.toString() ??
              'Please enter a valid phone number';
          return NodeResult.error(message: errorMsg, shouldProceed: false);
        }
        state.setUserMetadata('phone', value);
        break;

      case 'name':
        if (value.isEmpty) {
          return const NodeResult.error(
            message: 'Please enter your name',
            shouldProceed: false,
          );
        }
        state.setUserMetadata('name', value);
        break;
    }

    // Store answer
    final answerKey = '${nodeId}_q$currentIndex';
    state.setAnswerVariable(nodeId, value);
    state.setAnswerVariableByKey(answerKey, value);
    state.addToTranscript('user', value);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-multiple-questions-response',
      text: value,
      type: nodeType,
      additionalData: {
        'questionIndex': currentIndex,
        'answerType': answerType,
      },
    );

    // Move to next question
    _questionIndices[nodeId] = currentIndex + 1;

    // Check if more questions
    if (currentIndex + 1 < questions.length) {
      return _displayCurrentQuestion(nodeData, nodeId, questions);
    }

    // All questions answered
    _questionIndices.remove(nodeId);
    return const NodeResult.proceed();
  }

  /// Reset state for a specific node (useful for testing or re-processing)
  void resetNodeState(String nodeId) {
    _questionIndices.remove(nodeId);
  }

  /// Reset all state
  void resetAllState() {
    _questionIndices.clear();
  }
}

/// Handler for calendar-node
/// Displays date/time picker
class CalendarNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.calendar;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = nodeData['questionText']?.toString();
    final showTimeSelection = getBoolean(nodeData, 'showTimeSelection', false);
    final timezone = nodeData['botTimeZone']?.toString() ?? nodeData['timezone']?.toString();
    final answerKey = getString(nodeData, 'answerVariable', 'calendar_selection');

    if (questionText != null && questionText.isNotEmpty) {
      state.addToTranscript('bot', questionText);
    }
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      CalendarUIState(
        questionText: questionText,
        showTimeSelection: showTimeSelection,
        nodeId: nodeId,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    // Response should be a map with date/time info
    Map<String, dynamic> responseMap;
    if (response is Map<String, dynamic>) {
      responseMap = response;
    } else if (response is Map) {
      responseMap = Map<String, dynamic>.from(response);
    } else {
      responseMap = {'date': response.toString()};
    }

    final date = responseMap['date']?.toString() ?? '';
    final time = responseMap['time']?.toString();
    final showTimeSelection = getBoolean(nodeData, 'showTimeSelection', false);

    final displayText = (showTimeSelection && time != null && time.isNotEmpty)
        ? '$date at $time'
        : date;

    state.setAnswerVariable(nodeId, displayText);
    state.addToTranscript('user', displayText);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-calendar-selection',
      text: displayText,
      type: nodeType,
      additionalData: {
        'date': date,
        'time': time,
        'botTimeZone': nodeData['botTimeZone'] ?? nodeData['timezone'],
        'visitorTimeZone': DateTime.now().timeZoneName,
      },
    );

    return const NodeResult.delayedProceed(delay: Duration(milliseconds: 400));
  }
}
