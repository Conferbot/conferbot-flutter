import 'dart:async';
import 'dart:io' show SocketException as DartSocketException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'conferbot_exceptions.dart';
import '../../utils/logger.dart';

/// Callback type for user-facing error messages
typedef ErrorMessageCallback = void Function(String message);

/// Callback type for logging errors
typedef ErrorLogCallback = void Function(
  ConferBotException error,
  StackTrace? stackTrace,
);

/// Callback type for retry actions
typedef RetryCallback = Future<void> Function();

// ============================================
// ERROR HANDLER
// ============================================

/// Centralized error handler for the ConferBot SDK.
/// Provides utilities for handling, transforming, and displaying errors.
class ErrorHandler {
  /// Private constructor - this is a utility class
  ErrorHandler._();

  /// Default error log callback
  static ErrorLogCallback? _defaultLogCallback;

  /// Set the default log callback for all errors
  static void setDefaultLogCallback(ErrorLogCallback? callback) {
    _defaultLogCallback = callback;
  }

  // ========== Main Error Handling Methods ==========

  /// Handle a ConferBotException with callbacks for user message and logging.
  ///
  /// [error] The exception to handle
  /// [onUserMessage] Callback to display user-friendly message
  /// [onLog] Optional callback for logging (uses default if not provided)
  /// [shouldRetry] Whether to include retry information in the callback
  /// [onRetry] Callback to invoke when user requests retry
  static void handle(
    ConferBotException error, {
    required ErrorMessageCallback onUserMessage,
    ErrorLogCallback? onLog,
    bool shouldRetry = false,
    RetryCallback? onRetry,
  }) {
    // Log the error
    final logCallback = onLog ?? _defaultLogCallback;
    if (logCallback != null) {
      logCallback(error, error.originalStackTrace);
    }

    // Always log in debug mode
    if (kDebugMode) {
      _debugLog(error);
    }

    // Get user-friendly message
    final message = getUserFriendlyMessage(error);
    onUserMessage(message);
  }

  /// Handle any exception by converting it to a ConferBotException first.
  ///
  /// [error] Any error/exception
  /// [stackTrace] Optional stack trace
  /// [onUserMessage] Callback for user-friendly message
  /// [onLog] Optional logging callback
  /// [context] Optional context about where the error occurred
  static void handleAny(
    dynamic error, {
    StackTrace? stackTrace,
    required ErrorMessageCallback onUserMessage,
    ErrorLogCallback? onLog,
    String? context,
  }) {
    final conferBotError = fromException(error, stackTrace: stackTrace);
    handle(
      conferBotError,
      onUserMessage: onUserMessage,
      onLog: onLog,
    );
  }

  // ========== Error Transformation ==========

  /// Convert any exception to a ConferBotException.
  ///
  /// [error] The original error
  /// [stackTrace] Optional stack trace
  /// Returns appropriate ConferBotException subtype
  static ConferBotException fromException(
    dynamic error, {
    StackTrace? stackTrace,
  }) {
    // Already a ConferBotException
    if (error is ConferBotException) {
      return error;
    }

    // Dart SocketException (network connectivity)
    if (error is DartSocketException) {
      return NetworkException.noConnection(
        originalError: error,
        originalStackTrace: stackTrace,
      );
    }

    // HTTP Response errors
    if (error is http.Response) {
      return NetworkException.fromStatusCode(
        error.statusCode,
        responseBody: error.body,
      );
    }

    // TimeoutException
    if (error is TimeoutException) {
      return NetworkException.timeout(
        originalError: error,
        originalStackTrace: stackTrace,
      );
    }

    // FormatException (JSON parsing, etc.)
    if (error is FormatException) {
      return ValidationException(
        message: 'Invalid data format: ${error.message}',
        code: 'FORMAT_ERROR',
        originalError: error,
        originalStackTrace: stackTrace,
      );
    }

    // ArgumentError
    if (error is ArgumentError) {
      return ValidationException(
        message: error.message?.toString() ?? 'Invalid argument',
        code: 'ARGUMENT_ERROR',
        fieldName: error.name,
        invalidValue: error.invalidValue,
        originalError: error,
        originalStackTrace: stackTrace,
      );
    }

    // StateError
    if (error is StateError) {
      return NodeProcessingException(
        message: error.message,
        code: 'STATE_ERROR',
        originalError: error,
        originalStackTrace: stackTrace,
      );
    }

    // Generic exception - wrap in NetworkException as fallback
    if (error is Exception) {
      return NetworkException(
        message: error.toString(),
        code: 'UNKNOWN_ERROR',
        originalError: error,
        originalStackTrace: stackTrace,
      );
    }

    // Generic error
    return NetworkException(
      message: error?.toString() ?? 'Unknown error',
      code: 'UNKNOWN_ERROR',
      originalError: error,
      originalStackTrace: stackTrace,
    );
  }

