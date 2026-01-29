/// Webhook integration handler
///
/// Handles HTTP requests to external APIs for the webhook-node type.
/// Supports all HTTP methods, custom headers, authentication, and body payloads.
library;

import 'dart:convert';
import 'dart:io';

import '../../node_types.dart';
import '../legacy_handlers.dart';
import '../../../state/chat_state.dart';

/// Handler for webhook-node
/// Makes HTTP requests to external APIs
class WebhookNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.webhook;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final url = getString(nodeData, 'url', '');
    final method = getString(nodeData, 'method', 'POST').toUpperCase();
    final headers = getMap(nodeData, 'headers');
    final body = nodeData['body'];
    final includeAnswerVariables = getBoolean(nodeData, 'includeAnswerVariables', false);
    final answerVariable = nodeData['answerVariable']?.toString();

    if (url.isEmpty) {
      return const Proceed(); // Skip if no URL
    }

    // Handle authentication if provided
    final auth = getMap(nodeData, 'authentication');
    String? authToken;
    if (auth.isNotEmpty) {
      final tokenUrl = auth['tokenUrl']?.toString() ?? '';
      final username = auth['username']?.toString() ?? '';
      final password = auth['password']?.toString() ?? '';

      if (tokenUrl.isNotEmpty && username.isNotEmpty) {
        authToken = await _authenticateAndGetToken(tokenUrl, username, password);
      }
    }

    try {
      // Build request body with answer variables if requested
      final requestBody = _buildRequestBody(body, includeAnswerVariables);

      // Make the request
      final response = await _makeHttpRequest(url, method, headers, authToken, requestBody);

      // Store response if answer variable specified
      if (answerVariable != null && answerVariable.isNotEmpty && response != null) {
        state?.setAnswerVariable(nodeId, response);
      }
    } catch (e) {
      // Log error but continue flow
      recordResponse(
        nodeId: nodeId,
        shape: 'webhook-error',
        text: e.toString(),
        type: nodeType,
      );
    }

    return const Proceed();
  }

  Future<String?> _authenticateAndGetToken(
    String tokenUrl,
    String username,
    String password,
  ) async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(tokenUrl));
      request.headers.contentType = ContentType.json;

      final authBody = jsonEncode({
        'username': username,
        'password': password,
      });
      request.write(authBody);

      final response = await request.close();
      if (response.statusCode == HttpStatus.ok) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        return json['access']?.toString() ?? json['token']?.toString();
      }
      client.close();
      return null;
    } catch (e) {
      return null;
    }
  }

  String? _buildRequestBody(dynamic body, bool includeAnswerVariables) {
    Map<String, dynamic> json;

    if (body is String) {
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } catch (e) {
        json = {'data': body};
      }
    } else if (body is Map) {
      json = Map<String, dynamic>.from(body);
    } else {
      json = {};
    }

    // Include answer variables from ChatState if requested
    if (includeAnswerVariables) {
      final chatState = ChatState();
      json['answerVariables'] = chatState.getAnswerVariablesMap();
      json['userMetadata'] = chatState.userMetadata.toJson();
    }

    return jsonEncode(json);
  }

  Future<String?> _makeHttpRequest(
    String url,
    String method,
    Map<String, dynamic> headers,
    String? authToken,
    String? body,
  ) async {
    final client = HttpClient();
    final uri = Uri.parse(url);
    HttpClientRequest request;

    switch (method) {
      case 'GET':
        request = await client.getUrl(uri);
        break;
      case 'POST':
        request = await client.postUrl(uri);
        break;
      case 'PUT':
        request = await client.putUrl(uri);
        break;
      case 'PATCH':
        request = await client.patchUrl(uri);
        break;
      case 'DELETE':
        request = await client.deleteUrl(uri);
        break;
      default:
        request = await client.postUrl(uri);
    }

    request.headers.contentType = ContentType.json;

    // Add custom headers
    headers.forEach((key, value) {
      request.headers.add(key, value?.toString() ?? '');
    });

    // Add auth token if present
    if (authToken != null) {
      request.headers.add('Authorization', 'Bearer $authToken');
    }

    // Write body for POST/PUT/PATCH
    if (body != null && ['POST', 'PUT', 'PATCH'].contains(method)) {
      request.write(body);
    }

    final response = await request.close();
    client.close();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return await response.transform(utf8.decoder).join();
    }
    return null;
  }
}
