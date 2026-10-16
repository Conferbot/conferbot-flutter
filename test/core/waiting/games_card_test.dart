// The waiting games' card (lib/src/core/waiting/games_card.dart; web
// games/ui.ts) on a fake clock, ported from the React Native SDK's
// __tests__/core/gamesCard.test.ts: the menu, each game played through, the
// footer, and folding away when a teammate joins (web
// tests/audit-games-card.test.js).
import 'package:conferbot_flutter/src/core/waiting/games_card.dart';
import 'package:conferbot_flutter/src/core/waiting/games_logic.dart' show words;
import 'package:conferbot_flutter/src/core/waiting/waiting_games.dart';
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
  int get size => timers.length;
  void tick(int ms) {
    final until = now + ms;
    while (true) {
      final due = timers.entries.where((e) => e.value.at <= until).toList()
        ..sort((a, b) => a.value.at != b.value.at ? a.value.at.compareTo(b.value.at) : a.key.compareTo(b.key));
      if (due.isEmpty) break;
      timers.remove(due.first.key);
      now = due.first.value.at;
      due.first.value.fn();
    }
    now = until;
  }
}

class _Made {
  _Made(this.k, this.card, this._dismissed);
  final _Clock k;
  final GamesCard card;
  final int Function() _dismissed;
  int get dismissed => _dismissed();
}

// rng 0.9: no slip in tic-tac-toe, the bot plays its best move.
_Made _make({
  dynamic customizations = const <String, dynamic>{},
  double Function()? rng,
  String mode = 'offer',
  bool reducedMotion = false,
  List categories = const [],
}) {
  final k = _Clock();
  var dismissed = 0;
  final card = GamesCard.create(GamesCardOptions(
    customizations: customizations,
    rng: rng ?? () => 0.9,
    setTimer: k.set,
    clearTimer: k.clear,
    now: () => k.now.toDouble(),
    onDismiss: () => dismissed++,
    mode: mode,
    reducedMotion: reducedMotion,
    categories: categories,
  ))!;
  return _Made(k, card, () => dismissed);
}

List<String> keys(GamesCardState s) => s.foot.map((f) => f.key).toList();

