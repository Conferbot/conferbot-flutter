/// Socket events matching embed-server socket.js
class SocketEvents {
  // Client to server events (matching embed-server/socket.js)
  static const String getChatbotData = 'get-chatbot-data';
  static const String joinChatRoomVisitor = 'join-chat-room-visitor';
  static const String leaveChatRoom = 'leave-chat-room';
  static const String responseRecord = 'response-record'; // Send visitor message/response
  static const String visitorTyping = 'visitor-typing';
  static const String initiateHandover = 'initiate-handover';
  static const String endChat = 'end-chat';
  static const String leaveChat = 'leave-chat';
  static const String toggleVisitorInput = 'toggle-visitor-input';
  static const String emailNodeTrigger = 'email-node-trigger';
  static const String zapierNodeTrigger = 'zapier-node-trigger';
  static const String executeIntegration = 'execute-integration';
  static const String integrationResult = 'integration-result';
  static const String calendarSlotSelectionRecord = 'calendar-slot-selection-record';
  static const String handoverTimeout = 'handover-timeout';

  // Deprecated - use correct event names
  @Deprecated('Use joinChatRoomVisitor instead')
  static const String joinChatRoom = joinChatRoomVisitor;

  // Server to client events
  static const String fetchedChatbotData = 'fetched-chatbot-data';
  static const String botResponse = 'bot-response';
  static const String agentMessage = 'agent-message';
  static const String agentAccepted = 'agent-accepted';
  static const String agentLeft = 'agent-left';
  static const String agentTypingStatus = 'agent-typing-status';
  static const String visitorTypingStatus = 'visitor-typing-status';
  static const String chatEnded = 'chat-ended';
  static const String visitorDisconnected = 'visitor-disconnected';
  static const String visitorInputToggled = 'visitor-input-toggled';
  static const String destroyNotification = 'destroy-notification';
  static const String noAgentsAvailable = 'no-agents-available';

  // Connection events
  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String connectError = 'connect_error';
  static const String reconnect = 'reconnect';
  static const String reconnectAttempt = 'reconnect_attempt';
  static const String reconnectError = 'reconnect_error';
  static const String reconnectFailed = 'reconnect_failed';

  // ========== Human Handover Events ========== //
  // Client to server handover events

  /// Submit pre-chat form data before handover
  /// Payload: { chatId, botId, visitorData: { name, email, phone, customFields } }
  static const String submitPreChatForm = 'submit-pre-chat-form';

  /// Cancel handover request while in queue
  /// Payload: { chatId, botId }
  static const String cancelHandover = 'cancel-handover';

  /// Request current queue status
  /// Payload: { chatId, botId }
  static const String requestQueueStatus = 'request-queue-status';

  /// Submit post-chat survey/rating
  /// Payload: { chatId, botId, agentId, rating, feedback, conversationId }
  static const String submitPostChatSurvey = 'submit-post-chat-survey';

  /// Visitor ended the agent chat
  /// Payload: { chatId, botId }
  static const String visitorEndedChat = 'visitor-ended-chat';

  // Server to client handover events

  /// Pre-chat form configuration received
  /// Payload: { questions: [...], title, description }
  static const String preChatFormConfig = 'pre-chat-form-config';

  /// Queue status update
  /// Payload: { position, estimatedWaitSeconds, agentsAvailable, availableAgentCount, statusMessage }
  static const String queueStatusUpdate = 'queue-status-update';

  /// Agent is connecting (found an available agent)
  /// Payload: { agentId, agentName }
  static const String agentConnecting = 'agent-connecting';

  /// Handover was cancelled (by user or timeout)
  /// Payload: { reason: 'user_cancelled' | 'timeout' | 'no_agents' }
  static const String handoverCancelled = 'handover-cancelled';

  /// Handover failed (error occurred)
  /// Payload: { error, message }
  static const String handoverFailed = 'handover-failed';

  /// Agent profile update (avatar, status change)
  /// Payload: { agentId, name, avatar, status, title }
  static const String agentProfileUpdate = 'agent-profile-update';

  /// Survey submitted successfully
  /// Payload: { success: true }
  static const String surveySubmitted = 'survey-submitted';

  /// Chat transcript sent to email
  /// Payload: { email, success }
  static const String transcriptSent = 'transcript-sent';

  // ========== Analytics Events ========== //
  // Client to server analytics events (matching web widget chatAnalytics.ts)

  /// Track chat session start with attribution data
  static const String trackChatStart = 'track-chat-start';

  /// Track node entry/visit
  static const String trackNodeVisit = 'track-node-visit';

  /// Track node exit with dwell time and exit type
  static const String trackNodeExit = 'track-node-exit';

  /// Track user message for sentiment analysis
  static const String trackSentiment = 'track-sentiment';

  /// Track user interactions (link clicks, button clicks, file uploads, etc.)
  static const String trackInteraction = 'track-interaction';

  /// Track goal completion with conversion data
  static const String trackGoalCompletion = 'track-goal-completion';

  /// Periodic engagement update with session metrics
  static const String trackChatEngagement = 'track-chat-engagement';

  /// Submit chat rating (CSAT, NPS, thumbs up/down)
  static const String submitChatRating = 'submit-chat-rating';

  /// Track potential drop-off (user leaving mid-flow)
  static const String trackDropOff = 'track-drop-off';

  /// Finalize analytics when session ends
  static const String finalizeAnalytics = 'finalize-analytics';
}

// HandoverState is defined in node_ui_state.dart to avoid name collision
