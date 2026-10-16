/// Runs a bot flow the way the web widget does. The reference is the shared
/// flow-node spec (conferbot-react-native scripts/parity/flows/
/// nodes.spec.json, "engine"), made by running conferbot-widget's own code;
/// test/parity/flows_test.dart runs every fixture through this engine. A
/// port of the React Native SDK's src/core/NodeFlowEngine.ts.
///
/// - start: the FIRST welcome-node in nodes[].
/// - next: a step that does not branch leaves by the FIRST edge from it,
///   whatever its handle. No edge, or a target that does not exist: the
///   chat ends.
/// - port: a branching step leaves by an exact handle. No such edge: the
///   chat ends - never another edge. A wired edge to a missing node stops
///   the chat where it is (the web throws). Rich steps may name a fallback
///   handle, taken when only it is wired (web goPort).
/// - unknown step types (and a welcome-node reached mid-flow) show nothing
///   and continue along their first edge on the next tick.
/// - jump: to the target node; a missing target ends the chat.
/// - end: a sub-flow call returns to its caller; otherwise the chat is over
///   ("chat-flow-completed").
/// - pacing: typing dots before each displayed step for paceFor(), unless
///   a fixed typingDelay is configured.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/analytics.dart';
import '../providers/analytics_provider.dart';
import '../services/socket_client.dart';
import '../utils/logger.dart';
import 'delight/delight.dart';
import 'errors/conferbot_exceptions.dart';
import 'flow/flow_context.dart';
import 'flow/flow_control.dart';
import 'flow/js.dart' show jsIsoString;
import 'flow/text.dart';
import 'flow/zones.dart' show deviceTimeZone;
import 'nodes/handlers/special_handlers.dart' show HumanHandoverNodeHandler;
import 'nodes/node_handler.dart';
import 'nodes/node_handler_registry.dart';
import 'nodes/node_types.dart';
import 'nodes/node_ui_state.dart';
import 'state/chat_state.dart';

/// What the engine did, step by step (the flow-node spec's `expect`):
/// `enter` {node, type, via}, `shown` {node}, `port` {node, handle, wired},
/// `unsupported` {node, type}, `error` {node, message}, `end`, `crash`
/// {node, reason}.
class FlowTraceEvent {
  final String kind;
  final String? node;
  final String? type;
  final String? via;
  final String? handle;
  final bool? wired;
  final String? message;
  final String? reason;

  const FlowTraceEvent(this.kind, {this.node, this.type, this.via, this.handle, this.wired, this.message, this.reason});
}

/// How the engine runs.
class NodeFlowEngineConfig {
  /// A fixed typing delay (ms) before each displayed step. Unset: the web
  /// widget's pacing (nodeLogic paceFor), by the length of what is said.
  final int? typingDelay;

  /// Steps run without the visitor before the engine stops (a runaway loop guard).
  final int maxNodesPerCycle;

  /// How long a step's handler may take (ms).
  final int nodeProcessingTimeoutMs;

  /// How long an image or video step waits for its media at most (ms, web: 4000).
  final int mediaAdvanceMs;

  /// The bot server origin for /api/v1/bot/:id/* (default: the configured endpoint).
  final String? apiOrigin;

  /// The HTTP client for the bot API (tests script it).
  final http.Client? httpClient;

  /// The page the chat runs on, when the host app has one ({url, referrer}).
  final Map<String, String>? page;

  /// The visitor's IANA time zone (default: the device's).
  final String? visitorTimeZone;

  /// The bot's bookings (the bot data's calendarBookings): a calendar's
  /// taken slots. [NodeFlowEngine.setCalendarBookings] sets them later.
  final List<dynamic>? calendarBookings;

  /// The random source (random-flow).
  final double Function()? random;

  /// The clock (tests use a virtual one).
  final DateTime Function()? now;

  /// Every step entered, port taken, step passed and the end.
  final void Function(FlowTraceEvent event)? onTrace;

  const NodeFlowEngineConfig({
    this.typingDelay,
    this.maxNodesPerCycle = 500,
    this.nodeProcessingTimeoutMs = 90000,
    this.mediaAdvanceMs = 4000,
    this.apiOrigin,
    this.httpClient,
    this.page,
    this.visitorTimeZone,
    this.calendarBookings,
    this.random,
    this.now,
    this.onTrace,
  });
}

/// Steps that draw something, after the typing dots (web nodeTypeCategories DISPLAY_NODE_TYPES).
const Set<String> displayNodeTypes = {
  'two-choices-node',
  'three-choices-node',
  'select-option-node',
  'user-rating-node',
  'quiz-node',
  'user-input-node',
  'user-range-node',
  'welcome-node',
  'message-node',
  'image-node',
  'video-node',
  'audio-node',
  'file-node',
  'ask-name-node',
  'ask-email-node',
  'ask-phone-number-node',
  'ask-number-node',
  'ask-url-node',
  'ask-file-node',
  'ask-location-node',
  'ask-custom-question-node',
  'ask-multiple-questions-node',
  'calendar-node',
  'n-select-option-node',
  'n-check-options-node',
  'n-choices-node',
  'image-choice-node',
  'carousel-node',
  'rating-choice-node',
  'yes-or-no-choice-node',
  'opinion-scale-choice-node',
  'user-redirect-node',
  'html-node',
  'navigate-node',
  'dynamic-choices-node',
  'consent-node',
  'product-card-node',
  'slider-node',
  'datetime-node',
  'ranking-node',
  'otp-node',
  'address-node',
  'matrix-node',
  'ai-extract-node',
  'ai-route-node',
  'kb-answer-node',
  'signature-node',
  'payment-node',
};

