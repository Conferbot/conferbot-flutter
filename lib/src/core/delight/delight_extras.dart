/// The conversation's human touches, wired (core/delight/delight.dart; web
/// ts/chat/delight/index.ts, which watches the transcript). Ported from the
/// React Native SDK (context/hooks/useDelight.ts):
///
///   - the bot reacts to an answer that deserves it, 550 ms after it lands;
///   - bookings, payments and perfect scores celebrate (unless the visitor
///     asks for less motion);
///   - a question that waits a long while gets a gentle nudge;
///   - the latest answer can be changed with one tap ("Edit"), which takes
///     the conversation back to that question (NodeFlowEngine.rewindTo).
///
/// An answer is a conversation row the provider stamps with what it
/// answered ([AnswerOf]: the step, its type, its text as a score where it
/// is one). Each touch follows the owner's setting (botReactions,
/// celebrations, stallNudges, allowChangeAnswer; all on unless false).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../node_flow_engine.dart';
import 'delight.dart';

/// What an answer row answered.
class AnswerOf {
  final String nodeId;
  final String type;

  /// The answer's text as the web reads it ("4/5" for a score).
  final String text;
  const AnswerOf({required this.nodeId, required this.type, required this.text});
}

/// What an answer got: a tapback and / or a burst (a new [celebrate]
/// restarts it).
class AnswerTouch {
  final String? reaction;
  final int? celebrate;
  const AnswerTouch({this.reaction, this.celebrate});
}

/// A row of the conversation as the touches read it.
class DelightRow {
  final String id;

  /// The step that said it, when a step did.
  final String? nodeId;

  /// The visitor's own bubble.
  final bool visitor;
  final DateTime time;
  const DelightRow({required this.id, this.nodeId, this.visitor = false, required this.time});
}

class DelightExtras extends ChangeNotifier {
  DelightExtras({
    required dynamic Function() customizations,
    required NodeFlowEngine Function() engine,
    required List<DelightRow> Function() rows,
    required bool Function() chatVisible,
    required bool Function() locked,
    required void Function(int fromIndex) cut,
    DateTime Function()? now,
  })  : _customizations = customizations,
        _engine = engine,
        _rows = rows,
        _chatVisible = chatVisible,
        _locked = locked,
        _cut = cut,
        _now = now ?? DateTime.now {
    _stall = StallWatch(
      isVisible: () => _chatVisible() && appActive,
      composerValue: () => _composer,
      show: (hint) {
        stallHint = hint;
        _notify();
      },
      hide: () {
        stallHint = null;
        _notify();
      },
      now: () => _now().millisecondsSinceEpoch,
    );
  }

  final dynamic Function() _customizations;
  final NodeFlowEngine Function() _engine;
  final List<DelightRow> Function() _rows;
  final bool Function() _chatVisible;
  final bool Function() _locked;
  final void Function(int fromIndex) _cut;
  final DateTime Function() _now;
  late final StallWatch _stall;

  /// The visitor asked for less motion (MediaQuery.disableAnimations): no confetti.
  bool reducedMotion = false;

  /// The app is in front (the nudge waits while it is not).
  bool appActive = true;

  /// What each answer row answered, by row id.
  final Map<String, AnswerOf> answers = {};

  /// The tapbacks and bursts, by row id.
  final Map<String, AnswerTouch> touches = {};

  /// The answer row "Edit" sits under, or null.
  String? changeRowId;

  /// "No rush - ..." while a question waits, or null.
  String? stallHint;

