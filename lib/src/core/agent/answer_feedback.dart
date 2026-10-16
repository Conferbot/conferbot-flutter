/// "Helpful?" under an AI answer, as the web widget's ts/chat/answerFeedback.ts
/// (ported from the React Native SDK's src/core/answerFeedback.ts).
///
///   ask     "Helpful?" with a thumb up and a thumb down, on the newest
///           answer only (an older unrated one steps aside).
///   up      sent at once ({helpful:true}); "Thanks for letting us know!",
///           then the quiet rated line.
///   down    sent at once ({helpful:false}) - a No never waits for a reason.
///           "Sorry about that. What went wrong?" with four reasons; a reason
///           is sent too and opens an optional comment. "Talk to a person"
///           (only while nobody is coming or here) and "Ask another way"
///           stay right there.
///   rated   both thumbs, the chosen one pressed, and the reason. Tapping the
///           other thumb changes the vote. A restored answer draws this.
///
/// Pure: [Helpful.step] says what a tap does (the vote to send and the view
/// next); the caller sends it (`ai-answer-feedback`) and keeps it on the
/// answer's record entry (ChatState.setAnswerFeedback) so a restore draws it.
library;

import 'agent_bot.dart';

enum HelpfulView { ask, thanks, down, rated }

class HelpfulState {
  final HelpfulView view;
  final AnswerFeedback? current;

  /// The comment went: the field is replaced by "Thanks, that helps us improve."
  final bool commented;

  const HelpfulState(this.view, this.current, {this.commented = false});

  HelpfulState copyWith({HelpfulView? view, AnswerFeedback? current, bool? commented}) =>
      HelpfulState(view ?? this.view, current ?? this.current, commented: commented ?? this.commented);
}

/// A tap on the row.
sealed class HelpfulTap {
  const HelpfulTap();
}

class HelpfulVote extends HelpfulTap {
  final bool helpful;
  const HelpfulVote(this.helpful);
}

class HelpfulReason extends HelpfulTap {
  final String reason;
  const HelpfulReason(this.reason);
}

class HelpfulComment extends HelpfulTap {
  final String text;
  const HelpfulComment(this.text);
}

/// "Talk to a person".
class HelpfulHuman extends HelpfulTap {
  const HelpfulHuman();
}

/// "Ask another way".
class HelpfulRetry extends HelpfulTap {
  const HelpfulRetry();
}

/// The thanks line's time is up.
class HelpfulSettle extends HelpfulTap {
  const HelpfulSettle();
}

/// What a tap does: the next state, the vote to send (when there is one),
/// the visitor's words to send ([ask], for "Talk to a person") or [focus]
/// (the composer, for "Ask another way").
typedef HelpfulStep = ({HelpfulState state, AnswerFeedback? send, String? ask, bool focus});

class Helpful {
  Helpful._();

  /// The web's English strings (ts/i18n/en.ts helpful.*).
  static const ask = 'Helpful?';
  static const groupLabel = 'Was this answer helpful?';
  static const yes = 'Yes, helpful';
  static const no = 'No, not helpful';
  static const ratedUp = 'Helpful';
  static const ratedDown = 'Not helpful';
  static const thanks = 'Thanks for letting us know!';
  static const sorry = 'Sorry about that. What went wrong?';
  static const whatWentWrong = 'What went wrong?';
  static const comment = 'Add a comment (optional)';
  static const sendFeedback = 'Send feedback';
  static const retry = 'Ask another way';
  static const thanksComment = 'Thanks, that helps us improve.';
  static const talkToPerson = 'Talk to a person';
  static const talkToPersonAsk = "I'd like to talk to a person, please.";

  /// How long "Thanks for letting us know!" shows before the rated line (web: 1800 + 350 ms fade).
  static const thanksFor = Duration(milliseconds: 1800);

  /// The reasons and their words (web FEEDBACK_REASONS).
  static const reasons = AgentBotParser.feedbackReasons;

  static String reasonLabel(String? r) {
    for (final (key, label) in reasons) {
      if (key == r) return label;
    }
    return '';
  }

  /// The rated line's words: "Helpful", or "Not helpful · Outdated".
  static String ratedLabel(AnswerFeedback? fb) {
    if (fb == null) return '';
    if (fb.helpful) return ratedUp;
    return fb.reason != null ? '$ratedDown · ${reasonLabel(fb.reason)}' : ratedDown;
  }

  /// A comment as sent: one line, trimmed, at most 500 characters.
  static String cleanComment(String? text) {
    final s = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.length > 500 ? s.substring(0, 500) : s;
  }

  /// Where a row starts: rated when the answer already has a vote.
  static HelpfulState start([AnswerFeedback? initial]) =>
      HelpfulState(initial != null ? HelpfulView.rated : HelpfulView.ask, initial);

  static HelpfulStep _same(HelpfulState s) => (state: s, send: null, ask: null, focus: false);

  static HelpfulStep step(HelpfulState s, HelpfulTap tap) {
    switch (tap) {
      case HelpfulVote(:final helpful):
        // The same thumb again: nothing new.
        if (s.current != null && s.current!.helpful == helpful) return _same(s);
        final fb = AnswerFeedback(helpful);
        return (state: HelpfulState(helpful ? HelpfulView.thanks : HelpfulView.down, fb), send: fb, ask: null, focus: false);
      case HelpfulReason(:final reason):
        if (s.view != HelpfulView.down) return _same(s);
        final fb = AnswerFeedback(false, reason);
        return (state: s.copyWith(current: fb), send: fb, ask: null, focus: false);
      case HelpfulComment(:final text):
        if (s.view != HelpfulView.down || s.commented) return _same(s);
        final c = cleanComment(text);
        // An empty comment sends nothing, and the field still says thanks (web).
        final fb = c.isEmpty ? null : AnswerFeedback(false, s.current?.reason, c);
        return (state: HelpfulState(s.view, fb ?? s.current, commented: true), send: fb, ask: null, focus: false);
      case HelpfulHuman():
        return (state: s.copyWith(view: HelpfulView.rated), send: null, ask: talkToPersonAsk, focus: false);
      case HelpfulRetry():
        return (state: s.copyWith(view: HelpfulView.rated), send: null, ask: null, focus: true);
      case HelpfulSettle():
        return s.view == HelpfulView.thanks && s.current?.helpful == true ? _same(s.copyWith(view: HelpfulView.rated)) : _same(s);
    }
  }

  /// The newest AI answer that can be rated: only it asks (web: an older
  /// unrated one steps aside). [answers] are the answers in order, each with
  /// its id and whether it is an AI answer that is not a fallback.
  static String? newestRateableId(Iterable<({String id, bool rateable})> answers) {
    String? last;
    for (final a in answers) {
      if (a.rateable && AgentBotParser.canRate(a.id)) last = a.id;
    }
    return last;
  }
}