/// Question steps that register data.answerVariable when shown (web _nodeCategorizeHelper).
const Set<String> _registersAnswer = {
  'ask-name-node',
  'ask-email-node',
  'ask-phone-number-node',
  'ask-number-node',
  'ask-url-node',
  'ask-location-node',
  'ask-custom-question-node',
  'ask-file-node',
  'calendar-node',
  'n-select-option-node',
  'n-check-options-node',
  'n-choices-node',
  'image-choice-node',
  'rating-choice-node',
  'yes-or-no-choice-node',
  'opinion-scale-choice-node',
  'carousel-node',
  // rich steps (richNodesView categorizeRichNode)
  'dynamic-choices-node',
  'consent-node',
  'product-card-node',
  'slider-node',
  'datetime-node',
  'ranking-node',
  'otp-node',
  'address-node',
  'matrix-node',
  'ai-extract-node',
  'ai-route-node',
  'kb-answer-node',
  'signature-node',
  'payment-node',
};

/// Steps whose media decides when the flow moves on (load, or the cap).
const Set<String> _mediaTypes = {'image-node', 'video-node'};

const Set<String> _flowControlTypes = {loopType, subflowType, runSubflowType, subflowReturnType};

/// Steps that wait for the visitor once drawn.
const Set<String> _userInteractionNodes = {
  'ask-name-node',
  'ask-email-node',
  'ask-phone-number-node',
  'ask-number-node',
  'ask-url-node',
  'ask-location-node',
  'ask-custom-question-node',
  'ask-file-node',
  'ask-multiple-questions-node',
  'n-choices-node',
  'image-choice-node',
  'rating-choice-node',
  'yes-or-no-choice-node',
  'opinion-scale-choice-node',
  'n-select-option-node',
  'n-check-options-node',
  'calendar-node',
  // Waits on the team: agent-accepted / no-agents-available move it on
  'human-handover-node',
  'carousel-node',
  'navigate-node',
  'dynamic-choices-node',
  'consent-node',
  'product-card-node',
  'slider-node',
  'datetime-node',
  'ranking-node',
  'otp-node',
  'address-node',
  'matrix-node',
  'ai-extract-node',
  'ai-route-node',
  'kb-answer-node',
  'signature-node',
  'payment-node',
  'user-input-node',
  'user-range-node',
  'quiz-node',
  'two-choices-node',
  'three-choices-node',
  'select-option-node',
  'user-rating-node',
};

/// Whether a step type waits for the visitor once drawn.
bool requiresUserInteraction(String type) => _userInteractionNodes.contains(type);

/// Core engine that runs the chatbot flow. Uses ChangeNotifier and streams
/// for the chat UI.
class NodeFlowEngine extends ChangeNotifier {
  final FlowSocket? _socket;
  final NodeHandlerRegistry _registry;
  final NodeFlowEngineConfig _config;
  http.Client? _ownClient;

  /// Analytics provider for tracking
  final AnalyticsProvider _analytics = AnalyticsProvider.instance;

  /// The bot's customizations (redactSensitive, chatLeaveMessage...).
  Map<String, dynamic> _customizations = {};

  NodeFlowEngine({
    SocketClient? socketClient,
    FlowSocket? socket,
    NodeHandlerRegistry? registry,
    NodeFlowEngineConfig config = const NodeFlowEngineConfig(),
    Map<String, dynamic>? customizations,
  })  : _socket = socket ?? (socketClient == null ? null : SocketClientFlowSocket(socketClient)),
        _registry = registry ?? NodeHandlerRegistry.instance,
        _config = config {
    _linesSub = _chatState.flowLines.listen(_onFlowLine);
    if (customizations != null) setCustomizations(customizations);
  }

  ChatState get _chatState => ChatState.instance;

  // ========== Flow definition ==========

  final Map<String, Map<String, dynamic>> _nodes = {};
  List<Map<String, dynamic>> _nodeList = [];
  List<Map<String, dynamic>> _edges = [];
  String? _startNodeId;

  /// The flow's nodes as saved.
  List<Map<String, dynamic>> get steps => List.unmodifiable(_nodeList);

  /// The flow's edges as saved.
  List<Map<String, dynamic>> get edges => List.unmodifiable(_edges);

  // ========== Engine state ==========

  bool _isProcessing = false;
  bool _isWaitingForInput = false;
  String? _currentNodeId;
  dynamic _currentUIState;
  ConferBotException? _currentError;
  String? _validationMessage;
  bool _ended = false;

  /// Every step entered, in order (pacing reads the one before).
  final List<Map<String, dynamic>> _visits = [];

  /// Bumped whenever the flow moves: a stale timer or reply does nothing.
  int _moveToken = 0;

  /// The step whose "shown" was already reported for this visit.
  int _shownToken = -1;

  /// Media that finished loading: the step moves on before the cap.
  final Map<String, void Function()> _mediaWaiters = {};
  FlowControlState _flowControl = emptyFlowControl();
  int _nodesProcessedInCycle = 0;

  /// Questions asked, newest last, for "Edit" (only the recent past).
  List<QuestionPoint> _points = [];
  int _pointSeq = 0;

  /// The bot's bookings, from the bot data (a calendar greys out taken slots).
  late List<dynamic> _calendarBookings = _config.calendarBookings ?? const [];
  StreamSubscription<TranscriptEntry>? _linesSub;

  /// Current UI state to render (null while nothing waits for the visitor).
  dynamic get currentUIState => _currentUIState;

  /// Typing dots: the flow is working on a step.
  bool get isProcessing => _isProcessing;

  /// The flow waits for the visitor's answer.
  bool get isWaitingForInput => _isWaitingForInput;

  /// The flow reached its end.
  bool get isFlowComplete => _ended;

  /// Whether the chat has ended (the flow reached its end).
  bool isEnded() => _ended;

  /// The step the flow is on.
  String? get currentNodeId => _currentNodeId;

  /// The current step's data.
  Map<String, dynamic>? get currentNodeData {
    final n = _currentNodeId == null ? null : _nodes[_currentNodeId];
    final d = n?['data'];
    return d is Map ? Map<String, dynamic>.from(d) : (n == null ? null : <String, dynamic>{});
  }

  /// The current step's type.
  String? get currentNodeType => _currentNodeId == null ? null : _nodes[_currentNodeId]?['type']?.toString();

  /// The last error (typed).
  ConferBotException? get currentError => _currentError;

  /// The last error's message for the visitor.
  String? get errorMessage => _currentError?.userMessage;

