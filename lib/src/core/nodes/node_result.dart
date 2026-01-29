import 'node_ui_state.dart';

/// Sealed class representing the possible results from a node handler
sealed class NodeResult {
  const NodeResult();
}

/// Node requires UI display and user interaction
class DisplayUIResult extends NodeResult {
  final NodeUIState uiState;

  const DisplayUIResult({required this.uiState});
}

/// Node processed successfully, proceed to next node
class ProceedResult extends NodeResult {
  /// Optional target port for branching flows (e.g., "yes", "no", "option-1")
  final String? targetPort;

  const ProceedResult({this.targetPort});
}

/// Node processed with delay before proceeding
class DelayedProceedResult extends NodeResult {
  final Duration delay;
  final String? targetPort;

  const DelayedProceedResult({
    required this.delay,
    this.targetPort,
  });

  /// Create from milliseconds
  factory DelayedProceedResult.fromMs(int delayMs, {String? targetPort}) {
    return DelayedProceedResult(
      delay: Duration(milliseconds: delayMs),
      targetPort: targetPort,
    );
  }
}

/// Jump to specific node by ID
class JumpToResult extends NodeResult {
  final String targetNodeId;

  const JumpToResult({required this.targetNodeId});
}

/// Error occurred during processing
class ErrorResult extends NodeResult {
  final String message;
  final bool shouldProceed;

  const ErrorResult({
    required this.message,
    this.shouldProceed = true,
  });
}

// ============================================================================
// Type aliases for handler compatibility
// ============================================================================

/// Alias for DisplayUIResult (handler compatibility)
typedef DisplayUI = DisplayUIResult;

/// Alias for ProceedResult (handler compatibility)
typedef Proceed = ProceedResult;

/// Alias for JumpToResult (handler compatibility)
typedef JumpTo = JumpToResult;

/// Alias for ErrorResult (handler compatibility)
typedef NodeError = ErrorResult;

/// Handler-compatible delayed proceed
class DelayedProceed extends NodeResult {
  final int delayMs;
  final String? targetPort;

  const DelayedProceed({required this.delayMs, this.targetPort});

  /// Convert to DelayedProceedResult
  DelayedProceedResult toResult() => DelayedProceedResult.fromMs(delayMs, targetPort: targetPort);
}
