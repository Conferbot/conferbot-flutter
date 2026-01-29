/// Comprehensive exception types for the Conferbot Flutter SDK.
/// These exceptions provide typed error handling with error codes,
/// user-friendly messages, and debugging information.

// ============================================
// BASE EXCEPTION
// ============================================

/// Base exception class for all ConferBot exceptions.
/// Provides a consistent interface for error handling across the SDK.
abstract class ConferBotException implements Exception {
  /// Human-readable error message
  String get message;

  /// Unique error code for debugging and logging
  String get code;

  /// The original error that caused this exception, if any
  dynamic get originalError;

  /// Stack trace from the original error, if available
  StackTrace? get originalStackTrace;

  /// Whether this error is potentially recoverable through retry
  bool get isRetryable;

  /// Suggested user-friendly message to display in UI
  String get userMessage;

  @override
  String toString() => 'ConferBotException[$code]: $message';
}

// ============================================
// NETWORK EXCEPTIONS
// ============================================

/// Exception for general network-related errors (HTTP, connectivity).
class NetworkException extends ConferBotException {
  @override
  final String message;

  @override
  final String code;

  @override
  final dynamic originalError;

  @override
  final StackTrace? originalStackTrace;

  /// HTTP status code if applicable
  final int? statusCode;

  /// Response body if available
  final String? responseBody;

  /// Request URL that failed
  final String? requestUrl;

  /// HTTP method used
  final String? httpMethod;

  NetworkException({
    required this.message,
    this.code = 'NETWORK_ERROR',
    this.originalError,
    this.originalStackTrace,
    this.statusCode,
    this.responseBody,
    this.requestUrl,
    this.httpMethod,
  });

  @override
  bool get isRetryable {
    // 5xx errors and timeout errors are generally retryable
    if (statusCode != null) {
      return statusCode! >= 500 && statusCode! < 600;
    }
    // Connection errors are also retryable
    return true;
  }

