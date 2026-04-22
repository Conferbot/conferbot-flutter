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

// ========== Error Handling System ========== //
export 'src/core/errors/conferbot_exceptions.dart';
export 'src/core/errors/error_handler.dart' hide ErrorResult;

// ========== Node System (All 51 Node Types) ========== //
export 'src/core/state/chat_state.dart';
export 'src/core/node_flow_engine.dart';
export 'src/core/nodes/node_types.dart';
export 'src/core/nodes/node_result.dart';
export 'src/core/nodes/node_ui_state.dart';
export 'src/core/nodes/node_handler_registry.dart';

// Node Handlers — hide types that conflict with node_ui_state.dart
export 'src/core/nodes/handlers/legacy_handlers.dart'
    hide NodeUIState, CalendarState, ChoiceOption, RatingType;
export 'src/core/nodes/handlers/display_handlers.dart' hide CalendarState;
export 'src/core/nodes/handlers/ask_question_handlers.dart';
export 'src/core/nodes/handlers/choice_handlers.dart' hide ChoiceOption, RatingType;
export 'src/core/nodes/handlers/logic_handlers.dart';
export 'src/core/nodes/handlers/integration_handlers.dart';
export 'src/core/nodes/handlers/special_handlers.dart';
export 'src/core/nodes/handlers/voice_message_handler.dart';

// ========== Pagination System ========== //
export 'src/core/state/message_pagination_controller.dart';
export 'src/core/state/message_storage_service.dart';

// ========== Session Persistence System (Hive) ========== //
export 'src/services/storage_service.dart';
export 'src/storage/adapters/hive_adapters.dart';

// ========== Offline Message Queue System ========== //
export 'src/models/queued_message.dart';
export 'src/services/connectivity_service.dart';
export 'src/services/message_queue_service.dart';

// ========== Analytics System ========== //
export 'src/models/analytics.dart';
export 'src/services/analytics_service.dart';
export 'src/providers/analytics_provider.dart';

// ========== Voice Recording System ========== //
export 'src/services/voice_recording_service.dart';

// ========== Media Service ========== //
export 'src/services/media_service.dart';

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
export 'src/widgets/chat_bottom_bar.dart';
export 'src/widgets/chat_header.dart';
export 'src/widgets/message_list.dart';
export 'src/widgets/chat_widget.dart';
export 'src/widgets/error_widget.dart';
export 'src/widgets/offline_indicator.dart';

// Voice Message Widgets
export 'src/widgets/voice_message/voice_message.dart';
export 'src/widgets/voice_message/voice_recorder.dart';
export 'src/widgets/voice_message/voice_player.dart';
export 'src/widgets/voice_message/voice_input_widget.dart';

// Media Player Widgets
export 'src/widgets/media/media.dart';
export 'src/widgets/media/image_viewer.dart';
export 'src/widgets/media/video_player_widget.dart';
export 'src/widgets/media/audio_player_widget.dart';

// ========== Rich Text / Markdown Rendering ========== //
export 'src/widgets/markdown/markdown.dart';
export 'src/widgets/markdown/markdown_message.dart';
export 'src/widgets/markdown/markdown_theme.dart';
export 'src/widgets/markdown/link_handler.dart';
export 'src/widgets/markdown/code_block.dart';

// Node UI Widgets — only export node_widgets (choice_widgets has conflicts)
export 'src/ui/widgets/node_widgets.dart';

// ========== Knowledge Base ========== //
export 'src/models/knowledge_base.dart';
export 'src/services/knowledge_base_service.dart';
export 'src/providers/knowledge_base_provider.dart';
export 'src/widgets/knowledge_base/knowledge_base.dart';

// ========== Utilities ========== //
export 'src/utils/validation_utils.dart';
