/// The waiting games card, drawn from core/waiting/games_card.dart's state.
/// Ported from the React Native SDK (components/LiveChat/GamesCard.tsx),
/// itself from the web widget's conferbot-widget src/ts/chat/games/ui.ts and
/// its sheet src/css/polish-games.css: the theme's card surface and text,
/// the bot's accent (pickAccent) for picks, wins and the main button. Motion
/// is the web's and no more: the card rises in, the hands shake for the
/// rock-paper-scissors reveal, a small cheer, confetti on a win, the
/// scramble's nudge; all of it off when the phone asks for reduced motion.
/// Memory cards turn without the web's 3D flip, as in RN.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/waiting/games_card.dart';
import '../../core/waiting/waiting_games.dart';
import '../../theme/conferbot_theme.dart';
import '../../ui/widgets/step_style.dart';

Color _hex(String raw, Color fallback) {
  var s = raw.trim().replaceFirst('#', '');
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  final v = s.length == 6 ? int.tryParse('FF$s', radix: 16) : null;
  return v == null ? fallback : Color(v);
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// The card's colours (web polish-games.css).
class GamesLook {
  GamesLook({
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
  })  : dark = card.computeLuminance() < 0.5,
        fill = _mix(card, ink, card.computeLuminance() < 0.5 ? 0.1 : 0.05),
        soft = _mix(card, accent, 0.09),
        // A cross in the accent on a dark card is lifted so it reads.
        accentInk = card.computeLuminance() < 0.5 ? _mix(accent, Colors.white, 0.5) : accent;

  final Color card;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;
  final bool dark;
  final Color fill;
  final Color soft;
  final Color accentInk;

  static GamesLook of(BuildContext context, ConferBotTheme theme, dynamic customizations) {
    final step = StepLook.of(context, theme, theme.colors.primary);
    return GamesLook(
      card: step.card,
      ink: step.text,
      muted: step.muted,
      line: step.line,
      accent: _hex(pickAccent(customizations), const Color(0xFF0808EE)),
    );
  }

  TextStyle t(double size, {FontWeight? weight, Color? color, double? height}) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color ?? ink, height: height);
}

/// A quiet tile (a pick, an option, a cell).
class _Tile extends StatelessWidget {
  const _Tile({
    required this.look,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.disabled = false,
    this.color,
    this.border,
    this.padding,
    this.label,
    this.tileKey,
  });

  final GamesLook look;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onTapDown;
  final bool disabled;
  final Color? color;
  final BoxBorder? border;
  final EdgeInsets? padding;
  final String? label;
  final Key? tileKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      excludeSemantics: label != null,
      child: GestureDetector(
        key: tileKey,
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : onTap,
        onTapDown: disabled || onTapDown == null ? null : (_) => onTapDown!(),
        child: Container(
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color ?? look.fill, borderRadius: BorderRadius.circular(12), border: border),
          child: child,
        ),
      ),
    );
  }
}

