/// CRM integration handlers
///
/// Handles integrations with CRM platforms:
/// - HubSpot (create/update contacts and deals)
/// - Zoho CRM (create/update records across modules)
library;

import '../../node_types.dart';
import '../legacy_handlers.dart';

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
