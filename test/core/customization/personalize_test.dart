// "Greet by name" (lib/src/core/customization/personalize.dart): RN's
// __tests__/core/personalize.test.ts, the web's cases (conferbot-widget
// tests/ownerLayout.test.js personalize, personalizeCustomizations).
import 'package:conferbot_flutter/src/core/customization/personalize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('personalize', () {
    test('fills tokens and falls back', () {
      final vars = visitorVars({'name': 'Sam Lee', 'company': 'Acme'});
      expect(vars['first_name'], 'Sam');
      expect(personalize('Hi {{first_name|there}} 👋', vars), 'Hi Sam 👋');
      expect(personalize('Welcome, {{company}} team', vars), 'Welcome, Acme team');
      final anon = visitorVars(null);
      expect(personalize('Hi {{first_name|there}} 👋', anon), 'Hi there 👋');
      expect(personalize('Hi {{name}}!', anon), 'Hi!');
      expect(personalize('No tokens here', anon), 'No tokens here');
      expect(personalize(null, anon), isNull);
    });

    test('keeps a value as typed (drawn as text, not markup)', () {
      expect(personalize('Hi {{name}}', visitorVars({'name': 'Ann & Bo'})), 'Hi Ann & Bo');
    });

    test('takes a name the chat asked for, firstName / lastName, and {{firstName}}', () {
      expect(visitorVars({}, 'Priya')['first_name'], 'Priya');
      final v = visitorVars({'firstName': 'Ana', 'lastName': 'Ruiz'});
      expect(v['name'], 'Ana Ruiz');
      expect(personalize('Hey {{firstName}}', v), 'Hey Ana');
      expect(visitorVars({'organization': 'Globex'})['company'], 'Globex');
    });
  });

  group('personalizeCustomizations', () {
    test('touches only the visitor-facing texts', () {
      final rule2 = {'text': 'Plain'};
      final c = <String, dynamic>{
        'chatIconCtaText': 'Hi {{first_name|there}}',
        'initialPageTitle': 'Hello {{name}}',
        'initialPageDescription': 'For {{company|you}}',
        'initialPageCardButtonText': 'Chat, {{first_name}}',
        'logoText': '{{name}} Bot',
        'greetingRules': [
          {'text': 'Pricing for {{company|your team}}'},
          rule2,
        ],
      };
      final out = personalizeCustomizations(c, visitorVars({'firstName': 'Ana', 'company': 'Globex'}))!;
      expect(out['chatIconCtaText'], 'Hi Ana');
      expect(out['initialPageTitle'], 'Hello Ana');
      expect(out['initialPageDescription'], 'For Globex');
      expect(out['initialPageCardButtonText'], 'Chat, Ana');
      expect(out['logoText'], '{{name}} Bot');
      expect((out['greetingRules'] as List)[0]['text'], 'Pricing for Globex');
      expect(identical((out['greetingRules'] as List)[1], rule2), isTrue);
      expect(c['chatIconCtaText'], 'Hi {{first_name|there}}');
    });

    test('passes nothing through', () {
      expect(personalizeCustomizations(null, {}), isNull);
    });
  });
}
