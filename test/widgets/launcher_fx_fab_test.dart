// The launcher with an entrance, an attention loop and an idle call turned on:
// it is held hidden, arrives, loops, and the mascot calls with its bubble.
import 'dart:async';

import 'package:conferbot_flutter/src/providers/conferbot_provider.dart';
import 'package:conferbot_flutter/src/widgets/conferbot_fab.dart';
import 'package:conferbot_flutter/src/widgets/launcher_fx_controllers.dart';
import 'package:conferbot_flutter/src/widgets/launcher_fx_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ConferBotProvider _provider(Map<String, dynamic> customizations) {
  final p = ConferBotProvider(apiKey: 'k', botId: 'fx', config: const ConferBotConfig(autoConnect: false, enablePersistence: false));
  p.debugHandleChatbotData({
    'chatbotData': {'workspaceId': 'w1', 'customizations': customizations},
  });
  return p;
}

Widget _host(ConferBotProvider p, {bool reduced = false}) => MediaQuery(
      data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduced),
      child: MaterialApp(
        home: ChangeNotifierProvider<ConferBotProvider>.value(
          value: p,
          child: const ConferBotFAB(child: SizedBox.expand()),
        ),
      ),
    );

double _launcherOpacity(WidgetTester tester) {
  final stack = find.byType(FxLauncherStack);
  final ops = tester.widgetList<Opacity>(find.descendant(of: stack, matching: find.byType(Opacity)));
  return ops.isEmpty ? 1 : ops.first.opacity;
}

class _T implements FxTimer {
  final Timer t;
  _T(this.t);
  @override
  void cancel() => t.cancel();
}

/// The test binding's fake clock and timers.
class _TestClock implements FxScheduler {
  final TestWidgetsFlutterBinding binding;
  _TestClock(this.binding);
  @override
  int now() => binding.clock.now().millisecondsSinceEpoch;
  @override
  FxTimer after(int ms, void Function() fn) => _T(Timer(Duration(milliseconds: ms), fn));
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LauncherFxSession.reset();
    LauncherFxSession.scheduler = _TestClock(binding);
  });
  tearDown(() => LauncherFxSession.scheduler = const RealFxScheduler());

  testWidgets('holds the launcher for its entrance, then the mascot calls', (tester) async {
    final p = _provider({'launcherEntrance': 'drop', 'launcherAttention': 'heartbeat', 'launcherIdleCall': 'knock', 'launcherIdleCallDelay': 5});
    await tester.pumpWidget(_host(p));
    await tester.pump();
    expect(find.byType(FxLauncherStack), findsOneWidget);
    expect(_launcherOpacity(tester), 0);
    // The drop lands within 3s: the launcher is there.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(LauncherFxSession.entrancePlayed['fx'], 'drop');
    expect(_launcherOpacity(tester), 1);
    // 5s in, the mascot knocks and says so.
    var said = false;
    for (var i = 0; i < 60 && !said; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      said = find.text('Knock knock!').evaluate().isNotEmpty;
    }
    expect(said, isTrue);
    expect(LauncherFxSession.visits['fx']!.n, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('nothing plays with the phone’s animations off', (tester) async {
    final p = _provider({'launcherEntrance': 'drop', 'launcherIdleCall': 'knock', 'launcherIdleCallDelay': 5});
    await tester.pumpWidget(_host(p, reduced: true));
    await tester.pump();
    expect(_launcherOpacity(tester), 1);
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(LauncherFxSession.entrancePlayed, isEmpty);
    expect(find.text('Knock knock!'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
