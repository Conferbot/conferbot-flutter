/// Waiting games: the rules and the words, with no UI, so they can be tested
/// on their own. Ported from the React Native SDK (src/core/gamesLogic.ts),
/// itself from the web widget: conferbot-widget src/ts/chat/games/logic.ts
/// (every rule as it is) and src/ts/chat/games/content.ts (the quiz and
/// scramble per language come from core/i18n/i18n_games.dart, generated from
/// it; the emoji riddles are English wordplay). Words are the web's "games.*"
/// keys, read with t() as logic.ts does.
/// Every random choice takes an [Rng] (a fresh Random by default) so tests
/// can pin it.
library;

import 'dart:math' as math;

import '../i18n/i18n.dart' show t;
import '../i18n/i18n_games.dart' show i18nTriviaOf, i18nWordsOf;

/// A number in [0, 1), as Math.random.
typedef Rng = double Function();

final math.Random _random = math.Random();
double defaultRng() => _random.nextDouble();

/// A shuffled copy (Fisher-Yates).
List<T> shuffle<T>(List<T> items, [Rng rng = defaultRng]) {
  final out = List<T>.of(items);
  for (var i = out.length - 1; i > 0; i--) {
    final j = (rng() * (i + 1)).floor();
    final t = out[i];
    out[i] = out[j];
    out[j] = t;
  }
  return out;
}

T pick<T>(List<T> items, [Rng rng = defaultRng]) => items[(rng() * items.length).floor() % items.length];

// ---------------------------------------------------------------- content (web content.ts)

class Trivia {
  const Trivia(this.q, this.a, this.wrong);
  final String q;
  final String a;
  final List<String> wrong;
}

class Riddle {
  const Riddle(this.e, this.a, this.wrong);
  final String e;
  final String a;
  final List<String> wrong;
}

class Word {
  const Word(this.w, this.hint);
  final String w;
  final String hint;
}

/// The English quiz (web content.ts TRIVIA; every language in i18n_games.dart).
final List<Trivia> trivia = i18nTriviaOf('en');

const List<Riddle> riddles = [
  Riddle('☀️🌻', 'Sunflower', ['Daisy', 'Sunrise', 'Sunscreen']),
  Riddle('⭐🐟', 'Starfish', ['Goldfish', 'Swordfish', 'Shooting star']),
  Riddle('🥵🐶', 'Hot dog', ['Puppy love', 'Sunbathing', 'Dog days']),
  Riddle('🍿🎬', 'Movie night', ['Popcorn party', 'Film star', 'Snack time']),
  Riddle('🐛📚', 'Bookworm', ['Library', 'Caterpillar', 'Homework']),
  Riddle('🧈🪰', 'Butterfly', ['Dragonfly', 'Firefly', 'Bumblebee']),
  Riddle('🌙🚶', 'Moonwalk', ['Night shift', 'Sleepwalk', 'Stargazing']),
  Riddle('☕⏸️', 'Coffee break', ['Morning rush', 'Tea time', 'Wake up call']),
  Riddle('🐟🍟', 'Fish and chips', ['Sushi', 'Fish fingers', 'Seafood']),
  Riddle('🍯🌙', 'Honeymoon', ['Sweet dreams', 'Moonlight', 'Bedtime']),
  Riddle('🌧️🏹', 'Rainbow', ['Raincoat', 'Archery', 'Storm']),
  Riddle('☀️👓', 'Sunglasses', ['Sunburn', 'Eyesight', 'Daylight']),
  Riddle('🧀🎂', 'Cheesecake', ['Pizza', 'Fondue', 'Cupcake']),
  Riddle('⌚🐶', 'Watchdog', ['Hot dog', 'Dog walk', 'Clockwork']),
  Riddle('🦶⚽', 'Football', ['Footprint', 'Basketball', 'Kick off']),
  Riddle('🌊🏄', 'Surfing', ['Swimming', 'Sailing', 'Beach day']),
];

/// The English scramble words (web content.ts WORDS).
final List<Word> words = i18nWordsOf('en');

/// The quiz in a language, English for any other (web content.ts triviaFor).
List<Trivia> triviaFor(String lang) => i18nTriviaOf(lang);