  /// Create exception from HTTP response
  static ConferBotException fromHttpResponse(
    http.Response response, {
    String? requestUrl,
    String? httpMethod,
  }) {
    // Try to parse error message from response body
    String? errorMessage;
    try {
      if (response.body.isNotEmpty) {
        // Try to extract error from common response formats
        final body = response.body;
        if (body.contains('"error"')) {
          // Simple extraction without JSON parsing to avoid dependencies
          final match = RegExp(r'"error"\s*:\s*"([^"]*)"').firstMatch(body);
          if (match != null) {
            errorMessage = match.group(1);
          }
        } else if (body.contains('"message"')) {
          final match = RegExp(r'"message"\s*:\s*"([^"]*)"').firstMatch(body);
          if (match != null) {
            errorMessage = match.group(1);
          }
        }
      }
    } catch (_) {
      // Ignore parsing errors
    }

    final exception = NetworkException.fromStatusCode(
      response.statusCode,
      responseBody: response.body,
      requestUrl: requestUrl,
      httpMethod: httpMethod,
    );

    // Return exception with custom message if available
    if (errorMessage != null && errorMessage.isNotEmpty) {
      return NetworkException(
        message: errorMessage,
        code: exception.code,
        statusCode: response.statusCode,
        responseBody: response.body,
        requestUrl: requestUrl,
        httpMethod: httpMethod,
      );
    }

    return exception;
  }

  // ========== User Message Generation ==========

  /// Get a user-friendly message for any ConferBotException.
  ///
  /// [error] The exception
  /// Returns a message suitable for display to end users
  static String getUserFriendlyMessage(ConferBotException error) {
    return error.userMessage;
  }

  /// Get a detailed technical message for logging.
  ///
  /// [error] The exception
  /// Returns a detailed message for debugging
  static String getTechnicalMessage(ConferBotException error) {
    final buffer = StringBuffer();
    buffer.writeln('Error: ${error.code}');
    buffer.writeln('Message: ${error.message}');

    if (error is NetworkException) {
      if (error.statusCode != null) {
        buffer.writeln('Status Code: ${error.statusCode}');
      }
      if (error.requestUrl != null) {
        buffer.writeln('URL: ${error.requestUrl}');
      }
      if (error.httpMethod != null) {
        buffer.writeln('Method: ${error.httpMethod}');
      }
    } else if (error is SocketException) {
      if (error.event != null) {
        buffer.writeln('Event: ${error.event}');
      }
      if (error.reconnectionAttempts != null) {
        buffer.writeln(
          'Reconnection Attempts: ${error.reconnectionAttempts}/${error.maxReconnectionAttempts}',
        );
      }
    } else if (error is NodeProcessingException) {
      if (error.nodeId != null) {
        buffer.writeln('Node ID: ${error.nodeId}');
      }
      if (error.nodeType != null) {
        buffer.writeln('Node Type: ${error.nodeType}');
      }
      if (error.processingPhase != null) {
        buffer.writeln('Phase: ${error.processingPhase}');
      }
    } else if (error is ValidationException) {
      if (error.fieldName != null) {
        buffer.writeln('Field: ${error.fieldName}');
      }
      if (error.expectedFormat != null) {
        buffer.writeln('Expected: ${error.expectedFormat}');
      }
    }

    if (error.originalError != null) {
      buffer.writeln('Original Error: ${error.originalError}');
    }

    return buffer.toString();
  }