class _FootButton extends StatelessWidget {
  const _FootButton({required this.look, required this.label, this.primary = false, this.onTap, this.disabled = false, this.buttonKey});
  final GamesLook look;
  final String label;
  final bool primary;
  final VoidCallback? onTap;
  final bool disabled;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: GestureDetector(
          key: buttonKey,
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
            decoration: BoxDecoration(
              color: primary ? look.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: primary ? null : Border.all(color: look.line),
            ),
            child: Text(label, style: look.t(12.5, weight: FontWeight.w600, color: primary ? Colors.white : look.ink)),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ boards

class _RpsView extends StatefulWidget {
  const _RpsView({required this.b, required this.look, required this.act, required this.reduced});
  final RpsBoard b;
  final GamesLook look;
  final void Function(GameInput a) act;
  final bool reduced;

  @override
  State<_RpsView> createState() => _RpsViewState();
}

class _RpsViewState extends State<_RpsView> with SingleTickerProviderStateMixin {
  // Three shakes in 900ms.
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _maybeShake(false);
  }

  @override
  void didUpdateWidget(_RpsView old) {
    super.didUpdateWidget(old);
    _maybeShake(old.b.shaking);
  }

  void _maybeShake(bool was) {
    if (widget.b.shaking && !was && !widget.reduced) {
      _shake.forward(from: 0);
    } else if (!widget.b.shaking) {
      _shake.stop();
      _shake.value = 0;
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Widget _big(String face, String who) {
    final b = widget.b;
    final won = (who == 'you' && b.outcome == 'win') || (who == 'bot' && b.outcome == 'lose');
    final lost = (who == 'you' && b.outcome == 'lose') || (who == 'bot' && b.outcome == 'win');
    Widget glyph = Text(face, style: const TextStyle(fontSize: 40, height: 1.15));
    if (who == 'bot') glyph = Transform.flip(flipX: true, child: glyph);
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        // Up and back three times (web .cb-rps-shake).
        final p = b.shaking ? math.sin(_shake.value * 3 * math.pi).abs() : 0.0;
        return Transform.translate(
          offset: Offset(0, -12 * p),
          child: Transform.rotate(angle: -10 * math.pi / 180 * p, child: child),
        );
      },
      child: Opacity(opacity: lost ? 0.45 : 1, child: Transform.scale(scale: won ? 1.18 : 1, child: glyph)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final look = widget.look;
    return Column(
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _big(b.you, 'you'),
                const SizedBox(width: 22),
                Text('VS', style: look.t(11, weight: FontWeight.w700, color: look.muted)),
                const SizedBox(width: 22),
                _big(b.bot, 'bot'),
              ],
            ),
          ),
        ),
        Row(
          children: [
            for (var i = 0; i < b.hands.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Opacity(
                  opacity: b.busy ? 0.6 : 1,
                  child: _Tile(
                    look: look,
                    tileKey: ValueKey('cb-games-rps-${b.hands[i].hand}'),
                    disabled: b.busy,
                    label: b.hands[i].name,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    onTap: () => widget.act(RpsInput(b.hands[i].hand)),
                    child: Column(
                      children: [
                        Text(b.hands[i].emoji, style: const TextStyle(fontSize: 22, height: 1.2)),
                        const SizedBox(height: 3),
                        Text(b.hands[i].name, style: look.t(11.5, weight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

Widget _tttView(TttBoard b, GamesLook look, void Function(GameInput a) act) {
  String label(int i) =>
      'Row ${i ~/ 3 + 1}, column ${i % 3 + 1}, ${b.cells[i] == 'X' ? 'yours' : b.cells[i] == 'O' ? "the bot's" : 'empty'}';
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 210),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 9; i++)
            () {
              final c = b.cells[i];
              final inLine = b.line.contains(i);
              return Opacity(
                opacity: b.over && !inLine ? 0.5 : 1,
                child: _Tile(
                  look: look,
                  tileKey: ValueKey('cb-games-ttt-$i'),
                  disabled: c != null || b.over || b.thinking,
                  label: label(i),
                  color: inLine ? (c == 'O' ? look.muted : look.accent) : look.fill,
                  onTap: () => act(TttInput(i)),
                  child: Text(
                    c == 'X' ? '✕' : c == 'O' ? '◯' : '',
                    style: look.t(26,
                        weight: FontWeight.w700,
                        color: inLine ? Colors.white : c == 'X' ? look.accentInk : look.muted),
                  ),
                ),
              );
            }(),
        ],
      ),
    ),
  );
}

Widget _memoryView(MemoryBoard b, GamesLook look, void Function(GameInput a) act) => GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < b.cards.length; i++)
          () {
            final c = b.cards[i];
            return _Tile(
              look: look,
              tileKey: ValueKey('cb-games-mem-$i'),
              disabled: c.matched,
              label: 'Card ${i + 1}, ${c.up ? c.face : 'face down'}${c.matched ? ', matched' : ''}',
              color: c.up ? (c.matched ? look.soft : look.fill) : look.accent,
              border: c.matched ? Border.all(color: _mix(look.card, look.accent, 0.45), width: 1.5) : null,
              onTap: () => act(MemoryInput(i)),
              child: c.up
                  ? Text(c.face, style: const TextStyle(fontSize: 24))
                  : Text('?', style: look.t(18, weight: FontWeight.w700, color: Colors.white.withOpacity(0.75))),
            );
          }(),
      ],
    );

Widget _choiceView(ChoiceBoard b, GamesLook look, void Function(GameInput a) act) {
  final emoji = b.game == 'emoji';
  final done = b.picked != null;
  Widget option(int i) {
    final right = done && i == b.answer;
    final wrong = done && i == b.picked && i != b.answer;
    return Opacity(
      opacity: done && !right && !wrong ? 0.5 : (wrong ? 0.6 : 1),
      child: _Tile(
        look: look,
        tileKey: ValueKey('cb-games-opt-$i'),
        disabled: done,
        label: b.options[i],
        color: right ? look.accent : look.fill,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        onTap: () => act(ChoiceInput(i)),
        child: Row(
          mainAxisAlignment: emoji ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                b.options[i],
                style: look.t(13, weight: FontWeight.w600, color: right ? Colors.white : look.ink).copyWith(
                      decoration: wrong ? TextDecoration.lineThrough : null,
                    ),
              ),
            ),
            if (right) ...[
              if (!emoji) const Spacer() else const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('✓', style: look.t(13, weight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (b.tag != null) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: look.soft, borderRadius: BorderRadius.circular(999)),
            child: Text(b.tag!, style: look.t(10.5, weight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 8),
      ],
      if (b.big != null) ...[
        Semantics(
          label: 'Emoji: ${b.big}',
          excludeSemantics: true,
          child: Text(b.big!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, height: 1.15, letterSpacing: 3)),
        ),
        const SizedBox(height: 8),
      ],
      Text(
        b.q,
        textAlign: emoji ? TextAlign.center : TextAlign.start,
        style: emoji ? look.t(12, color: look.muted) : look.t(13.5, weight: FontWeight.w600, height: 1.4),
      ),
      const SizedBox(height: 8),
      if (emoji)
        LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - 6) / 2;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (var i = 0; i < b.options.length; i++) SizedBox(width: w, child: option(i))],
            );
          },
        )
      else
        for (var i = 0; i < b.options.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          option(i),
        ],
    ],
  );
}

