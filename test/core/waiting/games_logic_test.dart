// The waiting games' rules (lib/src/core/waiting/games_logic.dart), ported
// from the React Native SDK's __tests__/core/gamesLogic.test.ts: the same
// cases as the web widget's tests/waitingGames.test.js.
import 'dart:convert';
import 'dart:math' as math;

import 'package:conferbot_flutter/src/core/waiting/games_logic.dart' as logic;
import 'package:flutter_test/flutter_test.dart';

// A repeatable "random": a fixed sequence.
logic.Rng seq(List<double> xs) {
  var i = 0;
  return () => xs[i++ % xs.length];
}

List<logic.Cell> B(String s) => s.split('').map<logic.Cell>((ch) => ch == 'X' || ch == 'O' ? ch : null).toList();

final _random = math.Random();
double rnd() => _random.nextDouble();

void main() {
  group('rock paper scissors', () {
    test('every pairing', () {
      expect(logic.rpsOutcome('rock', 'scissors'), 'win');
      expect(logic.rpsOutcome('paper', 'rock'), 'win');
      expect(logic.rpsOutcome('scissors', 'paper'), 'win');
      expect(logic.rpsOutcome('rock', 'paper'), 'lose');
      expect(logic.rpsOutcome('paper', 'scissors'), 'lose');
      expect(logic.rpsOutcome('scissors', 'rock'), 'lose');
      for (final h in logic.hands) {
        expect(logic.rpsOutcome(h, h), 'draw');
      }
    });

    test('best of three, the first to two', () {
      expect(logic.rpsWinner(you: 1, bot: 1), isNull);
      expect(logic.rpsWinner(you: 2, bot: 1), 'you');
      expect(logic.rpsWinner(you: 0, bot: 2), 'bot');
    });
  });

  group('tic-tac-toe', () {
    test('rows, columns, diagonals, draws', () {
      var w = logic.tttWinner(B('XXX......'))!;
      expect(w.winner, 'X');
      expect(w.line, [0, 1, 2]);
      w = logic.tttWinner(B('O..O..O..'))!;
      expect(w.winner, 'O');
      expect(w.line, [0, 3, 6]);
      w = logic.tttWinner(B('..X.X.X..'))!;
      expect(w.winner, 'X');
      expect(w.line, [2, 4, 6]);
      w = logic.tttWinner(B('XOXXOOOXX'))!;
      expect(w.winner, 'draw');
      expect(w.line, <int>[]);
      expect(logic.tttWinner(B('XO.......')), isNull);
    });

    test('the bot takes a win before it blocks', () {
      expect(logic.tttBotMove(B('OO.XX....'), rnd, 1), 2);
    });

    test('the bot always blocks, even when it slips', () {
      expect(logic.tttBotMove(B('XX..O....'), () => 0, 1), 2);
      expect(logic.tttBotMove(B('X...X....'), () => 0.99, 1), 8);
    });

    test('with no slip the bot never loses', () {
      bool play(List<logic.Cell> board, String turn) {
        final w = logic.tttWinner(board);
        if (w != null) return w.winner != 'X';
        if (turn == 'O') {
          final m = logic.tttBotMove(board, () => 0, 0);
          final next = List<logic.Cell>.of(board);
          next[m] = 'O';
          return play(next, 'X');
        }
        for (var i = 0; i < board.length; i++) {
          if (board[i] != null) continue;
          final next = List<logic.Cell>.of(board);
          next[i] = 'X';
          if (!play(next, 'O')) return false;
        }
        return true;
      }

      expect(play(List<logic.Cell>.filled(9, null), 'X'), isTrue);
    });

    test('the bot can slip into a casual move, so it can be beaten', () {
      final moves = <int>{};
      for (final r in [0.0, 0.2, 0.5, 0.8, 0.95]) {
        moves.add(logic.tttBotMove(B('X........'), seq([0, r]), 1));
      }
      expect(moves.length, greaterThan(1));
      expect(logic.tttBotMove(B('X........'), () => 0.99, 0), 4);
    });
  });

  group('memory', () {
    test('six pairs, shuffled', () {
      final deck = logic.memoryDeck(logic.memoryFaces, 6, seq([0.1, 0.7, 0.3, 0.9, 0.5]));
      expect(deck, hasLength(12));
      final counts = <String, int>{};
      for (final c in deck) {
        counts[c.face] = (counts[c.face] ?? 0) + 1;
      }
      expect(counts.keys, hasLength(6));
      expect(counts.values.every((n) => n == 2), isTrue);
      expect(deck.map((c) => c.id).toList(), List.generate(12, (i) => i));
    });

    test('a pair stays up, a miss is counted and turned back, the last pair ends it', () {
      final cards = [for (final (id, face) in ['A', 'B', 'A', 'B'].indexed) logic.MemoryCard(id: id, face: face)];
      var s = logic.MemoryState(cards: cards);
      var r = logic.memoryFlip(s, 0);
      expect(r.result, 'open');
      r = logic.memoryFlip(r.state, 0);
      expect(r.result, 'ignored');
      r = logic.memoryFlip(r.state, 1);
      expect(r.result, 'miss');
      expect(r.state.moves, 1);
      expect(logic.memoryFlip(r.state, 2).result, 'ignored');
      s = logic.memoryHide(r.state);
      r = logic.memoryFlip(logic.memoryFlip(s, 0).state, 2);
      expect(r.result, 'match');
      expect(r.state.cards[0].matched && r.state.cards[2].matched, isTrue);
      expect(logic.memoryFlip(r.state, 0).result, 'ignored');
      r = logic.memoryFlip(logic.memoryFlip(r.state, 1).state, 3);
      expect(r.result, 'done');
      expect(r.state.moves, 3);
    });

    test('stars for fewer moves', () {
      expect(logic.memoryStars(6), 3);
      expect(logic.memoryStars(9), 3);
      expect(logic.memoryStars(12), 2);
      expect(logic.memoryStars(20), 1);
    });
  });

  const cats = [
    {
      'name': 'Billing',
      'articles': [
        {'_id': '1', 'title': 'Downloading invoices', 'description': 'Find every invoice in one place.'},
        {'_id': '2', 'title': 'Changing your plan', 'description': 'Upgrade, downgrade or cancel at any time.'},
      ],
    },
    {
      'name': 'Account',
      'articles': [
        {'_id': '3', 'title': 'Resetting your password', 'description': ''},
      ],
    },
    {
      'name': 'Shipping',
      'articles': [
        {'_id': '4', 'title': 'Tracking an order', 'description': 'See where your parcel is.'},
      ],
    },
  ];

  group('quiz', () {
    test('questions from the help centre, the right answer among the options', () {
      final qs = logic.quizFromArticles(cats, const [], seq([0.3, 0.6, 0.1, 0.8]));
      expect(qs, hasLength(3));
      for (final q in qs) {
        expect(q.source, 'kb');
        expect(q.options, hasLength(3));
        expect(q.answer, greaterThanOrEqualTo(0));
        expect(q.options.toSet().length, 3);
      }
      final pw = qs.where((q) => q.q.contains('Resetting your password')).firstOrNull;
      expect(pw, isNotNull);
      expect(pw!.options[pw.answer], 'Account');
      expect(pw.q, 'Where in our help centre would you find "Resetting your password"?');
    });

    test('too few articles means trivia', () {
      expect(
          logic.quizFromArticles([
            {
              'name': 'x',
              'articles': [
                {'title': 'Only one'}
              ]
            }
          ], const []),
          isEmpty);
      final qs = logic.buildQuiz(logic.trivia, const [], seq([0.2, 0.4, 0.6]));
      expect(qs, hasLength(3));
      expect(qs.every((q) => q.source == 'trivia' && q.options.length == 3), isTrue);
    });

    test('help-centre questions come first, topped up with trivia', () {
      final kb = logic.quizFromArticles(cats, const [], seq([0.5])).take(1).toList();
      expect(logic.buildQuiz(logic.trivia, kb, seq([0.5])).map((q) => q.source).toList(), ['kb', 'trivia', 'trivia']);
    });

    test('scoring and the verdict', () {
      logic.QuizQuestion q(int answer) => logic.QuizQuestion(q: '', options: const [], answer: answer, source: 'trivia');
      final qs = [q(0), q(2), q(1)];
      expect(logic.quizScore(qs, [0, 2, 1]), 3);
      expect(logic.quizScore(qs, [0, 1, 1]), 2);
      expect(logic.quizScore(qs, [1, 1, 0]), 0);
      expect(logic.quizVerdict(3, 3), contains('Perfect'));
      expect(logic.quizVerdict(0, 3), contains('another go'));
      expect(logic.quizVerdict(2, 3), contains('So close'));
    });
  });

  group('reflex, word scramble, emoji riddles', () {
    test('a fair random wait and a friendly verdict', () {
      expect(logic.reactionDelay(() => 0), 1200);
      expect(logic.reactionDelay(() => 1), 3400);
      expect(logic.reactionVerdict(200), contains('Lightning'));
      expect(logic.reactionVerdict(300), contains('Sharp'));
      expect(logic.reactionVerdict(400), contains('Nicely'));
      expect(logic.reactionVerdict(600), contains('steady'));
      expect(logic.average([200, 300, 401]), 300);
      expect(logic.reactionCounts(40), isFalse);
      expect(logic.reactionCounts(180), isTrue);
    });

    test('a scramble is never the word itself, and any case solves it', () {
      for (final word in logic.words) {
        final w = word.w;
        final s = logic.scrambleWord(w, seq([0.99, 0.98, 0.97, 0.96, 0.95, 0.94]));
        expect(s.join(), isNot(w));
        expect(List.of(s)..sort(), w.split('')..sort());
      }
      expect(logic.scrambleSolved(' planet ', 'PLANET'), isTrue);
      expect(logic.scrambleSolved('PLANTE', 'PLANET'), isFalse);
    });

    test('four riddle options, one right', () {
      for (final r in logic.riddles) {
        final o = logic.riddleOptions(r, seq([0.4, 0.1]));
        expect(o.options, hasLength(4));
        expect(o.options[o.answer], r.a);
        expect(o.options.toSet().length, 4);
      }
    });

    test('no em dashes in the words', () {
      final all = jsonEncode([
        for (final t in logic.trivia) [t.q, t.a, t.wrong],
        for (final r in logic.riddles) [r.e, r.a, r.wrong],
        for (final w in logic.words) [w.w, w.hint],
        [logic.Verdict.perfect, logic.Verdict.tough, logic.Verdict.close, logic.Verdict.notBad, logic.Verdict.nice],
      ]);
      expect(all.contains(String.fromCharCode(0x2014)), isFalse);
    });
  });
}
