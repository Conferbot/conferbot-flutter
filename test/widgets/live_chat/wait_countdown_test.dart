// The wait card's max-wait countdown (#38) and the AI's inactivity line
// (#35): LiveChatExtras' deadline and its handover-timeout, a restored
// wait's seconds left, the card counting down once a second and stopping at
// 0:00, the paused and ended lines drawn. The cases of the React Native
// SDK's __tests__/context/useLiveChatExtras.test.ts (#42),
// __tests__/components/WaitCountdown.test.tsx and InactiveCloseLine.test.tsx.
import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_chat_extras.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_events.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:conferbot_flutter/src/models/message.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/widgets/live_chat_cards.dart';
import 'package:conferbot_flutter/src/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_socket_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = ChatState.instance;
  late MockSocketClient socket;
  late LiveChatExtras live;
  // The clock the deadline and the card read, moved with the test's timers.
  late int now;
  const step = {'maxWaitTime': 2, 'assignmentType': 'auto'};

  setUp(() {
    state.reset();
    state.initialize(chatSessionId: 's1', visitorId: 'v1', botId: 'b1');
    now = DateTime.utc(2026, 10, 16, 10).millisecondsSinceEpoch;
    socket = MockSocketClient()..mockIsConnected = true;
    live = LiveChatExtras(socket: () => socket, sessionId: () => 's1', addMessage: (_) {}, sendRecord: () {}, now: () => now);
  });

  tearDown(() {
    live.dispose();
    state.reset();
    I18n.setWidgetLanguage('en');
  });

  Future<void> wait(WidgetTester tester, int ms) async {
    now += ms;
    await tester.pump(Duration(milliseconds: ms));
  }

  Widget card() => MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(listenable: live, builder: (_, __) => HandoverWaitCard(liveChat: live, theme: defaultTheme)),
        ),
      );

  Finder countdown() => find.byKey(const ValueKey('cb-wait-countdown'));
  String countdownText(WidgetTester tester) =>
      tester.widget<Text>(find.descendant(of: countdown(), matching: find.byType(Text))).data!;

  testWidgets('the max wait: a deadline while waiting, then handover-timeout at it', (tester) async {
    expect(live.waitEndsAt, isNull);
    live.startWaitTimer(Map<String, dynamic>.from(step), 'w1');
    expect(live.waitEndsAt, now + 2 * 60000);
    await wait(tester, 2 * 60000 - 1);
    expect(socket.wasEventEmitted('handover-timeout'), isFalse);
    await wait(tester, 1);
    final sent = socket.getEmittedEvents('handover-timeout').single.data as Map;
    expect(sent['chatSessionId'], 's1');
    expect(sent['workspaceId'], 'w1');
    // A person joined (or the wait ended): no countdown.
    live.stopWaitTimer();
    expect(live.waitEndsAt, isNull);
  });

  testWidgets("a restored wait counts down from the server's seconds left, once", (tester) async {
    live.resumeWaitWith(40);
    live.startWaitTimer({'maxWaitTime': 5}, 'w1');
    expect(live.waitEndsAt, now + 40000);
    await wait(tester, 40000);
    expect(socket.getEmittedEvents('handover-timeout'), hasLength(1));
    // The next wait has the step's full max wait again.
    live.stopWaitTimer();
    live.startWaitTimer({'maxWaitTime': 5}, 'w1');
    expect(live.waitEndsAt, now + 5 * 60000);
    live.stopWaitTimer();
  });

  testWidgets('the wait card counts down once a second and stops at 0:00', (tester) async {
    await tester.pumpWidget(card());
    expect(countdown(), findsNothing);
    live.resumeWaitWith(65);
    live.startWaitTimer(Map<String, dynamic>.from(step), 'w1');
    await tester.pump();
    expect(countdownText(tester), 'Max wait 1:05');
    await wait(tester, 1000);
    expect(countdownText(tester), 'Max wait 1:04');
    await wait(tester, 4000);
    expect(countdownText(tester), 'Max wait 1:00');
    await wait(tester, 60000);
    expect(countdownText(tester), 'Max wait 0:00');
    await wait(tester, 5000);
    expect(countdownText(tester), 'Max wait 0:00');
    // Not a live region: it would talk every second.
    final semantics = tester.widget<Semantics>(find.descendant(of: countdown(), matching: find.byType(Semantics)).first);
    expect(semantics.properties.liveRegion, isFalse);
    // The wait is over: the line goes.
    live.stopWaitTimer();
    await tester.pump();
    expect(countdown(), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("the countdown in the visitor's language", (tester) async {
    I18n.setWidgetLanguage('de');
    live.startWaitTimer(Map<String, dynamic>.from(step), 'w1');
    await tester.pumpWidget(card());
    expect(countdownText(tester), 'Max. Wartezeit 2:00');
    live.stopWaitTimer();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the paused and ended lines drawn, the note under the pause', (tester) async {
    SystemMessageRecord line(Map<String, dynamic> entry) {
      final l = LiveEvents.inactiveCloseLine(entry);
      return SystemMessageRecord(id: '${entry['paused']}', time: DateTime.now(), text: l.text, kind: 'ai-agent-inactive-close', note: l.note);
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          MessageBubble(message: line({'paused': true}), theme: defaultTheme),
          MessageBubble(message: line({'paused': false}), theme: defaultTheme),
        ]),
      ),
    ));
    expect(find.text('Chat paused'), findsOneWidget);
    expect(find.text('Send a message to pick up where you left off'), findsOneWidget);
    expect(find.text('Chat ended'), findsOneWidget);
    expect(find.byType(LiveChatLine), findsNWidgets(2));
  });
}
