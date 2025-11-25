/// Socket events matching embed-server socket.js
class SocketEvents {
  // Client to server events
  static const String mobileInit = 'mobile-init';
  static const String getChatbotData = 'get-chatbot-data';
  static const String sendVisitorMessage = 'send-visitor-message';
  static const String joinChatRoom = 'join-chat-room-visitor';
  static const String leaveChatRoom = 'leave-chat-room';
  static const String visitorTyping = 'visitor-typing';
  static const String initiateHandover = 'initiate-handover';
  static const String endChat = 'end-chat';
  static const String emailNodeTrigger = 'email-node-trigger';
  static const String zapierNodeTrigger = 'zapier-node-trigger';
  static const String calendarSlotSelectionRecord = 'calendar-slot-selection-record';

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

  // Connection events
  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String connectError = 'connect_error';
  static const String reconnect = 'reconnect';
  static const String reconnectAttempt = 'reconnect_attempt';
  static const String reconnectError = 'reconnect_error';
  static const String reconnectFailed = 'reconnect_failed';
}
