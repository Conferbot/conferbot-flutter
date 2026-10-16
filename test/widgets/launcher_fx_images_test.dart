/// Frames of every launcher entrance, attention loop and idle call, to look
/// at against the React Native SDK and the web widget in Chrome:
/// LAUNCHERFX_IMAGES_DIR=/abs/dir flutter test --update-goldens test/widgets/launcher_fx_images_test.dart
/// writes one PNG per frame (a 390 x 844 screen, a 50px launcher 16px from
/// the corner, as the RN golden's cases) to that directory, never into the
/// repo. Without the variable the group is skipped.
library;

import 'dart:io';

import 'package:conferbot_flutter/src/core/customization/launcher_attention.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_entrance.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_idle_call.dart';
import 'package:conferbot_flutter/src/core/customization/mascot_art.dart';
import 'package:conferbot_flutter/src/widgets/launcher_fx_controllers.dart';
import 'package:conferbot_flutter/src/widgets/launcher_fx_views.dart';
import 'package:conferbot_flutter/src/widgets/launcher_icon_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final loader = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold']) {
    final f = File('$root/bin/cache/artifacts/material_fonts/Roboto-$w.ttf');
    if (f.existsSync()) loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  }
  await loader.load();
}

const _accent = '#4f46e5';
const _color = Color(0xFF4F46E5);
const _size = 50.0, _side = 16.0, _bottom = 16.0;
const _screen = Size(390, 844);

Widget _button() => Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(_size / 2), boxShadow: const [BoxShadow(color: _color, blurRadius: 4)]),
      child: Center(child: CustomPaint(size: const Size(35, 35), painter: LauncherIconPainter(iconId: null, ink: Colors.white, bg: _color))),
    );

Widget _card() => Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x220F172A), blurRadius: 18, offset: Offset(0, 6))]),
      child: const Text('Need a hand? Ask us anything.', style: TextStyle(fontFamily: 'Roboto', fontSize: 14, color: Color(0xFF0F172A))),
    );

/// A phone screen with the launcher in its corner and its effects at one moment.
Widget _scene(Key key, {required String position, EntrancePlan? plan, double t = 0, EntranceLook? look, AttentionFrame? attention, IdleCallPerformance? perf, String line = '', bool card = false}) {
  final left = position == 'left';
  final layers = perf == null ? null : mascotLayers(_accent, perf.mascot.arm);
  final launcherLeft = left ? _side : _screen.width - _side - _size;
  Widget? bubble;
  if (perf != null && perf.talks) {
    final v = evaluateBubble(perf, t);
    if (v != null) {
      final b = idleBubbleSize(line, 'Roboto');
      final want = launcherLeft + perf.sayX - b.width / 2;
      final l = want.clamp(8.0, _screen.width - b.width - 8);
      final tail = (perf.sayX - (l - launcherLeft)).clamp(14.0, b.width - 14);
      bubble = Positioned(
        left: l,
        bottom: _bottom + _size - (perf.sayY - 10),
        child: Opacity(
          opacity: v.$1,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(0, v.$2, 0, 1)
              ..scaleByDouble(v.$3, v.$4, 1, 1),
            child: IdleCallBubble(line: line, tail: tail, font: 'Roboto', onTap: () {}),
          ),
        ),
      );
    }
  }
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Center(
      child: RepaintBoundary(
        key: key,
        child: SizedBox.fromSize(
          size: _screen,
          child: ClipRect(
            child: Stack(clipBehavior: Clip.none, children: [
              const Positioned.fill(child: ColoredBox(color: Color(0xFFF4F6FA))),
              if (card)
                Positioned(
                  bottom: _bottom + _size + 12,
                  left: left ? _side : null,
                  right: left ? null : _side,
                  child: fxGreeting(_card(), look: look, attention: attention),
                ),
              Positioned(
                bottom: _bottom,
                left: left ? _side : null,
                right: left ? null : _side,
                child: FxLauncherStack(
                  button: _button(),
                  size: const Size(_size, _size),
                  radius: BorderRadius.circular(_size / 2),
                  color: _color,
                  plan: plan,
                  entranceT: t,
                  look: look,
                  attention: attention,
                  perf: perf,
                  layers: layers,
                  idleT: t,
                ),
              ),
              if (bubble != null) bubble,
            ]),
          ),
        ),
      ),
    ),
  );
}

void main() {
  final dir = Platform.environment['LAUNCHERFX_IMAGES_DIR'];

  group('launcher effect images', () {
    setUpAll(_loadFonts);

    Future<void> shot(WidgetTester tester, String name, Widget Function(Key) scene) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(scene(key));
      await tester.pump();
      await expectLater(find.byKey(key), matchesGoldenFile(Uri.file('$dir/$name.png')));
    }

    for (final position in ['right', 'left']) {
      for (final m in launcherEntrances) {
        if (m == 'classic') continue;
        if (position == 'left' && !['ufo', 'plane', 'meteor', 'magic'].contains(m)) continue;
        testWidgets('entrance $m $position', (tester) async {
          final stage = entranceStage(width: _size, height: _size, position: position, screenWidth: _screen.width, screenHeight: _screen.height, side: _side, bottom: _bottom, accent: _accent);
          final plan = entrancePlan(m, stage, 4242)!;
          final tl = entranceTimeline(plan);
          final c = LauncherEntranceController(clock: const RealFxScheduler())..plan = plan;
          c.phase = 'play';
          for (final f in [0.1, 0.25, 0.4, 0.55, 0.7, 0.9]) {
            final t = (tl.endAt * f).roundToDouble();
            await shot(tester, 'entrance-$m-$position-${t.toInt()}', (k) => _scene(k, position: position, plan: plan, t: t, look: c.lookAt(t), card: true));
          }
        });
      }
    }

    for (final m in launcherAttentions) {
      if (m == 'off') continue;
      testWidgets('attention $m', (tester) async {
        final tracks = attentionTracks(m);
        final period = tracks.first.options.duration;
        for (final f in [0.02, 0.05, 0.1, 0.15, 0.25, 0.35]) {
          final t = (attentionStartMs + period * f).roundToDouble();
          await shot(tester, 'attention-$m-${t.toInt()}', (k) => _scene(k, position: 'right', attention: attentionFrameAt(m, t), card: m == 'wave' || m == 'float'));
        }
      });
    }

    for (final (position, card) in [('right', false), ('left', false), ('right', true)]) {
      for (final m in launcherIdleCalls) {
        if (m == 'off') continue;
        if ((position == 'left' || card) && m != 'peek' && m != 'knock') continue;
        testWidgets('idle call $m $position${card ? ' card' : ''}', (tester) async {
          final perf = idleCallPerformance(m, idleCallGeometry(_size, _size, position, card));
          for (final f in [0.08, 0.2, 0.35, 0.5, 0.65, 0.85]) {
            final t = (perf.total * f).roundToDouble();
            await shot(tester, 'idle-$m-$position${card ? '-card' : ''}-${t.toInt()}',
                (k) => _scene(k, position: position, perf: perf, t: t, line: idleCallLine(m, null), card: card));
          }
        });
      }
    }
  }, skip: dir == null ? 'set LAUNCHERFX_IMAGES_DIR to write the images' : null);
}
