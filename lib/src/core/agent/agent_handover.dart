/// The initiate-handover payload for an AI agent bot's silent start, as the
/// web widget sends it (conferbot-widget buildAllMetaData +
/// _handleHumanHandoverNode, with silentStart) - the same shape the
/// human-handover node sends (node_flow_engine.dart _emitInitiateHandover).
library;

import '../state/chat_state.dart';
import '../live_chat/live_chat.dart';

class AgentHandover {
  AgentHandover._();

  static Map<String, dynamic>? payload(ChatState state, Map<String, dynamic> nodeData, {Map<String, dynamic> extra = const {}}) {
    final chatSessionId = state.chatSessionId;
    if (chatSessionId == null) return null;
    final botId = state.botId ?? '';
    final workspaceId = state.workspaceId ?? '';
    final botName = state.getVariable('_botName')?.toString() ?? '';
    final now = DateTime.now().toUtc().toIso8601String();
    final device = 'Flutter/${state.buildResponseData()['deviceInfo'] ?? 'unknown'}';
    final location = DateTime.now().timeZoneName;
    // Minutes as the builder wrote them ("0.5" is half a minute).
    final maxWaitTime = LiveChat.waitMinutes(nodeData['maxWaitTime']);
    return {
      'workspaceId': workspaceId,
      'chatbotId': botId,
      'chatbotName': botName,
      'chatSessionId': chatSessionId,
      'chatMetaData': {
        'version': 'v2',
        'workspaceId': workspaceId,
        'chatSessionId': chatSessionId,
        'botId': botId,
        'botName': botName,
        'chatDate': now,
        'deviceInfo': device,
        'location': location,
        'record': state.getRecordForServer(),
        'answerVariables': state.getAnswerVariablesMap(),
        'transcript': state.getTranscriptForGPT(),
      },
      'metaData': {
        'visitorId': state.visitorId ?? chatSessionId,
        'chatDate': now,
        'deviceInfo': device,
        'location': location,
      },
      'priority': nodeData['priority']?.toString() ?? 'normal',
      'maxWaitTime': maxWaitTime,
      'assignmentType': nodeData['assignmentType']?.toString() ?? 'auto',
      'assignmentStrategy': nodeData['agentAssignmentStrategy']?.toString() ?? '',
      'assignedAgents': nodeData['assignedAgents'] ?? [],
      'assignedAIAgents': nodeData['assignedAIAgents'] ?? [],
      ...extra,
    };
  }
}
