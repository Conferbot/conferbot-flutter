/// The initiate-handover payload, as the web widget sends it
/// (conferbot-widget buildAllMetaData + _handleHumanHandoverNode): used by
/// the human-handover node (node_flow_engine.dart _emitInitiateHandover) and
/// by an AI agent bot's silent start (with silentStart).
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
    final method = nodeData['assignmentMethod'];
    final skills = nodeData['requiredSkills'];
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
      // The step's notification settings, as the web sends them: an
      // explicit enableHandoverEmail false is what keeps the team's email off.
      'enableHandoverEmail': nodeData['enableHandoverEmail'],
      'enableHandoverSound': nodeData['enableHandoverSound'],
      'checkedSoundTab': nodeData['checkedSoundTab'],
      'selectedSound': nodeData['selectedSound'],
      'customHandoverSoundUrl': nodeData['customHandoverSoundUrl'],
      // Assignment overrides for this step, only when set (a step that
      // follows the workspace setting sends what it always did).
      if (method is String && method.isNotEmpty && method != 'workspace') 'assignmentMethod': method,
      if (skills is List && skills.isNotEmpty) 'requiredSkills': skills,
      ...extra,
    };
  }
}
