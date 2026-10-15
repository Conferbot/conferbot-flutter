import 'package:conferbot_flutter/src/core/customization/customizations.dart';
import 'package:conferbot_flutter/src/core/customization/launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is a 50 speech bubble 16 from the bottom right by default', () {
    final l = Launcher.resolve({});
    expect(l.shape, 'bubble');
    expect(l.position, 'right');
    expect(l.size, 50);
    expect([l.bottom, l.side], [16, 16]);
    expect(l.corners, const BubbleCorners(25, 25, 6, 25));
    expect(Launcher.resolve({'widgetPosition': 'left'}).corners.bottomLeft, 6);
  });

  test('keeps an owner-rounded button round', () {
    expect(Launcher.normalizeShape(null, 12), 'circle');
    expect(Launcher.normalizeShape(null, 50), 'bubble');
    expect(Launcher.normalizeShape('peek', 12), 'peek');
    expect(Launcher.resolve({'widgetBorderRadius': 12, 'widgetSize': 60}).corners.topLeft, 12);
  });

  test('uses the phone size and offsets, clamped', () {
    final l = Launcher.resolve({'widgetSize': 70, 'mobileWidgetSize': 200, 'mobileOffsetBottom': 90, 'mobileOffsetSide': -5});
    expect(l.size, 80);
    expect([l.bottom, l.side], [90, 0]);
    expect(Launcher.resolve({'widgetSize': 64}).size, 64);
  });

  test('draws squircle, tab and peek', () {
    expect(Launcher.resolve({'launcherShape': 'squircle', 'widgetSize': 50}).corners.topLeft, 15);
    final tab = Launcher.resolve({'launcherShape': 'tab', 'widgetSize': 50});
    expect([tab.width, tab.side, tab.tucked], [41, 0, 0]);
    expect(tab.corners, const BubbleCorners(15, 0, 0, 15));
    expect(Launcher.resolve({'launcherShape': 'peek', 'widgetSize': 50}).tucked, 17);
  });

  test('reads colours with dark ink on light ones', () {
    expect(Launcher.resolve({'widgetIconBgColor': '#0F766E'}).solid, '#0F766E');
    expect(Launcher.resolve({'widgetIconBgColor': '#0F766E'}).ink, '#ffffff');
    expect(Launcher.resolve({'widgetIconBgColor': '#fef3c7'}).ink, '#111827');
    final g = Launcher.resolve({'widgetIconThemeType': 'Gradient', 'widgetGradientBgOne': '#7c3aed', 'widgetGradientBgTwo': '#0d9488'});
    expect(g.gradient, ['#7c3aed', '#0d9488']);
    expect(g.solid, '#7c3aed');
    expect(Launcher.resolve({'headerBgColor': '#123456'}).solid, '#123456');
  });

  test('falls back to the icon for an image, a missing avatar and the label on phones', () {
    expect(Launcher.resolve({'launcherStyle': 'avatar', 'avatar': 'https://x/a.png'}).style, 'avatar');
    expect(Launcher.resolve({'launcherStyle': 'avatar'}).style, 'icon');
    expect(Launcher.resolve({'launcherStyle': 'avatar', 'avatar': 'a', 'widgetIconType': 'Image', 'widgetIconImage': 'https://x/i.png'}).style, 'icon');
    expect(Launcher.resolve({'launcherStyle': 'label'}, screenWidth: 400).style, 'icon');
    expect(Launcher.resolve({'launcherStyle': 'label'}, screenWidth: 800).style, 'label');
  });

  test('caps the label and shows the greeting only when on', () {
    expect(Launcher.normalizeLabel('  Talk   to the   team about your order today  '), 'Talk to the team about y');
    expect(Launcher.resolve({}).label, 'Chat with us');
    expect(Launcher.resolve({'chatIconCtaText': 'Hi there'}).ctaText, isNull);
    expect(Launcher.resolve({'chatIconCta': true, 'chatIconCtaText': 'Hi there'}).ctaText, 'Hi there');
  });

  test('reads the motion, subtle by default', () {
    expect(Launcher.resolve({}).animation, 'subtle');
    expect(Launcher.resolve({'launcherAnimation': 'off'}).animation, 'off');
    expect(Launcher.resolve({'launcherAnimation': 'wild'}).animation, 'subtle');
  });
}
