/// Images of the owner's mascot (#81, #50), to look at against the React
/// Native SDK and the web widget:
/// MASCOT_IMAGES_DIR=/abs/dir flutter test --update-goldens test/widgets/mascot_images_test.dart
/// writes, to that directory and never into the repo: every character (the
/// whole figure waving, and the bust), every eye and accessory, moods
/// mid-move (a blink, a wave, think, the happy hop), the launcher's mascot
/// style closed and cheering, the greeting card's mascot in three styles
/// as it greets, the typing mascot and pencil, and the idle call in an
/// owner's mascot. Without the variable the group is skipped.
library;

import 'dart:io';

import 'package:conferbot_flutter/src/core/customization/greeting.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_idle_call.dart';
import 'package:conferbot_flutter/src/core/customization/mascot_art.dart';
import 'package:conferbot_flutter/src/core/customization/mascot_moods.dart';
import 'package:conferbot_flutter/src/widgets/greeting_card.dart';
import 'package:conferbot_flutter/src/widgets/greeting_controller.dart';
import 'package:conferbot_flutter/src/widgets/launcher_fx_views.dart';
import 'package:conferbot_flutter/src/widgets/mascot/launcher_mascot.dart';
import 'package:conferbot_flutter/src/widgets/mascot/mascot_view.dart';
import 'package:conferbot_flutter/src/widgets/typing_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';

/// Roboto from the Flutter SDK, and macOS files for the card's casual / serif / monospace (as greeting_card_test.dart).
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

  await load('Roboto', ['Regular', 'Medium', 'Bold', 'Italic'].map((w) => '$root/bin/cache/artifacts/material_fonts/Roboto-$w.ttf').toList());
  const sup = '/System/Library/Fonts/Supplemental';
  await load('casual', ['$sup/Comic Sans MS.ttf', '$sup/Comic Sans MS Bold.ttf']);
  await load('serif', ['$sup/Georgia.ttf', '$sup/Georgia Italic.ttf', '$sup/Georgia Bold.ttf']);
  await load('monospace', ['$sup/Courier New.ttf', '$sup/Courier New Bold.ttf']);
}

const _accent = '#4f46e5';

/// One mascot, still, in a pose (a mood at a moment).
Widget _figure(MascotLook look, {String arm = 'down', bool bust = false, double size = 96, MascotPose pose = const MascotPose()}) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: MascotPainter(mascotLayers(_accent, arm, look, bust), ValueNotifier(pose), bust: bust, joints: mascotOrigins(look), shadowY: look.shape == 'ghost' ? 99 : 95)),
    );

Widget _label(String s) => Text(s, style: const TextStyle(fontFamily: 'Roboto', fontSize: 11, color: Color(0xFF334155)));

Widget _sheet(Key key, Size size, Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: Material(
              color: const Color(0xFFF4F6FA),
              child: Container(width: size.width, height: size.height, padding: const EdgeInsets.all(12), child: child),
            ),
          ),
        ),
      ),
    );

GreetingCardData _card(String style, String shape) {
  final c = {
    'chatIconCta': true,
    'chatIconCtaText': 'Hi there, how can we help you today?',
    'greetingDelay': 0,
    'logoText': 'Conferbot',
    'headerBgColor': '#4f46e5',
    'widgetIconBgColor': '#4f46e5',
    'greetingStyle': style,
    'mascotInGreeting': true,
    'mascotShape': shape,
    'mascotName': 'Pip',
  };
  return GreetingCardData.from(c, Greeting.decide(c, const GreetingFacts(returning: false, signedIn: false))!);
}

