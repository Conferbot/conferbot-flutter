// The bot's font in the chat (services/font_loader.dart ChatFont,
// widgets/chat_widget.dart; RN #53): the owner's font over the theme's for
// the header's title, the bubbles and the composer; nothing set keeps the
// app's own font.
import 'dart:io';

import 'package:conferbot_flutter/src/providers/conferbot_provider.dart';
import 'package:conferbot_flutter/src/services/storage_service.dart';
import 'package:conferbot_flutter/src/widgets/chat_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TempPaths(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

ConferBotProvider _provider(Map<String, dynamic> c) {
  final p = ConferBotProvider(apiKey: 'k', botId: 'font-bot', config: const ConferBotConfig(autoConnect: false, enablePersistence: false));
  p.debugHandleChatbotData({
    'chatbotData': {
      'elements': [
        {'nodes': [], 'edges': []},
      ],
      'customizations': {'logoText': 'Acme', ...c},
    },
  });
  return p;
}

Future<void> _pump(WidgetTester tester, ConferBotProvider p) async {
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
      child: ChangeNotifierProvider.value(value: p, child: const ChatWidget()),
    ),
  ));
  await tester.pump();
  while (tester.takeException() != null) {}
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(minutes: 1));
  }
  while (tester.takeException() != null) {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _TempPaths(Directory.systemTemp.createTempSync('cb_font_').path);
    await StorageService.init();
  });

  testWidgets("the owner's font for the title, the text and the composer", (tester) async {
    final p = _provider({'font': 'Georgia'});
    expect(p.chatFont.body, 'Georgia');
    await _pump(tester, p);
    final title = tester.widget<Text>(find.text('Acme').first);
    expect(title.style?.fontFamily, 'Georgia');
    final field = tester.element(find.byType(TextField));
    expect(DefaultTextStyle.of(field).style.fontFamily, 'Georgia');
    expect(Theme.of(field).textTheme.titleMedium?.fontFamily, 'Georgia');
    await _finish(tester);
    p.dispose();
  });

  testWidgets("no font set: the app's own text styles stay", (tester) async {
    final p = _provider({});
    expect(p.chatFont.body, isNull);
    await _pump(tester, p);
    final field = tester.element(find.byType(TextField));
    expect(DefaultTextStyle.of(field).style.fontFamily, isNot('Georgia'));
    await _finish(tester);
    p.dispose();
  });
}
