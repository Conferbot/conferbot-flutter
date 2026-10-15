/// Every step handler, and [registerAllHandlers] (React Native
/// src/core/nodes/handlers/index.ts). Fields, ports, saved values and
/// records follow the shared flow-node spec (conferbot-react-native
/// scripts/parity/flows/nodes.spec.json).
library;

import '../node_handler.dart';
import '../node_handler_registry.dart';
import 'advanced_input_handlers.dart';
import 'ask_handlers.dart';
import 'choice_handlers.dart';
import 'display_handlers.dart';
import 'integration_handlers.dart';
import 'legacy_handlers.dart';
import 'logic_handlers.dart';
import 'rich_handlers.dart';
import 'special_handlers.dart';

export 'advanced_input_handlers.dart';
export 'ask_handlers.dart';
export 'choice_handlers.dart';
export 'display_handlers.dart';
export 'flow_kit.dart';
export 'integration_handlers.dart';
export 'legacy_handlers.dart';
export 'logic_handlers.dart';
export 'rich_handlers.dart';
export 'special_handlers.dart';
export 'voice_message_handler.dart';

/// Every built-in handler.
List<NodeHandler> allHandlers() => [
      ...displayHandlers,
      ...askHandlers,
      ...choiceHandlers,
      ...advancedInputHandlers,
      ...legacyHandlers,
      ...logicHandlers,
      ...integrationHandlers,
      ...specialHandlers,
      ...richHandlers,
    ];

/// Registers every built-in handler (the last one for a type wins).
void registerAllHandlers(NodeHandlerRegistry registry) => registry.registerAll(allHandlers());
