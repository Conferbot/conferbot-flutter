/// Base class for integration node handlers that need to emit
/// 'execute-integration' socket events to the server.
///
/// Provides a shared static [socketClient] reference (injected by
/// [NodeFlowEngine] at startup) and a helper method
/// [emitExecuteIntegration] that mirrors the web widget / Android SDK
/// protocol:
///
/// 1. Emit `execute-integration` with node metadata + answer variables.
/// 2. Listen for `integration-result` keyed by nodeId.
/// 3. Return the result data (or null on timeout / error).
library;

import 'dart:async';

import '../legacy_handlers.dart';
import '../../../../models/socket_events.dart';
import '../../../../services/socket_client.dart';

/// Mixin that adds server-side integration execution to any [BaseNodeHandler].
///
/// Usage:
/// ```dart
/// class SlackNodeHandler extends IntegrationNodeHandler {
///   @override String get nodeType => NodeTypes.slack;
///   @override
///   Future<NodeResult> process(...) async {
///     final result = await emitExecuteIntegration(nodeData: nodeData, nodeId: nodeId);
///     recordResponse(...);
///     return const Proceed();
///   }
/// }
/// ```
abstract class IntegrationNodeHandler extends BaseNodeHandler {
  /// Shared socket client reference, set by [NodeFlowEngine] during init.
  static SocketClient? socketClient;

  /// Timeout for waiting on the server's `integration-result` response.
  static const Duration _integrationTimeout = Duration(seconds: 30);

  /// Build the visitor metadata map sent as `visitorData` on
  /// execute-integration, matching the web widget payload. Used server-side
  /// for ${var} resolution of visitor fields.
  Map<String, dynamic> buildVisitorData() {
    final meta = state.userMetadata;
    return {
      if (meta.name != null && meta.name!.isNotEmpty) 'name': meta.name,
      if (meta.email != null && meta.email!.isNotEmpty) 'email': meta.email,
      if (meta.phone != null && meta.phone!.isNotEmpty) 'phone': meta.phone,
      ...meta.metadata,
    };
  }

  /// Emit `execute-integration` to the server and optionally wait for the
  /// `integration-result` response.
  ///
  /// If [waitForResult] is `true` (default), this method returns the result
  /// data map from the server, or `null` on timeout / error / disconnect.
  ///
  /// If [waitForResult] is `false`, the event is fired and the method returns
  /// immediately with `null` (fire-and-forget).
  ///
  /// [overrideNodeType] replaces the handler's [nodeType] in the payload.
  /// Needed for google-sheets-node, which the server only accepts as
  /// google-sheets-read-node / google-sheets-write-node.
  Future<Map<String, dynamic>?> emitExecuteIntegration({
    required Map<String, dynamic> nodeData,
    required String nodeId,
    bool waitForResult = true,
    String? overrideNodeType,
  }) async {
    final socket = socketClient;
    if (socket == null || !socket.isConnected) return null;

    final payload = {
      'nodeType': overrideNodeType ?? nodeType,
      'nodeId': nodeId,
      'nodeData': nodeData,
      'chatSessionId': state.chatSessionId,
      'chatbotId': state.botId,
      'workspaceId': state.workspaceId,
      // Server expects an ARRAY of {key, value} objects for ${var} resolution
      'answerVariables': state.answerVariables
          .map((v) => v.toJson())
          .toList(),
      'visitorData': buildVisitorData(),
    };

    if (!waitForResult) {
      socket.emit(SocketEvents.executeIntegration, payload);
      return null;
    }

    final completer = Completer<Map<String, dynamic>?>();
    Timer? timeout;

    void onResult(dynamic data) {
      if (data is! Map) return;
      final resultNodeId = data['nodeId']?.toString();
      if (resultNodeId != nodeId) return;

      timeout?.cancel();
      socket.off(SocketEvents.integrationResult, onResult);

      if (!completer.isCompleted) {
        if (data['success'] == true) {
          _applyResultVariables(data);
          final resultData = data['data'];
          completer.complete(
            resultData is Map<String, dynamic>
                ? resultData
                : (resultData is Map ? Map<String, dynamic>.from(resultData) : null),
          );
        } else {
          completer.complete(null);
        }
      }
    }

    socket.on(SocketEvents.integrationResult, onResult);
    socket.emit(SocketEvents.executeIntegration, payload);

    timeout = Timer(_integrationTimeout, () {
      socket.off(SocketEvents.integrationResult, onResult);
      if (!completer.isCompleted) completer.complete(null);
    });

    return completer.future;
  }

  /// Apply output variables from a successful integration-result, matching
  /// the web widget: `answerVariable`/`answerValue` plus each entry in
  /// `columnMappedValues` (Google Sheets reads with columnVariables) is
  /// stored as an answer variable keyed by variable name.
  void _applyResultVariables(Map data) {
    final answerVariable = data['answerVariable']?.toString();
    if (answerVariable != null &&
        answerVariable.isNotEmpty &&
        data.containsKey('answerValue')) {
      state.setAnswerVariableByKey(answerVariable, data['answerValue']);
    }

    final columnMappedValues = data['columnMappedValues'];
    if (columnMappedValues is Map) {
      columnMappedValues.forEach((variableName, value) {
        final name = variableName?.toString();
        if (name != null && name.isNotEmpty && value != null) {
          state.setAnswerVariableByKey(name, value);
        }
      });
    }
  }
}
