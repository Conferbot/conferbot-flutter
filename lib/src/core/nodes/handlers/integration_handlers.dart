/// Integration handlers - barrel export for backward compatibility
///
/// This file re-exports all integration handlers from their split files
/// to maintain backward compatibility with existing imports.
///
/// For new code, prefer importing directly from:
/// - integrations/webhook_handler.dart
/// - integrations/gpt_handler.dart
/// - integrations/google_handlers.dart
/// - integrations/crm_handlers.dart
/// - integrations/communication_handlers.dart
/// - integrations/other_handlers.dart
///
/// Or use the consolidated barrel:
/// - integrations/integrations.dart
library;

// Re-export all integration handlers for backward compatibility
export 'integrations/integrations.dart';

// Import and re-export the factory function
import 'integrations/integrations.dart' as integrations;
import 'legacy_handlers.dart' show NodeHandler, NodeUIState;
import 'display_handlers.dart' show CalendarState;

// Re-export CalendarState for Google Calendar/Meet handlers
export 'display_handlers.dart' show CalendarState;

/// Payment/Stripe UI state (kept for backward compatibility)
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

/// Factory function to get all integration node handlers
///
/// Returns a list of all 17 integration handlers.
/// @see integrations/integrations.dart for the implementation
List<NodeHandler> getIntegrationNodeHandlers() {
  return integrations.getIntegrationNodeHandlers();
}
