/// Integration handlers barrel export
///
/// This file exports all integration handlers for easy importing.
/// Use this single import to access all integration handlers:
///
/// ```dart
/// import 'integrations/integrations.dart';
/// ```
library;

export 'webhook_handler.dart';
export 'gpt_handler.dart';
export 'google_handlers.dart';
export 'crm_handlers.dart';
export 'communication_handlers.dart';
export 'other_handlers.dart';

import '../legacy_handlers.dart' show NodeHandler;
import 'webhook_handler.dart';
import 'gpt_handler.dart';
import 'google_handlers.dart';
import 'crm_handlers.dart';
import 'communication_handlers.dart';
import 'other_handlers.dart';

/// Factory function to get all integration node handlers
///
/// Returns a list of all 17 integration handlers:
/// - WebhookNodeHandler (HTTP requests)
/// - GptNodeHandler (OpenAI integration)
/// - EmailNodeHandler (SMTP email)
/// - ZapierNodeHandler (automation)
/// - GoogleSheetsNodeHandler (spreadsheets)
/// - GmailNodeHandler (Google email)
/// - GoogleCalendarNodeHandler (appointments)
/// - GoogleMeetNodeHandler (video meetings)
/// - GoogleDriveNodeHandler (file storage)
/// - GoogleDocsNodeHandler (documents)
/// - SlackNodeHandler (messaging)
/// - DiscordNodeHandler (messaging)
/// - AirtableNodeHandler (database)
/// - HubspotNodeHandler (CRM)
/// - NotionNodeHandler (workspace)
/// - ZohoCrmNodeHandler (CRM)
/// - StripeNodeHandler (payments)
List<NodeHandler> getIntegrationNodeHandlers() {
  return [
    // Webhook/API
    WebhookNodeHandler(),

    // AI
    GptNodeHandler(),

    // Communication
    EmailNodeHandler(),
    SlackNodeHandler(),
    DiscordNodeHandler(),

    // Google Services
    GoogleSheetsNodeHandler(),
    GmailNodeHandler(),
    GoogleCalendarNodeHandler(),
    GoogleMeetNodeHandler(),
    GoogleDriveNodeHandler(),
    GoogleDocsNodeHandler(),

    // CRM
    HubspotNodeHandler(),
    ZohoCrmNodeHandler(),

    // Other Services
    ZapierNodeHandler(),
    AirtableNodeHandler(),
    NotionNodeHandler(),
    StripeNodeHandler(),
  ];
}
