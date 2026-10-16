// The waiting games' settings and the offer's timing
// (lib/src/core/waiting/waiting_games.dart): the cases of the RN SDK's
// __tests__/core/waitingGames.test.ts (web games/settings.ts and
// games/wire.ts), on a fake clock.
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
        ..sort((a, b) => a.value.at.compareTo(b.value.at));
      if (due.isEmpty) break;
      timers.remove(due.first.key);
      now = due.first.value.at;
      due.first.value.fn();
    }
    now = until;
  }
}

class _FakeCard implements OfferCard {
  bool on = true;
  bool game = false;
  int menus = 0;
  int removed = 0;
  final List<String> wrapped = [];

  @override
  bool get up => on;
  @override
  bool get playing => game;
  @override
  void menu() => menus++;
  @override
  void remove() {
    on = false;
    removed++;
  }

  @override
  void wrapUp([String? name]) => wrapped.add(name ?? '');
}

class _Setup {
  _Setup({bool enabled = true, int failFirst = 0}) : _fails = failFirst {
    offer = GamesOffer(
      enabled: () => enabled,
      mount: (mode) {
        mounts.add(mode);
        if (_fails > 0) {
          _fails--;
          return null;
        }
        last = _FakeCard();
        return last;
      },
      setTimer: k.set,
      clearTimer: k.clear,
    );
  }

  final k = _Clock();
  final List<String> mounts = [];
  _FakeCard last = _FakeCard();
  int _fails;
  late final GamesOffer offer;
}

final _delay = offerDelay.inMilliseconds;
final _retry = offerRetry.inMilliseconds;

void main() {
  group('waitingGamesOf (web settings.ts)', () {
    test('unset is on with every game and the default line', () {
      final s = waitingGamesOf({});
      expect(s.enabled, isTrue);
      expect(s.games, [...gameIds]);
      expect(s.offerText, defaultOfferText);
      expect(gameIds, hasLength(7));
    });

    test('off, a subset, unknown games dropped, no games is off, the line cleaned', () {
      expect(waitingGamesOf({'waitingGames': {'enabled': false}}).enabled, isFalse);
      expect(
          waitingGamesOf({
            'waitingGames': {
              'games': ['ttt', 'nope', 'ttt', 'rps']
            }
          }).games,
          ['ttt', 'rps']);
      expect(waitingGamesOf({'waitingGames': {'games': []}}).enabled, isFalse);
      expect(waitingGamesOf({'waitingGames': {'offerText': '  Bored?   Play!  '}}).offerText, 'Bored? Play!');
      expect(waitingGamesOf({'waitingGames': {'offerText': 'x' * 300}}).offerText, hasLength(offerTextMax));
    });

    test('the emoji riddles only in English', () {
      expect(gamesForLanguage(gamesCatalogue, 'en').map((g) => g.id), contains('emoji'));
      expect(gamesForLanguage(gamesCatalogue, 'de').map((g) => g.id), isNot(contains('emoji')));
    });

    test('typing play or games opens the menu, a real message does not', () {
      for (final t in ['play', 'Play!', 'games', 'game', "let's play", 'lets play', 'play a game', 'I want to play']) {
        expect(playRe.hasMatch(t), isTrue, reason: t);
      }
      for (final t in ['how do I play the video', 'my game crashed', 'playlist', '']) {
        expect(playRe.hasMatch(t), isFalse, reason: t);
      }
    });

    test('the accent: the header colour unless too pale, then the bot bubble, then Conferbot blue', () {
      expect(pickAccent({'headerBgColor': '#123456'}), '#123456');
      expect(pickAccent({'headerBgColor': '#ffe4ec', 'botMsgColor': '#e65100'}), '#e65100');
      expect(pickAccent({'headerBgColor': '#ffffff', 'botMsgColor': 'red'}), '#0808EE');
      expect(pickAccent(null), '#0808EE');
    });
  });

  group('GamesOffer (web wire.ts)', () {
    test('offers once, offerDelay after the waiting signal', () {
      final s = _Setup();
      s.offer.waiting();
      s.k.tick(_delay - 1);
      expect(s.mounts, isEmpty);
      s.k.tick(1);
      expect(s.mounts, ['offer']);
      // A second signal in the same wait changes nothing.
      s.offer.waiting();
      s.k.tick(10000);
      expect(s.mounts, ['offer']);
    });

    test('a card that could not be drawn is tried three more times, 1.5s apart', () {
      final s = _Setup(failFirst: 10);
      s.offer.waiting();
      s.k.tick(_delay);
      s.k.tick(_retry * 3);
      expect(s.mounts, hasLength(4));
      s.k.tick(60000);
      expect(s.mounts, hasLength(4));
    });

    test('off: no offer, and "play" is sent as words', () {
      final s = _Setup(enabled: false);
      s.offer.waiting();
      s.k.tick(20000);
      expect(s.mounts, isEmpty);
      expect(s.offer.play('play'), isFalse);
    });

    test('a person joining before the offer: none comes', () {
      final s = _Setup();
      s.offer.waiting();
      s.k.tick(1000);
      s.offer.joined('Sam');
      s.k.tick(10000);
      expect(s.mounts, isEmpty);
      expect(s.k.size, 0);
    });

    test('a person joining: the card wraps up with their name', () {
      final s = _Setup();
      s.offer.waiting();
      s.k.tick(_delay);
      s.offer.joined('Sam');
      expect(s.last.wrapped, ['Sam']);
      s.offer.joined({'odd': true});
      expect(s.last.wrapped, ['Sam', '']);
    });

    test('the wait over: an unused card leaves, a game being played stays', () {
      final a = _Setup();
      a.offer.waiting();
      a.k.tick(_delay);
      a.offer.waitOver();
      expect(a.last.removed, 1);

      final b = _Setup();
      b.offer.waiting();
      b.k.tick(_delay);
      b.last.game = true;
      b.offer.waitOver();
      expect(b.last.removed, 0);
    });

    test('the wait over before the offer: none comes', () {
      final s = _Setup();
      s.offer.waiting();
      s.offer.waitOver();
      s.k.tick(10000);
      expect(s.mounts, isEmpty);
    });

    test('Not now: no more offers this session, even in a later wait; typing play still opens the menu', () {
      final s = _Setup();
      s.offer.waiting();
      s.k.tick(_delay);
      s.offer.dismissed();
      s.offer.waitOver();
      s.offer.waiting();
      s.k.tick(10000);
      expect(s.mounts, ['offer']);
      expect(s.offer.play("let's play"), isTrue);
      expect(s.mounts, ['offer', 'menu']);
      // A new conversation keeps a "Not now" (the web: this page view).
      s.offer.dismissed();
      s.offer.reset();
      s.offer.waiting();
      s.k.tick(10000);
      expect(s.mounts, ['offer', 'menu']);
    });

    test('typing play only while waiting; on a card already up it goes back to the menu, mid-game it does not', () {
      final s = _Setup();
      expect(s.offer.play('play'), isFalse);
      s.offer.waiting();
      expect(s.offer.play('my game crashed'), isFalse);
      s.k.tick(_delay);
      expect(s.offer.play('games'), isTrue);
      expect(s.last.menus, 1);
      s.last.game = true;
      expect(s.offer.play('play'), isTrue);
      expect(s.last.menus, 1);
      expect(s.mounts, ['offer']);
    });
  });
}
