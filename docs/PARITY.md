# Web widget parity: Flutter

This file tracks how far this SDK matches the web widget: what's done, what's left, and how to pick the work up. Features are built in the React Native SDK first; its `docs/PARITY.md` and `src/core/*.ts` are the reference.

Layout:

- **UI:** `lib/src/widgets/`. `conferbot_fab.dart` is the launcher; `chat_widget.dart` is the chat.
- **State:** `lib/src/providers/conferbot_provider.dart`.

## Done in this SDK

| Issue | Feature | Key files |
|---|---|---|
| #6-#11 | Live chat / agent parity | `core/live_chat/`, `widgets/live_chat_cards.dart` |
| #12, #13 | Customization basics | `core/customization/customizations.dart` |
| #14 | Chat background | `chat_background.dart`, `svg_path.dart`, `widgets/chat_background.dart` |
| #15 | 27 themes, light/dark/auto, palette | `widget_theme.dart`, `widget_themes_data.dart` (generated) |
| #17 | Launcher resolver | `core/customization/launcher.dart`, `widgets/conferbot_fab.dart` |
| #18 | 56 icons (CustomPainter) | `launcher_icons.dart`, `widgets/launcher_icon_painter.dart` |
| #19 | Launcher motion, passes the golden test | `launcher_motion.dart`, `test/fixtures/launcher_motion_golden.json` |
| #20 | User as `visitorContext` + identity hash (name, email and metadata now reach the server) | `models/user.dart` (`toVisitorContext`), `core/state/chat_state.dart`, provider constructor |
| #36, #45, #53, #54, #56, #57 | Help centre: loads from the socket's `knowledgeBaseData` (bodies fetched on open) or REST, sends `query` to search, follows `enableKnowledgeBase` / `hideRecentArticles` (`ChatWidget.showKnowledgeBase` overrides), draws HTML bodies, opens AI sources and rich article cards by `articleId`, uses the configured server. Fixtures captured from a local server | `core/help_centre/help_centre.dart`, `models/knowledge_base.dart` (`KnowledgeBaseData`), `providers/knowledge_base_provider.dart`, `services/knowledge_base_service.dart`, `widgets/agent_reply.dart`, `widgets/chat_widget.dart`, `test/fixtures/kb_payloads.json` |
| #22 | Greeting card: rules, frequency, per-bot state, 11 styles; replaces the old CTA tooltip. Checked with widget-test images, not yet on a device | `core/customization/greeting.dart`, `widgets/greeting_controller.dart`, `widgets/greeting_card.dart`, `widgets/conferbot_fab.dart` |
| #23, #29-#34, #48, #55, #66-#70 | Flow nodes: the engine and every node handler run the shared flow-node spec. **156 of 156 fixtures pass** (`test/parity/flows_test.dart`); none pending. See "Flow nodes" below | `core/node_flow_engine.dart`, `core/flow/*` (text, logic, flow_control, rich, inputs, calendar, zones, flow_context), `core/privacy/redact.dart`, `core/nodes/handlers/*`, `core/state/chat_state.dart`, `ui/widgets/node_widgets.dart`, `ui/widgets/rich_node_widgets.dart`, `widgets/message_bubble.dart` |
| #24-#28, #37, #61-#63, #65 | Handover lifecycle, ported from RN: the Connecting line and its four outcomes, an AI's idle pause ignored, the 20s waiting signal and `onWidgetSignal`, the header keeping the bot with Online and the reply time, "Talk to a person" only when allowed, Leave queue (`queue-self-resolve`, `queue-left`), a live chat or a wait picked back up after a restart without a second ticket, the flow started once per session, `openChat` waiting for start-up, the step's email / sound / assignment settings on `initiate-handover`, End chat and the survey as the server handles them. Checked on the iPhone 16e simulator against a local embed-server | `core/live_chat/handover_state.dart`, `handover_waiting.dart`, `reply_time.dart`, `handover_lifecycle.dart`, `core/agent/agent_handover.dart`, `core/node_flow_engine.dart` (`waitAt`), `providers/conferbot_provider.dart`, `widgets/message_bubble.dart` (`LiveChatLine`), `widgets/live_chat_cards.dart`, `widgets/chat_widget.dart` |
| #47 | Device language: every response record carries `visitorInsights: {v: 1, language: {browser}}` (the phone's preferred language from `PlatformDispatcher.locales`, BCP 47, cut to 16; Flutter's "und" counts as unknown), so the AI answers short messages in it. Ported from RN #51 | `core/device_language.dart`, `core/state/chat_state.dart` `buildResponseData` |
| #46 | "Helpful?": a No is sent at once; reasons, an optional comment, "Talk to a person" (only while nobody is coming or here), "Ask another way" (the composer's focus); the rated line's thumbs change the vote; the vote is kept on the answer's record entry (`ChatState.setAnswerFeedback`); only the newest unrated answer asks. Ported from RN #50 | `core/agent/answer_feedback.dart`, `core/agent/agent_bot.dart` (`AnswerFeedback` with its comment), `widgets/agent_reply.dart` `HelpfulRow`, `providers/conferbot_provider.dart` (`sendAnswerFeedback`, `newestRateableAnswerId`, `focusComposer`), `widgets/chat_bottom_bar.dart` (`focusNode`) |
| #44 | Back in the queue (`live-chat-requeued`): "Connecting you to another agent..." / "Connecting you to <team>...", nobody in the chat, and a flow at its handover step waits again. `live-chat-transferred` is kept in the record, not drawn (as the web). `isRepeatJoin` / `afterAI` on `agent-accepted` were already in the handover port. Ported from RN #48 | `core/live_chat/live_events.dart`, `core/live_chat/handover_lifecycle.dart` |
| #43 | Blocked visitor (`visitor-blocked`, or a handshake refused with `visitor_blocked`, which now carries the visitor id in `query` and `auth`): "This conversation has been closed.", no card, no input, no new chat, no reconnecting. The same `chat-ended` again draws nothing and opens no second survey; each end has its own record id. Once a chat has ended with nothing going on: composer off and "Start a new chat". Ported from RN #47 | `core/live_chat/live_events.dart`; `services/socket_client.dart` (`handshake`, `visitorId`), `core/live_chat/live_chat_extras.dart`, `core/live_chat/handover_lifecycle.dart`, `providers/conferbot_provider.dart` (`closedState`, `startNewChat`), `widgets/live_chat_cards.dart` `ClosedChatCard`, `widgets/chat_widget.dart` |
| #52 | Markdown as the web's `utils/agentHtml.ts`: tables (a sideways scroll, drawn by `ChatTable`; the rest by flutter_markdown), h3-h6 (# and ## drawn as 4), and from a person's HTML blockquote, pre and `<s>`/`<del>`; the "That took too long..." notice when the 45s AI wait runs out (on screen only); `isFallback` replies italic at 85%. Ported from RN #56 | `utils/chat_markdown.dart`, `widgets/markdown/markdown_message.dart`, `widgets/markdown/markdown_theme.dart`, `widgets/message_bubble.dart`, `core/agent/agent_bot.dart` (`awaitReply`, `replyTimeoutNotice`) |
| #42 | "Email me this chat" in the chat menu: one card (email filled in when known), the server's reason when it does not go, "Sent! Check your inbox at ...", the address kept as the visitor's. Server: `POST /api/v1/mobile/chat/transcript-email` (embed-server #193), never retried. Ported from RN #46 | `core/live_chat/email_transcript.dart`; `services/api_client.dart` `sendTranscriptEmail`, `core/live_chat/live_chat_extras.dart`, `widgets/live_chat_cards.dart` `EmailTranscriptCard`, `widgets/chat_widget.dart` (the header's menu) |
| #74 | Post-chat survey questions: asked when the handover step's `enablePostChatSurveyQuestions` is on (the key the builder saves and the web reads); the older `enablePostChatSurvey` still counts, as in Android | `core/nodes/handlers/special_handlers.dart` `onChatEnded` |
| #77 | Each `SocketClient` owns its connection (`enableForceNew()`): a second client to the same server connects with its own handshake (bot, visitor), and `resetConnection` opens a fresh socket with the current visitor (socket_io_client's cache used to hand back the old, closed one). Checked against a local embed-server with two clients and a reset | `services/socket_client.dart` |
| #79 | `identify(user)` after construction, `identify(null)` to sign out (RN's `user` prop, iOS `identify(user:)`, Android `Conferbot.identify`): the next records' `visitorContext` and its `hash`, "Your requests" read again for the new user (a signed-out user's list dropped, a list on its way for the last user not shown), the greeting's signed-in fact decided again, the user's id for the next handshake and session when there is no stored visitor id | `providers/conferbot_provider.dart`, `core/requests/requests_extras.dart`, `widgets/greeting_controller.dart` |
| #75 | `SocketClient.dispose()` no longer throws when the socket is not already disconnected (it reported the state on a closed stream) | `services/socket_client.dart` |
| #40, #64 | While you wait, ported from RN #44, #41: the help card 6s into a wait for a person (up to two help-centre articles for the visitor's last real question, only with the help centre on), replaced by the server's `queue-help` pick (or a waiting `queue-status`'s `help`) with "That solved it" (`queue-self-resolve {chatSessionId, articleId}`, then "You left the queue. Glad that helped.", recorded "Resolved while waiting", once per wait); the games offer 2.5s after `cb:waiting-for-human` with 3 retries 1.5s apart (owner setting `waitingGames`; rock paper scissors, tic-tac-toe, quiz, memory, reflex, emoji riddles, word scramble with the web's rules and scoring); "Not now" / x for the app session; "play" / "games" typed while waiting opens the menu; a person joining removes an unused offer and saves a game under way ("<name>'s here!", "Finish my game"); reduced motion; the cards never saved. #76: the composer stays open while a flow's handover step waits, as on the web (what is typed goes as a live message for whoever joins) | `core/waiting/wait_articles.dart`, `waiting_games.dart`, `games_logic.dart`, `games_card.dart`, `waiting_extras.dart`; `core/live_chat/handover_lifecycle.dart` (`waitStart` / `waitEnd`, `leftQueueHelped`), `live_chat_extras.dart` (`onQueueStatus`), `providers/conferbot_provider.dart` (`waiting`, "play" in `sendMessage`, `openWaitHelpItem`, `solveWait`), `widgets/waiting/wait_help_card.dart`, `games_card_view.dart`, `widgets/message_list.dart` (`inlineAfter`), `widgets/chat_widget.dart` |
| #73 | Launcher entrance (12 effects), attention (8 modes) and idle call (5), ported from RN #57. `keyframes.dart` evaluates the web's Web Animations tracks and passes RN's Chrome golden (447 cases, 19,275 samples; largest error 0.0007px, 0.005deg, 0.00005 scale and opacity, 0.03px `left`, 0.42px on the plane's path). The tracks are rebuilt from the same code and match the golden's. The rules are in the three controllers. Checked with widget-test images, not yet on a device | `core/customization/keyframes.dart`, `launcher_entrance.dart`, `launcher_attention.dart`, `launcher_idle_call.dart`, `mascot_art.dart`, `fx_paint.dart`; `widgets/launcher_fx_controllers.dart`, `launcher_fx_views.dart`, `fx_svg.dart`, `conferbot_fab.dart`; `test/fixtures/launcherfx_golden.json` |
| #41 | "Your requests", ported from RN #45: the visitor's conversations with the team (only their own: a conversation id this device started with its visitor id, or a signed-in user with a valid `user.hash`), each one's state in words, "New reply from <name>" and the unread count (`requestsUnread`), one request's banner, conversation and reply box (a reply to a solved one opens it again; Sending..., Not sent / Try again, closed for replies), team replies live while open (`my-request-update`), the open one read again after a reconnect. The device remembers per bot the last 30 chats the visitor wrote in and when each request was last read (shared_preferences). In the chat menu once there is one ("Your requests", "Your requests · New reply"); Back and Android's back (`PopScope`) step back. Checked against the local embed-server with the SDK's own classes (`my-requests`, `my-request-open`, `my-request-reply`, `my-request-close`, `my-request-update`, another visitor's conversation refused) | `core/requests/requests.dart`, `requests_portal.dart`, `requests_extras.dart`; `widgets/requests/requests_portal_view.dart`; `providers/conferbot_provider.dart` (`requests`, `openRequests`, `requestsUnread`); `services/socket_client.dart` (`onResponseRecord`); `widgets/chat_widget.dart` (menu, overlay) |
| #80, #78 | Home screen, ported from RN #68, #69 (and as Android #78): only when the owner has it on (`enableInitialPage`; else the chat opens on the conversation). The salutation by the phone's clock or "Welcome back, Jamie" (the device remembers per bot, 60 days, in shared_preferences), the brand, the owner's words (early placeholder copy shown honestly); "Ask anything" (`homeAskBox`: ask the AI agent, the articles that answer it with the server's `search-kb-articles` body matches, "Chat with us"); "Pick up where you left off" (agent bots); "Your requests" (two rows, See all (n), above "Talk to us" when a reply is new; the portal over the home); "Talk to us" (`homePeople` reply time, `hideOnlineStatus`, `homeTeamPhotos`, up to 3 agent questions, `homeRating`); the help card (recent articles unless `hideRecentArticles`, topics, See all; its own search with the ask box off); `homeTrustLogos` + `homeTrustLabel`. Home, conversation and help centre in a `ValueNotifier` view switched by `ViewSwitch` (an `AnimatedSwitcher`, the owner's `viewTransition` / `viewTransitionDirection`: fade, slide, the rest slide, classic and none at once, a 200ms fade with animations off); the chat header's ‹ and Android's back (`PopScope`) to the home; the help centre's back to where it was opened; a greeting card's send and starters go past the home. Seen receipts only on the conversation. #78: `{{first_name\|there}}` (and `{{name}}`, `{{company}}`) filled from the signed-in user and a name the chat asked for, on the bot's settings before anything reads them (greeting card, launcher call-to-action, home), again on `identify`. Checked with widget tests and widget-test images, not on a device | `core/home/home.dart`, `view_transition.dart`, `home_extras.dart`, `core/customization/personalize.dart`, `core/live_chat/reply_time.dart` (`homeLine`, `homePeople`); `widgets/home/home_screen_view.dart`, `view_switch.dart`; `providers/conferbot_provider.dart` (`home`, `homeModel`, `homePalette`, `_personalize`), `widgets/chat_widget.dart` (views, `PopScope`, header ‹), `widgets/conferbot_fab.dart` (greeting send) |
| #81, #50 | Mascots, ported from RN #71, #54 (as Android #81): all 27 characters with their 5 eyes, 7 accessories, the owner's colour and name, as RN's `mascotArt.ts` draws them, layer for layer (14 layers, each moving part its own; the bust framed tight; checked against RN for 367 looks by SHA-256 of every layer). The moods (blink, wave twice or on, think, happy; reduced motion keeps only the happy smile) and the greeting card's director line for line (lively, subtle, off; the pop, wave, nod, breath and at most three gestures; the Online ping; the words fading up; the hand-off toward the launcher or the bow at the x; the card's spring / in / collapse / out; a voice note talking; nothing in the background). The evaluator reads CSS `@keyframes` and transform lists (`transformOrder`, `transformMatrix`) and passes RN's Chrome golden, now 499 cases (52 mascot), 22,123 samples, every track rebuilt. The launcher's `mascot` style (`mascotLauncherScale` 70-150, 112; the soft light button; blinking; a happy hop for 2.4s on a reply while closed), `mascotInGreeting` (the mascot in place of the avatar, by its name, waving twice), the greeting card drawn while it leaves, the idle call in the owner's mascot about its own joints, the `mascot` and `pencil` typing styles ("Pip is typing" for screen readers; #50), `HomeModel.mascot` and `HomeScreenView(mascotBuilder:)` / `ChatWidget(homeMascotBuilder:)` given it, and the public `Mascot` widget. SVG dashes drawn (the stamps and keys, the pencil's line). Checked with widget tests and widget-test images, not on a device | `core/customization/mascot_art.dart`, `mascot_moods.dart`, `mascot_motion.dart`, `keyframes.dart` (`cssKeyframes`, transform lists), `customizations.dart`, `launcher.dart` (`LauncherMascotLook`), `core/home/home.dart` (`HomeMascot`); `widgets/mascot/mascot_view.dart` (`paintMascot`, `Mascot`, `FxClock`), `typing_mascot.dart`, `launcher_mascot.dart`, `greeting_motion.dart`; `widgets/fx_svg.dart` (`dashPath`), `greeting_card.dart`, `greeting_controller.dart` (`GreetingMascot`), `conferbot_fab.dart`, `launcher_fx_views.dart` (`IdleCallPainter`), `typing_indicator.dart`, `message_list.dart`, `home/home_screen_view.dart`, `chat_widget.dart`; `test/fixtures/mascot_art.json` (`tool/mascot_art_fixture.sh`), `test/fixtures/launcherfx_golden.json` |

