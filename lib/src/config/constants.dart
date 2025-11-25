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
}
