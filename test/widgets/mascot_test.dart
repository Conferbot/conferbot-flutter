// The owner's mascot drawn (#81, #50): Mascot in its moods, the launcher's
// mascot style (a happy hop when a reply lands while closed), the greeting
// card's mascot in place of the avatar (by its name, waving, the card moving
// as the owner chose and leaving), the mascot and pencil typing styles
// ("Pip is typing"), the idle call in the owner's mascot, and the home's
// mascot spot given the owner's mascot.
import 'package:conferbot_flutter/src/core/customization/greeting.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_idle_call.dart';
import 'package:conferbot_flutter/src/core/customization/mascot_art.dart';
import 'package:conferbot_flutter/src/core/home/home.dart';
import 'package:conferbot_flutter/src/providers/conferbot_provider.dart';
import 'package:conferbot_flutter/src/widgets/conferbot_fab.dart';
import 'package:conferbot_flutter/src/widgets/greeting_card.dart';
import 'package:conferbot_flutter/src/widgets/greeting_controller.dart';
import 'package:conferbot_flutter/src/widgets/home/home_screen_view.dart';
import 'package:conferbot_flutter/src/widgets/launcher_fx_views.dart';
import 'package:conferbot_flutter/src/widgets/mascot/launcher_mascot.dart';
import 'package:conferbot_flutter/src/widgets/mascot/mascot_view.dart';
import 'package:conferbot_flutter/src/widgets/mascot/typing_mascot.dart';
import 'package:conferbot_flutter/src/widgets/typing_indicator.dart';
import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

MascotPose _pose(WidgetTester tester, Finder of) {
  final paint = tester.widget<CustomPaint>(find.descendant(of: of, matching: find.byKey(const ValueKey('cb-mascot'))));
  return (paint.painter! as MascotPainter).pose.value;
}

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduced),
        child: Scaffold(body: Center(child: child)),
      ),
    );

const _bot = {
  'chatIconCta': true,
  'chatIconCtaText': 'Hi there, how can we help you today?',
  'greetingDelay': 0,
  'logoText': 'Conferbot',
  'avatar': 'https://example.com/avatar.png',
  'headerBgColor': '#0808EE',
  'widgetIconBgColor': '#0808EE',
};

GreetingCardData _card(Map<String, dynamic> extra) {
  final c = {..._bot, ...extra};
  final g = Greeting.decide(c, const GreetingFacts(returning: false, signedIn: false))!;
  return GreetingCardData.from(c, g);
}

