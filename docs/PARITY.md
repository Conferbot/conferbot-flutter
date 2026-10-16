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
| #75 | `SocketClient.dispose()` no longer throws when the socket is not already disconnected (it reported the state on a closed stream) | `services/socket_client.dart` |
| #73 | Launcher entrance (12 effects), attention (8 modes) and idle call (5), ported from RN #57. `keyframes.dart` evaluates the web's Web Animations tracks and passes RN's Chrome golden (447 cases, 19,275 samples; largest error 0.0007px, 0.005deg, 0.00005 scale and opacity, 0.03px `left`, 0.42px on the plane's path). The tracks are rebuilt from the same code and match the golden's. The rules are in the three controllers. Checked with widget-test images, not yet on a device | `core/customization/keyframes.dart`, `launcher_entrance.dart`, `launcher_attention.dart`, `launcher_idle_call.dart`, `mascot_art.dart`, `fx_paint.dart`; `widgets/launcher_fx_controllers.dart`, `launcher_fx_views.dart`, `fx_svg.dart`, `conferbot_fab.dart`; `test/fixtures/launcherfx_golden.json` |

## Left in this SDK

1. **Greeting card follow-ups:**
   - Check it on a device (iOS and Android).
   - Not drawn yet, as in RN: the word fade-up, the "Online" ping, the exit animations, the mascot and the agent's reply field.
2. **Handover follow-ups:**
   - #64: the help articles shown while waiting (`queue-help`, "That solved it") are not drawn.
   - Leave queue was checked against the server with a visitor socket (this simulator has no tap tool); the button itself is covered by widget tests.
   - After a restore that is still waiting, the max-wait timer starts over rather than from the server's `waitEndsAt`.
