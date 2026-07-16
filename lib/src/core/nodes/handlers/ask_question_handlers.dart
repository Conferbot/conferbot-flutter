/// Ask question handlers
///
/// Handlers for user input nodes that ask questions and validate responses.
/// All handlers extend BaseNodeHandler for consistent type hierarchy
/// with the NodeHandlerRegistry.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../node_types.dart';
import '../node_result.dart';
import '../node_ui_state.dart';
import 'legacy_handlers.dart' hide NodeUIState, TextInputType;
import 'integrations/integration_base.dart';
import '../../state/chat_state.dart';
import '../../../config/constants.dart';

/// Base class for ask question handlers.
/// Extends BaseNodeHandler to be compatible with NodeHandlerRegistry
/// which expects NodeHandler instances.
abstract class BaseAskNodeHandler extends BaseNodeHandler {
  // All utility methods (getString, getInt, getBoolean, getList, getMap,
  // stripHtml, isValidEmail, isValidPhone, isValidUrl, isValidNumber,
  // recordResponse, resolveText, state) are inherited from BaseNodeHandler.
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
    final questionText =
        resolveText(getString(nodeData, 'questionText', 'What is your name?'));
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
      // Resolve any ${var}/{var} references (name was just stored above)
      final greeting = resolveText(greetResponse);
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
    final questionText =
        resolveText(getString(nodeData, 'questionText', 'What is your email?'));
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
    final questionText =
        resolveText(getString(nodeData, 'questionText', 'What is your phone number?'));
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
    final questionText =
        resolveText(getString(nodeData, 'questionText', 'Please enter a number'));
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
    final questionText =
        resolveText(getString(nodeData, 'questionText', 'Please enter a URL'));
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
    final questionText =
        resolveText(getString(nodeData, 'questionText', 'What is your location?'));
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
    final questionText =
        resolveText(getString(nodeData, 'questionText', 'Please answer the question'));
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
    final questionText =
        resolveText(getString(nodeData, 'questionText', 'Please upload a file'));
    final answerKey = getString(nodeData, 'answerVariable', 'file');
    final maxSizeMb = getInt(nodeData, 'maxSize', 5);

    state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      FileUploadUIState(questionText: questionText, maxSizeMb: maxSizeMb, nodeId: nodeId, answerKey: answerKey),
    );
  }

  /// Maximum upload size accepted by the media endpoint (web widget parity)
  static const int _maxUploadBytes = 5000000;

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

    var fileUrl = responseMap['url']?.toString();

    // If the picker returned raw file info instead of an uploaded URL,
    // upload it to the media endpoint (mirrors the web widget's multipart
    // POST to /api/v1/bot/:botId/media)
    if (fileUrl == null || fileUrl.isEmpty) {
      final fileSize = responseMap['fileSize'];
      if (fileSize is num && fileSize > _maxUploadBytes) {
        return const NodeResult.error(
          message: 'Please upload a file smaller than 5MB',
          shouldProceed: false,
        );
      }

      try {
        fileUrl = await _uploadFile(responseMap);
      } catch (_) {
        fileUrl = null;
      }

      if (fileUrl == null || fileUrl.isEmpty) {
        return const NodeResult.error(
          message: 'File upload failed. Please try again.',
          shouldProceed: false,
        );
      }
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

  /// Upload the picked file to the embed-server media endpoint.
  /// Returns the media URL from the response, or null on failure.
  Future<String?> _uploadFile(Map<String, dynamic> responseMap) async {
    final botId = state.botId;
    if (botId == null || botId.isEmpty) return null;

    // The media endpoint lives on the embed-server origin (same host the
    // socket connects to)
    var origin = IntegrationNodeHandler.socketClient?.socketUrl ??
        ConferBotEndpoints.socketUrl;
    if (origin.endsWith('/')) origin = origin.substring(0, origin.length - 1);

    final uri = Uri.parse('$origin/api/v1/bot/$botId/media').replace(
      queryParameters: {
        'chatSessionId': state.chatSessionId ?? '',
        'visitorId': state.visitorId ?? '',
      },
    );

    final request = http.MultipartRequest('POST', uri);

    final filePath = responseMap['filePath']?.toString();
    final fileName = responseMap['fileName']?.toString() ?? 'uploaded_file';
    final fileBytes = responseMap['fileBytes'];

    if (filePath != null && filePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );
    } else if (fileBytes is List<int>) {
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );
    } else {
      return null;
    }

    final streamed =
        await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final json = jsonDecode(response.body);
    if (json is Map) return json['url']?.toString();
    return null;
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
    final questionText =
        resolveText(question['questionText']?.toString() ?? 'Please answer');

    state.addToTranscript('bot', questionText);
    state.addAnswerVariable(nodeId, '${nodeId}_q$currentIndex');

    return NodeResult.displayUI(
      MultipleQuestionsUIState(
        questions: questions.asMap().entries.map((e) => Question(
              questionText: resolveText(e.value['questionText']?.toString() ?? ''),
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
    final rawQuestionText = nodeData['questionText']?.toString();
    final questionText =
        rawQuestionText != null ? resolveText(rawQuestionText) : null;
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

    final botTimeZone =
        (nodeData['botTimeZone'] ?? nodeData['timezone'])?.toString();
    final visitorTimeZone = DateTime.now().timeZoneName;

    recordResponse(
      nodeId: nodeId,
      shape: 'user-calendar-selection',
      text: displayText,
      type: nodeType,
      additionalData: {
        'date': date,
        'time': time,
        'botTimeZone': botTimeZone,
        'visitorTimeZone': visitorTimeZone,
      },
    );

    // Emit calendar-slot-selection-record to the server when a time slot was
    // selected, matching the web widget payload
    if (showTimeSelection && time != null && time.isNotEmpty) {
      final socket = IntegrationNodeHandler.socketClient;
      if (socket != null && socket.isConnected) {
        socket.sendCalendarSlotSelectionRecord({
          'visitorId': state.visitorId,
          'chatbotId': state.botId,
          'nodeId': nodeId,
          'selectedDate': responseMap['selectedDate'] ?? date,
          'botTimeZone': botTimeZone,
          'visitorTimeZone': visitorTimeZone,
          'timeSlotSelected': time,
          'visitorTime': responseMap['visitorTime'] ?? time,
        });
      }
    }

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
