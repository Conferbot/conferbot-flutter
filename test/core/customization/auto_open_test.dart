// Auto-open (lib/src/core/customization/auto_open.dart): the React Native
// SDK's __tests__/core/autoOpen.test.ts ported (web src/index.ts live_chat
// auto-open, core/customizations.ts autoOpen / autoOpenDelay).
import 'package:conferbot_flutter/src/core/customization/auto_open.dart';
import 'package:flutter_test/flutter_test.dart';

int? plan(dynamic c, {bool chatStarted = false, bool isOpen = false, bool already = false, int? closedAt, int? now}) =>
    AutoOpen.plan(c, chatStarted: chatStarted, isOpen: isOpen, alreadyAutoOpened: already, closedAt: closedAt, now: now);

void main() {
  test("opens after the owner's delay, in seconds", () {
    expect(plan({'botAutoOpen': true, 'botAutoOpenDelay': 5}), 5000);
    expect(plan({'botAutoOpen': true}), 0);
    expect(AutoOpen.delayOf({'botAutoOpenDelay': '2.5'}), 2500);
    expect(AutoOpen.delayOf({'botAutoOpenDelay': -3}), 0);
    expect(AutoOpen.delayOf({'botAutoOpenDelay': 'soon'}), 0);
  });

  test('does nothing when off, for a chat already started, already open, or already done once', () {
    expect(plan(<String, dynamic>{}), isNull);
    expect(plan(null), isNull);
    expect(plan({'botAutoOpen': false}), isNull);
    expect(plan({'botAutoOpen': true}, chatStarted: true), isNull);
    expect(plan({'botAutoOpen': true}, isOpen: true), isNull);
    expect(plan({'botAutoOpen': true}, already: true), isNull);
  });

  test('waits 2 minutes after the visitor closed it', () {
    const c = {'botAutoOpen': true};
    expect(plan(c, closedAt: 1000, now: 1000 + AutoOpen.closedBlocksMs - 1), isNull);
    expect(plan(c, closedAt: 1000, now: 1000 + AutoOpen.closedBlocksMs), 0);
  });
}
