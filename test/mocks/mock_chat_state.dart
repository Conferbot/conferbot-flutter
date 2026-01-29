import 'package:conferbot_flutter/src/core/nodes/handlers/legacy_handlers.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';

/// Mock implementation of ChatStateInterface for testing handlers
class MockChatState implements ChatStateInterface {
  final Map<String, dynamic> answerVariables = {};
  final Map<String, dynamic> variables = {};
  final Map<String, String> userMetadata = {};
  final List<TranscriptEntry> transcriptEntries = [];
  final List<RecordEntry> recordEntries = [];

  String? chatSessionId;
  String? visitorId;
  String? botId;
  String? workspaceId;
  int currentIndex = 0;
  List<Map<String, dynamic>> steps = [];

  @override
  void addAnswerVariable(String nodeId, String answerKey) {
    answerVariables[nodeId] = {'key': answerKey, 'value': null};
  }

  @override
  void setAnswerVariable(String nodeId, dynamic value) {
    if (answerVariables.containsKey(nodeId)) {
      answerVariables[nodeId]['value'] = value;
    } else {
      answerVariables[nodeId] = {'key': nodeId, 'value': value};
    }
  }

  @override
  void setUserMetadata(String key, String value) {
    userMetadata[key] = value;
  }

  @override
  void addToTranscript(String role, String text) {
    transcriptEntries.add(TranscriptEntry(by: role, message: text));
  }

  @override
  void pushToRecord(RecordEntry entry) {
    recordEntries.add(entry);
  }

  /// Set a variable (for logic handlers)
  void setVariable(String name, dynamic value) {
    variables[name] = value;
  }

  /// Get a variable
  dynamic getVariable(String name) {
    return variables[name];
  }

  /// Resolve a value that might be a variable reference
  dynamic resolveValue(String value) {
    final variablePattern = RegExp(r'\{\{(.+?)\}\}|\$\{(.+?)\}');
    final match = variablePattern.firstMatch(value);

    if (match != null) {
      final varName = match.group(1)?.isNotEmpty == true
          ? match.group(1)!
          : match.group(2)!;

      // First check answer variables
      for (final entry in answerVariables.values) {
        if (entry is Map && entry['key'] == varName) {
          return entry['value'] ?? value;
        }
      }

      // Then check temp variables
      return variables[varName] ?? value;
    }

    return value;
  }

  /// Set answer variable by key
  void setAnswerVariableByKey(String key, dynamic value) {
    answerVariables['column_mapped_$key'] = {'key': key, 'value': value};
  }

  /// Initialize the state
  void initialize({
    required String chatSessionId,
    required String visitorId,
    required String botId,
    String? workspaceId,
  }) {
    this.chatSessionId = chatSessionId;
    this.visitorId = visitorId;
    this.botId = botId;
    this.workspaceId = workspaceId;
  }

  /// Set the flow steps
  void setSteps(List<Map<String, dynamic>> steps) {
    this.steps = List.from(steps);
  }

  /// Set current index
  void setCurrentIndex(int index) {
    currentIndex = index;
  }

  /// Get answer variable value by key
  dynamic getAnswerVariableValue(String key) {
    for (final entry in answerVariables.values) {
      if (entry is Map && entry['key'] == key) {
        return entry['value'];
      }
    }
    return null;
  }

  /// Reset all state
  void reset() {
    answerVariables.clear();
    variables.clear();
    userMetadata.clear();
    transcriptEntries.clear();
    recordEntries.clear();
    chatSessionId = null;
    visitorId = null;
    botId = null;
    workspaceId = null;
    currentIndex = 0;
    steps = [];
  }

  /// Build response data for server
  Map<String, dynamic> buildResponseData() {
    return {
      'version': 'v2',
      'chatSessionId': chatSessionId,
      'visitorId': visitorId,
      'botId': botId,
      'record': recordEntries.map((e) => e.toJson()).toList(),
      'answerVariables': answerVariables.entries
          .map((e) => {'nodeId': e.key, ...e.value as Map})
          .toList(),
      'workspaceId': workspaceId,
    };
  }
}

/// Transcript entry for testing
class TranscriptEntry {
  final String by;
  final String message;
  final int timestamp;

  TranscriptEntry({
    required this.by,
    required this.message,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
}
