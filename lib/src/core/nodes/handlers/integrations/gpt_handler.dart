/// GPT/OpenAI integration handler
///
/// Handles AI conversation with OpenAI's GPT models.
/// The server does NOT handle gpt-node via execute-integration; matching the
/// web widget, the OpenAI Chat Completions API is called directly client-side
/// using the API key configured on the node.
library;

import 'dart:convert';
import 'dart:io';

import '../../node_types.dart';
import '../legacy_handlers.dart';
import '../display_handlers.dart';

/// OpenAI Chat Completions endpoint (matches the web widget constant)
const String _openAiChatApi = 'https://api.openai.com/v1/chat/completions';

/// Handler for gpt-node
/// Calls the OpenAI API directly with the node's apiKey/selectedModel and the
/// chat transcript, displays the completion as a bot message, then proceeds.
/// On any failure (missing key, network, API error) it records a gpt-error
/// and proceeds silently, matching the web widget fallback.
class GptNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.gpt;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final apiKey = nodeData['apiKey']?.toString() ?? '';

    if (apiKey.isEmpty) {
      recordResponse(
        nodeId: nodeId,
        shape: 'gpt-error',
        text: 'Missing API key',
        type: nodeType,
      );
      return const Proceed();
    }

    try {
      // Build the messages array from the transcript, matching the web
      // widget: 'bot' entries map to 'system', user entries stay 'user'
      final messages = state.transcript.map((entry) {
        return {
          'role': entry.by == 'bot' ? 'system' : 'user',
          'content': entry.message,
        };
      }).toList();

      // Prepend the node's context as an initial system message
      final context = nodeData['context']?.toString() ?? '';
      if (context.trim().isNotEmpty) {
        messages.insert(0, {
          'role': 'system',
          'content': context,
        });
      }

      final body = jsonEncode({
        'model': nodeData['selectedModel'] ?? 'gpt-3.5-turbo',
        'messages': messages,
        'temperature': 0.7,
      });

      final responseText = await _callOpenAi(apiKey, body);

      if (responseText != null && responseText.isNotEmpty) {
        // Add response to transcript and record it (web widget shape)
        state.addToTranscript('bot', responseText);

        recordResponse(
          nodeId: nodeId,
          shape: 'gpt-node-response',
          text: responseText,
          type: nodeType,
          additionalData: {
            'model': nodeData['selectedModel'] ?? 'gpt-3.5-turbo',
          },
        );

        // Display the message (message-only UI auto-proceeds in the engine)
        return DisplayUI(
          MessageState(
            text: responseText,
            nodeId: nodeId,
          ),
        );
      }

      recordResponse(
        nodeId: nodeId,
        shape: 'gpt-error',
        text: 'Empty response from OpenAI',
        type: nodeType,
      );
    } catch (e) {
      // Continue to next node even on error to prevent chat from freezing
      recordResponse(
        nodeId: nodeId,
        shape: 'gpt-error',
        text: e.toString(),
        type: nodeType,
      );
    }

    return const Proceed();
  }

  /// POST to the OpenAI Chat Completions API and extract the completion text.
  /// Returns null on non-2xx responses or malformed payloads.
  Future<String?> _callOpenAi(String apiKey, String body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(_openAiChatApi));
      request.headers.contentType = ContentType.json;
      request.headers.add('Authorization', 'Bearer $apiKey');
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;

      final message = (choices[0] as Map)['message'] as Map?;
      return message?['content']?.toString();
    } finally {
      client.close();
    }
  }
}
