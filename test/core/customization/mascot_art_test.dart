// The owner's mascot (art3d.ts mascot(), mascotLookOf, mascotScaleOf), as the
// React Native SDK's core/mascotArt.ts draws it: test/fixtures/
// mascot_art.json holds, for 367 looks (every character in every arm pose,
// as a bust and in the owner's colour; every eye and accessory on five
// characters; junk), the first 16 hex digits of each layer's SHA-256 as RN
// drew it (tool/mascot_art_fixture.sh). Every layer here must be the same
// markup, character for character. Ported from RN __tests__/core/mascot.test.ts
// and conferbot-android's MascotArtTest.
import 'dart:convert';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:conferbot_flutter/src/core/customization/mascot_art.dart';
import 'package:flutter_test/flutter_test.dart';

final _fixture = jsonDecode(File('test/fixtures/mascot_art.json').readAsStringSync()) as Map<String, dynamic>;

String _hash(String s) => sha256.convert(utf8.encode(s)).toString().substring(0, 16);

MascotLook? _lookOf(Map<String, dynamic>? m) => m == null
    ? null
    : MascotLook(
        shape: m['shape'] as String? ?? 'blob',
        eyes: m['eyes'] as String? ?? 'round',
        accessory: m['accessory'] as String? ?? 'none',
        color: m['color'] as String? ?? '',
      );

/// Well-formed markup: every tag closed in order, attributes quoted, nothing between the tags.
bool _wellFormed(String xml) {
  final stack = <String>[];
  final re = RegExp(r'<(/?)([a-zA-Z]+)((?:\s+[a-zA-Z0-9:-]+="[^"<>]*")*)\s*(/?)>');
  var at = 0;
  for (final m in re.allMatches(xml)) {
    if (xml.substring(at, m.start).trim().isNotEmpty) return false;
    at = m.end;
    if (m.group(1)!.isNotEmpty) {
      if (stack.isEmpty || stack.removeLast() != m.group(2)) return false;
    } else if (m.group(4)!.isEmpty) {
      stack.add(m.group(2)!);
    }
  }
  return at == xml.length && stack.isEmpty;
}

