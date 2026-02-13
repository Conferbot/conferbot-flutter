import 'dart:async';
import 'package:flutter/foundation.dart';
import 'nodes/node_types.dart';
import 'nodes/node_result.dart';
import 'nodes/node_ui_state.dart';
import 'nodes/node_handler_registry.dart';
import 'nodes/handlers/legacy_handlers.dart' show NodeHandler;
import 'state/chat_state.dart';
import 'errors/conferbot_exceptions.dart';
import 'errors/error_handler.dart';
import '../services/socket_client.dart';
import '../providers/analytics_provider.dart';
import '../models/analytics.dart';
import '../utils/logger.dart';

/// Core engine that processes the chatbot flow
/// Orchestrates node handlers, manages state, and coordinates with socket
/// Uses ChangeNotifier for reactive Flutter UI updates
class NodeFlowEngine extends ChangeNotifier {
  final SocketClient _socketClient;

  /// Handler registry instance
  final NodeHandlerRegistry _handlerRegistry = NodeHandlerRegistry.instance;

  /// Analytics provider for tracking
  final AnalyticsProvider _analytics = AnalyticsProvider.instance;

  /// Timeout for processing a single node
  static const Duration _nodeProcessingTimeout = Duration(seconds: 30);

  /// Visited node tracking for infinite loop protection
  final Set<String> _visitedNodes = {};

  /// Maximum number of node visits before declaring a cycle
  static const int _maxNodeVisits = 100;

  /// Constructor
  NodeFlowEngine({
    required SocketClient socketClient,
  }) : _socketClient = socketClient;

  // ========== State Fields ==========

  /// Current UI state to render
  NodeUIState? _currentUIState;
  NodeUIState? get currentUIState => _currentUIState;

  /// Loading state for typing indicator
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// Error state (typed exception)
  ConferBotException? _currentError;
  ConferBotException? get currentError => _currentError;

  /// Legacy error message getter for backwards compatibility
  String? get errorMessage => _currentError?.userMessage;

  /// Flow is complete
  bool _isFlowComplete = false;
  bool get isFlowComplete => _isFlowComplete;

  /// Current node being processed
  String? _currentNodeId;
  String? get currentNodeId => _currentNodeId;

  Map<String, dynamic>? _currentNodeData;
  Map<String, dynamic>? get currentNodeData => _currentNodeData;

  /// Reference to steps from server
  List<Map<String, dynamic>> _steps = [];
  List<Map<String, dynamic>> get steps => List.unmodifiable(_steps);

  /// Edge mapping for port-based routing
  List<Map<String, dynamic>> _edges = [];
  List<Map<String, dynamic>> get edges => List.unmodifiable(_edges);

  /// Chat state singleton
  ChatState get _chatState => ChatState();

  // ========== Streams for Reactive Updates ==========

  /// Stream controller for UI state changes
  final StreamController<NodeUIState?> _uiStateController =
      StreamController<NodeUIState?>.broadcast();
  Stream<NodeUIState?> get currentUIStateStream => _uiStateController.stream;

  /// Stream controller for processing state
  final StreamController<bool> _processingController =
      StreamController<bool>.broadcast();
  Stream<bool> get isProcessingStream => _processingController.stream;

  /// Stream controller for error messages (legacy string-based)
  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();
  Stream<String?> get errorMessageStream => _errorController.stream;

  /// Stream controller for typed errors
  final StreamController<ConferBotException?> _typedErrorController =
      StreamController<ConferBotException?>.broadcast();
  Stream<ConferBotException?> get errorStream => _typedErrorController.stream;

  /// Stream controller for flow completion
  final StreamController<bool> _flowCompleteController =
      StreamController<bool>.broadcast();
  Stream<bool> get isFlowCompleteStream => _flowCompleteController.stream;

  // ========== Initialization ==========

  /// Initialize the flow engine with bot data from server
  void initialize({
    required String chatSessionId,
    required String visitorId,
    required String botId,
    String? workspaceId,
    required List<Map<String, dynamic>> stepsData,
    required List<Map<String, dynamic>> edgesData,
  }) {
    _chatState.initialize(
      chatSessionId: chatSessionId,
      visitorId: visitorId,
      botId: botId,
      workspaceId: workspaceId,
    );
    _steps = List.from(stepsData);
    _edges = List.from(edgesData);
    _chatState.setSteps(stepsData);

    // Reset visited nodes for new flow initialization
    _visitedNodes.clear();

    // Initialize analytics session
    _analytics.startSession(
      sessionId: chatSessionId,
      visitorId: visitorId,
      botId: botId,
      workspaceId: workspaceId,
    );

    flowLogger.debug('Initialized with ${_steps.length} steps and ${_edges.length} edges');
  }

