/// Images of the step cards, to look at against the web widget and iOS:
/// STEP_IMAGES_DIR=/abs/dir flutter test --update-goldens test/widgets/step_views_images_test.dart
/// writes one PNG per card to that directory (never into the repo). Roboto
/// comes from the Flutter SDK. Without the variable the group is skipped.
library;

import 'dart:io';

import 'package:conferbot_flutter/src/core/nodes/node_ui_state.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/ui/widgets/node_widgets.dart';
import 'package:flutter/material.dart' hide TextInputType;
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final loader = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold', 'Italic']) {
    final f = File('$root/bin/cache/artifacts/material_fonts/Roboto-$w.ttf');
    if (f.existsSync()) loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  }
  await loader.load();
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)))).load();
  }
}

final _theme = defaultTheme.copyWith(
  colors: defaultTheme.colors.copyWith(primary: const Color(0xFF0B4EB8), optionBubble: const Color(0xFFE8EEFB), optionBubbleText: const Color(0xFF0B2E6B)),
);

Widget _scene(Widget card, Key key) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        body: SingleChildScrollView(
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: 390,
              color: const Color(0xFFF4F6FA),
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              child: card,
            ),
          ),
        ),
      ),
    );

NodeRenderer _r(dynamic ui, {String? error}) => NodeRenderer(uiState: ui, onResponse: (_) {}, theme: _theme, stepKey: 1, error: error);

