/// The step cards (NodeRenderer and ui/widgets/*_step.dart) answer the
/// shared flow fixtures as a visitor would (#48, #72). Each fixture runs
/// three times:
///
/// 1. through the parity driver, recording the waiting step's UI state,
///    visit and refusal before every visitor action;
/// 2. in a widget test, each action is played on the step's card with
///    taps, typing and drags - the card is pumped again with the next UI
///    state of the same visit, as the chat does - and what the card sends
///    is kept;
/// 3. through the driver again with those answers in place of its own.
///
/// The outcome must still be the web's (path, ports, variables, answers,
/// errors...), and every action of a step with a card must come from it.
library;

import 'package:conferbot_flutter/src/core/nodes/node_ui_state.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/ui/widgets/address_step.dart' show addressDebounce;
import 'package:conferbot_flutter/src/ui/widgets/node_widgets.dart';
import 'package:flutter/material.dart' hide TextInputType;
import 'package:flutter_test/flutter_test.dart';

import '../parity/flow_driver.dart';
import '../parity/flows_test.dart' show compare;

class _Rec {
  final int index;
  final Map<String, dynamic> action;
  final dynamic ui;
  final int visit;
  final String? error;
  _Rec(this.index, this.action, this.ui, this.visit, this.error);
}

/// Actions no card sends: typed in the composer, a file picked, the clock.
const _notFromACard = {'text', 'file', 'skip', 'wait', 'navigateLink', 'navigateDone', 'check', 'date'};

Widget _host(dynamic ui, int visit, String? error, List<dynamic> sent) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: NodeRenderer(uiState: ui, onResponse: sent.add, theme: defaultTheme, stepKey: visit, error: error),
          ),
        ),
      ),
    );