  // ========== Flow Control ==========

  /// Start processing from the first node
  void start() {
    _visitedNodes.clear();

    if (_steps.isEmpty) {
      _setFlowComplete(true);
      return;
    }

    _processNodeAtIndex(0);
  }

  /// Resume from a specific node by ID (used when restoring session)
  void resumeFromNode(String nodeId) {
    _visitedNodes.clear();
    final index = _steps.indexWhere((step) => step['id'] == nodeId);
    if (index >= 0) {
      _processNodeAtIndex(index);
    } else {
      flowLogger.warning('Resume target node $nodeId not found, starting from beginning');
      start();
    }
  }

  /// Process node at given index
  Future<void> _processNodeAtIndex(int index) async {
    if (index < 0 || index >= _steps.length) {
      _setFlowComplete(true);
      return;
    }

    _chatState.setCurrentIndex(index);
    final node = _steps[index];

    final nodeId = node['id']?.toString();
    if (nodeId == null) {
      flowLogger.debug('Node at index $index has no ID, skipping');
      _proceedToNextNode(null);
      return;
    }

    // HIGH FIX 2: Infinite loop protection
    if (_visitedNodes.length >= _maxNodeVisits) {
      flowLogger.error('Flow cycle detected after $_maxNodeVisits nodes');
      _setTypedError(NodeProcessingException(
        message: 'Flow cycle detected after $_maxNodeVisits nodes',
        code: 'NODE_FLOW_CYCLE',
        nodeId: nodeId,
      ));
      _setProcessing(false);
      _setFlowComplete(true);
      return;
    }
    _visitedNodes.add(nodeId);

    final nodeData = node['data'] as Map<String, dynamic>? ?? {};
    final nodeType = nodeData['type']?.toString() ?? node['type']?.toString();

    if (nodeType == null) {
      flowLogger.debug('Node $nodeId has no type, skipping');
      _proceedToNextNode(null);
      return;
    }

    _currentNodeId = nodeId;
    _currentNodeData = nodeData;

    // Track node entry in analytics
    final nodeName = nodeData['name']?.toString() ??
                     nodeData['label']?.toString() ??
                     nodeType;
    _analytics.trackNodeEntry(
      nodeId: nodeId,
      nodeType: nodeType,
      nodeName: nodeName,
    );

    await _processNode(nodeId, nodeType, nodeData);
  }

  /// Process a specific node
  Future<void> _processNode(
    String nodeId,
    String nodeType,
    Map<String, dynamic> nodeData,
  ) async {
    _setProcessing(true);
    _setError(null);

    final handler = _handlerRegistry.getHandler(nodeType);

    if (handler == null) {
      flowLogger.debug('No handler for node type: $nodeType, skipping');
      _setProcessing(false);

      // Track node exit with skip
      _analytics.trackNodeExit(exitType: NodeExitType.skipped);

      // Set a typed error for debugging (but allow proceeding)
      _setTypedError(NodeProcessingException.handlerNotFound(nodeType));

      await _proceedToNextNode(null);
      return;
    }

    try {
      // HIGH FIX 1: Node processing timeout
      final result = await handler.process(nodeData, nodeId).timeout(
        _nodeProcessingTimeout,
        onTimeout: () {
          flowLogger.warning('Node processing timed out for: $nodeId');
          return ErrorResult(
            message: 'Node processing timed out',
            shouldProceed: true,
          );
        },
      );
      await _handleNodeResult(result, nodeData);
    } on TimeoutException catch (e, stackTrace) {
      // HIGH FIX 6: Specific timeout exception handling
      flowLogger.error('Node processing timeout for $nodeId: $e', e, stackTrace);

      final typedException = NodeProcessingException(
        message: 'Node processing timed out',
        code: 'NODE_TIMEOUT',
        nodeId: nodeId,
        nodeType: nodeType,
        originalError: e,
        originalStackTrace: stackTrace,
      );

      _setTypedError(typedException);
      _setProcessing(false);
      _analytics.trackNodeExit(exitType: NodeExitType.error);
      await _proceedToNextNode(null);
    } on ConferBotException catch (e) {
      // HIGH FIX 6: Specific ConferBotException handling
      flowLogger.error('ConferBot error processing node $nodeId: $e', e, e.originalStackTrace);

      _setTypedError(e);
      _setProcessing(false);
      _analytics.trackNodeExit(exitType: NodeExitType.error);

      if (e.isRetryable || _shouldProceedOnError(e)) {
        await _proceedToNextNode(null);
      }
    } catch (e, stackTrace) {
      flowLogger.error('Error processing node $nodeId: $e', e, stackTrace);

      // Convert to typed exception
      final typedException = NodeProcessingException.processingFailed(
        nodeId: nodeId,
        nodeType: nodeType,
        phase: 'process',
        originalError: e,
        originalStackTrace: stackTrace,
      );

      _setTypedError(typedException);
      _setProcessing(false);

      // Track node exit with error
      _analytics.trackNodeExit(exitType: NodeExitType.error);

      // Try to proceed anyway for recoverable errors
      if (typedException.isRetryable || _shouldProceedOnError(typedException)) {
        await _proceedToNextNode(null);
      }
    }
  }

