import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_session.dart';

/// API response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? message;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.message,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic)? dataParser) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: dataParser != null && json['data'] != null ? dataParser(json['data']) : null,
      error: json['error'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// API client for REST endpoints
class ApiClient {
  final String apiKey;
  final String botId;
  final String baseUrl;
  final http.Client _client;

  ApiClient({
    required this.apiKey,
    required this.botId,
    this.baseUrl = ConferBotConstants.defaultApiBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        ConferBotConstants.headerApiKey: apiKey,
        ConferBotConstants.headerBotId: botId,
        ConferBotConstants.headerPlatform: ConferBotConstants.platformIdentifier,
        'Content-Type': 'application/json',
      };

  /// Initialize a new chat session
  Future<ApiResponse<ChatSession>> initSession({String? userId}) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/session/init'),
            headers: _headers,
            body: jsonEncode({
              'botId': botId,
              if (userId != null) 'userId': userId,
              'platform': ConferBotConstants.platformIdentifier,
            }),
          )
          .timeout(Duration(milliseconds: ConferBotConstants.apiTimeout));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(
          success: true,
          data: ChatSession.fromJson(jsonData['data'] as Map<String, dynamic>),
        );
      } else {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(
          success: false,
          error: jsonData['error'] as String? ?? 'Failed to initialize session',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get session history
  Future<ApiResponse<List<dynamic>>> getSessionHistory(String chatSessionId) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/session/$chatSessionId'),
            headers: _headers,
          )
          .timeout(Duration(milliseconds: ConferBotConstants.apiTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final recordData = jsonData['data']['record'] as List;
        return ApiResponse(
          success: true,
          data: recordData,
        );
      } else {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(
          success: false,
          error: jsonData['error'] as String? ?? 'Failed to get session history',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Send a message
  Future<ApiResponse<dynamic>> sendMessage({
    required String chatSessionId,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/session/$chatSessionId/message'),
            headers: _headers,
            body: jsonEncode({
              'message': message,
              if (metadata != null) 'metadata': metadata,
            }),
          )
          .timeout(Duration(milliseconds: ConferBotConstants.apiTimeout));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(
          success: true,
          data: jsonData['data'],
        );
      } else {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(
          success: false,
          error: jsonData['error'] as String? ?? 'Failed to send message',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Register push notification token
  Future<ApiResponse<void>> registerPushToken({
    required String token,
    required String chatSessionId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/push/register'),
            headers: _headers,
            body: jsonEncode({
              'token': token,
              'chatSessionId': chatSessionId,
              'platform': ConferBotConstants.platformIdentifier,
            }),
          )
          .timeout(Duration(milliseconds: ConferBotConstants.apiTimeout));

      if (response.statusCode == 200) {
        return const ApiResponse(success: true);
      } else {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(
          success: false,
          error: jsonData['error'] as String? ?? 'Failed to register push token',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: e.toString(),
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
