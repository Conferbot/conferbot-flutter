// The owner's view transition between home, chat and help centre
// (lib/src/core/home/view_transition.dart): RN's
// __tests__/core/viewTransition.test.ts (web ts/layout/viewTransition.ts).
import 'package:conferbot_flutter/src/core/home/view_transition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unset is the honeycomb; unknown values too', () {
    expect(normalizeViewTransition(null), 'honeycomb');
    expect(normalizeViewTransition('nope'), 'honeycomb');
    expect(normalizeViewTransition('fade'), 'fade');
    expect(normalizeViewDirection('x'), 'auto');
  });

  test('deeper views are forward; coming back reverses the sweep', () {
    expect(isForward('home', 'chat'), isTrue);
    expect(isForward('chat', 'home'), isFalse);
    expect(isForward('home', 'help'), isTrue);
    expect(isForward('help', 'home'), isFalse);
    expect(sweepVector('auto', 1), (x: 1.0, y: 0.0));
    expect(sweepVector('auto', -1), (x: -1.0, y: 0.0));
    expect(sweepVector('rtl', 1), (x: -1.0, y: 0.0));
    expect(sweepVector('ttb', -1), (x: 0.0, y: -1.0));
    expect(sweepVector('tap', 1), (x: 1.0, y: 0.0));
  });

  test('classic and none switch at once; the same view does not move', () {
    expect(viewMotion('classic', 'auto', 'home', 'chat'), const NoMotion());
    expect(viewMotion('none', 'auto', 'home', 'chat'), const NoMotion());
    expect(viewMotion('fade', 'auto', 'chat', 'chat'), const NoMotion());
  });

  test("fade and slide are the web's; the rest slide; reduced motion is a short fade", () {
    expect(viewMotion('fade', 'auto', 'home', 'chat'), const FadeMotion(duration: 340, delay: 40, scaleFrom: 1.035));
    expect(viewMotion('slide', 'auto', 'home', 'chat'), const SlideMotion(duration: 420, dx: 1, dy: 0));
    expect(viewMotion('slide', 'auto', 'chat', 'home'), const SlideMotion(duration: 420, dx: -1, dy: 0));
    expect(viewMotion(null, 'btt', 'home', 'chat'), const SlideMotion(duration: 420, dx: 0, dy: -1));
    expect(viewMotion('iris', 'auto', 'home', 'help', reduced: true), const ReducedMotion(200));
    expect(viewMotion('classic', 'auto', 'home', 'help', reduced: true), const NoMotion());
  });
}