void main() {
  final dir = Platform.environment['STEP_IMAGES_DIR'];

  group('step card images', () {
    setUpAll(_loadFonts);

    Future<void> shot(WidgetTester tester, String name, Widget card, [Future<void> Function()? act]) async {
      tester.view.physicalSize = const Size(780, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(_scene(card, key));
      await tester.pump();
      if (act != null) await act();
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(find.byKey(key), matchesGoldenFile(Uri.file('$dir/$name.png')));
    }

    testWidgets('signature drawn', (tester) async {
      await shot(
        tester,
        'signature-drawn',
        _r(const TextInputUIState(
          questionText: '',
          nodeId: 's',
          inputType: TextInputType.text,
          extra: {'step': 'signature', 'allowTyped': true, 'requireName': true, 'submitLabel': 'Sign', 'consentText': 'By signing you accept the [Terms](https://example.com).'},
        )),
        () async {
          final pad = tester.getRect(find.byKey(const ValueKey('sig-pad')));
          final g = await tester.startGesture(pad.topLeft + const Offset(40, 90));
          for (var i = 0; i <= 40; i++) {
            await g.moveTo(pad.topLeft + Offset(40 + i * 5.0, 90 - 30 * (i % 10 < 5 ? (i % 5) / 5 : 1 - (i % 5) / 5)));
          }
          await g.up();
          await tester.enterText(find.byKey(const ValueKey('sig-name')), 'Ana Lima');
        },
      );
    });

    testWidgets('signature typed', (tester) async {
      await shot(
        tester,
        'signature-typed',
        _r(const TextInputUIState(questionText: '', nodeId: 's', inputType: TextInputType.text, extra: {'step': 'signature', 'allowTyped': true, 'submitLabel': 'Sign'}),
            error: 'Type your full name to sign.'),
        () async {
          await tester.tap(find.byKey(const ValueKey('sig-mode')));
          await tester.pump();
          await tester.enterText(find.byKey(const ValueKey('sig-typed')), 'Ana Lima');
        },
      );
    });

    testWidgets('otp email', (tester) async {
      await shot(tester, 'otp-email',
          _r(const TextInputUIState(questionText: '', nodeId: 'o', inputType: TextInputType.email, extra: {'step': 'otp', 'stage': 'email', 'allowSkip': true, 'skipLabel': 'Skip'})));
    });

    testWidgets('otp code', (tester) async {
      await shot(
        tester,
        'otp-code',
        _r(const TextInputUIState(questionText: '', nodeId: 'o', inputType: TextInputType.number, extra: {'step': 'otp', 'stage': 'code', 'sentTo': 'a***@acme.io', 'resendIn': 27}),
            error: "That code isn't right. 2 tries left."),
        () async => tester.enterText(find.byKey(const ValueKey('otp-code')), '1234'),
      );
    });

    const results = [
      {'formatted': 'Marina Walk, Dubai Marina, Dubai, United Arab Emirates', 'lat': 25.0805, 'lng': 55.1403},
      {'formatted': 'Marina Walk Tower, Dubai Marina, Dubai, United Arab Emirates', 'lat': 25.08, 'lng': 55.14},
    ];

    testWidgets('address suggestions', (tester) async {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(780, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_scene(_r(const AddressUIState(nodeId: 'a', extra: {'showMap': true})), key));
      await tester.enterText(find.byKey(const ValueKey('ad-input')), 'marina walk');
      await tester.pump(const Duration(milliseconds: 400));
      // The step answers the search with its matches, as the engine does.
      await tester.pumpWidget(_scene(_r(AddressUIState(nodeId: 'a', results: results, extra: const {'showMap': true})), key));
      await tester.pump();
      await expectLater(find.byKey(key), matchesGoldenFile(Uri.file('$dir/address-suggestions.png')));
    });

    testWidgets('address map', (tester) async {
      await shot(tester, 'address-map', _r(const AddressUIState(nodeId: 'a', results: results, extra: {'showMap': true})), () async {
        await tester.tap(find.byKey(const ValueKey('ad-opt-0')));
      });
    });

    testWidgets('address manual', (tester) async {
      await shot(tester, 'address-manual', _r(const AddressUIState(nodeId: 'a')), () async {
        await tester.tap(find.byKey(const ValueKey('ad-manual')));
        await tester.pump();
        await tester.enterText(find.byKey(const ValueKey('ad-m-line1')), '1 Main St');
      });
    });

    testWidgets('consent', (tester) async {
      await shot(
        tester,
        'consent',
        _r(const SingleChoiceUIState(nodeId: 'c', choices: [], extra: {
          'step': 'consent',
          'required': true,
          'markdown': 'I agree to the [Terms](https://example.com/terms) and [Privacy Policy](https://example.com/privacy).',
          'continueLabel': 'Continue',
        }), error: 'Please tick the box to continue.'),
      );
    });

    testWidgets('matrix', (tester) async {
      await shot(
        tester,
        'matrix',
        _r(const MatrixUIState(
          nodeId: 'm',
          rows: [ChoiceOption(id: 'r0', text: 'Ease of use'), ChoiceOption(id: 'r1', text: 'Speed'), ChoiceOption(id: 'r2', text: 'Support')],
          columns: [ChoiceOption(id: 'c0', text: 'Poor'), ChoiceOption(id: 'c1', text: 'Fair'), ChoiceOption(id: 'c2', text: 'Good'), ChoiceOption(id: 'c3', text: 'Great')],
        ), error: 'Answer every row - 1 left'),
        () async {
          await tester.tap(find.byKey(const ValueKey('mx-r0-c3')));
          await tester.tap(find.byKey(const ValueKey('mx-r1-c2')));
        },
      );
    });

    testWidgets('payment', (tester) async {
      await shot(
        tester,
        'payment',
        _r(const PaymentUIState(nodeId: 'p', paymentUrl: 'https://checkout.stripe.com/x', extra: {
          'productName': 'Setup fee',
          'description': 'One-time onboarding',
          'amountText': '\$25.00',
          'waiting': true,
          'buttons': [
            {'id': 'open', 'label': 'Pay now · \$25.00'},
            {'id': 'check', 'label': "I've paid"},
            {'id': 'cancel', 'label': 'Cancel'},
          ],
        })),
      );
    });

    testWidgets('carousel', (tester) async {
      await shot(
        tester,
        'carousel',
        _r(const CarouselUIState(nodeId: 'k', cards: [
          CarouselCard(id: 'a', title: 'Starter', price: '\$9 / mo', description: 'For one site', buttons: [
            CarouselButton(id: 'b1', label: 'Choose'),
            CarouselButton(id: 'b2', label: 'Details', url: 'https://www.conferbot.com/pricing'),
          ]),
          CarouselCard(id: 'b', title: 'Pro', price: '\$29 / mo', description: 'For teams', buttons: [CarouselButton(id: 'b3', label: 'Choose')]),
        ])),
      );
    });

    testWidgets('image choice', (tester) async {
      await shot(
        tester,
        'image-choice',
        _r(const ImageChoiceUIState(nodeId: 'i', images: [
          ImageChoiceOption(id: 'i1', label: 'Beach', imageUrl: ''),
          ImageChoiceOption(id: 'i2', label: 'Mountains', imageUrl: ''),
          ImageChoiceOption(id: 'i3', label: 'City', imageUrl: ''),
        ])),
      );
    });

    testWidgets('ranking', (tester) async {
      await shot(
        tester,
        'ranking',
        _r(const RankingUIState(nodeId: 'r', items: [
          ChoiceOption(id: 'a', text: 'Price'),
          ChoiceOption(id: 'b', text: 'Speed'),
          ChoiceOption(id: 'c', text: 'Support'),
        ], submitLabel: 'Submit')),
      );
    });

    testWidgets('slider', (tester) async {
      await shot(tester, 'slider', _r(const SliderUIState(nodeId: 's', min: 0, max: 100, step: 5, defaultValue: 40, unit: 'kg')));
    });

    testWidgets('datetime', (tester) async {
      await shot(tester, 'datetime',
          _r(const CalendarUIState(nodeId: 'd', mode: 'datetime', extra: {'datetime': true, 'note': 'Closed on Saturdays and Sundays', 'submitLabel': 'Send'})));
    });

    testWidgets('calendar slots', (tester) async {
      await shot(
        tester,
        'calendar-slots',
        CalendarStepWidget(
          state: const CalendarUIState(
            nodeId: 'c',
            mode: 'datetime',
            showTimeSelection: true,
            availableSlots: {'2026-10-19': ['09:00', '09:30', '10:00'], '2026-10-20': ['09:00'], '2026-10-21': ['09:30', '14:00']},
            extra: {'minDate': '2026-10-16'},
          ),
          onResponse: (_) {},
          primaryColor: const Color(0xFF0B4EB8),
          theme: _theme,
          today: DateTime(2026, 10, 16),
        ),
        () async {
          await tester.tap(find.byKey(const ValueKey('cal-day-2026-10-21')));
        },
      );
    });
  }, skip: dir == null || dir.isEmpty);
}
