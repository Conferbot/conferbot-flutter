import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_session.dart';
import '../core/errors/conferbot_exceptions.dart';
import '../core/errors/error_handler.dart';

// ============================================
// API RESPONSE WRAPPER
// ============================================

/// API response wrapper with typed data and error handling
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? message;
  final ConferBotException? exception;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.message,
    this.exception,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? dataParser,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: dataParser != null && json['data'] != null
          ? dataParser(json['data'])
          : null,
      error: json['error'] as String?,
      message: json['message'] as String?,
    );
  }

  /// Create a success response
  factory ApiResponse.successWith(T data, {String? message}) {
    return ApiResponse<T>(
      success: true,
      data: data,
      message: message,
    );
  }

  /// Create a failure response from exception
  factory ApiResponse.failure(ConferBotException exception) {
    return ApiResponse<T>(
      success: false,
      error: exception.message,
      exception: exception,
    );
  }

  /// Check if response has a retryable error
  bool get isRetryable => exception?.isRetryable ?? false;

  /// Get user-friendly error message
  String get userMessage =>
      exception?.userMessage ?? error ?? 'An error occurred';
}

// ============================================
// API CLIENT CONFIGURATION
// ============================================

/// Configuration for API client behavior
class ApiClientConfig {
  /// Connection timeout in milliseconds
  final int connectionTimeout;

  /// Read timeout in milliseconds
  final int readTimeout;

  /// Maximum number of retry attempts for retryable errors
  final int maxRetries;

  /// Base delay for exponential backoff (milliseconds)
  final int retryBaseDelay;

  /// Maximum delay for exponential backoff (milliseconds)
  final int retryMaxDelay;

  /// Whether to automatically retry on 5xx errors
  final bool autoRetry5xx;

  /// Whether to automatically retry on timeout
  final bool autoRetryTimeout;

  const ApiClientConfig({
    this.connectionTimeout = ConferBotConstants.apiTimeout,
    this.readTimeout = ConferBotConstants.apiTimeout,
    this.maxRetries = 3,
    this.retryBaseDelay = 1000,
    this.retryMaxDelay = 30000,
    this.autoRetry5xx = true,
    this.autoRetryTimeout = true,
  });

  /// Create config from ConferBotNetworkConfig (uses runtime-configurable values)
  factory ApiClientConfig.fromNetworkConfig() {
    return ApiClientConfig(
      connectionTimeout: ConferBotNetworkConfig.apiTimeout.inMilliseconds,
      readTimeout: ConferBotNetworkConfig.apiTimeout.inMilliseconds,
    );
  }

  /// Default configuration
  static const ApiClientConfig defaultConfig = ApiClientConfig();
}

// ============================================
// API CLIENT
// ============================================

/// API client for REST endpoints with comprehensive error handling
class ApiClient {
  final String apiKey;
  final String botId;
  final String baseUrl;
  final ApiClientConfig config;
  final http.Client _client;

  /// Callback for error logging
  ErrorLogCallback? onError;

  /// Callback for request start (useful for showing loading states)
  void Function(String endpoint)? onRequestStart;

  /// Callback for request end
  void Function(String endpoint, bool success)? onRequestEnd;

