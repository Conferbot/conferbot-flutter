import '../node_types.dart';
import '../node_result.dart';
import '../node_ui_state.dart' show TextInputType;
import '../../state/chat_state.dart';

// Re-export NodeResult and all its subclasses/aliases from the single source of truth
export '../node_result.dart';

// Re-export TextInputType so consumers of legacy_handlers.dart get it too
export '../node_ui_state.dart' show TextInputType;

/// UI state for nodes that require display (legacy variant)
///
/// This is the legacy NodeUIState base class used by display_handlers.dart,
/// choice_ui_states.dart, and integration_handlers.dart.
/// v2 handlers use the NodeUIState from node_ui_state.dart instead.
/// Both variants are accepted by NodeResult.displayUI() / DisplayUIResult.
abstract class NodeUIState {
  const NodeUIState();
}

/// Text input field
class TextInputState extends NodeUIState {
  final String questionText;
  final TextInputType inputType;
  final String? placeholder;
  final String? validationRegex;
  final String? errorMessage;
  final String nodeId;
  final String answerKey;

  const TextInputState({
    required this.questionText,
    required this.inputType,
    this.placeholder,
    this.validationRegex,
    this.errorMessage,
    required this.nodeId,
    required this.answerKey,
  });
}

/// File upload
class FileUploadState extends NodeUIState {
  final String questionText;
  final int maxSizeMb;
  final List<String>? allowedTypes;
  final String nodeId;
  final String answerKey;

  const FileUploadState({
    required this.questionText,
    this.maxSizeMb = 5,
    this.allowedTypes,
    required this.nodeId,
    required this.answerKey,
  });
}

/// Calendar/Date picker
class CalendarState extends NodeUIState {
  final String? questionText;
  final bool showTimeSelection;
  final String? timezone;
  final List<TimeSlot>? availableSlots;
  final String nodeId;
  final String answerKey;

  const CalendarState({
    this.questionText,
    required this.showTimeSelection,
    this.timezone,
    this.availableSlots,
    required this.nodeId,
    required this.answerKey,
  });
}

/// Time slot for calendar
class TimeSlot {
  final String date;
  final String? time;
  final bool available;

  const TimeSlot({
    required this.date,
    this.time,
    this.available = true,
  });
}

/// Range slider
class RangeState extends NodeUIState {
  final String? questionText;
  final int minValue;
  final int maxValue;
  final int? defaultValue;
  final String nodeId;
  final String answerKey;

  const RangeState({
    this.questionText,
    required this.minValue,
    required this.maxValue,
    this.defaultValue,
    required this.nodeId,
    required this.answerKey,
  });
}

/// Quiz question
class QuizState extends NodeUIState {
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String nodeId;
  final String answerKey;

  const QuizState({
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.nodeId,
    required this.answerKey,
  });
}

// RecordEntry is imported from chat_state.dart (single source of truth)

/// Chat state interface for handlers to interact with
abstract class ChatStateInterface {
  void addAnswerVariable(String nodeId, String answerKey);
  void setAnswerVariable(String nodeId, dynamic value);
  void setAnswerVariableByKey(String key, dynamic value);
  void setUserMetadata(String key, String value);
  void addToTranscript(String role, String text);
  void pushToRecord(RecordEntry entry);
  void setVariable(String name, dynamic value);
  dynamic resolveValue(String value);
}

/// Base interface for all node handlers
abstract class NodeHandler {
  /// The node type this handler processes
  String get nodeType;

  /// Process the node and return result
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId);

  /// Handle user response for interactive nodes
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    return const Proceed();
  }
}

/// Base class with common functionality for handlers
abstract class BaseNodeHandler extends NodeHandler {
  /// ChatState singleton provides full state access
  ChatState get state => ChatState.instance;

