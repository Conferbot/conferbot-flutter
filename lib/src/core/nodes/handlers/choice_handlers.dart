/// Choice handlers - barrel export for backward compatibility
///
/// This file re-exports all choice handlers from their split files
/// to maintain backward compatibility with existing imports.
///
/// For new code, prefer importing directly from:
/// - choices/choice_ui_states.dart
/// - choices/button_choice_handlers.dart
/// - choices/selection_handlers.dart
/// - choices/rating_handlers.dart
///
/// Or use the consolidated barrel:
/// - choices/choices.dart
library;

// Re-export all choice handlers for backward compatibility
export 'choices/choices.dart';

// Legacy exports (deprecated - use choices/choices.dart instead)
import 'choices/choices.dart' as choices;
import 'legacy_handlers.dart' show NodeHandler;

/// Get all choice node handlers
/// @deprecated Use getChoiceNodeHandlers() from choices/choices.dart
List<NodeHandler> getChoiceNodeHandlers() {
  return choices.getChoiceNodeHandlers();
}
