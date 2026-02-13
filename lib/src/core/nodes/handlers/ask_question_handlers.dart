/// Ask question handlers
///
/// Handlers for user input nodes that ask questions and validate responses.
/// All handlers extend BaseNodeHandler for consistent type hierarchy
/// with the NodeHandlerRegistry.
library;

import '../node_types.dart';
import '../node_result.dart';
import '../node_ui_state.dart';
import 'legacy_handlers.dart' hide NodeUIState, TextInputType;
import '../../state/chat_state.dart';

/// Base class for ask question handlers.
/// Extends BaseNodeHandler to be compatible with NodeHandlerRegistry
/// which expects NodeHandler instances.
abstract class BaseAskNodeHandler extends BaseNodeHandler {
  // All utility methods (getString, getInt, getBoolean, getList, getMap,
  // stripHtml, isValidEmail, isValidPhone, isValidUrl, isValidNumber,
  // recordResponse, state) are inherited from BaseNodeHandler.
}

// ============================================================================
// ASK QUESTION NODE HANDLERS
// ============================================================================

/// Handler for ask-name-node
/// Asks user for their name
class AskNameNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.askName;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = getString(nodeData, 'questionText', 'What is your name?');
    final answerKey = getString(nodeData, 'answerVariable', 'name');

    state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      TextInputUIState(
        questionText: questionText,
        inputType: TextInputType.name,
        placeholder: 'Enter your name',
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final name = response.toString().trim();

    if (name.isEmpty) {
      return const NodeResult.error(
        message: 'Please enter your name',
        shouldProceed: false,
      );
    }

    state.setAnswerVariable(nodeId, name);
    state.setUserMetadata('name', name);
    state.addToTranscript('user', name);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-ask-name-response',
      text: name,
      type: nodeType,
    );

    final greetResponse = nodeData['nameGreetResponse']?.toString() ??
        nodeData['nameGreet']?.toString();

    if (greetResponse != null && greetResponse.isNotEmpty) {
      final greeting = greetResponse
          .replaceAll('{name}', name)
          .replaceAll('\${name}', name)
          .replaceAll('{{name}}', name);
      state.addToTranscript('bot', greeting);
    }

    return const NodeResult.delayedProceed(delay: Duration(milliseconds: 500));
  }
}

/// Handler for ask-email-node
class AskEmailNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.askEmail;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = getString(nodeData, 'questionText', 'What is your email?');
    final answerKey = getString(nodeData, 'answerVariable', 'email');
    final errorMessage = getString(nodeData, 'incorrectEmailResponse', 'Please enter a valid email address');

    state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      TextInputUIState(
        questionText: questionText,
        inputType: TextInputType.email,
        placeholder: 'Enter your email',
        errorMessage: errorMessage,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, Map<String, dynamic> nodeData, String nodeId) async {
    final email = response.toString().trim();
    final errorMessage = getString(nodeData, 'incorrectEmailResponse', 'Please enter a valid email address');

    if (!isValidEmail(email)) {
      return NodeResult.error(message: errorMessage, shouldProceed: false);
    }

    state.setAnswerVariable(nodeId, email);
    state.setUserMetadata('email', email);
    state.addToTranscript('user', email);

    recordResponse(nodeId: nodeId, shape: 'user-ask-email-response', text: email, type: nodeType);
    return const NodeResult.proceed();
  }
}

/// Handler for ask-phone-number-node
class AskPhoneNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.askPhone;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = getString(nodeData, 'questionText', 'What is your phone number?');
    final answerKey = getString(nodeData, 'answerVariable', 'phone');
    final errorMessage = getString(nodeData, 'incorrectPhoneNumberResponse', 'Please enter a valid phone number');

    state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      TextInputUIState(
        questionText: questionText,
        inputType: TextInputType.phone,
        placeholder: 'Enter your phone number',
        errorMessage: errorMessage,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, Map<String, dynamic> nodeData, String nodeId) async {
    final phone = response.toString().trim();
    final errorMessage = getString(nodeData, 'incorrectPhoneNumberResponse', 'Please enter a valid phone number');

    if (!isValidPhone(phone)) {
      return NodeResult.error(message: errorMessage, shouldProceed: false);
    }

    state.setAnswerVariable(nodeId, phone);
    state.setUserMetadata('phone', phone);
    state.addToTranscript('user', phone);

    recordResponse(nodeId: nodeId, shape: 'user-ask-phone-response', text: phone, type: nodeType);
    return const NodeResult.proceed();
  }
}

