/// GPT/OpenAI integration handler
///
/// Handles AI conversation with OpenAI's GPT models.
/// Supports custom system contexts, model selection, and full ChatState access.
library;

import 'dart:convert';
import 'dart:io';

import '../../node_types.dart';
import '../legacy_handlers.dart';
import '../display_handlers.dart';
import '../../../state/chat_state.dart';

// ============================================================================
// GPT CONTEXT BUILDER
// ============================================================================

/// Builds comprehensive GPT context from ChatState
/// This class provides full conversation context for GPT API calls
class GptContextBuilder {
  final ChatState _chatState;

  GptContextBuilder(this._chatState);

  /// Build the full GPT context including conversation history and user metadata
  Map<String, dynamic> buildContext({
    String? systemPrompt,
    String? additionalContext,
    int? maxHistoryMessages,
  }) {
    final messages = <Map<String, String>>[];

    // Add system prompt
    final effectiveSystemPrompt = _buildSystemPrompt(
      systemPrompt: systemPrompt,
      additionalContext: additionalContext,
    );
    messages.add({'role': 'system', 'content': effectiveSystemPrompt});

    // Add conversation history
    final transcriptMessages = _getTranscriptMessages(maxHistoryMessages);
    messages.addAll(transcriptMessages);

    return {
      'messages': messages,
      'userContext': _buildUserContext(),
      'conversationMetadata': _buildConversationMetadata(),
    };
  }

  /// Build OpenAI-compatible messages array
  List<Map<String, String>> buildMessagesArray({
    String? systemPrompt,
    String? additionalContext,
    int? maxHistoryMessages,
  }) {
    final messages = <Map<String, String>>[];

    // Add system prompt
    final effectiveSystemPrompt = _buildSystemPrompt(
      systemPrompt: systemPrompt,
      additionalContext: additionalContext,
    );
    messages.add({'role': 'system', 'content': effectiveSystemPrompt});

    // Add conversation history
    final transcriptMessages = _getTranscriptMessages(maxHistoryMessages);
    messages.addAll(transcriptMessages);

    return messages;
  }

  /// Build system prompt with user context injected
  String _buildSystemPrompt({
    String? systemPrompt,
    String? additionalContext,
  }) {
    final buffer = StringBuffer();

    // Base system prompt
    buffer.writeln(systemPrompt ?? 'You are a helpful assistant.');

    // Add user context to system prompt
    final userContext = _buildUserContext();
    if (userContext.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('User Information:');
      if (userContext['name'] != null) {
        buffer.writeln('- Name: ${userContext['name']}');
      }
      if (userContext['email'] != null) {
        buffer.writeln('- Email: ${userContext['email']}');
      }
      if (userContext['phone'] != null) {
        buffer.writeln('- Phone: ${userContext['phone']}');
      }
    }

    // Add previous answers context
    final previousAnswers = _chatState.getAnswerVariablesMap();
    if (previousAnswers.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Previous Answers from Conversation:');
      previousAnswers.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          buffer.writeln('- $key: $value');
        }
      });
    }

    // Add any additional context
    if (additionalContext != null && additionalContext.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(additionalContext);
    }

    return buffer.toString();
  }

  /// Get transcript messages formatted for GPT
  List<Map<String, String>> _getTranscriptMessages(int? maxMessages) {
    final transcript = _chatState.transcript;

    // Apply message limit if specified
    List<TranscriptEntry> relevantTranscript;
    if (maxMessages != null && maxMessages > 0 && transcript.length > maxMessages) {
      relevantTranscript = transcript.sublist(transcript.length - maxMessages);
    } else {
      relevantTranscript = transcript.toList();
    }

    return relevantTranscript.map((entry) {
      return {
        'role': entry.by == 'bot' || entry.by == 'agent' ? 'assistant' : 'user',
        'content': entry.message,
      };
    }).toList();
  }

  /// Build user context from metadata
  Map<String, dynamic> _buildUserContext() {
    final metadata = _chatState.userMetadata;
    return {
      if (metadata.name != null && metadata.name!.isNotEmpty) 'name': metadata.name,
      if (metadata.email != null && metadata.email!.isNotEmpty) 'email': metadata.email,
      if (metadata.phone != null && metadata.phone!.isNotEmpty) 'phone': metadata.phone,
      ...metadata.metadata,
    };
  }

  /// Build conversation metadata
  Map<String, dynamic> _buildConversationMetadata() {
    return {
      'chatSessionId': _chatState.chatSessionId,
      'visitorId': _chatState.visitorId,
      'botId': _chatState.botId,
      'messageCount': _chatState.transcript.length,
      'answerVariables': _chatState.getAnswerVariablesMap(),
    };
  }
}