/// The scramble words in a language (web content.ts wordsFor).
List<Word> wordsFor(String lang) => i18nWordsOf(lang);

const List<String> memoryFaces = ['🍕', '🚀', '🌵', '🐙', '🎈', '🍩', '🦊', '🌈', '⚽', '🎧', '🍉', '🐢', '🦄', '🍦'];

// ---------------------------------------------------------------- RPS

/// rock, paper or scissors.
const List<String> hands = ['rock', 'paper', 'scissors'];
const Map<String, String> handEmoji = {'rock': '✊', 'paper': '✋', 'scissors': '✌️'};
/// Each hand's name in the active language (web ui.ts handName, games.rps.*).
Map<String, String> get handName => {'rock': t('games.rps.rock'), 'paper': t('games.rps.paper'), 'scissors': t('games.rps.scissors')};
const Map<String, String> _beats = {'rock': 'scissors', 'paper': 'rock', 'scissors': 'paper'};

/// From the visitor's side: 'win', 'lose' or 'draw'.
String rpsOutcome(String you, String bot) => you == bot ? 'draw' : (_beats[you] == bot ? 'win' : 'lose');

/// Best of three: the first to two wins.
const rpsToWin = 2;

/// 'you', 'bot' or null.
String? rpsWinner({required int you, required int bot}) => you >= rpsToWin ? 'you' : (bot >= rpsToWin ? 'bot' : null);

// ---------------------------------------------------------------- Tic-tac-toe

/// A square: 'X', 'O' or null.
typedef Cell = String?;

const List<List<int>> lines = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8], //
  [0, 3, 6], [1, 4, 7], [2, 5, 8], //
  [0, 4, 8], [2, 4, 6],
];

/// The winner ('X', 'O' or 'draw' on a full board) and the line, else null.
({String winner, List<int> line})? tttWinner(List<Cell> board) {
  for (final l in lines) {
    final a = board[l[0]];
    if (a != null && a == board[l[1]] && a == board[l[2]]) return (winner: a, line: List.of(l));
  }
  return board.every((c) => c != null) ? (winner: 'draw', line: <int>[]) : null;
}

List<int> _empties(List<Cell> board) => [
      for (var i = 0; i < board.length; i++)
        if (board[i] == null) i,
    ];

/// The square that completes a line for [who], or -1.
int tttFinisher(List<Cell> board, String who) {
  for (final line in lines) {
    final mine = line.where((i) => board[i] == who).length;
    final open = line.where((i) => board[i] == null).toList();
    if (mine == 2 && open.length == 1) return open[0];
  }
  return -1;
}

int _minimax(List<Cell> board, String turn, int depth) {
  final w = tttWinner(board);
  if (w != null) return w.winner == 'O' ? 10 - depth : (w.winner == 'X' ? depth - 10 : 0);
  final scores = <int>[];
  for (final i in _empties(board)) {
    board[i] = turn;
    scores.add(_minimax(board, turn == 'O' ? 'X' : 'O', depth + 1));
    board[i] = null;
  }
  return turn == 'O' ? scores.reduce(math.max) : scores.reduce(math.min);
}

/// The bot (O): always takes a win, always blocks one, and otherwise plays
/// its best move - except now and then ([slip], 0-1) it plays a casual one,
/// so a sharp visitor can set up a fork and beat it. Smart, but beatable.
int tttBotMove(List<Cell> board, [Rng rng = defaultRng, double slip = 0.3]) {
  final open = _empties(board);
  if (open.isEmpty) return -1;
  final win = tttFinisher(board, 'O');
  if (win >= 0) return win;
  final block = tttFinisher(board, 'X');
  if (block >= 0) return block;
  if (rng() < slip) return pick(open, rng);
  final b = List<Cell>.of(board);
  var best = -1 << 30;
  var moves = <int>[];
  for (final i in open) {
    b[i] = 'O';
    final s = _minimax(b, 'X', 1);
    b[i] = null;
    if (s > best) {
      best = s;
      moves = [i];
    } else if (s == best) {
      moves.add(i);
    }
  }
  return pick(moves, rng);
}

// ---------------------------------------------------------------- Memory

class MemoryCard {
  const MemoryCard({required this.id, required this.face, this.matched = false});
  final int id;
  final String face;
  final bool matched;