## Left in this SDK

1. **Greeting card follow-ups:**
   - Check it on a device (iOS and Android).
   - Not drawn yet, as in RN: the agent's reply field. The word fade-up, the "Online" ping, the exit animations and the mascot came with #81.
2. **Handover follow-ups:**
   - Leave queue was checked against the server with a visitor socket (this simulator has no tap tool); the button itself is covered by widget tests.
   - After a restore that is still waiting, the max-wait timer starts over rather than from the server's `waitEndsAt`.
3. **Launcher effects follow-ups (#73):**
   - Check them on a device (iOS and Android). They are covered by unit tests on a fake clock, a launcher widget test and widget-test images only.
   - As in RN, web filters (brightness, glows, blur, the mascot's bevel) are not drawn, and the waving hand is the system emoji.
4. **Live chat extras follow-ups (#42-#44, #46, #47, #52):**
   - Check them on a device (iOS and Android). They are covered by unit tests, fake-socket tests and widget tests only; the transcript call only against a stubbed HTTP client.
   - As on the web, a transfer is not drawn, and the reply-timeout notice is not kept in the record.
   - The cards (Email me this chat, the closed chat) sit at the end of the paginated message list, as the other live chat cards do; `ChatWidget(enablePagination: false)` does not draw them.
5. **While you wait follow-ups (#40, #64):**
   - Check it on a device (iOS and Android) and against a local embed-server. It is covered by unit tests on a fake clock and a fake socket, and widget tests only; the server side (`queue-help`, `queue-self-resolve` with the article, the ticket closed `self_service`) was checked from RN.
   - Where it starts and stops: a flow handover with no `assignedAIAgents` (`setWaitingForPerson`, which also covers a restored chat still in the queue), every AI escalation (`agent-left` handover); not a requeue. It stops on `agent-accepted`, `handover-waiting`, `no-agents-available`, `chat-ended`, `ai-agent-inactive-close`, a blocked visitor, leaving the queue, `cb:human-joined` and `cb:wait-over`.
   - The question is read from `ChatState.getRecordForServer()`: the newest entry whose `type` or `shape` is a typed message (a flow answer keeps the step's type in `type`), as Android does.
   - The cards sit after the message that was last on screen when each was drawn (`WaitingExtras.helpAfter` / `gamesAfter`, `MessageList.inlineAfter`), or at the end when that message is not on screen. `ChatWidget(enablePagination: false)` does not draw them, as with the other live chat cards.
   - The bot's font is not applied (this SDK has no font setting yet). The scramble takes taps; `KeyInput` exists but no hardware keyboard is wired in the view. Memory cards turn without the web's 3D flip, as in RN.
6. **Your requests follow-ups (#41):**
   - Check it on a device (iOS and Android). It is covered by unit tests, fake-socket tests, widget tests and a socket check against a local embed-server only.
   - When the list is read: at connect (every connect), when the chat opens or closes (at most every 15s), when the portal closes, on `my-request-update` while it is closed, and on a sign-in or sign-out (`identify`, #79).
   - The entries are the home screen's card (#80) and the chat menu, shown once the visitor has a request (for bots without a home screen); English only; replies are text only. The app's font is `ConferBotCustomization.fontFamily` (the bot's web font is not loaded).
7. **Home screen follow-ups (#80, #78):**
   - Check it on a device (iOS and Android). It is covered by unit tests, widget tests with the real provider and widget-test images only.
   - Not in an app, as in RN and Android: the page-aware parts (`pageAware.ts`: "For this page" articles and a page rule's own starters; the agent's own starters are used), the floating panel's three-article cap, the web's `keepsAgentChat`, the logos' grayscale filter (drawn at 55%).
   - The web's home draws no mascot; `HomeModel.mascot` gives the app's own spot (`HomeScreenView(mascotBuilder:)`, `ChatWidget(homeMascotBuilder:)`) the owner's mascot (#81).
   - The help centre from the home is the SDK's own help centre screen (its topic or article opened), not the web's Articles tab.
   - English only (the web's i18n `home.*`, `trust.*`).
8. **Mascot follow-ups (#81, #50):**
   - Check them on a device (iOS and Android). They are covered by RN's layer fixture (367 looks), the Chrome golden, unit tests on a fake clock, widget tests and widget-test images only.
   - As in RN and Android, no SVG filters: the bevel, the soft glows on the shine and cheeks and the LED glow are not drawn (the shine and cheeks a touch lighter instead).
   - No hover lean or hop (touch), as on the web for touch pointers.
   - Each mascot draws its layers with this SDK's own SVG renderer (`widgets/fx_svg.dart`) on a canvas, every part about its joint at the clock's time, rather than `flutter_svg` widgets in a `Stack` (RN's porting note): the same drawing, no new dependency.
   - The launcher mascot and the typing mascot loop for as long as they are on screen (the blink; RN loops them on the native driver); a frame that changes nothing is not repainted.
9. The rest of the list below.
10. **Test debt:**
   - #16: `media_service_test` fails because MockController is not an AudioPlayer.
   - #58: the older help centre widget tests (`article_list_test`, `article_detail_test`, `category_chips_test`) and `message_bubble_test` don't compile or fail. The help centre is covered by `test/core/help_centre/`, `test/providers/knowledge_base_provider_test.dart` and `test/widgets/knowledge_base/help_centre_test.dart`.
11. **Flow node follow-ups:**
   - Check the step cards on a device (iOS and Android). They are covered by widget tests and images only (no emulator or simulator run).
   - Address: no "Use my location" (it would need a location plugin); search, the map and typing by hand work.
   - Hidden fields read the page the chat runs on. An app has none: the provider passes no `NodeFlowEngineConfig.page`.
   - The visitor's time zone is the device's offset as a fixed `Etc/GMT` zone, because Dart does not expose the IANA name. The provider does not pass `NodeFlowEngineConfig.visitorTimeZone` yet.
12. **Help centre follow-ups:**
   - Ratings still use the SDK's 1-5 stars over REST; the web sends helpful / not helpful (`rate-article`). Reading time and scroll depth (`track-article-engagement`) are not sent.
   - Search uses REST (`/knowledge-base/search?query=`) plus local title matches; the socket's `search-kb-articles` (with snippets) is not used.
   - Recent articles show on the home screen (#80) and still at the top of the help centre list.

## How to test

- **Unit tests:** `flutter test test/core` (skip the media test, #16).
- **Flow nodes:** `flutter test test/parity/flows_test.dart` runs the 156 fixtures; `flutter test test/widgets/step_views_test.dart` plays them through the step cards; `flutter test test/core/node_flow_engine_test.dart test/core/handlers test/core/flow test/core/privacy test/widgets/node_renderer_test.dart test/widgets/flow_media_lines_test.dart` covers the engine API, the handlers, the flow rules and the step cards. `tool/sync_flow_fixtures.sh` copies the fixtures from the React Native repo (`RN_SDK` if it is not next door) into `test/fixtures/parity_flows/` and writes the RN revision to `REVISION`.
- **Handover lifecycle:** `flutter test test/core/live_chat test/core/agent test/widgets/handover/handover_lifecycle_widgets_test.dart`. `handover_lifecycle_test.dart` drives the lifecycle against a fake socket and a fake clock.
- **Handover on a device:** a temporary bot in local Mongo (`conferbotStaging`) with welcome -> human-handover-node (`enableHandoverEmail: false`) -> message, linked in `workspaces.chatbots` and `admins.chatbots` (the server finds a bot's workspace through `admins`). A node socket.io-client script plays the agent with a dashboard JWT signed with the server's `JWT_ACCESS_SECRET` (`auth: {userId, workspaceId, token}`): `accept-handover`, `leave-chat` with `agentDetails.isAIAgent: true` (the visitor sees an AI escalating), `end-chat`. Hot restart (`R`) checks the restore: count `initiate-handover` in the app log and the session's tickets. Delete the bot and everything for its sessions afterwards.
- **Help centre:** `flutter test test/core/help_centre test/providers/knowledge_base_provider_test.dart test/services/knowledge_base_service_test.dart test/widgets/knowledge_base/help_centre_test.dart`. The payloads in `test/fixtures/kb_payloads.json` were captured from a local embed-server (socket `fetched-chatbot-data`, `get-kb-article`, `search-kb-articles`; REST `/mobile/chatbot/:id/kb` and `/mobile/knowledge-base/*`). To refresh them, run a small socket.io-client script against `:8001` with a bot that has published articles.
- **Launcher entrance, attention, idle call:** `flutter test test/parity/launcherfx_test.dart` checks the evaluator against RN's Chrome golden (499 cases, 22,123 samples, the mascot's 52 as CSS matrices) and rebuilds every track the golden was sampled from; `tool/sync_launcherfx_golden.sh` copies the golden from the React Native repo (`RN_SDK` if it is not next door) and writes its RN revision to `test/fixtures/launcherfx_golden.REVISION`. `flutter test test/core/customization/launcher_fx_test.dart test/widgets/launcher_fx_controllers_test.dart test/widgets/launcher_fx_fab_test.dart` covers the settings, the rules on a fake clock and the launcher. `LAUNCHERFX_IMAGES_DIR=/abs/dir flutter test --update-goldens test/widgets/launcher_fx_images_test.dart` writes six frames of every effect (a 390 x 844 screen, a 50px launcher) to that directory, outside the repo.
- **Live chat extras (#42-#44, #46, #47, #52, #74):** `flutter test test/core/device_language_test.dart test/core/agent test/core/live_chat test/utils/chat_markdown_test.dart test/services/socket_handshake_test.dart test/services/api_client_test.dart test/core/handlers/handlers_test.dart test/widgets/helpful_row_test.dart test/widgets/live_chat test/widgets/markdown_message_test.dart`. The transcript email is only ever called against `MockClient` (no email is sent); a real send needs a local embed-server and a session of a bot you own.
- **While you wait (#40, #64):** `flutter test test/core/waiting test/widgets/waiting`. `waiting_extras_test.dart` drives the real handover lifecycle and the cards together on a fake clock and socket (help at 6s, games 2.5s after the signal, That solved it, a requeue, a restore, play typed, a person joining mid-game).
- **Your requests (#41):** `flutter test test/core/requests test/widgets/requests`. `requests_test.dart` and `requests_portal_test.dart` are RN's tests ported; `requests_extras_test.dart` covers the memory, when the list is read, the unread count and the updates on a fake socket. Against a server: seed `responses` and `tickets` in local Mongo (`conferbotStaging`) for two test visitors on a made-up bot id (team-handled, solved, AI-only; tickets with no `assignedAgents`, so a reply notifies nobody), then a temporary `flutter test` file with `SocketClient`, `SocketClientRequestsSocket`, `SocketRequestsApi` and `RequestsPortal` against `http://127.0.0.1:8001`. Delete everything for the sessions (`responses`, `tickets`, `messages`) afterwards.
- **Socket, identify (#77, #79):** `flutter test test/services/socket_client_force_new_test.dart test/providers/identify_test.dart`. Two clients (and a reset) against nothing listening, each with its own socket and handshake; `identify` on the provider, the requests on a fake socket (a list held back while the user changes), the greeting controller. Against a server: two `SocketClient`s to `http://127.0.0.1:8001` in a temporary `flutter test` file, each connecting with its own socket id, then a `resetConnection` (nothing is written).
- **Home screen, greet by name (#80, #78):** `flutter test test/core/home test/core/customization/personalize_test.dart test/core/live_chat/reply_time_test.dart test/widgets/home`. `home_test.dart`, `view_transition_test.dart`, `personalize_test.dart` and the `homeLine` / `homePeople` cases are RN's tests ported; `home_extras_test.dart` covers the view, back, a question asked 400ms after the chat is there, the memory and the body search on a fake socket; `home_screen_test.dart` taps every card and checks the view switch; `home_chat_test.dart` runs `ChatWidget` on the real provider (greet by name and `identify`, the header's ‹, Android's back, the help centre and back, a greeting send past the home, no home when it is off). `HOME_IMAGES_DIR=/abs/dir flutter test --update-goldens test/widgets/home/home_screen_images_test.dart` writes three images (a flow bot with the help centre, requests, faces and rating; an agent with welcome back, a new reply and its questions; a dark theme with the ask box off and the status hidden) to that directory, outside the repo.
- **Mascots (#81, #50):** `flutter test test/core/customization/mascot_art_test.dart test/core/customization/mascot_motion_test.dart test/parity/launcherfx_test.dart test/widgets/mascot_test.dart`. `mascot_art_test.dart` draws 367 looks (every character in every arm pose, as a bust and in an owner's colour; every eye and accessory on five characters; junk) and compares each layer's SHA-256 with RN's (`test/fixtures/mascot_art.json`, rebuilt from RN's `mascotArt.ts` by `tool/mascot_art_fixture.sh`, the same looks as Android's), and every character's joints; `mascot_motion_test.dart` is RN's `mascot.test.ts` ported (the moods, the director on a fake clock, the card's moves, the settings); `mascot_test.dart` draws `Mascot`, the launcher style and its hop, the greeting card's mascot and its leaving, the typing styles, the idle call and the home's spot. `MASCOT_IMAGES_DIR=/abs/dir flutter test --update-goldens test/widgets/mascot_images_test.dart` writes every character, the eyes and accessories, moods mid-move, the launcher style, three greeting styles as they greet, the typing mascot and pencil, and the idle call in an owner's mascot to that directory, outside the repo.
- **Full suite (2026-10-16, after #81, #50):** 1511 pass, 72 skipped, 65 fail (38 more passing: the mascot tests and the golden's mascot cases; 9 more skipped: the mascot images without `MASCOT_IMAGES_DIR`). The 65 are the same tests as before, by name: #16 (`media_service_test`), #71 (provider, socket client, storage and validation tests) and the older widget tests (#58 and the like, including `typing_indicator_test`'s and `markdown_message_test`'s); none in the launcher, mascot, flow, handover, live chat extras, while you wait, your requests, socket, identify or home tests.
- **Greeting card images:** `GREETING_GOLDEN_DIR=/abs/dir flutter test --update-goldens test/widgets/greeting_card_test.dart` writes one PNG per style to that directory, outside the repo. It loads Roboto from the Flutter SDK and macOS fonts in place of casual / serif / monospace. Without the variable the image group is skipped.
- **Example app:**
  - To point it at a local server, add `ConferBotEndpoints.configure(apiBaseUrl: 'http://10.0.2.2:8001/api/v1/mobile', socketUrl: 'http://10.0.2.2:8001')` in `example/lib/main.dart` (`localhost` on the iOS simulator).
  - iOS simulator: `flutter run -d <simulator id>` from `example/`.
  - Build: `flutter build apk --debug --target-platform android-x64` with gradle 8.7.
  - Revert `main.dart`, the gradle wrapper, `pubspec.lock` and `GeneratedPluginRegistrant.swift` before committing.

## The goal

Every web widget feature works the same in the 4 mobile SDKs: customization, launcher, greeting and the live chat / agent features. The web widget (`conferbot-widget/src`) is the reference. Each feature is built and checked against the web in React Native first, then ported to Android, iOS and Flutter. The web source file it came from is named in a comment.

## Status across the SDKs (2026-10-16)

| Feature | RN | Android | iOS | Flutter |
|---|---|---|---|---|
| Customization basics (header, bubbles, avatar, typing styles, composer, footer) | done | done | done | done |
| Chat background (solid, gradient, image + mask, patterns) | done | done | done | done |
| 27 widget themes, light/dark/auto, theme palette | done | done | done | done |
| Launcher shape, size, offsets, gradient, image, avatar, label, glow | done | done | done | done |
| 56 launcher icons, drawn from the widget SVGs | done | done | done | done |
| Launcher motion (idle moments, message reaction, ripple) | done | done | done | done |
| Signed-in user as `visitorContext` + identity hash | done | done | done | done |
| Greeting card (rules, frequency, 11 styles) | done | logic done, UI on a branch | todo | done (device check pending) |
| Launcher entrance / attention / idle call | done | todo | todo | done (device check pending) |
| Home screen (on/off, ask box, welcome back, requests card, Talk to us, help card, trust, view transitions) | done | done in Compose | todo | done (device check pending) |
| Greet by name (`{{first_name\|there}}` in the owner's texts) | done | done | todo | done |
| Mascots (incl. `mascotInGreeting`, `mascotMotion`, the mascot / pencil typing styles) | done | done in Compose | todo | done (device check pending) |
| `widgetLanguage` (i18n) | todo | todo | todo | todo |
| Message sounds | todo | todo | todo | todo |
| Celebrations / reactions | todo | todo | todo | todo |
| Reply-time wording (header line; home card `homePeople`) | done | home card done | todo | done |
| Handover lifecycle (Connecting line, outcomes, signals, leave queue, restore) | done | todo | todo | done |
| Flow nodes: shared spec, 156 fixtures (RN `scripts/parity/flows/`) | 156/156 | todo | todo | 156/156 |
| Device language on every response record | done | done | todo | done |
| "Helpful?": a No sent at once, reasons, comment, Talk to a person, Ask another way, vote changes | done | done | todo | done |
| Requeued / transfer lines, the same end once, blocked visitor, closed chat with a new chat | done | done | todo | done |
| Markdown tables, h3-h6, quote, pre, strikethrough; reply timeout notice; muted fallback | done | done | todo | done |
| Email me this chat (server embed-server #193) | done | done | todo | done |
| While you wait: help articles at 6s, `queue-help` + "That solved it", the waiting games at 2.5s | done | done in Compose | todo | done |
| "Your requests": list, one request, reply, live updates, unread | done (home screen card and chat menu) | done in Compose | todo | done (home screen card and chat menu) |
| Post-chat survey questions read `enablePostChatSurveyQuestions` | todo (no survey questions) | done | todo | done |

Live chat / agent features (handover, queue card, receipts, rating, files, prefill, max-wait timeout, agent bot replies, suggestion chips) are done in all 4.

Each SDK repo has its own `docs/PARITY.md`. The React Native one also covers the generators in `scripts/parity/` and the greeting card spec in `docs/greeting-card-native-spec.md`.

### Web sources for the features still to do

All paths are under `conferbot-widget/src/`.

- **Home screen (done here, #80):** `ts/home/` (firstImpression, homeCopy, homeUtils, askBox, trust, visitorMemory, requests/card; pageAware is not in apps), `ts/chat/replyTime.ts` homeLine / homePeople, `ts/layout/viewTransition.ts`, `ts/layout/ownerLayout.ts` personalize; CSS `css/polish.css` (Home), `polish-home.css`.
- **Mascots (done here, #81):** `ts/home/mascotMotion.ts`, `ts/launcher/launcherStyle.ts`, `ts/launcher/art3d.ts`, `ts/visibility/greeting.ts`, `css/polish.css` (.cb-typing--mascot, --pencil), `css/polish-home.css` (.cb-mm, the card's moves).
- **i18n:** `ts/i18n.ts` + `ts/i18n/{en,de,es,fr,nl}.ts`.
- **Sounds:** `ts/chat/messageSound.ts`.
- **Celebrations:** `ts/chat/delight/` (celebrate, reactions, rules) and `ts/chat/ratingFx.ts`.
- **Reply time:** `ts/chat/replyTime.ts`, `replyTimeView.ts`, `headerPresence.ts`.

### Porting the greeting card (from RN)

- **`src/core/greeting.ts`** is pure and tested. Port it with its tests.
  - `decideGreeting(c, facts)` picks the card:
    - The app counts as path "/". Rules for given pages, countries, sources, page attributes or browser-only behaviour never apply.
    - The rest are checked for audience (new/returning, signed in), schedule, `minVisits`, chatted, and their own limits (`maxShows` within `windowDays`, `quietDaysAfterDismiss`). They are ranked by priority, then by order.
    - A "show nothing" rule silences the card. A smart rule (sgpric, sgads0, sgretn, sgengd, sgcust, sgchko) gives way when the owner's own talking rule applies.
    - The legacy `proactivePrompt*` teaser has a delay of 8. Text is capped at 140 characters.
  - `frequencyAllows`:
    - page: 300s rest after a close or after the chat opens.
    - session: once per app session.
    - visitor: once every N days.
- **`FloatingWidget/useGreeting.ts`** holds the state, stored per bot as `{visits, chatted, shows, dismissed, closedAt, shownAt, last}`.
  - Visits are counted once per app session.
  - The X calls `dismiss()`, which records a dismissal of that rule. Tapping the card calls `closeForNow()`, which only rests it.
  - Opening the chat sets `chatted` and rests the card.
  - Signed in means the visitor context has an id or email.
- **`FloatingWidget/GreetingCard.tsx`** draws the 11 styles: card, note, imessage (default), postcard, sticky, typewriter, glass, notification, neon, voice, aurora. The geometry, colours, reveal timings and native font fallbacks are in RN's `docs/greeting-card-native-spec.md`.

## Flow nodes

The flow engine follows the shared flow-node spec (conferbot-react-native `scripts/parity/flows/nodes.spec.json`), and `test/parity/flows_test.dart` runs all 156 fixtures through the real `NodeFlowEngine` and every handler (`NodeHandlerRegistry.withAll()`): **156 pass, 0 pending**. The fixtures are a copy (`test/fixtures/parity_flows/`, RN revision in `REVISION`, as of RN `2f0b2a6`). It is a port of the RN engine, `src/core/flow/*` and the handlers.

- **The driver** (`test/parity/flow_driver.dart`):
  - The clock is virtual. Each case runs in a Zone whose timers the driver fires in time order, and the engine reads the same clock (2026-10-15 10:00 UTC, as `web/env.js`).
  - The bot API is a `MockClient` scripted from `server.http`.
  - A fake socket answers `execute-integration` and `initiate-handover` from `server.integration` and `server.handover`.
  - Each visitor action is played through `engine.submitResponse`, with the answer the SDK's cards send (the table in the README).
  - The engine reports what it does through `NodeFlowEngineConfig.onTrace`: enter, shown, port, unsupported, error, end and crash.
- **Compared:** path (node, type, via), ports, variables (key and value), the end, errors (count and node), answers (shape and value fields), rendered text, emits, unsupported steps, http (path and body keys), flowVariables, and the typing pace between shown steps, within 50 ms.
- **Not compared, on purpose:**
  - The pace in 7 cases (`timingSkip`). The web harness plays the next action after its cards' own UI timers (focus 30-50 ms, the address search debounce, animations), which native cards don't have.
  - The times the visitor acted at (`consent_at`, `signature_at`), which are compared as timestamps.
  - Emits of `response-record` and `join-chat-room-visitor`, which are transport, not flow.
- **Engine rules** (spec `engine`):
  - Start at the first `welcome-node`.
  - A step that does not branch takes its first edge. A branch takes its exact handle or ends the chat. A wired edge to a missing node stops the chat where it is.
  - Unknown types, and a welcome reached again, pass along their first edge. A jump to a missing node ends the chat.
  - The rich steps' `goPort` fallback, loops and sub-flows.
  - Answer variables are registered per step and saved by name. An unknown `{var}` shows nothing.
  - Masking follows `redactSensitive`.
  - Typing pace is `paceFor` unless a fixed `typingDelay` is set. Images and videos move on when they load (`engine.mediaSettled`) or at 4000 ms.
  - The runaway guard is 500 steps without the visitor, not a cap on distinct steps.
- **Time zones:** business hours, calendar slots and date limits read IANA zones through `package:timezone` (`core/flow/zones.dart`), with DST.
- **The chat UI:**
  - Each step says its own lines through `botMessageStream`: questions, greetings, answers, and media lines (image, video, audio, file, HTML, link) that `MessageBubble` draws. The visitor's answers come through `userMessageStream`.
  - The waiting step's card is `currentUIState`. `NodeRenderer` draws it, keyed by the step's visit (`NodeFlowEngine.stepVisit`) for the cards that take tries (OTP, signature, address, matrix, consent, date/time, payment), else by the state. So two steps never share a card, and a refused answer keeps what the visitor entered. The refusal (`validationMessage`, `ConferBotProvider.stepError`) is shown on the card (#72).
  - Typed questions are answered in the bottom bar. The OTP, signature and address cards have their own fields, so the bar is hidden for them.
  - Every step that waits has its web card, in the bot's option colours, option corner radius and font size and the theme's card colours (`ui/widgets/step_style.dart`, web `css/nodes/08-rich-cards.css`). Nothing moves on its own.

    | Step | Card | File |
    |---|---|---|
    | signature | a pad to sign with a finger (Undo, Clear), sent as a trimmed PNG; "Type instead" with a preview; the full name when asked; the consent line | `signature_step.dart` |
    | otp | the e-mail with Send code (and Skip); six digit boxes (paste and one-time-code autofill, six digits verify on their own), Verify, Resend after its countdown, Change email | `otp_step.dart` |
    | address | search with suggestions as you type (the typed words in bold), the pick confirmed on a 3x3 map-tile map with a pin and "View map", or typed by hand | `address_step.dart` |
    | consent | the text with its links (they open in the browser), bold and italics, a box to tick, Continue, "(optional)" | `consent_step.dart` |
    | datetime | the phone's date / time picker within the step's bounds, the closed days said up front, the step's button | `date_steps.dart` |
    | calendar | the month grid in the bot's colour, past days and days without free times greyed, then the day's free times | `date_steps.dart` |
    | payment | what is paid for and the amount, "Secure checkout by Stripe", the waiting line once open, Cancel / I've paid / Pay now | `payment_step.dart` |
    | carousel, product card | cards with image, title, price, description; path buttons in the option colours; link buttons with their site and an open icon; Continue when there is no path | `rich_node_widgets.dart` |
    | slider, ranking, matrix | the value over the track with its ends; numbered rows with up / down; rows of options with progress ("2 of 3 answered") | `rich_node_widgets.dart` |
    | image choice | two columns (one for a single image, a row to scroll past four), each picture over its label, ringed when picked | `node_widgets.dart` |
  - `test/widgets/step_views_test.dart` plays every fixture that has a card through the cards: the driver records what each action finds waiting, the widget test plays the action on the card with taps, typing and drags (the card pumped again with the next state of the same visit), and the driver runs again with what the cards sent. All 24 come out as the web's. `STEP_IMAGES_DIR=/abs/dir flutter test --update-goldens test/widgets/step_views_images_test.dart` writes an image of each card (map tiles don't load in tests).

## Conventions

- One commit per file: `feat|fix|style|test|docs|ci(scope): ... (#issue)`.
- One GitHub issue per bug, in this repo. Close it with the commit hashes.
- Update the README in the same batch.
