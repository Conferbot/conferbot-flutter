// The wait card's max-wait countdown (lib/src/core/live_chat/live_chat.dart),
// the React Native SDK's __tests__/core/waitCountdown.test.ts ported: the web
// widget's queueCard.ts clock / setRemaining and special.ts
// _attachHandoverWait (remainingSeconds after a reload) (#38).
import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => I18n.setWidgetLanguage('en'));

  group('clock', () {
    test('m:ss', () {
      expect(LiveChat.clock(0), '0:00');
      expect(LiveChat.clock(5), '0:05');
      expect(LiveChat.clock(65), '1:05');
      expect(LiveChat.clock(600), '10:00');
      expect(LiveChat.clock(59.6), '1:00');
    });
    test('never below 0:00', () {
      expect(LiveChat.clock(-3), '0:00');
      expect(LiveChat.clock(double.nan), '0:00');
      expect(LiveChat.clock(double.infinity), '0:00');
    });
  });

  group('maxWaitText', () {
    test('"Max wait 1:05"', () {
      expect(LiveChat.maxWaitText(65), 'Max wait 1:05');
    });
    test("in the visitor's language", () {
      I18n.setWidgetLanguage('de');
      expect(LiveChat.maxWaitText(65), 'Max. Wartezeit 1:05');
      I18n.setWidgetLanguage('es');
      expect(LiveChat.maxWaitText(120), 'Espera máx. 2:00');
    });
  });

  group('waitDeadline', () {
    const now = 1000000;
    test("the step's max wait from now", () {
      expect(LiveChat.waitDeadline(5, null, now: now), now + 5 * 60000);
      expect(LiveChat.waitDeadline('3', null, now: now), now + 3 * 60000);
      expect(LiveChat.waitDeadline(0.5, null, now: now), now + 30000);
    });
    test('2 minutes when unset', () {
      expect(LiveChat.waitDeadline(null, null, now: now), now + 2 * 60000);
      expect(LiveChat.waitDeadline(0, null, now: now), now + 2 * 60000);
    });
    test("a restored wait: the server's seconds left", () {
      expect(LiveChat.waitDeadline(5, 42, now: now), now + 42000);
      expect(LiveChat.waitDeadline(5, 0, now: now), now);
    });
    test('a bad remaining is ignored', () {
      expect(LiveChat.waitDeadline(5, double.nan, now: now), now + 5 * 60000);
      expect(LiveChat.waitDeadline(5, -1, now: now), now + 5 * 60000);
    });
  });

  group('secondsLeft', () {
    test('whole seconds, rounded up, 0 once past', () {
      expect(LiveChat.secondsLeft(10000, now: 0), 10);
      expect(LiveChat.secondsLeft(10000, now: 500), 10);
      expect(LiveChat.secondsLeft(10000, now: 1000), 9);
      expect(LiveChat.secondsLeft(10000, now: 10000), 0);
      expect(LiveChat.secondsLeft(10000, now: 20000), 0);
    });
  });
}
