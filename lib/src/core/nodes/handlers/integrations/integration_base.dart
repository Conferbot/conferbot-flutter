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

  /// Emit `execute-integration` to the server and optionally wait for the
  /// `integration-result` response.
  ///
  /// If [waitForResult] is `true` (default), this method returns the result
  /// data map from the server, or `null` on timeout / error / disconnect.
  ///
  /// If [waitForResult] is `false`, the event is fired and the method returns
  /// immediately with `null` (fire-and-forget).
  Future<Map<String, dynamic>?> emitExecuteIntegration({
    required Map<String, dynamic> nodeData,
    required String nodeId,
    bool waitForResult = true,
  }) async {
    final socket = socketClient;
    if (socket == null || !socket.isConnected) return null;

    final payload = {
      'nodeType': nodeType,
      'nodeId': nodeId,
      'nodeData': nodeData,
      'chatSessionId': state.chatSessionId,
      'chatbotId': state.botId,
      'workspaceId': state.workspaceId,
      'answerVariables': state.answerVariables
          .map((v) => v.toJson())
          .toList(),
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
}
