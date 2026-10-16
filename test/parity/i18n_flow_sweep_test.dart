/// Every flow fixture run under "de" (RN __tests__/components/i18nSweep.test.tsx,
/// its flow part; Android I18nFlowSweepTest): every step card the engine
/// hands the chat is drawn (NodeRenderer, with the reason an answer was
/// refused), and with the bubbles it rendered must hold no English table
/// value the German table words differently. The fixture's own strings
/// (the owner's flow, the server's answers, the visitor's input) are taken
/// out first: what the owner wrote is shown as written. The record's own
/// values (the survey and queue texts) stay English, as the web stores
/// them, and are not drawn from here.
library;

import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/ui/widgets/node_widgets.dart';
import 'package:flutter/material.dart' hide TextInputType;
import 'package:flutter_test/flutter_test.dart';

import '../i18n_sweep.dart';
import 'flow_driver.dart';

Widget _host(dynamic ui, int visit, String? error) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: NodeRenderer(uiState: ui, onResponse: (_) {}, theme: defaultTheme, stepKey: visit, error: error),
        ),
      ),
    );

void main() {
  setUp(() => I18n.setWidgetLanguage('de', const []));
  tearDown(I18n.debugReset);

  for (final c in fixtureIndex()) {
    final file = '${c['file']}';
    testWidgets('no English under German: ${c['id']}', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fx = loadFixture(file);
      final owner = ownerStrings([fx['flow'], fx['server'], fx['inputs'], fx['customizations']]);

      final seen = <(dynamic, int, String?)>[];
      final result = await tester.runAsync(() => runFixture(fx, answer: (i, a, ui, visit, error) {
            seen.add((ui, visit, error));
            return null;
          }));

      final drawn = <String>{};
      for (final r in (result!.outcome['rendered'] as List? ?? const [])) {
        final plain = '${(r as Map)['plain'] ?? ''}'.trim();
        if (plain.isNotEmpty) drawn.add(plain);
      }
      for (final (ui, visit, error) in seen) {
        if (error != null) drawn.add(error);
        if (ui == null) continue;
        await tester.pumpWidget(_host(ui, visit, error));
        await tester.pump();
        drawn.addAll(drawnStrings(tester));
      }
      await tester.pumpWidget(const SizedBox());
      expect(englishIn(drawn, owner), isEmpty, reason: '${c['id']}');
    });
  }

  test('the check sees English', () {
    expect(englishIn([I18n.tFor('en', 'validation.email')]), isNotEmpty);
    expect(englishIn([I18n.tFor('en', 'otp.sentTo', {'n': 6, 'email': 'a@b.co'})]), isNotEmpty);
    expect(englishIn([I18n.tFor('de', 'validation.email')]), isEmpty);
    expect(englishIn(['Please enter a valid email address'], ['Please enter a valid email address']), isEmpty);
  });
}