  MemoryCard matchedCopy() => MemoryCard(id: id, face: face, matched: true);
}

/// [pairs] faces from the pool, each twice, shuffled (4x3 = 6 pairs).
List<MemoryCard> memoryDeck(List<String> pool, [int pairs = 6, Rng rng = defaultRng]) {
  final faces = shuffle(pool, rng).take(pairs).expand((f) => [f, f]).toList();
  final deck = shuffle(faces, rng);
  return [for (var id = 0; id < deck.length; id++) MemoryCard(id: id, face: deck[id])];
}

class MemoryState {
  const MemoryState({required this.cards, this.open = const [], this.moves = 0});
  final List<MemoryCard> cards;

  /// Face-up cards not yet matched (0, 1 or 2).
  final List<int> open;
  final int moves;
}

/// Turn a card over. Two open cards make a move: a pair stays up, a miss
/// reports "miss" (the caller turns them back after a beat with [memoryHide]).
/// The result is 'ignored', 'open', 'match', 'miss' or 'done'.
({MemoryState state, String result}) memoryFlip(MemoryState s, int id) {
  final card = id >= 0 && id < s.cards.length ? s.cards[id] : null;
  if (card == null || card.matched || s.open.contains(id) || s.open.length >= 2) return (state: s, result: 'ignored');
  final open = [...s.open, id];
  if (open.length < 2) return (state: MemoryState(cards: s.cards, open: open, moves: s.moves), result: 'open');
  final a = s.cards[open[0]];
  final b = s.cards[open[1]];
  final moves = s.moves + 1;
  if (a.face == b.face) {
    final cards = s.cards.map((c) => c.id == a.id || c.id == b.id ? c.matchedCopy() : c).toList();
    final done = cards.every((c) => c.matched);
    return (state: MemoryState(cards: cards, open: const [], moves: moves), result: done ? 'done' : 'match');
  }
  return (state: MemoryState(cards: s.cards, open: open, moves: moves), result: 'miss');
}

MemoryState memoryHide(MemoryState s) => MemoryState(cards: s.cards, open: const [], moves: s.moves);

/// Three stars for a near-perfect run, down to one.
int memoryStars(int moves, [int pairs = 6]) => moves <= pairs + 3 ? 3 : (moves <= pairs * 2 + 2 ? 2 : 1);

// ---------------------------------------------------------------- Quiz

class QuizQuestion {
  const QuizQuestion({required this.q, required this.options, required this.answer, required this.source});
  final String q;
  final List<String> options;
  final int answer;

  /// Where it came from: 'kb' (the bot's help centre) or 'trivia'.
  final String source;
}

String _cleanText(dynamic v, int max) {
  if (v is! String) return '';
  final t = v.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length > max ? t.substring(0, max) : t;
}

/// Options in a random order, the right one tracked.
QuizQuestion _asQuestion(String q, String right, List<String> wrong, String source, Rng rng) {
  final options = shuffle([right, ...wrong], rng);
  return QuizQuestion(q: q, options: options, answer: options.indexOf(right), source: source);
}

class _KbItem {
  _KbItem(this.title, this.desc, this.cat);
  final String title;
  final String desc;
  final String cat;
}

/// Questions from the bot's own help centre: "Which of our articles helps
/// with: <its summary>" and "Where in our help centre would you find
/// <title>?". Needs three titled articles (and three categories for the
/// second kind); none otherwise.
List<QuizQuestion> quizFromArticles(dynamic categories, dynamic recent, [Rng rng = defaultRng, int count = 3]) {
  final seen = <String>{};
  final items = <_KbItem>[];
  void add(dynamic a, String cat) {
    final title = _cleanText(a is Map ? a['title'] : null, 70);
    if (title.isEmpty || seen.contains(title.toLowerCase())) return;
    seen.add(title.toLowerCase());
    items.add(_KbItem(title, _cleanText(a is Map ? a['description'] : null, 120), cat));
  }

  for (final c in categories is List ? categories : const []) {
    final arts = c is Map && c['articles'] is List ? c['articles'] as List : const [];
    for (final a in arts) {
      add(a, _cleanText(c is Map ? c['name'] : null, 40));
    }
  }
  for (final a in recent is List ? recent : const []) {
    add(a, '');
  }
  if (items.length < 3) return [];
  final cats = items.map((i) => i.cat).where((c) => c.isNotEmpty).toSet().toList();
  final out = <QuizQuestion>[];
  for (final it in shuffle(items, rng)) {
    if (out.length >= count) break;
    final others = shuffle(items.where((o) => !identical(o, it)).toList(), rng).map((o) => o.title).take(2).toList();
    if (it.desc.isNotEmpty && it.desc.toLowerCase() != it.title.toLowerCase() && others.length == 2) {
      out.add(_asQuestion(t('games.quiz.kbWhich', {'desc': it.desc}), it.title, others, 'kb', rng));
    } else if (it.cat.isNotEmpty && cats.length >= 3) {
      final wrong = shuffle(cats.where((c) => c != it.cat).toList(), rng).take(2).toList();
      out.add(_asQuestion(t('games.quiz.kbWhere', {'title': it.title}), it.cat, wrong, 'kb', rng));
    }
  }
  return out;
}

