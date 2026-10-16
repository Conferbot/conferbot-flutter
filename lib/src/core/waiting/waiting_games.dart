/// Waiting games: the owner's settings, the catalogue, and when the offer is
/// made and when it steps aside. Ported from the React Native SDK
/// (src/core/waitingGames.ts), itself from the web widget:
/// conferbot-widget src/ts/chat/games/settings.ts (waitingGamesOf, GAMES,
/// PLAY_RE) and src/ts/chat/games/wire.ts (OFFER_DELAY_MS, the offer's
/// retries, "Not now", the typed "play"), with nodeKit.ts pickAccent for the
/// card's accent. Pure: the card itself is core/waiting/games_card.dart, and
/// the provider (core/waiting/waiting_extras.dart) feeds the signals in.
///
///   waitingGames: { enabled: boolean, games: string[], offerText: string }
///
/// Unset means on with every game: the offer only ever appears while a
/// visitor is waiting for a person (cb:waiting-for-human), never starts a
/// game by itself, and goes away the moment a teammate joins.
///
///   cb:waiting-for-human  after [offerDelay], one offer card per wait.
///   cb:human-joined       a game in progress is saved and folded away
///                         (wrapUp), an unused offer leaves.
///   cb:wait-over          no offer any more; an unused card leaves, a game
///                         being played stays to finish.
///
/// While waiting, a visitor who types "play" or "games" gets the menu instead
/// of sending it. "Not now" (or the x) means no more offers for this app
/// session (the web: this page view). Nothing is stored or sent.
library;

import 'dart:async';
import 'dart:math' as math;

import '../i18n/i18n.dart' show t;
import '../live_chat/handover_waiting.dart' show SetTimer, ClearTimer;

/// The games' ids: rps, ttt, quiz, memory, reaction, emoji, scramble.
class GameIds {
  GameIds._();
  static const rps = 'rps';
  static const ttt = 'ttt';
  static const quiz = 'quiz';
  static const memory = 'memory';
  static const reaction = 'reaction';
  static const emoji = 'emoji';
  static const scramble = 'scramble';
}

class GameMeta {
  const GameMeta({required this.id, required this.emoji});

  final String id;
  final String emoji;

  /// The name in the active language (web ui.ts gameName, games.<id>.name).
  String get name => t('games.$id.name');

  /// One line for the menu, in the active language (games.<id>.blurb).
  String get blurb => t('games.$id.blurb');

  @override
  String toString() => 'GameMeta($id)';
}

const List<GameMeta> gamesCatalogue = [
  GameMeta(id: 'rps', emoji: '✊'),
  GameMeta(id: 'ttt', emoji: '⭕'),
  GameMeta(id: 'quiz', emoji: '🧠'),
  GameMeta(id: 'memory', emoji: '🃏'),
  GameMeta(id: 'reaction', emoji: '⚡'),
  GameMeta(id: 'emoji', emoji: '🤔'),
  GameMeta(id: 'scramble', emoji: '🔤'),
];

final List<String> gameIds = List.unmodifiable(gamesCatalogue.map((g) => g.id));

GameMeta? gameMeta(String id) => gamesCatalogue.where((g) => g.id == id).firstOrNull;

/// The stock offer as stored (English); drawn as [offerLine] (web ui.ts: the stock line is t("games.offer")).
const defaultOfferText = 'While you wait - fancy a quick game? 🎮';

/// The offer as drawn: the stock line in the active language, the owner's own as written.
String offerLine(String offerText) => offerText == defaultOfferText ? t('games.offer') : offerText;
const offerTextMax = 140;

/// The games that work in a language: the emoji riddles are English
/// wordplay ("Bookworm", "Hot dog"), so they are offered in English only.
List<GameMeta> gamesForLanguage(Iterable<GameMeta> list, String lang) =>
    list.where((g) => g.id != GameIds.emoji || lang == 'en').toList();

class WaitingGamesSettings {
  const WaitingGamesSettings({required this.enabled, required this.games, required this.offerText});

  final bool enabled;
  final List<String> games;
  final String offerText;
}

/// The settings as the widget uses them, from whatever was stored.
WaitingGamesSettings waitingGamesOf(dynamic c) {
  final raw = c is Map ? c['waitingGames'] : null;
  final w = raw is Map ? raw : const {};
  final List<String> list;
  if (w['games'] is List) {
    final all = w['games'] as List;
    list = [
      for (var i = 0; i < all.length; i++)
        if (all[i] is String && gameIds.contains(all[i]) && all.indexOf(all[i]) == i) all[i] as String,
    ];
  } else {
    list = [...gameIds];
  }
  var text = '';
  if (w['offerText'] is String) {
    text = (w['offerText'] as String).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > offerTextMax) text = text.substring(0, offerTextMax);
  }
  return WaitingGamesSettings(
    enabled: w['enabled'] != false && list.isNotEmpty,
    games: list,
    offerText: text.isNotEmpty ? text : defaultOfferText,
  );
}

/// Typed while waiting, these open the games menu: "play", "games", "let's play", "play a game".
final playRe = RegExp(
  r"^\s*(?:let'?s\s+)?(?:play(?:\s+a)?(?:\s+game)?|games?|i\s+want\s+to\s+play)\s*[!.?]*\s*$",
  caseSensitive: false,
);

