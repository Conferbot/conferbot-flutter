import 'dart:convert';
import 'dart:io';

import '../node_types.dart';
import 'legacy_handlers.dart';
import 'display_handlers.dart';

// ============================================================================
// INTEGRATION UI STATES
// ============================================================================

/// Payment/Stripe UI state
class PaymentState extends NodeUIState {
  final String paymentUrl;
  final double? amount;
  final String? currency;
  final String? description;
  final String nodeId;

  const PaymentState({
    required this.paymentUrl,
    this.amount,
    this.currency,
    this.description,
    required this.nodeId,
  });
}

// ============================================================================
// INTEGRATION NODE HANDLERS (17 types)
// ============================================================================

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
      // Build request body
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

    // Note: includeAnswerVariables would need full ChatState access
    // For now, this is passed to server which has full context

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

/// Handler for gpt-node
/// Sends conversation context to OpenAI
class GptNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.gpt;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final apiKey = getString(nodeData, 'apiKey', '');
    final model = getString(nodeData, 'selectedModel', 'gpt-3.5-turbo');
    final context = nodeData['context']?.toString();

    if (apiKey.isEmpty) {
      return const Proceed(); // Skip if no API key
    }

    try {
      // Build messages - context as system message
      final messages = <Map<String, String>>[];

      // Add system context if provided
      if (context != null && context.isNotEmpty) {
        messages.add({'role': 'system', 'content': context});
      }

      // Note: Full transcript would need ChatState access
      // For mobile SDKs, GPT context is typically managed server-side

      // Call OpenAI API
      final response = await _callOpenAI(apiKey, model, messages);

      if (response != null) {
        // Add response to transcript
        state?.addToTranscript('bot', response);

        // Record the response
        recordResponse(
          nodeId: nodeId,
          shape: 'gpt-response',
          text: response,
          type: nodeType,
        );

        // Display the message
        return DisplayUI(
          MessageState(
            text: response,
            nodeId: nodeId,
          ),
        );
      }
    } catch (e) {
      recordResponse(
        nodeId: nodeId,
        shape: 'gpt-error',
        text: e.toString(),
        type: nodeType,
      );
    }

    return const Proceed();
  }

  Future<String?> _callOpenAI(
    String apiKey,
    String model,
    List<Map<String, String>> messages,
  ) async {
    final client = HttpClient();
    final request = await client.postUrl(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
    );

    request.headers.contentType = ContentType.json;
    request.headers.add('Authorization', 'Bearer $apiKey');

    final body = jsonEncode({
      'model': model,
      'messages': messages,
    });
    request.write(body);

    final response = await request.close();
    client.close();

    if (response.statusCode == HttpStatus.ok) {
      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>;
      if (choices.isNotEmpty) {
        final firstChoice = choices[0] as Map<String, dynamic>;
        final message = firstChoice['message'] as Map<String, dynamic>;
        return message['content'] as String;
      }
    }
    return null;
  }
}

/// Handler for email-node
/// Sends email (fire-and-forget via server)
class EmailNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.email;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    // Email is handled server-side via socket event
    // Just record and proceed
    recordResponse(
      nodeId: nodeId,
      shape: 'email-triggered',
      type: nodeType,
      additionalData: {
        'to': nodeData['to'],
        'subject': nodeData['subject'],
      },
    );

    return const Proceed();
  }
}

/// Handler for zapier-node
/// Triggers Zapier webhook (fire-and-forget)
class ZapierNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.zapier;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    // Zapier trigger is handled server-side
    recordResponse(
      nodeId: nodeId,
      shape: 'zapier-triggered',
      type: nodeType,
    );

    return const Proceed();
  }
}

/// Handler for google-sheets-node
/// Reads/writes to Google Sheets
class GoogleSheetsNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.googleSheets;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'write');

    recordResponse(
      nodeId: nodeId,
      shape: 'google-sheets-$operation',
      type: nodeType,
      additionalData: {
        'operation': operation,
        'spreadsheetId': nodeData['spreadsheetId'],
        'sheetName': nodeData['sheetName'],
      },
    );

    // For read operations, column mappings should be handled via socket response
    return const Proceed();
  }
}

/// Handler for gmail-node
/// Sends email via Gmail
class GmailNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.gmail;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    recordResponse(
      nodeId: nodeId,
      shape: 'gmail-triggered',
      type: nodeType,
      additionalData: {
        'to': nodeData['to'],
        'subject': nodeData['subject'],
      },
    );

    return const Proceed();
  }
}

/// Handler for google-calendar-node
/// Books calendar appointments
class GoogleCalendarNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.googleCalendar;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'book');

    if (operation == 'book') {
      // Display calendar booking UI
      final timezone = getString(nodeData, 'timeZone', DateTime.now().timeZoneName);
      final answerKey = getString(nodeData, 'answerVariable', 'calendar_booking');

      state?.addAnswerVariable(nodeId, answerKey);

      return DisplayUI(
        CalendarState(
          questionText: 'Select a date and time',
          showTimeSelection: true,
          timezone: timezone,
          nodeId: nodeId,
          answerKey: answerKey,
        ),
      );
    }

    return const Proceed();
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final responseMap = response is Map<String, dynamic>
        ? response
        : {'date': response.toString()};

    final date = responseMap['date']?.toString() ?? '';
    final time = responseMap['time']?.toString() ?? '';
    final email = responseMap['email']?.toString();

    state?.setAnswerVariable(nodeId, '$date $time');
    state?.addToTranscript('user', 'Booked: $date at $time');

    recordResponse(
      nodeId: nodeId,
      shape: 'google-calendar-booking',
      text: '$date $time',
      type: nodeType,
      additionalData: {
        'date': date,
        'time': time,
        'attendeeEmail': email,
        'timezone': nodeData['timeZone'],
      },
    );

    return const Proceed();
  }
}

