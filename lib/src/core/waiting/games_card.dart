/// Waiting games: the in-chat card as a state machine, with no UI. Ported
/// from the React Native SDK (src/core/gamesCard.ts), itself from the web
/// widget's conferbot-widget src/ts/chat/games/ui.ts (mountGamesCard and the
/// seven game factories): the offer (the owner's line and a chip per game),
/// then the game itself, then "Play again" / "Another game"; folded away
/// when a teammate joins ("Finish my game"). Every change is a new [state]
/// snapshot that a view draws (widgets/waiting/games_card_view.dart), and
/// every tap is a call.
///
/// Timers go through the injected clock. A game's pending steps (the bot's
/// move, cards turning back, the next round) are held while the card is
/// paused and run on resume, as the web's ctx.queued. With `reducedMotion`
/// the rock-paper-scissors shake is skipped and the bot moves sooner.
///
/// Nothing here is sent anywhere or stored: the games are the visitor's own
/// and leave no trace in the transcript.
library;

import 'dart:async';

import '../live_chat/handover_waiting.dart' show SetTimer, ClearTimer;
import 'games_logic.dart';
import 'waiting_games.dart';

/// The card's words (web i18n/en.ts "games.*").
class GamesText {
  GamesText._();
  static const card = 'Games while you wait';
  static const close = 'Close games';
  static const pick = 'Pick a game';
  static const again = 'Play again';
  static const another = 'Another game';
  static const notNow = 'Not now';
  static String pausedNamed(String name) => "$name's here!";
  static const pausedSomeone = "Someone's here!";
  static const pausedSaved = 'Your game is saved - finish it later?';
  static const resume = 'Finish my game';
}

/// A footer button's key: notNow, again, another, action ("Next"), resume.
class FootButton {
  const FootButton({required this.key, required this.label, required this.primary});
  final String key;
  final String label;
  final bool primary;

  @override
  String toString() => 'FootButton($key, $label${primary ? ', primary' : ''})';
}

sealed class Board {
  const Board();
}

class RpsHand {
  const RpsHand(this.hand, this.emoji, this.name);
  final String hand;
  final String emoji;
  final String name;
}

class RpsBoard extends Board {
  const RpsBoard({
    required this.you,
    required this.bot,
    required this.outcome,
    required this.shaking,
    required this.busy,
    required this.hands,
  });
  final String you;
  final String bot;

  /// 'win', 'lose', 'draw' or null.
  final String? outcome;
  final bool shaking;
  final bool busy;
  final List<RpsHand> hands;
}

class TttBoard extends Board {
  const TttBoard({required this.cells, required this.line, required this.over, required this.thinking});
  final List<Cell> cells;
  final List<int> line;
  final bool over;
  final bool thinking;
}

class MemoryFace {
  const MemoryFace({required this.face, required this.up, required this.matched});
  final String face;
  final bool up;
  final bool matched;
}

class MemoryBoard extends Board {
  const MemoryBoard({required this.cards, required this.pop});
  final List<MemoryFace> cards;
  final List<int> pop;
}

class ChoiceBoard extends Board {
  const ChoiceBoard({
    required this.game,
    this.tag,
    this.big,
    required this.q,
    required this.options,
    required this.answer,
    required this.picked,
  });

  /// 'quiz' or 'emoji'.
  final String game;
  final String? tag;
  final String? big;
  final String q;
  final List<String> options;
  final int answer;
  final int? picked;
}

class ReactionBoard extends Board {
  const ReactionBoard({required this.state, required this.big, required this.line});

  /// idle, wait, go, between or done.
  final String state;
  final String big;
  final String line;
}

class ScrambleBoard extends Board {
  const ScrambleBoard({
    required this.hint,
    required this.letters,
    required this.placed,
    required this.solved,
    required this.revealed,
    required this.nope,
    required this.skipLabel,
  });
  final String hint;
  final List<String> letters;

  /// Slot i holds letters[placed[i]].
  final List<int> placed;
  final bool solved;
  final bool revealed;

  /// Bumped on a wrong word (the slots shake).
  final int nope;
  final String skipLabel;
}

