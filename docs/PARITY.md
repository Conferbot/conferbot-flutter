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
| #22 | Greeting card: rules, frequency, per-bot state, 11 styles; replaces the old CTA tooltip. Checked with widget-test images, not yet on a device | `core/customization/greeting.dart`, `widgets/greeting_controller.dart`, `widgets/greeting_card.dart`, `widgets/conferbot_fab.dart` |

## Left in this SDK

1. **Greeting card follow-ups:**
   - Check it on a device (iOS and Android).
   - Not drawn yet, as in RN: the word fade-up, the "Online" ping, the exit animations, the mascot and the agent's reply field.
2. The rest of the list below.
3. **Test debt:**
   - #16: `media_service_test` fails because MockController is not an AudioPlayer.
   - `test/core/handlers/*_test.dart` and `node_flow_engine_test.dart` don't compile: they set a `state` that the handlers no longer have.
4. There's no `identify()` after construction; the user comes only from the provider's `user`.

## How to test

- **Unit tests:** `flutter test test/core` (skip the media test, #16).
- **Greeting card images:** `GREETING_GOLDEN_DIR=/abs/dir flutter test --update-goldens test/widgets/greeting_card_test.dart` writes one PNG per style to that directory, outside the repo. It loads Roboto from the Flutter SDK and macOS fonts in place of casual / serif / monospace. Without the variable the image group is skipped.
- **Example app:**
  - To point it at a local server, add `ConferBotEndpoints.configure(apiBaseUrl: 'http://10.0.2.2:8001/api/v1/mobile', socketUrl: 'http://10.0.2.2:8001')` in `example/lib/main.dart`.
  - Build: `flutter build apk --debug --target-platform android-x64` with gradle 8.7.
  - Revert `main.dart`, the gradle wrapper, `pubspec.lock` and `GeneratedPluginRegistrant.swift` before committing.

## The goal

Every web widget feature works the same in the 4 mobile SDKs: customization, launcher, greeting and the live chat / agent features. The web widget (`conferbot-widget/src`) is the reference. Each feature is built and checked against the web in React Native first, then ported to Android, iOS and Flutter. The web source file it came from is named in a comment.

## Status across the SDKs (2026-10-15)

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
| Launcher entrance / attention / idle call | todo | todo | todo | todo |
| Home screen | todo | todo | todo | todo |
| Mascots (incl. `mascotInGreeting`) | todo | todo | todo | todo |
| `widgetLanguage` (i18n) | todo | todo | todo | todo |
| Message sounds | todo | todo | todo | todo |
| Celebrations / reactions | todo | todo | todo | todo |
| Reply-time wording | todo | todo | todo | todo |

Live chat / agent features (handover, queue card, receipts, rating, files, prefill, max-wait timeout, agent bot replies, suggestion chips) are done in all 4.

Each SDK repo has its own `docs/PARITY.md`. The React Native one also covers the generators in `scripts/parity/` and the greeting card spec in `docs/greeting-card-native-spec.md`.

### Web sources for the features still to do

All paths are under `conferbot-widget/src/`.

- **Launcher entrance / attention / idle call (all default off):**
  - `ts/launcher/entrance.ts`, setting `launcherEntrance`: classic default; lightning, rocket, portal, ufo, drop, confetti, coin.
  - `ts/launcher/attention.ts`, setting `launcherAttention`: off, pulse, wobble, bounce, wave, float, shine, heartbeat, orbit.
  - `ts/launcher/idleCall.ts`, setting `launcherIdleCall`: off, psst, peek, wave, knock, tap; delay 12.
  - The CSS is in `css/`.
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

## Conventions

- One commit per file: `feat|fix|style|test|docs|ci(scope): ... (#issue)`.
- One GitHub issue per bug, in this repo. Close it with the commit hashes.
- Update the README in the same batch.
