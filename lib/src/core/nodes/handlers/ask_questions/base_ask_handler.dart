/// Base handler for ask question nodes
///
/// Provides common functionality for all ask-type handlers.
/// Extends BaseNodeHandler for compatibility with NodeHandlerRegistry.
///
/// All utility methods (getString, getInt, getBoolean, getList, getMap,
/// stripHtml, isValidEmail, isValidPhone, isValidUrl, isValidNumber,
/// recordResponse, state) are inherited from BaseNodeHandler.
library;

import '../legacy_handlers.dart' hide NodeUIState, TextInputType;

// Re-export for convenience of ask handler files
export '../legacy_handlers.dart' show BaseNodeHandler, NodeHandler, NodeResult;
export '../../node_result.dart';
export '../../../state/chat_state.dart' show ChatState, RecordEntry;

/// Base class for ask question handlers.
/// Extends BaseNodeHandler to be compatible with NodeHandlerRegistry
/// which expects NodeHandler instances.
abstract class BaseAskNodeHandler extends BaseNodeHandler {
  // All utility methods inherited from BaseNodeHandler.
}