  @override
  String get userMessage {
    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          return 'The request was invalid. Please try again.';
        case 401:
          return 'Authentication failed. Please check your credentials.';
        case 403:
          return 'You do not have permission to access this resource.';
        case 404:
          return 'The requested resource was not found.';
        case 408:
          return 'The request timed out. Please check your connection.';
        case 429:
          return 'Too many requests. Please wait a moment and try again.';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'Server is temporarily unavailable. Please try again later.';
        default:
          return 'A network error occurred. Please check your connection.';
      }
    }
    return 'Unable to connect. Please check your internet connection.';
  }

  /// Creates a NetworkException from an HTTP status code
  factory NetworkException.fromStatusCode(
    int statusCode, {
    String? responseBody,
    String? requestUrl,
    String? httpMethod,
  }) {
    String message;
    String code;

    switch (statusCode) {
      case 400:
        message = 'Bad request';
        code = 'HTTP_BAD_REQUEST';
        break;
      case 401:
        message = 'Unauthorized';
        code = 'HTTP_UNAUTHORIZED';
        break;
      case 403:
        message = 'Forbidden';
        code = 'HTTP_FORBIDDEN';
        break;
      case 404:
        message = 'Not found';
        code = 'HTTP_NOT_FOUND';
        break;
      case 408:
        message = 'Request timeout';
        code = 'HTTP_TIMEOUT';
        break;
      case 429:
        message = 'Too many requests';
        code = 'HTTP_RATE_LIMITED';
        break;
      case 500:
        message = 'Internal server error';
        code = 'HTTP_SERVER_ERROR';
        break;
      case 502:
        message = 'Bad gateway';
        code = 'HTTP_BAD_GATEWAY';
        break;
      case 503:
        message = 'Service unavailable';
        code = 'HTTP_SERVICE_UNAVAILABLE';
        break;
      case 504:
        message = 'Gateway timeout';
        code = 'HTTP_GATEWAY_TIMEOUT';
        break;
      default:
        message = 'HTTP error $statusCode';
        code = 'HTTP_ERROR_$statusCode';
    }

    return NetworkException(
      message: message,
      code: code,
      statusCode: statusCode,
      responseBody: responseBody,
      requestUrl: requestUrl,
      httpMethod: httpMethod,
    );
  }

  /// Creates a NetworkException for connection timeout
  factory NetworkException.timeout({
    String? requestUrl,
    String? httpMethod,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return NetworkException(
      message: 'Connection timed out',
      code: 'NETWORK_TIMEOUT',
      requestUrl: requestUrl,
      httpMethod: httpMethod,
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a NetworkException for no internet connection
  factory NetworkException.noConnection({
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return NetworkException(
      message: 'No internet connection',
      code: 'NETWORK_NO_CONNECTION',
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  @override
  String toString() =>
      'NetworkException[$code]: $message (status: $statusCode, url: $requestUrl)';
}

// ============================================
// SOCKET EXCEPTIONS
// ============================================

/// Exception for WebSocket/Socket.IO related errors.
class SocketException extends ConferBotException {
  @override
  final String message;

  @override
  final String code;

  @override
  final dynamic originalError;

  @override
  final StackTrace? originalStackTrace;

  /// Socket event that caused the error
  final String? event;

  /// Number of reconnection attempts made
  final int? reconnectionAttempts;

  /// Maximum reconnection attempts allowed
  final int? maxReconnectionAttempts;

  SocketException({
    required this.message,
    this.code = 'SOCKET_ERROR',
    this.originalError,
    this.originalStackTrace,
    this.event,
    this.reconnectionAttempts,
    this.maxReconnectionAttempts,
  });

  @override
  bool get isRetryable => true; // Socket connections are generally retryable

  @override
  String get userMessage {
    switch (code) {
      case 'SOCKET_CONNECTION_FAILED':
        return 'Unable to establish real-time connection. Retrying...';
      case 'SOCKET_DISCONNECTED':
        return 'Connection lost. Attempting to reconnect...';
      case 'SOCKET_RECONNECTION_FAILED':
        return 'Could not reconnect. Please check your connection.';
      case 'SOCKET_AUTHENTICATION_FAILED':
        return 'Connection authentication failed. Please try again.';
      case 'SOCKET_TIMEOUT':
        return 'Connection timed out. Please try again.';
      default:
        return 'Real-time connection error. Please try again.';
    }
  }

  /// Creates a SocketException for connection failure
  factory SocketException.connectionFailed({
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return SocketException(
      message: 'Failed to connect to socket server',
      code: 'SOCKET_CONNECTION_FAILED',
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a SocketException for disconnection
  factory SocketException.disconnected({
    String? reason,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return SocketException(
      message: reason ?? 'Disconnected from socket server',
      code: 'SOCKET_DISCONNECTED',
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a SocketException for reconnection failure
  factory SocketException.reconnectionFailed({
    int? attempts,
    int? maxAttempts,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return SocketException(
      message: 'Failed to reconnect after $attempts attempts',
      code: 'SOCKET_RECONNECTION_FAILED',
      reconnectionAttempts: attempts,
      maxReconnectionAttempts: maxAttempts,
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a SocketException for authentication failure
  factory SocketException.authenticationFailed({
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return SocketException(
      message: 'Socket authentication failed',
      code: 'SOCKET_AUTHENTICATION_FAILED',
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a SocketException for timeout
  factory SocketException.timeout({
    String? event,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return SocketException(
      message: 'Socket operation timed out',
      code: 'SOCKET_TIMEOUT',
      event: event,
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a SocketException for emit failure
  factory SocketException.emitFailed({
    required String event,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return SocketException(
      message: 'Failed to emit event: $event',
      code: 'SOCKET_EMIT_FAILED',
      event: event,
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  @override
  String toString() =>
      'SocketException[$code]: $message (event: $event, attempts: $reconnectionAttempts/$maxReconnectionAttempts)';
}

// ============================================
// VALIDATION EXCEPTIONS
// ============================================

/// Exception for input validation errors.
class ValidationException extends ConferBotException {
  @override
  final String message;

  @override
  final String code;

  @override
  final dynamic originalError;

  @override
  final StackTrace? originalStackTrace;

  /// Name of the field that failed validation
  final String? fieldName;

  /// The invalid value that was provided
  final dynamic invalidValue;

  /// Expected format or constraints
  final String? expectedFormat;

  /// List of validation errors for multiple fields
  final Map<String, String>? fieldErrors;

  ValidationException({
    required this.message,
    this.code = 'VALIDATION_ERROR',
    this.originalError,
    this.originalStackTrace,
    this.fieldName,
    this.invalidValue,
    this.expectedFormat,
    this.fieldErrors,
  });

  @override
  bool get isRetryable =>
      false; // User must correct the input, not auto-retryable

  @override
  String get userMessage {
    if (fieldName != null) {
      return 'Invalid $fieldName. $message';
    }
    return message;
  }

  /// Creates a ValidationException for required field
  factory ValidationException.required(String fieldName) {
    return ValidationException(
      message: '$fieldName is required',
      code: 'VALIDATION_REQUIRED',
      fieldName: fieldName,
    );
  }

  /// Creates a ValidationException for invalid email
  factory ValidationException.invalidEmail(String? email) {
    return ValidationException(
      message: 'Please enter a valid email address',
      code: 'VALIDATION_INVALID_EMAIL',
      fieldName: 'email',
      invalidValue: email,
      expectedFormat: 'example@domain.com',
    );
  }

  /// Creates a ValidationException for invalid phone number
  factory ValidationException.invalidPhone(String? phone) {
    return ValidationException(
      message: 'Please enter a valid phone number',
      code: 'VALIDATION_INVALID_PHONE',
      fieldName: 'phone number',
      invalidValue: phone,
      expectedFormat: '6-15 digits',
    );
  }

  /// Creates a ValidationException for invalid URL
  factory ValidationException.invalidUrl(String? url) {
    return ValidationException(
      message: 'Please enter a valid URL',
      code: 'VALIDATION_INVALID_URL',
      fieldName: 'URL',
      invalidValue: url,
      expectedFormat: 'https://example.com',
    );
  }

  /// Creates a ValidationException for value out of range
  factory ValidationException.outOfRange({
    required String fieldName,
    required dynamic value,
    dynamic min,
    dynamic max,
  }) {
    String message;
    if (min != null && max != null) {
      message = 'Value must be between $min and $max';
    } else if (min != null) {
      message = 'Value must be at least $min';
    } else if (max != null) {
      message = 'Value must be at most $max';
    } else {
      message = 'Value is out of range';
    }

    return ValidationException(
      message: message,
      code: 'VALIDATION_OUT_OF_RANGE',
      fieldName: fieldName,
      invalidValue: value,
    );
  }

  /// Creates a ValidationException for invalid length
  factory ValidationException.invalidLength({
    required String fieldName,
    required int length,
    int? minLength,
    int? maxLength,
  }) {
    String message;
    if (minLength != null && maxLength != null) {
      message = 'Must be between $minLength and $maxLength characters';
    } else if (minLength != null) {
      message = 'Must be at least $minLength characters';
    } else if (maxLength != null) {
      message = 'Must be at most $maxLength characters';
    } else {
      message = 'Invalid length';
    }

    return ValidationException(
      message: message,
      code: 'VALIDATION_INVALID_LENGTH',
      fieldName: fieldName,
      invalidValue: length,
    );
  }

  /// Creates a ValidationException for multiple field errors
  factory ValidationException.multipleErrors(Map<String, String> fieldErrors) {
    return ValidationException(
      message: 'Multiple validation errors occurred',
      code: 'VALIDATION_MULTIPLE_ERRORS',
      fieldErrors: fieldErrors,
    );
  }

  @override
  String toString() =>
      'ValidationException[$code]: $message (field: $fieldName, value: $invalidValue)';
}

// ============================================
// NODE PROCESSING EXCEPTIONS
// ============================================

/// Exception for chatbot node processing errors.
class NodeProcessingException extends ConferBotException {
  @override
  final String message;

  @override
  final String code;

  @override
  final dynamic originalError;

  @override
  final StackTrace? originalStackTrace;

  /// ID of the node that failed
  final String? nodeId;

  /// Type of the node that failed
  final String? nodeType;

  /// The node data that caused the error
  final Map<String, dynamic>? nodeData;

  /// Phase of processing where error occurred
  final String? processingPhase;

  NodeProcessingException({
    required this.message,
    this.code = 'NODE_PROCESSING_ERROR',
    this.originalError,
    this.originalStackTrace,
    this.nodeId,
    this.nodeType,
    this.nodeData,
    this.processingPhase,
  });

  @override
  bool get isRetryable {
    // Some node processing errors might be retryable (e.g., API calls)
    return code == 'NODE_API_CALL_FAILED' || code == 'NODE_TIMEOUT';
  }

  @override
  String get userMessage {
    switch (code) {
      case 'NODE_NOT_FOUND':
        return 'An error occurred in the conversation flow. Skipping to next step.';
      case 'NODE_HANDLER_NOT_FOUND':
        return 'This feature is not supported. Continuing...';
      case 'NODE_INVALID_DATA':
        return 'Invalid conversation data. Please try again.';
      case 'NODE_API_CALL_FAILED':
        return 'Could not complete the action. Please try again.';
      case 'NODE_TIMEOUT':
        return 'The operation timed out. Please try again.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  /// Creates a NodeProcessingException for handler not found
  factory NodeProcessingException.handlerNotFound(String nodeType) {
    return NodeProcessingException(
      message: 'No handler registered for node type: $nodeType',
      code: 'NODE_HANDLER_NOT_FOUND',
      nodeType: nodeType,
    );
  }

  /// Creates a NodeProcessingException for invalid node data
  factory NodeProcessingException.invalidData({
    required String nodeId,
    required String nodeType,
    String? details,
    Map<String, dynamic>? nodeData,
  }) {
    return NodeProcessingException(
      message: details ?? 'Invalid node data',
      code: 'NODE_INVALID_DATA',
      nodeId: nodeId,
      nodeType: nodeType,
      nodeData: nodeData,
    );
  }

  /// Creates a NodeProcessingException for processing failure
  factory NodeProcessingException.processingFailed({
    required String nodeId,
    required String nodeType,
    String? phase,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return NodeProcessingException(
      message: 'Failed to process node',
      code: 'NODE_PROCESSING_FAILED',
      nodeId: nodeId,
      nodeType: nodeType,
      processingPhase: phase,
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a NodeProcessingException for API call failure within a node
  factory NodeProcessingException.apiCallFailed({
    required String nodeId,
    required String nodeType,
    String? endpoint,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return NodeProcessingException(
      message: 'API call failed during node processing',
      code: 'NODE_API_CALL_FAILED',
      nodeId: nodeId,
      nodeType: nodeType,
      processingPhase: 'api_call',
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a NodeProcessingException for node not found
  factory NodeProcessingException.notFound(String nodeId) {
    return NodeProcessingException(
      message: 'Node not found: $nodeId',
      code: 'NODE_NOT_FOUND',
      nodeId: nodeId,
    );
  }

  @override
  String toString() =>
      'NodeProcessingException[$code]: $message (nodeId: $nodeId, type: $nodeType, phase: $processingPhase)';
}

// ============================================
// STORAGE EXCEPTIONS
// ============================================

/// Exception for local storage errors.
class StorageException extends ConferBotException {
  @override
  final String message;

  @override
  final String code;

  @override
  final dynamic originalError;

  @override
  final StackTrace? originalStackTrace;

  /// Key that was being accessed
  final String? key;

  /// Operation being performed (read, write, delete)
  final String? operation;

  StorageException({
    required this.message,
    this.code = 'STORAGE_ERROR',
    this.originalError,
    this.originalStackTrace,
    this.key,
    this.operation,
  });

  @override
  bool get isRetryable =>
      false; // Storage errors are usually not auto-retryable

  @override
  String get userMessage {
    switch (code) {
      case 'STORAGE_READ_FAILED':
        return 'Could not load saved data.';
      case 'STORAGE_WRITE_FAILED':
        return 'Could not save data. Please try again.';
      case 'STORAGE_DELETE_FAILED':
        return 'Could not clear saved data.';
      case 'STORAGE_QUOTA_EXCEEDED':
        return 'Storage is full. Please free up some space.';
      default:
        return 'A storage error occurred.';
    }
  }

  /// Creates a StorageException for read failure
  factory StorageException.readFailed({
    required String key,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return StorageException(
      message: 'Failed to read from storage',
      code: 'STORAGE_READ_FAILED',
      key: key,
      operation: 'read',
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a StorageException for write failure
  factory StorageException.writeFailed({
    required String key,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return StorageException(
      message: 'Failed to write to storage',
      code: 'STORAGE_WRITE_FAILED',
      key: key,
      operation: 'write',
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a StorageException for delete failure
  factory StorageException.deleteFailed({
    required String key,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return StorageException(
      message: 'Failed to delete from storage',
      code: 'STORAGE_DELETE_FAILED',
      key: key,
      operation: 'delete',
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a StorageException for quota exceeded
  factory StorageException.quotaExceeded({
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return StorageException(
      message: 'Storage quota exceeded',
      code: 'STORAGE_QUOTA_EXCEEDED',
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  @override
  String toString() =>
      'StorageException[$code]: $message (key: $key, operation: $operation)';
}

// ============================================
// PERMISSION EXCEPTIONS
// ============================================

/// Exception for permission-related errors.
class PermissionException extends ConferBotException {
  @override
  final String message;

  @override
  final String code;

  @override
  final dynamic originalError;

  @override
  final StackTrace? originalStackTrace;

  /// The permission that was denied
  final String? permission;

  /// Whether the permission can be requested again
  final bool canRequestAgain;

  PermissionException({
    required this.message,
    this.code = 'PERMISSION_ERROR',
    this.originalError,
    this.originalStackTrace,
    this.permission,
    this.canRequestAgain = true,
  });

  @override
  bool get isRetryable =>
      canRequestAgain; // Can retry if permission can be requested

  @override
  String get userMessage {
    switch (permission) {
      case 'camera':
        return 'Camera access is required for this feature. Please enable it in settings.';
      case 'microphone':
        return 'Microphone access is required for this feature. Please enable it in settings.';
      case 'location':
        return 'Location access is required for this feature. Please enable it in settings.';
      case 'storage':
        return 'Storage access is required for this feature. Please enable it in settings.';
      case 'photos':
        return 'Photo library access is required for this feature. Please enable it in settings.';
      case 'notifications':
        return 'Notification permission is required for this feature. Please enable it in settings.';
      default:
        return 'Permission is required for this feature. Please enable it in settings.';
    }
  }

  /// Creates a PermissionException for denied permission
  factory PermissionException.denied({
    required String permission,
    bool canRequestAgain = true,
  }) {
    return PermissionException(
      message: '$permission permission denied',
      code: 'PERMISSION_DENIED',
      permission: permission,
      canRequestAgain: canRequestAgain,
    );
  }

  /// Creates a PermissionException for permanently denied permission
  factory PermissionException.permanentlyDenied({
    required String permission,
  }) {
    return PermissionException(
      message: '$permission permission permanently denied',
      code: 'PERMISSION_PERMANENTLY_DENIED',
      permission: permission,
      canRequestAgain: false,
    );
  }

  /// Creates a PermissionException for restricted permission (e.g., parental controls)
  factory PermissionException.restricted({
    required String permission,
  }) {
    return PermissionException(
      message: '$permission permission restricted',
      code: 'PERMISSION_RESTRICTED',
      permission: permission,
      canRequestAgain: false,
    );
  }

  @override
  String toString() =>
      'PermissionException[$code]: $message (permission: $permission, canRequestAgain: $canRequestAgain)';
}

// ============================================
// INITIALIZATION EXCEPTIONS
// ============================================

/// Exception for SDK initialization errors.
class InitializationException extends ConferBotException {
  @override
  final String message;

  @override
  final String code;

  @override
  final dynamic originalError;

  @override
  final StackTrace? originalStackTrace;

  /// Component that failed to initialize
  final String? component;

  InitializationException({
    required this.message,
    this.code = 'INITIALIZATION_ERROR',
    this.originalError,
    this.originalStackTrace,
    this.component,
  });

  @override
  bool get isRetryable => true; // Initialization can usually be retried

  @override
  String get userMessage {
    switch (code) {
      case 'INIT_INVALID_API_KEY':
        return 'Invalid API key. Please check your configuration.';
      case 'INIT_INVALID_BOT_ID':
        return 'Invalid bot ID. Please check your configuration.';
      case 'INIT_NETWORK_FAILED':
        return 'Could not connect to server. Please check your connection.';
      case 'INIT_BOT_NOT_FOUND':
        return 'Chatbot not found. Please check your configuration.';
      case 'INIT_BOT_DISABLED':
        return 'This chatbot is currently disabled.';
      default:
        return 'Failed to initialize chat. Please try again.';
    }
  }

  /// Creates an InitializationException for invalid API key
  factory InitializationException.invalidApiKey() {
    return InitializationException(
      message: 'Invalid or missing API key',
      code: 'INIT_INVALID_API_KEY',
      component: 'authentication',
    );
  }

  /// Creates an InitializationException for invalid bot ID
  factory InitializationException.invalidBotId() {
    return InitializationException(
      message: 'Invalid or missing bot ID',
      code: 'INIT_INVALID_BOT_ID',
      component: 'configuration',
    );
  }

  /// Creates an InitializationException for bot not found
  factory InitializationException.botNotFound(String botId) {
    return InitializationException(
      message: 'Bot not found: $botId',
      code: 'INIT_BOT_NOT_FOUND',
      component: 'bot',
    );
  }

  /// Creates an InitializationException for disabled bot
  factory InitializationException.botDisabled(String botId) {
    return InitializationException(
      message: 'Bot is disabled: $botId',
      code: 'INIT_BOT_DISABLED',
      component: 'bot',
    );
  }

  /// Creates an InitializationException for network failure during init
  factory InitializationException.networkFailed({
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return InitializationException(
      message: 'Network error during initialization',
      code: 'INIT_NETWORK_FAILED',
      component: 'network',
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  @override
  String toString() =>
      'InitializationException[$code]: $message (component: $component)';
}

// ============================================
// SESSION EXCEPTIONS
// ============================================

/// Exception for chat session errors.
class SessionException extends ConferBotException {
  @override
  final String message;

  @override
  final String code;

  @override
  final dynamic originalError;

  @override
  final StackTrace? originalStackTrace;

  /// Session ID if available
  final String? sessionId;

  SessionException({
    required this.message,
    this.code = 'SESSION_ERROR',
    this.originalError,
    this.originalStackTrace,
    this.sessionId,
  });

  @override
  bool get isRetryable {
    return code == 'SESSION_CREATE_FAILED' || code == 'SESSION_RESTORE_FAILED';
  }

  @override
  String get userMessage {
    switch (code) {
      case 'SESSION_CREATE_FAILED':
        return 'Could not start a new conversation. Please try again.';
      case 'SESSION_NOT_FOUND':
        return 'Conversation not found. Starting a new one.';
      case 'SESSION_EXPIRED':
        return 'Your session has expired. Starting a new conversation.';
      case 'SESSION_RESTORE_FAILED':
        return 'Could not restore your conversation. Starting fresh.';
      default:
        return 'A session error occurred. Please try again.';
    }
  }

  /// Creates a SessionException for session creation failure
  factory SessionException.createFailed({
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return SessionException(
      message: 'Failed to create chat session',
      code: 'SESSION_CREATE_FAILED',
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a SessionException for session not found
  factory SessionException.notFound(String sessionId) {
    return SessionException(
      message: 'Session not found',
      code: 'SESSION_NOT_FOUND',
      sessionId: sessionId,
    );
  }

  /// Creates a SessionException for expired session
  factory SessionException.expired(String sessionId) {
    return SessionException(
      message: 'Session has expired',
      code: 'SESSION_EXPIRED',
      sessionId: sessionId,
    );
  }

  /// Creates a SessionException for restore failure
  factory SessionException.restoreFailed({
    String? sessionId,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return SessionException(
      message: 'Failed to restore session',
      code: 'SESSION_RESTORE_FAILED',
      sessionId: sessionId,
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  @override
  String toString() =>
      'SessionException[$code]: $message (sessionId: $sessionId)';
}

// ============================================
// FILE UPLOAD EXCEPTIONS
// ============================================

/// Exception for file upload errors.
class FileUploadException extends ConferBotException {
  @override
  final String message;

  @override
  final String code;

  @override
  final dynamic originalError;

  @override
  final StackTrace? originalStackTrace;

  /// Name of the file
  final String? fileName;

  /// Size of the file in bytes
  final int? fileSize;

  /// Maximum allowed size in bytes
  final int? maxSize;

  /// File type/extension
  final String? fileType;

  /// Allowed file types
  final List<String>? allowedTypes;

  FileUploadException({
    required this.message,
    this.code = 'FILE_UPLOAD_ERROR',
    this.originalError,
    this.originalStackTrace,
    this.fileName,
    this.fileSize,
    this.maxSize,
    this.fileType,
    this.allowedTypes,
  });

  @override
  bool get isRetryable {
    // Only network-related upload failures are retryable
    return code == 'FILE_UPLOAD_FAILED' || code == 'FILE_UPLOAD_TIMEOUT';
  }

  @override
  String get userMessage {
    switch (code) {
      case 'FILE_TOO_LARGE':
        final maxMB = (maxSize ?? 0) / (1024 * 1024);
        return 'File is too large. Maximum size is ${maxMB.toStringAsFixed(0)}MB.';
      case 'FILE_TYPE_NOT_ALLOWED':
        return 'This file type is not allowed. Allowed: ${allowedTypes?.join(", ") ?? "unknown"}.';
      case 'FILE_UPLOAD_FAILED':
        return 'Failed to upload file. Please try again.';
      case 'FILE_UPLOAD_TIMEOUT':
        return 'Upload timed out. Please try again with a smaller file.';
      case 'FILE_NOT_FOUND':
        return 'File not found. Please select a different file.';
      default:
        return 'An error occurred while uploading the file.';
    }
  }

  /// Creates a FileUploadException for file too large
  factory FileUploadException.tooLarge({
    required String fileName,
    required int fileSize,
    required int maxSize,
  }) {
    return FileUploadException(
      message: 'File exceeds maximum size',
      code: 'FILE_TOO_LARGE',
      fileName: fileName,
      fileSize: fileSize,
      maxSize: maxSize,
    );
  }

  /// Creates a FileUploadException for invalid file type
  factory FileUploadException.typeNotAllowed({
    required String fileName,
    required String fileType,
    required List<String> allowedTypes,
  }) {
    return FileUploadException(
      message: 'File type not allowed',
      code: 'FILE_TYPE_NOT_ALLOWED',
      fileName: fileName,
      fileType: fileType,
      allowedTypes: allowedTypes,
    );
  }

  /// Creates a FileUploadException for upload failure
  factory FileUploadException.uploadFailed({
    String? fileName,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return FileUploadException(
      message: 'Failed to upload file',
      code: 'FILE_UPLOAD_FAILED',
      fileName: fileName,
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  /// Creates a FileUploadException for upload timeout
  factory FileUploadException.timeout({
    String? fileName,
    dynamic originalError,
    StackTrace? originalStackTrace,
  }) {
    return FileUploadException(
      message: 'File upload timed out',
      code: 'FILE_UPLOAD_TIMEOUT',
      fileName: fileName,
      originalError: originalError,
      originalStackTrace: originalStackTrace,
    );
  }

  @override
  String toString() =>
      'FileUploadException[$code]: $message (file: $fileName, size: $fileSize, maxSize: $maxSize, type: $fileType)';
}