/// Handler for ask-number-node
class AskNumberNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.askNumber;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = getString(nodeData, 'questionText', 'Please enter a number');
    final answerKey = getString(nodeData, 'answerVariable', 'number');

    state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      TextInputUIState(
        questionText: questionText,
        inputType: TextInputType.number,
        placeholder: 'Enter a number',
        errorMessage: 'Please enter a valid number',
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, Map<String, dynamic> nodeData, String nodeId) async {
    final value = response.toString().trim();

    if (!isValidNumber(value)) {
      return const NodeResult.error(message: 'Please enter a valid number', shouldProceed: false);
    }

    final number = double.tryParse(value) ?? 0.0;
    state.setAnswerVariable(nodeId, number);
    state.addToTranscript('user', value);

    recordResponse(nodeId: nodeId, shape: 'user-ask-number-response', text: value, type: nodeType);
    return const NodeResult.proceed();
  }
}

/// Handler for ask-url-node
class AskUrlNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.askUrl;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = getString(nodeData, 'questionText', 'Please enter a URL');
    final answerKey = getString(nodeData, 'answerVariable', 'url');

    state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      TextInputUIState(
        questionText: questionText,
        inputType: TextInputType.url,
        placeholder: 'Enter a URL',
        errorMessage: 'Please enter a valid URL',
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, Map<String, dynamic> nodeData, String nodeId) async {
    final url = response.toString().trim();

    if (!isValidUrl(url)) {
      return const NodeResult.error(message: 'Please enter a valid URL', shouldProceed: false);
    }

    state.setAnswerVariable(nodeId, url);
    state.addToTranscript('user', url);

    recordResponse(nodeId: nodeId, shape: 'user-ask-url-response', text: url, type: nodeType);
    return const NodeResult.proceed();
  }
}

/// Handler for ask-location-node
class AskLocationNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.askLocation;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = getString(nodeData, 'questionText', 'What is your location?');
    final answerKey = getString(nodeData, 'answerVariable', 'location');

    state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      TextInputUIState(
        questionText: questionText,
        inputType: TextInputType.location,
        placeholder: 'Enter your location',
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, Map<String, dynamic> nodeData, String nodeId) async {
    final location = response.toString().trim();

    if (location.isEmpty) {
      return const NodeResult.error(message: 'Please enter a location', shouldProceed: false);
    }

    state.setAnswerVariable(nodeId, location);
    state.addToTranscript('user', location);

    recordResponse(nodeId: nodeId, shape: 'user-ask-location-response', text: location, type: nodeType);
    return const NodeResult.proceed();
  }
}

/// Handler for ask-custom-question-node
class AskCustomNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.askCustom;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = getString(nodeData, 'questionText', 'Please answer the question');
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      TextInputUIState(
        questionText: questionText,
        inputType: TextInputType.text,
        placeholder: 'Type your answer',
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, Map<String, dynamic> nodeData, String nodeId) async {
    final answer = response.toString().trim();

    if (answer.isEmpty) {
      return const NodeResult.error(message: 'Please enter an answer', shouldProceed: false);
    }

    state.setAnswerVariable(nodeId, answer);
    state.addToTranscript('user', answer);

    recordResponse(nodeId: nodeId, shape: 'user-ask-custom-response', text: answer, type: nodeType);
    return const NodeResult.proceed();
  }
}

