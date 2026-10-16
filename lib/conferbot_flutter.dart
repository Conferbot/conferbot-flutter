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

// ========== Node System (the web widget's node types) ========== //
export 'src/core/state/chat_state.dart';
// The handover's widget signals (ConferBotProvider.onWidgetSignal).
export 'src/core/live_chat/handover_waiting.dart' show WidgetSignals;
// While waiting for a person: the help card and the games card (ConferBotProvider.waitHelpCard, gamesCard).
export 'src/core/waiting/wait_articles.dart' show HelpItem, HelpCardState;
export 'src/core/waiting/games_card.dart' show GamesCard, GamesCardState;
export 'src/widgets/waiting/wait_help_card.dart' show WaitHelpCard;
export 'src/widgets/waiting/games_card_view.dart' show GamesCardView;
// "Your requests": the visitor's conversations with the team (ConferBotProvider.requests, openRequests, requestsUnread).
export 'src/core/requests/requests.dart'
    show RequestSummary, RequestDetail, RequestMessage, RequestState, RequestsText, RequestMemory, ReplyResult, stateOf, isNewReply, rowLine, unreadCount, requestsAccent;
export 'src/core/requests/requests_portal.dart' show RequestsPortal, RequestsPortalState, RequestsScreen, PendingReply, PendingStatus;
export 'src/core/requests/requests_extras.dart' show RequestsExtras, RequestsStore, SharedPreferencesRequestsStore;
export 'src/widgets/requests/requests_portal_view.dart' show RequestsPortalView, requestsColorOf;
// The home screen (ConferBotProvider.home, homeModel; ChatWidget opens on it
// when the owner has one) and "Greet by name".
export 'src/core/home/home.dart'
    show
        HomeView,
        HomeModel,
        HomeMascot,
        HomeSection,
        HomeText,
        HomeAgent,
        HomePalette,
        VisitorMemory,
        homeModel,
        homeOn,
        safeHomeView,
        homePalette,
        classicHomePalette;
export 'src/core/home/home_extras.dart' show HomeExtras, HomeKnowledgeBase;
export 'src/core/home/view_transition.dart' show viewMotion, ViewMotion, NoMotion, ReducedMotion, FadeMotion, SlideMotion;
export 'src/core/customization/personalize.dart' show personalize, personalizeCustomizations, visitorVars;
export 'src/widgets/home/home_screen_view.dart' show HomeScreenView;
export 'src/widgets/home/view_switch.dart' show ViewSwitch;
// The owner's mascot (art, moods, the greeting card's motion) and <Mascot>
// for an app's own screens (the home's mascotBuilder, say).
export 'src/core/customization/mascot_art.dart'
    show MascotLook, MascotLayers, MascotJoints, mascotLookOf, mascotScaleOf, mascotColorOf, mascotLayers, mascotOrigins, mascotPoint, mascotUnit, mixColor, mascotShapes, mascotEyes, mascotAccessories, mascotArms, mascotDefaultNames, mascotLayerOrder;
export 'src/core/customization/mascot_moods.dart' show moodPlan, MoodPlan, mascotMoods, typingLabel;
export 'src/core/customization/mascot_motion.dart' show normalizeMascotMotion, mascotMotions, MascotDirector, MascotStage, MascotTimers, gestureTrack, cardEnterTrack, cardLeaveTrack, wordFade, figureAmp;
export 'src/widgets/mascot/mascot_view.dart' show Mascot, MascotPose, MascotPart, paintMascot;
export 'src/widgets/mascot/typing_mascot.dart' show TypingMascot, TypingPencil;
export 'src/widgets/mascot/launcher_mascot.dart' show LauncherMascot;
export 'src/core/node_flow_engine.dart';
export 'src/core/nodes/node_types.dart';
export 'src/core/nodes/node_result.dart';
export 'src/core/nodes/node_ui_state.dart';
export 'src/core/nodes/node_handler_registry.dart';

// Node Handlers (one per node type; registerAllHandlers) and the shared
// flow rules they use
export 'src/core/nodes/node_handler.dart';
export 'src/core/nodes/handlers/handlers.dart';

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
export 'src/widgets/conferbot_fab.dart';

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
