/// The step handler interface (as the React Native SDK's NodeHandler,
/// src/core/nodes/NodeHandler.ts). A handler runs one node type: [handle]
/// when the flow reaches the step, [handleResponse] with the visitor's
/// answer while the step waits.
library;

import '../flow/flow_context.dart';
import '../state/chat_state.dart';
import 'node_result.dart';

export '../flow/flow_context.dart' show FlowContext, ApiReply, UploadFile, UploadResult, FlowSocket;
export 'node_result.dart';

/// A step as the builder saved it, with the engine's context.
class FlowNode {
  final String id;
  final String type;

  /// `node.data` as saved (never null).
  final Map<String, dynamic> data;

  /// The whole saved node.
  final Map<String, dynamic> raw;

  /// What the handler may use: the bot API, the socket, timers, edges.
  final FlowContext ctx;

  FlowNode({
    required this.id,
    required this.type,
    Map<String, dynamic>? data,
    Map<String, dynamic>? raw,
    FlowContext? ctx,
  })  : data = data ?? <String, dynamic>{},
        raw = raw ?? {'id': id, 'type': type, 'data': data ?? <String, dynamic>{}},
        ctx = ctx ?? FlowContext.standalone();

  /// A saved node (`{id, type, data}`), with a context.
  factory FlowNode.fromMap(Map<String, dynamic> node, {FlowContext? ctx}) {
    final d = node['data'];
    return FlowNode(
      id: (node['id'] ?? node['_id'] ?? '').toString(),
      type: (node['type'] ?? '').toString(),
      data: d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{},
      raw: node,
      ctx: ctx,
    );
  }
}

/// A handler for one node type.
abstract class NodeHandler {
  /// The node type this handler runs.
  String get nodeType;

  /// The flow reached the step.
  Future<NodeResult> handle(FlowNode node, ChatState state);

  /// The visitor's answer while the step waits. Null: the step takes no
  /// answer and the flow moves on along its first edge.
  Future<NodeResult>? handleResponse(dynamic response, FlowNode node, ChatState state) => null;
}

/// A handler with the small readers the steps share.
abstract class BaseNodeHandler extends NodeHandler {
  /// A string from the step's data ("" or [fallback] when missing).
  String getString(Map<String, dynamic> data, String key, [String fallback = '']) {
    final v = data[key];
    if (v is String) return v;
    if (v != null) return v.toString();
    return fallback;
  }

  /// A number from the step's data.
  num getNumber(Map<String, dynamic> data, String key, [num fallback = 0]) {
    final v = data[key];
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim()) ?? fallback;
    return fallback;
  }

  /// A whole number from the step's data.
  int getInt(Map<String, dynamic> data, String key, [int fallback = 0]) => getNumber(data, key, fallback).toInt();

  /// A flag from the step's data.
  bool getBoolean(Map<String, dynamic> data, String key, [bool fallback = false]) {
    final v = data[key];
    if (v is bool) return v;
    if (v == 'true' || v == 1) return true;
    if (v == 'false' || v == 0) return false;
    return fallback;
  }

  /// A list from the step's data.
  List<dynamic> getArray(Map<String, dynamic> data, String key) {
    final v = data[key];
    return v is List ? v : const [];
  }
}
