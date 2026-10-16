// Auto-open on the launcher (core/customization/auto_open.dart,
// widgets/conferbot_fab.dart; RN FloatingWidget/ConferBotWidget.tsx): the
// chat opens on its own after the owner's delay, once per app launch, not
// for a visitor with a conversation, not within 2 minutes of a close.
import 'dart:io';

import 'package:conferbot_flutter/src/providers/conferbot_provider.dart';
import 'package:conferbot_flutter/src/services/storage_service.dart';
import 'package:conferbot_flutter/src/widgets/chat_widget.dart';
import 'package:conferbot_flutter/src/widgets/conferbot_fab.dart';
import 'package:conferbot_flutter/src/widgets/launcher_fx_controllers.dart';
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

ConferBotProvider _provider(Map<String, dynamic> customizations) {
  final p = ConferBotProvider(apiKey: 'k', botId: 'auto', config: const ConferBotConfig(autoConnect: false, enablePersistence: false));
  p.debugHandleChatbotData({
    'chatbotData': {'workspaceId': 'w1', 'customizations': customizations},
  });
  return p;
}

Widget _host(ConferBotProvider p) => MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
      child: MaterialApp(
        home: ChangeNotifierProvider<ConferBotProvider>.value(
          value: p,
          child: const ConferBotFAB(child: SizedBox.expand()),
        ),
      ),
    );

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
    PathProviderPlatform.instance = _TempPaths(Directory.systemTemp.createTempSync('cb_auto_').path);
    await StorageService.init();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LauncherFxSession.reset();
    AutoOpenSession.reset();
  });

  testWidgets("opens after the owner's delay, once per launch", (tester) async {
    final p = _provider({'botAutoOpen': true, 'botAutoOpenDelay': 3});
    await tester.pumpWidget(_host(p));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byType(ChatWidget), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ChatWidget), findsOneWidget);
    expect(AutoOpenSession.opened, isTrue);
    while (tester.takeException() != null) {}
    // Closed: it stays shut, and the launch has had its one.
    Navigator.of(tester.element(find.byType(ChatWidget))).pop();
    await tester.pump(const Duration(seconds: 1));
    expect(AutoOpenSession.closedAt, isNotNull);
    await _finish(tester);
    await tester.pumpWidget(_host(_provider({'botAutoOpen': true})));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(ChatWidget), findsNothing);
    await _finish(tester);
  });

  testWidgets('stays shut when off, or within 2 minutes of a close', (tester) async {
    await tester.pumpWidget(_host(_provider({'botAutoOpen': false})));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(ChatWidget), findsNothing);
    await _finish(tester);
    AutoOpenSession.closedAt = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(_host(_provider({'botAutoOpen': true})));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(ChatWidget), findsNothing);
    await _finish(tester);
  });
}
