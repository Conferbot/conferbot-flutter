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
/// Sends email (server-side via execute-integration socket event)
class EmailNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.email;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    // Emit execute-integration to server (fire-and-forget for email)
    await emitExecuteIntegration(
      nodeData: nodeData,
      nodeId: nodeId,
      waitForResult: false,
    );

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