  ApiClient({
    required this.apiKey,
    required this.botId,
    this.baseUrl = ConferBotConstants.defaultApiBaseUrl,
    this.config = ApiClientConfig.defaultConfig,
    http.Client? client,
    this.onError,
    this.onRequestStart,
    this.onRequestEnd,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        ConferBotConstants.headerApiKey: apiKey,
        ConferBotConstants.headerBotId: botId,
        ConferBotConstants.headerPlatform: ConferBotConstants.platformIdentifier,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ========== Session Management ==========

  /// Initialize a new chat session
  Future<ApiResponse<ChatSession>> initSession({String? userId}) async {
    return _executeWithRetry<ChatSession>(
      endpoint: '/session/init',
      method: 'POST',
      body: {
        'botId': botId,
        if (userId != null) 'userId': userId,
        'platform': ConferBotConstants.platformIdentifier,
      },
      parser: (data) => ChatSession.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Get session history
  Future<ApiResponse<List<dynamic>>> getSessionHistory(
    String chatSessionId,
  ) async {
    return _executeWithRetry<List<dynamic>>(
      endpoint: '/session/$chatSessionId',
      method: 'GET',
      parser: (data) {
        final recordData = (data as Map<String, dynamic>)['record'] as List;
        return recordData;
      },
    );
  }

  /// Send a message
  Future<ApiResponse<dynamic>> sendMessage({
    required String chatSessionId,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    return _executeWithRetry<dynamic>(
      endpoint: '/session/$chatSessionId/message',
      method: 'POST',
      body: {
        'message': message,
        if (metadata != null) 'metadata': metadata,
      },
      parser: (data) => data,
    );
  }

  /// Register push notification token
  Future<ApiResponse<void>> registerPushToken({
    required String token,
    required String chatSessionId,
  }) async {
    return _executeWithRetry<void>(
      endpoint: '/push/register',
      method: 'POST',
      body: {
        'token': token,
        'chatSessionId': chatSessionId,
        'platform': ConferBotConstants.platformIdentifier,
      },
      parser: (_) {},
    );
  }

  /// Upload file
  Future<ApiResponse<Map<String, dynamic>>> uploadFile({
    required String chatSessionId,
    required String filePath,
    required String fileName,
    String? mimeType,
  }) async {
    final endpoint = '/session/$chatSessionId/upload';
    final url = '$baseUrl$endpoint';

    onRequestStart?.call(endpoint);

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(_headers);
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
      ));

      final streamedResponse = await request.send().timeout(
            Duration(milliseconds: config.connectionTimeout * 2),
          );

      final response = await http.Response.fromStream(streamedResponse);

      onRequestEnd?.call(endpoint, response.statusCode < 400);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.successWith(
          jsonData['data'] as Map<String, dynamic>,
        );
      } else {
        final exception = ErrorHandler.fromHttpResponse(
          response,
          requestUrl: url,
          httpMethod: 'POST',
        );
        _logError(exception);
        return ApiResponse.failure(exception);
      }
    } on TimeoutException catch (e, stackTrace) {
      onRequestEnd?.call(endpoint, false);
      final exception = FileUploadException.timeout(
        fileName: fileName,
        originalError: e,
        originalStackTrace: stackTrace,
      );
      _logError(exception);
      return ApiResponse.failure(exception);
    } catch (e, stackTrace) {
      onRequestEnd?.call(endpoint, false);
      final exception = FileUploadException.uploadFailed(
        fileName: fileName,
        originalError: e,
        originalStackTrace: stackTrace,
      );
      _logError(exception);
      return ApiResponse.failure(exception);
    }
  }

  // ========== Internal Request Handling ==========

  /// Execute request with automatic retry for retryable errors
  Future<ApiResponse<T>> _executeWithRetry<T>({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    required T Function(dynamic) parser,
  }) async {
    ConferBotException? lastException;

    for (int attempt = 1; attempt <= config.maxRetries; attempt++) {
      final result = await _executeRequest<T>(
        endpoint: endpoint,
        method: method,
        body: body,
        parser: parser,
      );

      if (result.success) {
        return result;
      }

      lastException = result.exception;

      // Check if we should retry
      final shouldRetry = _shouldRetry(result.exception, attempt);
      if (!shouldRetry) {
        return result;
      }

      // Calculate backoff delay
      final delay = ErrorHandler.calculateBackoffDelay(
        attempt: attempt,
        baseDelay: config.retryBaseDelay,
        maxDelay: config.retryMaxDelay,
      );

      await Future.delayed(delay);
    }

    // All retries exhausted
    return ApiResponse.failure(
      lastException ?? NetworkException(message: 'Request failed', code: 'REQUEST_FAILED'),
    );
  }

  /// Check if request should be retried
  bool _shouldRetry(ConferBotException? exception, int attempt) {
    if (exception == null || attempt >= config.maxRetries) {
      return false;
    }

    if (exception is NetworkException) {
      // Retry on 5xx errors
      if (config.autoRetry5xx &&
          exception.statusCode != null &&
          exception.statusCode! >= 500) {
        return true;
      }

      // Retry on timeout
      if (config.autoRetryTimeout &&
          (exception.code == 'NETWORK_TIMEOUT' ||
              exception.code == 'HTTP_TIMEOUT' ||
              exception.code == 'HTTP_GATEWAY_TIMEOUT')) {
        return true;
      }

      // Retry on connection errors
      if (exception.code == 'NETWORK_NO_CONNECTION') {
        return true;
      }
    }

    return exception.isRetryable;
  }

  /// Execute a single HTTP request
  Future<ApiResponse<T>> _executeRequest<T>({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    required T Function(dynamic) parser,
  }) async {
    final url = '$baseUrl$endpoint';

    onRequestStart?.call(endpoint);

    try {
      final http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client
              .get(Uri.parse(url), headers: _headers)
              .timeout(Duration(milliseconds: config.connectionTimeout));
          break;
        case 'POST':
          response = await _client
              .post(
                Uri.parse(url),
                headers: _headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(Duration(milliseconds: config.connectionTimeout));
          break;
        case 'PUT':
          response = await _client
              .put(
                Uri.parse(url),
                headers: _headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(Duration(milliseconds: config.connectionTimeout));
          break;
        case 'DELETE':
          response = await _client
              .delete(Uri.parse(url), headers: _headers)
              .timeout(Duration(milliseconds: config.connectionTimeout));
          break;
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }

      onRequestEnd?.call(endpoint, response.statusCode < 400);

      return _parseResponse<T>(response, url, method, parser);
    } on TimeoutException catch (e, stackTrace) {
      onRequestEnd?.call(endpoint, false);
      final exception = NetworkException.timeout(
        requestUrl: url,
        httpMethod: method,
        originalError: e,
        originalStackTrace: stackTrace,
      );
      _logError(exception);
      return ApiResponse.failure(exception);
    } on SocketException catch (e, stackTrace) {
      onRequestEnd?.call(endpoint, false);
      final exception = NetworkException.noConnection(
        originalError: e,
        originalStackTrace: stackTrace,
      );
      _logError(exception);
      return ApiResponse.failure(exception);
    } on http.ClientException catch (e, stackTrace) {
      onRequestEnd?.call(endpoint, false);
      final exception = NetworkException(
        message: e.message,
        code: 'HTTP_CLIENT_ERROR',
        requestUrl: url,
        httpMethod: method,
        originalError: e,
        originalStackTrace: stackTrace,
      );
      _logError(exception);
      return ApiResponse.failure(exception);
    } on FormatException catch (e, stackTrace) {
      onRequestEnd?.call(endpoint, false);
      final exception = ValidationException(
        message: 'Invalid response format',
        code: 'INVALID_RESPONSE_FORMAT',
        originalError: e,
        originalStackTrace: stackTrace,
      );
      _logError(exception);
      return ApiResponse.failure(exception);
    } catch (e, stackTrace) {
      onRequestEnd?.call(endpoint, false);
      final exception = ErrorHandler.fromException(e, stackTrace: stackTrace);
      _logError(exception);
      return ApiResponse.failure(exception);
    }
  }

  /// Parse HTTP response to ApiResponse
  ApiResponse<T> _parseResponse<T>(
    http.Response response,
    String url,
    String method,
    T Function(dynamic) parser,
  ) {
    // Check for successful status codes
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        if (response.body.isEmpty) {
          // Some endpoints may return empty body for success
          return ApiResponse<T>(success: true);
        }

        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

        // Check for API-level success flag
        final apiSuccess = jsonData['success'] as bool? ?? true;
        if (!apiSuccess) {
          final errorMessage = jsonData['error'] as String? ??
              jsonData['message'] as String? ??
              'API error';
          return ApiResponse.failure(NetworkException(
            message: errorMessage,
            code: 'API_ERROR',
            statusCode: response.statusCode,
            responseBody: response.body,
            requestUrl: url,
            httpMethod: method,
          ));
        }

        // Parse data
        final data = jsonData['data'];
        return ApiResponse<T>(
          success: true,
          data: data != null ? parser(data) : null,
          message: jsonData['message'] as String?,
        );
      } on FormatException catch (e, stackTrace) {
        return ApiResponse.failure(ValidationException(
          message: 'Invalid JSON response',
          code: 'INVALID_JSON',
          originalError: e,
          originalStackTrace: stackTrace,
        ));
      } catch (e, stackTrace) {
        return ApiResponse.failure(NetworkException(
          message: 'Failed to parse response',
          code: 'PARSE_ERROR',
          responseBody: response.body,
          requestUrl: url,
          httpMethod: method,
          originalError: e,
          originalStackTrace: stackTrace,
        ));
      }
    }

    // Handle error status codes
    final exception = ErrorHandler.fromHttpResponse(
      response,
      requestUrl: url,
      httpMethod: method,
    );

    return ApiResponse.failure(exception);
  }

  /// Log error using callback
  void _logError(ConferBotException exception) {
    onError?.call(exception, exception.originalStackTrace);
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}