  /// Record a user response
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
      data: additionalData,
    );
    state.pushToRecord(entry);
  }

  /// Get string from nodeData with default
  String getString(Map<String, dynamic> nodeData, String key,
      [String defaultValue = '']) {
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
  bool getBoolean(Map<String, dynamic> nodeData, String key,
      [bool defaultValue = false]) {
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
    final emailRegex =
        RegExp(r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
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
// LEGACY NODE HANDLERS
// ============================================================================

/// Handler for user-input-node (legacy)
/// Handles various input types: name, email, number, url, phone, file, date
class UserInputNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.userInput;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final inputType = getString(nodeData, 'type', 'text');
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state.addAnswerVariable(nodeId, answerKey);

    switch (inputType.toLowerCase()) {
      case 'name':
        return DisplayUI(
          TextInputState(
            questionText: '',
            inputType: TextInputType.name,
            placeholder: 'Enter your name',
            nodeId: nodeId,
            answerKey: answerKey,
          ),
        );

      case 'email':
        return DisplayUI(
          TextInputState(
            questionText: '',
            inputType: TextInputType.email,
            placeholder: 'Enter your email',
            errorMessage:
                getString(nodeData, 'incorrectEmailResponse', 'Please enter a valid email'),
            nodeId: nodeId,
            answerKey: answerKey,
          ),
        );

      case 'number':
        return DisplayUI(
          TextInputState(
            questionText: '',
            inputType: TextInputType.number,
            placeholder: 'Enter a number',
            errorMessage:
                getString(nodeData, 'incorrectNumberResponse', 'Please enter a valid number'),
            nodeId: nodeId,
            answerKey: answerKey,
          ),
        );

      case 'url':
        return DisplayUI(
          TextInputState(
            questionText: '',
            inputType: TextInputType.url,
            placeholder: 'Enter a URL',
            errorMessage:
                getString(nodeData, 'incorrectUrlResponse', 'Please enter a valid URL'),
            nodeId: nodeId,
            answerKey: answerKey,
          ),
        );

      case 'mobile':
      case 'phone':
        return DisplayUI(
          TextInputState(
            questionText: '',
            inputType: TextInputType.phone,
            placeholder: 'Enter phone number',
            nodeId: nodeId,
            answerKey: answerKey,
          ),
        );

      case 'file':
        return DisplayUI(
          FileUploadState(
            questionText: '',
            maxSizeMb: 5,
            nodeId: nodeId,
            answerKey: answerKey,
          ),
        );

      case 'date':
        return DisplayUI(
          CalendarState(
            questionText: null,
            showTimeSelection: false,
            timezone: null,
            nodeId: nodeId,
            answerKey: answerKey,
          ),
        );

      default:
        return DisplayUI(
          TextInputState(
            questionText: '',
            inputType: TextInputType.text,
            placeholder: 'Type here...',
            nodeId: nodeId,
            answerKey: answerKey,
          ),
        );
    }
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final inputType = getString(nodeData, 'type', 'text');
    final value = response.toString().trim();

    // Validate based on type
    switch (inputType.toLowerCase()) {
      case 'email':
        if (!isValidEmail(value)) {
          return NodeError(
            getString(nodeData, 'incorrectEmailResponse', 'Please enter a valid email'),
            shouldProceed: false,
          );
        }
        state.setUserMetadata('email', value);

      case 'number':
        if (!isValidNumber(value)) {
          return NodeError(
            getString(nodeData, 'incorrectNumberResponse', 'Please enter a valid number'),
            shouldProceed: false,
          );
        }

      case 'url':
        if (!isValidUrl(value)) {
          return NodeError(
            getString(nodeData, 'incorrectUrlResponse', 'Please enter a valid URL'),
            shouldProceed: false,
          );
        }

      case 'name':
        if (value.isEmpty) {
          return const NodeError('Please enter your name', shouldProceed: false);
        }
        state.setUserMetadata('name', value);

      case 'mobile':
      case 'phone':
        if (!isValidPhone(value)) {
          return const NodeError('Please enter a valid phone number',
              shouldProceed: false);
        }
        state.setUserMetadata('phone', value);
    }

    state.setAnswerVariable(nodeId, value);
    state.addToTranscript('user', value);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-input-response',
      text: value,
      type: nodeType,
      additionalData: {'inputType': inputType},
    );

    // Handle name greeting
    if (inputType.toLowerCase() == 'name') {
      final greetResponse = nodeData['nameGreet']?.toString();
      if (greetResponse != null && greetResponse.isNotEmpty) {
        final greeting = greetResponse
            .replaceAll('{name}', value)
            .replaceAll('\${name}', value);
        state.addToTranscript('bot', greeting);
      }
      return const DelayedProceed(delayMs: 2000);
    }

    return const DelayedProceed(delayMs: 500);
  }
}