class GamesCardState {
  const GamesCardState({
    required this.view,
    this.title = '',
    this.titleEmoji = '',
    this.meta = '',
    this.status = '',
    this.result,
    this.settled = false,
    this.closable = true,
    this.chips = const [],
    this.game,
    this.board,
    this.foot = const [],
    this.cheer = 0,
    this.confetti = 0,
  });

  /// menu, game, paused or gone.
  final String view;
  final String title;
  final String titleEmoji;

  /// The score or progress at the card's top right.
  final String meta;

  /// The line under the game (announced politely).
  final String status;

  /// 'win', 'done' or null.
  final String? result;

  /// A finished game left as a result when a teammate joined: no buttons, no close.
  final bool settled;
  final bool closable;

  /// The menu's games (the owner's, for the language).
  final List<GameMeta> chips;
  final String? game;
  final Board? board;
  final List<FootButton> foot;

  /// Bumped for a small "nice!" and for a win's confetti.
  final int cheer;
  final int confetti;

  static const _keep = Object();

  GamesCardState copyWith({
    String? view,
    String? title,
    String? titleEmoji,
    String? meta,
    String? status,
    Object? result = _keep,
    bool? settled,
    bool? closable,
    Object? game = _keep,
    Object? board = _keep,
    List<FootButton>? foot,
    int? cheer,
    int? confetti,
  }) =>
      GamesCardState(
        view: view ?? this.view,
        title: title ?? this.title,
        titleEmoji: titleEmoji ?? this.titleEmoji,
        meta: meta ?? this.meta,
        status: status ?? this.status,
        result: identical(result, _keep) ? this.result : result as String?,
        settled: settled ?? this.settled,
        closable: closable ?? this.closable,
        chips: chips,
        game: identical(game, _keep) ? this.game : game as String?,
        board: identical(board, _keep) ? this.board : board as Board?,
        foot: foot ?? this.foot,
        cheer: cheer ?? this.cheer,
        confetti: confetti ?? this.confetti,
      );
}

/// A tap inside a game.
sealed class GameInput {
  const GameInput();
}

class RpsInput extends GameInput {
  const RpsInput(this.hand);
  final String hand;
}

class TttInput extends GameInput {
  const TttInput(this.i);
  final int i;
}

class MemoryInput extends GameInput {
  const MemoryInput(this.i);
  final int i;
}

class ChoiceInput extends GameInput {
  const ChoiceInput(this.i);
  final int i;
}

class ReactionInput extends GameInput {
  const ReactionInput();
}

class TileInput extends GameInput {
  const TileInput(this.i);
  final int i;
}

class SlotInput extends GameInput {
  const SlotInput(this.i);
  final int i;
}

class SkipInput extends GameInput {
  const SkipInput();
}

/// A hardware key in the word scramble: a letter, or Backspace.
class KeyInput extends GameInput {
  const KeyInput(this.key);
  final String key;
}

class _Ctx {
  _Ctx({
    required this.rng,
    required this.reduced,
    required this.now,
    required this.c,
    required this.categories,
    required this.recent,
    required this.plays,
    required this.meta,
    required this.status,
    required this.finish,
    required this.cheer,
    required this.action,
    required this.later,
    required this.timer,
    required this.clear,
  });

  final Rng rng;
  final bool reduced;
  final double Function() now;
  final dynamic c;
  final List categories;
  final List recent;
  final int plays;
  final void Function(String text) meta;
  final void Function(String text) status;
  final void Function(String text, bool win) finish;
  final void Function() cheer;

  /// The main button in the footer ("Next"), gone once pressed.
  final void Function(String label, void Function() fn) action;

  /// A pending step, held while paused.
  final void Function(void Function() fn, int ms) later;

  /// A timer that a pause drops (the reflex test's wait for green).
  final Object Function(void Function() fn, int ms) timer;
  final void Function(Object t) clear;
}

abstract class _Game {
  void input(GameInput a);
  Board board();
  void pause() {}
}

// ------------------------------------------------------------------ games

String _handLower(String h) => handName[h]!.toLowerCase();

class _Rps extends _Game {
  _Rps(this.ctx) {
    _show();
    ctx.status('First to two wins. Pick your hand!');
  }