void main() {
  test('draws every look as the React Native SDK does, layer by layer', () {
    final cases = (_fixture['cases'] as List).cast<Map<String, dynamic>>();
    final wrong = <String>[];
    var layers = 0;
    for (final c in cases) {
      final l = mascotLayers(c['accent'] as String, c['arm'] as String, _lookOf(c['look'] as Map<String, dynamic>?), c['bust'] == true);
      final want = c['layers'] as Map<String, dynamic>;
      expect(l.ordered.map((e) => e.$1).toList(), mascotLayerOrder);
      for (final (name, svg) in l.ordered) {
        final w = want[name] as String?;
        if ((svg == null) != (w == null) || (svg != null && _hash(svg) != w)) wrong.add('${c['look']} ${c['arm']} bust=${c['bust']}: $name');
        if (svg != null) {
          layers += 1;
          expect(_wellFormed(svg), isTrue, reason: '$name not well formed');
          expect(RegExp(r'style=|class=|filter=|color-mix|undefined|NaN|null').hasMatch(svg), isFalse, reason: name);
        }
      }
    }
    expect(cases.length, 367);
    expect(wrong, isEmpty, reason: '${wrong.length} layers differ, e.g. ${wrong.take(5)}');
    expect(layers, greaterThan(3500));
  });

  test('turns each part about the joints RN has, the lids at the character\'s eyes', () {
    final origins = (_fixture['origins'] as Map).cast<String, dynamic>();
    for (final shape in mascotShapes) {
      final o = mascotOrigins(MascotLook(shape: shape));
      for (final part in ['body', 'arm', 'lid', 'look', 'brow']) {
        final want = (origins[shape] as Map)[part] as List;
        expect(o[part]!.$1, closeTo((want[0] as num).toDouble(), 1e-9), reason: '$shape $part x');
        expect(o[part]!.$2, closeTo((want[1] as num).toDouble(), 1e-9), reason: '$shape $part y');
      }
    }
    expect(mascotBlobOrigins.body, (50.0, 94.0));
    expect(mascotBlobOrigins.lid, (50.0, 39.0));
    expect(mascotBlobOrigins.look, (50.0, 54.0));
    expect(mascotBlobOrigins.brow, (50.0, 36.0));
    // The car's eyes are high and small: eyeY 40, scale 0.62.
    expect(mascotOrigins(const MascotLook(shape: 'car')).lid.$2, closeTo(40 - 13 * 0.62, 1e-9));
    // The bust's 92 x 96 viewBox fitted in a square box.
    expect(mascotPoint((4, 0), 96, true), (2.0, 0.0));
    expect(mascotPoint((50, 94), 100), (50.0, 94.0));
    expect(mascotUnit(96, true), closeTo(1, 1e-12));
  });

  test('defaults to the classic blob and keeps only known values', () {
    expect(mascotLookOf(null), const MascotLook());
    expect(mascotLookOf({'mascotShape': 'dragon', 'mascotEyes': 'laser', 'mascotAccessory': 'cape', 'mascotColor': 'red', 'mascotName': 42}), const MascotLook());
    expect(
      mascotLookOf({'mascotShape': 'fox', 'mascotEyes': 'star', 'mascotAccessory': 'crown', 'mascotColor': ' #F97316 ', 'mascotName': '  Pip   the  fox, the friendliest one '}),
      const MascotLook(shape: 'fox', eyes: 'star', accessory: 'crown', color: '#F97316', name: 'Pip the fox, the fri'),
    );
  });

  test('sizes the launcher mascot 70-150% of the button, 112 when unset', () {
    expect(mascotScaleOf({}), 112);
    expect(mascotScaleOf({'mascotLauncherScale': null}), 112);
    expect(mascotScaleOf({'mascotLauncherScale': ''}), 112);
    expect(mascotScaleOf({'mascotLauncherScale': 'big'}), 112);
    expect(mascotScaleOf({'mascotLauncherScale': 10}), 70);
    expect(mascotScaleOf({'mascotLauncherScale': 999}), 150);
    expect(mascotScaleOf({'mascotLauncherScale': '120.4'}), 120);
    expect(mascotScaleOf({'mascotLauncherScale': 130.0}), 130);
  });

  test('has 27 characters, each with its own name', () {
    expect(mascotShapes, hasLength(27));
    for (final s in mascotShapes) {
      expect(mascotDefaultNames[s], isNotEmpty, reason: s);
    }
  });

  test('paints the owner\'s colour, cloud and ghost paler, a tooth pearly', () {
    expect(mascotColorOf(const MascotLook(shape: 'cat', color: '#ff0000'), '#0000ff'), '#ff0000');
    expect(mascotColorOf(const MascotLook(shape: 'cat'), '#0000ff'), '#0000ff');
    expect(mascotColorOf(const MascotLook(shape: 'cloud'), '#000000'), mixColor('#000000', 45, '#ffffff'));
    expect(mascotColorOf(const MascotLook(shape: 'ghost'), '#000000'), mixColor('#000000', 22, '#ffffff'));
    expect(mascotColorOf(const MascotLook(shape: 'tooth'), '#000000'), mixColor('#000000', 12, '#ffffff'));
    // The body in the owner's colour, the pupils' rim in the launcher's.
    final l = mascotLayers('#000000', 'down', const MascotLook(color: '#ff0000'));
    expect(l.body, contains('stop-color="#ff0000"'));
    expect(l.look, contains(mixColor('#000000', 45, '#0b1020')));
  });

  test('keeps the arm behind or in front by its pose, and the bust bare', () {
    expect(mascotLayers('#4f46e5', 'knock').armFront, contains('<svg'));
    expect(mascotLayers('#4f46e5', 'knock').armBack, isNull);
    expect(mascotLayers('#4f46e5', 'wave').armBack, contains('<svg'));
    final cat = mascotLayers('#4f46e5', 'wave', const MascotLook(shape: 'cat'));
    expect(cat.tail, contains('<path'));
    final bust = mascotLayers('#4f46e5', 'wave', const MascotLook(shape: 'cat'), true);
    expect([bust.shadow, bust.tail, bust.armBack, bust.armFront], [null, null, null, null]);
    expect(bust.body, contains('viewBox="4 0 92 96"'));
    expect(cat.body.length, greaterThan(bust.body.length));
    // Sleepy lids, shades, glasses, a crown; a robot's LED eyes without whites; an industry prop in its own paints.
    expect(mascotLayers('#4f46e5', 'down', const MascotLook(eyes: 'sleepy')).face, contains('<path'));
    expect(mascotLayers('#4f46e5', 'down').face, isNull);
    expect(mascotLayers('#4f46e5', 'down', const MascotLook(eyes: 'shades')).cover, contains('#0b1020'));
    expect(mascotLayers('#4f46e5', 'down', const MascotLook(accessory: 'glasses')).top, contains('stroke="#1f2937"'));
    expect(mascotLayers('#4f46e5', 'down', const MascotLook(accessory: 'crown')).top, contains('#facc15'));
    final robot = mascotLayers('#4f46e5', 'down', const MascotLook(shape: 'robot'));
    expect(robot.body, isNot(contains('url(#me)')));
    expect(robot.cover, isNull);
    final medic = mascotLayers('#4f46e5', 'down', const MascotLook(shape: 'medic')).top!;
    expect(medic, allOf(contains('url(#mr)'), contains('id="mr"')));
    expect(mascotLayers('#4f46e5', 'down', const MascotLook(shape: 'owl')).body.startsWith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'), isTrue);
    expect(_wellFormed('<svg><g></svg>'), isFalse);
  });
}
