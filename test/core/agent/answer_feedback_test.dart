// "Helpful?" as the web's ts/chat/answerFeedback.ts (#46), the cases of the
// React Native SDK's __tests__/core/answerFeedback.test.ts.
import 'package:conferbot_flutter/src/core/agent/agent_bot.dart';
import 'package:conferbot_flutter/src/core/agent/answer_feedback.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

({HelpfulState s, List<AnswerFeedback> sent}) play(HelpfulState s, List<HelpfulTap> taps) {
  final sent = <AnswerFeedback>[];
  for (final tap in taps) {
    final r = Helpful.step(s, tap);
    if (r.send != null) sent.add(r.send!);
    s = r.state;
  }
  return (s: s, sent: sent);
}

void main() {
  test('sends a No at once, without waiting for a reason', () {
    final r = Helpful.step(Helpful.start(), const HelpfulVote(false));
    expect(r.send, const AnswerFeedback(false));
    expect(r.state.view, HelpfulView.down);
  });

  test('a reason, then a comment, each go as they are given', () {
    final p = play(Helpful.start(), const [HelpfulVote(false), HelpfulReason('outdated'), HelpfulComment('  the   price changed \n')]);
    expect(p.sent, const [
      AnswerFeedback(false),
      AnswerFeedback(false, 'outdated'),
      AnswerFeedback(false, 'outdated', 'the price changed'),
    ]);
    expect(p.s.commented, isTrue);
    expect(Helpful.ratedLabel(p.s.current), 'Not helpful · Outdated');
  });

  test('a comment without a reason, and an empty one sends nothing', () {
    expect(play(Helpful.start(), const [HelpfulVote(false), HelpfulComment('meh')]).sent[1], const AnswerFeedback(false, null, 'meh'));
    final p = play(Helpful.start(), const [HelpfulVote(false), HelpfulComment('   ')]);
    expect(p.sent, const [AnswerFeedback(false)]);
    expect(p.s.commented, isTrue);
    // Only one comment.
    expect(Helpful.step(p.s, const HelpfulComment('again')).send, isNull);
  });

  test('Yes thanks, then settles into the rated line', () {
    final p = play(Helpful.start(), const [HelpfulVote(true)]);
    expect(p.sent, const [AnswerFeedback(true)]);
    expect(p.s.view, HelpfulView.thanks);
    expect(Helpful.step(p.s, const HelpfulSettle()).state.view, HelpfulView.rated);
    expect(Helpful.ratedLabel(p.s.current), 'Helpful');
  });

  test('the vote can change; the same thumb again sends nothing', () {
    final start = Helpful.start(const AnswerFeedback(true));
    expect(start.view, HelpfulView.rated);
    expect(Helpful.step(start, const HelpfulVote(true)).send, isNull);
    final p = play(start, const [HelpfulVote(false)]);
    expect(p.sent, const [AnswerFeedback(false)]);
    expect(p.s.view, HelpfulView.down);
    // A settle after switching to No does not hide the reasons.
    expect(Helpful.step(p.s, const HelpfulSettle()).state.view, HelpfulView.down);
  });

  test("Talk to a person asks in the visitor's words; Ask another way focuses the composer", () {
    final down = play(Helpful.start(), const [HelpfulVote(false)]).s;
    final human = Helpful.step(down, const HelpfulHuman());
    expect(human.ask, "I'd like to talk to a person, please.");
    expect(human.state.view, HelpfulView.rated);
    final retry = Helpful.step(down, const HelpfulRetry());
    expect(retry.focus, isTrue);
    expect(retry.state.view, HelpfulView.rated);
  });

  test('reads a stored vote as the web does', () {
    expect(AnswerFeedback.fromJson(null), isNull);
    expect(AnswerFeedback.fromJson({'helpful': 'no'}), isNull);
    expect(AnswerFeedback.fromJson({'helpful': true, 'reason': 'wrong', 'comment': 'x'}), const AnswerFeedback(true));
    expect(AnswerFeedback.fromJson({'helpful': false, 'reason': 'bogus', 'comment': ' ok '}), const AnswerFeedback(false, null, 'ok'));
    expect(AnswerFeedback.fromJson({'helpful': false, 'comment': 'a' * 600})!.comment, hasLength(500));
    expect(const AnswerFeedback(false, 'wrong', 'c').toJson(), {'helpful': false, 'reason': 'wrong', 'comment': 'c'});
  });

  test('only the newest rateable answer asks', () {
    const a = '0123456789abcdef01234567';
    const b = '0123456789abcdef89abcdef';
    expect(Helpful.newestRateableId(const [(id: a, rateable: true), (id: b, rateable: true)]), b);
    // A fallback or a person's message steps out; an id the server did not give cannot be rated.
    expect(Helpful.newestRateableId(const [(id: a, rateable: true), (id: b, rateable: false)]), a);
    expect(Helpful.newestRateableId(const [(id: 'agent_msg_1', rateable: true)]), isNull);
  });

  test("keeps the vote on the answer's record entry", () {
    final state = ChatState.instance..reset();
    state.initialize(chatSessionId: 's1', visitorId: 'v1', botId: 'b1');
    state.pushToRecord(RecordEntry(id: 'a1', shape: 'agent-message', type: 'agent-message', text: 'x'));
    state.pushToRecord(RecordEntry(id: 'u1', shape: 'user-live-message', type: 'user-live-message', text: 'hi'));
    expect(state.setAnswerFeedback('a1', const AnswerFeedback(false, 'wrong').toJson(), at: '2026-10-16T10:00:00.000Z'), isTrue);
    final rec = state.getRecordForServer();
    expect(rec[0]['feedback'], {'helpful': false, 'reason': 'wrong', 'at': '2026-10-16T10:00:00.000Z'});
    expect(rec[0]['type'], 'agent-message');
    expect(rec[0]['data'], {'text': 'x'});
    expect(rec[1].containsKey('feedback'), isFalse);
    // The vote changes in place.
    state.setAnswerFeedback('a1', const AnswerFeedback(true).toJson(), at: 't2');
    expect(state.getRecordForServer()[0]['feedback'], {'helpful': true, 'at': 't2'});
    expect(state.setAnswerFeedback('nope', const AnswerFeedback(true).toJson()), isFalse);
    state.reset();
  });
}