  final _Ctx ctx;
  int _you = 0;
  int _bot = 0;
  String _youFace = handEmoji['rock']!;
  String _botFace = handEmoji['rock']!;
  String? _outcome;
  bool _shaking = false;
  bool _busy = false;

  void _show() => ctx.meta('You $_you · $_bot Bot');

  @override
  Board board() => RpsBoard(
        you: _youFace,
        bot: _botFace,
        outcome: _outcome,
        shaking: _shaking,
        busy: _busy,
        hands: [for (final h in hands) RpsHand(h, handEmoji[h]!, handName[h]!)],
      );

  @override
  void input(GameInput a) {
    if (a is! RpsInput || _busy) return;
    final mine = a.hand;
    if (!hands.contains(mine)) return;
    final theirs = hands[(ctx.rng() * 3).floor()];
    _busy = true;
    _youFace = handEmoji['rock']!;
    _botFace = handEmoji['rock']!;
    _outcome = null;
    void reveal() {
      _shaking = false;
      _youFace = handEmoji[mine]!;
      _botFace = handEmoji[theirs]!;
      final r = rpsOutcome(mine, theirs);
      _outcome = r;
      if (r == 'win') _you += 1;
      if (r == 'lose') _bot += 1;
      _show();
      final line = r == 'draw'
          ? '${handName[mine]} and ${_handLower(theirs)} - a draw!'
          : r == 'win'
              ? '${handName[mine]} beats ${_handLower(theirs)} - point to you!'
              : '${handName[theirs]} beats ${_handLower(mine)} - point to the bot.';
      final w = rpsWinner(you: _you, bot: _bot);
      if (w != null) {
        ctx.finish(
          w == 'you' ? '$line You win $_you-$_bot! 🎉' : '$line The bot takes it $_bot-$_you. Rematch? 🤖',
          w == 'you',
        );
        return;
      }
      ctx.status(line);
      _busy = false;
    }

    if (ctx.reduced) {
      reveal();
    } else {
      _shaking = true;
      ctx.status('Rock... paper... scissors...');
      ctx.later(reveal, 900);
    }
  }
}

class _Ttt extends _Game {
  _Ttt(this.ctx) {
    ctx.meta('You ✕ · Bot ◯');
    // Turns alternate between games: the bot opens every second one.
    if (ctx.plays % 2 == 1) {
      _botTurn();
    } else {
      ctx.status('You go first - tap a square');
    }
  }

  final _Ctx ctx;
  final List<Cell> _cells = List<Cell>.filled(9, null);
  bool _over = false;
  bool _busy = false;
  List<int> _line = const [];

  bool _check() {
    final w = tttWinner(_cells);
    if (w == null) return false;
    _over = true;
    _line = w.line;
    if (w.winner == 'X') {
      ctx.finish('Three in a row - you beat the bot! 🎉', true);
    } else if (w.winner == 'O') {
      ctx.finish('The bot got this one. Rematch? 🤖', false);
    } else {
      ctx.finish('A draw - great minds think alike 🤝', false);
    }
    return true;
  }

  void _botTurn() {
    _busy = true;
    ctx.status('The bot is thinking...');
    ctx.later(() {
      final m = tttBotMove(_cells, ctx.rng);
      if (m >= 0) _cells[m] = 'O';
      _busy = false;
      if (!_check()) ctx.status('Your move');
    }, ctx.reduced ? 250 : 550);
  }

  @override
  Board board() => TttBoard(cells: List.of(_cells), line: List.of(_line), over: _over, thinking: _busy);

  @override
  void input(GameInput a) {
    if (a is! TttInput || _over || _busy) return;
    if (a.i < 0 || a.i > 8 || _cells[a.i] != null) return;
    _cells[a.i] = 'X';
    if (!_check()) _botTurn();
  }
}

class _Memory extends _Game {
  _Memory(this.ctx) : _s = MemoryState(cards: memoryDeck(memoryFaces, 6, ctx.rng)) {
    _paint();
    ctx.status('Find all six pairs');
  }

  final _Ctx ctx;
  MemoryState _s;
  bool _waiting = false;
  List<int> _pop = const [];

  void _paint() {
    final pairs = _s.cards.where((c) => c.matched).length ~/ 2;
    ctx.meta('Moves ${_s.moves} · Pairs $pairs/6');
  }