  /// Determine if flow should proceed after an error
  bool _shouldProceedOnError(ConferBotException error) {
    // For most node processing errors, try to continue the flow
    if (error is NodeProcessingException) {
      return error.code != 'NODE_INVALID_DATA';
    }
    return false;
  }

  /// Handle the result from a node handler
  Future<void> _handleNodeResult(
    NodeResult result,
    Map<String, dynamic> nodeData,
  ) async {
    switch (result) {
      case DisplayUIResult():
        _setProcessing(false);
        _setUIState(result.uiState);

        // Track bot message for display nodes
        final text = _extractDisplayText(result.uiState);
        if (text != null) {
          _analytics.trackMessage(sender: 'bot', text: text);
        }

        // For message-only nodes, auto-proceed after delay
        if (_isMessageOnlyUI(result.uiState)) {
          await Future.delayed(const Duration(seconds: 1));

          // Track node exit
          _analytics.trackNodeExit(exitType: NodeExitType.proceeded);

          _sendResponseToServer();
          await _proceedToNextNode(null);
        }

      case ProceedResult():
        _setProcessing(false);

        // Track node exit
        _analytics.trackNodeExit(exitType: NodeExitType.proceeded);

        _sendResponseToServer();
        await _proceedToNextNode(result.targetPort);

      case DelayedProceedResult():
        _setProcessing(true);
        await Future.delayed(result.delay);
        _setProcessing(false);

        // Track node exit
        _analytics.trackNodeExit(exitType: NodeExitType.proceeded);

        _sendResponseToServer();
        await _proceedToNextNode(result.targetPort);

      case DelayedProceed():
        // Handler compatibility: convert int ms to Duration
        _setProcessing(true);
        await Future.delayed(Duration(milliseconds: result.delayMs));
        _setProcessing(false);

        // Track node exit
        _analytics.trackNodeExit(exitType: NodeExitType.proceeded);

        _sendResponseToServer();
        await _proceedToNextNode(result.targetPort);

      case JumpToResult():
        _setProcessing(false);

        // Track node exit
        _analytics.trackNodeExit(exitType: NodeExitType.proceeded);

        _sendResponseToServer();
        await _jumpToNode(result.targetNodeId);

      case ErrorResult():
        _setProcessing(false);

        // Convert error result to typed exception
        final nodeType = nodeData['type']?.toString() ?? 'unknown';
        final typedException = NodeProcessingException(
          message: result.message,
          code: 'NODE_ERROR',
          nodeId: _currentNodeId,
          nodeType: nodeType,
        );
        _setTypedError(typedException);

        // Track node exit with error
        _analytics.trackNodeExit(exitType: NodeExitType.error);

        if (result.shouldProceed) {
          _sendResponseToServer();
          await _proceedToNextNode(null);
        }
    }
  }

  /// Extract display text from UI state for analytics
  String? _extractDisplayText(NodeUIState uiState) {
    if (uiState is MessageUIState) {
      return uiState.text;
    } else if (uiState is TextInputUIState) {
      return uiState.question;
    } else if (uiState is MultiChoiceUIState) {
      return uiState.question;
    }
    // Add more cases as needed
    return null;
  }

