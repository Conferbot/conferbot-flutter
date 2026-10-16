// The conversation's human touches (lib/src/core/delight/delight.dart): the
// React Native SDK's __tests__/core/delight.test.ts ported (web
// ts/chat/delight/rules.ts, index.ts, stallNudge.ts, celebrate.ts,
// ratingFx.ts).
import 'dart:math' as math;

import 'package:conferbot_flutter/src/core/delight/delight.dart';
import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('delight rules', () {
    tearDown(() => I18n.setWidgetLanguage('en'));

    test('is on unless the owner set it to false', () {
      expect(Delight.touchOn(<String, dynamic>{}, 'celebrations'), isTrue);
      expect(Delight.touchOn(null, 'botReactions'), isTrue);
      expect(Delight.touchOn({'celebrations': false}, 'celebrations'), isFalse);
      expect(Delight.touchOn({'stallNudges': 0}, 'stallNudges'), isTrue);
    });

    test('lets questions be changed while only safe steps ran since', () {
      expect(Delight.canChangeAnswer('ask-email-node', []), isTrue);
      expect(Delight.canChangeAnswer('ask-email-node', ['message-node', 'condition-node', 'delay-node', 'ask-name-node']), isTrue);
      expect(Delight.canChangeAnswer('ask-email-node', ['calendar-node']), isFalse);
      expect(Delight.canChangeAnswer('ask-email-node', ['webhook-node']), isFalse);
      expect(Delight.canChangeAnswer('ask-email-node', ['agent']), isFalse);
      expect(Delight.canChangeAnswer('calendar-node', []), isFalse);
      expect(Delight.isSafeToUndo('welcome-node'), isFalse);
      expect(Delight.waitsForAnswer('payment-node'), isTrue);
      expect(Delight.waitsForAnswer('message-node'), isFalse);
    });

    test('shows "Edit" only on the latest answer, when the bot is quiet and nothing locks the chat', () {
      bool show({dynamic c = const {}, bool locked = false, bool busy = false, bool latest = true}) => Delight.showChangeFor(
            customizations: c,
            locked: locked,
            botBusy: busy,
            isLatestAnswer: latest,
            questionType: 'ask-name-node',
            typesSince: const [],
          );
      expect(show(), isTrue);
      expect(show(c: {'allowChangeAnswer': false}), isFalse);
      expect(show(locked: true), isFalse);
      expect(show(busy: true), isFalse);
      expect(show(latest: false), isFalse);
    });

    test('reads a score from the answer text', () {
      expect(Delight.scoreShare('★★★★ Good'), closeTo(0.8, 1e-9));
      expect(Delight.scoreShare('⭐⭐⭐⭐⭐'), 1);
      expect(Delight.scoreShare('8/10'), closeTo(0.8, 1e-9));
      expect(Delight.scoreShare('7 / 10'), closeTo(0.7, 1e-9));
      expect(Delight.scoreShare('hello'), isNull);
      expect(Delight.scoreText('rating-choice-node', 4, 5), '4/5');
      expect(Delight.scoreText('ask-name-node', 4, 5), '');
    });

    test('reacts as a person would: a wave, a party, a heart, a thumbs up, a thank-you', () {
      expect(Delight.reactionFor('ask-name-node', 'Jamie'), '👋');
      expect(Delight.reactionFor('calendar-node', 'Tue 10:00'), '🎉');
      expect(Delight.reactionFor('payment-node', 'Paid'), '🎉');
      expect(Delight.reactionFor('rating-choice-node', '5/5'), '❤️');
      expect(Delight.reactionFor('opinion-scale-choice-node', '6/10'), '👍');
      expect(Delight.reactionFor('user-rating-node', '2/5'), '🙏');
      expect(Delight.reactionFor('rating-choice-node', 'great'), isNull);
      expect(Delight.reactionFor('ask-email-node', 'a@b.co'), isNull);
      expect(Delight.reactionLabel('👋'), 'The bot waved');
      expect(Delight.reactionLabel('🦄'), 'The bot reacted');
    });

    test('celebrates a booking, a payment, a perfect score (not the rating card, which sparks)', () {
      expect(Delight.celebrates('calendar-node', ''), isTrue);
      expect(Delight.celebrates('payment-node', ''), isTrue);
      expect(Delight.celebrates('opinion-scale-choice-node', '10/10'), isTrue);
      expect(Delight.celebrates('opinion-scale-choice-node', '9/10'), isFalse);
      expect(Delight.celebrates('rating-choice-node', '5/5'), isFalse);
      expect(Delight.celebrates('ask-email-node', ''), isFalse);
    });

    test("follows the owner's switches and reduced motion", () {
      expect(Delight.touchesFor(<String, dynamic>{}, 'calendar-node', '', false), (reaction: '🎉', celebrate: true));
      expect(Delight.touchesFor(<String, dynamic>{}, 'calendar-node', '', true), (reaction: '🎉', celebrate: false));
      expect(Delight.touchesFor({'celebrations': false}, 'calendar-node', '', false), (reaction: '🎉', celebrate: false));
      expect(Delight.touchesFor({'botReactions': false}, 'ask-name-node', 'Jo', false), (reaction: null, celebrate: false));
    });

    test("draws the web's confetti fan and rating sparks", () {
      final pieces = Delight.confettiPieces(() => 0.5);
      expect(pieces, hasLength(Delight.confettiCount));
      // The first piece at -160 degrees (no jitter at 0.5), 86 px out.
      final a = -160 * math.pi / 180;
      expect(pieces[0].dx, (math.cos(a) * 86 + 0.5).floor());
      expect(pieces[0].dy, (math.sin(a) * 86 + 0.5).floor());
      expect([pieces[0].fall, pieces[0].rot, pieces[0].delay, pieces[0].tone, pieces[0].round], [41, 0, 45, 0, true]);
      // The fan opens up: every piece flies upward.
      for (final p in pieces) {
        expect(p.dy, lessThan(0));
      }
      expect(pieces.map((p) => p.tone).take(5), [0, 1, 2, 3, 0]);
      expect(Delight.ratingSparks(false), [20, 65, 110, 155, 200, 245, 290, 335]);
      expect(Delight.ratingSparks(true), hasLength(12));
    });

    test("words the nudge for typing or picking, in the visitor's language", () {
      expect(Delight.stallHintFor('ask-email-node'), "No rush - type your answer below whenever you're ready.");
      expect(Delight.stallHintFor('n-choices-node'), "No rush - pick whichever fits when you're ready.");
      I18n.setWidgetLanguage('de');
      expect(Delight.stallHintFor('n-choices-node'), isNot(contains('No rush')));
      expect(Delight.nudgesWhileWaiting('calendar-node'), isTrue);
      expect(Delight.nudgesWhileWaiting('ask-file-node'), isFalse);
    });
  });

  group('the stall watch', () {
    ({StallWatch watch, void Function(int) advance, List<String> shown, int Function() hidden}) harness({
      bool Function()? visible,
      String Function()? composer,
    }) {
      var now = 0;
      var seq = 0;
      final timers = <({int at, void Function() fn, int id})>[];
      final shown = <String>[];
      var hidden = 0;
      final watch = StallWatch(
        isVisible: visible ?? () => true,
        composerValue: composer ?? () => '',
        show: shown.add,
        hide: () => hidden++,
        now: () => now,
        setTimer: (fn, ms) {
          timers.add((at: now + ms, fn: fn, id: ++seq));
          return seq;
        },
        clearTimer: (id) => timers.removeWhere((t) => t.id == id),
      );
      void advance(int ms) {
        final end = now + ms;
        for (;;) {
          timers.sort((a, b) => a.at.compareTo(b.at));
          if (timers.isEmpty || timers.first.at > end) break;
          final t = timers.removeAt(0);
          now = t.at;
          t.fn();
        }
        now = end;
      }

      return (watch: watch, advance: advance, shown: shown, hidden: () => hidden);
    }

    test('nudges once, 40 s into a question nobody touched', () {
      final h = harness();
      h.advance(Delight.stallQuietMs); // quiet since it started
      h.watch.arm('n-choices-node');
      h.advance(Delight.stallAfterMs - 1);
      expect(h.shown, isEmpty);
      h.advance(1);
      expect(h.shown, ["No rush - pick whichever fits when you're ready."]);
      h.watch.arm('n-choices-node');
      h.advance(Delight.stallAfterMs * 2);
      expect(h.shown, hasLength(1));
      h.watch.disarm();
      expect(h.hidden(), 1);
    });

    test('waits while the visitor is busy, away or typing', () {
      var visible = false;
      var typed = 'hel';
      final h = harness(visible: () => visible, composer: () => typed);
      h.advance(Delight.stallQuietMs);
      h.watch.arm('ask-name-node');
      h.advance(Delight.stallAfterMs);
      expect(h.shown, isEmpty);
      visible = true;
      h.advance(Delight.stallQuietMs);
      expect(h.shown, isEmpty); // still typing
      typed = '';
      h.watch.touch();
      h.advance(Delight.stallQuietMs - 1);
      expect(h.shown, isEmpty);
      h.advance(Delight.stallQuietMs);
      expect(h.shown, hasLength(1));
    });

    test('goes quietly when answered before the nudge', () {
      final h = harness();
      h.advance(Delight.stallQuietMs);
      h.watch.arm('ask-name-node');
      h.advance(1000);
      h.watch.disarm();
      h.advance(Delight.stallAfterMs);
      expect(h.shown, isEmpty);
      expect(h.hidden(), 0);
    });
  });
}
