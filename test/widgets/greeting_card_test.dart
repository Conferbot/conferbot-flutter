import 'dart:io';

import 'package:conferbot_flutter/src/core/customization/greeting.dart';
import 'package:conferbot_flutter/src/widgets/greeting_card.dart';
import 'package:conferbot_flutter/src/widgets/greeting_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bot = {
  'chatIconCta': true,
  'chatIconCtaText': 'Hi there! Need a hand finding the right plan for your team?',
  'greetingDelay': 0,
  'logoText': 'Conferbot',
  'avatar': 'https://example.com/avatar.png',
  'headerBgColor': '#0808EE',
  'widgetIconBgColor': '#0808EE',
};

GreetingCardData _data(String style, {List<String> starters = const ['See pricing', 'Talk to sales'], bool firstShow = true}) {
  final c = {..._bot, 'greetingStyle': style};
  final g = Greeting.decide(c, const GreetingFacts(returning: false, signedIn: false))!;
  final d = GreetingCardData.from(c, g, firstShow: firstShow);
  return GreetingCardData(
    style: d.style, text: d.text, head: d.head, starters: starters, bubble: d.bubble, accent: d.accent,
    font: d.font, firstShow: d.firstShow, click: d.click, linkUrl: d.linkUrl,
  );
}

Widget _scene(Widget card, {Key? key}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: Container(
            width: 360,
            height: 330,
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)]),
            ),
            child: Stack(children: [
              // Something behind the translucent styles.
              const Positioned(left: 24, top: 60, child: Text('App content behind', style: TextStyle(fontFamily: 'Roboto', fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF6366F1), decoration: TextDecoration.none))),
              Positioned(right: 16, bottom: 16, child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: Color(0xFF0808EE), shape: BoxShape.circle))),
              Positioned(right: 16, bottom: 16 + 50 + 12, child: card),
            ]),
          ),
        ),
      ),
    );

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File(f);
      if (file.existsSync()) loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    }
    await loader.load();
  }

  final roboto = '$root/bin/cache/artifacts/material_fonts';
  await load('Roboto', ['Regular', 'Medium', 'Bold', 'Italic', 'MediumItalic', 'BoldItalic'].map((w) => '$roboto/Roboto-$w.ttf').toList());
  const sup = '/System/Library/Fonts/Supplemental';
  // The Android families the card asks for, with the nearest macOS files.
  await load('casual', ['$sup/Comic Sans MS.ttf', '$sup/Comic Sans MS Bold.ttf']);
  await load('serif', ['$sup/Georgia.ttf', '$sup/Georgia Italic.ttf', '$sup/Georgia Bold.ttf', '$sup/Georgia Bold Italic.ttf']);
  await load('monospace', ['$sup/Courier New.ttf', '$sup/Courier New Bold.ttf', '$sup/Courier New Italic.ttf']);
}

