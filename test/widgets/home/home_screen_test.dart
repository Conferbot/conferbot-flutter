// The home screen drawn and tapped (lib/src/widgets/home/home_screen_view.dart):
// RN __tests__/components/HomeScreen.test.tsx - talk, ask, help, requests,
// welcome back, trust - and the view switch (view_switch.dart).
import 'package:conferbot_flutter/src/core/home/home.dart';
import 'package:conferbot_flutter/src/core/requests/requests.dart';
import 'package:conferbot_flutter/src/widgets/home/home_screen_view.dart';
import 'package:conferbot_flutter/src/widgets/home/view_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const now = 1800000000000;
const homeC = <String, dynamic>{'enableInitialPage': true, 'initialPageTitle': 'Hi Sam 👋', 'logoText': 'Acme'};

final cats = [
  {
    '_id': 'c1',
    'name': 'Billing',
    'articles': [
      {'_id': '3', 'title': 'Changing your plan', 'description': 'Upgrade, downgrade or cancel at any time.', 'content': ''},
      {'_id': '4', 'title': 'Downloading invoices', 'description': 'Find every invoice in one place.'},
    ],
  },
];
final recent = [
  {'_id': '2', 'title': 'Embedding the widget', 'description': 'Copy one script tag.', 'content': ''},
];

class Taps {
  final chats = <String?>[];
  final articles = <String>[];
  final helps = <String?>[];
  final requests = <String?>[];
  int closes = 0;
}

Widget scene(HomeModel m, Taps t, {bool hasAgent = false, Future<List<({String id, String snippet})>> Function(String)? search, List<dynamic> raw = const []}) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
        child: HomeScreenView(
          model: m,
          palette: classicHomePalette,
          hasAgent: hasAgent,
          rawArticles: raw,
          onClose: () => t.closes++,
          onShowChat: ([text]) => t.chats.add(text),
          onOpenArticle: t.articles.add,
          onShowHelp: ([id]) => t.helps.add(id),
          onOpenRequests: ([id]) => t.requests.add(id),
          searchArticleText: search,
        ),
      ),
    );