Widget _reactionView(ReactionBoard b, GamesLook look, void Function(GameInput a) act) {
  final go = b.state == 'go';
  final wait = b.state == 'wait';
  return _Tile(
    look: look,
    tileKey: const ValueKey('cb-games-pad'),
    disabled: b.state == 'done',
    label: b.line,
    color: go ? const Color(0xFF16A34A) : (wait ? look.fill : look.soft),
    border: go ? null : Border.all(color: wait ? look.line : _mix(look.card, look.accent, 0.18)),
    // On press, not on release, so the time is the visitor's.
    onTapDown: () => act(const ReactionInput()),
    onTap: () {},
    child: SizedBox(
      height: 128,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(b.big, style: const TextStyle(fontSize: 30, height: 1.15)),
          const SizedBox(height: 6),
          Text(b.line, style: look.t(13.5, weight: FontWeight.w600, color: go ? Colors.white : look.ink)),
        ],
      ),
    ),
  );
}

class _ScrambleView extends StatefulWidget {
  const _ScrambleView({required this.b, required this.look, required this.act, required this.reduced});
  final ScrambleBoard b;
  final GamesLook look;
  final void Function(GameInput a) act;
  final bool reduced;

  @override
  State<_ScrambleView> createState() => _ScrambleViewState();
}