  /// Check if UI state is message-only (auto-proceeds)
  bool _isMessageOnlyUI(NodeUIState uiState) {
    return uiState is MessageUIState ||
        uiState is ImageUIState ||
        uiState is VideoUIState ||
        uiState is AudioUIState ||
        uiState is FileUIState ||
        uiState is HtmlUIState;
  }

  // ========== User Response Handling ==========

  /// Handle user response for current interactive node
  void submitResponse(dynamic response) {
    final nodeId = _currentNodeId;
    final nodeData = _currentNodeData;

    if (nodeId == null || nodeData == null) {
      flowLogger.debug('Cannot submit response: no current node');
      return;
    }

    _handleResponseAsync(response, nodeId, nodeData);
  }

  Future<void> _handleResponseAsync(
    dynamic response,
    String nodeId,
    Map<String, dynamic> nodeData,
  ) async {
    _setProcessing(true);
    _setError(null);

    final nodeType = nodeData['type']?.toString();
    if (nodeType == null) {
      _setProcessing(false);
      await _proceedToNextNode(null);
      return;
    }

    // Track user message
    final responseText = response is String ? response : response.toString();
    _analytics.trackMessage(sender: 'user', text: responseText);

    // Track node exit with user input
    String? selectedOption;
    if (response is Map && response.containsKey('selectedOption')) {
      selectedOption = response['selectedOption']?.toString();
    }
    _analytics.trackNodeExit(
      exitType: NodeExitType.proceeded,
      userInput: response,
      selectedOption: selectedOption,
    );

    final handler = _handlerRegistry.getHandler(nodeType);
    if (handler == null) {
      _setProcessing(false);
      await _proceedToNextNode(null);
      return;
    }

    try {
      // HIGH FIX 1: Timeout for response handling
      final result = await handler.handleResponse(response, nodeData, nodeId).timeout(
        _nodeProcessingTimeout,
        onTimeout: () {
          flowLogger.warning('Response handling timed out for node: $nodeId');
          return ErrorResult(
            message: 'Response handling timed out',
            shouldProceed: true,
          );
        },
      );
      await _handleNodeResult(result, nodeData);
    } on TimeoutException catch (e, stackTrace) {
      // HIGH FIX 6: Specific timeout exception handling
      flowLogger.error('Response handling timeout for $nodeId: $e', e, stackTrace);

      final typedException = NodeProcessingException(
        message: 'Response handling timed out',
        code: 'NODE_TIMEOUT',
        nodeId: nodeId,
        nodeType: nodeType,
        originalError: e,
        originalStackTrace: stackTrace,
      );

      _setTypedError(typedException);
      _setProcessing(false);
    } on ConferBotException catch (e) {
      // HIGH FIX 6: Specific ConferBotException handling
      flowLogger.error('ConferBot error handling response: $e', e, e.originalStackTrace);

      _setTypedError(e);
      _setProcessing(false);
    } catch (e, stackTrace) {
      flowLogger.error('Error handling response: $e', e, stackTrace);

      // Convert to typed exception
      final typedException = NodeProcessingException.processingFailed(
        nodeId: nodeId,
        nodeType: nodeType,
        phase: 'handleResponse',
        originalError: e,
        originalStackTrace: stackTrace,
      );

      _setTypedError(typedException);
      _setProcessing(false);
    }
  }

  /// Clear current error
  void clearError() {
    _setError(null);
  }

  // ========== Navigation ==========

  /// Proceed to the next node in the flow
  Future<void> _proceedToNextNode(String? targetPort) async {
    final currentId = _currentNodeId;
    if (currentId == null) {
      _setFlowComplete(true);
      return;
    }

    // Find next node based on edges
    String? nextNodeId;
    if (targetPort != null) {
      nextNodeId = _findNextNodeByPort(currentId, targetPort);
    } else {
      nextNodeId = _findNextNodeByDefaultEdge(currentId);
    }

    if (nextNodeId != null) {
      final nextIndex = _steps.indexWhere((step) => step['id'] == nextNodeId);
      if (nextIndex >= 0) {
        await _processNodeAtIndex(nextIndex);
        return;
      } else {
        // HIGH FIX 5: Log when edge target node doesn't exist in steps
        flowLogger.warning('Edge target node $nextNodeId not found in steps, falling back to sequential');
      }
    }

    // Try sequential fallback
    final currentIndex = _chatState.currentIndex;
    if (currentIndex + 1 < _steps.length) {
      await _processNodeAtIndex(currentIndex + 1);
    } else {
      _setFlowComplete(true);
    }
  }