  @override
  Board board() => MemoryBoard(
        cards: [
          for (var i = 0; i < _s.cards.length; i++)
            MemoryFace(face: _s.cards[i].face, up: _s.cards[i].matched || _s.open.contains(i), matched: _s.cards[i].matched),
        ],
        pop: List.of(_pop),
      );

  @override
  void input(GameInput a) {
    if (a is! MemoryInput || _waiting) return;
    final r = memoryFlip(_s, a.i);
    if (r.result == 'ignored') return;
    _s = r.state;
    _pop = const [];
    _paint();
    if (r.result == 'match') {
      ctx.status('A pair! ✨');
      // The pair just made (the card tapped and its twin).
      final face = _s.cards[a.i].face;
      _pop = [
        for (var i = 0; i < _s.cards.length; i++)
          if (_s.cards[i].face == face) i,
      ];
    } else if (r.result == 'miss') {
      ctx.status('Not a pair');
      _waiting = true;
      ctx.later(() {
        _s = memoryHide(_s);
        _waiting = false;
        _paint();
      }, 850);
    } else if (r.result == 'done') {
      ctx.finish('All pairs in ${_s.moves} moves! ${'⭐' * memoryStars(_s.moves)}', true);
    }
  }
}

class _Round {
  const _Round({required this.q, this.big, this.tag, required this.options, required this.answer});
  final String q;
  final String? big;
  final String? tag;
  final List<String> options;
  final int answer;
}

const _right = ['Correct! 🎯', 'Spot on! ✨', 'Nailed it! 🙌', 'Yes! 🎉'];
String _pickLine(List<String> xs, Rng rng) => xs[(rng() * xs.length).floor() % xs.length];

/// Shared by the quiz and the emoji riddles: a round at a time, three in all.
class _ChoiceRounds extends _Game {
  _ChoiceRounds(this.ctx, this.game, this.rounds, this.summary) {
    _showRound();
  }

  final _Ctx ctx;
  final String game;
  final List<_Round> rounds;
  final ({String text, bool win}) Function(int score, int total) summary;
  int _at = 0;
  int _score = 0;
  int? _picked;
  int _shown = 0;

  void _meta() => ctx.meta('${_shown + 1} of ${rounds.length} · $_score right');

  void _showRound() {
    _shown = _at;
    _picked = null;
    _meta();
  }

  @override
  Board board() {
    final r = rounds[_shown];
    return ChoiceBoard(game: game, tag: r.tag, big: r.big, q: r.q, options: List.of(r.options), answer: r.answer, picked: _picked);
  }

  @override
  void input(GameInput a) {
    if (a is! ChoiceInput || _picked != null) return;
    final r = rounds[_shown];
    if (a.i < 0 || a.i >= r.options.length) return;
    _picked = a.i;
    final right = a.i == r.answer;
    if (right) _score += 1;
    _meta();
    if (right) ctx.cheer();
    final fb = right ? _pickLine(_right, ctx.rng) : "Not quite - it's ${r.options[r.answer]}";
    _at += 1;
    if (_at >= rounds.length) {
      final s = summary(_score, rounds.length);
      ctx.finish('$fb. ${s.text}', s.win);
      return;
    }
    ctx.status(fb);
    ctx.action(_at == rounds.length - 1 ? 'Last one →' : 'Next →', _showRound);
  }
}

_Game _quiz(_Ctx ctx) {
  final kb = ctx.c is Map && ctx.c['enableKnowledgeBase'] == true
      ? quizFromArticles(ctx.categories, ctx.recent, ctx.rng)
      : <QuizQuestion>[];
  final qs = buildQuiz(trivia, kb, ctx.rng);
  ctx.status(kb.isNotEmpty ? 'Three questions - some about our help centre' : 'Three quick questions');
  return _ChoiceRounds(
    ctx,
    'quiz',
    [
      for (final q in qs)
        _Round(q: q.q, options: q.options, answer: q.answer, tag: q.source == 'kb' ? 'From our help centre' : null),
    ],
    (score, total) => (text: '$score out of $total. ${quizVerdict(score, total)}', win: score == total),
  );
}

