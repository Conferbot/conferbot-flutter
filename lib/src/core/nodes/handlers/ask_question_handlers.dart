import '../node_types.dart';
import '../node_result.dart';
import '../node_ui_state.dart';
import '../../state/chat_state.dart';

/// Base interface for node handlers with chat state integration
abstract class BaseAskNodeHandler {
  /// The node type this handler processes
  String get nodeType;

  /// Chat state singleton for session management
  ChatState get state => ChatState();

  /// Process the node and return result
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId);

  /// Handle user response for interactive nodes
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  );

  /// Record a user response entry
  void recordResponse({
    required String nodeId,
    required String shape,
    String? text,
    String? type,
    Map<String, dynamic> additionalData = const {},
  }) {
    final entry = RecordEntry(
      id: nodeId,
      shape: shape,
      type: type,
      text: text,
      data: Map<String, dynamic>.from(additionalData),
    );
    state.pushToRecord(entry);
  }

  /// Get string from nodeData with default
  String getString(Map<String, dynamic> nodeData, String key, [String defaultValue = '']) {
    return nodeData[key]?.toString() ?? defaultValue;
  }

  /// Get int from nodeData with default
  int getInt(Map<String, dynamic> nodeData, String key, [int defaultValue = 0]) {
    final value = nodeData[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Get boolean from nodeData with default
  bool getBoolean(Map<String, dynamic> nodeData, String key, [bool defaultValue = false]) {
    final value = nodeData[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return defaultValue;
  }

  /// Get list from nodeData
  List<T> getList<T>(Map<String, dynamic> nodeData, String key) {
    final value = nodeData[key];
    if (value is List) return List<T>.from(value);
    return [];
  }

  /// Get map from nodeData
  Map<String, dynamic> getMap(Map<String, dynamic> nodeData, String key) {
    final value = nodeData[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  /// Strip HTML tags and decode entities
  String stripHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  /// Validate email format
  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  /// Validate phone number format
  bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^[+]?[0-9]{7,15}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[\s\-()]'), ''));
  }

  /// Validate URL format
  bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      return uri.scheme.isNotEmpty && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Validate number format
  bool isValidNumber(String value) {
    return double.tryParse(value.trim()) != null;
  }
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

    // Add question to transcript
    state.addToTranscript('bot', questionText);

    // Initialize answer variable
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

    // Update answer variable
    state.setAnswerVariable(nodeId, name);

    // Set user metadata
    state.setUserMetadata('name', name);

    // Add to transcript
    state.addToTranscript('user', name);

    // Record the response
    recordResponse(
      nodeId: nodeId,
      shape: 'user-ask-name-response',
      text: name,
      type: nodeType,
    );

    // Display greeting if configured
    final greetResponse = nodeData['nameGreetResponse']?.toString() ??
        nodeData['nameGreet']?.toString();

    if (greetResponse != null && greetResponse.isNotEmpty) {
      // Replace placeholders with name
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
/// Asks user for their email
class AskEmailNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.askEmail;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = getString(nodeData, 'questionText', 'What is your email?');
    final answerKey = getString(nodeData, 'answerVariable', 'email');
    final errorMessage = getString(
      nodeData,
      'incorrectEmailResponse',
      'Please enter a valid email address',
    );

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
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final email = response.toString().trim();
    final errorMessage = getString(
      nodeData,
      'incorrectEmailResponse',
      'Please enter a valid email address',
    );

    if (!isValidEmail(email)) {
      return NodeResult.error(message: errorMessage, shouldProceed: false);
    }

    state.setAnswerVariable(nodeId, email);
    state.setUserMetadata('email', email);
    state.addToTranscript('user', email);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-ask-email-response',
      text: email,
      type: nodeType,
    );

    return const NodeResult.proceed();
  }
}

/// Handler for ask-phone-number-node
/// Asks user for their phone number
class AskPhoneNodeHandler extends BaseAskNodeHandler {
  @override
  String get nodeType => NodeTypes.askPhone;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = getString(nodeData, 'questionText', 'What is your phone number?');
    final answerKey = getString(nodeData, 'answerVariable', 'phone');
    final errorMessage = getString(
      nodeData,
      'incorrectPhoneNumberResponse',
      'Please enter a valid phone number',
    );

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
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final phone = response.toString().trim();
    final errorMessage = getString(
      nodeData,
      'incorrectPhoneNumberResponse',
      'Please enter a valid phone number',
    );

    if (!isValidPhone(phone)) {
      return NodeResult.error(message: errorMessage, shouldProceed: false);
    }

    state.setAnswerVariable(nodeId, phone);
    state.setUserMetadata('phone', phone);
    state.addToTranscript('user', phone);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-ask-phone-response',
      text: phone,
      type: nodeType,
    );

    return const NodeResult.proceed();
  }
}

/// Handler for ask-number-node
/// Asks user for a number
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
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final value = response.toString().trim();

    if (!isValidNumber(value)) {
      return const NodeResult.error(
        message: 'Please enter a valid number',
        shouldProceed: false,
      );
    }

    final number = double.tryParse(value) ?? 0.0;

    state.setAnswerVariable(nodeId, number);
    state.addToTranscript('user', value);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-ask-number-response',
      text: value,
      type: nodeType,
    );

    return const NodeResult.proceed();
  }
}

/// Handler for ask-url-node
/// Asks user for a URL
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
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final url = response.toString().trim();

    if (!isValidUrl(url)) {
      return const NodeResult.error(
        message: 'Please enter a valid URL',
        shouldProceed: false,
      );
    }

    state.setAnswerVariable(nodeId, url);
    state.addToTranscript('user', url);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-ask-url-response',
      text: url,
      type: nodeType,
    );

    return const NodeResult.proceed();
  }
}

/// Handler for ask-location-node
/// Asks user for a location
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
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final location = response.toString().trim();

    if (location.isEmpty) {
      return const NodeResult.error(
        message: 'Please enter a location',
        shouldProceed: false,
      );
    }

    state.setAnswerVariable(nodeId, location);
    state.addToTranscript('user', location);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-ask-location-response',
      text: location,
      type: nodeType,
    );

    return const NodeResult.proceed();
  }
}

/// Handler for ask-custom-question-node
/// Asks a custom question
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
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final answer = response.toString().trim();

    if (answer.isEmpty) {
      return const NodeResult.error(
        message: 'Please enter an answer',
        shouldProceed: false,
      );
    }

    state.setAnswerVariable(nodeId, answer);
    state.addToTranscript('user', answer);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-ask-custom-response',
      text: answer,
      type: nodeType,
    );

    return const NodeResult.proceed();
  }
}

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
        timezone: timezone,
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