  // ========== Retry Logic ==========

  /// Check if an error is potentially recoverable through retry.
  ///
  /// [error] The exception to check
  /// Returns true if the error might be resolved by retrying
  static bool isRetryable(ConferBotException error) {
    return error.isRetryable;
  }

  /// Calculate delay for exponential backoff retry.
  ///
  /// [attempt] Current attempt number (1-based)
  /// [baseDelay] Base delay in milliseconds (default: 1000)
  /// [maxDelay] Maximum delay in milliseconds (default: 30000)
  /// [jitter] Whether to add random jitter (default: true)
  /// Returns delay duration
  static Duration calculateBackoffDelay({
    required int attempt,
    int baseDelay = 1000,
    int maxDelay = 30000,
    bool jitter = true,
  }) {
    // Exponential backoff: baseDelay * 2^(attempt-1)
    int delay = baseDelay * (1 << (attempt - 1).clamp(0, 10));

    // Apply maximum cap
    delay = delay.clamp(0, maxDelay);

    // Add jitter to prevent thundering herd
    if (jitter) {
      final jitterAmount = (delay * 0.1).round();
      delay += (DateTime.now().millisecond % jitterAmount) - (jitterAmount ~/ 2);
    }

    return Duration(milliseconds: delay.clamp(0, maxDelay));
  }

  /// Execute a function with automatic retry on failure.
  ///
  /// [action] The async function to execute
  /// [maxAttempts] Maximum number of retry attempts (default: 3)
  /// [shouldRetry] Optional function to determine if error should trigger retry
  /// [onRetry] Optional callback before each retry
  /// Returns the result of the action
  /// Throws the last error if all retries fail
  static Future<T> withRetry<T>({
    required Future<T> Function() action,
    int maxAttempts = 3,
    bool Function(ConferBotException)? shouldRetry,
    void Function(int attempt, ConferBotException error)? onRetry,
  }) async {
    ConferBotException? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e, stackTrace) {
        lastError = fromException(e, stackTrace: stackTrace);

        // Check if we should retry
        final canRetry = shouldRetry?.call(lastError) ?? isRetryable(lastError);

        if (!canRetry || attempt >= maxAttempts) {
          throw lastError;
        }

        // Notify about retry
        onRetry?.call(attempt, lastError);

        // Wait before retrying
        final delay = calculateBackoffDelay(attempt: attempt);
        await Future.delayed(delay);
      }
    }

    // This should never be reached, but just in case
    throw lastError ?? NetworkException(message: 'Unknown error', code: 'UNKNOWN');
  }

  // ========== Error Categorization ==========

  /// Get the severity level of an error.
  ///
  /// [error] The exception
  /// Returns severity level
  static ErrorSeverity getSeverity(ConferBotException error) {
    if (error is ValidationException) {
      return ErrorSeverity.warning;
    }

    if (error is NetworkException) {
      if (error.statusCode != null) {
        if (error.statusCode! >= 500) {
          return ErrorSeverity.error;
        }
        if (error.statusCode! >= 400) {
          return ErrorSeverity.warning;
        }
      }
      return ErrorSeverity.error;
    }

    if (error is SocketException) {
      if (error.code == 'SOCKET_DISCONNECTED') {
        return ErrorSeverity.warning;
      }
      return ErrorSeverity.error;
    }

    if (error is InitializationException) {
      return ErrorSeverity.critical;
    }

    if (error is PermissionException) {
      return ErrorSeverity.warning;
    }

    if (error is NodeProcessingException) {
      return ErrorSeverity.warning; // Usually recoverable
    }

    return ErrorSeverity.error;
  }

  /// Get suggested action for an error.
  ///
  /// [error] The exception
  /// Returns suggested ErrorAction
  static ErrorAction getSuggestedAction(ConferBotException error) {
    if (error.isRetryable) {
      return ErrorAction.retry;
    }

    if (error is ValidationException) {
      return ErrorAction.correctInput;
    }

    if (error is PermissionException) {
      return ErrorAction.openSettings;
    }

    if (error is InitializationException) {
      if (error.code == 'INIT_INVALID_API_KEY' ||
          error.code == 'INIT_INVALID_BOT_ID') {
        return ErrorAction.checkConfiguration;
      }
      return ErrorAction.retry;
    }

    if (error is SessionException && error.code == 'SESSION_EXPIRED') {
      return ErrorAction.startNewSession;
    }

    return ErrorAction.dismiss;
  }

  // ========== Debug Logging ==========

  static void _debugLog(ConferBotException error) {
    final message = getTechnicalMessage(error);
    errorLogger.error(message);

    if (error.originalStackTrace != null) {
      errorLogger.error('Stack trace:', error.originalStackTrace);
    }
  }
}

