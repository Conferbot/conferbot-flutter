/// The rules round the launcher's entrance, attention loop and idle call
/// (core/customization/launcher_entrance.dart, launcher_attention.dart,
/// launcher_idle_call.dart), as the React Native SDK's hooks keep them
/// (FloatingWidget/useLauncherEntrance.ts, useLauncherAttention.ts,
/// useLauncherIdleCall.ts). Each controller owns its clock and timers on an
/// [FxScheduler] (a fake one in tests) and reports what to draw at a time;
/// the launcher (conferbot_fab.dart) feeds them the chat's state and draws.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/customization/keyframes.dart';
import '../core/customization/launcher_attention.dart';
import '../core/customization/launcher_entrance.dart';
import '../core/customization/launcher_idle_call.dart';
import '../core/customization/launcher_motion.dart';

/// A cancellable timer.
abstract class FxTimer {
  void cancel();
}

/// The clock and timers the controllers run on.
abstract class FxScheduler {
  /// Milliseconds since the epoch.
  int now();
  FxTimer after(int ms, void Function() fn);
}

class _RealTimer implements FxTimer {
  final Timer t;
  _RealTimer(this.t);
  @override
  void cancel() => t.cancel();
}

/// The wall clock and dart:async timers.
class RealFxScheduler implements FxScheduler {
  const RealFxScheduler();
  @override
  int now() => DateTime.now().millisecondsSinceEpoch;
  @override
  FxTimer after(int ms, void Function() fn) => _RealTimer(Timer(Duration(milliseconds: ms < 0 ? 0 : ms), fn));
}

/// What the launcher remembers for the app session (the web's sessionStorage).
class LauncherFxSession {
  LauncherFxSession._();

  /// When the chat was last opened (0: not yet). Idle moments, attention and calls rest after it.
  static int openedAt = 0;

  /// The entrance each bot played this session (a different one plays once more).
  static final Map<String, String> entrancePlayed = {};

  /// The calls each bot made this session.
  static final Map<String, VisitState> visits = {};

  /// The clock the launcher's controllers run on (a test can set its own).
  static FxScheduler scheduler = const RealFxScheduler();

  static bool openedRecently(int now) => openedAt != 0 && now - openedAt < LauncherMotion.openedRestMs;

