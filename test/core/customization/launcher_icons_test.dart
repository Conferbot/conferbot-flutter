import 'package:conferbot_flutter/src/core/customization/launcher.dart';
import 'package:conferbot_flutter/src/core/customization/launcher_icons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("has the web widget's 56 icons", () {
    expect(LauncherIcons.all, hasLength(56));
    final ids = LauncherIcons.all.map((i) => i.id).toSet();
    for (var n = 1; n <= 56; n++) {
      expect(ids.contains('WidgetBubbleIcon$n'), isTrue, reason: '$n');
    }
  });

  test('falls back to the glossy bubble, as the web does', () {
    expect(LauncherIcons.defaultIcon, 'WidgetBubbleIcon40');
    expect(LauncherIcons.byId('nope').id, 'WidgetBubbleIcon40');
    expect(LauncherIcons.byId(null).id, 'WidgetBubbleIcon40');
    expect(LauncherIcons.byId('WidgetBubbleIcon7').id, 'WidgetBubbleIcon7');
  });

  test('reads paints, gradients and hidden parts', () {
    final glossy = LauncherIcons.byId('WidgetBubbleIcon40');
    expect(glossy.grads, hasLength(3));
    expect(glossy.grads[0].stops[0].c, 'ink');
    expect(glossy.grads[0].stops[1].a, closeTo(0.84, 1e-9));
    expect(LauncherIcons.all.any((i) => i.ops.any((o) => o.op == 0)), isTrue);
    for (final icon in LauncherIcons.all) {
      for (final o in icon.ops) {
        expect(o.d.length, greaterThan(3));
        for (final p in [o.fill, o.stroke]) {
          if (p?.g != null) expect(p!.g! < icon.grads.length, isTrue);
        }
      }
    }
  });

  test('draws the icon at 70% of the button', () {
    expect(Launcher.resolve({'widgetSize': 50}).glyph, 35);
    expect(Launcher.resolve({'widgetSize': 50, 'launcherShape': 'tab'}).glyph, 25);
  });
}
