import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:conferbot_flutter/src/services/api_client.dart';
import 'package:conferbot_flutter/src/config/constants.dart';

void main() {
  late ApiClient apiClient;

  group('ApiClient Construction', () {
    test('should create with required parameters', () {
      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
      );

      expect(apiClient.apiKey, 'test_api_key');
      expect(apiClient.botId, 'test_bot_id');
      expect(apiClient.baseUrl, ConferBotConstants.defaultApiBaseUrl);
    });

    test('should create with custom base URL', () {
      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        baseUrl: 'https://custom.api.com',
      );

      expect(apiClient.baseUrl, 'https://custom.api.com');
    });
  });

  group('ApiClient.initSession', () {
    test('should successfully initialize session', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/session/init'));
        expect(request.headers[ConferBotConstants.headerApiKey], 'test_api_key');
        expect(request.headers[ConferBotConstants.headerBotId], 'test_bot_id');
        expect(request.headers[ConferBotConstants.headerPlatform], ConferBotConstants.platformIdentifier);

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'chatSessionId': 'session_123',
              'visitorId': 'visitor_456',
              'record': [],
            },
          }),
          200,
        );
      });

      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await apiClient.initSession();

      expect(response.success, true);
      expect(response.data, isNotNull);
      expect(response.data!.chatSessionId, 'session_123');
      expect(response.data!.visitorId, 'visitor_456');
    });

    test('should handle session init with userId', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['userId'], 'user_123');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'chatSessionId': 'session_123',
              'visitorId': 'visitor_456',
              'record': [],
            },
          }),
          200,
        );
      });

      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await apiClient.initSession(userId: 'user_123');

      expect(response.success, true);
    });

    test('should handle session init failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'Invalid API key',
          }),
          401,
        );
      });

      apiClient = ApiClient(
        apiKey: 'invalid_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await apiClient.initSession();

      expect(response.success, false);
      expect(response.error, 'Invalid API key');
    });

    test('should handle network error', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network error');
      });

      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await apiClient.initSession();

      expect(response.success, false);
      expect(response.error, contains('Exception'));
    });
  });

  group('ApiClient.getSessionHistory', () {
    test('should successfully get session history', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, contains('/session/session_123'));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'record': [
                {'id': 'msg_1', 'shape': 'bot-message', 'text': 'Hello'},
                {'id': 'msg_2', 'shape': 'user-input', 'text': 'Hi'},
              ],
            },
          }),
          200,
        );
      });

      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await apiClient.getSessionHistory('session_123');

      expect(response.success, true);
      expect(response.data, isNotNull);
      expect(response.data!.length, 2);
    });

    test('should handle session not found', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'Session not found',
          }),
          404,
        );
      });

      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await apiClient.getSessionHistory('invalid_session');

      expect(response.success, false);
      expect(response.error, 'Session not found');
    });
  });

  group('ApiClient.sendMessage', () {
    test('should successfully send message', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/session/session_123/message'));

        final body = jsonDecode(request.body);
        expect(body['message'], 'Hello bot');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'msg_123',
              'status': 'sent',
            },
          }),
          200,
        );
      });

      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await apiClient.sendMessage(
        chatSessionId: 'session_123',
        message: 'Hello bot',
      );

      expect(response.success, true);
      expect(response.data, isNotNull);
    });

    test('should send message with metadata', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['message'], 'Hello');
        expect(body['metadata']['source'], 'flutter');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {},
          }),
          200,
        );
      });

      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await apiClient.sendMessage(
        chatSessionId: 'session_123',
        message: 'Hello',
        metadata: {'source': 'flutter'},
      );

      expect(response.success, true);
    });

    test('should handle send message failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'Rate limit exceeded',
          }),
          429,
        );
      });

      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await apiClient.sendMessage(
        chatSessionId: 'session_123',
        message: 'Hello',
      );

      expect(response.success, false);
      expect(response.error, 'Rate limit exceeded');
    });
  });

  group('ApiClient.registerPushToken', () {
    test('should successfully register push token', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/push/register'));

        final body = jsonDecode(request.body);
        expect(body['token'], 'fcm_token_123');
        expect(body['chatSessionId'], 'session_123');
        expect(body['platform'], ConferBotConstants.platformIdentifier);

        return http.Response(
          jsonEncode({
            'success': true,
          }),
          200,
        );
      });

      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await apiClient.registerPushToken(
        token: 'fcm_token_123',
        chatSessionId: 'session_123',
      );

      expect(response.success, true);
    });

    test('should handle push token registration failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'Invalid token',
          }),
          400,
        );
      });

      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      final response = await apiClient.registerPushToken(
        token: 'invalid_token',
        chatSessionId: 'session_123',
      );

      expect(response.success, false);
      expect(response.error, 'Invalid token');
    });
  });

  group('ApiResponse', () {
    test('should create from JSON with data parser', () {
      final json = {
        'success': true,
        'data': {'key': 'value'},
        'message': 'Success',
      };

      final response = ApiResponse<Map<String, dynamic>>.fromJson(
        json,
        (data) => data as Map<String, dynamic>,
      );

      expect(response.success, true);
      expect(response.data, {'key': 'value'});
      expect(response.message, 'Success');
    });

    test('should handle null data', () {
      final json = {
        'success': true,
        'data': null,
      };

      final response = ApiResponse<String>.fromJson(json, null);

      expect(response.success, true);
      expect(response.data, isNull);
    });

    test('should handle error response', () {
      final json = {
        'success': false,
        'error': 'Something went wrong',
      };

      final response = ApiResponse<String>.fromJson(json, null);

      expect(response.success, false);
      expect(response.error, 'Something went wrong');
    });
  });

  group('ApiClient.dispose', () {
    test('should dispose client', () {
      final mockClient = MockClient((request) async {
        return http.Response('', 200);
      });

      apiClient = ApiClient(
        apiKey: 'test_api_key',
        botId: 'test_bot_id',
        client: mockClient,
      );

      // Should not throw
      expect(() => apiClient.dispose(), returnsNormally);
    });
  });
}
