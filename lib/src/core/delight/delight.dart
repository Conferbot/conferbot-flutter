/// The conversation's small human touches, as the web widget judges them.
/// Ported from the React Native SDK (src/core/delight.ts), itself from
/// conferbot-widget src/ts/chat/delight/rules.ts (which answers can be
/// changed and when going back is safe, the bot's tapback, the moments that
/// earn a celebration, the gentle nudge), delight/index.ts (the timings, the
/// owner's on/off settings), delight/stallNudge.ts (when the nudge shows),
/// delight/celebrate.ts (the confetti's fan) and ratingFx.ts (the rating's
/// sparks).
///
/// Restraint is the point: a reaction on every answer, or confetti for an
/// email address, would feel like a toy. These fire on the moments a person
/// would react to, and each can be switched off by the owner:
/// customizations.botReactions, celebrations, stallNudges, allowChangeAnswer
/// (all on unless false). Motion is skipped for visitors who ask for less.
/// Pure.
library;

import 'dart:async';
import 'dart:math' as math;

import '../i18n/i18n.dart';

class Delight {
  Delight._();

  // ------------------------------------------------------------ the owner's switches

  /// On unless the owner set it to false (web delight/index.ts `on`):
  /// botReactions, celebrations, stallNudges, allowChangeAnswer.
  static bool touchOn(dynamic c, String key) => !(c is Map && c[key] == false);

  /// The reaction and the burst wait this long after the answer (web REACT_AFTER_MS).
  static const reactAfterMs = 550;

  /// "Edit" shows once the bot has been quiet this long (web QUIET_BEFORE_CHANGE_MS).
  static const quietBeforeChangeMs = 900;

  /// Only the recent past can be changed (web keeps 30 question points).
  static const maxQuestionPoints = 30;

  // ------------------------------------------------------------ changing an answer

  /// Questions whose answer can be taken back and given again.
  static const changeableTypes = {
    // v2 questions
    'ask-name-node',
    'ask-email-node',
    'ask-phone-number-node',
    'ask-number-node',
    'ask-url-node',
    'ask-location-node',
    'ask-custom-question-node',
    // choices
    'n-choices-node',
    'n-select-option-node',
    'n-check-options-node',
    'yes-or-no-choice-node',
    'image-choice-node',
    'rating-choice-node',
    'opinion-scale-choice-node',
    'dynamic-choices-node',
    // rich inputs with no side effect
    'slider-node',
    'datetime-node',
    'ranking-node',
    'matrix-node',
    'address-node',
    // classic
    'two-choices-node',
    'three-choices-node',
    'select-option-node',
    'user-rating-node',
    'user-range-node',
    'user-input-node',
  };

  /// Steps that show something but act on the world (a booking made, a code
  /// sent, a payment, a file uploaded, a signature given, an AI call): once
  /// one has run, going back would not undo it, so the answer before it stays.
  static const _actsOnTheWorld = {
    'calendar-node',
    'payment-node',
    'otp-node',
    'ask-file-node',
    'signature-node',
    'ai-extract-node',
    'ai-route-node',
    'kb-answer-node',
    'quiz-node',
    'consent-node',
    'ask-multiple-questions-node',
  };

  /// The web's display steps (core/node-processors/nodeTypeCategories.ts DISPLAY_NODE_TYPES).
  static const _displayTypes = {
    'two-choices-node', 'three-choices-node', 'select-option-node', 'user-rating-node', 'quiz-node', 'user-input-node',
    'user-range-node', 'message-node', 'image-node', 'video-node', 'audio-node', 'file-node', 'ask-name-node',
    'ask-email-node', 'ask-phone-number-node', 'ask-number-node', 'ask-url-node', 'ask-file-node', 'ask-location-node',
    'ask-custom-question-node', 'ask-multiple-questions-node', 'calendar-node', 'n-select-option-node',
    'n-check-options-node', 'n-choices-node', 'image-choice-node', 'carousel-node', 'rating-choice-node',
    'yes-or-no-choice-node', 'opinion-scale-choice-node', 'user-redirect-node', 'html-node', 'navigate-node',
    'dynamic-choices-node', 'consent-node', 'product-card-node', 'slider-node', 'datetime-node', 'ranking-node',
    'otp-node', 'address-node', 'matrix-node', 'ai-extract-node', 'ai-route-node', 'kb-answer-node', 'signature-node',
    'payment-node',
  };

  /// The web's logic steps (LOGIC_NODE_TYPES).
  static const _logicTypes = {
    'condition-node', 'boolean-logic-node', 'random-flow-node', 'math-operation-node', 'variable-node', 'jump-to-node',
    'business-hours-node',
  };

  /// A step after the answer that going back can safely undo.
  static bool isSafeToUndo(String type) =>
      (_displayTypes.contains(type) && !_actsOnTheWorld.contains(type)) || _logicTypes.contains(type) || type == 'delay-node';