// ============================================
// ERROR SEVERITY
// ============================================

/// Severity levels for errors
enum ErrorSeverity {
  /// Informational - operation completed with minor issues
  info,

  /// Warning - something went wrong but can be recovered
  warning,

  /// Error - operation failed but app can continue
  error,

  /// Critical - major failure, app functionality compromised
  critical,
}

// ============================================
// ERROR ACTIONS
// ============================================

/// Suggested actions for error resolution
enum ErrorAction {
  /// Dismiss the error and continue
  dismiss,

  /// Retry the failed operation
  retry,

  /// User needs to correct their input
  correctInput,

  /// Open device/app settings
  openSettings,

  /// Check app configuration
  checkConfiguration,

  /// Start a new chat session
  startNewSession,

  /// Contact support
  contactSupport,
}

// ============================================
// ERROR RESULT
// ============================================

/// Result wrapper that can contain either success data or an error.
/// Useful for async operations that can fail.
class ErrorResult<T> {
  final T? data;
  final ConferBotException? error;

  const ErrorResult._({this.data, this.error});

  /// Create a success result with data
  factory ErrorResult.success(T data) => ErrorResult._(data: data);

  /// Create a failure result with error
  factory ErrorResult.failure(ConferBotException error) =>
      ErrorResult._(error: error);

  /// Whether this result is successful
  bool get isSuccess => error == null;

  /// Whether this result is a failure
  bool get isFailure => error != null;

  /// Get the data or throw the error
  T get dataOrThrow {
    if (error != null) throw error!;
    return data as T;
  }

  /// Get the data or a default value
  T dataOr(T defaultValue) => data ?? defaultValue;

  /// Map the success value
  ErrorResult<R> map<R>(R Function(T) mapper) {
    if (isSuccess) {
      return ErrorResult.success(mapper(data as T));
    }
    return ErrorResult.failure(error!);
  }

  /// Handle both success and failure cases
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(ConferBotException error) onFailure,
  }) {
    if (isSuccess) {
      return onSuccess(data as T);
    }
    return onFailure(error!);
  }
}

// ============================================
// ASYNC ERROR HELPERS
// ============================================

/// Extension methods for Future to add error handling
extension FutureErrorExtensions<T> on Future<T> {
  /// Convert Future to ErrorResult
  Future<ErrorResult<T>> toErrorResult() async {
    try {
      final result = await this;
      return ErrorResult.success(result);
    } catch (e, stackTrace) {
      final error = ErrorHandler.fromException(e, stackTrace: stackTrace);
      return ErrorResult.failure(error);
    }
  }

  /// Execute with automatic retry
  Future<T> withRetry({
    int maxAttempts = 3,
    bool Function(ConferBotException)? shouldRetry,
    void Function(int attempt, ConferBotException error)? onRetry,
  }) {
    return ErrorHandler.withRetry(
      action: () => this,
      maxAttempts: maxAttempts,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );
  }
}
