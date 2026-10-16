// The home screen's decisions (lib/src/core/home/home.dart): RN's
// __tests__/core/home.test.ts, the web's cases (conferbot-widget
// tests/homeCopy.test.js, homeUtils.test.js, askBox.test.js, trust.test.js,
// visitorMemory.test.js) and what firstImpression.ts enhanceHome shows, in
// what order.
import 'package:conferbot_flutter/src/core/home/home.dart';
import 'package:conferbot_flutter/src/core/requests/requests.dart';
import 'package:flutter_test/flutter_test.dart';

const now = 1800000000000;

Map<String, dynamic> art(String id, String title, [String description = '', String content = '', Map<String, dynamic> extra = const {}]) =>
    {'_id': id, 'title': title, 'description': description, 'content': content, ...extra};

final cats = [
  {
    '_id': 'c1',
    'name': 'Billing',
    'articles': [art('3', 'Changing your plan', 'Upgrade, downgrade or cancel at any time.'), art('4', 'Downloading invoices', 'Find every invoice in one place.')],
  },
  {
    '_id': 'c2',
    'name': 'Getting started',
    'articles': [art('1', 'How to build your first bot', 'A step by step guide.')],
  },
];
final recent = [
  art('2', 'Embedding the widget on your website', 'Copy one script tag into your site.'),
  art('9', 'A draft', '', '', {'reviewStatus': 'draft'}),
];
const home = <String, dynamic>{'enableInitialPage': true, 'initialPageTitle': 'Hi there 👋', 'logo': 'https://cdn.x/logo.png', 'logoText': 'Acme'};