  /// Can the visitor change their answer to [questionType], given the step
  /// types that have run since it was asked (the question itself excluded)?
  /// A person in the conversation since then counts as "agent" (not safe).
  static bool canChangeAnswer(String questionType, List<String> typesSince) =>
      changeableTypes.contains(questionType) && typesSince.every(isSafeToUndo);

  /// Steps that wait for the visitor's answer: the ones a question point is
  /// kept for (what an answer belongs to, and what to go back to).
  static bool waitsForAnswer(String questionType) =>
      changeableTypes.contains(questionType) || _actsOnTheWorld.contains(questionType);

  /// Whether "Edit" shows under the visitor's latest answer: the owner allows
  /// it, nothing locks the conversation (a person in it, or over), the bot is
  /// not mid-reply, the answer is the visitor's latest bubble, and nothing
  /// irreversible ran since (web delight/index.ts refreshChange).
  static bool showChangeFor({
    required dynamic customizations,
    required bool locked,
    required bool botBusy,
    required bool isLatestAnswer,
    required String questionType,
    required List<String> typesSince,
  }) =>
      touchOn(customizations, 'allowChangeAnswer') &&
      !locked &&
      !botBusy &&
      isLatestAnswer &&
      canChangeAnswer(questionType, typesSince);

  // ------------------------------------------------------------ reading an answer

  /// A rating or scale answer as a share of the best (0 to 1), from the
  /// reply text: "★★★★ Good" (stars out of 5), "8/10", "7/10". null when the
  /// text is not a score. Star answers ("⭐⭐⭐⭐") are counted the same.
  static double? scoreShare(String? text) {
    final s = (text ?? '').trim();
    final frac = RegExp(r'^(\d+(?:\.\d+)?)\s*/\s*(\d+)\b').firstMatch(s);
    if (frac != null) {
      final max = double.parse(frac.group(2)!);
      return max > 0 ? (double.parse(frac.group(1)!) / max).clamp(0.0, 1.0) : null;
    }
    final stars = RegExp('★|⭐').allMatches(s).length;
    if (stars > 0) return math.min(1, stars / 5);
    return null;
  }

  static const _scoreTypes = {'rating-choice-node', 'opinion-scale-choice-node', 'user-rating-node'};

  /// The answer's text as the web would read it for a score: a rating of n
  /// out of [max] stars as "n/max", a scale value as "v/to" (its top).
  static String scoreText(String questionType, num? value, num? max) {
    if (!_scoreTypes.contains(questionType) || value == null || max == null || !value.isFinite || max <= 0) return '';
    String n(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
    return '${n(value)}/${n(max)}';
  }

  // ------------------------------------------------------------ the bot's reaction

  /// The tapback the bot puts on the visitor's answer, or null for none.
  /// Names get a wave, scores a heart or a thumbs up (a low score gets a
  /// quiet "thank you for telling us", never a cheer), a booking a party.
  /// Everything else goes unremarked - a reaction on every answer is noise.
  static String? reactionFor(String questionType, String answerText) {
    if (questionType == 'ask-name-node') return '👋';
    if (questionType == 'calendar-node') return '🎉';
    if (questionType == 'payment-node') return '🎉';
    if (_scoreTypes.contains(questionType)) {
      final s = scoreShare(answerText);
      if (s == null) return null;
      if (s >= 0.8) return '❤️';
      if (s >= 0.55) return '👍';
      return '🙏';
    }
    return null;
  }

  static const _reactionLabels = {
    '👋': 'reaction.waved',
    '🎉': 'reaction.celebrated',
    '❤️': 'reaction.loved',
    '👍': 'reaction.liked',
    '🙏': 'reaction.thanked',
  };

  /// What a screen reader says for the badge (web reactions.ts LABELS).
  static String reactionLabel(String emoji) => t(_reactionLabels[emoji] ?? 'reaction.reacted');

  // ------------------------------------------------------------ celebrations

  /// The moments that earn a burst: a booking made, a payment through, a
  /// top score. The rating card already sparks on a pick; a perfect score
  /// elsewhere adds the burst.
  static bool celebrates(String questionType, String answerText) {
    if (questionType == 'calendar-node' || questionType == 'payment-node') return true;
    if (_scoreTypes.contains(questionType)) {
      final s = scoreShare(answerText);
      return s != null && s >= 0.999 && questionType != 'rating-choice-node';
    }
    return false;
  }

  /// What an answer gets, a beat after it lands: a tapback and / or a burst
  /// (web delight/index.ts onAnswer).
  static ({String? reaction, bool celebrate}) touchesFor(dynamic c, String questionType, String answerText, bool reducedMotion) => (
        reaction: touchOn(c, 'botReactions') ? reactionFor(questionType, answerText) : null,
        celebrate: !reducedMotion && touchOn(c, 'celebrations') && celebrates(questionType, answerText),
      );

  /// Pieces in a burst (web celebrate.ts PIECES).
  static const confettiCount = 28;

  /// The burst is gone after this (web: the pieces removed at 1600 ms).
  static const confettiMs = 1600;

  /// The burst's pieces: a fan that opens up and towards the bot's side,
  /// -160 to -20 degrees with a little jitter, 56-116 px out, then a 26-56 px
  /// fall (web celebrate.ts). [random] is Random().nextDouble unless a test
  /// gives one.
  static List<ConfettiPiece> confettiPieces([double Function()? random]) {
    final r = random ?? math.Random().nextDouble;
    // JavaScript's Math.round: halves go up.
    int round(double v) => (v + 0.5).floor();
    return List.generate(confettiCount, (i) {
      final angle = (-160 + (140 * i) / (confettiCount - 1) + (r() * 14 - 7)) * (math.pi / 180);
      final reach = 56 + r() * 60;
      return ConfettiPiece(
        dx: round(math.cos(angle) * reach),
        dy: round(math.sin(angle) * reach),
        fall: round(26 + r() * 30),
        rot: round(r() * 540 - 270),
        delay: round(r() * 90),
        tone: i % 4,
        round: i % 3 == 0,
      );
    });
  }

  /// The rating's sparks on a pick: 8, or 12 for the top score, evenly round
  /// from 20 degrees (web ratingFx.ts burst).
  static List<double> ratingSparks(bool top) {
    final count = top ? 12 : 8;
    return [for (var i = 0; i < count; i++) (360 / count) * i + 20];
  }

  /// The sparks are gone after this (web: removed at 1000 ms).
  static const ratingSparksMs = 1000;

  // ------------------------------------------------------------ a gentle nudge when a question waits

  /// How long a question waits, with the chat open and nobody busy, before the nudge.
  static const stallAfterMs = 40000;

  /// Recent activity (typing, a touch, a scroll) in the chat postpones it this long.
  static const stallQuietMs = 15000;

  static const _typed = {
    'ask-name-node',
    'ask-email-node',
    'ask-phone-number-node',
    'ask-number-node',
    'ask-url-node',
    'ask-location-node',
    'ask-custom-question-node',
    'user-input-node',
    'user-range-node',
  };

  /// What the nudge says: picking or typing, never pushy.
  static String stallHintFor(String questionType) => _typed.contains(questionType) ? t('nudge.stallType') : t('nudge.stallPick');

  /// Whether a question shows a nudge at all (not for steps that already wait on their own).
  static bool nudgesWhileWaiting(String questionType) =>
      changeableTypes.contains(questionType) || questionType == 'calendar-node' || questionType == 'consent-node';
}

/// One piece of the burst.
class ConfettiPiece {
  /// Where the piece flies to from the answer, px.
  final int dx;
  final int dy;

