/// Ask question handlers barrel export
///
/// This file exports all ask question handlers for easy importing.
/// Use this single import to access all ask question handlers:
///
/// ```dart
/// import 'ask_questions/ask_questions.dart';
/// ```
library;

// Base
export 'base_ask_handler.dart';

// Handlers
export 'text_input_handlers.dart';
export 'complex_input_handlers.dart';

import 'base_ask_handler.dart';
import 'text_input_handlers.dart';
import 'complex_input_handlers.dart';

/// Get all ask question handlers
///
/// Returns a list of all 10 ask question handlers:
///
/// Text Inputs:
/// - AskNameNodeHandler (name)
/// - AskEmailNodeHandler (email with validation)
/// - AskPhoneNodeHandler (phone with validation)
/// - AskNumberNodeHandler (numeric)
/// - AskUrlNodeHandler (URL with validation)
/// - AskLocationNodeHandler (address/location)
/// - AskCustomNodeHandler (free text)
///
/// Complex Inputs:
/// - AskFileNodeHandler (file upload)
/// - AskMultipleQuestionsNodeHandler (sequential questions)
/// - CalendarNodeHandler (date/time picker)
List<BaseAskNodeHandler> getAskQuestionHandlers() {
  return [
    // Text inputs
    AskNameNodeHandler(),
    AskEmailNodeHandler(),
    AskPhoneNodeHandler(),
    AskNumberNodeHandler(),
    AskUrlNodeHandler(),
    AskLocationNodeHandler(),
    AskCustomNodeHandler(),

    // Complex inputs
    AskFileNodeHandler(),
    AskMultipleQuestionsNodeHandler(),
    CalendarNodeHandler(),
  ];
}

/// Create a map of node types to handlers
Map<String, BaseAskNodeHandler> createAskQuestionHandlerMap() {
  final handlers = getAskQuestionHandlers();
  return {for (var handler in handlers) handler.nodeType: handler};
}
