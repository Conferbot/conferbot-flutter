/// Communication platform integration handlers
///
/// Handles integrations with communication services:
/// - Slack (send channel/DM messages)
/// - Discord (send channel messages via webhooks)
/// - Email (generic SMTP email sending)
library;

import '../../node_types.dart';
import '../legacy_handlers.dart';

/// Handler for email-node
/// Sends email (fire-and-forget via server)
class EmailNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.email;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    // Email is handled server-side via socket event
    // Just record and proceed
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
class SlackNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.slack;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
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
class DiscordNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.discord;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
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
