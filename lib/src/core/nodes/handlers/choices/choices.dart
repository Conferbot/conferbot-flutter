/// Choice handlers barrel export
///
/// This file exports all choice handlers for easy importing.
/// Use this single import to access all choice handlers:
///
/// ```dart
/// import 'choices/choices.dart';
/// ```
library;

// UI States
export 'choice_ui_states.dart';

// Handlers
export 'button_choice_handlers.dart';
export 'selection_handlers.dart';
export 'rating_handlers.dart';

import '../legacy_handlers.dart' show NodeHandler;
import 'button_choice_handlers.dart';
import 'selection_handlers.dart';
import 'rating_handlers.dart';

/// Factory function to get all choice node handlers
///
/// Returns a list of all 12 choice handlers:
///
/// Button Choices:
/// - TwoChoicesNodeHandler (2-option buttons)
/// - ThreeChoicesNodeHandler (3-option buttons)
/// - NChoicesNodeHandler (N-option buttons)
/// - YesOrNoChoiceNodeHandler (Yes/No toggle)
///
/// Selection Choices:
/// - SelectOptionNodeHandler (legacy dropdown)
/// - NSelectOptionNodeHandler (dynamic dropdown)
/// - NCheckOptionsNodeHandler (checkbox multi-select)
/// - ImageChoiceNodeHandler (image grid)
///
/// Rating Choices:
/// - RatingChoiceNodeHandler (star/smiley/number)
/// - OpinionScaleChoiceNodeHandler (NPS-style)
/// - UserRatingNodeHandler (legacy 5-star)
List<NodeHandler> getChoiceNodeHandlers() {
  return [
    // Button choices
    TwoChoicesNodeHandler(),
    ThreeChoicesNodeHandler(),
    NChoicesNodeHandler(),
    YesOrNoChoiceNodeHandler(),

    // Selection choices
    SelectOptionNodeHandler(),
    NSelectOptionNodeHandler(),
    NCheckOptionsNodeHandler(),
    ImageChoiceNodeHandler(),

    // Rating choices
    RatingChoiceNodeHandler(),
    OpinionScaleChoiceNodeHandler(),
    UserRatingNodeHandler(),
  ];
}