// ============================================================================
// GPT NODE HANDLER
// ============================================================================

/// Handler for gpt-node
/// Sends conversation context to OpenAI with full ChatState access
class GptNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.gpt;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final apiKey = getString(nodeData, 'apiKey', '');
    final model = getString(nodeData, 'selectedModel', 'gpt-3.5-turbo');
    final systemPrompt = nodeData['systemPrompt']?.toString() ?? nodeData['context']?.toString();
    final temperature = _parseDouble(nodeData['temperature'], 0.7);
    final maxTokens = getInt(nodeData, 'maxTokens', 1000);
    final maxHistoryMessages = getInt(nodeData, 'maxHistoryMessages', 0);
    final userMessage = nodeData['userMessage']?.toString();

    if (apiKey.isEmpty) {
      return const Proceed(); // Skip if no API key
    }

    try {
      // Access full ChatState for comprehensive context
      final chatState = ChatState();
      final contextBuilder = GptContextBuilder(chatState);

      // Build messages with full conversation context
      final messages = contextBuilder.buildMessagesArray(
        systemPrompt: systemPrompt,
        maxHistoryMessages: maxHistoryMessages > 0 ? maxHistoryMessages : null,
      );

      // Add explicit user message if provided (for direct GPT queries)
      if (userMessage != null && userMessage.isNotEmpty) {
        messages.add({'role': 'user', 'content': userMessage});
      }

      // If no user messages exist, add a prompt to continue the conversation
      if (!messages.any((m) => m['role'] == 'user')) {
        messages.add({
          'role': 'user',
          'content': 'Please provide a helpful response based on our conversation so far.',
        });
      }

      // Call OpenAI API
      final response = await _callOpenAI(
        apiKey: apiKey,
        model: model,
        messages: messages,
        temperature: temperature,
        maxTokens: maxTokens,
      );

      if (response != null) {
        // Add response to transcript
        state?.addToTranscript('bot', response);

        // Record the response
        recordResponse(
          nodeId: nodeId,
          shape: 'gpt-response',
          text: response,
          type: nodeType,
          additionalData: {
            'model': model,
            'messageCount': messages.length,
          },
        );

        // Display the message
        return DisplayUI(
          MessageState(
            text: response,
            nodeId: nodeId,
          ),
        );
      }
    } on SocketException catch (e) {
      recordResponse(
        nodeId: nodeId,
        shape: 'gpt-error',
        text: 'Network error: $e',
        type: nodeType,
      );
    } on FormatException catch (e) {
      recordResponse(
        nodeId: nodeId,
        shape: 'gpt-error',
        text: 'Data format error: $e',
        type: nodeType,
      );
    } catch (e) {
      recordResponse(
        nodeId: nodeId,
        shape: 'gpt-error',
        text: 'Unexpected error: $e',
        type: nodeType,
      );
    }

    return const Proceed();
  }

  double _parseDouble(dynamic value, double defaultValue) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  Future<String?> _callOpenAI({
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 1000,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );

      request.headers.contentType = ContentType.json;
      request.headers.add('Authorization', 'Bearer $apiKey');

      final body = jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
      });
      request.write(body);

      final response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>;
        if (choices.isNotEmpty) {
          final firstChoice = choices[0] as Map<String, dynamic>;
          final message = firstChoice['message'] as Map<String, dynamic>;
          return message['content'] as String;
        }
      } else {
        // Handle API error
        final responseBody = await response.transform(utf8.decoder).join();
        throw Exception('OpenAI API error: ${response.statusCode} - $responseBody');
      }
      return null;
    } finally {
      client.close();
    }
  }

  /// Build GPT context map for external use (e.g., server-side processing)
  /// This method can be called externally to get the full context structure
  static Map<String, dynamic> buildGptContextForExport() {
    final chatState = ChatState();
    final contextBuilder = GptContextBuilder(chatState);
    return contextBuilder.buildContext();
  }
}