_Game _emoji(_Ctx ctx) {
  final picked = shuffle(riddles, ctx.rng).take(3).toList();
  ctx.status('What phrase do the emoji spell?');
  return _ChoiceRounds(
    ctx,
    'emoji',
    [
      for (final r in picked)
        () {
          final o = riddleOptions(r, ctx.rng);
          return _Round(big: r.e, q: "What's the phrase?", options: o.options, answer: o.answer);
        }(),
    ],
    (score, total) => (text: '$score of $total riddles solved. ${quizVerdict(score, total)}', win: score == total),
  );
}

const reactionRounds = 3;

class _Reaction extends _Game {
  _Reaction(this.ctx) {
    ctx.meta('Round 1 of $reactionRounds');
    ctx.status('When the pad turns green, tap as fast as you can');
  }

  final _Ctx ctx;
  final List<int> _times = [];
  String _state = 'idle';
  String _big = '⚡';
  String _line = 'Tap to start';
  double _goAt = 0;
  Object? _timer;

  void _set(String s, String e, String text) {
    _state = s;
    _big = e;
    _line = text;
  }

  void _start() {
    _set('wait', '👀', 'Wait for green...');
    ctx.meta('Round ${_times.length + 1} of $reactionRounds');
    _timer = ctx.timer(() {
      _timer = null;
      _goAt = ctx.now();
      _set('go', '🟢', 'Tap now!');
    }, reactionDelay(ctx.rng));
  }

  @override
  Board board() => ReactionBoard(state: _state, big: _big, line: _line);

  // On press, not on release, so the time is the visitor's.
  @override
  void input(GameInput a) {
    if (a is! ReactionInput) return;
    if (_state == 'idle' || _state == 'between') {
      _start();
    } else if (_state == 'wait') {
      final t = _timer;
      if (t != null) ctx.clear(t);
      _timer = null;
      _set('between', '🙈', 'Too soon! Tap to try again');
      ctx.status('Too soon - wait for green');
    } else if (_state == 'go') {
      final ms = jsRound(ctx.now() - _goAt);
      if (!reactionCounts(ms)) {
        _set('between', '🙈', 'A lucky guess! Tap to try again');
        ctx.status('Too quick to be real - wait until you see green');
        return;
      }
      _times.add(ms);
      if (_times.length >= reactionRounds) {
        final avg = average(_times);
        _set('done', '🏁', '$avg ms average');
        ctx.meta('${_times.join(' · ')} ms');
        ctx.finish('${reactionVerdict(avg)} - $avg ms on average.', avg < 350);
        return;
      }
      _set('between', '⏱️', '$ms ms - tap for the next round');
      ctx.status('$ms milliseconds');
    }
  }

  @override
  void pause() {
    final t = _timer;
    if (t != null) ctx.clear(t);
    _timer = null;
    if (_state == 'wait' || _state == 'go') _set('between', '⏸️', 'Tap to carry on');
  }
}

const scrambleRounds = 3;

class _Scramble extends _Game {
  _Scramble(this.ctx) : _words = shuffle(words, ctx.rng).take(scrambleRounds).toList() {
    // The web's intro says "or just type": a phone has no keys to type on.
    ctx.status('Tap the letters in order');
    _round();
  }

  final _Ctx ctx;
  final List<Word> _words;
  int _at = 0;
  int _solvedCount = 0;
  List<String> _letters = const [];
  List<int> _placed = [];
  bool _isSolved = false;
  bool _revealed = false;
  int _nope = 0;
  String _word = '';
  String _hint = '';

  void _round() {
    _word = _words[_at].w;
    _hint = _words[_at].hint;
    _letters = scrambleWord(_word, ctx.rng);
    _placed = [];
    _isSolved = false;
    _revealed = false;
    ctx.meta('Word ${_at + 1} of $scrambleRounds · $_solvedCount solved');
  }

  void _next(String msg, bool win) {
    _at += 1;
    if (win) _solvedCount += 1;
    ctx.meta('Word ${(_at + 1).clamp(0, scrambleRounds)} of $scrambleRounds · $_solvedCount solved');
    if (_at >= scrambleRounds) {
      final verdict = _solvedCount == scrambleRounds
          ? 'Word wizard! 🧙'
          : _solvedCount > 0
              ? Verdict.nice
              : 'Tricky ones! 🙈';
      ctx.finish('$msg You solved $_solvedCount of $scrambleRounds. $verdict', _solvedCount == scrambleRounds);
      return;
    }
    ctx.status(msg);
    ctx.later(_round, win ? 1100 : 1500);
  }