3. **Launcher effects follow-ups (#73):**
   - Check them on a device (iOS and Android). They are covered by unit tests on a fake clock, a launcher widget test and widget-test images only.
   - As in RN, web filters (brightness, glows, blur, the mascot's bevel) are not drawn, and the waving hand is the system emoji.
4. **Live chat extras follow-ups (#42-#44, #46, #47, #52):**
   - Check them on a device (iOS and Android). They are covered by unit tests, fake-socket tests and widget tests only; the transcript call only against a stubbed HTTP client.
   - As on the web, a transfer is not drawn, and the reply-timeout notice is not kept in the record.
   - The cards (Email me this chat, the closed chat) sit at the end of the paginated message list, as the other live chat cards do; `ChatWidget(enablePagination: false)` does not draw them.
5. The rest of the list below.
6. **Test debt:**
   - #16: `media_service_test` fails because MockController is not an AudioPlayer.
   - #58: the older help centre widget tests (`article_list_test`, `article_detail_test`, `category_chips_test`) and `message_bubble_test` don't compile or fail. The help centre is covered by `test/core/help_centre/`, `test/providers/knowledge_base_provider_test.dart` and `test/widgets/knowledge_base/help_centre_test.dart`.
7. **Flow node follow-ups:**
   - Check the step cards on a device (iOS and Android). They are covered by widget tests and images only (no emulator or simulator run).
   - Address: no "Use my location" (it would need a location plugin); search, the map and typing by hand work.
   - Hidden fields read the page the chat runs on. An app has none: the provider passes no `NodeFlowEngineConfig.page`.
   - The visitor's time zone is the device's offset as a fixed `Etc/GMT` zone, because Dart does not expose the IANA name. The provider does not pass `NodeFlowEngineConfig.visitorTimeZone` yet.
8. There's no `identify()` after construction; the user comes only from the provider's `user`.
9. **Help centre follow-ups:**
   - Ratings still use the SDK's 1-5 stars over REST; the web sends helpful / not helpful (`rate-article`). Reading time and scroll depth (`track-article-engagement`) are not sent.
   - Search uses REST (`/knowledge-base/search?query=`) plus local title matches; the socket's `search-kb-articles` (with snippets) is not used.
   - No home screen yet, so Recent articles sit at the top of the help centre list rather than on a welcome screen.

## How to test

- **Unit tests:** `flutter test test/core` (skip the media test, #16).
- **Flow nodes:** `flutter test test/parity/flows_test.dart` runs the 156 fixtures; `flutter test test/widgets/step_views_test.dart` plays them through the step cards; `flutter test test/core/node_flow_engine_test.dart test/core/handlers test/core/flow test/core/privacy test/widgets/node_renderer_test.dart test/widgets/flow_media_lines_test.dart` covers the engine API, the handlers, the flow rules and the step cards. `tool/sync_flow_fixtures.sh` copies the fixtures from the React Native repo (`RN_SDK` if it is not next door) into `test/fixtures/parity_flows/` and writes the RN revision to `REVISION`.
- **Handover lifecycle:** `flutter test test/core/live_chat test/core/agent test/widgets/handover/handover_lifecycle_widgets_test.dart`. `handover_lifecycle_test.dart` drives the lifecycle against a fake socket and a fake clock.
- **Handover on a device:** a temporary bot in local Mongo (`conferbotStaging`) with welcome -> human-handover-node (`enableHandoverEmail: false`) -> message, linked in `workspaces.chatbots` and `admins.chatbots` (the server finds a bot's workspace through `admins`). A node socket.io-client script plays the agent with a dashboard JWT signed with the server's `JWT_ACCESS_SECRET` (`auth: {userId, workspaceId, token}`): `accept-handover`, `leave-chat` with `agentDetails.isAIAgent: true` (the visitor sees an AI escalating), `end-chat`. Hot restart (`R`) checks the restore: count `initiate-handover` in the app log and the session's tickets. Delete the bot and everything for its sessions afterwards.
- **Help centre:** `flutter test test/core/help_centre test/providers/knowledge_base_provider_test.dart test/services/knowledge_base_service_test.dart test/widgets/knowledge_base/help_centre_test.dart`. The payloads in `test/fixtures/kb_payloads.json` were captured from a local embed-server (socket `fetched-chatbot-data`, `get-kb-article`, `search-kb-articles`; REST `/mobile/chatbot/:id/kb` and `/mobile/knowledge-base/*`). To refresh them, run a small socket.io-client script against `:8001` with a bot that has published articles.
- **Launcher entrance, attention, idle call:** `flutter test test/parity/launcherfx_test.dart` checks the evaluator against RN's Chrome golden and rebuilds every track the golden was sampled from; `tool/sync_launcherfx_golden.sh` copies the golden from the React Native repo (`RN_SDK` if it is not next door) and writes its RN revision to `test/fixtures/launcherfx_golden.REVISION`. `flutter test test/core/customization/launcher_fx_test.dart test/widgets/launcher_fx_controllers_test.dart test/widgets/launcher_fx_fab_test.dart` covers the settings, the rules on a fake clock and the launcher. `LAUNCHERFX_IMAGES_DIR=/abs/dir flutter test --update-goldens test/widgets/launcher_fx_images_test.dart` writes six frames of every effect (a 390 x 844 screen, a 50px launcher) to that directory, outside the repo.
- **Live chat extras (#42-#44, #46, #47, #52, #74):** `flutter test test/core/device_language_test.dart test/core/agent test/core/live_chat test/utils/chat_markdown_test.dart test/services/socket_handshake_test.dart test/services/api_client_test.dart test/core/handlers/handlers_test.dart test/widgets/helpful_row_test.dart test/widgets/live_chat test/widgets/markdown_message_test.dart`. The transcript email is only ever called against `MockClient` (no email is sent); a real send needs a local embed-server and a session of a bot you own.
- **Full suite (2026-10-16):** 1239 pass, 60 skipped, 65 fail. The 65 are the same as before this batch: #16 (`media_service_test`), #71 (provider, socket client, storage and validation tests) and the older widget tests (#58 and the like, including `markdown_message_test`'s mailto case); none in the launcher, flow, handover or live chat extras tests.
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
| Home screen | todo | todo | todo | todo |
| Mascots (incl. `mascotInGreeting`) | todo | todo | todo | todo |
| `widgetLanguage` (i18n) | todo | todo | todo | todo |
| Message sounds | todo | todo | todo | todo |
| Celebrations / reactions | todo | todo | todo | todo |
| Reply-time wording (header line) | done | todo | todo | done |
| Handover lifecycle (Connecting line, outcomes, signals, leave queue, restore) | done | todo | todo | done |
| Flow nodes: shared spec, 156 fixtures (RN `scripts/parity/flows/`) | 156/156 | todo | todo | 156/156 |
| Device language on every response record | done | done | todo | done |
| "Helpful?": a No sent at once, reasons, comment, Talk to a person, Ask another way, vote changes | done | done | todo | done |
| Requeued / transfer lines, the same end once, blocked visitor, closed chat with a new chat | done | done | todo | done |
| Markdown tables, h3-h6, quote, pre, strikethrough; reply timeout notice; muted fallback | done | done | todo | done |
| Email me this chat (server embed-server #193) | done | done | todo | done |
| Post-chat survey questions read `enablePostChatSurveyQuestions` | todo (no survey questions) | done | todo | done |

Live chat / agent features (handover, queue card, receipts, rating, files, prefill, max-wait timeout, agent bot replies, suggestion chips) are done in all 4.

Each SDK repo has its own `docs/PARITY.md`. The React Native one also covers the generators in `scripts/parity/` and the greeting card spec in `docs/greeting-card-native-spec.md`.

### Web sources for the features still to do

All paths are under `conferbot-widget/src/`.

- **Home screen:** `ts/home/` (homeCopy, askBox, trust, pageAware, visitorMemory).
- **Mascots:** `ts/home/mascotMotion.ts`, `ts/launcher/launcherStyle.ts`, `ts/launcher/art3d.ts`, `ts/visibility/greeting.ts`. The `mascot` typing style is accepted but not drawn yet.
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
