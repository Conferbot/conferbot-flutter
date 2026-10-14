import 'package:conferbot_flutter/src/core/customization/chat_background.dart';
import 'package:conferbot_flutter/src/core/customization/svg_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is a white solid by default and reads the type in any case', () {
    expect(ChatBackgrounds.resolve({}), const SolidBackground('#ffffff'));
    expect(ChatBackgrounds.resolve({'chatBgType': 'Gradient'}), isA<GradientBackground>());
    expect(ChatBackgrounds.resolve({'chatBgType': 'Image', 'chatBgImg': 'https://x/bg.jpg'}), isA<ImageBackground>());
  });

  test('reads gradient stops, angle and style', () {
    expect(ChatBackgrounds.gradientStops({}), ['#fffcf1', '#1b55f3']);
    expect(ChatBackgrounds.gradientStops({'chatBgGradientStops': ['#111', 'bogus(', '#222', '#333', '#444', '#555']}), ['#111', '#222', '#333', '#444']);
    final g = ChatBackgrounds.resolve({'chatBgType': 'gradient', 'chatBgGradientAngle': 400, 'chatBgGradientStyle': 'mesh'}) as GradientBackground;
    expect(g.angle, 360);
    expect(g.style, 'mesh');
    expect((ChatBackgrounds.resolve({'chatBgType': 'gradient', 'chatBgGradientStyle': 'nope'}) as GradientBackground).style, 'linear');
  });

  test('masks images only when an opacity is set and refuses script urls', () {
    expect((ChatBackgrounds.resolve({'chatBgType': 'image', 'chatBgImg': 'https://x/bg.jpg'}) as ImageBackground).maskColor, isNull);
    final m = ChatBackgrounds.resolve({'chatBgType': 'image', 'chatBgImg': 'https://x/bg.jpg', 'chatBgMaskOpacity': 95, 'chatBgMaskColor': '#123456'}) as ImageBackground;
    expect(m.maskColor, '#123456');
    expect(m.maskAlpha, closeTo(0.9, 0.001));
    expect(ChatBackgrounds.resolve({'chatBgType': 'image', 'chatBgImg': 'javascript:alert(1)'}), const SolidBackground('#ffffff'));
  });

  test('reads patterns with the web defaults and has every tile', () {
    final p = ChatBackgrounds.resolve({'chatBgType': 'pattern'}) as PatternBackground;
    expect([p.pattern, p.ink, p.alpha], ['dots', '#0f172a', 0.12]);
    expect(chatPatterns.keys, containsAll(['dots', 'grid', 'diagonal', 'waves', 'topography', 'confetti', 'doodles', 'paper', 'hexagons', 'rings', 'plus', 'zigzag', 'sparkles']));
    expect(ChatBackgrounds.rimPoint(0), (0.5, 0.0));
    expect(ChatBackgrounds.rimPoint(90), (1.0, 0.5));
  });

  test('parses every tile path, arcs included', () {
    final segs = parseSvgPath('M10 10 h5 v5 L10 15 z');
    expect(segs.length, 5);
    expect(segs.last, isA<SvgClose>());
    final arc = parseSvgPath('M0 0 A5 5 0 0 1 10 0');
    final end = arc.last as SvgCubic;
    expect(end.x, closeTo(10, 1e-9));
    expect(end.y, closeTo(0, 1e-9));
    for (final tile in chatPatterns.values) {
      for (final s in tile.shapes.where((s) => s.d != null)) {
        expect(parseSvgPath(s.d!), isNotEmpty, reason: s.d);
      }
    }
  });
}
