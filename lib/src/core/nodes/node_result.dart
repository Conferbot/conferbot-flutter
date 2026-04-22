/// Sealed class representing the possible results from a node handler
///
/// This is the single source of truth for all node result types.
/// All handlers (legacy, v2, ask, special, logic) use this class.
abstract class NodeResult {
  const NodeResult();

  /// Factory: proceed to next node (optionally via a specific port)
  const factory NodeResult.proceed({String? targetPort}) = ProceedResult;

  /// Factory: display UI and wait for user interaction
  /// Accepts any UI state object (legacy NodeUIState or v2 NodeUIState)
  factory NodeResult.displayUI(Object uiState) = DisplayUIResult.positional;

  /// Factory: proceed after a delay
  const factory NodeResult.delayedProceed({required Duration delay, String? targetPort}) = DelayedProceedResult;

  /// Factory: jump to a specific node by ID
  factory NodeResult.jumpTo(String targetNodeId) = JumpToResult.positional;

  /// Factory: error occurred during processing
  const factory NodeResult.error({required String message, bool shouldProceed}) = ErrorResult;
}

/// Node requires UI display and user interaction
class DisplayUIResult extends NodeResult {
  /// The UI state object. Can be any NodeUIState subclass from either
  /// the legacy or v2 type hierarchy.
  final Object uiState;

  /// Primary positional constructor (used by both legacy and v2 handlers)
  const DisplayUIResult(this.uiState);

  /// Named constructor for explicit usage
  const DisplayUIResult.withState({required this.uiState});

  /// Alias for primary constructor (used by factory redirect)
  const DisplayUIResult.positional(this.uiState);
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

  /// Positional constructor for factory redirect
  const JumpToResult.positional(this.targetNodeId);
}

/// Error occurred during processing
class ErrorResult extends NodeResult {
  final String message;
  final bool shouldProceed;

  /// Named parameter constructor (used by v2 handlers via NodeResult.error())
  const ErrorResult({
    required this.message,
    this.shouldProceed = true,
  });
}

// ============================================================================
// Type aliases and compatibility classes for handler backward compatibility
// ============================================================================

/// Alias for DisplayUIResult (handler compatibility)
typedef DisplayUI = DisplayUIResult;

/// Alias for ProceedResult (handler compatibility)
typedef Proceed = ProceedResult;

/// Alias for JumpToResult (handler compatibility)
typedef JumpTo = JumpToResult;

/// Legacy-compatible error class that accepts positional message parameter.
/// Used by legacy handlers: NodeError('message', shouldProceed: false)
class NodeError extends NodeResult {
  final String message;
  final bool shouldProceed;

  const NodeError(this.message, {this.shouldProceed = true});
}

/// Handler-compatible delayed proceed (milliseconds-based)
class DelayedProceed extends NodeResult {
  final int delayMs;
  final String? targetPort;

  const DelayedProceed({required this.delayMs, this.targetPort});

  /// Convert to DelayedProceedResult
  DelayedProceedResult toResult() => DelayedProceedResult.fromMs(delayMs, targetPort: targetPort);
}
