// "Was this helpful?" and the reading depth on an article (#59), as the
// web widget's knowledgeBase.ts _kbFeedbackBar and its scroll handler.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/models/knowledge_base.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/widgets/knowledge_base/article_detail.dart';

KnowledgeBaseArticle article({String body = '<p>Short</p>'}) => KnowledgeBaseArticle(
      id: '6ab7ac19b03f13ff22412cd5',
      title: 'Live chat',
      content: body,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

class _Host extends StatefulWidget {
  const _Host({required this.onVote, this.onChat, this.onDepth, this.body = '<p>Short</p>'});
  final ValueChanged<bool> onVote;
  final VoidCallback? onChat;
  final ValueChanged<double>? onDepth;
  final String body;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool? helpful;
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: ArticleDetail(
          article: article(body: widget.body),
          theme: defaultTheme,
          helpful: helpful,
          onHelpful: (h) {
            widget.onVote(h);
            setState(() => helpful = h);
          },
          onChatWithUs: widget.onChat,
          onScrollDepth: widget.onDepth,
        ),
      );
}

Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('thumbs up: the thank-you, no stars', (tester) async {
    final votes = <bool>[];
    await tester.pumpWidget(_Host(onVote: votes.add));
    await scrollTo(tester, find.text('Was this helpful?'));
    expect(find.byIcon(Icons.star_border), findsNothing);
    await tester.tap(find.bySemanticsLabel('Yes, this helped'));
    await tester.pumpAndSettle();
    expect(votes, [true]);
    expect(find.text('Thanks for letting us know!'), findsOneWidget);
    expect(find.text('Was this helpful?'), findsNothing);
  });

  testWidgets('thumbs down: sorry, and Chat with us', (tester) async {
    final votes = <bool>[];
    var chats = 0;
    await tester.pumpWidget(_Host(onVote: votes.add, onChat: () => chats++));
    await scrollTo(tester, find.text('Was this helpful?'));
    await tester.tap(find.bySemanticsLabel("No, this didn't help"));
    await tester.pumpAndSettle();
    expect(votes, [false]);
    expect(find.text('Sorry about that. Can we help?'), findsOneWidget);
    await tester.tap(find.text('Chat with us'));
    expect(chats, 1);
  });

  testWidgets('an answer given before shows as answered', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ArticleDetail(article: article(), theme: defaultTheme, helpful: false, onHelpful: (_) {}),
    ));
    await scrollTo(tester, find.text('Sorry about that. Can we help?'));
    expect(find.text('Was this helpful?'), findsNothing);
    expect(find.text('Chat with us'), findsNothing);
  });

  testWidgets('scrolling reports the depth in percent, up to 100', (tester) async {
    final depths = <double>[];
    final long = List.generate(80, (i) => '<p>Paragraph $i of the article body.</p>').join();
    await tester.pumpWidget(_Host(onVote: (_) {}, onDepth: depths.add, body: long));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(depths, isNotEmpty);
    expect(depths.last, greaterThan(0));
    expect(depths.last, lessThan(100));
    await tester.fling(find.byType(Scrollable).first, const Offset(0, -20000), 5000);
    await tester.pumpAndSettle();
    expect(depths.last, 100);
  });
}
