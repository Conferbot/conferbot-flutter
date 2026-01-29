library conferbot_flutter;

// ========== Core (Headless SDK) ========== //
export 'src/providers/conferbot_provider.dart';
export 'src/models/agent.dart';
export 'src/models/message.dart';
export 'src/models/chat_session.dart';
export 'src/models/socket_events.dart';
export 'src/models/user.dart';
export 'src/services/api_client.dart';
export 'src/services/socket_client.dart';
export 'src/config/constants.dart';

// ========== Node System (All 51 Node Types) ========== //
export 'src/core/state/chat_state.dart';
export 'src/core/node_flow_engine.dart';
export 'src/core/nodes/node_types.dart';
export 'src/core/nodes/node_result.dart';
export 'src/core/nodes/node_ui_state.dart';
export 'src/core/nodes/node_handler_registry.dart';

// Node Handlers
export 'src/core/nodes/handlers/legacy_handlers.dart';
export 'src/core/nodes/handlers/display_handlers.dart';
export 'src/core/nodes/handlers/ask_question_handlers.dart';
export 'src/core/nodes/handlers/choice_handlers.dart';
export 'src/core/nodes/handlers/logic_handlers.dart';
export 'src/core/nodes/handlers/integration_handlers.dart';
export 'src/core/nodes/handlers/special_handlers.dart';

// ========== Theme System ========== //
export 'src/theme/conferbot_theme.dart';
export 'src/theme/default_theme.dart';
export 'src/theme/dark_theme.dart';

// ========== UI Widgets ========== //
export 'src/widgets/avatar.dart';
export 'src/widgets/connection_status.dart';
export 'src/widgets/typing_indicator.dart';
export 'src/widgets/empty_state.dart';
export 'src/widgets/message_bubble.dart';
export 'src/widgets/chat_input.dart';
export 'src/widgets/chat_header.dart';
export 'src/widgets/message_list.dart';
export 'src/widgets/chat_widget.dart';

// Node UI Widgets
export 'src/ui/widgets/node_widgets.dart';
export 'src/ui/widgets/choice_widgets.dart';

// ========== Utilities ========== //
export 'src/utils/validation_utils.dart';
