// The device language as the web's visitorInsights.language.browser (#47),
// the cases of the React Native SDK's __tests__/core/deviceLanguage.test.ts.
import 'dart:ui' show Locale;

import 'package:conferbot_flutter/src/core/device_language.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => DeviceLanguage.debugReset());

  test('writes locales as the browser does', () {
    expect(DeviceLanguage.normalize('de_DE'), 'de-DE');
    expect(DeviceLanguage.normalize('en_US@calendar=gregorian'), 'en-US');
    expect(DeviceLanguage.normalize('ja-JP-u-ca-japanese'), 'ja-JP');
    expect(DeviceLanguage.normalize('zh-Hant-TW'), 'zh-Hant-TW');
    expect(DeviceLanguage.normalize(' fr '), 'fr');
    expect(DeviceLanguage.normalize(''), '');
    expect(DeviceLanguage.normalize(null), '');
    expect(DeviceLanguage.normalize('123'), '');
    // The web cuts at 16 characters.
    expect(DeviceLanguage.normalize('sr-Latn-RS-x-private-long'), hasLength(16));
  });

  test('the most preferred language that is one wins', () {
    expect(DeviceLanguage.firstOf(['es-MX', 'en-US']), 'es-MX');
    expect(DeviceLanguage.firstOf(['', 'und', 'nl_NL']), 'nl-NL');
    expect(DeviceLanguage.firstOf(const []), '');
  });

  test('reads the phone (Flutter: PlatformDispatcher locales, as BCP 47)', () {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.localesTestValue = const [Locale('pt', 'BR'), Locale('en', 'US')];
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);
    expect(DeviceLanguage.read(binding.platformDispatcher), 'pt-BR');
  });

  test('is the web snapshot with only the language', () {
    expect(DeviceLanguage.visitorInsightsOf('de-DE'), {
      'v': 1,
      'language': {'browser': 'de-DE'},
    });
    expect(DeviceLanguage.visitorInsightsOf(''), isNull);
  });

  test('goes with every response record, and not when unknown', () {
    final state = ChatState.instance..reset();
    state.initialize(chatSessionId: 's-1', visitorId: 'v-1', botId: 'b-1');
    DeviceLanguage.debugReset('de-DE');
    expect(state.buildResponseData()['visitorInsights'], {
      'v': 1,
      'language': {'browser': 'de-DE'},
    });
    DeviceLanguage.debugReset('');
    expect(state.buildResponseData().containsKey('visitorInsights'), isFalse);
    state.reset();
  });
}