void main() {
  group('on or off (web templates, core/helpCentre.ts safeView)', () {
    test('only when the owner turned it on', () {
      expect(homeOn({'enableInitialPage': true}), isTrue);
      expect(homeOn({'enableInitialPage': false}), isFalse);
      expect(homeOn({}), isFalse);
      expect(homeOn(null), isFalse);
      expect(homeModel(c: {'enableInitialPage': false}), isNull);
      expect(homeModel(c: null), isNull);
    });

    test('a view that cannot show falls back', () {
      expect(safeHomeView({'enableInitialPage': true}, null), HomeView.home);
      expect(safeHomeView({}, null), HomeView.chat);
      expect(safeHomeView({}, HomeView.home), HomeView.chat);
      expect(safeHomeView({'enableInitialPage': true}, HomeView.help), HomeView.home);
      expect(safeHomeView({'enableInitialPage': true, 'enableKnowledgeBase': true}, HomeView.help), HomeView.help);
      expect(safeHomeView({}, HomeView.help), HomeView.chat);
    });
  });

  group('words (web homeCopy.ts, homeUtils.ts)', () {
    test("early bots' placeholder copy is shown as what is true", () {
      final c = {
        'initialPageCardSubTitle': 'Our usual reply time',
        'initialPageCardTagline': 'Later Today',
        'initialPageDescription': 'Welcome to the Conferbot\nWe help your business to connect with your customer',
      };
      expect(homeCopy(c, 'Acme Support'), const HomeCopy(cardTitle: 'Acme Support', cardTagline: 'Online now', description: HomeText.description, online: true));
      expect(homeCopy({}, '').cardTitle, 'Support');
    });

    test("the owner's own words are kept exactly", () {
      final c = {'initialPageCardSubTitle': 'Sales team', 'initialPageCardTagline': 'Mon-Fri, 9-5', 'initialPageDescription': 'Hi! Questions about orders?'};
      expect(homeCopy(c, 'Acme'), const HomeCopy(cardTitle: 'Sales team', cardTagline: 'Mon-Fri, 9-5', description: 'Hi! Questions about orders?', online: false));
    });

    test('the salutation follows the clock', () {
      expect(salutation(9), 'Good morning');
      expect(salutation(14), 'Good afternoon');
      expect(salutation(20), 'Good evening');
      expect(salutation(2), 'Hello');
      expect(salutation(double.nan), 'Good afternoon');
    });

    test('the brand is the header logo and name, nothing when hidden', () {
      expect(homeBrand({'logo': 'https://cdn.x/l.png', 'logoText': ' Acme  Co '}), const HomeBrand('https://cdn.x/l.png', 'Acme Co'));
      expect(homeBrand({'logo': 'https://cdn.x/l.png'}, 'Bot'), const HomeBrand('https://cdn.x/l.png', 'Bot'));
      expect(homeBrand({'logo': 'https://cdn.x/l.png', 'hideLogo': true}), isNull);
      expect(homeBrand({'logo': 'javascript:x'}), isNull);
    });

    test("the card's face: the owner's, the bot's avatar, its logo, then Conferbot's", () {
      expect(homeCardAvatar({'initialPageAvatar': 'https://a/me.png', 'avatar': 'https://a/b.png'}), 'https://a/me.png');
      expect(homeCardAvatar({'avatar': 'https://a/b.png'}), 'https://a/b.png');
      expect(homeCardAvatar({'avatar': 'https://a/b.png', 'hideAvatar': true, 'logo': 'https://a/l.png'}), 'https://a/l.png');
      expect(homeCardAvatar({'logo': 'https://x/conferbot-logo.png'}), contains('conferbot-logo-1710782074234'));
    });

    test('light colours take dark ink', () {
      expect(isLight(parseColor('#ffffff')), isTrue);
      expect(isLight(parseColor('#0808EE')), isFalse);
      expect(isLight(parseColor('rgb(250, 240, 200)')), isTrue);
      expect(parseColor('teal'), isNull);
    });
  });

  group('surfaces', () {
    test("the theme's canvas and cards, else the classic widget's", () {
      expect(homePalette(), classicHomePalette);
      expect(homePalette(bg2: '#101014', card: '#18181d', card2: '#222228', ink: '#f4f4f5', muted: '#a1a1aa', line: '#2a2a31'),
          const HomePalette(page: '#101014', card: '#18181d', soft: '#222228', ink: '#f4f4f5', muted: '#a1a1aa', line: '#2a2a31'));
    });
  });

  group('the help centre (web core/helpCentre.ts, homeUtils.ts topCategories)', () {
    test('recent articles show only with the home, the help centre, a published article and not hidden', () {
      final c = {'enableInitialPage': true, 'enableKnowledgeBase': true};
      expect(showsRecentArticles(c, recent), isTrue);
      expect(showsRecentArticles({...c, 'hideRecentArticles': true}, recent), isFalse);
      expect(showsRecentArticles({...c, 'enableKnowledgeBase': false}, recent), isFalse);
      expect(showsRecentArticles(c, [recent[1]]), isFalse);
    });

    test('topics: named, not empty, most articles first', () {
      final list = [
        {'name': 'A', 'articles': [1]},
        {'name': '', 'articles': [1, 2]},
        {'name': 'B', 'articles': [1, 2]},
        {'name': 'C', 'articles': []},
      ];
      expect(topCategories(list).map((c) => c['name']), ['B', 'A']);
    });
  });

  group('trust (web trust.ts)', () {
    test('only https images, once each, at most max', () {
      final list = ['https://cdn.x/a.png', 'http://cdn.x/b.png', 'javascript:alert(1)', 'https://cdn.x/a.png', ' https://cdn.x/c.png ', 'https://x/"onerror=1', 42, 'https://cdn.x/d.png'];
      expect(trustImages(list, 6), ['https://cdn.x/a.png', 'https://cdn.x/c.png', 'https://cdn.x/d.png']);
      expect(trustImages(list, 1), ['https://cdn.x/a.png']);
      expect(trustImages(null, 3), isEmpty);
    });

    test('counts read as people say them', () {
      expect(compactCount(7), '7');
      expect(compactCount(999), '999');
      expect(compactCount(1000), '1k');
      expect(compactCount(1320), '1.3k');
      expect(compactCount(12900), '12k');
    });

    test('a rating line for a real average only', () {
      expect(ratingLine({'average': 4.83, 'count': 120}), const RatingLine(average: '4.8', count: '120 reviews', fill: 96, label: 'Rated 4.8 out of 5 from 120 reviews'));
      expect(ratingLine({'average': 4.36, 'count': 1520}), const RatingLine(average: '4.4', count: '1.5k reviews', fill: 88, label: 'Rated 4.4 out of 5 from 1520 reviews'));
      expect(ratingLine({'average': 5, 'count': 1})!.count, '1 review');
      expect(ratingLine(null), isNull);
      expect(ratingLine({'average': 6, 'count': 50}), isNull);
      expect(ratingLine({'average': 4.5, 'count': 0}), isNull);
      expect(ratingLine({'average': 'x', 'count': 30}), isNull);
    });
  });

  group('visitor memory (web visitorMemory.ts)', () {
    test("a conversation's first real question is what they came for", () {
      var m = withMessage(null, 's1', 'hi', now);
      expect(m.topic, isNull);
      m = withMessage(m, 's1', 'Do you support Shopify stores?', now);
      m = withMessage(m, 's1', 'And what about WooCommerce?', now + 1000);
      expect(m.topic, 'Do you support Shopify stores?');
      m = withMessage(m, 's2', 'Can I cancel my plan anytime?', now + 5000);
      expect(m.topic, 'Can I cancel my plan anytime?');
      expect(m.session, 's2');
      expect(m.at, now + 5000);
    });

    test('a first name only, and never something that is not a name', () {
      final m = withName(null, 'jamie lee', now)!;
      expect(m.name, 'Jamie');
      expect(withName(m, 'x@y.com', now), isNull);
      expect(withName(m, 'R2D2', now), isNull);
    });

    test('welcome back once the last chat is over, not while it would be restored', () {
      const m = VisitorMemory(at: now, name: 'Jamie', topic: 'Do you support Shopify stores?');
      expect(welcomeBack(m, now + liveChatMs - 1), isNull);
      expect(welcomeBack(m, now + liveChatMs), (hello: 'Welcome back, Jamie', topic: 'Do you support Shopify stores?'));
      expect(welcomeBack(const VisitorMemory(at: now, topic: 'Do you support Shopify stores?'), now + liveChatMs),
          (hello: 'Welcome back', topic: 'Do you support Shopify stores?'));
      expect(welcomeBack(const VisitorMemory(at: now), now + liveChatMs), isNull);
      expect(welcomeBack(null, now), isNull);
    });

    test('forgotten after 60 days; broken storage is no memory', () {
      final raw = serializeHomeMemory(withMessage(null, 's1', 'Do you support Shopify stores?', now));
      expect(parseHomeMemory(raw, now)!.topic, 'Do you support Shopify stores?');
      expect(parseHomeMemory(raw, now + 61 * 86400000), isNull);
      expect(parseHomeMemory('{nope', now), isNull);
      expect(parseHomeMemory(null, now), isNull);
      // An old memory is started again, not added to.
      expect(withMessage(parseHomeMemory(raw, now), 's9', 'hello', now + 61 * 86400000).topic, isNull);
    });

    test('the card opens the conversation only when it is the one on the device', () {
      final m = withMessage(null, 's1', 'Do you support Shopify stores?', now);
      expect(canResume(m, 's1'), isTrue);
      expect(canResume(m, 's9'), isFalse);
      expect(canResume(m, null), isFalse);
      expect(canResume(null, 's1'), isFalse);
    });
  });

  group('"Ask anything" (web askBox.ts)', () {
    const articles = [
      HelpArticle(id: '1', title: 'How to build your first bot', description: 'A step by step guide to your first chatbot.', text: 'Open the builder.'),
      HelpArticle(id: '3', title: 'Changing your plan', description: 'Upgrade, downgrade or cancel at any time.', categoryName: 'Billing'),
      HelpArticle(id: '4', title: 'Downloading invoices', description: 'Find every invoice in one place.', categoryName: 'Billing'),
    ];

    test('the box asks for a question with an agent, a search without', () {
      expect(askPlaceholder(true, false), 'Ask a question…');
      expect(askPlaceholder(false, true), 'Search for help');
    });

    test('it shows with an agent or articles, unless the owner turned it off', () {
      expect(askBoxOn({}, true, false), isTrue);
      expect(askBoxOn({}, false, true), isTrue);
      expect(askBoxOn({'homeAskBox': false}, true, true), isFalse);
      expect(askBoxOn({}, false, false), isFalse);
    });

    test('an agent: "Ask" first (what Enter does), then the articles', () {
      final rows = askRows('how do I change my plan', agentName: 'Ava', articles: articles);
      expect(rows.map((r) => r.kind), [AskKind.ask, AskKind.label, AskKind.article]);
      final ask = rows[0] as AskQueryRow;
      expect(ask.query, 'how do I change my plan');
      expect(ask.sub, 'Ava answers right away');
      final a = rows[2] as AskArticleRow;
      expect(a.id, '3');
      expect(a.sub, 'Upgrade, downgrade or cancel at any time.');
      expect(askDefault(rows)!.kind, AskKind.ask);
    });

    test('a flow bot: the articles, else "No articles match" and Chat with us', () {
      final rows = askRows('invoice', agentName: null, articles: articles);
      expect(rows.map((r) => r.kind), [AskKind.label, AskKind.article]);
      expect((askDefault(rows) as AskArticleRow).id, '4');
      final none = askRows('do you ship to mars', agentName: null, articles: articles);
      expect(none.map((r) => r.kind), [AskKind.none, AskKind.chat]);
      expect((none[0] as AskNoneRow).text, 'No articles match “do you ship to mars”.');
      expect((none[1] as AskChatRow).title, 'Chat with us');
      expect((none[1] as AskChatRow).sub, "We'll help you with it");
      expect(askDefault(none)!.kind, AskKind.chat);
      // An agent with nothing found: only the ask.
      expect(askRows('do you ship to mars', agentName: 'Ava', articles: articles).map((r) => r.kind), [AskKind.ask]);
      expect(askRows('   ', agentName: 'Ava', articles: articles), isEmpty);
    });

    test("the server's matches inside article text come after the local ones, for the query asked", () {
      const remote = RemoteHits('pdf vat', [(id: '4', snippet: 'Each invoice is a PDF with your VAT number.'), (id: 'zz', snippet: 'not here')]);
      final rows = askRows('PDF VAT', agentName: null, articles: articles, remote: remote);
      final a = rows[1] as AskArticleRow;
      expect(a.id, '4');
      expect(a.sub, 'Each invoice is a PDF with your VAT number.');
      expect(askRows('other', agentName: null, articles: articles, remote: remote).any((r) => r.kind == AskKind.article), isFalse);
    });

    test('asks the server with the two longest key words, only when a body is missing', () {
      expect(remoteQueryFor('where is my vat number', [
        {'_id': '1'},
      ]), 'number vat');
      expect(remoteQueryFor('where is my vat number', [
        {'_id': '1', 'content': '<p>x</p>'},
      ]), isNull);
      expect(remoteQueryFor('how do I', [
        {'_id': '1'},
      ]), isNull);
    });

    test('marks the words that matched', () {
      expect(highlightRuns('Changing your plan', ['plan']), const [TextRun('Changing your '), TextRun('plan', mark: true)]);
      expect(highlightRuns('Plain', []), const [TextRun('Plain')]);
    });

    test("the help card's own search: up to five, else ask or chat instead", () {
      final found = helpSearch('billing', articles, false)!;
      expect(found, isA<HelpSearchResults>());
      expect((found as HelpSearchResults).rows.map((r) => r.id), ['3', '4']);
      expect(helpSearch('mars', articles, true), const HelpSearchEmpty(text: 'No articles match “mars”.', action: 'Ask us instead', asks: true));
      final chat = helpSearch('mars', articles, false) as HelpSearchEmpty;
      expect(chat.action, 'Chat with us instead');
      expect(chat.asks, isFalse);
      expect(helpSearch('', articles, false), isNull);
    });
  });

  group('the home screen (web firstImpression.ts enhanceHome)', () {
    const agent = HomeAgent(displayName: 'Ava', starters: ['Pricing?', 'Do you integrate with Shopify?', 'Refunds', 'Fourth']);

    test('a plain flow bot: the header and "Talk to us"', () {
      final m = homeModel(c: home, botName: 'Acme bot', now: now, hour: 9)!;
      expect(m.hello, 'Good morning');
      expect(m.brand, const HomeBrand('https://cdn.x/logo.png', 'Acme'));
      expect(m.title, 'Hi there 👋');
      expect(m.description, HomeText.description);
      expect(m.order, [HomeSection.talk]);
      expect(m.ask, isNull);
      expect(m.help, isNull);
      expect(m.talk.title, 'Acme');
      expect(m.talk.tagline, isNull);
      expect(m.talk.status, 'Online · Answers instantly, day or night');
      expect(m.talk.dot, isTrue);
      expect(m.talk.button, 'Chat with us');
      expect(m.talk.starters, isEmpty);
      expect(m.light, isFalse);
    });

    test("the owner's tagline is kept, the status line after it; status off takes Online and the dot", () {
      final c = {
        ...home,
        'initialPageCardTagline': 'Mon-Fri 9-5',
        'hideOnlineStatus': true,
        'replyTime': {'mode': 'auto', 'handover': true, 'state': 'online', 'bucket': 'few_minutes'},
      };
      final m = homeModel(c: c, now: now)!;
      expect(m.talk.tagline, 'Mon-Fri 9-5');
      expect(m.talk.status, 'Usually replies in a few minutes');
      expect(m.talk.dot, isFalse);
      // Hide: no line at all.
      expect(homeModel(c: {...c, 'replyTime': {'mode': 'hide', 'handover': true}}, now: now)!.talk.status, isNull);
    });

    test("the owner's button text, or the stock one", () {
      expect(homeModel(c: {...home, 'initialPageCardButtonText': 'Message us'})!.talk.button, 'Message us');
      expect(homeModel(c: {...home, 'initialPageCardButtonText': 'Chat with us'})!.talk.button, 'Chat with us');
    });

    test('an agent: the ask box first, three of its questions on the card', () {
      final m = homeModel(c: home, agent: agent, now: now)!;
      expect(m.order, [HomeSection.ask, HomeSection.talk]);
      expect(m.ask!.placeholder, 'Ask a question…');
      expect(m.ask!.label, 'Ask Ava a question');
      expect(m.ask!.agentName, 'Ava');
      expect(m.talk.starters, ['Pricing?', 'Do you integrate with Shopify?', 'Refunds']);
      expect(m.talk.title, 'Ava');
      expect(homeModel(c: {...home, 'homeAskBox': false}, agent: agent)!.ask, isNull);
    });

    test('the help centre: ask box over articles, recent list, topics and See all; drafts never', () {
      final c = {...home, 'enableKnowledgeBase': true};
      final m = homeModel(c: c, categories: cats, recentArticles: recent)!;
      expect(m.order, [HomeSection.ask, HomeSection.talk, HomeSection.help]);
      expect(m.ask!.placeholder, 'Search for help');
      expect(m.help!.title, 'Recent articles');
      expect(m.help!.seeAll, isTrue);
      expect(m.help!.search, isFalse);
      expect(m.help!.recent.map((r) => r.id), ['2']);
      expect(m.help!.topics, const [HomeTopic('c1', 'Billing', 2), HomeTopic('c2', 'Getting started', 1)]);
      expect(m.articles.map((a) => a.id), ['3', '4', '1', '2']);
    });

    test('recent articles hidden: the card is the help centre; the ask box off: the card searches', () {
      final c = {...home, 'enableKnowledgeBase': true, 'hideRecentArticles': true, 'homeAskBox': false};
      final m = homeModel(c: c, categories: cats, recentArticles: recent)!;
      expect(m.order, [HomeSection.talk, HomeSection.help]);
      expect(m.help!.title, 'Help centre');
      expect(m.help!.recent, isEmpty);
      expect(m.help!.search, isTrue);
    });

    test('a help centre with no published article counts as off', () {
      final m = homeModel(c: {...home, 'enableKnowledgeBase': true}, categories: [], recentArticles: [recent[1]])!;
      expect(m.help, isNull);
      expect(m.ask, isNull);
      expect(m.articles, isEmpty);
    });

    test('welcome back, and pick up where they left off for an agent bot', () {
      const memory = VisitorMemory(at: now - liveChatMs, name: 'Jamie', topic: 'Do you support Shopify stores?', session: 's1');
      final m = homeModel(c: home, agent: agent, memory: memory, chatSessionId: 's1', now: now)!;
      expect(m.hello, 'Welcome back, Jamie');
      expect(m.order, [HomeSection.ask, HomeSection.resume, HomeSection.talk]);
      expect(m.resume!.topic, 'Do you support Shopify stores?');
      expect(m.resume!.resumable, isTrue);
      expect(m.resume!.line, 'Continue the conversation');
      expect(homeModel(c: home, agent: agent, memory: memory, chatSessionId: 's2', now: now)!.resume!.line, "Ask it again - we'll answer right away");
      // A flow bot: welcomed back, nothing to pick up.
      final flow = homeModel(c: home, memory: memory, now: now)!;
      expect(flow.hello, 'Welcome back, Jamie');
      expect(flow.resume, isNull);
    });

    test('your requests: two rows and See all (n), below Talk to us, above it when a reply is new', () {
      RequestSummary req(String id, int lastAt, String lastFrom) => RequestSummary(
            id: id,
            title: 'Request $id',
            status: 'open',
            lastFrom: lastFrom,
            lastAt: DateTime.fromMillisecondsSinceEpoch(lastAt).toUtc().toIso8601String(),
            lastText: '',
            teamName: 'Ada',
          );
      final requests = [req('a', now - 3000, 'you'), req('b', now - 2000, 'you'), req('c', now - 1000, 'you')];
      final m = homeModel(c: home, requests: requests, now: now)!;
      expect(m.order, [HomeSection.talk, HomeSection.requests]);
      expect(m.requests!.rows.map((r) => r.id), ['c', 'b']);
      expect(m.requests!.seeAll, 'See all (3)');
      expect(m.requests!.fresh, isFalse);
      final replied = [req('a', now - 3000, 'team'), req('b', now - 2000, 'you')];
      final n = homeModel(c: home, requests: replied, now: now)!;
      expect(n.order, [HomeSection.requests, HomeSection.talk]);
      expect(n.requests!.rows[0].id, 'a');
      expect(n.requests!.rows[0].fresh, isTrue);
      expect(n.requests!.rows[0].state, RequestState.replied);
      expect(n.requests!.seeAll, isNull);
      // Read here since: no longer new.
      expect(homeModel(c: home, requests: replied, seen: {'a': now}, now: now)!.order, [HomeSection.talk, HomeSection.requests]);
      // Nothing at all for a first-time visitor.
      expect(homeModel(c: home, requests: null)!.requests, isNull);
      expect(homeModel(c: home, requests: const [])!.requests, isNull);
    });

    test('trust: faces and the rating on the card, the logos with their line last', () {
      final c = {
        ...home,
        'homeTeamPhotos': ['https://cdn.x/1.png', 'https://cdn.x/2.png'],
        'homeRating': {'average': 4.83, 'count': 120},
        'homeTrustLogos': ['https://cdn.x/l.png'],
        'homeTrustLabel': ' Trusted by 2,000+ teams ',
      };
      final m = homeModel(c: c)!;
      expect(m.talk.faces, ['https://cdn.x/1.png', 'https://cdn.x/2.png']);
      expect(m.talk.rating!.average, '4.8');
      expect(m.trust!.label, 'Trusted by 2,000+ teams');
      expect(m.trust!.logos, ['https://cdn.x/l.png']);
      expect(m.order, [HomeSection.talk, HomeSection.trust]);
      // A label with no logo is a claim with no proof: nothing.
      expect(homeModel(c: {...home, 'homeTrustLabel': 'Trusted'})!.trust, isNull);
    });

    test('the band is the launcher colours; light ones take dark ink', () {
      expect(homeModel(c: {...home, 'widgetIconThemeType': 'Gradient', 'widgetGradientBgOne': '#0808EE', 'widgetGradientBgTwo': '#6366F1'})!.band, ('#0808EE', '#6366F1'));
      final light = homeModel(c: {...home, 'widgetIconBgColor': '#ffffff'})!;
      expect(light.light, isTrue);
      expect(light.accent, '#4F46E5');
    });

    test('while the visitor types, the list is the page', () {
      expect(hiddenWhileAsking, [HomeSection.resume, HomeSection.requests, HomeSection.talk, HomeSection.help]);
    });

    test('carries the owner\'s mascot and its colour, for the app\'s own spot (#81)', () {
      final m = homeModel(c: {...home, 'mascotShape': 'fox', 'mascotEyes': 'star', 'mascotName': 'Pip', 'widgetIconBgColor': ' #0ea5e9 '})!.mascot;
      expect([m.look.shape, m.look.eyes, m.look.name, m.accent], ['fox', 'star', 'Pip', '#0ea5e9']);
      // Unset: the classic blob in the header's colour.
      final d = homeModel(c: {...home, 'headerBgColor': '#123456'})!.mascot;
      expect([d.look.shape, d.accent], ['blob', '#123456']);
    });

    test('{{first_name|there}} is filled before the home reads it (#78)', () {
      // The provider personalises the settings; the model prints what it gets.
      expect(homeModel(c: {...home, 'initialPageTitle': 'Hi Sam 👋'})!.title, 'Hi Sam 👋');
    });
  });
}
