/// GPT/OpenAI integration handler
///
/// Handles AI conversation with OpenAI's GPT models.
/// Emits 'execute-integration' to the server which performs the actual
/// OpenAI API call server-side (matching web widget / Android SDK protocol).
library;

import '../../node_types.dart';
import '../legacy_handlers.dart';
import '../display_handlers.dart';
import 'integration_base.dart';

/// Handler for gpt-node
/// Delegates GPT execution to the server via execute-integration socket event.
/// The server calls the OpenAI API with the configured model/context and
/// returns the response via integration-result.
class GptNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.gpt;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    // Emit execute-integration to server and wait for GPT response
    final result = await emitExecuteIntegration(
      nodeData: nodeData,
      nodeId: nodeId,
    );

    // Extract the GPT response text from the server result
    final responseText = result?['response']?.toString()
        ?? result?['text']?.toString()
        ?? result?['content']?.toString();

    if (responseText != null && responseText.isNotEmpty) {
      // Add response to transcript
      state.addToTranscript('bot', responseText);

      recordResponse(
        nodeId: nodeId,
        shape: 'gpt-response',
        text: responseText,
        type: nodeType,
        additionalData: {
          'model': nodeData['selectedModel'] ?? 'gpt-3.5-turbo',
        },
      );

      // Display the message
      return DisplayUI(
        MessageState(
          text: responseText,
          nodeId: nodeId,
        ),
      );
    }

    // If no response, just proceed
    recordResponse(
      nodeId: nodeId,
      shape: 'gpt-no-response',
      type: nodeType,
    );

    return const Proceed();
  }
}
