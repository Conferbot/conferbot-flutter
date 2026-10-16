/// The look every step card shares (web css/nodes/08-rich-cards.css): a
/// card in the theme's card colour with a thin line, the accent for the
/// primary button, focus and picks, the bot's option colours, option corner
/// radius and font size for what the visitor picks. Nothing moves on its own.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/customization/customizations.dart';
import '../../providers/conferbot_provider.dart';
import '../../theme/conferbot_theme.dart';

Color? _hex(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final v = int.tryParse(s, radix: 16);
  return v == null ? null : Color(v);
}

/// White or near-black, whichever reads on [c].
Color inkOn(Color c) => c.computeLuminance() > 0.55 ? const Color(0xFF0F172A) : Colors.white;

/// The step cards' colours, corners and text size.
class StepLook {
  /// Options: the bot's option bubble colour and its text colour.
  final Color option;
  final Color optionInk;

  /// Primary buttons, ticks, focus: the accent and the ink on it.
  final Color accent;
  final Color ink;

  /// The card, its text, quiet text and its line.
  final Color card;
  final Color text;
  final Color muted;
  final Color line;

  /// Options' corner radius and the message text size.
  final double radius;
  final double fontSize;

  const StepLook({
    required this.option,
    required this.optionInk,
    required this.accent,
    required this.ink,
    required this.card,
    required this.text,
    required this.muted,
    required this.line,
    required this.radius,
    required this.fontSize,
  });

  static const Color error = Color(0xFFB42318);
  static const Color ok = Color(0xFF067647);

  /// The bot's look when its settings have arrived, else the theme's.
  static StepLook of(BuildContext context, ConferBotTheme theme, Color primary) {
    ResolvedCustomizations? look;
    try {
      final p = Provider.of<ConferBotProvider>(context, listen: false);
      if (p.serverCustomizations != null) look = p.customizations;
    } catch (_) {}
    final tokens = look?.theme.tokens;
    final accent = _hex(look?.accent) ?? primary;
    return StepLook(
      option: theme.colors.optionBubble,
      optionInk: theme.colors.optionBubbleText,
      accent: accent,
      ink: _hex(look?.accentInk) ?? inkOn(accent),
      card: _hex(tokens?.card) ?? (theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white),
      text: _hex(tokens?.ink) ?? theme.colors.text,
      muted: _hex(tokens?.muted) ?? theme.colors.textSecondary,
      line: _hex(tokens?.line) ?? const Color(0x1F0F172A),
      radius: look?.optionRadius ?? 10,
      fontSize: look?.fontSize ?? theme.typography.messageSize,
    );
  }

  TextStyle get body => TextStyle(fontSize: fontSize, color: text, height: 1.4);
  TextStyle get bold => TextStyle(fontSize: fontSize, color: text, fontWeight: FontWeight.w600, height: 1.35);
  TextStyle get hint => TextStyle(fontSize: 12, color: muted, height: 1.35);
  TextStyle get label => TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600);

  /// A text field on a card: a soft fill, a thin border, the accent when focused.
  InputDecoration field({String? hint, bool invalid = false, Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: muted.withOpacity(0.8), fontSize: 15),
      isDense: true,
      filled: true,
      fillColor: text.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: border(invalid ? const Color(0xFFD92D20) : text.withOpacity(0.22)),
      disabledBorder: border(text.withOpacity(0.12)),
      focusedBorder: border(invalid ? const Color(0xFFD92D20) : accent, 1.5),
      suffixIcon: suffix,
    );
  }
}

/// Lines a step's card up with the bot's bubble (after the avatar).
EdgeInsets stepIndent(ConferBotTheme theme) => EdgeInsets.only(left: theme.layout.avatarSize + 10);

/// The card a step sits on: at most 320 wide, the theme's card colour, a thin line.
class StepCard extends StatelessWidget {
  final StepLook style;
  final Widget child;
  final bool done;

  const StepCard({super.key, required this.style, required this.child, this.done = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Opacity(
          opacity: done ? 0.78 : 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: style.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: style.line),
              boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 6, offset: Offset(0, 2), spreadRadius: -2)],
            ),
            child: DefaultTextStyle.merge(style: style.body, child: child),
          ),
        ),
      ),
    );
  }
}

/// A card button: primary in the accent, else a light accent wash.
class StepButton extends StatelessWidget {
  final String label;
  final StepLook style;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;
  final bool busy;

  const StepButton({
    super.key,
    required this.label,
    required this.style,
    required this.onPressed,
    this.primary = false,
    this.icon,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final on = onPressed != null && !busy;
    final fg = primary ? style.ink : style.text;
    return Opacity(
      opacity: on || busy ? 1 : 0.5,
      child: Material(
        color: primary ? style.accent : style.accent.withOpacity(0.09),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.radius),
          side: primary ? BorderSide.none : BorderSide(color: style.accent.withOpacity(0.26)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(style.radius),
          onTap: on ? onPressed : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 38),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                  else ...[
                    if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                    Flexible(
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg, height: 1.2)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An option in the bot's option colours; a picked one is ringed in the accent.
class StepOption extends StatelessWidget {
  final String label;
  final StepLook style;
  final VoidCallback? onPressed;
  final bool picked;
  final IconData? icon;
  final bool expand;

  const StepOption({
    super.key,
    required this.label,
    required this.style,
    required this.onPressed,
    this.picked = false,
    this.icon,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(label,
        style: TextStyle(fontSize: style.fontSize - 0.5, fontWeight: FontWeight.w500, color: style.optionInk, height: 1.25));
    return Opacity(
      opacity: onPressed == null && !picked ? 0.55 : 1,
      child: Material(
        color: style.option,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.radius),
          side: BorderSide(color: picked ? style.accent : Colors.transparent, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(style.radius),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: expand ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: style.optionInk.withOpacity(picked ? 1 : 0.7)), const SizedBox(width: 6)],
                expand ? Flexible(child: text) : Flexible(child: text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet text link on a card (Resend code, Change email, Undo).
class StepLink extends StatelessWidget {
  final String label;
  final StepLook style;
  final VoidCallback? onPressed;
  final IconData? icon;

  const StepLink({super.key, required this.label, required this.style, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final color = style.text.withOpacity(onPressed == null ? 0.42 : 0.86);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 4)],
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// The line under a field: the step's refusal in red, else its hint.
class StepStatus extends StatelessWidget {
  final StepLook style;
  final String? hint;
  final String? error;

  const StepStatus({super.key, required this.style, this.hint, this.error});

  @override
  Widget build(BuildContext context) {
    final e = error ?? '';
    final h = hint ?? '';
    if (e.isEmpty && h.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        liveRegion: e.isNotEmpty,
        child: Text(e.isNotEmpty ? e : h,
            style: e.isNotEmpty ? const TextStyle(fontSize: 12.5, color: StepLook.error, height: 1.35) : style.hint),
      ),
    );
  }
}

/// Buttons at the end of a card, right-aligned.
class StepActions extends StatelessWidget {
  final List<Widget> children;
  const StepActions({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: children),
        ),
      );
}

/// A field's caption above it.
class StepLabel extends StatelessWidget {
  final String text;
  final StepLook style;
  const StepLabel(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: style.label));
}