  @visibleForTesting
  static void reset() {
    openedAt = 0;
    entrancePlayed.clear();
    visits.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entrance
// ─────────────────────────────────────────────────────────────────────────────

/// What the launcher and the greeting look like at a moment of the entrance.
class EntranceLook {
  /// The launcher's opacity and transform (about its centre), and how much of it shows from the top (the ufo's beam: 1 = all).
  final double o, tx, ty, r, sx, sy, shown;

  /// The greeting card's opacity and drop.
  final double greetingO, greetingTy;
  const EntranceLook({this.o = 1, this.tx = 0, this.ty = 0, this.r = 0, this.sx = 1, this.sy = 1, this.shown = 1, this.greetingO = 1, this.greetingTy = 0});
}

/// How the launcher arrives: decided when the bot's settings arrive, once
/// per app session per bot and entrance, never over an open chat or with
/// reduced motion. The launcher is held invisible until the effect reveals
/// it; the greeting stays hidden until it has landed, then fades up 150ms
/// later. Opening the chat ends it at once. [busy] (it has not landed yet)
/// holds the attention loop and the idle call.
class LauncherEntranceController extends ChangeNotifier {
  final FxScheduler clock;
  LauncherEntranceController({FxScheduler? clock}) : clock = clock ?? LauncherFxSession.scheduler;

  /// If the effect has not started by then, the launcher simply appears.
  static const revealFailsafeMs = 6000;

  /// none, hold, play, done.
  String phase = 'none';
  EntrancePlan? plan;
  bool busy = false;
  int _startedAt = 0;
  bool _decided = false;
  final List<FxTimer> _timers = [];
  String _mode = 'classic';
  String _botId = '';

  /// Once, when the settings arrive.
  void decide({required String mode, required String botId, required bool reduced, required bool chatOpen}) {
    if (_decided) return;
    _decided = true;
    _mode = mode;
    _botId = botId.isEmpty ? 'bot' : botId;
    if (!shouldPlayEntrance(mode: mode, reducedMotion: reduced, chatOpen: chatOpen, played: LauncherFxSession.entrancePlayed[_botId] == mode)) return;
    phase = 'hold';
    busy = true;
    _timers.add(clock.after(revealFailsafeMs, () {
      if (phase == 'hold') finish();
    }));
    notifyListeners();
  }

  bool _laying = false;

  /// The launcher is laid out (its size and place): the stage, the effect, the phases.
  void laidOut(EntranceStage Function() stage) {
    if (phase != 'hold' || _laying) return;
    _laying = true;
    _timers.add(clock.after(entranceStartMs, () {
      if (phase != 'hold') return;
      final p = entrancePlan(_mode, stage());
      if (p == null) return finish();
      LauncherFxSession.entrancePlayed[_botId] = _mode;
      final tl = entranceTimeline(p);
      plan = p;
      phase = 'play';
      _startedAt = clock.now();
      _timers.add(clock.after(tl.endAt.ceil(), finish));
      _timers.add(clock.after(tl.settleAt.ceil(), () {
        busy = false;
        notifyListeners();
      }));
      notifyListeners();
    }));
  }

  /// Opening the chat by any route ends it at once.
  void chatOpened() {
    if (phase == 'hold' || phase == 'play') finish();
  }

  void finish() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    final was = phase;
    busy = false;
    phase = 'done';
    if (was != 'done') notifyListeners();
  }

  bool get active => phase == 'hold' || phase == 'play';

  /// Milliseconds into the effect.
  double get elapsed => phase == 'play' ? (clock.now() - _startedAt).toDouble() : 0;

  /// The launcher and the card at [t] ms (null: nothing to change).
  EntranceLook? lookAt(double t) {
    if (phase == 'hold') return const EntranceLook(o: 0, greetingO: 0);
    final p = plan;
    if (phase != 'play' || p == null) return null;
    final tl = entranceTimeline(p);
    final settle = evaluate([settleReveal.withDelay(tl.settleAt)], t);
    if (t < p.revealAt) return EntranceLook(o: 0, greetingO: settle.o, greetingTy: settle.ty);
    final arrive = p.arrive.withDelay(p.revealAt);
    final v = evaluate([arrive], t);
    final f = spriteFrame(FxSprite(x: 0, y: 0, w: 0, h: 0, tracks: [arrive]), t, v);
    return EntranceLook(o: f.o, tx: f.tx, ty: f.ty, r: f.r, sx: f.sx, sy: f.sy, shown: 1 - v.clip / 100, greetingO: settle.o, greetingTy: settle.ty);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attention
// ─────────────────────────────────────────────────────────────────────────────

/// The orbit's spark and the gloss band (attention.ts ATTENTION_CSS).
const orbitDot = 8.0;
const glossWidth = 0.45, glossTop = -0.3, glossHeight = 1.6;

/// The waving hand's box (a 20px emoji), turning about 70% 80%.
const handW = 22.0, handH = 20.0, handOx = 15.4, handOy = 16.0;

/// The opt-in "look here" loop: the first beat 1.5s after the launcher (or
/// the greeting card) shows, then a beat and stillness per lap while the
/// chat stays closed; paused while the launcher plays an idle or message
/// moment; not while an entrance lands; over once the chat is opened (and
/// not started when it was opened in the last 30 minutes); nothing with
/// reduced motion.
class LauncherAttentionController extends ChangeNotifier {
  final FxScheduler clock;
  LauncherAttentionController({FxScheduler? clock})
      : clock = clock ?? LauncherFxSession.scheduler,
        _over = LauncherFxSession.openedRecently((clock ?? LauncherFxSession.scheduler).now());

  String _mode = 'off';
  bool _enabled = false, _reduced = false, _cardShown = false, _moment = false, _entranceBusy = false, _hasSize = false, _wide = false;
  bool _over;
  List<Track> _tracks = const [];

  // The clock: ms run so far, and since when it has been running (null: stopped or paused).
  double _ran = 0;
  int? _since;

  String get mode => _mode;
  String? get target => attentionTarget(_mode);
  bool get active => _enabled && target != null && !_reduced && !_over;

  /// Moving the launcher: its idle moments hold off and the load ripples give way.
  bool get onLauncher => active && target == 'launcher';
  bool get running => active && !_entranceBusy && _hasSize && (target == 'launcher' || _cardShown);

  void update({
    required String mode,
    required bool enabled,
    required bool reduced,
    required bool chatOpen,
    required bool cardShown,
    required bool moment,
    required bool entranceBusy,
    required bool hasSize,
    required bool wide,
  }) {
    final wasRunning = running;
    final wasActive = active;
    final changed = mode != _mode || wide != _wide;
    if (changed) {
      _mode = mode;
      _wide = wide;
      _tracks = attentionTracks(mode, false, wide);
    }
    _enabled = enabled;
    _reduced = reduced;
    if (chatOpen) _over = true;
    _cardShown = cardShown;
    _entranceBusy = entranceBusy;
    _hasSize = hasSize;
    final now = clock.now();
    if (running && (!wasRunning || changed)) {
      // Run (again, from the start: the card showing again restarts it).
      _ran = 0;
      _since = moment ? null : now;
    } else if (!running && wasRunning) {
      _ran = 0;
      _since = null;
    } else if (running && moment != _moment) {
      // A launcher moment (idle / message) pauses it.
      if (moment && _since != null) {
        _ran += now - _since!;
        _since = null;
      } else if (!moment && _since == null) {
        _since = now;
      }
    }
    _moment = moment;
    if (running != wasRunning || active != wasActive) notifyListeners();
  }

  /// Milliseconds on the loop's clock: the intro, then lap after lap.
  double get elapsed {
    if (!running || _tracks.isEmpty) return 0;
    final t = _ran + (_since == null ? 0 : clock.now() - _since!);
    final intro = _tracks.map((x) => x.options.delay).reduce((a, b) => a > b ? a : b);
    final period = _tracks.first.options.duration;
    return t < intro ? t : intro + (t - intro) % period;
  }

  /// A part's values at [t] ms (null when the mode has no such part or it is not running).
  FxValues? part(String name, double t) {
    if (!running) return null;
    for (final tr in _tracks) {
      if (tr.part == name) return evaluate([tr], t, attentionBase[name]);
    }
    return null;
  }

  bool has(String name) => running && _tracks.any((t) => t.part == name);
}

// ─────────────────────────────────────────────────────────────────────────────
// Idle call
// ─────────────────────────────────────────────────────────────────────────────

/// Where the 3-day rest is kept.
abstract class IdleCallRestStore {
  Future<int> read(String botId);
  void write(String botId, int until);
}

class PrefsIdleCallRestStore implements IdleCallRestStore {
  const PrefsIdleCallRestStore();
  static String key(String botId) => 'conferbot_idlecall_rest_${botId.isEmpty ? 'default' : botId}';

  @override
  Future<int> read(String botId) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key(botId));
      final v = raw == null ? null : jsonDecode(raw);
      return v is Map && v['until'] is num ? (v['until'] as num).toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  void write(String botId, int until) {
    SharedPreferences.getInstance().then((p) => p.setString(key(botId), jsonEncode({'until': until}))).catchError((_) => false);
  }
}

/// The idle call: after the owner's delay, if the visitor has not opened the
/// chat, the mascot slips out from behind the launcher and calls them over,
/// with a speech bubble that opens the chat. One call per screen, two per
/// app session 3 minutes apart, then 3 days' rest (also after an opening);
/// closing the greeting means none for the session. A call waits while the
/// chat is open, the app is in the background, the keyboard is up, an
/// entrance lands, or the greeting has had less than 15s alone.
class LauncherIdleCallController extends ChangeNotifier {
  final FxScheduler clock;
  final IdleCallRestStore store;
  LauncherIdleCallController({FxScheduler? clock, this.store = const PrefsIdleCallRestStore()}) : clock = clock ?? LauncherFxSession.scheduler;

  // What the launcher reports.
  bool chatOpen = false, appActive = true, keyboard = false, entranceBusy = false;
  double? width, height;
  String position = 'right';
  bool _cardShown = false;
  int _cardSince = 0;

  IdleCallPerformance? perf;
  int _startedAt = 0;
  bool _started = false, _destroyed = false, _playing = false;
  String _mode = 'off', _botId = '';
  int _restUntil = 0;
  final List<FxTimer> _timers = [];

  set cardShown(bool v) {
    if (v && !_cardShown) _cardSince = clock.now();
    if (!v) _cardSince = 0;
    _cardShown = v;
  }

  bool get cardShown => _cardShown;

  void _later(void Function() fn, int ms) => _timers.add(clock.after(ms, fn));

  VisitState get _visit => LauncherFxSession.visits[_botId] ?? const VisitState();
  bool _allowed() => !LauncherFxSession.openedRecently(clock.now()) && callAllowed(_visit, _restUntil, clock.now());
  bool _blocked() {
    final greetingHasTheFloor = _cardShown && clock.now() - _cardSince < greetingFirstMs;
    return chatOpen || !appActive || keyboard || greetingHasTheFloor || entranceBusy || width == null || height == null;
  }

  /// Once, when the settings arrive.
  Future<void> start({required String mode, required int delay, required String botId, required bool reduced}) async {
    if (_started) return;
    _started = true;
    _mode = mode;
    _botId = botId;
    if (mode == 'off' || reduced) return;
    _restUntil = await store.read(botId);
    if (_destroyed || !_allowed()) return;
    _later(_attempt, delay * 1000);
  }

  void _attempt() {
    if (_destroyed) return;
    if (!_allowed()) return _destroy();
    if (_playing || _blocked()) return _later(_attempt, idleCallRetryMs);
    final now = clock.now();
    final next = afterCall(_visit, now);
    LauncherFxSession.visits[_botId] = next.visit;
    // After the last call this session, rest for a few days.
    if (next.rest) store.write(_botId, now + restMs);
    final p = idleCallPerformance(_mode, idleCallGeometry(width!, height!, position, _cardShown));
    _playing = true;
    perf = p;
    _startedAt = now;
    _later(stop, p.total.ceil() + 80);
    notifyListeners();
  }

  /// The call over (or cut short by a tap on its bubble).
  void stop() {
    _playing = false;
    if (perf != null) {
      perf = null;
      notifyListeners();
    }
  }

  void _destroy() {
    _destroyed = true;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    stop();
  }

  /// Opening the chat: the call ends, and they are left alone for a few days.
  void chatOpened() {
    chatOpen = true;
    if (_destroyed || _mode == 'off' || !_started) return;
    store.write(_botId, clock.now() + restMs);
    _destroy();
  }

  /// The greeting was closed ("not now"): no more calls this session.
  void greetingClosed() {
    if (_mode == 'off') return;
    LauncherFxSession.visits[_botId] = _visit.copyWith(quiet: true);
    _destroy();
  }

  /// Milliseconds into the call.
  double get elapsed => perf == null ? 0 : (clock.now() - _startedAt).toDouble();

  @override
  void dispose() {
    _destroyed = true;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
