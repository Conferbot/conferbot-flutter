/// Conferbot SDK constants
class ConferBotConstants {
  // API Configuration
  static const String defaultApiBaseUrl = 'https://embed.conferbot.com/api/v1/mobile';
  static const String defaultSocketUrl = 'https://embed.conferbot.com';
  static const int apiTimeout = 30000; // 30 seconds
  static const int socketTimeout = 20000; // 20 seconds

  // Headers
  static const String headerApiKey = 'X-API-Key';
  static const String headerBotId = 'X-Bot-ID';
  static const String headerPlatform = 'X-Platform';

  // Platform identifier
  static const String platformIdentifier = 'flutter';

  // Socket configuration
  static const int socketReconnectionAttempts = 5;
  static const int socketReconnectionDelay = 1000;
  static const int socketReconnectionDelayMax = 5000;

  // Message limits
  static const int maxMessageLength = 5000;
  static const int maxFileSize = 10485760; // 10MB

  // UI Constants
  static const int typingIndicatorDuration = 3000;
  static const int messageAnimationDuration = 300;

  // ========== Pagination Constants ==========

  /// Default page size for message loading
  static const int defaultPageSize = 50;

  /// Maximum messages to keep in memory at once
  static const int maxMessagesInMemory = 150;

  /// Scroll threshold (in pixels) from top to trigger load more
  static const double loadMoreThreshold = 200.0;

  /// Scroll threshold (in pixels) from bottom to show jump button
  static const double jumpToBottomThreshold = 300.0;

  /// Estimated average message height for scroll position calculations
  static const double estimatedMessageHeight = 80.0;

  /// Auto-save debounce delay in milliseconds
  static const int autoSaveDebounceMs = 500;

  // ========== Storage Constants ==========

  /// Session timeout in minutes (matches web widget)
  static const int sessionTimeoutMinutes = 30;

  /// Storage box name for sessions
  static const String sessionStorageBox = 'conferbot_sessions';

  /// Storage box name for messages
  static const String messageStorageBox = 'conferbot_messages';

  /// Storage key prefix for message data
  static const String messageKeyPrefix = 'conferbot_messages_';

  /// Maximum stored sessions to keep
  static const int maxStoredSessions = 10;
}
