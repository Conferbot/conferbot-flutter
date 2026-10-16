/// The "mascot" launcher style (the React Native SDK's components/Mascot/
/// LauncherMascot.tsx; web launcherStyle.ts): the owner's mascot on a soft
/// light button.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/customization/mascot_art.dart';
import '../../core/customization/mascot_moods.dart';
import '../fx_svg.dart';
import 'mascot_view.dart';

/// The soft light button behind it (launcherStyle.ts): white at 35% 30%, to the launcher colour at 14% on white.
String mascotButtonSvg(String light) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" preserveAspectRatio="none"><defs><radialGradient id="g" cx="0.35" cy="0.3" r="0.955"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="$light"/></radialGradient></defs><rect width="100" height="100" fill="url(#g)"/></svg>';

/// The button's light, filling its box (clip it to the button's corners).
class MascotButtonLight extends StatelessWidget {
  final String light;
  const MascotButtonLight({super.key, required this.light});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _LightPainter(mascotButtonSvg(light)), child: const SizedBox.expand());
}

class _LightPainter extends CustomPainter {
  final String svg;
  _LightPainter(this.svg);
  @override
  void paint(Canvas canvas, Size size) => drawFxSvg(canvas, svg, size);
  @override
  bool shouldRepaint(_LightPainter old) => old.svg != svg;
}

/// The owner's mascot in the launcher: its bust at [scale]% of the button's
/// short side, centred and lifted (translate -50% -56%) so its ears and hat
/// peek over the rim, blinking now and then. A reply landing while the chat
/// is closed (the unread count rising) makes it hop for joy and smile for
/// 2.4s (cheerLauncherMascot), then it goes back to blinking; a reply
/// mid-hop starts it again. Reduced motion keeps only the smile.
class LauncherMascot extends StatefulWidget {
  final MascotLook look;
  final String accent;
  final int scale;
  final Size box;
  final int unread;
  final bool chatOpen;
  final bool? reduceMotion;
  const LauncherMascot({
    super.key,
    required this.look,
    required this.accent,
    required this.scale,
    required this.box,
    required this.unread,
    required this.chatOpen,
    this.reduceMotion,
  });

  @override
  State<LauncherMascot> createState() => _LauncherMascotState();
}

class _LauncherMascotState extends State<LauncherMascot> {
  bool _happy = false;
  int _cheer = 0;

  @override
  void didUpdateWidget(LauncherMascot old) {
    super.didUpdateWidget(old);
    if (widget.unread > old.unread && !widget.chatOpen) _cheerUp();
  }

  void _cheerUp() {
    final run = ++_cheer;
    // A fresh mood (the hop starts again), then back to blinking.
    setState(() => _happy = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || run != _cheer) return;
      setState(() => _happy = true);
    });
    Future.delayed(const Duration(milliseconds: mascotCheerMs), () {
      if (!mounted || run != _cheer) return;
      setState(() => _happy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.box;
    final n = math.min(b.width, b.height) * widget.scale / 100;
    return IgnorePointer(
      child: SizedBox(
        key: const ValueKey('cb-launcher-mascot'),
        width: b.width,
        height: b.height,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: b.width / 2 - n / 2,
            top: b.height / 2 - n * 0.56,
            width: n,
            height: n,
            child: Mascot(
              // A new key per cheer: the hop starts from its beginning.
              key: ValueKey('mood $_happy $_cheer'),
              look: widget.look,
              accent: widget.accent,
              size: n,
              bust: true,
              mood: _happy ? 'happy' : 'idle',
              enabled: !widget.chatOpen,
              reduceMotion: widget.reduceMotion,
            ),
          ),
        ]),
      ),
    );
  }
}