Future<void> _tap(WidgetTester tester, Finder f) async {
  expect(f, findsOneWidget, reason: 'tap target $f');
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

Future<void> _type(WidgetTester tester, Finder f, String text) async {
  expect(f, findsOneWidget, reason: 'field $f');
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// Plays [a] on the card showing [ui]; false when no card answers this action.
Future<bool> _play(WidgetTester tester, Map<String, dynamic> a, dynamic ui, Map<String, dynamic> memo) async {
  final k = find.byKey;
  switch (a['do']) {
    case 'choose':
      if (ui is CarouselUIState) {
        final id = a['buttonId'];
        await _tap(tester, id == null ? k(const ValueKey('card-continue')) : k(ValueKey('card-btn-$id')));
        return true;
      }
      if (ui is ImageChoiceUIState) {
        final id = a['id'] ?? (a['index'] != null ? ui.images[(a['index'] as num).toInt()].id : null);
        await _tap(tester, k(ValueKey('img-$id')));
        return true;
      }
      return false;
    case 'consent':
      final want = a['agreed'] == true;
      if ((memo['agreed'] ?? false) != want) {
        await _tap(tester, k(const ValueKey('consent-box')));
        memo['agreed'] = want;
      }
      await _tap(tester, k(const ValueKey('consent-go')));
      return true;
    case 'slider':
      tester.widget<Slider>(k(const ValueKey('slider'))).onChanged!((a['value'] as num).toDouble());
      await tester.pump();
      await _tap(tester, k(const ValueKey('slider-go')));
      return true;
    case 'datetime':
      final v = '${a['value']}';
      final mode = (ui as CalendarUIState).mode;
      final date = mode == 'time' ? '' : v.split('T').first;
      final time = mode == 'date' ? '' : v.split('T').last;
      if (date.isNotEmpty) {
        await _tap(tester, k(const ValueKey('dt-date')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Switch to input'));
        await tester.pumpAndSettle();
        final p = date.split('-');
        await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), '${p[1]}/${p[2]}/${p[0]}');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      if (time.isNotEmpty) {
        await _tap(tester, k(const ValueKey('dt-time')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Switch to text input mode'));
        await tester.pumpAndSettle();
        final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
        final hm = time.split(':').map(int.parse).toList();
        // The picker follows the phone's 12 / 24 hour setting.
        final h12 = find.text('PM').evaluate().isNotEmpty;
        await tester.enterText(fields.at(0), h12 ? '${hm[0] % 12 == 0 ? 12 : hm[0] % 12}' : '${hm[0]}');
        await tester.enterText(fields.at(1), hm[1].toString().padLeft(2, '0'));
        if (h12) await tester.tap(find.text(hm[0] < 12 ? 'AM' : 'PM'));
        await tester.pump();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      await _tap(tester, k(const ValueKey('dt-go')));
      return true;
    case 'calendar':
      final date = '${a['date']}';
      final p = date.split('-').map(int.parse).toList();
      for (var guard = 0; guard < 24; guard++) {
        final title = tester.widget<Text>(k(const ValueKey('cal-title'))).data!;
        final parts = title.split(' ');
        final shown = int.parse(parts[1]) * 12 + _months.indexOf(parts[0]);
        final want = p[0] * 12 + p[1] - 1;
        if (shown == want) break;
        await _tap(tester, k(ValueKey(shown < want ? 'cal-next' : 'cal-prev')));
      }
      await _tap(tester, k(ValueKey('cal-day-$date')));
      if (a['slot'] != null) await _tap(tester, k(ValueKey('cal-slot-${a['slot']}')));
      return true;
    case 'rankingMove':
      await _tap(tester, k(ValueKey('rank-${(a['dir'] as num) < 0 ? 'up' : 'down'}-${a['id']}')));
      return true;
    case 'rankingSubmit':
      await _tap(tester, k(const ValueKey('rank-go')));
      return true;
    case 'matrix':
      final multiple = (ui as MatrixUIState).mode == 'multiple';
      final on = memo.putIfAbsent('cells', () => <String, Set<String>>{}) as Map<String, Set<String>>;
      for (final e in (a['cells'] as Map).entries) {
        final cols = e.value is List ? (e.value as List).map((c) => '$c').toList() : ['${e.value}'];
        for (final col in multiple ? cols : [cols.last]) {
          final row = on.putIfAbsent('${e.key}', () => <String>{});
          if (row.contains(col)) continue;
          await _tap(tester, k(ValueKey('mx-${e.key}-$col')));
          if (!multiple) row.clear();
          row.add(col);
        }
      }
      if (a['submit'] != false) await _tap(tester, k(const ValueKey('mx-go')));
      return true;
    case 'otpEmail':
      if (find.byKey(const ValueKey('otp-email')).evaluate().isEmpty) await _tap(tester, k(const ValueKey('otp-change')));
      await _type(tester, k(const ValueKey('otp-email')), '${a['email']}');
      await _tap(tester, k(const ValueKey('otp-send')));
      return true;
    case 'otpCode':
      final code = '${a['code']}';
      await _type(tester, k(const ValueKey('otp-code')), code);
      // Six digits send on their own; fewer need Verify.
      if (code.length != 6) await _tap(tester, k(const ValueKey('otp-verify')));
      return true;
    case 'otpSkip':
      await _tap(tester, k(const ValueKey('otp-skip')));
      return true;
    case 'addressSearch':
      await _type(tester, k(const ValueKey('ad-input')), '${a['q']}');
      await tester.pump(addressDebounce + const Duration(milliseconds: 50));
      return true;
    case 'addressPick':
      await _tap(tester, k(ValueKey('ad-opt-${a['index']}')));
      await _tap(tester, k(const ValueKey('ad-confirm')));
      return true;
    case 'addressManual':
      if (find.byKey(const ValueKey('ad-m-line1')).evaluate().isEmpty) await _tap(tester, k(const ValueKey('ad-manual')));
      for (final f in const ['line1', 'city', 'region', 'postal', 'country']) {
        await _type(tester, k(ValueKey('ad-m-$f')), a[f] == null ? '' : '${a[f]}');
      }
      await _tap(tester, k(const ValueKey('ad-manual-go')));
      return true;
    case 'signTyped':
      if (a['fullName'] != null && find.byKey(const ValueKey('sig-name')).evaluate().isNotEmpty) {
        await _type(tester, k(const ValueKey('sig-name')), '${a['fullName']}');
      }
      if (find.byKey(const ValueKey('sig-typed')).evaluate().isEmpty) await _tap(tester, k(const ValueKey('sig-mode')));
      await _type(tester, k(const ValueKey('sig-typed')), '${a['name']}');
      await _tap(tester, k(const ValueKey('sig-go')));
      return true;
    case 'signEmpty':
      // Sign with nothing on the pad.
      await _tap(tester, k(const ValueKey('sig-go')));
      return true;
    case 'payOpen':
      await _tap(tester, k(const ValueKey('pay-open')));
      return true;
    case 'payCancel':
      await _tap(tester, k(const ValueKey('pay-cancel')));
      return true;
  }
  return false;
}

/// The fixtures with at least one action a card answers.
List<String> _cardFixtures() {
  const cardActions = {
    'consent', 'slider', 'datetime', 'calendar', 'rankingMove', 'rankingSubmit', 'matrix', 'otpEmail', 'otpCode', 'otpSkip',
    'addressSearch', 'addressPick', 'addressManual', 'signTyped', 'signEmpty', 'payOpen', 'payCancel',
  };
  final out = <String>[];
  for (final c in fixtureIndex()) {
    final file = '${c['file'] ?? '${c['id']}.json'}';
    final fx = loadFixture(file);
    final types = {for (final n in fx['flow']['nodes'] as List) n['id']: n['type']};
    final inputs = (fx['inputs'] as List? ?? const []).cast<Map<String, dynamic>>();
    if (inputs.any((a) =>
        cardActions.contains(a['do']) ||
        (a['do'] == 'choose' && const {'carousel-node', 'product-card-node', 'image-choice-node'}.contains(types[a['at']])))) {
      out.add(file);
    }
  }
  return out;
}

void main() {
  for (final file in _cardFixtures()) {
    testWidgets('cards answer $file as the web', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fx = loadFixture(file);

      // 1. What each action finds waiting.
      final recs = <_Rec>[];
      await tester.runAsync(() => runFixture(fx, answer: (i, a, ui, visit, error) {
            recs.add(_Rec(i, a, ui, visit, error));
            return null;
          }));

      // 2. The actions played on the cards.
      final answers = <int, ({dynamic response, bool local})>{};
      final notAnswered = <String>[];
      int? shownVisit;
      final memo = <String, dynamic>{};
      for (final r in recs) {
        if (r.visit != shownVisit) memo.clear();
        final sent = <dynamic>[];
        await tester.pumpWidget(_host(r.ui, r.visit, r.error, sent));
        shownVisit = r.visit;
        final played = await _play(tester, r.action, r.ui, memo);
        if (!played) {
          if (!_notFromACard.contains(r.action['do']) && r.action['do'] != 'choose') notAnswered.add('${r.action['do']}');
          continue;
        }
        expect(sent.length, lessThanOrEqualTo(1), reason: 'input ${r.index} (${r.action['do']}) sent $sent');
        answers[r.index] = sent.isEmpty ? (response: null, local: true) : (response: sent.single, local: false);
      }
      await tester.pumpWidget(const SizedBox());
      expect(notAnswered, isEmpty, reason: 'actions no card answered');
      expect(answers, isNotEmpty);

      // 3. The run with the cards' answers.
      final result = await tester.runAsync(() => runFixture(fx, answer: (i, a, ui, visit, error) => answers[i]));
      final diffs = [...result!.problems.map((p) => 'problem: $p'), ...compare(fx, result.outcome)];
      expect(diffs, isEmpty, reason: diffs.join('\n'));
    });
  }
}
