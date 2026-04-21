/// Text input handlers for ask question nodes
///
/// Handlers for simple text-based inputs:
/// - AskNameNodeHandler (name input)
/// - AskEmailNodeHandler (email with validation)
/// - AskPhoneNodeHandler (phone with validation)
/// - AskNumberNodeHandler (numeric input)
/// - AskUrlNodeHandler (URL with validation)
/// - AskLocationNodeHandler (location/address input)
/// - AskCustomNodeHandler (free text input)
library;

import '../../node_types.dart';
import '../../node_result.dart';
import '../../node_ui_state.dart';
import 'base_ask_handler.dart';

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
