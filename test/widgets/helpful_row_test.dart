// "Helpful?" under an AI answer (#46): a No goes at once, then reasons, a
// comment, Talk to a person, Ask another way; the rated line's thumbs change
// the vote. The cases of the React Native SDK's
// __tests__/components/AgentReplyHelpful.test.tsx.
import 'package:conferbot_flutter/src/core/agent/agent_bot.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/widgets/agent_reply.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<AnswerFeedback> sent;
  late List<String> asked;
  late int focused;

  Future<void> pump(WidgetTester tester, {AnswerFeedback? initial, bool canTalk = true}) async {
    sent = [];
    asked = [];
    focused = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HelpfulRow(
          // A fresh row each pump (as each answer has its own).
          key: UniqueKey(),
          initial: initial,
          theme: defaultTheme,
          onSend: sent.add,
          onAsk: canTalk ? asked.add : null,
          onRetry: () => focused++,
        ),
      ),
    ));
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets('a No is sent at once, then a reason, then a comment', (tester) async {
    await pump(tester);
    expect(find.text('Helpful?'), findsOneWidget);
    await tester.tap(key('cb-helpful-down'));
    await tester.pump();
    expect(sent, const [AnswerFeedback(false)]);
    expect(find.text('Sorry about that. What went wrong?'), findsOneWidget);
    await tester.tap(key('cb-helpful-reason-outdated'));
    await tester.pump();
    expect(sent.last, const AnswerFeedback(false, 'outdated'));
    await tester.enterText(key('cb-helpful-comment'), 'the price changed');
    await tester.tap(key('cb-helpful-comment-send'));
    await tester.pump();
    expect(sent.last, const AnswerFeedback(false, 'outdated', 'the price changed'));
    expect(find.text('Thanks, that helps us improve.'), findsOneWidget);
  });

  testWidgets('Talk to a person asks in the visitor\'s words; Ask another way puts the cursor in the composer', (tester) async {
    await pump(tester);
    await tester.tap(key('cb-helpful-down'));
    await tester.pump();
    await tester.tap(key('cb-helpful-human'));
    await tester.pump();
    expect(asked, ["I'd like to talk to a person, please."]);
    expect(key('cb-helpful-rated'), findsOneWidget);
    expect(find.text('Not helpful'), findsOneWidget);

    await pump(tester);
    await tester.tap(key('cb-helpful-down'));
    await tester.pump();
    await tester.tap(key('cb-helpful-retry'));
    await tester.pump();
    expect(focused, 1);
  });

  testWidgets('no Talk to a person while someone is coming or here', (tester) async {
    await pump(tester, canTalk: false);
    await tester.tap(key('cb-helpful-down'));
    await tester.pump();
    expect(key('cb-helpful-human'), findsNothing);
    expect(key('cb-helpful-retry'), findsOneWidget);
  });

  testWidgets('a Yes thanks, then the rated line; its thumbs change the vote', (tester) async {
    await pump(tester);
    await tester.tap(key('cb-helpful-up'));
    await tester.pump();
    expect(sent, const [AnswerFeedback(true)]);
    expect(find.text('Thanks for letting us know!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    expect(key('cb-helpful-rated'), findsOneWidget);
    expect(find.text('Helpful'), findsOneWidget);
    // The same thumb again sends nothing; the other one changes the vote.
    await tester.tap(key('cb-helpful-up'));
    await tester.pump();
    expect(sent, hasLength(1));
    await tester.tap(key('cb-helpful-down'));
    await tester.pump();
    expect(sent.last, const AnswerFeedback(false));
    expect(key('cb-helpful-rated'), findsNothing);
    expect(key('cb-helpful-reasons'), findsOneWidget);
  });

  testWidgets('a restored answer starts rated', (tester) async {
    await pump(tester, initial: const AnswerFeedback(false, 'wrong'));
    expect(key('cb-helpful-rated'), findsOneWidget);
    expect(find.text('Not helpful · Wrong'), findsOneWidget);
    expect(sent, isEmpty);
  });
}