/// Handler for google-meet-node
/// Creates Google Meet meetings
class GoogleMeetNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.googleMeet;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'book');

    if (operation == 'book') {
      final timezone = getString(nodeData, 'timeZone', DateTime.now().timeZoneName);
      final answerKey = getString(nodeData, 'answerVariable', 'meet_booking');

      state?.addAnswerVariable(nodeId, answerKey);

      return DisplayUI(
        CalendarState(
          questionText: 'Select a time for your meeting',
          showTimeSelection: true,
          timezone: timezone,
          nodeId: nodeId,
          answerKey: answerKey,
        ),
      );
    }

    return const Proceed();
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final responseMap = response is Map<String, dynamic>
        ? response
        : {'date': response.toString()};

    recordResponse(
      nodeId: nodeId,
      shape: 'google-meet-booking',
      type: nodeType,
      additionalData: Map<String, dynamic>.from(responseMap),
    );

    return const Proceed();
  }
}

/// Handler for google-drive-node
/// Uploads/downloads from Google Drive
class GoogleDriveNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.googleDrive;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'upload');

    recordResponse(
      nodeId: nodeId,
      shape: 'google-drive-$operation',
      type: nodeType,
      additionalData: {'operation': operation},
    );

    return const Proceed();
  }
}

/// Handler for google-docs-node
/// Creates/updates Google Docs
class GoogleDocsNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.googleDocs;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'create');

    recordResponse(
      nodeId: nodeId,
      shape: 'google-docs-$operation',
      type: nodeType,
      additionalData: {
        'operation': operation,
        'title': nodeData['title'],
      },
    );

    return const Proceed();
  }
}

/// Handler for slack-node
/// Sends messages to Slack
class SlackNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.slack;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    recordResponse(
      nodeId: nodeId,
      shape: 'slack-message',
      text: nodeData['message']?.toString(),
      type: nodeType,
      additionalData: {'channel': nodeData['channel']},
    );

    return const Proceed();
  }
}

/// Handler for discord-node
/// Sends messages to Discord
class DiscordNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.discord;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    recordResponse(
      nodeId: nodeId,
      shape: 'discord-message',
      text: nodeData['message']?.toString(),
      type: nodeType,
      additionalData: {'channel': nodeData['channel']},
    );

    return const Proceed();
  }
}

/// Handler for airtable-node
/// CRUD operations on Airtable
class AirtableNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.airtable;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'create');

    recordResponse(
      nodeId: nodeId,
      shape: 'airtable-$operation',
      type: nodeType,
      additionalData: {
        'baseId': nodeData['baseId'],
        'tableName': nodeData['tableName'],
        'operation': operation,
      },
    );

    return const Proceed();
  }
}

/// Handler for hubspot-node
/// Creates/updates HubSpot contacts
class HubspotNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.hubspot;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'createContact');

    recordResponse(
      nodeId: nodeId,
      shape: 'hubspot-$operation',
      type: nodeType,
      additionalData: {'operation': operation},
    );

    return const Proceed();
  }
}

/// Handler for notion-node
/// Creates/updates Notion pages
class NotionNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.notion;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'createPage');

    recordResponse(
      nodeId: nodeId,
      shape: 'notion-$operation',
      type: nodeType,
      additionalData: {
        'databaseId': nodeData['databaseId'],
        'operation': operation,
      },
    );

    return const Proceed();
  }
}

/// Handler for zohocrm-node
/// Creates/updates Zoho CRM records
class ZohoCrmNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.zohoCrm;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'create');
    final module = getString(nodeData, 'module', 'Contacts');

    recordResponse(
      nodeId: nodeId,
      shape: 'zohocrm-$operation',
      type: nodeType,
      additionalData: {
        'module': module,
        'operation': operation,
      },
    );

    return const Proceed();
  }
}

/// Handler for stripe-node
/// Creates payment links/sessions
class StripeNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.stripe;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'createPaymentLink');

    // For payment operations, display payment UI
    if (operation == 'createPaymentLink' || operation == 'createCheckoutSession') {
      final amount = nodeData['customAmount'];
      final currency = nodeData['currency']?.toString() ?? 'USD';
      final description = nodeData['description']?.toString();

      recordResponse(
        nodeId: nodeId,
        shape: 'stripe-payment',
        type: nodeType,
        additionalData: {
          'operation': operation,
          'amount': amount,
          'currency': currency,
        },
      );

      // Payment URL will be provided by server via socket
      // For now, return a placeholder UI
      return DisplayUI(
        PaymentState(
          paymentUrl: '', // Will be filled by server response
          amount: _parseAmount(amount),
          currency: currency,
          description: description,
          nodeId: nodeId,
        ),
      );
    }

    return const Proceed();
  }

  double? _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    if (amount is String) return double.tryParse(amount);
    return null;
  }
}

/// Factory function to get all integration node handlers
List<NodeHandler> getIntegrationNodeHandlers() {
  return [
    WebhookNodeHandler(),
    GptNodeHandler(),
    EmailNodeHandler(),
    ZapierNodeHandler(),
    GoogleSheetsNodeHandler(),
    GmailNodeHandler(),
    GoogleCalendarNodeHandler(),
    GoogleMeetNodeHandler(),
    GoogleDriveNodeHandler(),
    GoogleDocsNodeHandler(),
    SlackNodeHandler(),
    DiscordNodeHandler(),
    AirtableNodeHandler(),
    HubspotNodeHandler(),
    NotionNodeHandler(),
    ZohoCrmNodeHandler(),
    StripeNodeHandler(),
  ];
}
