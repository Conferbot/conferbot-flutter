// "Email me this chat" card (#42, the transcript call stubbed: no email is
// sent) and the closed chat card (#43). The cases of the React Native SDK's
// __tests__/components/LiveChatCards.test.tsx.
import 'package:conferbot_flutter/src/core/live_chat/email_transcript.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_chat_extras.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_events.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/widgets/live_chat_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_socket_client.dart';

void main() {
  final state = ChatState.instance;
  late List<String> posted;
  late TranscriptEmailResult answer;
  late LiveChatExtras live;

  setUp(() {
    state.reset();
    state.initialize(chatSessionId: 's1', visitorId: 'v1', botId: 'b1');
    posted = [];
    answer = const TranscriptEmailResult(true);
    live = LiveChatExtras(
      socket: () => MockSocketClient(),
      sessionId: () => 's1',
      addMessage: (_) {},
      sendRecord: () {},
      postTranscriptEmail: (_, email) async {
        posted.add(email);
        return answer;
      },
    );
  });

  tearDown(() => state.reset());

  Future<void> pumpMail(WidgetTester tester) async {
    live.openEmailTranscript();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: live,
          builder: (_, __) => live.mailOpen || live.mailSentTo != null ? EmailTranscriptCard(liveChat: live, theme: defaultTheme) : const SizedBox(),
        ),
      ),
    ));
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets('the known email filled in; sent, then "Sent! Check your inbox at ..."', (tester) async {
    state.setUserMetadata('email', 'ada@example.com');
    await pumpMail(tester);
    expect(find.text('Email me this chat'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    await tester.tap(key('cb-mailchat-send'));
    await tester.pumpAndSettle();
    expect(posted, ['ada@example.com']);
    expect(find.text('Sent! Check your inbox at ada@example.com'), findsOneWidget);
  });

  testWidgets('a bad address is not sent; the server\'s reason is shown; Cancel closes', (tester) async {
    await pumpMail(tester);
    await tester.enterText(find.byType(TextField), 'ada@example');
    await tester.tap(key('cb-mailchat-send'));
    await tester.pump();
    expect(find.text('Please check the email address.'), findsOneWidget);
    expect(posted, isEmpty);

    answer = const TranscriptEmailResult(false, 'Too many requests. Please try again later.');
    await tester.enterText(find.byType(TextField), 'ada@example.com');
    await tester.tap(key('cb-mailchat-send'));
    await tester.pumpAndSettle();
    expect(find.text('Too many requests. Please try again later.'), findsOneWidget);

    await tester.tap(key('cb-mailchat-cancel'));
    await tester.pump();
    expect(key('cb-mailchat'), findsNothing);
  });

  testWidgets('blocked: the closed line, no new chat; ended: Start a new chat', (tester) async {
    var newChats = 0;
    Future<void> pumpClosed(ClosedState closed) => tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ClosedChatCard(closed: closed, theme: defaultTheme, onNewChat: () => newChats++)),
        ));

    await pumpClosed(LiveEvents.closedStateOf(const [], blocked: LiveEvents.closedText)!);
    expect(find.text('This conversation has been closed.'), findsOneWidget);
    expect(key('cb-new-chat'), findsNothing);

    await pumpClosed(LiveEvents.closedStateOf(const [
      {'type': 'agent-chat-ended'},
    ])!);
    expect(find.text('This conversation has been closed.'), findsNothing);
    await tester.tap(find.text('Start a new chat'));
    expect(newChats, 1);
  });
}