  /// Jump to a specific node by ID
  Future<void> _jumpToNode(String targetNodeId) async {
    final targetIndex = _steps.indexWhere((step) => step['id'] == targetNodeId);
    if (targetIndex >= 0) {
      await _processNodeAtIndex(targetIndex);
    } else {
      // Node not found, proceed sequentially
      flowLogger.debug('Jump target $targetNodeId not found, proceeding sequentially');

      // Set a warning error (non-blocking)
      _setTypedError(NodeProcessingException.notFound(targetNodeId));

      await _proceedToNextNode(null);
    }
  }

  /// Find next node using edge with specific source port
  /// HIGH FIX 5: Edge routing validation with logging
  String? _findNextNodeByPort(String sourceId, String sourcePort) {
    // Look for edge from this node's specific port
    final edge = _edges.firstWhere(
      (edge) {
        final edgeSource = edge['source'];
        final edgeSourceHandle = edge['sourceHandle']?.toString();
        return edgeSource == sourceId &&
            (edgeSourceHandle == sourcePort ||
                edgeSourceHandle == sourcePort.replaceFirst('source-', ''));
      },
      orElse: () => <String, dynamic>{},
    );

    final target = edge['target']?.toString();
    if (target == null) {
      flowLogger.warning('No edge found for port: $sourcePort on node: $sourceId');
    }
    return target;
  }

  /// Find next node using default edge (any edge from source)
  /// HIGH FIX 5: Edge routing validation with logging
  String? _findNextNodeByDefaultEdge(String sourceId) {
    final edge = _edges.firstWhere(
      (edge) => edge['source'] == sourceId,
      orElse: () => <String, dynamic>{},
    );

    final target = edge['target']?.toString();
    if (target == null) {
      flowLogger.warning('No default edge found for node: $sourceId');
    }
    return target;
  }

  // ========== Server Communication ==========

  /// Send current state to server via socket
  void _sendResponseToServer() {
    final responseData = _chatState.buildResponseData();
    final chatSessionId = _chatState.chatSessionId;

    if (chatSessionId == null) {
      flowLogger.debug('Cannot send response: no chat session ID');
      return;
    }

    _socketClient.sendResponseRecord(
      chatSessionId: chatSessionId,
      record: responseData['record'],
      answerVariables: responseData['answerVariables'],
    );
  }

  /// Handle incoming bot message from server
  void handleServerMessage(Map<String, dynamic> message) {
    _handleServerMessageAsync(message);
  }

  Future<void> _handleServerMessageAsync(Map<String, dynamic> message) async {
    final nodeData = message['nodeData'] as Map<String, dynamic>?;
    final nodeType =
        nodeData?['type']?.toString() ?? message['type']?.toString();

    if (nodeType != null && nodeData != null) {
      final nodeId =
          message['_id']?.toString() ?? message['id']?.toString() ?? '';
      _currentNodeId = nodeId;
      _currentNodeData = nodeData;

      // Track node entry for server-pushed nodes
      final nodeName = nodeData['name']?.toString() ??
                       nodeData['label']?.toString() ??
                       nodeType;
      _analytics.trackNodeEntry(
        nodeId: nodeId,
        nodeType: nodeType,
        nodeName: nodeName,
      );

      await _processNode(nodeId, nodeType, nodeData);
    } else {
      // Plain text message
      final text = message['text']?.toString();
      if (text != null) {
        // Track bot message
        _analytics.trackMessage(sender: 'bot', text: text);

        _setUIState(MessageUIState(
          text: text,
          nodeId: message['_id']?.toString() ?? '',
        ));
      }
    }
  }

  // ========== Agent Event Handlers ==========

  /// Handle agent accepted event (human handover)
  void handleAgentAccepted(String agentName) {
    final nodeId = _currentNodeId;
    final nodeData = _currentNodeData;

    if (nodeId == null || nodeData == null) return;

    // Track interaction
    _analytics.trackInteraction(
      type: 'agent_accepted',
      data: {'agentName': agentName},
    );

    if (nodeData['type']?.toString() == NodeTypes.humanHandover) {
      final handler = _handlerRegistry.getHandler(NodeTypes.humanHandover);

      // Notify handler if it supports agent events
      if (handler is AgentEventHandler) {
        handler.onAgentAccepted(nodeId, agentName);
      }

      _setUIState(HumanHandoverUIState(
        state: HandoverState.agentConnected,
        agentName: agentName,
        nodeId: nodeId,
      ));
    }
  }