/// Handler for ask-file-node
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
      FileUploadUIState(questionText: questionText, maxSizeMb: maxSizeMb, nodeId: nodeId, answerKey: answerKey),
    );
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, Map<String, dynamic> nodeData, String nodeId) async {
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
      return const NodeResult.error(message: 'Invalid file upload', shouldProceed: false);
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

/// Handler for ask-multiple-questions-node
class AskMultipleQuestionsNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.askMultiple;

  final Map<String, int> _questionIndices = {};

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questions = getList<Map<String, dynamic>>(nodeData, 'questions');

    if (questions.isEmpty) return const NodeResult.proceed();
    if (!_questionIndices.containsKey(nodeId)) _questionIndices[nodeId] = 0;

    return _displayCurrentQuestion(nodeData, nodeId, questions);
  }

  NodeResult _displayCurrentQuestion(Map<String, dynamic> nodeData, String nodeId, List<Map<String, dynamic>> questions) {
    final currentIndex = _questionIndices[nodeId] ?? 0;
    if (currentIndex >= questions.length) {
      _questionIndices.remove(nodeId);
      return const NodeResult.proceed();
    }

    final question = questions[currentIndex];
    final questionText = question['questionText']?.toString() ?? 'Please answer';

    state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, '${nodeId}_q$currentIndex');

    return NodeResult.displayUI(
      MultipleQuestionsUIState(
        questions: questions.asMap().entries.map((e) => Question(
              questionText: e.value['questionText']?.toString() ?? '',
              answerType: e.value['answerVariable']?.toString() ?? 'text',
              answerKey: '${nodeId}_q${e.key}',
            )).toList(),
        currentIndex: currentIndex,
        nodeId: nodeId,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, Map<String, dynamic> nodeData, String nodeId) async {
    final questions = getList<Map<String, dynamic>>(nodeData, 'questions');
    final currentIndex = _questionIndices[nodeId] ?? 0;

    if (currentIndex >= questions.length) {
      _questionIndices.remove(nodeId);
      return const NodeResult.proceed();
    }

    final question = questions[currentIndex];
    final answerType = question['answerVariable']?.toString() ?? 'text';
    final value = response.toString().trim();

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
        if (value.isEmpty) return const NodeResult.error(message: 'Please enter your name', shouldProceed: false);
        state.setUserMetadata('name', value);
        break;
    }

    final answerKey = '${nodeId}_q$currentIndex';
    state.setAnswerVariable(nodeId, value);
    state.setAnswerVariableByKey(answerKey, value);
    state.addToTranscript('user', value);

    recordResponse(nodeId: nodeId, shape: 'user-multiple-questions-response', text: value, type: nodeType,
        additionalData: {'questionIndex': currentIndex, 'answerType': answerType});

    _questionIndices[nodeId] = currentIndex + 1;
    if (currentIndex + 1 < questions.length) return _displayCurrentQuestion(nodeData, nodeId, questions);

    _questionIndices.remove(nodeId);
    return const NodeResult.proceed();
  }

  void resetNodeState(String nodeId) => _questionIndices.remove(nodeId);
  void resetAllState() => _questionIndices.clear();
}

/// Handler for calendar-node
class CalendarNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.calendar;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = nodeData['questionText']?.toString();
    final showTimeSelection = getBoolean(nodeData, 'showTimeSelection', false);
    final timezone = nodeData['botTimeZone']?.toString() ?? nodeData['timezone']?.toString();
    final answerKey = getString(nodeData, 'answerVariable', 'calendar_selection');

    if (questionText != null && questionText.isNotEmpty) state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      CalendarUIState(questionText: questionText, showTimeSelection: showTimeSelection, timezone: timezone, nodeId: nodeId, answerKey: answerKey),
    );
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, Map<String, dynamic> nodeData, String nodeId) async {
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

    final displayText = (showTimeSelection && time != null && time.isNotEmpty) ? '$date at $time' : date;

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

// ============================================================================
// HANDLER REGISTRY HELPERS
// ============================================================================

/// Get all ask question handlers
List<BaseAskNodeHandler> getAskQuestionHandlers() {
  return [
    AskNameNodeHandler(),
    AskEmailNodeHandler(),
    AskPhoneNodeHandler(),
    AskNumberNodeHandler(),
    AskUrlNodeHandler(),
    AskLocationNodeHandler(),
    AskCustomNodeHandler(),
    AskFileNodeHandler(),
    AskMultipleQuestionsNodeHandler(),
    CalendarNodeHandler(),
  ];
}

/// Create a map of node types to handlers
Map<String, BaseAskNodeHandler> createAskQuestionHandlerMap() {
  final handlers = getAskQuestionHandlers();
  return {for (var handler in handlers) handler.nodeType: handler};
}