void main() {
  testWidgets('a flow bot: the header, Talk to us, the cross', (tester) async {
    final t = Taps();
    await tester.pumpWidget(scene(homeModel(c: homeC, now: now, hour: 9)!, t));
    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Hi Sam 👋'), findsOneWidget);
    expect(find.text(HomeText.description), findsOneWidget);
    expect(find.text('Online · Answers instantly, day or night'), findsOneWidget);
    expect(find.byKey(const ValueKey('cb-home-online-dot')), findsOneWidget);
    expect(find.byKey(const ValueKey('cb-home-ask')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('cb-home-talk-button')));
    expect(t.chats, [null]);
    await tester.tap(find.byKey(const ValueKey('cb-home-close')));
    expect(t.closes, 1);
  });

  testWidgets('hideOnlineStatus: no dot, no Online', (tester) async {
    await tester.pumpWidget(scene(homeModel(c: {...homeC, 'hideOnlineStatus': true}, now: now)!, Taps()));
    expect(find.byKey(const ValueKey('cb-home-online-dot')), findsNothing);
    expect(find.text('Answers instantly, day or night'), findsOneWidget);
  });

  testWidgets('an agent: the starters and the ask box ask in the chat', (tester) async {
    final t = Taps();
    const agent = HomeAgent(displayName: 'Ava', starters: ['Pricing?', 'Refunds']);
    await tester.pumpWidget(scene(homeModel(c: homeC, agent: agent, now: now)!, t, hasAgent: true));
    await tester.tap(find.byKey(const ValueKey('cb-home-starter-1')));
    expect(t.chats, ['Refunds']);
    await tester.enterText(find.byKey(const ValueKey('cb-home-ask-input')), 'Do you ship to Canada?');
    await tester.pump();
    // While asking, the list is the page.
    expect(find.byKey(const ValueKey('cb-home-talk')), findsNothing);
    expect(find.text('Ava answers right away'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cb-home-ask-ask')));
    expect(t.chats.last, 'Do you ship to Canada?');
    // Enter does the first row.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    expect(t.chats.last, 'Do you ship to Canada?');
    expect(t.chats, hasLength(3));
  });

  testWidgets("the help centre: ask over articles with the server's body matches; recent, topics, See all", (tester) async {
    final t = Taps();
    final asked = <String>[];
    final m = homeModel(c: {...homeC, 'enableKnowledgeBase': true}, categories: cats, recentArticles: recent, now: now)!;
    await tester.pumpWidget(scene(m, t, raw: [...recent, ...cats.first['articles'] as List], search: (q) async {
      asked.add(q);
      return [(id: '4', snippet: 'Every invoice is a PDF with your VAT number.')];
    }));
    expect(find.text('Recent articles'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cb-home-article-2')));
    expect(t.articles, ['2']);
    await tester.tap(find.byKey(const ValueKey('cb-home-topic-c1')));
    expect(t.helps, ['c1']);
    await tester.tap(find.byKey(const ValueKey('cb-home-help-all')));
    expect(t.helps, ['c1', null]);

    await tester.enterText(find.byKey(const ValueKey('cb-home-ask-input')), 'vat number');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(asked, ['number vat']);
    expect(find.text('Every invoice is a PDF with your VAT number.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cb-home-ask-article-4')));
    expect(t.articles.last, '4');
  });

  testWidgets("the ask box off: the help card's own search, else Chat with us instead", (tester) async {
    final t = Taps();
    final m = homeModel(c: {...homeC, 'enableKnowledgeBase': true, 'homeAskBox': false, 'hideRecentArticles': true}, categories: cats, now: now)!;
    await tester.pumpWidget(scene(m, t));
    expect(find.text('Help centre'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('cb-home-help-input')), 'invoices');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cb-home-help-result-4')));
    expect(t.articles, ['4']);
    await tester.enterText(find.byKey(const ValueKey('cb-home-help-input')), 'mars');
    await tester.pump();
    expect(find.text('Chat with us instead'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cb-home-help-instead')));
    expect(t.chats, [null]);
  });

  testWidgets('your requests: rows open the portal, See all (n), a new reply first', (tester) async {
    final t = Taps();
    RequestSummary req(String id, int at, String from) => RequestSummary(
        id: id, title: 'Request $id', status: 'open', lastFrom: from, lastAt: DateTime.fromMillisecondsSinceEpoch(at).toIso8601String(), lastText: '', teamName: 'Ada');
    final m = homeModel(c: homeC, requests: [req('a', now - 1000, 'team'), req('b', now - 2000, 'you'), req('c', now - 3000, 'you')], now: now)!;
    expect(m.order.first, HomeSection.requests);
    await tester.pumpWidget(scene(m, t));
    expect(find.byKey(const ValueKey('cb-home-request-new-a')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cb-home-request-a')));
    await tester.tap(find.byKey(const ValueKey('cb-home-requests-all')));
    expect(t.requests, ['a', null]);
  });

  testWidgets('welcome back and pick up where you left off', (tester) async {
    final t = Taps();
    const memory = VisitorMemory(at: now - liveChatMs, name: 'Jamie', topic: 'Do you support Shopify stores?', session: 's0');
    final m = homeModel(c: homeC, agent: const HomeAgent(displayName: 'Ava'), memory: memory, chatSessionId: 's1', now: now)!;
    await tester.pumpWidget(scene(m, t, hasAgent: true));
    expect(find.text('Welcome back, Jamie'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cb-home-resume-row')));
    expect(t.chats, ['Do you support Shopify stores?']);
  });

  testWidgets('the rating and the faces sit on the card; broken logos show no claim', (tester) async {
    final m = homeModel(c: {
      ...homeC,
      'homeRating': {'average': 4.83, 'count': 120},
      'homeTeamPhotos': ['https://cdn.x/1.png'],
      'homeTrustLogos': ['https://cdn.x/l.png'],
      'homeTrustLabel': 'Trusted by 2,000+ teams',
    }, now: now)!;
    await tester.pumpWidget(scene(m, Taps()));
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('120 reviews'), findsOneWidget);
    await tester.pump();
    await tester.pump();
    // The logo cannot load in a test: neither it nor its line is shown.
    expect(find.text('Trusted by 2,000+ teams'), findsNothing);
  });

  group('ViewSwitch', () {
    Widget switcher(HomeView v, {dynamic kind, bool reduced = false}) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduced),
            child: ViewSwitch(view: v, transition: kind, child: Text(v.name)),
          ),
        );

    testWidgets('slide: the new view only, in from the side over 420ms', (tester) async {
      await tester.pumpWidget(switcher(HomeView.home, kind: 'slide'));
      await tester.pumpWidget(switcher(HomeView.chat, kind: 'slide'));
      expect(find.text('home'), findsNothing);
      expect(find.text('chat'), findsOneWidget);
      final slide = tester.widget<SlideTransition>(find.descendant(of: find.byType(ViewSwitch), matching: find.byType(SlideTransition)).first);
      expect(slide.position.value.dx, 1);
      await tester.pump(const Duration(milliseconds: 420));
      expect(slide.position.value, Offset.zero);
    });

    testWidgets('classic: at once; reduced motion: a 200ms fade', (tester) async {
      await tester.pumpWidget(switcher(HomeView.home, kind: 'classic'));
      await tester.pumpWidget(switcher(HomeView.chat, kind: 'classic'));
      expect(find.descendant(of: find.byType(ViewSwitch), matching: find.byType(SlideTransition)), findsNothing);
      await tester.pumpWidget(switcher(HomeView.home, kind: 'iris', reduced: true));
      final fade = tester.widget<FadeTransition>(find.descendant(of: find.byType(ViewSwitch), matching: find.byType(FadeTransition)).first);
      expect(fade.opacity.value, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(fade.opacity.value, 1);
    });
  });
}