// ------------------------------------------------------------ the accent

List<int>? _hexToRgb(dynamic hex) {
  final m = RegExp(r'^#?([0-9a-f]{3}|[0-9a-f]{6})$', caseSensitive: false).firstMatch((hex ?? '').toString().trim());
  if (m == null) return null;
  var h = m.group(1)!;
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  final n = int.parse(h, radix: 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

/// Relative luminance (0 black .. 1 white), or null for non-hex input (web nodeKit.ts).
double? luminance(dynamic hex) {
  final rgb = _hexToRgb(hex);
  if (rgb == null) return null;
  final c = rgb.map((v) {
    final x = v / 255;
    return x <= 0.03928 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
  }).toList();
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

/// The card's accent (web nodeKit.ts pickAccent): the header colour unless
/// it is too pale to carry white text, then the bot bubble's, the visitor
/// bubble's, the choice text's, then Conferbot blue.
String pickAccent(dynamic c) {
  final m = c is Map ? c : const {};
  for (final v in [m['headerBgColor'], m['botMsgColor'], m['userMsgColor'], m['optionBubbleTextColor']]) {
    final l = luminance(v);
    if (l != null && l < 0.5) return v.toString();
  }
  return '#0808EE';
}

// ------------------------------------------------------------ the offer

/// The offer card comes this long after the waiting signal.
const offerDelay = Duration(milliseconds: 2500);

/// A card that could not be drawn is tried again this often, [offerRetries] times.
const offerRetry = Duration(milliseconds: 1500);
const offerRetries = 3;

/// What the offer needs of the card on screen (core/waiting/games_card.dart).
abstract class OfferCard {
  /// Still on screen.
  bool get up;

  /// A game is under way.
  bool get playing;

  /// Back to the menu.
  void menu();

  void remove();

  /// A teammate joined: save a game in progress, or step aside.
  void wrapUp([String? name]);
}

Object _setTimer(void Function() fn, Duration after) => Timer(after, fn);
void _clearTimer(Object t) => (t as Timer).cancel();

/// The offer's rules (web wire.ts wireWaitingGames). Feed it the signals:
/// waiting() on cb:waiting-for-human, joined(name) on cb:human-joined,
/// waitOver() on cb:wait-over; play(text) before sending the visitor's
/// words; dismissed() when the card's "Not now" or x closes it.
class GamesOffer {
  GamesOffer({
    required bool Function() enabled,
    required OfferCard? Function(String mode) mount,
    SetTimer? setTimer,
    ClearTimer? clearTimer,
  })  : _enabled = enabled,
        _mount = mount,
        _set = setTimer ?? _setTimer,
        _clear = clearTimer ?? _clearTimer;

  /// The owner's waitingGames allow it now.
  final bool Function() _enabled;

  /// Draw a new card ("offer": the owner's line; "menu": the visitor asked). Null when it cannot.
  final OfferCard? Function(String mode) _mount;
  final SetTimer _set;
  final ClearTimer _clear;

  bool _waiting = false;
  bool _offered = false;
  bool _dismissed = false;
  OfferCard? _card;
  Object? _timer;

  bool get isWaiting => _waiting;

  void _cancel() {
    final t = _timer;
    if (t != null) _clear(t);
    _timer = null;
  }

  bool _show(String mode) {
    if (!_enabled()) return false;
    final card = _card;
    if (card != null && card.up && mode == 'menu') {
      // Mid-game, "play" brings the game back into view instead.
      if (!card.playing) card.menu();
      return true;
    }
    _card = _mount(mode);
    return _card != null;
  }

  /// cb:waiting-for-human: after [offerDelay], one offer per wait.
  void waiting() {
    if (_waiting) return;
    _waiting = true;
    _offered = false;
    _cancel();
    // The chat may still be drawing: a few more tries before giving up.
    void attempt(int left) {
      _timer = _set(() {
        _timer = null;
        if (!_waiting || _offered || _dismissed) return;
        final card = _card;
        if (card != null && card.up) return;
        _offered = _show('offer');
        if (!_offered && left > 0) attempt(left - 1);
      }, left == offerRetries ? offerDelay : offerRetry);
    }

    attempt(offerRetries);
  }

  /// cb:wait-over: no more offers; an unused card leaves, a game being played stays.
  void waitOver() {
    _waiting = false;
    _cancel();
    final card = _card;
    if (card != null && card.up && !card.playing) {
      card.remove();
      _card = null;
    }
  }

  /// cb:human-joined: a game in progress is saved and folded away, an unused card leaves.
  void joined([dynamic name]) {
    _waiting = false;
    _cancel();
    final card = _card;
    if (card != null && card.up) card.wrapUp(name is String ? name : '');
  }

  /// The visitor's words while waiting: "play" opens the menu instead of
  /// being sent. True when it did (do not send them).
  bool play(String text) {
    if (!_waiting || !playRe.hasMatch(text)) return false;
    if (!_show('menu')) return false;
    _dismissed = false;
    return true;
  }

  /// The card's "Not now" or x: no more offers for this session.
  void dismissed() {
    _dismissed = true;
    _card = null;
  }

  /// A new conversation: the wait is gone ("Not now" still holds, as on the web's page view).
  void reset() {
    _cancel();
    _waiting = false;
    _offered = false;
    _card = null;
  }
}