  void _check() {
    if (_placed.length < _letters.length) return;
    final guess = _placed.map((i) => _letters[i]).join();
    if (scrambleSolved(guess, _word)) {
      _isSolved = true;
      ctx.cheer();
      _next('$_word - got it! 🎉', true);
    } else {
      _nope += 1;
      ctx.status('Not quite - tap letters to take them back');
    }
  }

  void _put(int i) {
    if (i < 0 || i >= _letters.length || _placed.contains(i) || _placed.length >= _letters.length || _isSolved) return;
    _placed.add(i);
    _check();
  }

  @override
  Board board() => ScrambleBoard(
        hint: _hint,
        letters: List.of(_letters),
        placed: List.of(_placed),
        solved: _isSolved,
        revealed: _revealed,
        nope: _nope,
        skipLabel: _at == scrambleRounds - 1 ? 'Reveal' : 'Skip',
      );

  @override
  void input(GameInput a) {
    if (a is TileInput) {
      _put(a.i);
    } else if (a is SlotInput) {
      if (_isSolved || a.i < 0 || a.i >= _placed.length) return;
      _placed.removeRange(a.i, _placed.length);
    } else if (a is KeyInput) {
      if (_isSolved) return;
      if (a.key == 'Backspace') {
        if (_placed.isNotEmpty) _placed.removeLast();
        return;
      }
      if (!RegExp(r'^[a-z]$', caseSensitive: false).hasMatch(a.key)) return;
      final up = a.key.toUpperCase();
      var i = -1;
      for (var j = 0; j < _letters.length; j++) {
        if (_letters[j] == up && !_placed.contains(j)) {
          i = j;
          break;
        }
      }
      if (i >= 0) _put(i);
    } else if (a is SkipInput) {
      if (_isSolved) return;
      _isSolved = true;
      _revealed = true;
      _placed = [];
      for (final l in _word.split('')) {
        var at = -1;
        for (var j = 0; j < _letters.length; j++) {
          if (_letters[j] == l && !_placed.contains(j)) {
            at = j;
            break;
          }
        }
        _placed.add(at);
      }
      _next('It was $_word.', false);
    }
  }
}

final Map<String, _Game Function(_Ctx ctx)> _factories = {
  GameIds.rps: _Rps.new,
  GameIds.ttt: _Ttt.new,
  GameIds.quiz: _quiz,
  GameIds.memory: _Memory.new,
  GameIds.reaction: _Reaction.new,
  GameIds.emoji: _emoji,
  GameIds.scramble: _Scramble.new,
};

// ------------------------------------------------------------------ the card

class _Entry {
  _Entry(this.id);
  final String id;
  late _Game game;
  final Set<Object> timers = {};
  final Map<Object, void Function()> queued = {};
  bool over = false;
}

Object _setTimer(void Function() fn, Duration after) => Timer(after, fn);
void _clearTimer(Object t) => (t as Timer).cancel();

final Stopwatch _clock = Stopwatch()..start();
double _now() => _clock.elapsedMicroseconds / 1000;

/// One card (web mountGamesCard). [create] gives null when the owner left
/// no game for this language. Starts on the menu: with the owner's offer
/// line for an offer, "Pick a game" when the visitor asked.
class GamesCard implements OfferCard {
  GamesCard._(this._o, this._settings, List<GameMeta> available)
      : _rng = _o.rng ?? defaultRng,
        _set = _o.setTimer ?? _setTimer,
        _clear = _o.clearTimer ?? _clearTimer,
        _nowFn = _o.now ?? _now,
        _state = GamesCardState(view: 'menu', chips: available) {
    _showMenu(true);
  }

  /// The card, or null when the owner's games leave none for this language.
  static GamesCard? create(GamesCardOptions o) {
    final settings = waitingGamesOf(o.customizations);
    final available = gamesForLanguage(gamesCatalogue.where((g) => settings.games.contains(g.id)), o.lang);
    if (available.isEmpty) return null;
    return GamesCard._(o, settings, available);
  }