class _ScrambleViewState extends State<_ScrambleView> with SingleTickerProviderStateMixin {
  late final AnimationController _nudge = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void didUpdateWidget(_ScrambleView old) {
    super.didUpdateWidget(old);
    if (widget.b.nope != old.b.nope && !widget.reduced) _nudge.forward(from: 0);
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  static double _dx(double t) {
    const xs = [0.0, -5.0, 5.0, -3.0, 3.0, 0.0];
    final p = (t.clamp(0.0, 1.0)) * 5;
    final i = p.floor().clamp(0, 4);
    return xs[i] + (xs[i + 1] - xs[i]) * (p - i);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final look = widget.look;
    final solvedLook = b.solved && !b.revealed;
    return Column(
      children: [
        ExcludeSemantics(child: Text(b.hint, style: const TextStyle(fontSize: 30, height: 1.15))),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _nudge,
          builder: (context, child) => Transform.translate(offset: Offset(_dx(_nudge.value), 0), child: child),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var i = 0; i < b.letters.length; i++)
                () {
                  final filled = i < b.placed.length && b.placed[i] >= 0;
                  final letter = filled ? b.letters[b.placed[i]] : '';
                  return Semantics(
                    button: true,
                    label: filled ? 'Space ${i + 1}, $letter' : 'Space ${i + 1}, empty',
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: ValueKey('cb-games-slot-$i'),
                      onTap: !filled || b.solved ? null : () => widget.act(SlotInput(i)),
                      child: Container(
                        width: 34,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: solvedLook
                              ? look.accent
                              : b.revealed
                                  ? look.fill
                                  : filled
                                      ? look.soft
                                      : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          border: solvedLook || b.revealed
                              ? null
                              : Border.all(color: filled ? _mix(look.card, look.accent, 0.55) : look.line, width: 1.5),
                        ),
                        child: Text(
                          letter,
                          style: look.t(16,
                              weight: FontWeight.w700,
                              color: solvedLook ? Colors.white : b.revealed ? look.muted : look.ink),
                        ),
                      ),
                    ),
                  );
                }(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 5,
          runSpacing: 5,
          children: [
            for (var i = 0; i < b.letters.length; i++)
              () {
                final used = b.placed.contains(i);
                return Semantics(
                  button: true,
                  label: 'Letter ${b.letters[i]}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: ValueKey('cb-games-tile-$i'),
                    onTap: used || b.solved ? null : () => widget.act(TileInput(i)),
                    child: Opacity(
                      opacity: used ? 0.2 : 1,
                      child: Transform.scale(
                        scale: used ? 0.9 : 1,
                        child: Container(
                          width: 36,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: look.fill, borderRadius: BorderRadius.circular(10)),
                          child: Text(b.letters[i], style: look.t(16, weight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                );
              }(),
          ],
        ),
        const SizedBox(height: 10),
        _FootButton(
          look: look,
          label: b.skipLabel,
          buttonKey: const ValueKey('cb-games-skip'),
          disabled: b.solved,
          onTap: () => widget.act(const SkipInput()),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ confetti (web ui.ts confetti)

const _pieces = 34;

class _Confetti extends StatefulWidget {
  const _Confetti({required this.look, required this.burst});
  final GamesLook look;
  final int burst;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1750));
  final _rand = math.Random();
  late final List<({double x, double dx, double r, double d, bool round})> _p = List.generate(
    _pieces,
    (i) => (
      x: _rand.nextDouble(),
      dx: (_rand.nextDouble() - 0.5) * 120,
      r: _rand.nextDouble() * 720 - 360,
      d: _rand.nextDouble() * 0.15,
      round: i % 3 == 0,
    ),
  );

  @override
  void didUpdateWidget(_Confetti old) {
    super.didUpdateWidget(old);
    if (widget.burst != old.burst && widget.burst > 0) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => !_c.isAnimating
              ? const SizedBox.shrink()
              : CustomPaint(
                  size: Size.infinite,
                  painter: _ConfettiPainter(
                    _p,
                    const Cubic(0.25, 0.6, 0.4, 1).transform(_c.value),
                    [widget.look.accent, const Color(0xFFF5A524), _mix(widget.look.accent, Colors.white, 0.55), const Color(0xFFFF6B6B), const Color(0xFF22C55E)],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress, this.tints);
  final List<({double x, double dx, double r, double d, bool round})> pieces;
  final double progress;
  final List<Color> tints;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < pieces.length; i++) {
      final p = pieces[i];
      final t = progress <= p.d ? 0.0 : ((progress - p.d) / (1 - p.d)).clamp(0.0, 1.0);
      final opacity = t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15).clamp(0.0, 1.0);
      final paint = Paint()..color = tints[i % tints.length].withOpacity(opacity);
      canvas.save();
      canvas.translate(p.x * size.width + p.dx * t, -12 + 300 * t);
      canvas.rotate(p.r * t * math.pi / 180);
      final w = p.round ? 8.0 : 7.0;
      final h = p.round ? 8.0 : 11.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(p.round ? 4 : 2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ------------------------------------------------------------ the card

class GamesCardView extends StatefulWidget {
  const GamesCardView({super.key, required this.card, required this.theme, this.customizations});

  final GamesCard card;
  final ConferBotTheme theme;

  /// The bot's settings, for the accent (pickAccent).
  final dynamic customizations;

  @override
  State<GamesCardView> createState() => _GamesCardViewState();
}

class _GamesCardViewState extends State<GamesCardView> with TickerProviderStateMixin {
  late GamesCardState _state = widget.card.state;
  void Function()? _off;
  late final AnimationController _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final AnimationController _cheer = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _off?.call();
    _state = widget.card.state;
    _off = widget.card.subscribe((s) {
      if (!mounted) return;
      final cheered = s.cheer != _state.cheer;
      setState(() => _state = s);
      if (cheered && !_reduced) _cheer.forward(from: 0);
    });
  }

  bool get _reduced => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduced) {
      _rise.value = 1;
    } else {
      _rise.forward();
    }
  }

  @override
  void didUpdateWidget(GamesCardView old) {
    super.didUpdateWidget(old);
    if (!identical(old.card, widget.card)) _listen();
  }

  @override
  void dispose() {
    _off?.call();
    _rise.dispose();
    _cheer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    if (s.view == 'gone') return const SizedBox.shrink();
    final theme = widget.theme;
    final look = GamesLook.of(context, theme, widget.customizations);
    final reduced = _reduced;
    final card = widget.card;
    void act(GameInput a) => card.input(a);
    final b = s.board;
    final win = s.result == 'win';

    Widget? board;
    if (s.view == 'game' && b != null) {
      board = switch (b) {
        RpsBoard() => _RpsView(b: b, look: look, act: act, reduced: reduced),
        TttBoard() => _tttView(b, look, act),
        MemoryBoard() => _memoryView(b, look, act),
        ChoiceBoard() => _choiceView(b, look, act),
        ReactionBoard() => _reactionView(b, look, act),
        ScrambleBoard() => _ScrambleView(b: b, look: look, act: act, reduced: reduced),
      };
      if (s.settled) board = IgnorePointer(child: board);
    }

    final body = Container(
      key: const ValueKey('cb-games'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: look.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: win ? _mix(look.card, look.accent, 0.55) : look.line, width: win ? 1.5 : 1),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    if (s.titleEmoji.isNotEmpty) ...[
                      ExcludeSemantics(child: Text(s.titleEmoji, style: const TextStyle(fontSize: 17))),
                      const SizedBox(width: 7),
                    ],
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          s.title,
                          key: const ValueKey('cb-games-title'),
                          style: look.t(14, weight: FontWeight.w700, height: 1.3),
                        ),
                      ),
                    ),
                    if (s.meta.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      // A long score line ("Word 1 of 3 · 0 solved") shares the row, never overflows it.
                      Flexible(
                        child: Text(
                          s.meta,
                          key: const ValueKey('cb-games-meta'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: look.t(11.5, weight: FontWeight.w600, color: look.muted)
                              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ),
                    ],
                    if (s.closable) ...[
                      const SizedBox(width: 4),
                      Semantics(
                        button: true,
                        label: GamesText.close,
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: const ValueKey('cb-games-close'),
                          behavior: HitTestBehavior.opaque,
                          onTap: card.dismiss,
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: Center(child: Text('✕', style: look.t(14, color: look.muted))),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (s.view == 'menu')
                Semantics(
                  label: GamesText.pick,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final half = (c.maxWidth - 6) / 2;
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < s.chips.length; i++)
                            SizedBox(
                              width: i == s.chips.length - 1 && s.chips.length.isOdd ? c.maxWidth : half,
                              child: _Chip(game: s.chips[i], look: look, onTap: () => card.open(s.chips[i].id)),
                            ),
                        ],
                      );
                    },
                  ),
                )
              else if (board != null)
                board,
              if (s.status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      s.status,
                      key: const ValueKey('cb-games-status'),
                      style: look.t(12.5, height: 1.45, weight: s.result != null ? FontWeight.w600 : FontWeight.w400),
                    ),
                  ),
                ),
              if (s.foot.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in s.foot)
                        _FootButton(
                          look: look,
                          label: f.label,
                          primary: f.primary,
                          buttonKey: ValueKey('cb-games-${f.key}'),
                          onTap: () => card.press(f.key),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          if (!reduced) Positioned.fill(child: _Confetti(look: look, burst: s.confetti)),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: theme.layout.avatarSize + 10 + theme.spacing.chatContentPadding,
        right: theme.spacing.chatContentPadding,
        top: 6,
        bottom: 12,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          container: true,
          label: GamesText.card,
          child: AnimatedBuilder(
            animation: Listenable.merge([_rise, _cheer]),
            builder: (context, child) {
              final r = const Cubic(0.22, 1, 0.36, 1).transform(_rise.value);
              // A 1.5% cheer: up in 200ms, back in 300ms.
              final cv = _cheer.value;
              final cheer = cv <= 0.4 ? cv / 0.4 : 1 - (cv - 0.4) / 0.6;
              return Opacity(
                opacity: r.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - r)),
                  child: Transform.scale(scale: 1 + 0.015 * (_cheer.isAnimating ? cheer : 0), child: child),
                ),
              );
            },
            child: body,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.game, required this.look, required this.onTap});
  final GameMeta game;
  final GamesLook look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${game.name}. ${game.blurb}',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('cb-games-chip-${game.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            color: look.soft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _mix(look.card, look.accent, 0.16)),
          ),
          child: Row(
            children: [
              Text(game.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  game.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: look.t(12.5, weight: FontWeight.w600, height: 1.28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

