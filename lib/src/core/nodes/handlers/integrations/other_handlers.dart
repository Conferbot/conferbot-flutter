/// Miscellaneous integration handlers
///
/// Handles integrations with various services:
/// - Zapier (automation webhook triggers)
/// - Airtable (database CRUD operations)
/// - Notion (page/database management)
/// - Stripe (payment processing)
///
/// All handlers emit 'execute-integration' to the server via socket,
/// matching the web widget / Android SDK protocol.
library;

import 'dart:async';

import '../../node_types.dart';
import '../../node_ui_state.dart';
import '../legacy_handlers.dart';
import '../../../../models/socket_events.dart';
import '../../../../services/socket_client.dart';
import 'integration_base.dart';

/// Handler for zapier-node
/// Triggers Zapier webhook (fire-and-forget)
class ZapierNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.zapier;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    await emitExecuteIntegration(
      nodeData: nodeData,
      nodeId: nodeId,
      waitForResult: false,
    );

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
class AirtableNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.airtable;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'create');

    await emitExecuteIntegration(
      nodeData: nodeData,
      nodeId: nodeId,
    );

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
class NotionNodeHandler extends IntegrationNodeHandler {
  @override
  String get nodeType => NodeTypes.notion;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'createPage');

    await emitExecuteIntegration(
      nodeData: nodeData,
      nodeId: nodeId,
    );

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
///
/// Emits 'execute-integration' to the server via socket and listens for
/// 'integration-result' containing the Stripe payment URL, matching the
/// same protocol used by the web widget.
class StripeNodeHandler extends IntegrationNodeHandler {
  /// Static socket client reference, set by NodeFlowEngine during initialization.
  /// Kept for backward compatibility; also delegates to IntegrationNodeHandler.socketClient.
  static set socketClient(SocketClient? client) {
    IntegrationNodeHandler.socketClient = client;
  }

  @override
  String get nodeType => NodeTypes.stripe;

  @override
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final operation = getString(nodeData, 'operation', 'createPaymentLink');

    // For payment operations, request payment URL from server and display UI
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

      // Request payment URL from the server via socket
      String paymentUrl = '';
      final socket = IntegrationNodeHandler.socketClient;

      if (socket != null && socket.isConnected) {
        paymentUrl = await _requestPaymentUrl(
          socket: socket,
          nodeId: nodeId,
          nodeData: nodeData,
        );
      }

      return DisplayUI(
        PaymentUIState(
          paymentUrl: paymentUrl,
          amount: _parseAmount(amount),
          currency: currency,
          description: description,
          nodeId: nodeId,
        ),
      );
    }

    return const Proceed();
  }

  /// Emit 'execute-integration' and wait for the 'integration-result' response
  /// containing the payment URL from the server-side StripeHandler.
  Future<String> _requestPaymentUrl({
    required SocketClient socket,
    required String nodeId,
    required Map<String, dynamic> nodeData,
  }) async {
    final completer = Completer<String>();
    Timer? timeout;

    void onResult(dynamic data) {
      if (data is! Map) return;
      final resultNodeId = data['nodeId']?.toString();
      if (resultNodeId != nodeId) return;

      timeout?.cancel();
      socket.off(SocketEvents.integrationResult, onResult);

      if (data['success'] == true) {
        final resultData = data['data'] as Map<String, dynamic>?;
        final url = resultData?['url']?.toString() ?? '';
        if (!completer.isCompleted) completer.complete(url);
      } else {
        if (!completer.isCompleted) completer.complete('');
      }
    }

    socket.on(SocketEvents.integrationResult, onResult);

    // Emit the integration execution request (matches embed-server protocol)
    socket.emit(SocketEvents.executeIntegration, {
      'nodeType': nodeType,
      'nodeId': nodeId,
      'nodeData': nodeData,
      'chatSessionId': state.chatSessionId,
      'chatbotId': state.botId,
      'workspaceId': state.workspaceId,
      'answerVariables': state.answerVariables
          .map((v) => v.toJson())
          .toList(),
    });

    // Timeout after 15 seconds to avoid hanging indefinitely
    timeout = Timer(const Duration(seconds: 15), () {
      socket.off(SocketEvents.integrationResult, onResult);
      if (!completer.isCompleted) completer.complete('');
    });

    return completer.future;
  }

  double? _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    if (amount is String) return double.tryParse(amount);
    return null;
  }
}