  /// Handle no agents available event
  void handleNoAgentsAvailable() {
    final nodeId = _currentNodeId;
    final nodeData = _currentNodeData;

    if (nodeId == null || nodeData == null) return;

    // Track interaction
    _analytics.trackInteraction(
      type: 'no_agents_available',
      data: {},
    );

    if (nodeData['type']?.toString() == NodeTypes.humanHandover) {
      final handler = _handlerRegistry.getHandler(NodeTypes.humanHandover);

      if (handler is AgentEventHandler) {
        _handleNoAgentsAsync(handler, nodeId, nodeData);
      } else {
        // Default behavior: show no agents available state
        _setUIState(HumanHandoverUIState(
          state: HandoverState.noAgentsAvailable,
          nodeId: nodeId,
        ));
      }
    }
  }

  Future<void> _handleNoAgentsAsync(
    AgentEventHandler handler,
    String nodeId,
    Map<String, dynamic> nodeData,
  ) async {
    final result = await handler.onNoAgentsAvailable(nodeId, nodeData);
    if (result != null) {
      await _handleNodeResult(result, nodeData);
    }
  }

  /// Handle chat ended event (for handover)
  void handleChatEnded() {
    final nodeId = _currentNodeId;
    final nodeData = _currentNodeData;

    if (nodeId == null || nodeData == null) return;

    // Track interaction
    _analytics.trackInteraction(
      type: 'chat_ended',
      data: {},
    );

    if (nodeData['type']?.toString() == NodeTypes.humanHandover) {
      final handler = _handlerRegistry.getHandler(NodeTypes.humanHandover);

      if (handler is AgentEventHandler) {
        _handleChatEndedAsync(handler, nodeId, nodeData);
      }
    }
  }

  Future<void> _handleChatEndedAsync(
    AgentEventHandler handler,
    String nodeId,
    Map<String, dynamic> nodeData,
  ) async {
    final result = await handler.onChatEnded(nodeId, nodeData);
    if (result != null) {
      await _handleNodeResult(result, nodeData);
    }
  }

  // ========== State Setters (with notifications) ==========

  void _setUIState(NodeUIState? state) {
    _currentUIState = state;
    _uiStateController.add(state);
    notifyListeners();
  }

  void _setProcessing(bool processing) {
    _isProcessing = processing;
    _processingController.add(processing);
    notifyListeners();
  }

  void _setError(String? error) {
    if (error == null) {
      _currentError = null;
    }
    _errorController.add(error);
    _typedErrorController.add(_currentError);
    notifyListeners();
  }

  void _setTypedError(ConferBotException? error) {
    _currentError = error;
    _errorController.add(error?.userMessage);
    _typedErrorController.add(error);
    notifyListeners();
  }

  void _setFlowComplete(bool complete) {
    _isFlowComplete = complete;
    _flowCompleteController.add(complete);

    // End analytics session when flow completes
    if (complete) {
      _analytics.endSession();
    }

    notifyListeners();
  }

  // ========== Reset & Cleanup ==========

  /// Reset the engine for a new conversation
  void reset() {
    // End current analytics session
    _analytics.endSession();

    _currentUIState = null;
    _isProcessing = false;
    _currentError = null;
    _isFlowComplete = false;
    _currentNodeId = null;
    _currentNodeData = null;
    _steps = [];
    _edges = [];
    _visitedNodes.clear();
    _chatState.reset();

    notifyListeners();
  }

  /// Clean up resources
  @override
  void dispose() {
    // End analytics session on dispose
    _analytics.endSession();

    _uiStateController.close();
    _processingController.close();
    _errorController.close();
    _typedErrorController.close();
    _flowCompleteController.close();
    _chatState.reset();
    super.dispose();
  }
}

/// Interface for handlers that need to respond to agent events
abstract class AgentEventHandler {
  /// Called when an agent accepts the handover
  void onAgentAccepted(String nodeId, String agentName);

  /// Called when no agents are available
  Future<NodeResult?> onNoAgentsAvailable(
    String nodeId,
    Map<String, dynamic> nodeData,
  );

  /// Called when the chat is ended
  Future<NodeResult?> onChatEnded(
    String nodeId,
    Map<String, dynamic> nodeData,
  );
}