  final GamesCardOptions _o;
  final WaitingGamesSettings _settings;
  final Rng _rng;
  final SetTimer _set;
  final ClearTimer _clear;
  final double Function() _nowFn;
  final Set<void Function(GamesCardState s)> _listeners = {};

  GamesCardState _state;
  _Entry? _current;
  int _plays = 0;
  void Function()? _action;
  List<void Function()> _held = [];

  /// The card as it stands.
  GamesCardState get state => _state;

  /// Listen to every change; call the returned function to stop.
  void Function() subscribe(void Function(GamesCardState s) fn) {
    _listeners.add(fn);
    return () => _listeners.remove(fn);
  }

  void _emit() {
    final cur = _current;
    if (cur != null) _state = _state.copyWith(board: cur.game.board());
    final snap = _state;
    for (final fn in List.of(_listeners)) {
      try {
        fn(snap);
      } catch (_) {
        // A listener's error is its own.
      }
    }
  }

  void _stopTimers() {
    final cur = _current;
    if (cur == null) return;
    for (final t in cur.timers) {
      _clear(t);
    }
  }

  static const _quietAnother = FootButton(key: 'another', label: GamesText.another, primary: false);

  void _showMenu(bool first) {
    _stopTimers();
    _current = null;
    _action = null;
    _state = _state.copyWith(
      view: 'menu',
      settled: false,
      closable: true,
      game: null,
      board: null,
      titleEmoji: '',
      title: first && _o.mode != 'menu' ? _settings.offerText : GamesText.pick,
      meta: '',
      status: '',
      result: null,
      foot: const [FootButton(key: 'notNow', label: GamesText.notNow, primary: false)],
    );
  }

  void _open(String id) {
    final g = gameMeta(id);
    if (g == null || !_settings.games.contains(id) || _state.view == 'gone') return;
    _stopTimers();
    _action = null;
    _state = _state.copyWith(
      view: 'game',
      game: id,
      titleEmoji: g.emoji,
      title: g.name,
      meta: '',
      status: '',
      result: null,
      settled: false,
      closable: true,
      foot: const [_quietAnother],
    );
    final entry = _Entry(id);
    bool live() => identical(_current, entry);
    final ctx = _Ctx(
      rng: _rng,
      reduced: _o.reducedMotion,
      now: _nowFn,
      c: _o.customizations,
      categories: _o.categories,
      recent: _o.recentArticles,
      plays: _plays,
      meta: (t) => _state = _state.copyWith(meta: t),
      status: (t) => _state = _state.copyWith(status: t),
      action: (label, fn) {
        _action = fn;
        _state = _state.copyWith(foot: [
          ..._state.foot.where((b) => b.key != 'action'),
          FootButton(key: 'action', label: label, primary: true),
        ]);
      },
      cheer: () {
        if (!_o.reducedMotion) _state = _state.copyWith(cheer: _state.cheer + 1);
      },
      finish: (text, win) {
        entry.over = true;
        _action = null;
        _state = _state.copyWith(
          result: win ? 'win' : 'done',
          status: text,
          confetti: win && !_o.reducedMotion ? _state.confetti + 1 : _state.confetti,
          foot: const [
            FootButton(key: 'again', label: GamesText.again, primary: true),
            FootButton(key: 'another', label: GamesText.another, primary: false),
          ],
        );
      },
      later: (fn, ms) {
        late final Object t;
        t = _set(() {
          entry.timers.remove(t);
          entry.queued.remove(t);
          if (!live()) return;
          fn();
          _emit();
        }, Duration(milliseconds: ms));
        entry.timers.add(t);
        entry.queued[t] = fn;
      },
      timer: (fn, ms) {
        late final Object t;
        t = _set(() {
          entry.timers.remove(t);
          if (!live()) return;
          fn();
          _emit();
        }, Duration(milliseconds: ms));
        entry.timers.add(t);
        return t;
      },
      clear: (t) {
        _clear(t);
        entry.timers.remove(t);
      },
    );
    _plays += 1;
    _current = entry;
    entry.game = _factories[id]!(ctx);
  }