void main() {
  group('GreetingCard', () {
    testWidgets('a tap opens, the X dismisses, a chip sends', (tester) async {
      var pressed = 0, closed = 0;
      String? starter;
      await tester.pumpWidget(_scene(GreetingCard(
        data: _data('card'),
        reduceMotion: true,
        onPress: () => pressed++,
        onClose: () => closed++,
        onStarter: (s) => starter = s,
      )));
      expect(find.text(_bot['chatIconCtaText'] as String), findsOneWidget);
      expect(find.text('Conferbot'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      await tester.tap(find.text(_bot['chatIconCtaText'] as String));
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.tap(find.text('Talk to sales'));
      expect([pressed, closed, starter], [1, 1, 'Talk to sales']);
    });

    testWidgets('the phone text shows its dots, then the bubble and "Delivered"', (tester) async {
      await tester.pumpWidget(_scene(GreetingCard(data: _data('imessage'), onPress: () {}, onClose: () {}, onStarter: (_) {})));
      await tester.pump(const Duration(milliseconds: 200));
      final delivered = tester.widget<Opacity>(find.ancestor(of: find.text('Delivered'), matching: find.byType(Opacity)).first);
      expect(delivered.opacity, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<Opacity>(find.ancestor(of: find.text('Delivered'), matching: find.byType(Opacity)).first).opacity, 1);
      expect(find.text('Conferbot'), findsNothing); // no head
    });

    testWidgets('the typewriter types the message out', (tester) async {
      final d = _data('typewriter');
      await tester.pumpWidget(_scene(GreetingCard(data: d, onPress: () {}, onClose: () {}, onStarter: (_) {})));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(d.text, findRichText: true), findsNothing);
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining(d.text, findRichText: true), findsOneWidget);
    });

    testWidgets('the voice note times the message and the postcard sends greetings', (tester) async {
      await tester.pumpWidget(_scene(GreetingCard(data: _data('voice'), reduceMotion: true, onPress: () {}, onClose: () {}, onStarter: (_) {})));
      expect(find.text('0:05'), findsOneWidget); // 12 words / 2.4
      await tester.pumpWidget(_scene(GreetingCard(data: _data('postcard'), reduceMotion: true, onPress: () {}, onClose: () {}, onStarter: (_) {})));
      expect(find.text('Greetings from Conferbot'), findsOneWidget);
      await tester.pumpWidget(_scene(GreetingCard(data: _data('notification'), reduceMotion: true, onPress: () {}, onClose: () {}, onStarter: (_) {})));
      expect(find.text('now'), findsOneWidget);
    });

    testWidgets('every style lays out without overflow', (tester) async {
      for (final style in Greeting.styles) {
        await tester.pumpWidget(_scene(GreetingCard(key: ValueKey(style), data: _data(style), reduceMotion: true, onPress: () {}, onClose: () {}, onStarter: (_) {})));
        expect(tester.takeException(), isNull, reason: style);
        expect(tester.getSize(find.byType(GreetingCard)).width, GreetingCard.widthOf(style), reason: style);
      }
    });
  });

  group('GreetingController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GreetingController.resetSession();
    });

    testWidgets('shows after the delay, counts the visit, and rests after a tap', (tester) async {
      final g = GreetingController('bot1');
      g.update(customizations: {..._bot, 'greetingDelay': 2}, chatOpen: false);
      await tester.pump(const Duration(milliseconds: 10));
      expect(g.card, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(g.card?.style, 'imessage');
      expect(g.card?.firstShow, isTrue);
      g.closeForNow();
      expect(g.card, isNull);
      final prefs = await SharedPreferences.getInstance();
      final st = GreetingRecord.decode(prefs.getString('conferbot.greeting.bot1'));
      expect(st.visits, 1);
      expect(st.closedAt, isNotNull);
      expect(st.dismissed, isEmpty);
      // Resting on "every page": not again straight away.
      g.update(customizations: {..._bot}, chatOpen: false);
      await tester.pump(const Duration(seconds: 1));
      expect(g.card, isNull);
      g.dispose();
    });

    testWidgets('the X dismisses its rule; opening the chat marks chatted', (tester) async {
      final g = GreetingController('bot2');
      g.update(customizations: _bot, chatOpen: false);
      await tester.pump(const Duration(milliseconds: 10));
      expect(g.card, isNotNull);
      g.dismiss();
      g.update(customizations: _bot, chatOpen: true);
      await tester.pump(const Duration(milliseconds: 10));
      final st = GreetingRecord.decode((await SharedPreferences.getInstance()).getString('conferbot.greeting.bot2'));
      expect(st.dismissed.keys, [st.last]);
      expect(st.chatted, isTrue);
      g.dispose();
    });

    testWidgets('signed in means the visitor context has an id or email', (tester) async {
      final c = {
        ..._bot,
        'greetingRules': [
          {'matchType': 'contains', 'pattern': '/', 'text': 'Welcome back, customer', 'signedIn': 'yes'},
        ],
      };
      final g = GreetingController('bot3');
      g.update(customizations: c, chatOpen: false, visitorContext: const {'email': 'a@b.co'});
      await tester.pump(const Duration(milliseconds: 10));
      expect(g.card?.text, 'Welcome back, customer');
      g.dispose();
    });
  });

  // Images of the 11 styles: GREETING_GOLDEN_DIR=/abs/dir flutter test --update-goldens test/widgets/greeting_card_test.dart
  final goldenDir = Platform.environment['GREETING_GOLDEN_DIR'];
  group('GreetingCard images', () {
    setUpAll(_loadFonts);
    for (final style in Greeting.styles) {
      testWidgets(style, (tester) async {
        tester.view.physicalSize = const Size(720, 660);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(_scene(GreetingCard(data: _data(style), onPress: () {}, onClose: () {}, onStarter: (_) {}), key: key));
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await expectLater(find.byKey(key), matchesGoldenFile(Uri.file('$goldenDir/$style.png')));
      });
    }
  }, skip: goldenDir == null || goldenDir.isEmpty);
}
