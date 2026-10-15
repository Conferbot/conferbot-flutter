// Ported from the React Native SDK's __tests__/core/greeting.test.ts.
import 'package:conferbot_flutter/src/core/customization/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

const _new = GreetingFacts(returning: false, signedIn: false);

void main() {
  test('shows nothing when the greeting is off', () {
    expect(Greeting.decide({'chatIconCtaText': 'Hi'}, _new), isNull);
    expect(Greeting.decide(null, _new), isNull);
  });

  test('shows the default message after 3s, opening the chat on a tap', () {
    final g = Greeting.decide({'chatIconCta': true, 'chatIconCtaText': ' Hi there '}, _new)!;
    expect([g.text, g.delay, g.click], ['Hi there', 3, 'open']);
    final h = Greeting.decide({'chatIconCta': true, 'chatIconCtaText': 'Hi', 'greetingDelay': 9999, 'greetingClickAction': 'send'}, _new)!;
    expect([h.delay, h.click], [3600, 'send']);
  });

  test('uses a rule for every page, never one for a given page', () {
    final c = {
      'chatIconCta': true,
      'chatIconCtaText': 'Default',
      'greetingRules': [
        {'matchType': 'contains', 'pattern': '/pricing', 'text': 'Pricing help?'},
        {'matchType': 'glob', 'pattern': '*', 'text': 'Everywhere', 'delay': 1, 'clickAction': 'send', 'starters': ['A', 'B']},
      ],
    };
    final g = Greeting.decide(c, _new)!;
    expect([g.text, g.delay, g.click, g.starters], ['Everywhere', 1, 'send', ['A', 'B']]);
  });

  test('ranks rules by priority, and lets a show-nothing rule silence the card', () {
    final rules = [
      {'matchType': 'contains', 'pattern': '/', 'text': 'Low', 'priority': 10},
      {'matchType': 'contains', 'pattern': '/', 'text': 'High', 'priority': 90},
    ];
    expect(Greeting.decide({'chatIconCta': true, 'greetingRules': rules}, _new)!.text, 'High');
    final silent = [
      ...rules,
      {'matchType': 'contains', 'pattern': '/', 'text': '', 'action': {'type': 'none'}, 'signedIn': 'yes'},
    ];
    expect(Greeting.decide({'chatIconCta': true, 'greetingRules': silent}, const GreetingFacts(returning: false, signedIn: true)), isNull);
    expect(Greeting.decide({'chatIconCta': true, 'greetingRules': silent}, _new)!.text, 'High');
  });

  test('honours who and when; skips what only a browser knows', () {
    final now = DateTime.parse('2026-10-15T12:00:00Z').millisecondsSinceEpoch;
    Map<String, dynamic> r(Map<String, dynamic> extra) => {
          'chatIconCta': true,
          'chatIconCtaText': 'Default',
          'greetingRules': [
            {'matchType': 'contains', 'pattern': '/', 'text': 'Rule', ...extra},
          ],
        };
    expect(Greeting.decide(r({'visitors': 'returning'}), _new)!.text, 'Default');
    expect(Greeting.decide(r({'visitors': 'returning'}), const GreetingFacts(returning: true, signedIn: false))!.text, 'Rule');
    expect(Greeting.decide(r({'endsAt': '2026-10-01T00:00:00Z'}), GreetingFacts(returning: false, signedIn: false, now: now))!.text, 'Default');
    expect(Greeting.decide(r({'countries': ['GB']}), _new)!.text, 'Default');
    expect(Greeting.decide(r({'source': {'utmSource': 'ads'}}), _new)!.text, 'Default');
    expect(Greeting.decide(r({'patterns': ['pricing']}), _new)!.text, 'Default');
  });

  test('carries the old proactive teaser over as the web does', () {
    final g = Greeting.decide({'proactivePromptEnabled': true, 'proactivePromptText': 'Need help?'}, _new)!;
    expect([g.text, g.delay, g.click], ['Need help?', 8, 'send']);
    expect(Greeting.decide({'chatIconCta': true, 'chatIconCtaText': 'Hi', 'proactivePromptEnabled': true, 'proactivePromptText': 'Teaser'}, _new)!.text, 'Teaser');
    expect(Greeting.decide({'smartOnly': true}, _new), isNull);
  });

  test('follows the frequency: every launch with a rest after closing, once a session, once in N days', () {
    const now = 1000000000000;
    expect(Greeting.frequencyAllows({}, const GreetingSeen(), now), isTrue);
    expect(Greeting.frequencyAllows({}, const GreetingSeen(closedAt: now - 10000), now), isFalse);
    expect(Greeting.frequencyAllows({}, const GreetingSeen(closedAt: now - Greeting.pageCooldownSeconds * 1000), now), isTrue);
    expect(Greeting.frequencyAllows({'greetingFrequency': 'session'}, const GreetingSeen(shownThisSession: true), now), isFalse);
    expect(Greeting.frequencyAllows({'greetingFrequency': 'visitor', 'greetingFrequencyDays': 2}, const GreetingSeen(shownAt: now - 86400000), now), isFalse);
    expect(Greeting.frequencyAllows({'greetingFrequency': 'visitor', 'greetingFrequencyDays': 2}, const GreetingSeen(shownAt: now - 3 * 86400000), now), isTrue);
  });

  test('heads the card with the avatar, name and Online', () {
    expect(Greeting.head({'avatar': 'a.png', 'logoText': 'Acme'}), const GreetingHead(avatar: 'a.png', name: 'Acme', online: true));
    expect(
      Greeting.head({'hideAvatar': true, 'avatar': 'a.png', 'logo': 'l.png', 'hideOnlineStatus': true}, 'Bot'),
      const GreetingHead(avatar: 'l.png', name: 'Bot', online: false),
    );
    expect(Greeting.normalizeStyle('nope'), 'imessage');
    expect(Greeting.normalizeStyle('sticky'), 'sticky');
  });

  test('reads the smart rules as the web: visits, chatted, limits, and customers kept quiet', () {
    final smart = [
      {'id': 'sgcust', 'matchType': 'contains', 'pattern': '/', 'text': '', 'signedIn': 'yes', 'action': {'type': 'none'}, 'priority': 95},
      {
        'id': 'sgretn', 'matchType': 'contains', 'pattern': '/', 'text': 'Welcome back!', 'behavior': {'minVisits': 2}, 'priority': 24,
        'limits': {'maxShows': 1, 'windowDays': 3, 'quietDaysAfterDismiss': 14},
      },
      {'id': 'sgengd', 'matchType': 'contains', 'pattern': '/', 'text': 'Finding what you need?', 'behavior': {'minPagesThisVisit': 3}, 'priority': 22},
    ];
    final c = {'chatIconCta': true, 'chatIconCtaText': 'Default', 'greetingRules': smart};
    final now = DateTime.parse('2026-10-15T12:00:00Z').millisecondsSinceEpoch;
    expect(Greeting.decide(c, GreetingFacts(returning: false, signedIn: false, visits: 1, now: now))!.text, 'Default');
    expect(Greeting.decide(c, GreetingFacts(returning: true, signedIn: false, visits: 2, now: now))!.text, 'Welcome back!');
    expect(
      Greeting.decide(c, GreetingFacts(returning: true, signedIn: false, visits: 2, shows: {'sgretn': [now - 86400000]}, now: now))!.text,
      'Default',
    );
    expect(
      Greeting.decide(c, GreetingFacts(returning: true, signedIn: false, visits: 2, dismissed: {'sgretn': now - 5 * 86400000}, now: now))!.text,
      'Default',
    );
    // Signed-in customers: quiet, unless the owner has a rule of their own for them.
    expect(Greeting.decide(c, GreetingFacts(returning: false, signedIn: true, now: now)), isNull);
    final own = {
      ...c,
      'greetingRules': [
        ...smart,
        {'matchType': 'contains', 'pattern': '/', 'text': 'Hi customer', 'signedIn': 'yes'},
      ],
    };
    expect(Greeting.decide(own, GreetingFacts(returning: false, signedIn: true, now: now))!.text, 'Hi customer');
  });

  test("dresses the card in the bot's colours", () {
    expect(Greeting.accent({'brandColor': '#FFFFFF', 'headerBgColor': '#0F766E'}), '#0f766e');
    expect(Greeting.accent({'headerBgColor': '#fef08a', 'widgetIconBgColor': '#fde68a'}), '#4f46e5');
    final b = Greeting.bubble({'widgetIconBgColor': '#0F766E'});
    expect([b.bg, b.tail, b.fg], [['#0f766e'], '#0f766e', '#ffffff']);
    expect(Greeting.bubble({'widgetIconBgColor': '#fde68a'}).fg, '#111827');
    final g = Greeting.bubble({'widgetIconThemeType': 'Gradient', 'widgetGradientBgOne': '#7c3aed', 'widgetGradientBgTwo': '#0d9488'});
    expect([g.bg, g.tail], [['#7c3aed', '#0d9488'], '#0d9488']);
    expect(Greeting.font({'font': 'Arial, sans-serif'}), isNull);
    expect(Greeting.font({'font': 'Inter'}), 'Inter');
  });

  test('keeps what it saw per bot, and reads junk as a first visit', () {
    const r = GreetingRecord(visits: 2, chatted: true, shows: {'k': [1, 2]}, dismissed: {'k': 3}, closedAt: 4, shownAt: 5, last: 'k');
    final back = GreetingRecord.decode(r.encode());
    expect([back.visits, back.chatted, back.shows, back.dismissed, back.closedAt, back.shownAt, back.last], [2, true, {'k': [1, 2]}, {'k': 3}, 4, 5, 'k']);
    expect(GreetingRecord.decode('not json').visits, 0);
    expect(GreetingRecord.decode(null).chatted, isFalse);
  });
}