  /// Why the visitor's last answer was refused (the step still waits).
  String? get validationMessage => _validationMessage;

  /// The visit the flow is on: one more each time a step is entered. The
  /// chat keeps a card's draft while the same visit asks again.
  int get stepVisit => _visits.length;

  /// Question text of the waiting step, if any.
  String? get currentQuestionText {
    final ui = _currentUIState;
    if (ui is SingleChoiceUIState) return ui.questionText;
    if (ui is MultipleChoiceUIState) return ui.questionText;
    if (ui is TextInputUIState) return ui.questionText;
    return null;
  }

  /// A node of the loaded flow by id.
  Map<String, dynamic>? getNode(String nodeId) => _nodes[nodeId];

  // ========== Streams for the chat UI ==========

  final StreamController<dynamic> _uiStateController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get currentUIStateStream => _uiStateController.stream;

  /// A bot line to draw: {text, nodeId, type, imageUrl?, videoUrl?, audioUrl?, fileUrl?, fileName?, html?, link?}.
  final StreamController<Map<String, dynamic>> _botMessageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get botMessageStream => _botMessageController.stream;

  /// The visitor's line to draw: {text, nodeId, type}.
  final StreamController<Map<String, dynamic>> _userMessageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get userMessageStream => _userMessageController.stream;

  final StreamController<bool> _processingController = StreamController<bool>.broadcast();
  Stream<bool> get isProcessingStream => _processingController.stream;

  final StreamController<String?> _errorController = StreamController<String?>.broadcast();
  Stream<String?> get errorMessageStream => _errorController.stream;

  final StreamController<ConferBotException?> _typedErrorController = StreamController<ConferBotException?>.broadcast();
  Stream<ConferBotException?> get errorStream => _typedErrorController.stream;

  final StreamController<bool> _flowCompleteController = StreamController<bool>.broadcast();
  Stream<bool> get isFlowCompleteStream => _flowCompleteController.stream;

  void _onFlowLine(TranscriptEntry e) {
    if (e.nodeId == null) return;
    if (e.by == 'user') {
      if (e.message.isEmpty || _userMessageController.isClosed) return;
      _userMessageController.add({'text': e.message, 'nodeId': e.nodeId, 'type': 'user-message'});
      return;
    }
    if (e.by != 'bot' || _botMessageController.isClosed) return;
    final data = e.data ?? const <String, dynamic>{};
    if (e.message.isEmpty && data.isEmpty) return;
    _botMessageController.add({
      'text': e.message,
      'nodeId': e.nodeId,
      'type': 'bot-message',
      if (e.nodeType != null) 'nodeType': e.nodeType,
      ...data,
    });
    if (e.message.isNotEmpty) _analytics.trackMessage(sender: 'bot', text: e.message);
  }

  // ========== Setup ==========

  /// The bot's customizations (redactSensitive, chatLeaveMessage...).
  void setCustomizations(Map<String, dynamic>? customizations) {
    _customizations = Map<String, dynamic>.from(customizations ?? const {});
    _chatState.setRedactSensitive(_customizations['redactSensitive'] != false);
  }

  /// Initialize the flow engine with bot data from the server.
  void initialize({
    required String chatSessionId,
    required String visitorId,
    required String botId,
    String? workspaceId,
    required List<Map<String, dynamic>> stepsData,
    required List<Map<String, dynamic>> edgesData,
    Map<String, dynamic>? customizations,
  }) {
    _chatState.initialize(chatSessionId: chatSessionId, visitorId: visitorId, botId: botId, workspaceId: workspaceId);
    _chatState.setSteps(stepsData);
    if (customizations != null) setCustomizations(customizations);
    loadFlow(stepsData, edgesData);
    _analytics.startSession(sessionId: chatSessionId, visitorId: visitorId, botId: botId, workspaceId: workspaceId);
  }

  /// Loads a flow (`chatbot.elements[0].nodes` / `.edges`).
  void loadFlow(List<dynamic> nodes, List<dynamic> edges) {
    _nodes.clear();
    _nodeList = nodes.whereType<Map>().map((n) => Map<String, dynamic>.from(n)).toList();
    _edges = edges.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    for (final n in _nodeList) {
      final id = n['id'];
      if (id != null) _nodes[id.toString()] = n;
    }
    _startNodeId = _findStartNode();
    flowLogger.debug('Flow loaded: ${_nodes.length} nodes, start $_startNodeId');
  }

  /// The first welcome-node in nodes[] starts the chat (web index.ts
  /// _findAndDisplayNode). A flow without one starts at a node no edge
  /// leads to, else the first node.
  String? _findStartNode() {
    for (final n in _nodeList) {
      if (n['type'] == 'welcome-node' && n['id'] != null) return n['id'].toString();
    }
    final targets = _edges.map((e) => e['target']?.toString()).toSet();
    for (final id in _nodes.keys) {
      if (!targets.contains(id)) return id;
    }
    return _nodes.keys.isEmpty ? null : _nodes.keys.first;
  }

  // ========== Running ==========

  /// Starts the flow from the beginning.
  Future<void> start() async {
    final startId = _startNodeId;
    if (startId == null) {
      _handleFlowComplete('no_start_node');
      return;
    }
    resetFlow();
    await _enter(_nodes[startId]!, 'start');
  }

  /// Resume from a step by id, as if reached along an edge (a restored session).
  Future<void> resumeFromNode(String nodeId) async {
    _nodesProcessedInCycle = 0;
    _ended = false;
    final node = _nodes[nodeId];
    if (node == null) {
      flowLogger.warning('Resume target node $nodeId not found, starting from beginning');
      await start();
      return;
    }
    await _enter(node, 'edge');
  }

  /// Resets per-run state when starting a new flow.
  void resetFlow() {
    _visits.clear();
    _points = [];
    _ended = false;
    _nodesProcessedInCycle = 0;
    _flowControl = emptyFlowControl();
    _mediaWaiters.clear();
  }

