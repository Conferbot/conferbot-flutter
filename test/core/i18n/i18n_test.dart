// The widget languages (core/i18n): how the language is chosen, the
// fallbacks, the tables against RN's shared strings.json. Ported from RN's
// __tests__/core/i18n.test.ts and Android's I18nTest.
import 'dart:convert';
import 'dart:io';

import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
import 'package:conferbot_flutter/src/core/i18n/i18n_games.dart';
import 'package:conferbot_flutter/src/providers/conferbot_provider.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_test/flutter_test.dart';

final _holes = RegExp(r'\{(\w+)\}');
Set<String> holes(String s) => _holes.allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final en = I18n.dictionary('en');

  tearDown(I18n.debugReset);

  group('which language', () {
    test("the owner's choice wins over the phone", () {
      expect(I18n.resolveLanguage('nl', ['de-DE', 'fr']), 'nl');
      expect(I18n.resolveLanguage(' DE ', ['fr']), 'de');
    });

    test('auto, absent or unknown follows the first supported phone language', () {
      expect(I18n.resolveLanguage('auto', ['ja-JP', 'fr-CA', 'de']), 'fr');
      expect(I18n.resolveLanguage(null, ['es_MX']), 'es');
      expect(I18n.resolveLanguage('klingon', ['nl-BE']), 'nl');
      expect(I18n.resolveLanguage(42, ['de']), 'de');
    });

    test('English when nothing fits', () {
      expect(I18n.resolveLanguage('auto', ['ja', 'zh-Hant']), 'en');
      expect(I18n.resolveLanguage(null, []), 'en');
      expect(I18n.resolveLanguage(null, null), 'en');
    });

    test('a stored setting is a supported code or auto', () {
      expect(I18n.normalizeWidgetLanguage('FR'), 'fr');
      expect(I18n.normalizeWidgetLanguage('pt'), 'auto');
      expect(I18n.normalizeWidgetLanguage(''), 'auto');
      expect(I18n.normalizeWidgetLanguage(null), 'auto');
      expect(I18n.baseLanguageOf('nl-BE'), 'nl');
      expect(I18n.baseLanguageOf('pt-BR'), isNull);
    });

    test("the device's languages are BCP 47 tags, und and repeats dropped", () {
      final tags = I18n.deviceLanguages();
      for (final tag in tags) {
        expect(tag, isNot(contains('_')));
        expect(tag.toLowerCase().startsWith('und'), isFalse);
      }
      expect(tags.toSet().length, tags.length);
    });

    test('setWidgetLanguage keeps a regional tag of the language for dates and tells listeners', () {
      var told = 0;
      void listener() => told++;
      I18n.languageListenable.addListener(listener);
      expect(I18n.setWidgetLanguage('auto', ['nl-BE', 'en-US']), 'nl');
      expect(I18n.language, 'nl');
      expect(I18n.localeTag, 'nl-BE');
      expect(I18n.intlLocale, 'nl');
      expect(I18n.setWidgetLanguage('nl', ['nl_BE']), 'nl');
      expect(I18n.localeTag, 'nl-BE');
      expect(I18n.setWidgetLanguage('de', ['nl-BE']), 'de');
      expect(I18n.localeTag, 'de');
      expect(I18n.setWidgetLanguage('de-CH', ['ja-JP']), 'en', reason: 'a setting is a code, not a tag');
      expect(told, 3);
      I18n.languageListenable.removeListener(listener);
    });

    test("the app's widgetLanguage wins over the owner's, the owner's over the phone", () {
      final app = ConferBotProvider(apiKey: 'k', botId: 'b', config: const ConferBotConfig(widgetLanguage: 'es', autoConnect: false));
      expect(app.applyWidgetLanguageFor({'widgetLanguage': 'de'}), 'es');
      final owner = ConferBotProvider(apiKey: 'k', botId: 'b', config: const ConferBotConfig(autoConnect: false));
      expect(owner.applyWidgetLanguageFor({'widgetLanguage': 'de'}), 'de');
      expect(I18n.language, 'de');
      expect(owner.applyWidgetLanguageFor({'widgetLanguage': 'xx'}), I18n.resolveLanguage('auto', I18n.deviceLanguages()));
      app.dispose();
      owner.dispose();
    });
  });

  group('the words', () {
    test('t draws the active language', () {
      expect(t('common.close'), en['common.close']);
      I18n.setWidgetLanguage('de', const []);
      expect(t('common.close'), I18n.dictionary('de')['common.close']);
      expect(t('common.close'), isNot(en['common.close']));
    });

    test('name placeholders are filled, a missing value keeps its braces', () {
      expect(I18n.tFor('en', 'sdk.agent.avatarOf', {'name': 'Ada'}), "Ada's avatar");
      expect(I18n.tFor('de', 'sdk.agent.avatarOf', {'name': 'Ada'}), 'Avatar von Ada');
      expect(I18n.tFor('en', 'sdk.agent.avatarOf'), "{name}'s avatar");
      expect(I18n.tFor('en', 'sdk.agent.avatarOf', {'other': 1}), "{name}'s avatar");
      expect(I18n.tFor('en', 'matrix.progress', {'n': 2.0, 'total': 5}), '2 of 5 answered');
    });

    test('plurals take one for 1 and other otherwise, n filled', () {
      expect(tPlural('address.suggestions', 1), '1 suggestion');
      expect(tPlural('address.suggestions', 3), '3 suggestions');
      expect(tPlural('address.suggestions', 0), '0 suggestions');
      I18n.setWidgetLanguage('nl', const []);
      expect(tPlural('address.suggestions', 2), I18n.dictionary('nl')['address.suggestions.other']!.replaceAll('{n}', '2'));
    });

    test('an unknown language is English and an unknown key is the key', () {
      expect(I18n.tFor('pt', 'common.close'), en['common.close']);
      expect(I18n.tFor('de', 'no.such.key'), 'no.such.key');
      expect(I18n.tFor('de', 'no.such.{x}', {'x': 1}), 'no.such.1');
    });

    test("owner fields: the stock English shows translated, the owner's own words as written", () {
      I18n.setWidgetLanguage('fr', const []);
      final close = I18n.dictionary('fr')['common.close']!;
      expect(I18n.ownerTextOr(en['common.close'], 'common.close'), close);
      expect(I18n.ownerTextOr('  <b>${en['common.close']!.toUpperCase()}</b>! ', 'common.close'), close);
      expect(I18n.ownerTextOr('', 'common.close'), close);
      expect(I18n.ownerTextOr(null, 'common.close'), close);
      expect(I18n.ownerTextOr('Fermez', 'common.close'), 'Fermez');
      expect(I18n.stockText(en['common.close'], 'common.close'), close);
      expect(I18n.stockText('Shut', 'common.close', ['shut']), close);
      expect(I18n.stockText('', 'common.close'), '');
      expect(I18n.stockText(null, 'common.close'), '');
      expect(I18n.stockText('My own words', 'common.close'), 'My own words');
    });

    test('day and month names in the language, English keeps its own', () {
      expect(I18n.weekdayNames('short', ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])[1], 'Mon');
      expect(I18n.monthNames('short', ['Jan'])[0], 'Jan');
      I18n.setWidgetLanguage('de', const []);
      expect(I18n.weekdayNames('long'), hasLength(7));
      expect(I18n.weekdayNames('long')[1], 'Montag');
      expect(I18n.weekdayNames('narrow')[1], 'M');
      expect(I18n.monthNames('long'), hasLength(12));
      expect(I18n.monthNames('long')[0], 'Januar');
      I18n.setWidgetLanguage('fr', const []);
      expect(I18n.monthNames('long')[1], 'février');
    });
  });

  group('the tables', () {
    test('every key is in all five languages, none empty', () {
      expect(I18n.keys.length, greaterThan(1000));
      expect(I18n.keys.toSet().length, I18n.keys.length);
      for (final lang in I18n.supported) {
        final dict = I18n.dictionary(lang);
        final missing = I18n.keys.where((k) => (dict[k] ?? '').trim().isEmpty).toList();
        expect(missing, isEmpty, reason: '$lang missing');
      }
    });

    test('each translation has the same placeholders as the English', () {
      for (final lang in I18n.supported) {
        final dict = I18n.dictionary(lang);
        // queue.position: the web passes both {n} and {ord}; English says "{ord}", the others "{n}".
        final off = I18n.keys
            .where((k) => k != 'queue.position')
            .where((k) => !setEquals(holes(dict[k]!), holes(en[k]!)))
            .toList();
        expect(off, isEmpty, reason: '$lang placeholders');
      }
    });

    test('every one has its other', () {
      final lonely = I18n.keys
          .where((k) => k.endsWith('.one'))
          .where((k) => !en.containsKey('${k.substring(0, k.length - 4)}.other'))
          .where((k) => !const {'sources.one', 'requests.one'}.contains(k))
          .toList();
      expect(lonely, isEmpty);
    });

    test('the games have their lists in every language', () {
      for (final lang in I18n.supported) {
        expect(i18nTriviaOf(lang).length, greaterThanOrEqualTo(10), reason: lang);
        expect(i18nWordsOf(lang).length, greaterThanOrEqualTo(10), reason: lang);
      }
      expect(i18nTriviaOf('de').first.q, isNot(i18nTriviaOf('en').first.q));
      expect(i18nTriviaOf('pt').first.q, i18nTriviaOf('en').first.q);
    });

    // Every literal key the SDK passes to t(...) / tPlural(...) is in the table.
    test('every key the SDK draws is in the table', () {
      final call = RegExp(r"\b(?:t|tFor|tPlural|ownerTextOr|stockText)\(\s*(?:'[a-z]{2}',\s*)?'([a-zA-Z][\w-]*(?:\.[\w-]+)+)'");
      final unknown = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') || f.path.contains('/core/i18n/strings_')) continue;
        for (final m in call.allMatches(f.readAsStringSync())) {
          final key = m.group(1)!;
          if (!en.containsKey(key) && !en.containsKey('$key.one') && !en.containsKey('$key.other')) {
            unknown.add('${f.path}: $key');
          }
        }
      }
      expect(unknown.toSet().toList(), isEmpty);
    });

    // The Dart tables are RN's shared strings.json (tool/sync_i18n.sh).
    test('the generated tables match the shared strings.json', () {
      final dev = Platform.environment['CONFERBOT_DEV'];
      final json = File('${dev != null ? '$dev/sdk' : '..'}/conferbot-react-native/scripts/parity/i18n/strings.json');
      if (!json.existsSync()) {
        markTestSkipped('RN SDK is not checked out beside this one');
        return;
      }
      final d = jsonDecode(json.readAsStringSync()) as Map<String, dynamic>;
      final strings = (d['strings'] as Map).cast<String, Map>();
      expect(d['languages'], I18n.supported);
      expect(strings['en']!.keys.toList(), I18n.keys);
      for (final lang in I18n.supported) {
        expect(I18n.dictionary(lang), Map<String, String>.from(strings[lang]!), reason: '$lang words');
      }
      final games = d['games'] as Map;
      for (final lang in I18n.supported) {
        final trivia = (games['trivia'][lang] as List).cast<Map>();
        expect(i18nTriviaOf(lang).map((x) => x.q).toList(), trivia.map((x) => x['q']).toList());
        expect(i18nTriviaOf(lang).map((x) => x.a).toList(), trivia.map((x) => x['a']).toList());
        expect(i18nTriviaOf(lang).map((x) => x.wrong).toList(), trivia.map((x) => x['wrong']).toList());
        final words = (games['words'][lang] as List).cast<Map>();
        expect(i18nWordsOf(lang).map((x) => x.w).toList(), words.map((x) => x['w']).toList());
        expect(i18nWordsOf(lang).map((x) => x.hint).toList(), words.map((x) => x['hint']).toList());
      }
    });

    test('the sync script says the tables are up to date', () {
      final r = Process.runSync('sh', ['tool/sync_i18n.sh', '--check']);
      if (r.exitCode != 0 && '${r.stderr}'.contains('not found')) {
        markTestSkipped('RN SDK or node not available');
        return;
      }
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });
  });
}
