// While you wait for a person (lib/src/core/waiting/wait_articles.dart): the
// cases of the RN SDK's __tests__/core/waitArticles.test.ts - the articles
// for the visitor's question (web tests/waitArticles.test.js), the server's
// queue-help card and "That solved it" (web special.ts _wireQueue), on a
// fake clock.
import 'package:conferbot_flutter/src/core/waiting/wait_articles.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock {
  int now = 0;
  int _id = 0;
  final Map<int, ({void Function() fn, int at})> timers = {};
  Object set(void Function() fn, Duration after) {
    timers[++_id] = (fn: fn, at: now + after.inMilliseconds);
    return _id;
  }

  void clear(Object t) => timers.remove(t);
  void tick(int ms) {
    final until = now + ms;
    while (true) {
      final due = timers.entries.where((e) => e.value.at <= until).toList()
        ..sort((a, b) => a.value.at.compareTo(b.value.at));
      if (due.isEmpty) break;
      timers.remove(due.first.key);
      now = due.first.value.at;
      due.first.value.fn();
    }
    now = until;
  }
}

const _cats = [
  {
    'name': 'Billing',
    'articles': [
      {'_id': '1', 'title': 'Downloading invoices', 'description': 'Find every invoice in one place.'},
      {'_id': '2', 'title': 'Changing your plan', 'description': 'Upgrade, downgrade or cancel at any time.'},
    ],
  },
];
const _on = {'enableKnowledgeBase': true};
final _wait = waitBefore.inMilliseconds;

