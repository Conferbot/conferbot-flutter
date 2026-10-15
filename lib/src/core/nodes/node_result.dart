/// What a step handler tells the flow engine to do next (as the React Native
/// SDK's NodeResult, src/core/nodes/NodeHandler.ts).
///
/// - [DisplayUIResult]: draw a UI state; the step waits for the visitor when
///   its type takes input (NodeTypes.requiresUserInteraction) or when
///   `awaitInput` is set, else the flow moves on along the first edge.
/// - [ProceedResult]: `nextNodeId` null takes the step's FIRST edge;
///   "__port:<handle>" takes exactly that handle (none: the chat ends);
///   anything else jumps to that node.
/// - [DelayedProceedResult]: the same after `delayMs`.
/// - [JumpToResult]: to a node by id (a missing one ends the chat).
/// - [InvalidResult]: a refused answer; the step keeps waiting.
/// - [EndResult]: the chat is over.
/// - [ErrorResult]: something failed; the flow stops where it is.
sealed class NodeResult {
  const NodeResult();

  /// Draw [uiState]; [awaitInput] makes any step wait for the visitor.
  factory NodeResult.displayUI(Object uiState, {bool awaitInput}) = DisplayUIResult;

  /// Move on: the first edge (null), an exact handle ("__port:<h>") or a node id.
  factory NodeResult.proceed(String? nextNodeId, [Map<String, dynamic>? data]) = ProceedResult;

  /// Move on after [delayMs].
  factory NodeResult.delayedProceed(String? nextNodeId, int delayMs, [Map<String, dynamic>? data]) =
      DelayedProceedResult;

  /// To a node by id.
  factory NodeResult.jumpTo(String targetNodeId, [Map<String, dynamic>? data]) = JumpToResult;

  /// A refused answer: say [message] and keep waiting. [inCard]: the card
  /// shows it itself (no bot bubble).
  factory NodeResult.invalid(String message, {Object? uiState, bool inCard}) = InvalidResult;

  /// The chat is over.
  factory NodeResult.end() = EndResult;

  /// Something failed.
  factory NodeResult.error(String message, {bool recoverable}) = ErrorResult;

  /// Leave by exactly [handle]; [fallback] is taken when only it is wired
  /// (web goPort).
  static ProceedResult port(String handle, {String? fallback, Map<String, dynamic>? data}) =>
      ProceedResult('__port:$handle', {...?data, if (fallback != null) 'fallbackPort': fallback});

  /// Leave by the step's first edge.
  static ProceedResult next([Map<String, dynamic>? data]) => ProceedResult(null, data);
}

/// Draw a UI state.
class DisplayUIResult extends NodeResult {
  final Object uiState;
  final bool awaitInput;

  const DisplayUIResult(this.uiState, {this.awaitInput = false});
}

/// Move on (see [NodeResult]).
class ProceedResult extends NodeResult {
  final String? nextNodeId;
  final Map<String, dynamic>? data;

  const ProceedResult(this.nextNodeId, [this.data]);

  /// The exact handle asked for, when this is a port.
  String? get port => nextNodeId != null && nextNodeId!.startsWith('__port:') ? nextNodeId!.substring(7) : null;
}

/// Move on after a delay.
class DelayedProceedResult extends NodeResult {
  final String? nextNodeId;
  final int delayMs;
  final Map<String, dynamic>? data;

  const DelayedProceedResult(this.nextNodeId, this.delayMs, [this.data]);
}

/// To a node by id.
class JumpToResult extends NodeResult {
  final String targetNodeId;
  final Map<String, dynamic>? data;

  const JumpToResult(this.targetNodeId, [this.data]);
}

/// A refused answer.
class InvalidResult extends NodeResult {
  final String message;
  final Object? uiState;
  final bool inCard;

  const InvalidResult(this.message, {this.uiState, this.inCard = false});
}

/// The chat is over.
class EndResult extends NodeResult {
  const EndResult();
}

/// Something failed.
class ErrorResult extends NodeResult {
  final String message;
  final bool recoverable;

  const ErrorResult(this.message, {this.recoverable = true});
}