  String _id(Map<String, dynamic> node) => node['id'].toString();
  String _type(Map<String, dynamic> node) => (node['type'] ?? '').toString();
  Map<String, dynamic> _data(Map<String, dynamic> node) {
    final d = node['data'];
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  /// The handler registered for a type.
  NodeHandler? _handlerFor(String type) => _registry.getHandler(type);

  /// Enter a step: record it, pace it, run its handler.
  Future<void> _enter(Map<String, dynamic> node, String via) async {
    if (_ended) return;

    _nodesProcessedInCycle++;
    if (_nodesProcessedInCycle > _config.maxNodesPerCycle) {
      _handleError('Max nodes per cycle exceeded (${_config.maxNodesPerCycle})', _id(node));
      return;
    }

    final id = _id(node);
    final type = _type(node);
    // A question: what "Edit" goes back to, before it is drawn.
    if (Delight.waitsForAnswer(type)) _notePoint(node);
    final token = ++_moveToken;
    _currentNodeId = id;
    _isWaitingForInput = false;
    _validationMessage = null;
    _setProcessing(true);
    _chatState.setCurrentNodeId(id);
    _visits.add(node);
    _trace(FlowTraceEvent('enter', node: id, type: type, via: via));
    _analytics.trackNodeEntry(nodeId: id, nodeType: type, nodeName: _data(node)['name']?.toString() ?? type);

    // The step on the record, with its text as the visitor saw it (web _nodeRecord)
    final renderedText = renderedTextFor(node, _chatState.lookupVariable);
    _chatState.appendRecord({
      ...node,
      '_id': id,
      'id': id,
      'type': type,
      'data': _data(node),
      if (renderedText != null) 'renderedText': renderedText,
      'time': jsIsoString(_now()),
    });

    // A welcome reached again is not a display step there: passed.
    if (type == 'welcome-node' && via != 'start') {
      await _passUnknown(node, token);
      return;
    }

    if (_flowControlTypes.contains(type)) {
      await _runFlowControl(node, token);
      return;
    }

    final handler = _handlerFor(type);
    if (handler == null) {
      await _passUnknown(node, token);
      return;
    }

    if (displayNodeTypes.contains(type)) {
      // A message with no text or an image with no picture: straight on.
      if (isEmptyContentStep(node)) {
        await _next(node, token);
        return;
      }
      _registerAnswerVariables(node);
      final previous = _visits.length >= 2 ? _visits[_visits.length - 2] : null;
      final pace = _config.typingDelay ?? paceFor(previous, node, followsAutoAdvanceStep(previous?['type']));
      if (pace > 0) {
        _setProcessing(true);
        await _delay(pace);
        if (token != _moveToken || _ended) return;
      }
      // Drawn now (web: the message sound plays as the step is drawn).
      _shownToken = token;
      _trace(FlowTraceEvent('shown', node: id));
    }

    NodeResult result;
    try {
      result = await _runHandler(handler, node, via, token);
    } catch (e, st) {
      flowLogger.error('Error processing node $id: $e', e, st);
      _handleError('$e', id);
      return;
    }
    if (token != _moveToken || _ended) return;
    await _handleNodeResult(result, node, token);
  }

  void _notePoint(Map<String, dynamic> node) {
    _points.add(QuestionPoint._(
      id: ++_pointSeq,
      nodeId: _id(node),
      type: _type(node),
      stepsLen: _visits.length,
      recordLen: _chatState.record.length,
      snap: _chatState.snapshot(),
      flowControl: restoreFlowControl(_flowControl.toJson()),
    ));
    if (_points.length > Delight.maxQuestionPoints) _points = _points.sublist(_points.length - Delight.maxQuestionPoints);
  }

  /// The questions asked so far that can still be gone back to, oldest first.
  List<QuestionPoint> get questionPoints => List.unmodifiable(_points);

  /// The step types run since a question (it excluded); "agent" when a
  /// person or the AI agent has been in the conversation since (what they
  /// saw stays). Web index.ts typesSince.
  List<String> typesSince(QuestionPoint point) {
    final types = [
      for (final n in _visits.skip(point.stepsLen + 1)) _type(n),
    ];
    final record = _chatState.record;
    final agent = record.skip(math.min(point.recordLen, record.length)).any((r) {
      final kind = r.type ?? r.shape;
      return kind.startsWith('agent') || r.shape.startsWith('agent');
    });
    return agent ? [...types, 'agent'] : types;
  }

  /// "Edit": the conversation as it was when the question was asked, and the
  /// question asked again exactly as the forward path asks it (web index.ts
  /// _rewindToQuestion). False when the point is gone or the chat ended.
  Future<bool> rewindTo(int pointId) async {
    final i = _points.indexWhere((p) => p.id == pointId);
    if (i < 0) return false;
    final point = _points[i];
    final node = _nodes[point.nodeId];
    if (node == null || _ended) return false;
    _moveToken++;
    _chatState.restore(point.snap);
    if (_visits.length > point.stepsLen) _visits.removeRange(point.stepsLen, _visits.length);
    _flowControl = restoreFlowControl(point.flowControl.toJson());
    _points = _points.sublist(0, i);
    _mediaWaiters.clear();
    _ended = false;
    _isWaitingForInput = false;
    _validationMessage = null;
    _nodesProcessedInCycle = 0;
    _sendResponseToServer();
    await _enter(node, 'rewind');
    return true;
  }

  /// The bot's bookings, from the bot data (a calendar's taken slots).
  void setCalendarBookings(dynamic bookings) => _calendarBookings = bookings is List ? List.of(bookings) : const [];

  /// A question step registers {nodeId, key, value: null} when shown.
  void _registerAnswerVariables(Map<String, dynamic> node) {
    final d = _data(node);
    final id = _id(node);
    if (_type(node) == NodeTypes.askMultiple) {
      final qs = d['questions'];
      if (qs is List) {
        for (var i = 0; i < qs.length; i++) {
          final q = qs[i];
          final key = q is Map ? q['answerVariable'] : null;
          if (key != null && key.toString().isNotEmpty) _chatState.registerAnswerVariable('$id$i', key.toString());
        }
      }
      return;
    }
    final key = d['answerVariable'];
    if (_registersAnswer.contains(_type(node)) && key != null && key.toString().isNotEmpty) {
      _chatState.registerAnswerVariable(id, key.toString());
    }
  }

  /// Runs a step's handler with the engine's context, under the step timeout.
  Future<NodeResult> _runHandler(NodeHandler handler, Map<String, dynamic> node, String via, int token) {
    final flowNode = _flowNode(node, via, token);
    final timeout = Completer<NodeResult>();
    final timer = Timer(Duration(milliseconds: _config.nodeProcessingTimeoutMs), () {
      if (!timeout.isCompleted) {
        timeout.complete(NodeResult.error('Node processing timed out after ${_config.nodeProcessingTimeoutMs}ms'));
      }
    });
    return Future.any([handler.handle(flowNode, _chatState), timeout.future]).whenComplete(timer.cancel);
  }

  FlowNode _flowNode(Map<String, dynamic> node, String via, int token) =>
      FlowNode(id: _id(node), type: _type(node), data: _data(node), raw: node, ctx: _contextFor(node, via, token));

  DateTime _now() => (_config.now ?? DateTime.now)();

  http.Client get _client => _config.httpClient ?? (_ownClient ??= http.Client());

  String get _apiOrigin => _config.apiOrigin ?? ConferBotEndpoints.apiOrigin;

  /// What a handler may use: the bot API, the socket, timers, this step's edges.
  FlowContext _contextFor(Map<String, dynamic> node, String via, int token) {
    final id = _id(node);
    final state = _chatState;
    final botId = state.botId ?? '';
    final sessionId = state.chatSessionId ?? '';
    final index = _visits.lastIndexOf(node);
    return FlowContext(
      botId: botId,
      sessionId: sessionId,
      api: (path, body, {timeoutMs}) => postBotApi(_client, _apiOrigin, botId, path, body, timeoutMs: timeoutMs),
      upload: (file) => uploadBotMedia(_client, _apiOrigin, botId, sessionId, state.visitorId ?? sessionId, file),
      emit: _emit,
      on: _onSocket,
      typing: (ms) async {
        if (ms > 0) {
          _setProcessing(true);
          await _delay(ms);
        }
      },
      delay: _delay,
      edges: () => _edges.where((e) => e['source']?.toString() == id).toList(),
      edgesOf: (other) => _edges.where((e) => e['source']?.toString() == other).toList(),
      wired: (handle) => _edges.any((e) => e['source']?.toString() == id && e['sourceHandle'] == handle),
      via: via,
      stepIndex: index < 0 ? 0 : index,
      random: _config.random ?? _defaultRandom,
      now: _now,
      customizations: _customizations,
      page: _config.page,
      calendarBookings: _calendarBookings,
      visitorTimeZone: _config.visitorTimeZone ?? deviceTimeZone(),
      respond: (response) {
        if (_currentNodeId == id && _isWaitingForInput) submitResponse(response);
      },
      shown: () {
        if (_shownToken != token && token == _moveToken) {
          _shownToken = token;
          _trace(FlowTraceEvent('shown', node: id));
        }
      },
      isStale: () => token != _moveToken && _currentNodeId != id,
      node: (other) => _nodes[other],
      httpClient: _client,
    );
  }

  /// Handles what a step's handler returned.
  Future<void> _handleNodeResult(NodeResult result, Map<String, dynamic> node, int token) async {
    switch (result) {
      case DisplayUIResult():
        await _handleDisplayUI(result.uiState, result.awaitInput, node, token);
      case ProceedResult():
        await _handleProceed(result.nextNodeId, result.data, node, token);
      case DelayedProceedResult():
        await _delay(result.delayMs);
        if (token != _moveToken || _ended) return;
        await _handleProceed(result.nextNodeId, result.data, node, token);
      case JumpToResult():
        _sendResponseToServer();
        await _jump(result.targetNodeId, token);
      case InvalidResult():
        await _handleInvalid(result.message, node, token, result.uiState, result.inCard);
      case EndResult():
        await _end('completed');
      case ErrorResult():
        _handleError(result.message, _id(node));
    }
  }

  /// Whether the step waits for the visitor once drawn.
  bool _awaitsInput(Map<String, dynamic> node, bool awaitInput) => awaitInput || requiresUserInteraction(_type(node));

  Future<void> _handleDisplayUI(Object uiState, bool awaitInput, Map<String, dynamic> node, int token) async {
    final id = _id(node);
    if (_shownToken != token && displayNodeTypes.contains(_type(node))) {
      _shownToken = token;
      _trace(FlowTraceEvent('shown', node: id));
    }

    if (_awaitsInput(node, awaitInput)) {
      _isWaitingForInput = true;
      _setProcessing(false, notify: false);
      _setUIState(uiState);
      return;
    }

    // Shown and moving on by itself: the step's own line is already in the
    // chat (the handler said it); no card waits.
    _setProcessing(false, notify: false);
    _setUIState(null);
    _analytics.trackNodeExit(exitType: NodeExitType.proceeded);
    _sendResponseToServer();
    if (_mediaTypes.contains(_type(node))) {
      await _waitForMedia(id, _config.mediaAdvanceMs);
      if (token != _moveToken || _ended) return;
    }
    await _next(node, token);
  }

  /// Resolves when the media loads ([mediaSettled]) or after `capMs`.
  Future<void> _waitForMedia(String nodeId, int capMs) {
    final done = Completer<void>();
    late Timer timer;
    void finish() {
      timer.cancel();
      _mediaWaiters.remove(nodeId);
      if (!done.isCompleted) done.complete();
    }

    timer = Timer(Duration(milliseconds: capMs < 0 ? 0 : capMs), finish);
    _mediaWaiters[nodeId] = finish;
    return done.future;
  }

  /// An image or video step's media loaded (or failed): the flow moves on
  /// now instead of at the cap (web: load / loadedmetadata / error).
  void mediaSettled(String nodeId) => _mediaWaiters[nodeId]?.call();

  Future<void> _handleProceed(String? nextNodeId, Map<String, dynamic>? data, Map<String, dynamic> node, int token) async {
    _setProcessing(false, notify: false);
    if (data?['flowComplete'] == true) {
      await _end(data?['completionStatus']?.toString() ?? 'completed');
      return;
    }
    _sendResponseToServer();
    final effective = nextNodeId ?? (data?['__targetPort'] != null ? '__port:${data!['__targetPort']}' : null);
    if (effective == null) {
      await _next(node, token);
    } else if (effective.startsWith('__port:')) {
      await _port(node, effective.substring(7), data?['fallbackPort']?.toString(), token);
    } else {
      await _jump(effective, token);
    }
  }

  // ========== Routing ==========

  /// The FIRST edge from the step, whatever its handle; none ends the chat.
  Future<void> _next(Map<String, dynamic> node, int token) async {
    if (_ended || token != _moveToken) return;
    final id = _id(node);
    Map<String, dynamic>? edge;
    for (final e in _edges) {
      if (e['source']?.toString() == id) {
        edge = e;
        break;
      }
    }
    if (edge != null) _chatState.appendRecord({...edge, '_id': edge['id'], 'time': jsIsoString(_now())});
    final target = edge == null ? null : _nodes[edge['target']?.toString()];
    if (edge != null && target != null) {
      final h = edge['sourceHandle'];
      await _enter(target, h != null && h.toString().isNotEmpty ? 'edge:$h' : 'edge');
    } else {
      await _end('no_next_node');
    }
  }

  /// The edge from exactly this handle; none ends the chat.
  Future<void> _port(Map<String, dynamic> node, String handle, String? fallback, int token) async {
    if (_ended || token != _moveToken) return;
    final id = _id(node);
    bool wired(String h) => _edges.any((e) => e['source']?.toString() == id && e['sourceHandle'] == h);
    final h = fallback != null && !wired(handle) && wired(fallback) ? fallback : handle;
    Map<String, dynamic>? edge;
    for (final e in _edges) {
      if (e['source']?.toString() == id && e['sourceHandle'] == h) {
        edge = e;
        break;
      }
    }
    _trace(FlowTraceEvent('port', node: id, handle: h, wired: edge != null));
    if (edge == null) {
      await _end('no_next_node');
      return;
    }
    _chatState.appendRecord({...edge, '_id': edge['id'], 'time': jsIsoString(_now())});
    final target = _nodes[edge['target']?.toString()];
    if (target == null) {
      // The web throws on nextNode.type here: the chat stops where it is.
      _trace(FlowTraceEvent('crash', node: id, reason: 'edge target missing'));
      _isWaitingForInput = false;
      _handleError('Edge ${edge['id']} leads to a missing node (${edge['target']})', id);
      return;
    }
    await _enter(target, 'port:$h');
  }

  /// To a node by id; a missing target ends the chat.
  Future<void> _jump(String targetNodeId, int token) async {
    if (_ended || token != _moveToken) return;
    final target = targetNodeId.isEmpty ? null : _nodes[targetNodeId];
    if (target == null) {
      await _end('jump_target_missing');
      return;
    }
    await _enter(target, 'jump');
  }

  /// A step type this engine does not run: nothing shown, then its first edge.
  Future<void> _passUnknown(Map<String, dynamic> node, int token) async {
    flowLogger.warning('step "${_type(node)}" is not supported here; continuing the flow');
    _trace(FlowTraceEvent('unsupported', node: _id(node), type: _type(node)));
    _analytics.trackNodeExit(exitType: NodeExitType.skipped);
    await _delay(0);
    if (token != _moveToken || _ended) return;
    await _next(node, token);
  }

  // ========== Loops and sub-flows (web flowControlRun.ts) ==========

  dynamic _flowLookup(String key) => _chatState.lookupVariable(key);

  void _setVars(Map<String, dynamic> vars) => vars.forEach((k, v) => _chatState.saveVariableByName(k, v));

  /// A trail entry on the step's latest record ("Loop 3 of 5").
  void _trail(Map<String, dynamic> node, Map<String, dynamic> extra) {
    final record = _chatState.record;
    for (var i = record.length - 1; i >= 0; i--) {
      final r = record[i].toJson();
      if (r['id'] == _id(node) && r['type'] == _type(node) && r['shape'] == null) {
        _chatState.addRecord({...r, ...extra});
        return;
      }
    }
  }

  Future<void> _runFlowControl(Map<String, dynamic> node, int token) async {
    final d = _data(node);
    final id = _id(node);
    switch (_type(node)) {
      case loopType:
        final step = stepLoop(id, d, _flowControl, _flowLookup);
        _setVars(step.vars);
        _trail(node, {
          'loop': {...step.trail.toJson(), 'text': loopTrailText(step.trail)},
        });
        _sendResponseToServer();
        await _delay(0);
        if (token != _moveToken || _ended) return;
        await _port(node, step.handle, null, token);
        return;
      case runSubflowType:
        final call = callSubflow(node, _nodeList, _flowControl, _flowLookup);
        if (!call.ok) {
          _trail(node, {
            'subflow': {'name': call.name ?? '', 'error': call.error},
          });
          _sendResponseToServer();
          await _delay(0);
          if (token != _moveToken || _ended) return;
          final wiredError = _edges.any((e) => e['source']?.toString() == id && e['sourceHandle'] == runErrorHandle);
          await _port(node, wiredError ? runErrorHandle : 'source', null, token);
          return;
        }
        _setVars(call.vars);
        _trail(node, {
          'subflow': {'name': call.name, 'inputs': call.vars, 'depth': call.frame?.depth, 'text': 'Ran sub-flow ${call.name}'},
        });
        _sendResponseToServer();
        await _delay(0);
        if (token != _moveToken || _ended) return;
        await _jump(call.startId ?? '', token);
        return;
      case subflowType:
        _trail(node, {
          'subflow': {'name': subflowName(node), 'entered': true},
        });
        await _delay(0);
        if (token != _moveToken || _ended) return;
        await _port(node, 'source', null, token);
        return;
      case subflowReturnType:
        if (await _returnFromSubflowPath(token)) return;
        await _delay(0);
        if (token != _moveToken || _ended) return;
        await _next(node, token);
        return;
    }
  }

  /// The end of a path inside a sub-flow: copy the outputs back and carry
  /// on from Run sub-flow's "source" edge (or one with no handle). True when
  /// it carried on.
  Future<bool> _returnFromSubflowPath(int token) async {
    var ret = returnFromSubflow(_flowControl, _flowLookup);
    while (ret != null) {
      _setVars(ret.vars);
      final runNodeId = ret.frame.runNodeId;
      Map<String, dynamic>? edge;
      for (final e in _edges) {
        final h = e['sourceHandle'];
        if (e['source']?.toString() == runNodeId && (h == 'source' || h == null || h == '')) {
          edge = e;
          break;
        }
      }
      final target = edge?['target']?.toString();
      if (target != null && target.isNotEmpty) {
        _sendResponseToServer();
        await _delay(0);
        if (token != _moveToken || _ended) return true;
        await _jump(target, token);
        return true;
      }
      ret = returnFromSubflow(_flowControl, _flowLookup);
    }
    return false;
  }

  // ========== The visitor's answer ==========

  /// Submits the visitor's answer for the waiting step. Ignored when no step
  /// waits; typed text is trimmed and an empty send is ignored (web composer).
  Future<void> submitResponse(dynamic response) async {
    final id = _currentNodeId;
    if (!_isWaitingForInput || id == null) {
      flowLogger.debug('Not waiting for input, ignoring response');
      return;
    }
    if (response is String && response.trim().isEmpty) return;
    final node = _nodes[id];
    if (node == null) {
      _handleError('Current node not found: $id', id);
      return;
    }
    final handler = _handlerFor(_type(node));

    _isWaitingForInput = false;
    _validationMessage = null;
    _nodesProcessedInCycle = 0;
    _setProcessing(true);
    final token = _moveToken;

    try {
      final pending = handler?.handleResponse(response, _flowNode(node, 'edge', token), _chatState);
      final NodeResult result = pending == null ? NodeResult.next() : await pending;
      if (token != _moveToken || _ended) return;
      if (result is! DisplayUIResult && result is! InvalidResult) {
        _analytics.trackNodeExit(exitType: NodeExitType.proceeded, userInput: response);
      }
      _sendResponseToServer();
      await _handleNodeResult(result, node, token);
    } catch (e, st) {
      flowLogger.error('Error handling response: $e', e, st);
      _handleError('$e', id);
    }
  }

  /// A refused answer: say why, keep waiting at the step. A typed answer's
  /// reason comes as a bot bubble after 700 ms of typing (web helpers
  /// _displayErrorMessage); a card shows its own at once.
  Future<void> _handleInvalid(String message, Map<String, dynamic> node, int token, Object? uiState, bool inCard) async {
    final id = _id(node);
    _trace(FlowTraceEvent('error', node: id, message: message));
    if (message.isNotEmpty && !inCard) {
      _setProcessing(true);
      await _delay(700);
      if (token != _moveToken || _ended) return;
      _chatState.addBotMessage(bubbleText(message), id, 'validation-error');
    }
    _validationMessage = plainText(message);
    _isWaitingForInput = true;
    _setProcessing(false, notify: false);
    _setUIState(uiState ?? _currentUIState);
  }

  // ========== Server ==========

  bool _emit(String event, dynamic payload) {
    final s = _socket;
    if (s == null) return false;
    try {
      s.emit(event, payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  void Function() _onSocket(String event, void Function(dynamic payload) listener) {
    final s = _socket;
    if (s == null) return () {};
    return s.on(event, listener);
  }

  /// Sends the chat state to the server (web `response-record`).
  void _sendResponseToServer() {
    final s = _socket;
    if (s == null) return;
    final data = _chatState.buildResponseData();
    // Never emit without a session id - the server would file the record
    // under a shared no-session document.
    if (data['chatSessionId'] == null) return;
    s.sendResponseRecord(data);
  }

  /// A message the server pushed (bot-response): its text is drawn.
  void handleServerMessage(Map<String, dynamic> message) {
    final text = message['text']?.toString();
    if (text != null && text.isNotEmpty && !_botMessageController.isClosed) {
      _botMessageController.add({'text': text, 'nodeId': message['_id']?.toString() ?? '', 'type': 'bot-message'});
      _analytics.trackMessage(sender: 'bot', text: text);
    }
  }

  // ========== Errors and the end ==========

  void _handleError(String message, [String? nodeId]) {
    flowLogger.error('[NodeFlowEngine] $message (node $nodeId)');
    _currentError = NodeProcessingException(message: message, code: 'NODE_ERROR', nodeId: nodeId);
    _isProcessing = false;
    _errorController.add(_currentError?.userMessage);
    _typedErrorController.add(_currentError);
    _processingController.add(false);
    _analytics.trackNodeExit(exitType: NodeExitType.error);
    notifyListeners();
  }

  /// Clear the current error.
  void clearError() {
    _currentError = null;
    _errorController.add(null);
    _typedErrorController.add(null);
    notifyListeners();
  }

  /// The end of a path: a sub-flow returns to its caller; otherwise the
  /// chat is over (web index.ts: hasChatEnded, record sent, chat-flow-completed).
  Future<void> _end(String reason) async {
    if (_ended) return;
    if (_flowControl.stack.isNotEmpty && await _returnFromSubflowPath(_moveToken)) return;
    _handleFlowComplete(reason);
  }

  void _handleFlowComplete(String reason) {
    if (_ended) return;
    flowLogger.debug('Flow complete: $reason');
    _ended = true;
    _isWaitingForInput = false;
    _isProcessing = false;
    _currentUIState = null;
    _chatState.markConversationComplete(reason);
    _sendResponseToServer();
    _emit('chat-flow-completed', {'chatSessionId': _chatState.chatSessionId});
    _trace(const FlowTraceEvent('end'));
    _uiStateController.add(null);
    _processingController.add(false);
    _flowCompleteController.add(true);
    _analytics.endSession();
    notifyListeners();
  }

  void _trace(FlowTraceEvent event) {
    try {
      _config.onTrace?.call(event);
    } catch (_) {
      // a listener's error never stops the flow
    }
  }

  // ========== The handover step ==========

  /// Waiting on its handover step (for a person, or after nobody came).
  bool get isAtHandover => currentNodeType == NodeTypes.humanHandover;

  /// The handover step's data while the flow is on it (its fallbackMessage...).
  Map<String, dynamic>? get handoverNodeData => isAtHandover ? currentNodeData : null;

  HumanHandoverNodeHandler? get _handoverHandler {
    final h = _registry.getHandler(NodeTypes.humanHandover);
    return h is HumanHandoverNodeHandler ? h : null;
  }

  /// A restored chat back on its handover step, without running the step
  /// again (which would ask for a person a second time: a second ticket):
  /// its wait card ([uiState]), or no card while a person has the chat
  /// (null). The step's handler is told where it stands, so the chat ending
  /// carries the flow on. False when the step is not in this flow.
  bool waitAt(String nodeId, dynamic uiState) {
    if (!_nodes.containsKey(nodeId)) return false;
    _moveToken++;
    _ended = false;
    _currentNodeId = nodeId;
    _isWaitingForInput = true;
    _chatState.setCurrentNodeId(nodeId);
    _handoverHandler?.restoreAt(nodeId, uiState is HumanHandoverUIState ? uiState.state : HandoverState.agentConnected);
    _setProcessing(false, notify: false);
    _setUIState(uiState);
    return true;
  }

  /// The handover step's card goes (a person joined, or nobody could).
  void clearHandoverUI() {
    if (_currentUIState is HumanHandoverUIState) _setUIState(null);
  }

  /// Nobody came and the visitor left a message or skipped it: the flow
  /// carries on from the handover step, as the web widget does.
  void continueAfterHandover() {
    if (!isAtHandover) return;
    _setUIState(null);
    _isWaitingForInput = true;
    submitResponse(const {'action': 'continue'});
  }

  /// A person accepted the handover.
  void handleAgentAccepted(String agentName) {
    final id = _currentNodeId;
    if (id == null || !isAtHandover) return;
    _analytics.trackInteraction(type: 'agent_accepted', data: {'agentName': agentName});
    _handoverHandler?.onAgentAccepted(id, agentName);
    _setUIState(HumanHandoverUIState(state: HandoverState.agentConnected, agentName: agentName, nodeId: id));
  }

  /// Nobody is free (the handover step draws its fallback itself).
  void handleNoAgentsAvailable() {
    if (_currentNodeId == null || !isAtHandover) return;
    _analytics.trackInteraction(type: 'no_agents_available', data: {});
  }

  /// The live chat ended: a post-chat survey, else the flow carries on
  /// from the handover step, as the web widget does.
  void handleChatEnded() {
    final id = _currentNodeId;
    final node = id == null ? null : _nodes[id];
    if (node == null || !isAtHandover) return;
    _analytics.trackInteraction(type: 'chat_ended', data: {});
    final handler = _handoverHandler;
    if (handler == null) return;
    final token = _moveToken;
    _isWaitingForInput = false;
    _handleNodeResult(handler.onChatEnded(id!, _data(node)), node, token);
  }

  // ========== State ==========

  void _setUIState(dynamic state) {
    _currentUIState = state;
    _uiStateController.add(state);
    notifyListeners();
  }

  void _setProcessing(bool processing, {bool notify = true}) {
    if (_isProcessing == processing) return;
    _isProcessing = processing;
    _processingController.add(processing);
    if (notify) notifyListeners();
  }

  Future<void> _delay(int ms) => Future<void>.delayed(Duration(milliseconds: ms < 0 ? 0 : ms));

  static double _defaultRandom() => _rng.nextDouble();

  /// Reset the engine for a new conversation.
  void reset() {
    _analytics.endSession();
    _moveToken++;
    _isProcessing = false;
    _isWaitingForInput = false;
    _currentNodeId = null;
    _currentUIState = null;
    _currentError = null;
    _validationMessage = null;
    _nodes.clear();
    _nodeList = [];
    _edges = [];
    _startNodeId = null;
    resetFlow();
    _chatState.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    _analytics.endSession();
    _moveToken++;
    _linesSub?.cancel();
    _ownClient?.close();
    _uiStateController.close();
    _botMessageController.close();
    _userMessageController.close();
    _processingController.close();
    _errorController.close();
    _typedErrorController.close();
    _flowCompleteController.close();
    super.dispose();
  }
}

final _rng = _Lcg();

class _Lcg {
  int _seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x80000000;
  }
}

/// The SDK's socket as the flow uses it.
class SocketClientFlowSocket implements FlowSocket {
  final SocketClient client;

  SocketClientFlowSocket(this.client);

  @override
  void emit(String event, dynamic payload) => client.emit(event, payload);

  @override
  void Function() on(String event, void Function(dynamic payload) listener) {
    void handler(dynamic data) => listener(data);
    client.on(event, handler);
    return () => client.off(event, handler);
  }

  @override
  void sendResponseRecord(Map<String, dynamic> responseData) {
    final sessionId = responseData['chatSessionId']?.toString();
    if (sessionId == null) return;
    client.sendResponseRecord(
      chatSessionId: sessionId,
      record: responseData['record'],
      answerVariables: responseData['answerVariables'] as List<dynamic>?,
      extra: responseData,
    );
  }
}

/// A question the visitor may go back to (web index.ts _noteQuestionPoint):
/// kept each time a step that waits for an answer is entered, before it is
/// drawn, with a copy of the conversation's state as it was.
class QuestionPoint {
  /// Unique per point (a step asked twice has two).
  final int id;
  final String nodeId;
  final String type;

  /// Steps entered before this question.
  final int stepsLen;

  /// The record's length before the question.
  final int recordLen;
  final ChatSnapshot snap;
  final FlowControlState flowControl;

  const QuestionPoint._({
    required this.id,
    required this.nodeId,
    required this.type,
    required this.stepsLen,
    required this.recordLen,
    required this.snap,
    required this.flowControl,
  });
}