/// The quiz: help-centre questions first, topped up with trivia.
List<QuizQuestion> buildQuiz(List<Trivia> pool, List<QuizQuestion> kb, [Rng rng = defaultRng, int count = 3]) {
  final out = kb.take(count).toList();
  for (final t in shuffle(pool, rng)) {
    if (out.length >= count) break;
    out.add(_asQuestion(t.q, t.a, t.wrong.take(2).toList(), 'trivia', rng));
  }
  return out;
}

/// How many of [picks] are right.
int quizScore(List<QuizQuestion> questions, List<int?> picks) {
  var n = 0;
  for (var i = 0; i < questions.length; i++) {
    if (i < picks.length && picks[i] == questions[i].answer) n++;
  }
  return n;
}

/// The verdicts in the active language (web logic.ts, games.verdict.*).
class Verdict {
  Verdict._();
  static String get perfect => t('games.verdict.perfect');
  static String get tough => t('games.verdict.tough');
  static String get close => t('games.verdict.close');
  static String get notBad => t('games.verdict.notBad');
  static String get nice => t('games.verdict.nice');
}

String quizVerdict(int score, int total) => score == total
    ? Verdict.perfect
    : score == 0
        ? Verdict.tough
        : score >= total - 1
            ? Verdict.close
            : Verdict.notBad;

// ---------------------------------------------------------------- Reflex

/// A random wait before green: 1.2 to 3.4 seconds, in milliseconds.
int reactionDelay([Rng rng = defaultRng]) => 1200 + _jsRound(rng() * 2200);

/// Faster than any person can see it: a lucky guess, counted as too soon.
const reactionMinMs = 100;
bool reactionCounts(num ms) => ms >= reactionMinMs;

String reactionVerdict(num ms) => t(ms < 250
    ? 'games.reaction.fast'
    : ms < 350
        ? 'games.reaction.sharp'
        : ms < 500
            ? 'games.verdict.nice'
            : 'games.reaction.steady');

/// Math.round: halves go up (-2.5 is -2), as in JS.
int _jsRound(num x) => (x + 0.5).floor();

int average(List<num> xs) => xs.isEmpty ? 0 : _jsRound(xs.fold<num>(0, (a, b) => a + b) / xs.length);

/// Math.round, as the reflex test reads its clock.
int jsRound(num x) => _jsRound(x);

// ---------------------------------------------------------------- Word scramble

/// The word's letters in an order that is not the word itself.
List<String> scrambleWord(String word, [Rng rng = defaultRng]) {
  final letters = word.toUpperCase().split('');
  if (letters.toSet().length < 2) return letters;
  for (var tries = 0; tries < 20; tries++) {
    final s = shuffle(letters, rng);
    if (s.join() != letters.join()) return s;
  }
  return letters.reversed.toList();
}

bool scrambleSolved(String guess, String word) => guess.trim().toUpperCase() == word.trim().toUpperCase();

// ---------------------------------------------------------------- Emoji riddles

/// One riddle's options, shuffled, with the answer's index.
({List<String> options, int answer}) riddleOptions(Riddle r, [Rng rng = defaultRng]) {
  final options = shuffle([r.a, ...r.wrong.take(3)], rng);
  return (options: options, answer: options.indexOf(r.a));
}
