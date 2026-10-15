/// Waiting for a person, and the signals other app code can listen to.
/// Ported from the React Native SDK (src/core/handoverWaiting.ts), itself
/// from the web widget's src/ts/chat/handoverWaiting.ts (createConnectingSignal,
/// the signal names and details). The web dispatches the signals on its
/// window; here they go through a small bus ([WidgetSignalBus]) that the
/// provider exposes as `onWidgetSignal`.
///
///   cb:waiting-for-human  the visitor now waits for a person. detail:
///                         {offline, reason, backAt, emailCaptured}. From the
///                         server's handover-waiting, or the SDK's own
///                         connecting wait after [connectingSignalDelay].
///   cb:human-joined       a person (never the AI) joined. detail: {name}.
///   cb:wait-over          the wait ended without a person. detail:
///                         {reason: unavailable | cancelled | ended}.
///
/// No personal data (the visitor's email) is ever put in a detail. Pure.
library;

import 'dart:async';

class WidgetSignals {
  WidgetSignals._();

  static const waitingForHuman = 'cb:waiting-for-human';
  static const humanJoined = 'cb:human-joined';
  static const waitOver = 'cb:wait-over';

  static const all = [waitingForHuman, humanJoined, waitOver];

  /// The server's handover-waiting payload as a signal detail.
  static Map<String, dynamic> waitingDetail(dynamic data, {bool emailCaptured = false}) {
    final d = data is Map ? data : const {};
    final email = d['email'];
    return {
      'offline': d['offline'] == true,
      'reason': d['offline'] == true || d['reason'] == 'offline' ? 'offline' : 'busy',
      'backAt': d['backAt'] is String ? d['backAt'] : null,
      'emailCaptured': emailCaptured || (email is String && email.isNotEmpty),
    };
  }
}

/// A connecting wait with nobody yet after this long counts as waiting for a person.
const connectingSignalDelay = Duration(seconds: 20);

/// Chat closed when it was due: checked again this often until it opens.
const connectingRecheck = Duration(seconds: 2);

typedef SetTimer = Object Function(void Function() fn, Duration after);
typedef ClearTimer = void Function(Object timer);

Object _setTimer(void Function() fn, Duration after) => Timer(after, fn);
void _clearTimer(Object t) => (t as Timer).cancel();

/// The connecting wait's own cb:waiting-for-human, once per wait.
///
///   start()  a wait for a person began (or a restore re-entered one): fire
///            after [connectingSignalDelay] unless it ends first. A second
///            start() during the same wait changes nothing.
///   end()    a person joined, nobody could, the visitor left the queue, the
///            chat ended - or the server sent its own handover-waiting
///            (which already fired the signal): never fire for this wait.
///
/// Due while the chat is closed ([canFire] false), it waits for the chat to
/// open rather than offering something nobody can see.
class ConnectingSignal {
  ConnectingSignal(this._fire, {bool Function()? canFire, SetTimer? setTimer, ClearTimer? clearTimer})
      : _canFire = canFire ?? (() => true),
        _set = setTimer ?? _setTimer,
        _clear = clearTimer ?? _clearTimer;

  final void Function() _fire;
  final bool Function() _canFire;
  final SetTimer _set;
  final ClearTimer _clear;
  Object? _timer;
  bool _active = false;

  bool get pending => _active;

  void _cancel() {
    final t = _timer;
    if (t != null) _clear(t);
    _timer = null;
  }

  void _due() {
    _timer = null;
    if (!_active) return;
    if (!_canFire()) {
      _timer = _set(_due, connectingRecheck);
      return;
    }
    _active = false;
    _fire();
  }

  void start() {
    // Already counting for this wait: once per wait, not once per event.
    if (_active) return;
    _active = true;
    _cancel();
    _timer = _set(_due, connectingSignalDelay);
  }

  void end() {
    _active = false;
    _cancel();
  }
}

/// A listener bus for the widget signals. emit never throws.
class WidgetSignalBus {
  final Map<String, Set<void Function(Map<String, dynamic>)>> _listeners = {};

  /// Listen to a signal; call the returned function to stop.
  void Function() on(String name, void Function(Map<String, dynamic> detail) fn) {
    _listeners.putIfAbsent(name, () => {}).add(fn);
    return () => _listeners[name]?.remove(fn);
  }

  /// The number of listeners that took it.
  int emit(String name, Map<String, dynamic> detail) {
    var n = 0;
    for (final fn in List.of(_listeners[name] ?? const <void Function(Map<String, dynamic>)>{})) {
      try {
        fn(detail);
        n++;
      } catch (_) {
        // A listener's error is its own.
      }
    }
    return n;
  }
}
