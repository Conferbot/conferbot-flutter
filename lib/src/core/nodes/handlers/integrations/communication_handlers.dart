/// Communication platform integration handlers
///
/// Handles integrations with communication services:
/// - Slack (send channel/DM messages)
/// - Discord (send channel messages via webhooks)
/// - Email (generic SMTP email sending)
///
/// All handlers emit 'execute-integration' to the server via socket,
/// matching the web widget / Android SDK protocol.
library;

import '../../node_types.dart';
import '../legacy_handlers.dart';
import 'integration_base.dart';

/// Handler for email-node
/// Sends email via the server's email-node-trigger socket event
/// (NOT execute-integration - the dispatcher does not handle email-node).
class EmailNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.email;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final socket = IntegrationNodeHandler.socketClient;

    if (socket != null && socket.isConnected) {
      // Build the data object matching the web widget's _handleEmailNode
      final dataObject = <String, dynamic>{
        'nodeData': nodeData,
        'botName': state.getVariable('_botName')?.toString() ?? '',
        'transcript': state.transcript
            .map((entry) => {'by': entry.by, 'message': entry.message})
            .toList(),
        'visitorName': state.userMetadata.name ?? '',
        'visitorEmail': state.userMetadata.email ?? '',
      };

      // Flatten each answer variable as key: value on the data object
      for (final variable in state.answerVariables) {
        dataObject[variable.key] = variable.value;
      }

      // Attach the answer variables array (server expects [{key, value}, ...])
      dataObject['answerVariables'] =
          state.answerVariables.map((v) => v.toJson()).toList();

      dataObject['chatDate'] = DateTime.now().toUtc().toIso8601String();
      dataObject['workspaceId'] = state.workspaceId;

      socket.sendEmailNodeTrigger(dataObject);
    }

    recordResponse(
      nodeId: nodeId,
      shape: 'email-triggered',
      type: nodeType,
      additionalData: {
        'to': nodeData['to'],
        'subject': nodeData['subject'],
      },
    );

    return const Proceed();
  }
}

/// Handler for slack-node
/// Sends messages to Slack
class SlackNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.slack;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    await emitExecuteIntegration(
      nodeData: nodeData,
      nodeId: nodeId,
      waitForResult: false,
    );

    recordResponse(
      nodeId: nodeId,
      shape: 'slack-message',
      text: nodeData['message']?.toString(),
      type: nodeType,
      additionalData: {'channel': nodeData['channel']},
    );

    return const Proceed();
  }
}

/// Handler for discord-node
/// Sends messages to Discord
class DiscordNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.discord;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    await emitExecuteIntegration(
      nodeData: nodeData,
      nodeId: nodeId,
      waitForResult: false,
    );

    recordResponse(
      nodeId: nodeId,
      shape: 'discord-message',
      text: nodeData['message']?.toString(),
      type: nodeType,
      additionalData: {'channel': nodeData['channel']},
    );

    return const Proceed();
  }
}
