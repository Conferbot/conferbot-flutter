import 'node_handler.dart';
import 'handlers/handlers.dart' show registerAllHandlers;

/// The handlers by node type. [NodeHandlerRegistry.instance] holds every
/// built-in handler; a new registry starts empty (tests, custom engines).
class NodeHandlerRegistry {
  NodeHandlerRegistry();

  /// A registry with every built-in handler.
  factory NodeHandlerRegistry.withAll() {
    final r = NodeHandlerRegistry();
    registerAllHandlers(r);
    return r;
  }

  static NodeHandlerRegistry? _instance;

  /// The shared registry with every built-in handler.
  static NodeHandlerRegistry get instance => _instance ??= NodeHandlerRegistry.withAll();

  final Map<String, NodeHandler> _handlers = {};

  /// Register a handler (the last one for a type wins).
  void register(NodeHandler handler) => _handlers[handler.nodeType] = handler;

  /// Register several handlers.
  void registerAll(Iterable<NodeHandler> handlers) => handlers.forEach(register);

  /// The handler for a type, or null.
  NodeHandler? getHandler(String nodeType) => _handlers[nodeType];

  /// Whether a type has a handler.
  bool hasHandler(String nodeType) => _handlers.containsKey(nodeType);

  /// Every registered type.
  Set<String> getRegisteredTypes() => _handlers.keys.toSet();

  /// How many handlers are registered.
  int get handlerCount => _handlers.length;
}