void main() {
  group('the menu', () {
    test("an offer opens on the owner's line with a chip per game and Not now", () {
      final card = _make().card;
      final s = card.state;
      expect(s.view, 'menu');
      expect(s.title, defaultOfferText);
      expect(s.chips.map((g) => g.id).toList(), ['rps', 'ttt', 'quiz', 'memory', 'reaction', 'emoji', 'scramble']);
      expect(keys(s), ['notNow']);
      expect(card.playing, isFalse);
    });

    test("the owner's own line and games; asked for, it says Pick a game", () {
      final s = _make(customizations: {
        'waitingGames': {
          'offerText': 'Bored? Play!',
          'games': ['ttt'],
        },
      }).card.state;
      expect(s.title, 'Bored? Play!');
      expect(s.chips.map((g) => g.id).toList(), ['ttt']);
      expect(_make(mode: 'menu').card.state.title, 'Pick a game');
    });

    test('no game left for the language: no card', () {
      expect(
        GamesCard.create(const GamesCardOptions(
          customizations: {
            'waitingGames': {
              'games': ['emoji'],
            },
          },
          lang: 'de',
        )),
        isNull,
      );
    });

    test('Not now and the x close it, once', () {
      final m = _make();
      m.card.press('notNow');
      expect(m.card.state.view, 'gone');
      expect(m.card.up, isFalse);
      m.card.dismiss();
      expect(m.dismissed, 1);
    });

    test('a game the owner turned off does not open', () {
      final card = _make(customizations: {
        'waitingGames': {
          'games': ['ttt'],
        },
      }).card;
      card.open('rps');
      expect(card.state.view, 'menu');
    });
  });

  group('rock paper scissors', () {
    test('the hands shake for 900ms, then the point; first to two wins', () {
      // rng 0.9: the bot always plays scissors.
      final m = _make();
      final card = m.card;
      card.open('rps');
      expect(card.state.title, 'Rock paper scissors');
      expect(card.state.titleEmoji, '✊');
      expect(card.state.meta, 'You 0 · 0 Bot');
      expect(card.state.status, 'First to two wins. Pick your hand!');
      card.input(const RpsInput('rock'));
      var b = card.state.board as RpsBoard;
      expect(b.shaking, isTrue);
      expect(card.state.status, 'Rock... paper... scissors...');
      // Busy: a second pick is ignored.
      card.input(const RpsInput('paper'));
      m.k.tick(900);
      b = card.state.board as RpsBoard;
      expect(b.shaking, isFalse);
      expect(b.you, '✊');
      expect(b.bot, '✌️');
      expect(b.outcome, 'win');
      expect(b.busy, isFalse);
      expect(card.state.status, 'Rock beats scissors - point to you!');
      expect(card.state.meta, 'You 1 · 0 Bot');
      card.input(const RpsInput('rock'));
      m.k.tick(900);
      expect(card.state.result, 'win');
      expect(card.state.status, 'Rock beats scissors - point to you! You win 2-0! 🎉');
      expect(card.state.confetti, 1);
      expect(keys(card.state), ['again', 'another']);
      expect(card.playing, isFalse);
    });

    test('with reduced motion the hands show at once', () {
      final card = _make(reducedMotion: true).card;
      card.open('rps');
      card.input(const RpsInput('paper'));
      expect(card.state.status, 'Scissors beats paper - point to the bot.');
      expect((card.state.board as RpsBoard).shaking, isFalse);
    });
  });

  int count(GamesCard card, bool Function(String? c) f) => (card.state.board as TttBoard).cells.where(f).length;

  group('tic-tac-toe', () {
    test('the visitor goes first, the bot thinks for 550ms, then it is their move', () {
      final m = _make();
      final card = m.card;
      card.open('ttt');
      expect(card.state.status, 'You go first - tap a square');
      expect(card.state.meta, 'You ✕ · Bot ◯');
      card.input(const TttInput(0));
      expect((card.state.board as TttBoard).thinking, isTrue);
      card.input(const TttInput(1));
      expect(count(card, (c) => c != null), 1);
      m.k.tick(550);
      expect(count(card, (c) => c == 'O'), 1);
      expect(card.state.status, 'Your move');
    });

    test('the bot opens every second game', () {
      final m = _make();
      m.card.open('ttt');
      m.card.press('another');
      m.card.open('ttt');
      expect(m.card.state.status, 'The bot is thinking...');
      m.k.tick(550);
      expect(count(m.card, (c) => c == 'O'), 1);
    });

    test('a teammate joins while the bot is thinking: Finish my game makes its move, the board is not locked', () {
      final m = _make();
      final card = m.card;
      card.open('ttt');
      card.input(const TttInput(0));
      expect(m.k.size, 1);
      card.wrapUp('Sam');
      expect(card.state.view, 'paused');
      expect(card.state.titleEmoji, '👋');
      expect(card.state.title, "Sam's here!");
      expect(card.state.status, 'Your game is saved - finish it later?');
      expect(card.state.foot.map((f) => (f.key, f.label, f.primary)).toList(), [('resume', 'Finish my game', false)]);
      m.k.tick(5000);
      expect(count(card, (c) => c == 'O'), 0);
      card.input(const TttInput(4));
      expect(count(card, (c) => c != null), 1);
      card.press('resume');
      final b = card.state.board as TttBoard;
      expect(b.cells.where((c) => c == 'O').length, 1);
      expect(b.thinking, isFalse);
      final free = b.cells.indexWhere((c) => c == null);
      card.input(TttInput(free));
      expect(count(card, (c) => c == 'X'), 2);
    });

    test('a win marks the line and finishes', () {
      // rng 0 every time: a slip each move, the bot's casual move is the first free square.
      final m = _make(rng: () => 0);
      final card = m.card;
      card.open('ttt');
      card.input(const TttInput(4));
      m.k.tick(550); // O at 0 (slip, first free)
      card.input(const TttInput(2));
      m.k.tick(550); // O blocks 6
      card.input(const TttInput(8));
      m.k.tick(550); // O blocks 5 ... whatever it picks, play on until over
      for (var i = 0; i < 9 && card.state.result == null; i++) {
        final b = card.state.board as TttBoard;
        final free = b.cells.indexWhere((c) => c == null);
        if (free < 0) break;
        card.input(TttInput(free));
        m.k.tick(550);
      }
      final s = card.state;
      expect(s.result, isNotNull);
      expect((s.board as TttBoard).over, isTrue);
      expect(
        ['Three in a row - you beat the bot! 🎉', 'The bot got this one. Rematch? 🤖', 'A draw - great minds think alike 🤝'],
        contains(s.status),
      );
    });
  });

  group('memory', () {
    List<List<int>> byFace(MemoryBoard b) {
      final m = <String, List<int>>{};
      for (var i = 0; i < b.cards.length; i++) {
        (m[b.cards[i].face] ??= []).add(i);
      }
      return m.values.toList();
    }

    test('a pair pops the two cards just matched; a miss turns back after 850ms', () {
      final m = _make();
      final card = m.card;
      card.open('memory');
      expect(card.state.meta, 'Moves 0 · Pairs 0/6');
      final pairs = byFace(card.state.board as MemoryBoard);
      card.input(MemoryInput(pairs[0][0]));
      card.input(MemoryInput(pairs[0][1]));
      expect(card.state.status, 'A pair! ✨');
      expect((card.state.board as MemoryBoard).pop.toList()..sort(), List.of(pairs[0])..sort());
      card.input(MemoryInput(pairs[1][0]));
      card.input(MemoryInput(pairs[2][0]));
      expect(card.state.status, 'Not a pair');
      expect((card.state.board as MemoryBoard).cards.where((c) => c.up).length, 4);
      // Waiting for them to turn back: taps are ignored.
      card.input(MemoryInput(pairs[3][0]));
      m.k.tick(850);
      expect((card.state.board as MemoryBoard).cards.where((c) => c.up).length, 2);
      expect(card.state.meta, 'Moves 2 · Pairs 1/6');
    });

    test('all six pairs: the moves and the stars', () {
      final card = _make().card;
      card.open('memory');
      for (final p in byFace(card.state.board as MemoryBoard)) {
        card.input(MemoryInput(p[0]));
        card.input(MemoryInput(p[1]));
      }
      expect(card.state.result, 'win');
      expect(card.state.status, 'All pairs in 6 moves! ⭐⭐⭐');
    });
  });

  group('quiz and emoji riddles', () {
    void answerAll(GamesCard card, bool right) {
      for (var r = 0; r < 3; r++) {
        final b = card.state.board as ChoiceBoard;
        card.input(ChoiceInput(right ? b.answer : (b.answer + 1) % b.options.length));
        if (r < 2) card.press('action');
      }
    }

    test('three trivia rounds: feedback, Next, Last one, the score', () {
      final card = _make().card;
      card.open('quiz');
      expect(card.state.status, 'Three quick questions');
      expect(card.state.meta, '1 of 3 · 0 right');
      var b = card.state.board as ChoiceBoard;
      expect(b.options, hasLength(3));
      expect(b.tag, isNull);
      card.input(ChoiceInput(b.answer));
      expect(card.state.meta, '1 of 3 · 1 right');
      expect(card.state.cheer, 1);
      expect(card.state.foot.map((f) => f.label).toList(), ['Another game', 'Next →']);
      // A second pick on the same round is ignored.
      card.input(ChoiceInput((b.answer + 1) % 3));
      expect(card.state.meta, '1 of 3 · 1 right');
      card.press('action');
      expect(card.state.meta, '2 of 3 · 1 right');
      b = card.state.board as ChoiceBoard;
      card.input(ChoiceInput((b.answer + 1) % 3));
      expect(card.state.status, "Not quite - it's ${b.options[b.answer]}");
      expect(card.state.foot.map((f) => f.label).toList(), ['Another game', 'Last one →']);
      card.press('action');
      b = card.state.board as ChoiceBoard;
      card.input(ChoiceInput(b.answer));
      expect(card.state.result, 'done');
      expect(card.state.status, matches(RegExp(r'\. 2 out of 3\. So close! 🌟$')));
    });

    test('with the help centre on, questions from its articles come first, tagged', () {
      final categories = [
        {
          'name': 'Billing',
          'articles': [
            {'_id': '1', 'title': 'Downloading invoices', 'description': 'Find every invoice in one place.'},
            {'_id': '2', 'title': 'Changing your plan', 'description': 'Upgrade or cancel.'},
          ],
        },
        {
          'name': 'Account',
          'articles': [
            {'_id': '3', 'title': 'Resetting your password', 'description': 'Forgot it? Reset it.'},
          ],
        },
      ];
      final card = _make(customizations: {'enableKnowledgeBase': true}, categories: categories).card;
      card.open('quiz');
      expect(card.state.status, 'Three questions - some about our help centre');
      expect((card.state.board as ChoiceBoard).tag, 'From our help centre');
      final off = _make(categories: categories).card;
      off.open('quiz');
      expect((off.state.board as ChoiceBoard).tag, isNull);
    });

    test('emoji riddles: the picture, four options, all right is a win', () {
      final card = _make().card;
      card.open('emoji');
      final b = card.state.board as ChoiceBoard;
      expect(b.big, isNotEmpty);
      expect(b.q, "What's the phrase?");
      expect(b.options, hasLength(4));
      answerAll(card, true);
      expect(card.state.result, 'win');
      expect(card.state.status, matches(RegExp(r'3 of 3 riddles solved\. Perfect score! 🏆$')));
    });
  });

  group('reflex test', () {
    test('wait for green, tap; too soon; a lucky guess; three rounds and the average', () {
      // rng 0.9: green after 1200 + 1980 = 3180ms.
      final m = _make();
      final card = m.card;
      card.open('reaction');
      ReactionBoard pad() => card.state.board as ReactionBoard;
      expect((pad().state, pad().line), ('idle', 'Tap to start'));
      card.input(const ReactionInput());
      expect((pad().state, pad().big), ('wait', '👀'));
      card.input(const ReactionInput());
      expect((pad().state, pad().line), ('between', 'Too soon! Tap to try again'));
      expect(card.state.status, 'Too soon - wait for green');
      card.input(const ReactionInput());
      m.k.tick(3180);
      expect((pad().state, pad().line), ('go', 'Tap now!'));
      m.k.tick(50);
      card.input(const ReactionInput());
      expect(pad().line, 'A lucky guess! Tap to try again');
      for (final ms in [200, 300, 400]) {
        card.input(const ReactionInput());
        m.k.tick(3180);
        m.k.tick(ms);
        card.input(const ReactionInput());
      }
      expect(card.state.result, 'win');
      expect(card.state.status, 'Sharp reflexes 🎯 - 300 ms on average.');
      expect(card.state.meta, '200 · 300 · 400 ms');
      expect((pad().state, pad().line), ('done', '300 ms average'));
    });

    test('a teammate joining mid-round: the round is reset, Tap to carry on', () {
      final m = _make();
      final card = m.card;
      card.open('reaction');
      card.input(const ReactionInput());
      card.wrapUp('');
      expect(card.state.title, "Someone's here!");
      m.k.tick(10000);
      card.press('resume');
      final b = card.state.board as ReactionBoard;
      expect((b.state, b.big, b.line), ('between', '⏸️', 'Tap to carry on'));
    });
  });

  // The scramble words by their hint (web content.ts WORDS).
  String solve(List<String> letters, String hint) {
    final w = words.firstWhere((x) => x.hint == hint).w;
    expect(List.of(letters)..sort(), w.split('')..sort());
    return w;
  }

  group('word scramble', () {
    test('tap letters in order; a wrong word shakes; tap a slot to take it back; solved moves on', () {
      final m = _make();
      final card = m.card;
      card.open('scramble');
      final b0 = card.state.board as ScrambleBoard;
      expect(card.state.meta, 'Word 1 of 3 · 0 solved');
      expect(b0.skipLabel, 'Skip');
      // Wrong: the tiles as they lie (never the word itself).
      for (var i = 0; i < b0.letters.length; i++) {
        card.input(TileInput(i));
      }
      var b = card.state.board as ScrambleBoard;
      expect(b.nope, 1);
      expect(card.state.status, 'Not quite - tap letters to take them back');
      card.input(const SlotInput(0));
      expect((card.state.board as ScrambleBoard).placed, isEmpty);
      card.input(const SkipInput());
      b = card.state.board as ScrambleBoard;
      expect(b.revealed, isTrue);
      final revealed = b.placed.map((i) => b.letters[i]).join();
      expect(card.state.status, 'It was $revealed.');
      m.k.tick(1500);
      b = card.state.board as ScrambleBoard;
      expect(card.state.meta, 'Word 2 of 3 · 0 solved');
      expect(b.placed, isEmpty);
    });

    test('three words solved: Word wizard', () {
      final m = _make();
      final card = m.card;
      card.open('scramble');
      final solvedWords = <String>[];
      for (var r = 0; r < 3; r++) {
        final b = card.state.board as ScrambleBoard;
        final target = solve(b.letters, b.hint);
        solvedWords.add(target);
        for (final l in target.split('')) {
          card.input(KeyInput(l.toLowerCase()));
        }
        if (r < 2) {
          expect(card.state.status, '$target - got it! 🎉');
          m.k.tick(1100);
        }
      }
      expect(card.state.result, 'win');
      expect(card.state.status, '${solvedWords[2]} - got it! 🎉 You solved 3 of 3. Word wizard! 🧙');
    });
  });

  group('the footer and folding away', () {
    test('Play again replays the same game; Another game goes back to the menu', () {
      final card = _make().card;
      card.open('memory');
      card.press('another');
      expect((card.state.view, card.state.title), ('menu', 'Pick a game'));
      card.open('rps');
      card.press('again');
      expect((card.state.view, card.state.game, card.state.meta), ('game', 'rps', 'You 0 · 0 Bot'));
    });

    test('a teammate joins: the menu leaves; a finished game stays as a result, with no buttons and no x', () {
      final a = _make();
      a.card.wrapUp('Sam');
      expect(a.card.state.view, 'gone');

      final b = _make(reducedMotion: true);
      b.card.open('rps');
      b.card.input(const RpsInput('rock'));
      b.card.input(const RpsInput('rock'));
      expect(b.card.state.result, 'win');
      b.card.wrapUp('Sam');
      final s = b.card.state;
      expect((s.view, s.settled, s.closable), ('game', true, false));
      expect(s.foot, isEmpty);
    });

    test('the menu on a paused card is back, with its x', () {
      final card = _make().card;
      card.open('rps');
      card.wrapUp('Sam');
      card.menu();
      expect((card.state.view, card.state.closable), ('menu', true));
      expect(card.state.chips.length, 7);
    });

    test('removed: its timers stop and taps do nothing', () {
      final m = _make();
      m.card.open('ttt');
      m.card.input(const TttInput(0));
      m.card.remove();
      expect(m.k.size, 0);
      m.card.input(const TttInput(1));
      expect(m.card.state.view, 'gone');
    });

    test('every change reaches the subscribers', () {
      final card = _make().card;
      final seen = <String>[];
      final off = card.subscribe((s) => seen.add(s.view));
      card.open('quiz');
      card.press('another');
      off();
      card.open('rps');
      expect(seen, ['game', 'menu']);
    });
  });
}
