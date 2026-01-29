/// Human Handover UI Components
///
/// This library provides comprehensive UI components for the human handover flow
/// in the Conferbot SDK. It includes:
///
/// - Pre-chat forms for collecting user information
/// - Queue status displays with real-time updates
/// - Agent information cards with typing indicators
/// - Post-chat surveys with star ratings
/// - Complete handover overlay widget
///
/// Example usage:
/// ```dart
/// import 'package:conferbot/src/widgets/handover/handover.dart';
///
/// // Pre-chat form
/// PreChatFormWidget(
///   fields: [
///     PreChatFormField.name(),
///     PreChatFormField.email(),
///   ],
///   onSubmit: (result) => handlePreChatSubmit(result),
///   primaryColor: Colors.blue,
/// )
///
/// // Queue status
/// QueueStatusWidget(
///   queueInfo: QueueInfo(position: 3, estimatedWaitSeconds: 120),
///   maxWaitMinutes: 5,
///   onCancel: () => cancelHandover(),
///   primaryColor: Colors.blue,
/// )
///
/// // Agent info
/// AgentInfoWidget(
///   agent: agent,
///   isTyping: true,
///   primaryColor: Colors.blue,
/// )
///
/// // Post-chat survey
/// PostChatSurveyWidget(
///   agent: agent,
///   onSubmit: (result) => submitSurvey(result),
///   primaryColor: Colors.blue,
/// )
///
/// // Complete handover overlay
/// HumanHandoverOverlay(
///   uiState: handoverUIState,
///   agent: currentAgent,
///   primaryColor: Colors.blue,
///   onPreChatSubmit: (result) => submitPreChat(result),
///   onCancel: () => cancelHandover(),
///   onSurveySubmit: (result) => submitSurvey(result),
/// )
/// ```
library handover;

export 'pre_chat_form.dart';
export 'queue_status.dart';
export 'agent_info.dart';
export 'post_chat_survey.dart';
export 'human_handover_overlay.dart';
