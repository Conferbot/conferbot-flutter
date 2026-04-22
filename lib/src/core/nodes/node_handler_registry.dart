import 'node_types.dart';

// Consolidated handler imports (legacy_handlers exports base classes)
import 'handlers/legacy_handlers.dart';
import 'handlers/display_handlers.dart';
import 'handlers/ask_question_handlers.dart';
import 'handlers/choice_handlers.dart';
import 'handlers/logic_handlers.dart';
import 'handlers/integration_handlers.dart';
import 'handlers/special_handlers.dart';

/// Registry of all node handlers
/// Maps node types to their handlers
///
/// This is a singleton that manages all 58 node handlers.
/// Use [NodeHandlerRegistry.instance] to access the registry.
class NodeHandlerRegistry {
  NodeHandlerRegistry._internal() {
    _registerAllHandlers();
  }

  static final NodeHandlerRegistry _instance = NodeHandlerRegistry._internal();

  /// Singleton instance of the registry
  static NodeHandlerRegistry get instance => _instance;

  final Map<String, NodeHandler> _handlers = {};

  void _registerAllHandlers() {
    // ==================== DISPLAY NODE HANDLERS ====================

    // Legacy nodes (v1)
    _register(TwoChoicesNodeHandler());
    _register(ThreeChoicesNodeHandler());
    _register(SelectOptionNodeHandler());
    _register(UserRatingNodeHandler());
    _register(QuizNodeHandler());
    _register(UserInputNodeHandler());
    _register(UserRangeNodeHandler());

    // Welcome node
    _register(WelcomeNodeHandler());

    // Send response nodes (v2)
    _register(MessageNodeHandler());
    _register(ImageNodeHandler());
    _register(VideoNodeHandler());
    _register(AudioNodeHandler());
    _register(FileNodeHandler());

    // Ask question nodes (v2)
    _register(AskNameNodeHandler());
    _register(AskEmailNodeHandler());
    _register(AskPhoneNodeHandler());
    _register(AskNumberNodeHandler());
    _register(AskUrlNodeHandler());
    _register(AskFileNodeHandler());
    _register(AskLocationNodeHandler());
    _register(AskCustomNodeHandler());
    _register(AskMultipleQuestionsNodeHandler());
    _register(CalendarNodeHandler());
    _register(NSelectOptionNodeHandler());
    _register(NCheckOptionsNodeHandler());

    // Flow operation nodes (v2)
    _register(NChoicesNodeHandler());
    _register(ImageChoiceNodeHandler());
    _register(RatingChoiceNodeHandler());
    _register(YesOrNoChoiceNodeHandler());
    _register(OpinionScaleChoiceNodeHandler());

    // Special display nodes (v2)
    _register(UserRedirectNodeHandler());
    _register(HtmlNodeHandler());
    _register(NavigateNodeHandler());

    // ==================== LOGIC NODE HANDLERS ====================

    _register(ConditionNodeHandler());
    _register(BooleanLogicNodeHandler());
    _register(RandomFlowNodeHandler());
    _register(MathOperationNodeHandler());
    _register(VariableNodeHandler());
    _register(JumpToNodeHandler());
    _register(BusinessHoursNodeHandler());

    // ==================== INTEGRATION NODE HANDLERS ====================

    _register(EmailNodeHandler());
    _register(WebhookNodeHandler());
    _register(GptNodeHandler());
    _register(ZapierNodeHandler());
    _register(GoogleSheetsNodeHandler());
    _register(GmailNodeHandler());
    _register(GoogleCalendarNodeHandler());
    _register(GoogleMeetNodeHandler());
    _register(GoogleDriveNodeHandler());
    _register(GoogleDocsNodeHandler());
    _register(SlackNodeHandler());
    _register(DiscordNodeHandler());
    _register(AirtableNodeHandler());
    _register(HubspotNodeHandler());
    _register(NotionNodeHandler());
    _register(ZohoCrmNodeHandler());
    _register(StripeNodeHandler());

    // ==================== SPECIAL FLOW NODE HANDLERS ====================

    _register(DelayNodeHandler());
    _register(HumanHandoverNodeHandler());
  }

  /// Register a handler internally
  void _register(NodeHandler handler) {
    _handlers[handler.nodeType] = handler;
  }

  /// Register a custom handler (for extensions)
  void register(NodeHandler handler) {
    _handlers[handler.nodeType] = handler;
  }

  /// Get handler for node type
  /// Returns null if no handler is registered for the type
  NodeHandler? getHandler(String nodeType) {
    return _handlers[nodeType];
  }

  /// Check if handler exists for node type
  bool hasHandler(String nodeType) {
    return _handlers.containsKey(nodeType);
  }

  /// Get all registered node types
  Set<String> getRegisteredTypes() {
    return _handlers.keys.toSet();
  }

  /// Get count of registered handlers
  int get handlerCount => _handlers.length;

  /// Validate that all expected node types have handlers
  /// Returns list of missing handler types
  List<String> validateHandlers() {
    final missing = <String>[];
    for (final nodeType in NodeTypes.allNodes) {
      if (!hasHandler(nodeType)) {
        missing.add(nodeType);
      }
    }
    return missing;
  }

  /// Check if registry is complete (all 58 handlers registered)
  bool get isComplete => handlerCount == 58 && validateHandlers().isEmpty;
}