  void _remove() {
    _stopTimers();
    _current = null;
    _action = null;
    _state = _state.copyWith(view: 'gone', board: null, foot: const []);
  }

  /// A game from the menu.
  void open(String id) {
    _open(id);
    _emit();
  }

  /// Back to the menu ("play" typed while the card is up).
  @override
  void menu() {
    if (_state.view == 'gone') return;
    _showMenu(false);
    _emit();
  }

  /// A footer button.
  void press(String key) {
    if (!_state.foot.any((b) => b.key == key)) return;
    if (key == 'notNow') {
      dismiss();
      return;
    }
    final cur = _current;
    if (key == 'again' && cur != null) {
      _open(cur.id);
    } else if (key == 'another') {
      _showMenu(false);
    } else if (key == 'resume') {
      _resume();
    } else if (key == 'action' && _action != null) {
      final fn = _action!;
      _action = null;
      _state = _state.copyWith(foot: _state.foot.where((b) => b.key != 'action').toList());
      fn();
    }
    _emit();
  }

  /// A tap inside the game.
  void input(GameInput a) {
    final cur = _current;
    if (_state.view != 'game' || cur == null || cur.over) return;
    cur.game.input(a);
    _emit();
  }

  /// The x.
  void dismiss() {
    if (_state.view == 'gone') return;
    _remove();
    _emit();
    _o.onDismiss?.call();
  }

  /// A teammate joined: a game under way pauses ("Finish my game"), a
  /// finished one stays as its result, the menu leaves.
  @override
  void wrapUp([String? name]) {
    if (_state.view == 'paused' || _state.view == 'gone') return;
    final cur = _current;
    if (cur == null) {
      // Only the offer or the menu: nothing to keep.
      _remove();
      _emit();
      return;
    }
    if (cur.over) {
      // A finished game stays as a result, without its buttons.
      _state = _state.copyWith(foot: const [], settled: true, closable: false);
      _emit();
      return;
    }
    cur.game.pause();
    // Hold the game's pending steps for "Finish my game": dropped, the board would stay locked.
    _held = cur.queued.values.toList();
    _stopTimers();
    cur.timers.clear();
    cur.queued.clear();
    _action = null;
    var who = (name ?? '').trim();
    if (who.length > 40) who = who.substring(0, 40);
    _state = _state.copyWith(
      view: 'paused',
      titleEmoji: '👋',
      title: who.isNotEmpty ? GamesText.pausedNamed(who) : GamesText.pausedSomeone,
      status: GamesText.pausedSaved,
      foot: const [FootButton(key: 'resume', label: GamesText.resume, primary: false)],
    );
    _emit();
  }

  void _resume() {
    final cur = _current;
    if (cur == null || _state.view != 'paused') return;
    final g = gameMeta(cur.id);
    _state = _state.copyWith(view: 'game', titleEmoji: g?.emoji ?? '', title: g?.name ?? '', status: '', foot: const []);
    final run = _held;
    _held = [];
    for (final fn in run) {
      fn();
    }
  }

  @override
  void remove() {
    if (_state.view == 'gone') return;
    _remove();
    _emit();
  }

  /// A game is under way (not the menu, not a finished one).
  @override
  bool get playing => _state.view == 'game' && _current != null && !_current!.over;

  @override
  bool get up => _state.view != 'gone';
}

class GamesCardOptions {
  const GamesCardOptions({
    required this.customizations,
    this.categories = const [],
    this.recentArticles = const [],
    this.mode = 'offer',
    this.rng,
    this.reducedMotion = false,
    this.lang = 'en',
    this.onDismiss,
    this.setTimer,
    this.clearTimer,
    this.now,
  });

  final dynamic customizations;
  final List categories;
  final List recentArticles;

  /// "offer": the owner's line; "menu": the visitor asked for the games.
  final String mode;
  final Rng? rng;
  final bool reducedMotion;

  /// The language the games are offered in (the emoji riddles are English only).
  final String lang;

  /// The card was closed ("Not now", the x).
  final void Function()? onDismiss;
  final SetTimer? setTimer;
  final ClearTimer? clearTimer;

  /// A clock in milliseconds, for the reflex test.
  final double Function()? now;
}