/// Handler for user-range-node (legacy)
/// Displays a range slider with 3-way branching
class UserRangeNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.userRange;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final minVal = getInt(nodeData, 'minVal', 0);
    final maxVal = getInt(nodeData, 'maxVal', 100);
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state.addAnswerVariable(nodeId, answerKey);

    return DisplayUI(
      RangeState(
        questionText: null,
        minValue: minVal,
        maxValue: maxVal,
        defaultValue: (minVal + maxVal) ~/ 2,
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
    int value;
    if (response is num) {
      value = response.toInt();
    } else if (response is String) {
      value = int.tryParse(response) ?? 0;
    } else {
      value = 0;
    }

    final minVal = getInt(nodeData, 'minVal', 0);
    final maxVal = getInt(nodeData, 'maxVal', 100);

    state.setAnswerVariable(nodeId, value);
    state.addToTranscript('user', value.toString());

    recordResponse(
      nodeId: nodeId,
      shape: 'user-range-response',
      text: value.toString(),
      type: nodeType,
      additionalData: {'minVal': minVal, 'maxVal': maxVal},
    );

    // Route based on value relative to min/max
    // This provides 3-way branching:
    // - source-1: value below min (shouldn't normally happen with slider)
    // - source-2: value within range
    // - source-3: value above max (shouldn't normally happen with slider)
    String targetPort;
    if (value < minVal) {
      targetPort = 'source-1';
    } else if (value >= minVal && value <= maxVal) {
      targetPort = 'source-2';
    } else {
      targetPort = 'source-3';
    }

    return Proceed(targetPort: targetPort);
  }
}

/// Handler for quiz-node (legacy)
/// Displays a quiz question with correct/incorrect routing
class QuizNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.quiz;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final answerKey = getString(nodeData, 'answerVariable', nodeId);
    state.addAnswerVariable(nodeId, answerKey);

    // Build options from option1, option2, etc.
    final options = <String>[];
    for (int i = 1; i <= 5; i++) {
      final optionKey = 'option$i';
      final disableKey = 'disableOption$i';

      if (getBoolean(nodeData, disableKey, false)) continue;

      final optionText = nodeData[optionKey]?.toString();
      if (optionText != null && optionText.isNotEmpty) {
        options.add(stripHtml(optionText));
      }
    }

    final correctAnswer = getInt(nodeData, 'correctAnswer', 0);

    return DisplayUI(
      QuizState(
        questionText: '',
        options: options,
        correctAnswerIndex: correctAnswer,
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
    int selectedIndex;
    if (response is num) {
      selectedIndex = response.toInt();
    } else if (response is String) {
      selectedIndex = int.tryParse(response) ?? -1;
    } else if (response is Map) {
      selectedIndex =
          int.tryParse(response['index']?.toString() ?? '') ?? -1;
    } else {
      selectedIndex = -1;
    }

    final correctAnswer = getInt(nodeData, 'correctAnswer', 0);
    final isCorrect = selectedIndex == correctAnswer;

    // Get selected option text
    final optionKey = 'option${selectedIndex + 1}';
    final selectedText = nodeData[optionKey]?.toString() ?? 'Unknown';

    state.setAnswerVariable(nodeId, selectedText);
    state.addToTranscript('user', selectedText);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-quiz-response',
      text: selectedText,
      type: nodeType,
      additionalData: {
        'selectedIndex': selectedIndex,
        'correctAnswer': correctAnswer,
        'isCorrect': isCorrect,
      },
    );

    // Route based on correct/incorrect
    if (isCorrect) {
      // Correct: go to source-2 (may increment a variable node)
      return const Proceed(targetPort: 'source-2');
    } else {
      // Incorrect: go to source-1
      return const Proceed(targetPort: 'source-1');
    }
  }
}