void main() {
  final dir = Platform.environment['MASCOT_IMAGES_DIR'];

  group('mascot images', () {
    setUpAll(_loadFonts);

    Future<void> shot(WidgetTester tester, String name, Size size, Widget child, {List<Duration> pumps = const []}) async {
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(_sheet(key, size, child));
      await tester.pump();
      for (final p in pumps) {
        await tester.pump(p);
      }
      await expectLater(find.byKey(key), matchesGoldenFile(Uri.file('$dir/$name.png')));
    }

    testWidgets('every character, waving and as a bust', (tester) async {
      await shot(
        tester,
        'characters',
        const Size(840, 980),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in mascotShapes)
            SizedBox(
              width: 112,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [_figure(MascotLook(shape: s), arm: 'wave', size: 72), _figure(MascotLook(shape: s), bust: true, size: 40)]),
                _label('$s (${mascotDefaultNames[s]})'),
              ]),
            ),
        ]),
      );
    });

    testWidgets('eyes and accessories', (tester) async {
      await shot(
        tester,
        'eyes-accessories',
        const Size(620, 460),
        Column(children: [
          Row(children: [for (final e in mascotEyes) Column(children: [_figure(MascotLook(shape: 'cat', eyes: e), size: 110), _label(e)])]),
          Row(children: [for (final a in mascotAccessories) Column(children: [_figure(MascotLook(accessory: a, color: '#F97316'), size: 84), _label(a)])]),
          Row(children: [for (final s in ['robot', 'laptop', 'ghost']) for (final e in ['round', 'happy', 'star']) Column(children: [_figure(MascotLook(shape: s, eyes: e), size: 64), _label('$s $e')])]),
        ]),
      );
    });

    testWidgets('moods mid-move', (tester) async {
      MascotPose at(String mood, double t, {String arm = 'down', double wave = double.infinity}) => moodPose(moodPlan(mood, arm: arm, waveCount: wave), t);
      final frames = <(String, MascotLook, String, MascotPose)>[
        ('blink', const MascotLook(), 'down', at('idle', 6400 * 0.426)),
        ('wave-up 24%', const MascotLook(shape: 'fox'), 'down', at('wave', 3200 * 0.24)),
        ('wave 60%', const MascotLook(shape: 'bear'), 'wave', at('wave', 2800 * 0.6, arm: 'wave', wave: 2)),
        ('think 25%', const MascotLook(shape: 'owl'), 'down', at('think', 800)),
        ('think glance', const MascotLook(shape: 'owl'), 'down', at('think', 4800 * 0.25)),
        ('happy hop 45%', const MascotLook(shape: 'bunny'), 'down', at('happy', 900 * 0.45)),
        ('happy land 70%', const MascotLook(shape: 'bunny'), 'down', at('happy', 900 * 0.7)),
        ('reduced happy', const MascotLook(shape: 'chef'), 'down', moodPose(moodPlan('happy', reduced: true), 0)),
      ];
      await shot(
        tester,
        'moods',
        const Size(560, 300),
        Wrap(spacing: 10, runSpacing: 6, children: [
          for (final (name, look, arm, pose) in frames) Column(mainAxisSize: MainAxisSize.min, children: [_figure(look, arm: arm, size: 120, pose: pose), _label(name)]),
        ]),
      );
    });

    testWidgets('the launcher\'s mascot style, closed and cheering', (tester) async {
      Widget button(MascotLook look, int scale, {int unread = 0}) => Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0xFF4F46E5), blurRadius: 4)]),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(30), child: MascotButtonLight(light: mixColor('#4f46e5', 14, '#ffffff')))),
              LauncherMascot(look: look, accent: _accent, scale: scale, box: const Size(60, 60), unread: unread, chatOpen: false),
            ]),
          );
      await shot(
        tester,
        'launcher',
        const Size(480, 130),
        Row(children: [
          button(const MascotLook(), 112),
          button(const MascotLook(shape: 'cat', accessory: 'headset'), 130),
          button(const MascotLook(shape: 'robot'), 90),
          button(const MascotLook(shape: 'tooth', color: '#0ea5e9'), 150),
        ]),
        pumps: const [Duration(milliseconds: 300)],
      );
    });

    for (final (style, shape) in [('card', 'cat'), ('note', 'piggy'), ('glass', 'medic')]) {
      testWidgets('greeting card $style with its mascot', (tester) async {
        for (final ms in [200, 500, 1100, 2400]) {
          await shot(
            tester,
            'greeting-$style-$shape-$ms',
            const Size(340, 230),
            Align(alignment: Alignment.bottomRight, child: GreetingCard(data: _card(style, shape), onPress: () {}, onClose: () {}, onStarter: (_) {})),
            pumps: [Duration(milliseconds: ms)],
          );
        }
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('typing: the mascot and the pencil', (tester) async {
      Widget bubble(Widget child, {bool mascot = false}) => Container(
            height: mascot ? 42 : 36,
            constraints: const BoxConstraints(minWidth: 70),
            padding: mascot ? const EdgeInsets.only(left: 6, right: 12) : const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFF4F46E5), borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(6))),
            child: child,
          );
      for (final ms in [300, 1100]) {
        await shot(
          tester,
          'typing-$ms',
          const Size(300, 120),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            bubble(const TypingIndicator(style: 'mascot', mascot: MascotLook(shape: 'fox', name: 'Pip'), accent: '#0ea5e9', dotColor: Colors.white), mascot: true),
            const SizedBox(height: 10),
            bubble(const TypingIndicator(style: 'pencil', accent: '#fbbf24', dotColor: Colors.white)),
          ]),
          pumps: [Duration(milliseconds: ms)],
        );
      }
    });

    testWidgets('the idle call in the owner\'s mascot', (tester) async {
      for (final (m, look) in [('peek', const MascotLook(shape: 'fox', eyes: 'happy')), ('knock', const MascotLook(shape: 'robot')), ('wave', const MascotLook(shape: 'dino', accessory: 'crown'))]) {
        final perf = idleCallPerformance(m, idleCallGeometry(50, 50, 'right', false));
        final layers = mascotLayers(_accent, perf.mascot.arm, look);
        await shot(
          tester,
          'idle-$m-${look.shape}',
          const Size(420, 150),
          Row(children: [
            for (final f in [0.25, 0.45, 0.65])
              SizedBox(
                width: 130,
                height: 120,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: 60,
                    top: 50,
                    width: 50,
                    height: 50,
                    child: Stack(clipBehavior: Clip.none, children: [
                      if (!perf.front) Positioned.fill(child: CustomPaint(painter: IdleCallPainter(perf, layers, perf.total * f, look))),
                      Container(decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle)),
                      if (perf.front) Positioned.fill(child: CustomPaint(painter: IdleCallPainter(perf, layers, perf.total * f, look))),
                    ]),
                  ),
                ]),
              ),
          ]),
        );
      }
    });
  }, skip: dir == null ? 'set MASCOT_IMAGES_DIR to write the images' : null);
}
