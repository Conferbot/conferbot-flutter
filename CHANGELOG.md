# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- The post-chat rating is asked unless the owner switched Post-chat feedback off, as on the web; bots that never set it get the stock stars and wording instead of no rating (#100).
- "Talk to a person" shows under AI answers on any bot whose owner turned it on, including a flow handed to an AI agent, as on the web; it needed an agent-only bot (#101).

### Changed

- The widget's words shared by all SDKs include its signature and street-address error messages in all five languages, matching the web widget (#103).

## [2.0.1] - 2026-10-18

### Fixed

- The coin entrance's glint waits off the button's left edge through its delay instead of showing as a white streak at its left side before the sweep (#97).
- An idle call's mascot (psst, wave, knock, tap) keeps facing the screen on a left-side launcher; the slide's scale dropped its mirror, so it faced the edge (#97).
- `ApiClient.sendMessage` matches the store-only REST route `POST session/{id}/message`: it takes `record`, `answerVariables` and `visitorId`, posts `{ record, answerVariables, visitorId? }` and returns the server's data (`storeOnly: true`; a failure when an agent locked the chat). The route never runs the bot; messages still go over the socket (#98).
- The example app builds for Android with the current Flutter stable (3.38): Gradle 8.13, Android Gradle Plugin 8.11.1, Kotlin 2.1.0 and `compileSdk` 36. The package itself is unchanged (#95).

### Deprecated

- `ApiClient.sendMessage`'s `message` and `metadata` (now optional): the route never took `{ message, metadata }`, so a call without `record` sends nothing and fails with `STORE_ONLY_ROUTE`. Use `ConferBotProvider.sendMessage` (#98).

## [2.0.0] - 2026-10-16

Everything since 1.0.0: the SDK now does what the web widget does, from the
flow builder's 82 step types to the launcher, the home screen, live chat, the
help centre and push. The status per feature is in
[docs/PARITY.md](docs/PARITY.md).

### Breaking changes & migration

- **Node handlers rewritten.** The 1.0.0 handler classes are gone, together
  with the files they lived in (`ask_question_handlers.dart` and the old
  integration, Google, CRM, GPT and webhook handlers): `AskNameNodeHandler`,
  `AskEmailNodeHandler`, `AskPhoneNodeHandler`, `AskNumberNodeHandler`,
  `AskUrlNodeHandler`, `AskFileNodeHandler`, `AskLocationNodeHandler`,
  `AskCustomNodeHandler`, `AskMultipleQuestionsNodeHandler`,
  `BaseAskNodeHandler`, `MessageNodeHandler`, `ImageNodeHandler`,
  `VideoNodeHandler`, `AudioNodeHandler`, `FileNodeHandler`, `HtmlNodeHandler`,
  `NavigateNodeHandler`, `UserRedirectNodeHandler`, `CalendarNodeHandler`,
  `ConditionNodeHandler`, `BooleanLogicNodeHandler`, `MathOperationNodeHandler`,
  `RandomFlowNodeHandler`, `JumpToNodeHandler`, `BusinessHoursNodeHandler`,
  `VariableNodeHandler`, `DelayNodeHandler`, `LogicNodeHandlers`,
  `ChatStateInterface`, and the old states `MessageState`, `ImageState`,
  `VideoState`, `AudioState`, `FileState`, `HtmlState`, `RedirectState`,
  `PaymentState`, `TextInputState`, `FileUploadState`, `CalendarState`,
  `RangeState`, `QuizState`, `TimeSlot`. One handler per node type now comes
  from `allHandlers()` / `registerAllHandlers(registry)`.
  - `NodeHandler` changed shape: `process(Map nodeData, String nodeId)` is now
    `handle(FlowNode node, ChatState state)`, and
    `handleResponse(response, nodeData, nodeId)` is now
    `handleResponse(response, FlowNode node, ChatState state)`, which returns
    `null` when the step takes no answer. A custom handler has to be ported to
    the new signatures; `FlowNode` carries the saved node and its `ctx` (the
    bot API, the socket, timers).
  - `NodeHandlerRegistry.validateHandlers()` is removed;
    `NodeHandlerRegistry.withAll()` builds a registry with every handler, and
    `NodeHandlerRegistry.instance` still exists.
  - Waiting steps answer with `submitResponse` in the shapes listed in the
    README ("How bot flows run"), for example `{'buttonId': id}` for a choice.
- **`ChatWidget.showKnowledgeBase` is now `bool?` and defaults to `null`.**
  In 1.0.0 it was `bool` with a default of `true`, so the help button always
  showed. Now `null` follows the owner's **Help articles**
  (`enableKnowledgeBase`) switch and needs at least one published article.
  Pass `showKnowledgeBase: true` to keep the old behaviour.
- **The chat can open on a home screen.** When the owner turns on the home
  screen (`enableInitialPage`), `ChatWidget` and the floating bubble open on it
  instead of on the conversation. To go straight to the conversation, turn it
  off in the dashboard, or call `provider.home.showChat()`.
- **The post-chat redirect is followed by default.** A URL set in Customize >
  Conversations > Post-chat redirect now opens in the system browser after a
  10 s countdown with Cancel, once the conversation ends. Use
  `ConferBotConfig(disablePostChatRedirect: true)` to turn it off, or
  `onPostChatRedirect: (url) { ...; return true; }` to handle it yourself.
- **The SDK's own words follow the visitor's language.** They were English
  only. Now they are in English, Dutch, French, German or Spanish (the owner's
  `widgetLanguage`, else the phone's language). Use
  `ConferBotConfig(widgetLanguage: 'en')` to keep English.
- **Owner settings that were ignored now apply:** the widget theme (and its
  dark mode, which follows the phone's when the appearance is auto), the
  font (downloaded from Google Fonts at run time), message sounds (played
  through `audioplayers`, with Sound on / off in the chat menu), auto-open,
  the greeting card (it replaces the plain call-to-action tooltip), the
  launcher shape, style, icon and motion, and the human touches (tapbacks,
  confetti, "Edit", the waiting nudge). Each one is controlled from the
  dashboard.
- **Push registration changed.** `ConferBotProvider.registerPushToken(token)`
  is now an alias of `setPushToken(token)` and no longer waits for an open
  chat. Use `setPushToken(token, PushTokenType.fcm | .apns)`. The token is
  registered per conversation (`POST /push/register` with `chatSessionId` and
  `tokenType`, through `ApiClient.registerPush`), and unregistered on
  `identify(null)`, `clearAllPersistedData()`, `clearCurrentSession()` and
  `unregisterPush()`. This needs an embed-server with mobile push on (see the
  README).
- **The provider's `user` comes from `identify`.** `ConferBotProvider.user` is
  still readable, but it is now a getter that `identify(user)` and
  `identify(null)` change. The user, `metadata` included, is now sent with
  every response record as the visitor context.
- **`ChatState.setAnswerVariable` returns `bool`** (it returned `void`):
  whether a variable was registered for that node. Code that overrides it
  needs the new return type.
- **New dependency:** `timezone: ^0.11.2`, for business hours and calendars in
  the bot's IANA time zone.

### Added

- AI agent bots (Agent Studio): the greeting with starter questions, streamed
  replies, sources, answer buttons, cards, action confirmation, follow-up
  chips, edited and deleted messages, and **Helpful?** with reasons, a
  comment, "Talk to a person" and "Ask another way". There is a notice after
  45 s with no reply, and the phone's language goes with each record so the
  AI answers in it.
- Live chat as on the web: the handover lifecycle ("Connecting you with the
  team…" and how the wait ended), the queue and its position, the usual wait
  and a max-wait countdown, Leave queue, leave a message, receipts, locks,
  file requests, the lead card, the rating, translation with "See original",
  requeue and transfer lines, a blocked visitor, **Start a new chat**, and a
  live chat picked back up after a restart (`live-chat-state`).
- The waiting signals `WidgetSignals.waitingForHuman`, `humanJoined` and
  `waitOver` through `provider.onWidgetSignal`.
- While you wait: help articles for the visitor's question after 6 s, the
  server's `queue-help` pick with **That solved it**, and seven waiting games
  (`WaitHelpCard`, `GamesCardView`).
- **Email me this chat** in the chat menu (`provider.emailTranscript`).
- **Your requests**: the visitor's conversations with the team, their status,
  new replies and a reply box (`RequestsPortal`, `RequestsPortalView`,
  `provider.openRequests`, `provider.requestsUnread`).
- The home screen (`HomeScreenView`, `ViewSwitch`, `provider.home`,
  `provider.homeModel`) and greet by name (`{{first_name|there}}`,
  `personalize`).
- `identify(ConferBotUser?)` to sign a user in or out after start-up, and
  `ConferBotUser.hash` for identity verification.
- Push notifications: `setPushToken`, `handlePushNotification`,
  `unregisterPush`, `ConferbotPush.parse` / `isConferbot`, `PushTokenType`,
  `pushChannelId`. The SDK adds no Firebase dependency.
- Customization resolved as the web widget does: the 27 widget themes, the
  chat background (gradients, image masks, 13 patterns), bubble and option
  colours and corners, the header, the typing styles (dots, wave, shimmer,
  pencil, mascot).
- The launcher as on the web: 56 icons, shapes, styles, motion, and the
  opt-in entrance, attention and idle call effects. The greeting card has 11
  styles and the web's greeting rules and frequency.
- The owner's mascot, 27 characters with their moods (`Mascot`,
  `TypingMascot`, `LauncherMascot`, `ChatWidget.homeMascotBuilder`).
- Every step type the web runs (82), with native step cards: consent, OTP,
  address (with "Use my location" through
  `ConferBotConfig.locationProvider`, `ConferBotLatLng`,
  `ConferBotLocationDenied`), signature, ranking, matrix, payment, slider,
  date / time, carousel and product cards, picture choices. The flow is
  checked against 156 shared cases from the web widget's own code.
- Calendar slots that are already booked are shown as taken, and fully
  booked days are not offered.
- Sounds (`messageSound`, `soundPack`, the launcher sound), auto-open, the
  typing preview for agents, the human touches, the owner's font.
- The help centre: the owner's switch, Recent articles, article bodies as
  HTML, search inside bodies over the chat's socket, "Was this helpful?",
  reading analytics, and AI-cited articles opened in the app.
- `ConferBotConfig.widgetLanguage`, `onPostChatRedirect`,
  `disablePostChatRedirect`, `locationProvider`.

### Changed

- Flow answers and records carry the full payload the web widget sends, on
  the mobile channel.
- Each `SocketClient` has its own connection, so a second client connects
  with its own visitor and a reset opens a new connection.
- `ChatWidget`'s header keeps the bot's name and shows the team's reply time,
  or "Online" once a person joins.
- Bot texts are filled from answers (`{x}`, `${x}`, `{{x}}`), and an unknown
  variable shows nothing. Typing dots last as long as the web's.

### Fixed

- Messages were only kept in memory and were lost on a restart. They are now
  stored on the device.
- `session/init` parses without a `botId`.
- Keyboard types come from Flutter's services. The SDK's own text input type
  had shadowed them.
- Steps read the fields the builder saves (question text, answer variables,
  media, links, options) and leave by the web's handles.
- A restored session resumes at its step instead of running the flow again.
- Question bubbles show plain text, not the builder's HTML.
- A `mailto:` link's subject and body are percent-encoded.
- The full test suite is green (2265 pass, 72 skipped).
- The example's widget test pumps the example with no connection instead of the
  stock counter test, and `flutter analyze` in `example/` is clean (#92).
- `SocketClient.onReconnect` fires on each reconnect. socket_io_client tells
  `reconnect` on the Manager, not the Socket, so it never fired; the reconnect
  attempts and the failure are heard on the Manager too (#93).

### Security

- The GPT step no longer calls OpenAI from the device with a key from the
  flow. GPT, AI route and extract, knowledge-base answers, OTP, address
  search and payments go through the bot's server (`/api/v1/bot/:botId/...`).
- Card numbers, bank accounts, government ids and passwords are masked in
  stored and sent answers, as the web does (unless the owner turns off
  `redactSensitive`).
- Identity verification: pass a server-made HMAC-SHA256 as
  `ConferBotUser.hash` so that a chat is filed under a verified user.
- The typing preview is never sent for a secret field (obscured text,
  password autofill), and the owner can turn it off (`visitorDraftPreview`).
- The post-chat redirect follows only `http(s)` URLs.
- A visitor the workspace blocked can't type or start a new chat.

## [1.0.0] - 2026-04-23

### Added
- Initial release of the Conferbot Flutter SDK
- Real-time messaging via Socket.IO
- Node flow engine with 50+ node types
- Live agent handover support
- Message reactions and read receipts
- File and image uploads
- Knowledge base integration
- Session persistence
- Push notification support
- Full theming and customization
- Offline message queuing
- Analytics and event tracking
