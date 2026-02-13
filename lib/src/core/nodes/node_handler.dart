/// Node handler base classes barrel file
///
/// Re-exports all handler base types from legacy_handlers.dart.
/// This file exists to provide a clean import path at the nodes/ level
/// for v2 handlers (logic, special) that import '../node_handler.dart'.
library;

export 'handlers/legacy_handlers.dart';
