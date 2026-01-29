import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/core/nodes/handlers/integration_handlers.dart';
import 'package:conferbot_flutter/src/core/nodes/node_result.dart';
import 'package:conferbot_flutter/src/core/nodes/node_types.dart';
import '../../mocks/mock_chat_state.dart';
import '../../fixtures/test_fixtures.dart';

void main() {
  late MockChatState mockState;

  setUp(() {
    mockState = MockChatState();
  });

  tearDown(() {
    mockState.reset();
  });

  group('WebhookNodeHandler', () {
    late WebhookNodeHandler handler;

    setUp(() {
      handler = WebhookNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.webhook);
    });

    test('should proceed when no URL is provided', () async {
      final nodeData = {
        'type': 'webhook-node',
        'url': '',
        'method': 'POST',
      };

      final result = await handler.process(nodeData, 'webhook_1');

      expect(result, isA<ProceedResult>());
    });

    test('should record response on error', () async {
      // Test with an invalid URL to trigger error handling
      final nodeData = TestFixtures.webhookNode(
        url: 'not-a-valid-url',
        method: 'POST',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'webhook_1');

      // Should proceed even on error
      expect(result, isA<ProceedResult>());
    });

    test('should handle different HTTP methods', () async {
      for (final method in ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
        final nodeData = {
          'type': 'webhook-node',
          'url': '',
          'method': method,
        };

        final result = await handler.process(nodeData, 'webhook_$method');
        expect(result, isA<ProceedResult>());
      }
    });
  });

  group('GptNodeHandler', () {
    late GptNodeHandler handler;

    setUp(() {
      handler = GptNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.gpt);
    });

    test('should proceed when no API key is provided', () async {
      final nodeData = {
        'type': 'gpt-node',
        'apiKey': '',
        'selectedModel': 'gpt-3.5-turbo',
      };

      final result = await handler.process(nodeData, 'gpt_1');

      expect(result, isA<ProceedResult>());
    });
  });

  group('EmailNodeHandler', () {
    late EmailNodeHandler handler;

    setUp(() {
      handler = EmailNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.email);
    });

    test('should proceed and record email trigger', () async {
      final nodeData = TestFixtures.emailNode(
        to: 'test@example.com',
        subject: 'Test Email',
      )['data'] as Map<String, dynamic>;

      final result = await handler.process(nodeData, 'email_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'email-triggered'), true);
    });
  });

  group('ZapierNodeHandler', () {
    late ZapierNodeHandler handler;

    setUp(() {
      handler = ZapierNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.zapier);
    });

    test('should proceed and record zapier trigger', () async {
      final nodeData = {
        'type': 'zapier-node',
        'webhookUrl': 'https://hooks.zapier.com/test',
      };

      final result = await handler.process(nodeData, 'zapier_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'zapier-triggered'), true);
    });
  });

  group('GoogleSheetsNodeHandler', () {
    late GoogleSheetsNodeHandler handler;

    setUp(() {
      handler = GoogleSheetsNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.googleSheets);
    });

    test('should proceed and record write operation', () async {
      final nodeData = {
        'type': 'google-sheets-node',
        'operation': 'write',
        'spreadsheetId': 'sheet123',
        'sheetName': 'Sheet1',
      };

      final result = await handler.process(nodeData, 'sheets_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'google-sheets-write'), true);
    });

    test('should proceed and record read operation', () async {
      final nodeData = {
        'type': 'google-sheets-node',
        'operation': 'read',
        'spreadsheetId': 'sheet123',
        'sheetName': 'Sheet1',
      };

      final result = await handler.process(nodeData, 'sheets_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'google-sheets-read'), true);
    });
  });

  group('GmailNodeHandler', () {
    late GmailNodeHandler handler;

    setUp(() {
      handler = GmailNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.gmail);
    });

    test('should proceed and record gmail trigger', () async {
      final nodeData = {
        'type': 'gmail-node',
        'to': 'test@example.com',
        'subject': 'Test Email',
      };

      final result = await handler.process(nodeData, 'gmail_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'gmail-triggered'), true);
    });
  });

  group('GoogleCalendarNodeHandler', () {
    late GoogleCalendarNodeHandler handler;

    setUp(() {
      handler = GoogleCalendarNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.googleCalendar);
    });

    test('should display calendar for book operation', () async {
      final nodeData = {
        'type': 'google-calendar-node',
        'operation': 'book',
        'timeZone': 'America/New_York',
        'answerVariable': 'booking',
      };

      final result = await handler.process(nodeData, 'gcal_1');

      expect(result, isA<DisplayUIResult>());
    });

    test('should handle booking response', () async {
      final nodeData = {
        'type': 'google-calendar-node',
        'operation': 'book',
        'timeZone': 'America/New_York',
        'answerVariable': 'booking',
      };

      await handler.process(nodeData, 'gcal_1');
      final result = await handler.handleResponse(
        {'date': '2024-01-15', 'time': '14:00'},
        nodeData,
        'gcal_1',
      );

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'google-calendar-booking'), true);
    });
  });

  group('GoogleMeetNodeHandler', () {
    late GoogleMeetNodeHandler handler;

    setUp(() {
      handler = GoogleMeetNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.googleMeet);
    });

    test('should display calendar for book operation', () async {
      final nodeData = {
        'type': 'google-meet-node',
        'operation': 'book',
        'timeZone': 'America/New_York',
        'answerVariable': 'meeting',
      };

      final result = await handler.process(nodeData, 'meet_1');

      expect(result, isA<DisplayUIResult>());
    });
  });

  group('GoogleDriveNodeHandler', () {
    late GoogleDriveNodeHandler handler;

    setUp(() {
      handler = GoogleDriveNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.googleDrive);
    });

    test('should proceed and record upload operation', () async {
      final nodeData = {
        'type': 'google-drive-node',
        'operation': 'upload',
      };

      final result = await handler.process(nodeData, 'drive_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'google-drive-upload'), true);
    });
  });

  group('GoogleDocsNodeHandler', () {
    late GoogleDocsNodeHandler handler;

    setUp(() {
      handler = GoogleDocsNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.googleDocs);
    });

    test('should proceed and record create operation', () async {
      final nodeData = {
        'type': 'google-docs-node',
        'operation': 'create',
        'title': 'New Document',
      };

      final result = await handler.process(nodeData, 'docs_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'google-docs-create'), true);
    });
  });

  group('SlackNodeHandler', () {
    late SlackNodeHandler handler;

    setUp(() {
      handler = SlackNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.slack);
    });

    test('should proceed and record slack message', () async {
      final nodeData = {
        'type': 'slack-node',
        'message': 'Test message',
        'channel': '#general',
      };

      final result = await handler.process(nodeData, 'slack_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'slack-message'), true);
    });
  });

  group('DiscordNodeHandler', () {
    late DiscordNodeHandler handler;

    setUp(() {
      handler = DiscordNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.discord);
    });

    test('should proceed and record discord message', () async {
      final nodeData = {
        'type': 'discord-node',
        'message': 'Test message',
        'channel': 'general',
      };

      final result = await handler.process(nodeData, 'discord_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'discord-message'), true);
    });
  });

  group('AirtableNodeHandler', () {
    late AirtableNodeHandler handler;

    setUp(() {
      handler = AirtableNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.airtable);
    });

    test('should proceed and record create operation', () async {
      final nodeData = {
        'type': 'airtable-node',
        'operation': 'create',
        'baseId': 'base123',
        'tableName': 'Table1',
      };

      final result = await handler.process(nodeData, 'airtable_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'airtable-create'), true);
    });
  });

  group('HubspotNodeHandler', () {
    late HubspotNodeHandler handler;

    setUp(() {
      handler = HubspotNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.hubspot);
    });

    test('should proceed and record createContact operation', () async {
      final nodeData = {
        'type': 'hubspot-node',
        'operation': 'createContact',
      };

      final result = await handler.process(nodeData, 'hubspot_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'hubspot-createContact'), true);
    });
  });

  group('NotionNodeHandler', () {
    late NotionNodeHandler handler;

    setUp(() {
      handler = NotionNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.notion);
    });

    test('should proceed and record createPage operation', () async {
      final nodeData = {
        'type': 'notion-node',
        'operation': 'createPage',
        'databaseId': 'db123',
      };

      final result = await handler.process(nodeData, 'notion_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'notion-createPage'), true);
    });
  });

  group('ZohoCrmNodeHandler', () {
    late ZohoCrmNodeHandler handler;

    setUp(() {
      handler = ZohoCrmNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.zohoCrm);
    });

    test('should proceed and record create operation', () async {
      final nodeData = {
        'type': 'zohocrm-node',
        'operation': 'create',
        'module': 'Contacts',
      };

      final result = await handler.process(nodeData, 'zoho_1');

      expect(result, isA<ProceedResult>());
      expect(mockState.recordEntries.any((e) => e.shape == 'zohocrm-create'), true);
    });
  });

  group('StripeNodeHandler', () {
    late StripeNodeHandler handler;

    setUp(() {
      handler = StripeNodeHandler();
      handler.state = mockState;
    });

    test('should have correct node type', () {
      expect(handler.nodeType, NodeTypes.stripe);
    });

    test('should display payment UI for createPaymentLink', () async {
      final nodeData = {
        'type': 'stripe-node',
        'operation': 'createPaymentLink',
        'customAmount': 99.99,
        'currency': 'USD',
        'description': 'Test payment',
      };

      final result = await handler.process(nodeData, 'stripe_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as PaymentState;
      expect(uiState.amount, 99.99);
      expect(uiState.currency, 'USD');
      expect(uiState.description, 'Test payment');
    });

    test('should display payment UI for createCheckoutSession', () async {
      final nodeData = {
        'type': 'stripe-node',
        'operation': 'createCheckoutSession',
        'customAmount': 50.0,
        'currency': 'EUR',
      };

      final result = await handler.process(nodeData, 'stripe_1');

      expect(result, isA<DisplayUIResult>());
    });

    test('should record stripe payment', () async {
      final nodeData = {
        'type': 'stripe-node',
        'operation': 'createPaymentLink',
        'customAmount': 99.99,
        'currency': 'USD',
      };

      await handler.process(nodeData, 'stripe_1');

      expect(mockState.recordEntries.any((e) => e.shape == 'stripe-payment'), true);
    });

    test('should parse string amount', () async {
      final nodeData = {
        'type': 'stripe-node',
        'operation': 'createPaymentLink',
        'customAmount': '49.99',
        'currency': 'USD',
      };

      final result = await handler.process(nodeData, 'stripe_1');

      expect(result, isA<DisplayUIResult>());
      final uiState = (result as DisplayUIResult).uiState as PaymentState;
      expect(uiState.amount, 49.99);
    });
  });

  group('IntegrationNodeHandlers Factory', () {
    test('should return all integration handlers', () {
      final handlers = getIntegrationNodeHandlers();

      expect(handlers.length, 17);
      expect(handlers.any((h) => h.nodeType == NodeTypes.webhook), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.gpt), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.email), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.zapier), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.googleSheets), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.gmail), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.googleCalendar), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.googleMeet), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.googleDrive), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.googleDocs), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.slack), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.discord), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.airtable), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.hubspot), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.notion), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.zohoCrm), true);
      expect(handlers.any((h) => h.nodeType == NodeTypes.stripe), true);
    });
  });
}
