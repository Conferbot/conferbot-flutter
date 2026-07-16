import 'dart:async';
import 'package:flutter/foundation.dart';
import 'nodes/node_types.dart';
import 'nodes/node_result.dart';
import 'nodes/node_ui_state.dart';
import 'nodes/node_handler_registry.dart';
import 'nodes/handlers/legacy_handlers.dart' show NodeHandler;
import 'nodes/handlers/display_handlers.dart' show MessageState, ImageState, VideoState, AudioState, FileState, HtmlState;
import 'nodes/handlers/choices/choice_ui_states.dart' show SingleChoiceState, MultipleChoiceState;
import 'nodes/handlers/integrations/integration_base.dart' show IntegrationNodeHandler;
import 'state/chat_state.dart';
import 'errors/conferbot_exceptions.dart';
import 'errors/error_handler.dart' hide ErrorResult;
import '../services/socket_client.dart';
import '../models/socket_events.dart';
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
  }) : _socketClient = socketClient {
    // Inject socket client into all integration handlers that need server communication
    IntegrationNodeHandler.socketClient = socketClient;
    // StripeNodeHandler.socketClient setter delegates to IntegrationNodeHandler
    // for backward compatibility
  }

  // ========== State Fields ==========

  /// Current UI state to render
  dynamic _currentUIState;
  dynamic get currentUIState => _currentUIState;

  /// Question text of the active interactive node, if any. The provider
  /// persists it into the visible transcript before echoing the answer.
  String? get currentQuestionText =>
      _extractInteractiveQuestionText(_currentUIState);

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
  final StreamController<dynamic> _uiStateController =
      StreamController<dynamic>.broadcast();
  Stream<dynamic> get currentUIStateStream => _uiStateController.stream;

  /// Stream controller for bot messages to add to chat record
  final StreamController<Map<String, dynamic>> _botMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get botMessageStream => _botMessageController.stream;

  /// Stream controller for user messages to add to chat record
  final StreamController<Map<String, dynamic>> _userMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get userMessageStream => _userMessageController.stream;

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
    flowLogger.debug('_processNodeAtIndex($index) called, total steps: ${_steps.length}');
    if (index < 0 || index >= _steps.length) {
      flowLogger.debug('Index $index out of bounds, marking flow complete');
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

    flowLogger.debug('Node[$index] id=$nodeId type=$nodeType dataKeys=${nodeData.keys.toList()}');

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
      flowLogger.debug('No handler for node type: $nodeType (nodeId: $nodeId), skipping to next');
      _setProcessing(false);

      // Track node exit with skip
      _analytics.trackNodeExit(exitType: NodeExitType.skipped);

      // For welcome-node, just proceed — it's a start marker
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
        // uiState can be either canonical NodeUIState or legacy NodeUIState
        final uiState = result.uiState;
        flowLogger.debug('DisplayUIResult: setting UI state type=${uiState.runtimeType}');

        // Extract text for message-only nodes
        final text = _extractDisplayText(uiState as dynamic);

        // Push bot message to record (matching web widget format)
        final nodeId = _currentNodeId;
        final nodeType = nodeData['type']?.toString();
        if (nodeId != null && nodeType != null) {
          final nodeDataSub = (nodeData['data'] as Map<String, dynamic>?) ?? {};
          final recordData = Map<String, dynamic>.from(nodeDataSub);
          if (text != null) recordData['text'] = text;
          _chatState.pushToRecord(RecordEntry(
            id: nodeId,
            shape: nodeType,
            type: nodeType,
            text: text,
            data: recordData,
          ));
        }

        // For message-only nodes, add to chat record and auto-proceed
        if (_isMessageOnlyUI(uiState as dynamic)) {
          // Emit bot message to be added to provider's record
          if (text != null && text.isNotEmpty) {
            _botMessageController.add({
              'text': text,
              'nodeId': _currentNodeId ?? '',
              'type': 'bot-message',
            });
            flowLogger.debug('Emitted bot message to record: "$text"');
          }

          // Emit the node's image (welcome GIF, image-node) as a standalone
          // image entry below the text bubble - web widget parity
          final dynamic dynUi = uiState;
          String? imageUrl;
          if (dynUi is ImageState) {
            imageUrl = dynUi.url;
          } else if (dynUi is ImageUIState) {
            imageUrl = dynUi.url;
          } else {
            // nodeData may be the node's data map itself or the full node
            final dataMap =
                (nodeData['data'] as Map<String, dynamic>?) ?? nodeData;
            final nodeImage = dataMap['image']?.toString();
            final disabled = dataMap['disableImage'] == true;
            if (!disabled && nodeImage != null && nodeImage.isNotEmpty) {
              imageUrl = nodeImage;
            }
          }
          if (imageUrl != null && imageUrl.isNotEmpty) {
            _botMessageController.add({
              'imageUrl': imageUrl,
              'nodeId': _currentNodeId ?? '',
              'type': 'bot-message',
            });
            flowLogger.debug('Emitted bot image to record: "$imageUrl"');
          }

          // Track bot message
          if (text != null) {
            _analytics.trackMessage(sender: 'bot', text: text);
          }

          // Brief delay to show typing, then auto-proceed
          await Future.delayed(const Duration(milliseconds: 800));

          // Track node exit
          _analytics.trackNodeExit(exitType: NodeExitType.proceeded);

          _sendResponseToServer();
          await _proceedToNextNode(null);
        } else {
          // Interactive node — set UI state for inline rendering in message list
          _setUIState(uiState as dynamic);

          // For human handover waiting state, emit initiate-handover socket event
          // matching the web widget's payload format
          if (uiState is HumanHandoverUIState &&
              (uiState as HumanHandoverUIState).state == HandoverState.waitingForAgent) {
            // Send response-record before handover so the server has the
            // Response document when creating the ticket/notification
            _sendResponseToServer();
            // Re-join room to ensure socket is in the correct room
            if (_chatState.chatSessionId != null) {
              _socketClient.joinChatRoomVisitor(_chatState.chatSessionId!);
            }
            _emitInitiateHandover(nodeData);
          }

          // Track bot message
          if (text != null) {
            _analytics.trackMessage(sender: 'bot', text: text);
          }
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
  String? _extractDisplayText(dynamic uiState) {
    if (uiState is MessageUIState) {
      return uiState.text;
    } else if (uiState is MessageState) {
      return uiState.text;
    } else if (uiState is TextInputUIState) {
      return uiState.questionText;
    } else if (uiState is MultipleChoiceUIState) {
      return uiState.questionText;
    }
    return null;
  }

  /// Extract question text from interactive node states
  /// Used to add the question as a bot message in the chat record
  String? _extractInteractiveQuestionText(dynamic uiState) {
    if (uiState is SingleChoiceUIState) return uiState.questionText;
    if (uiState is SingleChoiceState) return uiState.questionText;
    if (uiState is MultipleChoiceUIState) return uiState.questionText;
    if (uiState is MultipleChoiceState) return uiState.questionText;
    if (uiState is TextInputUIState) return uiState.questionText;
    return null;
  }

  /// Check if UI state is message-only (auto-proceeds)
  bool _isMessageOnlyUI(dynamic uiState) {
    // Check both canonical (node_ui_state.dart) and legacy (display_handlers.dart) types
    return uiState is MessageUIState ||
        uiState is MessageState ||
        uiState is ImageUIState ||
        uiState is ImageState ||
        uiState is VideoUIState ||
        uiState is VideoState ||
        uiState is AudioUIState ||
        uiState is AudioState ||
        uiState is FileUIState ||
        uiState is FileState ||
        uiState is HtmlUIState ||
        uiState is HtmlState;
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

    // Track user message — extract display text from response
    final String responseText;
    if (response is String) {
      responseText = response;
    } else if (response is Map) {
      responseText = response['text']?.toString() ??
          response['label']?.toString() ??
          response.toString();
    } else {
      responseText = response.toString();
    }
    _analytics.trackMessage(sender: 'user', text: responseText);

    // Push user response to record (matching web widget format)
    _chatState.pushToRecord(RecordEntry(
      id: nodeId,
      shape: 'user-input-response',
      type: nodeData['type']?.toString(),
      text: responseText,
    ));

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
      // Snapshot transcript length before handling to detect new user entries
      final transcriptBefore = _chatState.transcript.length;

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

      // Emit any new user messages added by the handler to the transcript
      final transcriptAfter = _chatState.transcript;
      for (var i = transcriptBefore; i < transcriptAfter.length; i++) {
        final entry = transcriptAfter[i];
        if (entry.by == 'user' && entry.message.isNotEmpty) {
          _userMessageController.add({
            'text': entry.message,
            'nodeId': nodeId,
            'type': 'user-message',
          });
        }
      }

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
    flowLogger.debug('_proceedToNextNode called: currentId=$currentId, targetPort=$targetPort');
    if (currentId == null) {
      flowLogger.debug('No currentId, marking flow complete');
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

    flowLogger.debug('Edge lookup result: nextNodeId=$nextNodeId');

    if (nextNodeId != null) {
      final nextIndex = _steps.indexWhere((step) => step['id'] == nextNodeId);
      if (nextIndex >= 0) {
        flowLogger.debug('Found next node at index $nextIndex, processing...');
        await _processNodeAtIndex(nextIndex);
        return;
      } else {
        flowLogger.warning('Edge target node $nextNodeId not found in steps, falling back to sequential');
      }
    }

    // Try sequential fallback
    final currentIndex = _chatState.currentIndex;
    flowLogger.debug('Sequential fallback: currentIndex=$currentIndex, totalSteps=${_steps.length}');
    if (currentIndex + 1 < _steps.length) {
      await _processNodeAtIndex(currentIndex + 1);
    } else {
      flowLogger.debug('No more steps, marking flow complete');
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
    flowLogger.debug('Looking for default edge from node: $sourceId');
    flowLogger.debug('Available edges: ${_edges.map((e) => '${e['source']}->${e['target']}').toList()}');
    final edge = _edges.firstWhere(
      (edge) => edge['source'] == sourceId,
      orElse: () => <String, dynamic>{},
    );

    final target = edge['target']?.toString();
    if (target == null) {
      flowLogger.warning('No default edge found for node: $sourceId');
    } else {
      flowLogger.debug('Found edge: $sourceId -> $target');
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
        (handler as AgentEventHandler).onAgentAccepted(nodeId, agentName);
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
        _handleNoAgentsAsync(handler as AgentEventHandler, nodeId, nodeData);
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
        _handleChatEndedAsync(handler as AgentEventHandler, nodeId, nodeData);
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

  void _setUIState(dynamic state) {
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

  /// Emit initiate-handover socket event matching web widget payload format.
  /// Called when handover handler returns waitingForAgent UI state.
  void _emitInitiateHandover(Map<String, dynamic> nodeData) {
    final chatSessionId = _chatState.chatSessionId;
    final botId = _chatState.botId ?? '';
    final workspaceId = _chatState.workspaceId ?? '';
    final botName = _chatState.getVariable('_botName')?.toString() ?? '';
    final now = DateTime.now().toUtc().toIso8601String();

    // Build chatMetaData matching web widget format exactly
    final chatMetaData = {
      'version': 'v2',
      'workspaceId': workspaceId,
      'chatSessionId': chatSessionId,
      'botId': botId,
      'botName': botName,
      'chatDate': now,
      'deviceInfo': 'Flutter/${_chatState.buildResponseData()['deviceInfo'] ?? 'unknown'}',
      'location': DateTime.now().timeZoneName,
      'record': _chatState.getRecordForServer(),
      'answerVariables': _chatState.getAnswerVariablesMap(),
      'transcript': _chatState.getTranscriptForGPT(),
    };

    // Build visitor metaData
    final metaData = {
      'visitorId': chatSessionId ?? '',
      'chatDate': now,
      'deviceInfo': chatMetaData['deviceInfo'],
      'location': chatMetaData['location'],
    };

    // Extract handover config from nodeData
    final maxWaitTime = nodeData['maxWaitTime'] is num
        ? (nodeData['maxWaitTime'] as num).toInt()
        : 2;

    final payload = {
      'workspaceId': workspaceId,
      'chatbotId': botId,
      'chatbotName': botName,
      'chatSessionId': chatSessionId,
      'chatMetaData': chatMetaData,
      'metaData': metaData,
      'priority': nodeData['priority']?.toString() ?? 'normal',
      'maxWaitTime': maxWaitTime,
      'assignmentType': nodeData['assignmentType']?.toString() ?? 'auto',
      'assignmentStrategy': nodeData['agentAssignmentStrategy']?.toString() ?? '',
      'assignedAgents': nodeData['assignedAgents'] ?? [],
      'assignedAIAgents': nodeData['assignedAIAgents'] ?? [],
    };

    _socketClient.emit(SocketEvents.initiateHandover, payload);
    flowLogger.debug('Emitted initiate-handover to server');
  }

  /// Clean up resources
  @override
  void dispose() {
    // End analytics session on dispose
    _analytics.endSession();

    _uiStateController.close();
    _botMessageController.close();
    _userMessageController.close();
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
