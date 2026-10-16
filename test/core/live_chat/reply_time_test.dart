// The header's status (lib/src/core/live_chat/reply_time.dart), the cases of
// the RN SDK's __tests__/core/replyTime.test.ts (the header cases of the web
// widget's tests/replyTime.test.js), plus a person in the chat (web
// headerPresence.ts markHeaderLive), and the home card's homeLine /
// homePeople (the web's tests/replyTime.test.js).
import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
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

  // The web's home card cases (tests/replyTime.test.js homeLine, homePeople).
  group('homeLine / homePeople (web replyTime.ts)', () {
    test('the card line for each case', () {
      expect(ReplyTime.homeLine(online('few_minutes')), const HomeLine('The team typically replies in a few minutes'));
      expect(ReplyTime.homeLine(online(null)), isNull);
      expect(ReplyTime.homeLine(null), isNull);
      final now = DateTime(2026, 10, 3, 20, 0);
      final backAt = DateTime(2026, 10, 5, 9, 0).toUtc().toIso8601String();
      expect(ReplyTime.homeLine({...online('few_minutes'), 'state': 'away', 'backAt': backAt}, now: now),
          const HomeLine("We're away right now · back Monday 9 AM", away: true));
      expect(ReplyTime.homeLine({...online('few_minutes'), 'state': 'offline'}),
          const HomeLine("The team is offline · we'll reply by email", away: true));
      expect(ReplyTime.homeLine({...online('few_minutes'), 'state': 'offline', 'leaveMessage': false})!.text, 'The team is offline right now');
      expect(ReplyTime.homeLine({'mode': 'hide', 'handover': true}), HomeLine.hidden);
      expect(ReplyTime.homeLine(online('few_minutes'), agent: true), const HomeLine('Answers instantly · team replies in a few minutes'));
      expect(ReplyTime.homeLine({...online('few_minutes'), 'state': 'away', 'backAt': backAt}, agent: true, now: now)!.text,
          'Answers instantly · team back Monday 9 AM');
      expect(ReplyTime.homeLine({'mode': 'hide', 'handover': true}, agent: true), isNull);
    });

    test("the home card's promise: plain words, never a speed promise when nobody is there", () {
      final now = DateTime(2026, 10, 8, 22, 0);
      HomeLine p(dynamic rt, {bool agent = false}) => ReplyTime.homePeople(rt, agent: agent, now: now);
      final tomorrow9 = DateTime(2026, 10, 9, 9, 0).toUtc().toIso8601String();
      expect(p(online('few_minutes')), const HomeLine('Usually replies in a few minutes'));
      expect(p({...online('few_minutes'), 'mode': 'fixed', 'text': 'We reply within 2 hours'}), const HomeLine('We reply within 2 hours'));
      expect(p(online(null)), const HomeLine('Usually replies instantly'));
      expect(p(null), const HomeLine('Answers instantly, day or night'));
      expect(p({...online('few_minutes'), 'handover': false}), const HomeLine('Answers instantly, day or night'));
      expect(p({...online('few_minutes'), 'state': 'offline'}).text, 'Team replies by email');
      expect(p({...online('few_minutes'), 'state': 'offline', 'backAt': tomorrow9}).text, 'Team back tomorrow 9 AM');
      expect(p({...online('few_minutes'), 'state': 'away', 'backAt': tomorrow9}).text, 'Team back tomorrow 9 AM');
      expect(p({...online('few_minutes'), 'state': 'away', 'leaveMessage': false}).text, 'Team away right now');
      expect(p({...online('few_minutes'), 'state': 'away', 'leaveMessage': false}).away, isTrue);
      expect(p({'mode': 'hide', 'handover': true}).text, '');
      expect(p(null, agent: true), const HomeLine('Answers instantly, day or night'));
      expect(p({...online('few_minutes'), 'state': 'offline'}, agent: true), const HomeLine('Answers instantly, day or night'));
      expect(p({'mode': 'hide', 'handover': true}, agent: true).text, 'Answers instantly, day or night');
    });
  });

  group('typicalWait (the wait card, web replyTime.ts typicalWait)', () {
    tearDown(() => I18n.setWidgetLanguage('en'));

    test("says the routed team's usual wait first, else the workspace's", () {
      expect(ReplyTime.typicalWait({'mode': 'auto', 'bucket': 'few_hours'}, {'bucket': 'under_minute'}), 'Typical wait: under a minute');
      expect(ReplyTime.typicalWait({'mode': 'auto', 'bucket': 'few_hours'}), 'Typical wait: a few hours');
      expect(ReplyTime.typicalWait({'mode': 'auto', 'bucket': 'unknown', 'wait': 'about 3 minutes'}), 'Typical wait: about 3 minutes');
      expect(ReplyTime.typicalWait(null, {'bucket': 'day'}), 'Typical wait: up to a day');
    });

    test('says nothing when the owner chose Fixed or Hide, or there is no data', () {
      expect(ReplyTime.typicalWait({'mode': 'hide', 'bucket': 'few_minutes'}, {'bucket': 'few_minutes'}), isNull);
      expect(ReplyTime.typicalWait({'mode': 'fixed', 'text': 'Within a day', 'bucket': 'few_minutes'}), isNull);
      expect(ReplyTime.typicalWait({'mode': 'auto'}), isNull);
      expect(ReplyTime.typicalWait(null, null), isNull);
    });

    test("is in the visitor's language", () {
      I18n.setWidgetLanguage('de');
      expect(ReplyTime.typicalWait({'mode': 'auto', 'bucket': 'few_minutes'}), isNot(contains('Typical')));
    });
  });
}
