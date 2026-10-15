// The header's status (lib/src/core/live_chat/reply_time.dart), the cases of
// the RN SDK's __tests__/core/replyTime.test.ts (the header cases of the web
// widget's tests/replyTime.test.js), plus a person in the chat (web
// headerPresence.ts markHeaderLive).
import 'package:conferbot_flutter/src/core/live_chat/reply_time.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> online(String? bucket) => {'mode': 'auto', 'handover': true, 'state': 'online', 'bucket': bucket, 'leaveMessage': true};

void main() {
  group('headerLine (web replyTime.ts)', () {
    test('a bucket reads as an honest phrase', () {
      expect(ReplyTime.headerLine(online('few_minutes')), 'Typically replies in a few minutes');
      expect(ReplyTime.headerLine(online('day')), 'Typically replies within a day');
    });

    test('no data, an older server, or no handover: Online stays', () {
      expect(ReplyTime.headerLine(online(null)), isNull);
      expect(ReplyTime.headerLine(null), isNull);
      expect(ReplyTime.headerLine({...online('few_minutes'), 'handover': false}), isNull);
    });

    test("away: Online, and when the team is back in the visitor's time", () {
      final now = DateTime(2026, 10, 3, 20, 0);
      final backAt = DateTime(2026, 10, 5, 9, 0).toUtc().toIso8601String();
      final rt = {...online('few_minutes'), 'state': 'away', 'backAt': backAt};
      expect(ReplyTime.headerLine(rt, now: now), 'Online · team back Monday 9 AM');
      expect(ReplyTime.headerLine({...rt, 'backAt': null}, now: now), 'Online · team replies by email');
      expect(ReplyTime.backWhen(DateTime(2026, 10, 4, 9, 30).toUtc().toIso8601String(), now: now), 'tomorrow 9:30 AM');
      expect(ReplyTime.backWhen(DateTime(2026, 10, 3, 22, 0).toUtc().toIso8601String(), now: now), 'at 10 PM');
      expect(ReplyTime.backWhen(DateTime(2026, 10, 12, 9, 0).toUtc().toIso8601String(), now: now), 'Mon, Oct 12 9 AM');
      expect(ReplyTime.backWhen('not a date', now: now), '');
    });

    test('offline: email only when leave-a-message is on', () {
      final rt = {...online('few_minutes'), 'state': 'offline'};
      expect(ReplyTime.headerLine(rt), 'Online · team replies by email');
      expect(ReplyTime.headerLine({...rt, 'leaveMessage': false}), 'Online · team away right now');
    });

    test("the owner's fixed words, or nothing; an AI agent bot shows none", () {
      expect(ReplyTime.headerLine({...online(null), 'mode': 'fixed', 'text': 'We reply within 2 hours'}), 'We reply within 2 hours');
      expect(ReplyTime.headerLine({'mode': 'hide', 'handover': true}), isNull);
      expect(ReplyTime.headerLine(online('few_minutes'), agent: true), isNull);
    });
  });

  group('headerStatus', () {
    test('the reply time before anyone joins, plain Online once a person is in the chat', () {
      final rt = {...online('few_minutes'), 'state': 'offline'};
      expect(ReplyTime.headerStatus(rt), 'Online · team replies by email');
      expect(ReplyTime.headerStatus(rt, personInChat: true), 'Online');
      expect(ReplyTime.headerStatus(null), 'Online');
      expect(ReplyTime.headerStatus(rt, hidden: true), isNull);
    });
  });
}