void main() {
  group('waitArticlesFor (web waitArticles.ts)', () {
    test('the articles that may answer their question, at most two', () {
      expect(waitArticlesFor(_on, 'Where can I download my invoices?', _cats, []).map((a) => a.id).toList(), ['1']);
      expect(
        waitArticlesFor(_on, 'Where can I download my invoices?', _cats, [])[0],
        const HelpItem(kind: 'article', id: '1', title: 'Downloading invoices', description: 'Find every invoice in one place.'),
      );
      expect(waitArticlesFor(_on, 'billing', _cats, []).length, lessThanOrEqualTo(2));
      expect(waitArticlesFor(_on, 'how do I change my plan', _cats, []).map((a) => a.id).toList(), ['2']);
    });

    test('nothing with the help centre off, no question, or nothing that fits', () {
      expect(waitArticlesFor({'enableKnowledgeBase': false}, 'download my invoices', _cats, []), isEmpty);
      expect(waitArticlesFor({}, 'download my invoices', _cats, []), isEmpty);
      expect(waitArticlesFor(_on, '', _cats, []), isEmpty);
      expect(waitArticlesFor(_on, 'do you ship to mars', _cats, []), isEmpty);
    });

    test('the help centre once each, categories first, recent articles after', () {
      final all = flattenArticles(_cats, [
        {'_id': '1', 'title': 'dup'},
        {'_id': '9', 'title': ' Recent ', 'content': '<p>Hi&amp;there</p>', 'category': {'name': 'X'}},
        {'title': 'no id'},
      ]);
      expect(all.map((a) => [a.id, a.title, a.categoryName]).toList(), [
        ['1', 'Downloading invoices', 'Billing'],
        ['2', 'Changing your plan', 'Billing'],
        ['9', 'Recent', 'X'],
      ]);
      expect(all[2].text, 'Hi there');
      expect(findArticle('2', _cats, [])?['title'], 'Changing your plan');
      expect(findArticle('9', _cats, [
        {'_id': '9', 'title': 'R'}
      ])?['title'], 'R');
      expect(findArticle('nope', _cats, []), isNull);
      expect(keywordsOf('How do I change my plan?'), ['change', 'plan']);
      expect(answersFor(all, 'invoices', 4).map((a) => a.id).toList(), ['1']);
    });
  });

  group('the question (web special.ts lastVisitorText)', () {
    test('the newest real question, not "hi" and not an ask for a person', () {
      expect(isRealQuestion('hi'), isFalse);
      expect(isRealQuestion('Where can I download my invoices?'), isTrue);
      expect(isRealQuestion('me@example.com'), isFalse);
      final record = [
        {'type': 'user-message', 'text': 'Where can I download my invoices?'},
        {'type': 'bot-message', 'text': 'Let me check that for you right now.'},
        {'type': 'user-message', 'text': 'Can I talk to a real person please'},
        {'type': 'user-message', 'text': 'thanks'},
      ];
      expect(waitQuestion(record), 'Where can I download my invoices?');
      expect(waitQuestion([]), '');
      expect(waitQuestion(null), '');
    });
  });

  group('helpItemsOf (embed-server queueHelp.js payload)', () {
    test('articles and pages, an id and a title each; a page only with an http address', () {
      expect(
        helpItemsOf({
          'chatSessionId': 's',
          'offer': 1,
          'items': [
            {'kind': 'article', 'id': 'a1', 'title': 'Invoices', 'description': 'Find them', 'score': 0.8},
            {'kind': 'page', 'id': 'p1', 'title': 'Pricing', 'url': 'https://example.com/pricing', 'description': ''},
            {'kind': 'page', 'id': 'p2', 'title': 'Bad', 'url': 'javascript:alert(1)'},
            {'id': 'x', 'title': '  '},
            null,
          ],
        }),
        const [
          HelpItem(kind: 'article', id: 'a1', title: 'Invoices', description: 'Find them'),
          HelpItem(kind: 'page', id: 'p1', title: 'Pricing', url: 'https://example.com/pricing'),
          HelpItem(kind: 'page', id: 'p2', title: 'Bad'),
        ],
      );
      expect(helpItemsOf(null), isEmpty);
    });
  });

  group('WaitHelp', () {
    ({_Clock k, WaitHelp help, List<HelpCardState?> cards}) setup({String? question, dynamic c, bool joined = false}) {
      final k = _Clock();
      final cards = <HelpCardState?>[];
      final help = WaitHelp(
        customizations: () => c ?? _on,
        question: () => question ?? 'Where can I download my invoices?',
        articles: () => (categories: _cats, recentArticles: const []),
        joined: () => joined,
        onChange: cards.add,
        setTimer: k.set,
        clearTimer: k.clear,
      );
      return (k: k, help: help, cards: cards);
    }

    test('waitBefore into a wait: the articles for their question, no "That solved it"', () {
      final s = setup();
      s.help.startWait();
      s.k.tick(_wait - 1);
      expect(s.help.card, isNull);
      s.k.tick(1);
      final card = s.help.card!;
      expect(card.key, 1);
      expect(card.solvable, isFalse);
      expect(card.settled, isFalse);
      expect(card.items.map((i) => [i.id, i.title]).toList(), [
        ['1', 'Downloading invoices']
      ]);
      expect(s.help.solving(), isNull);
    });

    test('nothing when the wait ends first, a person is here, nothing fits or there is no question', () {
      final a = setup();
      a.help.startWait();
      a.k.tick(3000);
      a.help.endWait();
      a.k.tick(10000);
      expect(a.help.card, isNull);
      for (final s in [
        setup(joined: true),
        setup(question: 'do you ship to mars'),
        setup(question: ''),
        setup(c: <String, dynamic>{}),
      ]) {
        s.help.startWait();
        s.k.tick(_wait);
        expect(s.help.card, isNull);
      }
    });

    test('the server keeps a queue: its pick only, ours stays out', () {
      final s = setup();
      s.help.startWait();
      s.help.queueStatus({'status': 'waiting', 'position': 1});
      s.k.tick(_wait);
      expect(s.help.card, isNull);
      // A reload: queue-status carries the help it was offered.
      s.help.queueStatus({
        'status': 'waiting',
        'help': {
          'items': [
            {'kind': 'article', 'id': 'a1', 'title': 'Invoices'}
          ],
          'offer': 1,
        },
      });
      expect(s.help.card!.solvable, isTrue);
      expect(s.help.card!.items.map((i) => i.id).toList(), ['a1']);
      s.help.queueStatus({
        'status': 'none',
        'help': {
          'items': [
            {'id': 'zz', 'title': 'Other'}
          ]
        },
      });
      expect(s.help.card!.items[0].id, 'a1');
    });

    test('queue-help: the card, replaced only by new items', () {
      final s = setup();
      s.help.startWait();
      s.help.queueHelp({
        'items': [
          {'kind': 'article', 'id': 'a1', 'title': 'Invoices'}
        ],
        'offer': 1,
      });
      expect(s.help.card!.key, 1);
      expect(s.help.card!.solvable, isTrue);
      s.help.queueHelp({
        'items': [
          {'kind': 'article', 'id': 'a1', 'title': 'Invoices'}
        ],
        'offer': 1,
      });
      expect(s.cards, hasLength(1));
      s.help.queueHelp({
        'items': [
          {'kind': 'article', 'id': 'a2', 'title': 'Plans'}
        ],
        'offer': 2,
      });
      expect(s.help.card!.key, 2);
      expect(s.help.card!.items.map((i) => i.id).toList(), ['a2']);
      s.help.queueHelp({'items': []});
      expect(s.help.card!.key, 2);
    });

    test('That solved it: the opened row (else the first) goes; ok leaves, else the button comes back', () {
      final s = setup();
      final help = s.help;
      help.startWait();
      help.queueHelp({
        'items': [
          {'id': 'a1', 'title': 'One'},
          {'id': 'a2', 'title': 'Two'},
        ]
      });
      help.open('a2');
      expect(help.solving()?.id, 'a2');
      expect(help.card!.busy, isTrue);
      // Busy: a second press sends nothing.
      expect(help.solving(), isNull);
      help.solved(false);
      expect(help.card!.busy, isFalse);
      expect(help.card!.done, isFalse);
      expect(help.solving()?.id, 'a2');
      help.solved(true);
      expect(help.card!.busy, isFalse);
      expect(help.card!.done, isTrue);
      // Done: no more server cards for this wait.
      help.queueHelp({
        'items': [
          {'id': 'a3', 'title': 'Three'}
        ]
      });
      expect(help.card!.items[0].id, 'a1');
      // The wait settling keeps the done line.
      help.endWait();
      expect(help.card!.settled, isTrue);
      expect(help.card!.done, isTrue);
    });

    test('the wait over: the card stays as history, without the button; a new wait gets new cards', () {
      final s = setup();
      final help = s.help;
      help.startWait();
      help.queueHelp({
        'items': [
          {'id': 'a1', 'title': 'One'}
        ]
      });
      help.endWait();
      expect(help.card!.settled, isTrue);
      expect(help.card!.solvable, isFalse);
      expect(help.solving(), isNull);
      help.startWait();
      help.queueHelp({
        'items': [
          {'id': 'a1', 'title': 'One'}
        ]
      });
      expect(help.card!.key, 2);
      expect(help.card!.settled, isFalse);
      expect(help.card!.solvable, isTrue);
    });

    test('reset: no card, and our own articles again', () {
      final s = setup();
      s.help.queueHelp({
        'items': [
          {'id': 'a1', 'title': 'One'}
        ]
      });
      s.help.reset();
      expect(s.help.card, isNull);
      s.help.startWait();
      s.k.tick(_wait);
      expect(s.help.card!.solvable, isFalse);
    });
  });
}