ConferBotProvider _provider(Map<String, dynamic> customizations) {
  final p = ConferBotProvider(apiKey: 'k', botId: 'mascot', config: const ConferBotConfig(autoConnect: false, enablePersistence: false));
  p.debugHandleChatbotData({
    'chatbotData': {'workspaceId': 'w1', 'customizations': customizations},
  });
  return p;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Mascot', () {
    testWidgets('blinks now and then, thinks, and is still with animations off', (tester) async {
      await tester.pumpWidget(_app(const Mascot(look: MascotLook(shape: 'owl'), accent: '#4f46e5', mood: 'think')));
      final m = find.byType(Mascot);
      expect(_pose(tester, m).parts.keys, containsAll(['lid', 'body', 'look', 'brow']));
      // The bob at a quarter of its lap: up and tilted.
      await tester.pump(const Duration(milliseconds: 800));
      expect(_pose(tester, m).parts['body']!.v.ty, lessThan(0));
      // The blink closes the lids at 42.6% of its 6.4s.
      await tester.pump(const Duration(milliseconds: 6400 * 426 ~/ 1000 - 800));
      expect(_pose(tester, m).parts['lid']!.v.sy, greaterThan(0.9));
      await tester.pumpWidget(_app(const Mascot(look: MascotLook(shape: 'owl'), accent: '#4f46e5', mood: 'happy'), reduced: true));
      final still = _pose(tester, find.byType(Mascot));
      expect(still.parts, isEmpty);
      // The happy smile is not motion: it stays.
      expect(still.grin, isTrue);
    });
  });

  group('the launcher\'s mascot style', () {
    testWidgets('the bust at its scale, lifted, on the light button; a reply while closed: a happy hop for 2.4s', (tester) async {
      Widget at(int unread, {bool open = false}) => _app(LauncherMascot(look: const MascotLook(shape: 'fox'), accent: '#0ea5e9', scale: 130, box: const Size(50, 50), unread: unread, chatOpen: open));
      await tester.pumpWidget(at(0));
      final box = find.byKey(const ValueKey('cb-launcher-mascot'));
      final fig = find.descendant(of: box, matching: find.byType(Mascot));
      expect(tester.getSize(fig), const Size(65, 65));
      // Centred, lifted: its top 0.56 of its height above the button's middle.
      final off = tester.getTopLeft(fig) - tester.getTopLeft(box);
      expect([off.dx, off.dy], [closeTo(25 - 32.5, 1e-9), closeTo(25 - 65 * 0.56, 1e-9)]);
      expect(_pose(tester, box).grin, isFalse);
      await tester.pumpWidget(at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final hop = _pose(tester, box);
      expect(hop.grin, isTrue);
      expect(hop.parts['body']!.v.ty, lessThan(0));
      // The bust has no arm to cheer with.
      expect(hop.parts['arm'], isNull);
      await tester.pump(const Duration(milliseconds: 2400));
      expect(_pose(tester, box).grin, isFalse);
      // Open, the reply makes no hop.
      await tester.pumpWidget(at(2, open: true));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_pose(tester, box).grin, isFalse);
    });

    testWidgets('the launcher draws the owner\'s mascot in place of the icon', (tester) async {
      final p = _provider({'launcherStyle': 'mascot', 'mascotShape': 'robot', 'mascotLauncherScale': 120, 'widgetIconBgColor': '#0ea5e9'});
      await tester.pumpWidget(MaterialApp(home: ChangeNotifierProvider<ConferBotProvider>.value(value: p, child: const ConferBotFAB(child: SizedBox.expand()))));
      await tester.pump();
      final lm = tester.widget<LauncherMascot>(find.byType(LauncherMascot));
      expect([lm.look.shape, lm.scale, lm.accent], ['robot', 120, '#0ea5e9']);
      expect(find.byType(MascotButtonLight), findsOneWidget);
      // Another style: no mascot, no light.
      final icon = _provider({'launcherStyle': 'icon', 'mascotShape': 'robot'});
      await tester.pumpWidget(MaterialApp(home: ChangeNotifierProvider<ConferBotProvider>.value(value: icon, child: const ConferBotFAB(child: SizedBox.expand()))));
      await tester.pump();
      expect(find.byType(LauncherMascot), findsNothing);
      expect(find.byType(MascotButtonLight), findsNothing);
    });
  });

  group('the greeting card\'s mascot', () {
    testWidgets('greets in place of the avatar, by its name, waving twice; the words fade up; the dot pings', (tester) async {
      final data = _card({'mascotInGreeting': true, 'mascotShape': 'cat', 'mascotName': 'Pip', 'greetingStyle': 'card'});
      expect(data.head.avatar, isNull);
      expect(data.head.name, 'Pip');
      expect(data.mascot!.accent, '#0808EE');
      await tester.pumpWidget(_app(GreetingCard(data: data, onPress: () {}, onClose: () {}, onStarter: (_) {})));
      final m = find.byKey(const ValueKey('cb-greet-mascot'));
      expect(m, findsOneWidget);
      final mascot = tester.widget<Mascot>(m);
      expect([mascot.mood, mascot.arm, mascot.waveCount, mascot.size], ['wave', 'wave', 2, 40]);
      expect(find.text('Pip'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      // The words are each their own text, fading up; all of them up within a second.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Hi '), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
      final words = tester.widgetList<Opacity>(find.ancestor(of: find.text('today?'), matching: find.byType(Opacity)));
      expect(words.every((o) => o.opacity > 0.99), isTrue);
      expect(find.bySemanticsLabel(RegExp('how can we help you today')), findsWidgets);
      // The arm waves while the card is up.
      expect(_pose(tester, m).parts['arm'], isNotNull);
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('leaving: hands off toward the launcher and collapses, then gone; the x bows and fades', (tester) async {
      final data = _card({'mascotInGreeting': true, 'greetingStyle': 'card'});
      var gone = 0;
      Widget card(String? leaving) => _app(GreetingCard(data: data, launcher: const Size(50, 50), leaving: leaving, onGone: () => gone++, onPress: () {}, onClose: () {}, onStarter: (_) {}));
      await tester.pumpWidget(card(null));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(card('open'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(gone, 0);
      // Taps no longer land on a card that is going.
      expect(find.descendant(of: find.byType(GreetingCard), matching: find.byType(IgnorePointer)), findsWidgets);
      await tester.pump(const Duration(milliseconds: 200));
      expect(gone, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('motion off: no spring, no words, no wave of the card\'s figure', (tester) async {
      final data = _card({'mascotInGreeting': true, 'mascotMotion': 'off', 'greetingStyle': 'card'});
      expect(data.motion, 'off');
      await tester.pumpWidget(_app(GreetingCard(data: data, onPress: () {}, onClose: () {}, onStarter: (_) {})));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Hi there, how can we help you today?'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('typing: the mascot and pencil styles (#50)', () {
    testWidgets('the mascot sways by its three dots, "Pip is typing"', (tester) async {
      await tester.pumpWidget(_app(const TypingIndicator(style: 'mascot', mascot: MascotLook(shape: 'bear', name: 'Pip'), accent: '#0ea5e9')));
      expect(find.byType(TypingMascot), findsOneWidget);
      expect(find.descendant(of: find.byType(TypingIndicator), matching: find.byType(FadeTransition)), findsNothing);
      expect(find.bySemanticsLabel('Pip is typing'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(Transform), findsWidgets);
      await tester.pumpWidget(_app(const TypingIndicator(style: 'mascot')));
      expect(find.bySemanticsLabel('Agent is typing'), findsOneWidget);
    });

    testWidgets('the pencil writes its line', (tester) async {
      await tester.pumpWidget(_app(const TypingIndicator(style: 'pencil', accent: '#0ea5e9')));
      expect(find.byType(TypingPencil), findsOneWidget);
      expect(find.descendant(of: find.byType(TypingIndicator), matching: find.byType(FadeTransition)), findsNothing);
      expect(tester.getSize(find.byType(TypingPencil)), const Size(44, 16));
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pumpWidget(_app(const TypingIndicator(style: 'pencil'), reduced: true));
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.byType(TypingPencil), findsOneWidget);
    });
  });

  group('the idle call and the home', () {
    test('the idle call draws the owner\'s mascot about its own joints', () {
      final perf = idleCallPerformance('peek', idleCallGeometry(50, 50, 'right', false));
      final look = const MascotLook(shape: 'car');
      final p = IdleCallPainter(perf, mascotLayers('#4f46e5', perf.mascot.arm, look), perf.total / 2, look);
      final rec = PictureRecorder();
      p.paint(Canvas(rec), const Size(50, 50));
      rec.endRecording();
      expect(p.shouldRepaint(IdleCallPainter(perf, p.layers, p.t)), isTrue);
    });

    testWidgets('the home\'s mascot spot is given the owner\'s mascot', (tester) async {
      HomeMascot? got;
      final m = homeModel(c: {'enableInitialPage': true, 'mascotShape': 'heart', 'mascotName': 'Hope', 'headerBgColor': '#123456'})!;
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
          child: HomeScreenView(
            model: m,
            palette: classicHomePalette,
            hasAgent: false,
            rawArticles: const [],
            onClose: () {},
            onShowChat: ([_]) {},
            onOpenArticle: (_) {},
            onShowHelp: ([_]) {},
            onOpenRequests: ([_]) {},
            mascotBuilder: (context, mascot) {
              got = mascot;
              return Mascot(look: mascot.look, accent: mascot.accent, mood: 'wave');
            },
          ),
        ),
      ));
      expect([got!.look.shape, got!.look.name, got!.accent], ['heart', 'Hope', '#123456']);
      expect(find.byType(Mascot), findsOneWidget);
    });
  });
}