  /// How far it then falls, px.
  final int fall;

  /// Its spin, degrees.
  final int rot;

  /// Its start delay, ms.
  final int delay;

  /// Which of the 4 colours (the bot's own).
  final int tone;
  final bool round;

  const ConfettiPiece({required this.dx, required this.dy, required this.fall, required this.rot, required this.delay, required this.tone, required this.round});
}

/// The nudge's timing (web delight/stallNudge.ts): [Delight.stallAfterMs]
/// after the question, unless the visitor was busy in the last
/// [Delight.stallQuietMs], the chat is not on screen, or something is typed;
/// then it checks again every [Delight.stallQuietMs]. Once per question.
class StallWatch {
  StallWatch({
    required this.isVisible,
    required this.composerValue,
    required this.show,
    required this.hide,
    int Function()? now,
    Object Function(void Function() fn, int ms)? setTimer,
    void Function(Object timer)? clearTimer,
  })  : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
        _setTimer = setTimer ?? ((fn, ms) => Timer(Duration(milliseconds: ms), fn)),
        _clearTimer = clearTimer ?? ((t) => (t as Timer).cancel()) {
    _lastActivity = _now();
  }

  /// The chat open, on the conversation, and the app in front.
  final bool Function() isVisible;
  final String Function() composerValue;
  final void Function(String hint) show;
  final void Function() hide;
  final int Function() _now;
  final Object Function(void Function() fn, int ms) _setTimer;
  final void Function(Object timer) _clearTimer;

  Object? _timer;
  String _armedType = '';
  bool _armed = false;
  bool _shown = false;
  late int _lastActivity;

  void _clear() {
    if (_timer != null) _clearTimer(_timer!);
    _timer = null;
  }

  void _check() {
    _timer = null;
    if (_shown || !_armed) return;
    final busy = _now() - _lastActivity < Delight.stallQuietMs;
    if (busy || !isVisible() || composerValue().trim().isNotEmpty) {
      _timer = _setTimer(_check, Delight.stallQuietMs);
      return;
    }
    _shown = true;
    show(Delight.stallHintFor(_armedType));
  }

  /// Start (or restart) the wait for the question now on screen.
  void arm(String questionType) {
    _armedType = questionType;
    _armed = true;
    if (_shown) return;
    _clear();
    _timer = _setTimer(_check, Delight.stallAfterMs);
  }

  /// They answered, or the question went away: the nudge goes.
  void disarm() {
    _clear();
    final was = _shown;
    _armed = false;
    _shown = false;
    if (was) hide();
  }

  /// The visitor touched, scrolled or typed in the chat.
  void touch() => _lastActivity = _now();
}
