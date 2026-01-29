/// Miscellaneous integration handlers
///
/// Handles integrations with various services:
/// - Zapier (automation webhook triggers)
/// - Airtable (database CRUD operations)
/// - Notion (page/database management)
/// - Stripe (payment processing)
library;

import '../../node_types.dart';
import '../../node_ui_state.dart';
import '../legacy_handlers.dart';

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
        PaymentUIState(
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
