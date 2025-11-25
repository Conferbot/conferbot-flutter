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
