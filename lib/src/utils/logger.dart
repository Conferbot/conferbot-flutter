import 'package:flutter/foundation.dart';

/// Log level enumeration for controlling output verbosity
enum LogLevel {
  /// Debug level - verbose logging for development
  debug,

  /// Info level - general informational messages
  info,

  /// Warning level - potential issues
  warning,

  /// Error level - errors and exceptions
  error,
}

/// Centralized logger for the ConferBot SDK.
///
/// This logger:
/// - Only outputs in debug mode (using kDebugMode)
/// - Supports configurable log levels
/// - Can be configured via ConferBotConfig
/// - Never logs sensitive data (tokens, passwords, etc.)
/// - Uses debugPrint for proper output handling
///
/// Usage:
/// ```dart
/// ConferBotLogger.debug('Connecting to socket...');
/// ConferBotLogger.info('Session started', sessionId);
/// ConferBotLogger.warning('Connection unstable');
/// ConferBotLogger.error('Failed to connect', e, stackTrace);
/// ```
class ConferBotLogger {
  /// Private constructor - utility class
  ConferBotLogger._();

  /// Minimum log level for output.
  /// In release mode, defaults to warning. In debug mode, defaults to debug.
  /// Can be configured via [configure].
  static LogLevel minLevel = kReleaseMode ? LogLevel.warning : LogLevel.debug;

  /// Whether logging is enabled globally.
  /// Can be disabled via [configure] or by SDK configuration.
  static bool _enabled = true;

  /// Tag prefix for log messages
  static const String _tag = 'ConferBot';

  /// List of patterns to redact from log messages (security)
  static final List<RegExp> _redactPatterns = [
    RegExp('api[_-]?key["\\s:=]+["\']?[\\w-]+["\']?', caseSensitive: false),
    RegExp('token["\\s:=]+["\']?[\\w.-]+["\']?', caseSensitive: false),
    RegExp('password["\\s:=]+["\']?[^\\s"\']+["\']?', caseSensitive: false),
    RegExp('secret["\\s:=]+["\']?[\\w-]+["\']?', caseSensitive: false),
    RegExp('authorization["\\s:=]+["\']?[\\w.-]+["\']?', caseSensitive: false),
  ];

  // ========== Configuration ==========

  /// Configure the logger settings.
  ///
  /// [enabled] - Whether logging is enabled
  /// [level] - Minimum log level to output
  static void configure({
    bool? enabled,
    LogLevel? level,
  }) {
    if (enabled != null) {
      _enabled = enabled;
    }
    if (level != null) {
      minLevel = level;
    }
  }

  /// Enable logging
  static void enable() {
    _enabled = true;
  }

  /// Disable logging (for production or testing)
  static void disable() {
    _enabled = false;
  }

  /// Check if a log level would be output
  static bool wouldLog(LogLevel level) {
    return _enabled && kDebugMode && level.index >= minLevel.index;
  }

  // ========== Logging Methods ==========

  /// Log a debug message.
  /// Only outputs in debug mode when minLevel is debug.
  ///
  /// [message] - The message to log
  /// [data] - Optional additional data to include
  /// [tag] - Optional custom tag (defaults to 'ConferBot')
  static void debug(String message, [dynamic data, String? tag]) {
    _log(LogLevel.debug, message, data, tag: tag);
  }

  /// Log an info message.
  /// Outputs when minLevel is info or lower.
  ///
  /// [message] - The message to log
  /// [data] - Optional additional data to include
  /// [tag] - Optional custom tag (defaults to 'ConferBot')
  static void info(String message, [dynamic data, String? tag]) {
    _log(LogLevel.info, message, data, tag: tag);
  }

  /// Log a warning message.
  /// Outputs when minLevel is warning or lower.
  ///
  /// [message] - The message to log
  /// [data] - Optional additional data to include
  /// [tag] - Optional custom tag (defaults to 'ConferBot')
  static void warning(String message, [dynamic data, String? tag]) {
    _log(LogLevel.warning, message, data, tag: tag);
  }

  /// Log an error message.
  /// Always outputs when logging is enabled in debug mode.
  ///
  /// [message] - The error message
  /// [error] - Optional error object
  /// [stackTrace] - Optional stack trace
  /// [tag] - Optional custom tag (defaults to 'ConferBot')
  static void error(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    _log(LogLevel.error, message, error, stackTrace: stackTrace, tag: tag);
  }

