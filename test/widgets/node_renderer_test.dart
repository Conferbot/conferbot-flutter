/// The step cards the chat draws (NodeRenderer): each sends the answer in
/// the shape the step handlers read (#48, #55). The step's question is its
/// own chat line, so no card repeats it.
library;

import 'package:conferbot_flutter/src/core/nodes/node_ui_state.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/ui/widgets/node_widgets.dart';
import 'package:flutter/material.dart' hide TextInputType;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<dynamic> answers;

  Future<void> pump(WidgetTester tester, dynamic state) async {
    answers = [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: NodeRenderer(uiState: state, onResponse: answers.add, theme: defaultTheme),
        ),
      ),
    ));
  }

  testWidgets('buttons send the picked id, label and value; the question is not repeated', (tester) async {
    await pump(
      tester,
      const SingleChoiceUIState(
        questionText: 'Pick one',
        choices: [ChoiceOption(id: '1', text: 'One', value: 'One'), ChoiceOption(id: 'u2', text: 'Two', value: 'Two')],
        nodeId: 'c',
      ),
    );
    expect(find.text('Pick one'), findsNothing);
    await tester.tap(find.text('Two'));
    expect(answers.single, {'buttonId': 'u2', 'label': 'Two', 'value': 'Two'});
  });

  testWidgets('ticked options send their ids', (tester) async {
    await pump(
      tester,
      const MultipleChoiceUIState(
        options: [SelectOption(id: 'a', text: 'A'), SelectOption(id: 'b', text: 'B'), SelectOption(id: 'c', text: 'C')],
        nodeId: 'n',
      ),
    );
    await tester.tap(find.text('C'));
    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    expect((answers.single as Map)['buttonIds'], unorderedEquals(['a', 'c']));
  });

  testWidgets('a dropdown option, a rating and an image choice (#55)', (tester) async {
    await pump(tester, const DropdownUIState(options: [SelectOption(id: 'x', text: 'Ex')], nodeId: 'd'));
    await tester.tap(find.byType(DropdownButtonFormField<SelectOption>).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ex').last);
    expect((answers.single as Map)['buttonId'], 'x');

    await pump(tester, const RatingUIState(ratingType: RatingType.number, maxValue: 5, nodeId: 'r'));
    await tester.tap(find.text('4'));
    expect((answers.single as Map)['value'], 4);

    await pump(
      tester,
      const ImageChoiceUIState(images: [ImageChoiceOption(id: 'i1', label: 'Cat', imageUrl: '')], nodeId: 'i'),
    );
    await tester.tap(find.text('Cat'));
    expect((answers.single as Map)['buttonId'], 'i1');
  });

  testWidgets('a carousel path button sends its id and card; Continue when there is none (#48)', (tester) async {
    await pump(
      tester,
      const CarouselUIState(
        cards: [
          CarouselCard(id: 'k1', title: 'Plan A', buttons: [CarouselButton(id: 'b1', label: 'Choose')]),
        ],
        nodeId: 'car',
      ),
    );
    await tester.tap(find.text('Choose'));
    expect(answers.single, {'buttonId': 'b1', 'cardId': 'k1', 'label': 'Choose'});

    await pump(tester, const CarouselUIState(cards: [CarouselCard(id: 'k', title: 'Info')], showContinue: true, nodeId: 'car'));
    await tester.tap(find.text('Continue'));
    expect((answers.single as Map)['action'], 'continue');
  });

  testWidgets('a slider sends its value on the step (#48)', (tester) async {
    await pump(tester, const SliderUIState(min: 0, max: 10, step: 1, defaultValue: 3, unit: 'kg', nodeId: 's'));
    expect(find.text('3 kg'), findsOneWidget);
    await tester.tap(find.text('Send'));
    expect(answers.single, {'value': 3, 'label': '3 kg'});
  });

  testWidgets('a ranking sends the order after a move (#48)', (tester) async {
    await pump(
      tester,
      const RankingUIState(items: [ChoiceOption(id: 'a', text: 'A'), ChoiceOption(id: 'b', text: 'B')], nodeId: 'rk'),
    );
    await tester.tap(find.byTooltip('Move A down'));
    await tester.pump();
    await tester.tap(find.text('Send'));
    expect((answers.single as Map)['order'], ['b', 'a']);
  });

  testWidgets('a matrix sends one column per row (#48)', (tester) async {
    await pump(
      tester,
      const MatrixUIState(
        rows: [ChoiceOption(id: 'r1', text: 'Speed'), ChoiceOption(id: 'r2', text: 'Price')],
        columns: [ChoiceOption(id: 'c1', text: 'Good'), ChoiceOption(id: 'c2', text: 'Bad')],
        nodeId: 'm',
      ),
    );
    await tester.tap(find.text('Good').first);
    await tester.tap(find.text('Bad').last);
    await tester.pump();
    await tester.tap(find.text('Submit'));
    expect((answers.single as Map)['cells'], {'r1': 'c1', 'r2': 'c2'});
  });

  testWidgets('an address typed by hand (#48)', (tester) async {
    await pump(tester, const AddressUIState(nodeId: 'ad'));
    await tester.tap(find.text('Enter it manually'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('ad-m-line1')), '1 Main St');
    await tester.enterText(find.byKey(const ValueKey('ad-m-city')), 'Austin');
    await tester.tap(find.text('Confirm'));
    final a = answers.single as Map;
    expect([a['action'], a['line1'], a['city']], ['manual', '1 Main St', 'Austin']);
  });

  testWidgets("the payment step's buttons send their action (#48)", (tester) async {
    await pump(
      tester,
      const PaymentUIState(
        paymentUrl: '',
        buttonLabel: 'Pay now',
        nodeId: 'p',
        extra: {
          'buttons': [
            {'id': 'check', 'label': "I've paid"},
            {'id': 'cancel', 'label': 'Cancel'},
          ],
        },
      ),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect((answers.single as Map)['action'], 'cancel');
  });

  testWidgets('a calendar day and slot; a date step sends one value', (tester) async {
    await pump(
      tester,
      const CalendarUIState(
        mode: 'datetime',
        showTimeSelection: true,
        availableSlots: {'2026-10-21': ['09:30']},
        nodeId: 'cal',
        extra: {'minDate': '2026-10-15'},
      ),
    );
    expect(find.text('October 2026'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cal-day-2026-10-20')));
    expect(answers, isEmpty, reason: 'a day without free times');
    await tester.tap(find.byKey(const ValueKey('cal-day-2026-10-21')));
    await tester.pump();
    await tester.tap(find.text('09:30'));
    expect((answers.single as Map)['date'], '2026-10-21');
    expect((answers.single as Map)['slot'], '09:30');

    await pump(tester, const CalendarUIState(mode: 'time', showTimeSelection: true, nodeId: 'dt', extra: {'datetime': true}));
    expect(find.text('Choose a date'), findsNothing);
    expect(find.text('Choose a time'), findsOneWidget);
  });

  testWidgets('consent: the box, then Continue (#48)', (tester) async {
    await pump(
      tester,
      const SingleChoiceUIState(choices: [], nodeId: 'cs', extra: {'step': 'consent', 'markdown': 'I agree to the [Terms](https://x.io/t).'}),
    );
    expect(find.textContaining('Terms', findRichText: true), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('consent-box')));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    expect((answers.single as Map)['agreed'], true);
  });

  testWidgets('signature: strokes on the pad go out as a PNG (#48)', (tester) async {
    await pump(tester, const TextInputUIState(questionText: '', nodeId: 'sg', inputType: TextInputType.text, extra: {'step': 'signature', 'submitLabel': 'Sign'}));
    final pad = tester.getRect(find.byKey(const ValueKey('sig-pad')));
    await tester.dragFrom(pad.center - const Offset(60, 0), const Offset(120, 20));
    await tester.pump();
    await tester.tap(find.text('Sign'));
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && answers.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    final a = answers.single as Map;
    expect([a['action'], a['method']], ['sign', 'drawn']);
    expect('${a['dataUrl']}', startsWith('data:image/png;base64,'));
    expect(a['width'], greaterThan(0));
  });

  testWidgets('otp: six digits send the code; Resend waits for its countdown (#48)', (tester) async {
    await pump(tester, const TextInputUIState(questionText: '', nodeId: 'o', inputType: TextInputType.number, extra: {'step': 'otp', 'stage': 'code', 'resendIn': 2}));
    expect(find.text('Resend in 0:02'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('otp-code')), '12 34 56');
    expect(answers.single, {'action': 'verify', 'code': '123456', 'label': '123456'});
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Resend code'), findsOneWidget);
  });

  testWidgets('a text step leaves its answer to the composer, with Skip when allowed', (tester) async {
    await pump(tester, const TextInputUIState(questionText: 'Email?', inputType: TextInputType.email, nodeId: 't'));
    expect(find.text('Email?'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    await pump(
      tester,
      const TextInputUIState(questionText: 'Code', inputType: TextInputType.number, nodeId: 'o', extra: {'allowSkip': true}),
    );
    await tester.tap(find.text('Skip'));
    expect(answers.single, {'action': 'skip'});
  });
}
