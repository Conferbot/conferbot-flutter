// The while-you-wait cards (lib/src/widgets/waiting/wait_help_card.dart and
// games_card_view.dart): drawn from the provider's state and the games
// controller, taps going back to them. The cases of the React Native SDK's
// __tests__/components/WaitingCards.test.tsx, plus the inline placement in
// MessageList.
import 'package:conferbot_flutter/src/core/waiting/games_card.dart';
import 'package:conferbot_flutter/src/core/waiting/wait_articles.dart';
import 'package:conferbot_flutter/src/models/message.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/widgets/message_list.dart';
import 'package:conferbot_flutter/src/widgets/waiting/games_card_view.dart';
import 'package:conferbot_flutter/src/widgets/waiting/wait_help_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HelpCardState card({List<HelpItem> items = const [], bool solvable = false, bool settled = false, bool done = false}) =>
    HelpCardState(key: 1, items: items, solvable: solvable, settled: settled, done: done);

Widget host(Widget child, {bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Finder key(String k) => find.byKey(ValueKey(k));

void main() {
  group('WaitHelpCard', () {
    testWidgets('nothing without items', (tester) async {
      await tester.pumpWidget(host(WaitHelpCard(card: card(), theme: defaultTheme, onOpen: (_) {}, onSolved: () {})));
      expect(key('cb-wait-help'), findsNothing);
    });

    testWidgets('our own articles: the rows, Read, no That solved it; a row opens the article', (tester) async {
      final opened = <HelpItem>[];
      const item = HelpItem(kind: 'article', id: 'a1', title: 'Downloading invoices', description: 'Find every invoice in one place.');
      await tester.pumpWidget(host(WaitHelpCard(card: card(items: [item]), theme: defaultTheme, onOpen: opened.add, onSolved: () {})));
      expect(find.text('While you wait, this might help'), findsOneWidget);
      expect(find.text('Find every invoice in one place.'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('That solved it'), findsNothing);
      await tester.tap(find.text('Downloading invoices'));
      expect(opened, [item]);
    });

    testWidgets("the server's pick: That solved it; a page opens in the browser", (tester) async {
      final urls = <String>[];
      final opened = <HelpItem>[];
      var solved = 0;
      const page = HelpItem(kind: 'page', id: 'p1', title: 'Pricing', url: 'https://example.com/pricing');
      await tester.pumpWidget(host(WaitHelpCard(
        card: card(items: [page], solvable: true),
        theme: defaultTheme,
        onOpen: opened.add,
        onSolved: () => solved++,
        openUrl: (u) async => urls.add(u),
      )));
      await tester.tap(find.text('Pricing'));
      expect(opened, [page]);
      expect(urls, ['https://example.com/pricing']);
      await tester.tap(find.text('That solved it'));
      expect(solved, 1);
    });

    testWidgets('left the queue this way: Glad that helped; the wait over: the history title, no button', (tester) async {
      const items = [HelpItem(kind: 'article', id: 'a1', title: 'Invoices')];
      await tester.pumpWidget(host(WaitHelpCard(
        card: card(items: items, solvable: true, done: true, settled: true),
        theme: defaultTheme,
        onOpen: (_) {},
        onSolved: () {},
      )));
      expect(find.text('Glad that helped. You have left the queue.'), findsOneWidget);
      expect(find.text('Articles that might help'), findsOneWidget);
      await tester.pumpWidget(host(WaitHelpCard(
        card: card(items: items, solvable: true, settled: true),
        theme: defaultTheme,
        onOpen: (_) {},
        onSolved: () {},
      )));
      expect(find.text('Articles that might help'), findsOneWidget);
      expect(find.text('That solved it'), findsNothing);
    });
  });

  group('GamesCardView', () {
    late Map<int, void Function()> timers;
    late GamesCard c;

    void flush() {
      for (final e in timers.entries.toList()) {
        timers.remove(e.key);
        e.value();
      }
    }

    Future<void> pump(WidgetTester tester, {bool reduced = true}) async {
      var id = 0;
      timers = {};
      c = GamesCard.create(GamesCardOptions(
        customizations: const {'headerBgColor': '#123456'},
        rng: () => 0.9,
        reducedMotion: true,
        setTimer: (fn, _) {
          timers[++id] = fn;
          return id;
        },
        clearTimer: (t) => timers.remove(t),
      ))!;
      await tester.pumpWidget(host(
        GamesCardView(card: c, theme: defaultTheme, customizations: const {'headerBgColor': '#123456'}),
        reduced: reduced,
      ));
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> tap(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pump();
    }

    testWidgets('the offer: a chip per game (odd last full width) and Not now; Not now closes it', (tester) async {
      await pump(tester);
      expect(find.text('While you wait - fancy a quick game? 🎮'), findsOneWidget);
      for (final name in ['Rock paper scissors', 'Tic-tac-toe', 'Quick quiz', 'Memory match', 'Reflex test', 'Emoji riddles', 'Word scramble']) {
        expect(find.text(name), findsOneWidget);
      }
      final first = tester.getSize(key('cb-games-chip-rps')).width;
      final last = tester.getSize(key('cb-games-chip-scramble')).width;
      expect(last, greaterThan(first * 1.8));
      expect(key('cb-games-close'), findsOneWidget);
      await tap(tester, find.text('Not now'));
      expect(c.state.view, 'gone');
      expect(key('cb-games'), findsNothing);
    });

    testWidgets('the x dismisses the card', (tester) async {
      await pump(tester);
      await tap(tester, key('cb-games-close'));
      expect(c.state.view, 'gone');
      expect(key('cb-games'), findsNothing);
    });

    testWidgets('tic-tac-toe played from the board; the bot answers', (tester) async {
      await pump(tester);
      await tap(tester, find.text('Tic-tac-toe'));
      expect(find.text('You go first - tap a square'), findsOneWidget);
      expect(find.text('You ✕ · Bot ◯'), findsOneWidget);
      await tap(tester, key('cb-games-ttt-4'));
      expect((c.state.board as TttBoard).cells[4], 'X');
      expect(find.text('The bot is thinking...'), findsOneWidget);
      flush();
      await tester.pump();
      expect(find.text('Your move'), findsOneWidget);
      expect(c.state.board, isA<TttBoard>());
      expect(find.text('Another game'), findsOneWidget);
    });

    testWidgets('rock paper scissors to the end: Play again and Another game; reduced motion shows the hands at once', (tester) async {
      await pump(tester);
      await tap(tester, find.text('Rock paper scissors'));
      await tap(tester, key('cb-games-rps-rock'));
      // No shake: the hands are out straight away.
      expect(find.text('✌️'), findsWidgets);
      await tap(tester, key('cb-games-rps-rock'));
      expect(find.text('Rock beats scissors - point to you! You win 2-0! 🎉'), findsOneWidget);
      expect(find.text('Play again'), findsOneWidget);
      await tap(tester, find.text('Another game'));
      expect(find.text('Pick a game'), findsOneWidget);
    });

    testWidgets('a person joins mid-game: their name, the game saved, Finish my game', (tester) async {
      await pump(tester);
      await tap(tester, find.text('Memory match'));
      c.wrapUp('Sam');
      await tester.pump();
      expect(find.text("Sam's here!"), findsOneWidget);
      expect(find.text('Your game is saved - finish it later?'), findsOneWidget);
      expect(key('cb-games-mem-0'), findsNothing);
      await tap(tester, find.text('Finish my game'));
      expect(key('cb-games-mem-0'), findsOneWidget);
    });

    testWidgets('the quiz: an option, then Next', (tester) async {
      await pump(tester);
      await tap(tester, find.text('Quick quiz'));
      final b = c.state.board as ChoiceBoard;
      await tap(tester, key('cb-games-opt-${b.answer}'));
      expect(find.text('1 of 3 · 1 right'), findsOneWidget);
      await tap(tester, find.text('Next →'));
      expect(find.text('2 of 3 · 1 right'), findsOneWidget);
    });

    testWidgets('the reflex pad and the word scramble take taps', (tester) async {
      await pump(tester);
      await tap(tester, find.text('Reflex test'));
      await tester.ensureVisible(key('cb-games-pad'));
      final g = await tester.startGesture(tester.getCenter(key('cb-games-pad')));
      await tester.pump();
      expect(find.text('Wait for green...'), findsOneWidget);
      await g.up();
      await tester.pump();
      await tap(tester, find.text('Another game'));
      await tap(tester, find.text('Word scramble'));
      await tap(tester, key('cb-games-tile-0'));
      expect((c.state.board as ScrambleBoard).placed, [0]);
      await tap(tester, key('cb-games-slot-0'));
      expect((c.state.board as ScrambleBoard).placed, isEmpty);
      await tap(tester, key('cb-games-skip'));
      expect(find.textContaining(RegExp(r'^It was [A-Z]+\.$')), findsOneWidget);
    });
  });

  testWidgets('MessageList draws an inline card right after its message', (tester) async {
    final t = DateTime(2026, 10, 16);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageList(
          showDeliveryStatus: false,
          messages: [
            BotMessageRecord(id: 'm1', time: t, text: 'first'),
            BotMessageRecord(id: 'm2', time: t, text: 'second'),
          ],
          inlineAfter: const {
            'm1': [Text('card')],
          },
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    final first = tester.getTopLeft(find.text('first')).dy;
    final cardY = tester.getTopLeft(find.text('card')).dy;
    final second = tester.getTopLeft(find.text('second')).dy;
    expect(cardY, greaterThan(first));
    expect(cardY, lessThan(second));
  });
}