  // ========== Internal Implementation ==========

  /// Internal log method that handles all logging logic.
  static void _log(
    LogLevel level,
    String message,
    dynamic data, {
    StackTrace? stackTrace,
    String? tag,
  }) {
    // Skip if not enabled or not in debug mode
    if (!_enabled) return;
    if (!kDebugMode) return;

    // Skip if below minimum level
    if (level.index < minLevel.index) return;

    // Format the log message
    final effectiveTag = tag ?? _tag;
    final levelStr = _levelToString(level);
    final timestamp = _formatTimestamp(DateTime.now());

    // Build message parts
    final buffer = StringBuffer();
    buffer.write('[$effectiveTag][$levelStr][$timestamp] ');
    buffer.write(_sanitizeMessage(message));

    // Add data if provided
    if (data != null) {
      buffer.write(' | ');
      buffer.write(_sanitizeMessage(data.toString()));
    }

    // Use debugPrint for proper handling in Flutter
    debugPrint(buffer.toString());

    // Print stack trace separately for errors
    if (stackTrace != null && level == LogLevel.error) {
      debugPrint('[$effectiveTag][STACK] $stackTrace');
    }
  }

  /// Convert log level to string representation
  static String _levelToString(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  /// Format timestamp for log output
  static String _formatTimestamp(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }

  /// Sanitize message by redacting sensitive information
  static String _sanitizeMessage(String message) {
    var sanitized = message;
    for (final pattern in _redactPatterns) {
      sanitized = sanitized.replaceAll(pattern, '[REDACTED]');
    }
    return sanitized;
  }

  // ========== Scoped Loggers ==========

  /// Create a scoped logger with a specific tag.
  /// Useful for subsystems that want their own log prefix.
  ///
  /// Example:
  /// ```dart
  /// final socketLogger = ConferBotLogger.scoped('Socket');
  /// socketLogger.debug('Connecting...'); // [ConferBot Socket][DEBUG]...
  /// ```
  static ScopedLogger scoped(String scope) {
    return ScopedLogger(scope);
  }
}

/// Scoped logger for subsystem-specific logging.
/// Automatically prefixes all messages with the scope name.
class ScopedLogger {
  final String _scope;

  /// Create a scoped logger with the given scope name
  const ScopedLogger(this._scope);

  /// Full tag including scope
  String get _tag => '$_scope';

  /// Log a debug message
  void debug(String message, [dynamic data]) {
    ConferBotLogger.debug(message, data, _tag);
  }

  /// Log an info message
  void info(String message, [dynamic data]) {
    ConferBotLogger.info(message, data, _tag);
  }

  /// Log a warning message
  void warning(String message, [dynamic data]) {
    ConferBotLogger.warning(message, data, _tag);
  }

  /// Log an error message
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    ConferBotLogger.error(message, error, stackTrace, _tag);
  }

  /// Check if debug level would be logged
  bool get wouldLogDebug => ConferBotLogger.wouldLog(LogLevel.debug);

  /// Check if info level would be logged
  bool get wouldLogInfo => ConferBotLogger.wouldLog(LogLevel.info);
}

// ========== Pre-defined Scoped Loggers ==========

/// Logger for socket-related operations
final socketLogger = ConferBotLogger.scoped('Socket');

/// Logger for API client operations
final apiLogger = ConferBotLogger.scoped('API');

/// Logger for storage operations
final storageLogger = ConferBotLogger.scoped('Storage');

/// Logger for analytics operations
final analyticsLogger = ConferBotLogger.scoped('Analytics');

/// Logger for node flow engine
final flowLogger = ConferBotLogger.scoped('Flow');

/// Logger for chat state operations
final chatStateLogger = ConferBotLogger.scoped('ChatState');

/// Logger for pagination operations
final paginationLogger = ConferBotLogger.scoped('Pagination');

/// Logger for connectivity operations
final connectivityLogger = ConferBotLogger.scoped('Connectivity');

/// Logger for message queue operations
final queueLogger = ConferBotLogger.scoped('Queue');

/// Logger for knowledge base operations
final kbLogger = ConferBotLogger.scoped('KnowledgeBase');

/// Logger for voice operations
final voiceLogger = ConferBotLogger.scoped('Voice');

/// Logger for error handling
final errorLogger = ConferBotLogger.scoped('Error');
