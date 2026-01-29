/// Node Handlers - Barrel Export
///
/// This file provides a unified import point for all node handlers.
/// The handlers have been organized into the following categories:
///
/// **Base Classes** (legacy_handlers.dart):
/// - NodeHandler, BaseNodeHandler, NodeUIState, NodeResult
///
/// **Display Handlers** (display_handlers.dart):
/// - MessageNodeHandler, ImageNodeHandler, VideoNodeHandler, etc.
///
/// **Choice Handlers** (choices/):
/// - TwoChoicesNodeHandler, ThreeChoicesNodeHandler, NChoicesNodeHandler
/// - SelectOptionNodeHandler, NSelectOptionNodeHandler, NCheckOptionsNodeHandler
/// - ImageChoiceNodeHandler, RatingChoiceNodeHandler, etc.
///
/// **Ask Question Handlers** (ask_questions/):
/// - AskNameNodeHandler, AskEmailNodeHandler, AskPhoneNodeHandler
/// - AskMultipleQuestionsNodeHandler, CalendarNodeHandler, etc.
///
/// **Integration Handlers** (integrations/):
/// - WebhookNodeHandler, GptNodeHandler, EmailNodeHandler
/// - GoogleSheetsNodeHandler, SlackNodeHandler, StripeNodeHandler, etc.
///
/// **Logic Handlers** (logic_handlers.dart):
/// - ConditionNodeHandler, BooleanLogicNodeHandler, VariableNodeHandler, etc.
///
/// **Special Handlers** (special_handlers.dart):
/// - DelayNodeHandler, HumanHandoverNodeHandler
library;

// Base classes and legacy handlers
export 'legacy_handlers.dart';

// Display handlers
export 'display_handlers.dart';

// Choice handlers (split into multiple files)
export 'choice_handlers.dart';

// Ask question handlers (split into multiple files)
export 'ask_question_handlers.dart';

// Integration handlers (split into multiple files)
export 'integration_handlers.dart';

// Logic handlers
export 'logic_handlers.dart';

// Special handlers
export 'special_handlers.dart';

// Voice message handler
export 'voice_message_handler.dart';
