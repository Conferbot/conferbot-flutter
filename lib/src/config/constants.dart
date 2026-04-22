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


/// Configurable network settings for timeouts and retry policies.
///
/// Use [configure] to override default network behavior at SDK initialization.
/// Use [reset] to restore defaults (useful for testing).
class ConferBotNetworkConfig {
  static Duration _apiTimeout = const Duration(milliseconds: ConferBotConstants.apiTimeout);
  static Duration _socketTimeout = const Duration(milliseconds: ConferBotConstants.socketTimeout);
  static int _reconnectionAttempts = ConferBotConstants.socketReconnectionAttempts;
  static Duration _reconnectionDelay = const Duration(milliseconds: ConferBotConstants.socketReconnectionDelay);
  static Duration _reconnectionDelayMax = const Duration(milliseconds: ConferBotConstants.socketReconnectionDelayMax);

  static Duration get apiTimeout => _apiTimeout;
  static Duration get socketTimeout => _socketTimeout;
  static int get reconnectionAttempts => _reconnectionAttempts;
  static Duration get reconnectionDelay => _reconnectionDelay;
  static Duration get reconnectionDelayMax => _reconnectionDelayMax;

  /// Configure custom network settings.
  ///
  /// All durations must be positive. Reconnection attempts must be >= 0.
  static void configure({
    Duration? apiTimeout,
    Duration? socketTimeout,
    int? reconnectionAttempts,
    Duration? reconnectionDelay,
    Duration? reconnectionDelayMax,
  }) {
    if (apiTimeout != null) {
      assert(apiTimeout.inMilliseconds > 0, 'API timeout must be positive');
      _apiTimeout = apiTimeout;
    }
    if (socketTimeout != null) {
      assert(socketTimeout.inMilliseconds > 0, 'Socket timeout must be positive');
      _socketTimeout = socketTimeout;
    }
    if (reconnectionAttempts != null) {
      assert(reconnectionAttempts >= 0, 'Reconnection attempts must be >= 0');
      _reconnectionAttempts = reconnectionAttempts;
    }
    if (reconnectionDelay != null) {
      assert(reconnectionDelay.inMilliseconds > 0, 'Reconnection delay must be positive');
      _reconnectionDelay = reconnectionDelay;
    }
    if (reconnectionDelayMax != null) {
      assert(reconnectionDelayMax.inMilliseconds > 0, 'Reconnection delay max must be positive');
      _reconnectionDelayMax = reconnectionDelayMax;
    }
  }

  /// Reset all network settings to defaults.
  static void reset() {
    _apiTimeout = const Duration(milliseconds: ConferBotConstants.apiTimeout);
    _socketTimeout = const Duration(milliseconds: ConferBotConstants.socketTimeout);
    _reconnectionAttempts = ConferBotConstants.socketReconnectionAttempts;
    _reconnectionDelay = const Duration(milliseconds: ConferBotConstants.socketReconnectionDelay);
    _reconnectionDelayMax = const Duration(milliseconds: ConferBotConstants.socketReconnectionDelayMax);
  }
}

/// Configurable endpoint URLs with HTTPS enforcement.
///
/// Use [configure] to override the default URLs at SDK initialization.
/// All URLs must use HTTPS for security.
class ConferBotEndpoints {
  static String _apiBaseUrl = ConferBotConstants.defaultApiBaseUrl;
  static String _socketUrl = ConferBotConstants.defaultSocketUrl;

  /// Current API base URL
  static String get apiBaseUrl => _apiBaseUrl;

  /// Current socket URL
  static String get socketUrl => _socketUrl;

  /// Configure custom endpoint URLs.
  ///
  /// Both [apiBaseUrl] and [socketUrl] must use HTTPS if provided.
  /// Throws [AssertionError] in debug mode if HTTP is used.
  static void configure({String? apiBaseUrl, String? socketUrl}) {
    if (apiBaseUrl != null) {
      _apiBaseUrl = apiBaseUrl;
    }
    if (socketUrl != null) {
      _socketUrl = socketUrl;
    }
  }

  /// Reset endpoints to defaults (useful for testing)
  static void reset() {
    _apiBaseUrl = ConferBotConstants.defaultApiBaseUrl;
    _socketUrl = ConferBotConstants.defaultSocketUrl;
  }
}