  String _composer = '';
  String? _armedFor;
  Timer? _changeTimer;
  final List<Timer> _touchTimers = [];
  int _burstSeq = 0;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// A visitor's answer row was added (a step's answer, given just now).
  void answered(String rowId, AnswerOf answer, {DateTime? at}) {
    answers[rowId] = answer;
    _stall.disarm();
    // A conversation put back on screen (restored) is not news.
    if (at != null && _now().difference(at).inMilliseconds > 30000) return;
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: Delight.reactAfterMs), () {
      _touchTimers.remove(timer);
      final touch = Delight.touchesFor(_customizations(), answer.type, answer.text, reducedMotion);
      if (touch.reaction == null && !touch.celebrate) return;
      touches[rowId] = AnswerTouch(reaction: touch.reaction, celebrate: touch.celebrate ? ++_burstSeq : null);
      _notify();
    });
    _touchTimers.add(timer);
  }

  /// The burst ran out: drawn no more.
  void clearBurst(String rowId) {
    final t = touches[rowId];
    if (t?.celebrate == null) return;
    touches[rowId] = AnswerTouch(reaction: t!.reaction);
    _notify();
  }

  /// The step waiting now ([nodeId] and its type), or null for none; each
  /// new question restarts the nudge's wait.
  void stepChanged(String? nodeId, String? stepType, {bool loading = false}) {
    // The typing dots before the next step: keep what is up.
    if (loading) return;
    final key = nodeId == null ? null : '$nodeId:${stepType ?? ''}';
    if (key == _armedFor) return;
    _armedFor = key;
    _stall.disarm();
    final type = stepType ?? '';
    if (key != null && Delight.touchOn(_customizations(), 'stallNudges') && Delight.nudgesWhileWaiting(type)) _stall.arm(type);
  }

  /// The visitor touched, scrolled or typed in the chat.
  void noteActivity() => _stall.touch();

  /// What is in the composer (a nudge waits while something is typed).
  void setComposerValue(String v) {
    _composer = v;
    _stall.touch();
  }

  /// The conversation changed (a row, the bot busy or not, the step): "Edit"
  /// goes, and comes back under the latest answer once the bot has been
  /// quiet for a moment.
  void conversationChanged() {
    _changeTimer?.cancel();
    if (changeRowId != null) {
      changeRowId = null;
      _notify();
    }
    _changeTimer = Timer(const Duration(milliseconds: Delight.quietBeforeChangeMs), _refreshChange);
  }

  QuestionPoint? _pointFor(AnswerOf a) {
    final points = _engine().questionPoints;
    for (var i = points.length - 1; i >= 0; i--) {
      if (points[i].nodeId == a.nodeId) return points[i];
    }
    return null;
  }

  void _refreshChange() {
    final rows = _rows();
    DelightRow? last;
    for (var i = rows.length - 1; i >= 0; i--) {
      if (rows[i].visitor) {
        last = rows[i];
        break;
      }
    }
    final a = last == null ? null : answers[last.id];
    if (a == null) return;
    final engine = _engine();
    final point = _pointFor(a);
    if (point == null) return;
    final show = Delight.showChangeFor(
      customizations: _customizations(),
      locked: _locked() || engine.isFlowComplete,
      botBusy: engine.isProcessing,
      isLatestAnswer: true,
      questionType: point.type,
      typesSince: engine.typesSince(point),
    );
    if (show && changeRowId != last!.id) {
      changeRowId = last.id;
      _notify();
    }
  }

  /// Where "Edit" cuts the conversation: the question's own rows just above
  /// the answer (its bubble, its frozen choices), else the answer itself.
  static int cutIndexFor(List<DelightRow> rows, int answerIndex, String nodeId) {
    var cut = answerIndex;
    for (var i = answerIndex - 1; i >= 0; i--) {
      if (rows[i].nodeId != nodeId) break;
      cut = i;
    }
    return cut;
  }

  /// "Edit": the conversation from the question again.
  Future<bool> changeAnswer() async {
    final id = changeRowId;
    final rows = _rows();
    final index = rows.indexWhere((r) => r.id == id);
    final a = id == null ? null : answers[id];
    if (index < 0 || a == null) return false;
    final point = _pointFor(a);
    if (point == null) return false;
    final cut = cutIndexFor(rows, index, a.nodeId);
    changeRowId = null;
    _stall.disarm();
    _armedFor = null;
    for (final r in rows.skip(cut)) {
      answers.remove(r.id);
      touches.remove(r.id);
    }
    _cut(cut);
    _notify();
    return _engine().rewindTo(point.id);
  }

  /// A new conversation: nothing kept.
  void reset() {
    _changeTimer?.cancel();
    for (final t in _touchTimers) {
      t.cancel();
    }
    _touchTimers.clear();
    _stall.disarm();
    _armedFor = null;
    answers.clear();
    touches.clear();
    changeRowId = null;
    stallHint = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _changeTimer?.cancel();
    for (final t in _touchTimers) {
      t.cancel();
    }
    _stall.disarm();
    super.dispose();
  }
}
