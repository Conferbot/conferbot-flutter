/// The chat's sounds, as the web widget plays them. Ported from the React
/// Native SDK (src/core/messageSound.ts), itself from conferbot-widget
/// src/ts/chat/messageSound.ts (soundRecipe, packRecipe, playMessageFor,
/// playPackSound, MIN_GAP_MS, PACK_GAP_MS), the launcher sound in
/// src/index.ts (_playToggleSound and the soundUrl it picks) and
/// src/ts/layout/ownerLayout.ts (normalizeMessageSound).
///
///   messageSound   "off" (default) | "pop" | "chime" | "bubble": a message
///                  arrived (the bot's step drawn, an agent's message)
///   soundPack      "off" (default) | "soft" | "playful" | "retro" |
///                  "bubbly" | "premium": open, message, send and close as a
///                  set; a pack replaces the single message sound and the
///                  launcher sound, so nothing doubles up
///   launcher sound enableWidgetToggleSound with checkedSoundTab "choose"
///                  (widgetToggleSound) or "upload" (customWidgetSoundUrl):
///                  an audio file played when the chat opens or closes
///
/// The visitor's "Sound off" in the chat menu silences all of them (the web
/// keeps it as localStorage "conferbot-sound-enabled" = "false").
///
/// The web synthesises each tone with Web Audio (an oscillator per step, its
/// frequency and gain on exponential ramps), so there are no files. An app
/// has no Web Audio: [MessageSounds.renderWav] computes the same steps into a
/// small 16-bit mono WAV (about 20 KB for the longest sound) that a player
/// can load. Pure: no audio, storage or clock of its own.
library;

import 'dart:math' as math;
import 'dart:typed_data';

enum Wave { sine, triangle, square }

enum SoundEvent { open, message, send, close }

/// One oscillator step of a tone.
class ToneStep {
  /// Start, seconds after the sound begins.
  final double at;

  /// Frequency at the start and end of the step (Hz).
  final double from;
  final double to;

  /// Length of the step (seconds).
  final double dur;
  final Wave type;

  /// Peak gain, 0-1.
  final double gain;

  const ToneStep({required this.at, required this.from, required this.to, required this.dur, required this.type, required this.gain});

  @override
  bool operator ==(Object other) =>
      other is ToneStep && other.at == at && other.from == from && other.to == to && other.dur == dur && other.type == type && other.gain == gain;

  @override
  int get hashCode => Object.hash(at, from, to, dur, type, gain);

  @override
  String toString() => 'ToneStep($at, $from->$to, $dur, ${type.name}, $gain)';
}

/// What to play for a moment: a tone (its cache key and notes) or a file.
sealed class SoundCue {
  const SoundCue();
}

class ToneCue extends SoundCue {
  final String key;
  final List<ToneStep> steps;
  const ToneCue(this.key, this.steps);
}

class UrlCue extends SoundCue {
  final String url;
  const UrlCue(this.url);
}

ToneStep _note(double at, double from, double dur, Wave type, double gain, [double? to]) =>
    ToneStep(at: at, from: from, to: to ?? from, dur: dur, type: type, gain: gain);

List<ToneStep> _run(List<double> freqs, double step, double dur, Wave type, double gain) =>
    [for (var i = 0; i < freqs.length; i++) _note(i * step, freqs[i], dur, type, gain)];

// C5 E5 G5 C6, and the rest of the notes the packs use.
const _c5 = 523.25, _e5 = 659.25, _g5 = 783.99, _c6 = 1046.5, _e6 = 1318.5, _g6 = 1568.0, _b5 = 987.77, _a4 = 440.0, _e4 = 329.63;

final Map<String, Map<SoundEvent, List<ToneStep>>> _packs = {
  // Soft: low, rounded sines - barely there.
  'soft': {
    SoundEvent.open: [_note(0, _a4, 0.16, Wave.sine, 0.07, _e5), _note(0.08, _e5, 0.16, Wave.sine, 0.05)],
    SoundEvent.message: [_note(0, _e5, 0.16, Wave.sine, 0.08), _note(0.07, _a4 * 2, 0.2, Wave.sine, 0.05)],
    SoundEvent.send: [_note(0, _c5, 0.08, Wave.sine, 0.05, _g5)],
    SoundEvent.close: [_note(0, _e5, 0.16, Wave.sine, 0.06, _a4)],
  },
  // Playful: a bright arpeggio and a boing.
  'playful': {
    SoundEvent.open: _run([_c5, _e5, _g5], 0.065, 0.09, Wave.triangle, 0.1),
    SoundEvent.message: [_note(0, 300, 0.14, Wave.sine, 0.14, 900), _note(0.13, 900, 0.06, Wave.sine, 0.06)],
    SoundEvent.send: [_note(0, 600, 0.06, Wave.sine, 0.12, 1050)],
    SoundEvent.close: _run([_g5, _e5, _c5], 0.06, 0.08, Wave.triangle, 0.08),
  },
  // Retro: square-wave chiptune - a power-up and a coin.
  'retro': {
    SoundEvent.open: _run([_e4, _a4, _e5, _a4 * 2], 0.045, 0.05, Wave.square, 0.045),
    SoundEvent.message: [_note(0, _b5, 0.07, Wave.square, 0.05), _note(0.07, _e6, 0.16, Wave.square, 0.045)],
    SoundEvent.send: [_note(0, 660, 0.04, Wave.square, 0.04)],
    SoundEvent.close: _run([_a4 * 2, _e5, _a4], 0.05, 0.05, Wave.square, 0.04),
  },
  // Bubbly: rising bubbles.
  'bubbly': {
    SoundEvent.open: [
      _note(0, 400, 0.06, Wave.sine, 0.13, 800),
      _note(0.07, 500, 0.06, Wave.sine, 0.11, 1000),
      _note(0.14, 650, 0.07, Wave.sine, 0.09, 1300),
    ],
    SoundEvent.message: [_note(0, 380, 0.07, Wave.sine, 0.16, 760), _note(0.08, 520, 0.07, Wave.sine, 0.12, 1040)],
    SoundEvent.send: [_note(0, 700, 0.05, Wave.sine, 0.1, 1400)],
    SoundEvent.close: [_note(0, 800, 0.09, Wave.sine, 0.1, 400)],
  },
  // Premium: a soft bell - a fundamental and its octave, long and low.
  'premium': {
    SoundEvent.open: [_note(0, _c5, 0.42, Wave.sine, 0.07), _note(0, _c6, 0.34, Wave.sine, 0.03), _note(0.1, _g5, 0.36, Wave.sine, 0.04)],
    SoundEvent.message: [_note(0, _c6, 0.32, Wave.triangle, 0.07), _note(0.09, _g6, 0.28, Wave.sine, 0.035)],
    SoundEvent.send: [_note(0, _a4 * 2, 0.1, Wave.sine, 0.045)],
    SoundEvent.close: [_note(0, _g5, 0.26, Wave.sine, 0.05, _c5)],
  },
};

class MessageSounds {
  MessageSounds._();

  static const messageSounds = ['off', 'pop', 'chime', 'bubble'];
  static const soundPacks = ['off', 'soft', 'playful', 'retro', 'bubbly', 'premium'];

  /// The visitor's switch, under the web's own key.
  static const soundEnabledKey = 'conferbot-sound-enabled';

  static String normalizeMessageSound(dynamic v) => messageSounds.contains(v) ? v as String : 'off';
  static String normalizeSoundPack(dynamic v) => soundPacks.contains(v) ? v as String : 'off';

  static dynamic _get(dynamic c, String key) => c is Map ? c[key] : null;

  /// True when a pack (not "off") is chosen.
  static bool soundPackOn(dynamic c) => normalizeSoundPack(_get(c, 'soundPack')) != 'off';

  /// The notes of each message sound.
  static List<ToneStep> soundRecipe(dynamic kind) {
    switch (normalizeMessageSound(kind)) {
      case 'pop':
        return const [ToneStep(at: 0, from: 520, to: 880, dur: 0.09, type: Wave.sine, gain: 0.18)];
      case 'chime':
        return const [
          ToneStep(at: 0, from: 880, to: 880, dur: 0.18, type: Wave.triangle, gain: 0.12),
          ToneStep(at: 0.09, from: 1318.5, to: 1318.5, dur: 0.22, type: Wave.triangle, gain: 0.1),
        ];
      case 'bubble':
        return const [
          ToneStep(at: 0, from: 380, to: 760, dur: 0.07, type: Wave.sine, gain: 0.16),
          ToneStep(at: 0.08, from: 520, to: 1040, dur: 0.07, type: Wave.sine, gain: 0.12),
        ];
      default:
        return const [];
    }
  }

  /// The notes of [pack] for [event].
  static List<ToneStep> packRecipe(dynamic pack, SoundEvent event) {
    final p = normalizeSoundPack(pack);
    return p == 'off' ? const [] : (_packs[p]![event] ?? const []);
  }

  /// At most one message sound this often.
  static const minGapMs = 800;

  /// A pack's own moments can follow each other quickly (open, then the
  /// greeting arriving); each has its own gap.
  static const packGapMs = {SoundEvent.open: 400, SoundEvent.message: 800, SoundEvent.send: 250, SoundEvent.close: 400};

  /// The launcher sound's file, or "" (none, or a pack plays open and close instead).
  static String toggleSoundUrl(dynamic c) {
    if (_get(c, 'enableWidgetToggleSound') != true || soundPackOn(c)) return '';
    final tabRaw = _get(c, 'checkedSoundTab');
    final tab = tabRaw is String && tabRaw.isNotEmpty ? tabRaw : 'choose';
    final url = tab == 'choose' ? _get(c, 'widgetToggleSound') : (tab == 'upload' ? _get(c, 'customWidgetSoundUrl') : '');
    return url is String && RegExp(r'^https?://', caseSensitive: false).hasMatch(url.trim()) ? url.trim() : '';
  }

  /// Whether the bot has any sound at all (the chat menu offers Sound on / off only then).
  static bool hasAnySound(dynamic c) =>
      soundPackOn(c) || normalizeMessageSound(_get(c, 'messageSound')) != 'off' || toggleSoundUrl(c).isNotEmpty;

  /// The visitor's stored switch: only "false" turns sounds off (blocked or
  /// empty storage reads as on).
  static bool soundEnabledFrom(dynamic stored) => stored != 'false';

  /// The cue for [event] under the owner's settings: the pack's sound when a
  /// pack is on; else the message sound for "message" and the launcher file
  /// for "open" / "close"; "send" has a sound only in a pack.
  static SoundCue? cueFor(dynamic c, SoundEvent event) {
    if (soundPackOn(c)) {
      final pack = normalizeSoundPack(_get(c, 'soundPack'));
      final steps = packRecipe(pack, event);
      return steps.isNotEmpty ? ToneCue('$pack.${event.name}', steps) : null;
    }
    if (event == SoundEvent.message) {
      final kind = normalizeMessageSound(_get(c, 'messageSound'));
      final steps = soundRecipe(kind);
      return steps.isNotEmpty ? ToneCue('message.$kind', steps) : null;
    }
    if (event == SoundEvent.open || event == SoundEvent.close) {
      final url = toggleSoundUrl(c);
      return url.isNotEmpty ? UrlCue(url) : null;
    }
    return null;
  }

  // -------------------------------------------------------------- the tone as a WAV file

  /// Web Audio starts the notes this long after the call (t0 = currentTime + 0.01).
  static const _leadS = 0.01;

  /// The gain's attack (exponentialRampToValueAtTime(gain, t + 0.012)).
  static const _attackS = 0.012;

  /// Each oscillator stops this long after its note (osc.stop(t + dur + 0.02)).
  static const _tailS = 0.02;
  static const _floor = 0.0001;

  static double _wave(Wave type, double phase) {
    final p = phase - phase.floorToDouble(); // 0..1 of a cycle
    switch (type) {
      case Wave.square:
        return p < 0.5 ? 1 : -1;
      case Wave.triangle:
        return p < 0.25 ? 4 * p : (p < 0.75 ? 2 - 4 * p : 4 * p - 4);
      case Wave.sine:
        return math.sin(2 * math.pi * p);
    }
  }

  /// A value on an exponential ramp from a to b, at fraction f (Web Audio's
  /// exponentialRampToValueAtTime).
  static double _expRamp(double a, double b, double f) => a * math.pow(b / a, f.clamp(0.0, 1.0)).toDouble();

  /// The gain of a step [t] seconds into it: 0.0001, up to `gain` in 12 ms,
  /// down to 0.0001 at `dur`.
  static double stepGain(ToneStep s, double t) {
    if (t < 0 || t > s.dur + _tailS) return 0;
    if (t <= _attackS) return _expRamp(_floor, s.gain, t / _attackS);
    if (t <= s.dur) return _expRamp(s.gain, _floor, (t - _attackS) / math.max(1e-6, s.dur - _attackS));
    return _floor;
  }

  /// The step's frequency [t] seconds into it: an exponential glide from
  /// `from` to `to` over `dur`.
  static double stepFrequency(ToneStep s, double t) => _expRamp(s.from, s.to, t / s.dur);

  /// Seconds the sound lasts, its lead-in and tails included.
  static double toneLength(List<ToneStep> steps) =>
      steps.isEmpty ? 0 : _leadS + steps.map((s) => s.at + s.dur + _tailS).reduce(math.max);

  /// The steps as samples in [-1, 1].
  static Float32List renderSamples(List<ToneStep> steps, [int sampleRate = 22050]) {
    final n = (toneLength(steps) * sampleRate).ceil();
    // Float32 as the web's Float32Array, so the samples come out the same.
    final out = Float32List(n);
    for (final s in steps) {
      final start = ((_leadS + s.at) * sampleRate).round();
      final len = ((s.dur + _tailS) * sampleRate).ceil();
      var phase = 0.0;
      for (var i = 0; i < len && start + i < n; i++) {
        final t = i / sampleRate;
        out[start + i] += _wave(s.type, phase) * stepGain(s, t);
        phase += stepFrequency(s, math.min(t, s.dur)) / sampleRate;
      }
    }
    for (var i = 0; i < n; i++) {
      out[i] = out[i].clamp(-1.0, 1.0);
    }
    return out;
  }

  /// The steps as a 16-bit mono PCM WAV file.
  static Uint8List renderWav(List<ToneStep> steps, [int sampleRate = 22050]) {
    final samples = renderSamples(steps, sampleRate);
    final data = samples.length * 2;
    final bytes = Uint8List(44 + data);
    final view = ByteData.view(bytes.buffer);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes[o + i] = s.codeUnitAt(i);
      }
    }

    str(0, 'RIFF');
    view.setUint32(4, 36 + data, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    view.setUint32(16, 16, Endian.little); // PCM chunk size
    view.setUint16(20, 1, Endian.little); // PCM
    view.setUint16(22, 1, Endian.little); // mono
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    view.setUint16(32, 2, Endian.little); // block align
    view.setUint16(34, 16, Endian.little); // bits per sample
    str(36, 'data');
    view.setUint32(40, data, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      // Math.round: halves go up, as in JavaScript.
      view.setInt16(44 + i * 2, (samples[i] * 32767 + 0.5).floor(), Endian.little);
    }
    return bytes;
  }

  // -------------------------------------------------------------- which rows are a message arriving

  static const _agentMessages = {'agent-message', 'agent-message-rich', 'agent-message-file', 'agent-message-audio'};

  /// A row that is a message arriving: a bot step's bubble (web displayStep
  /// plays as each step is drawn) or a person's / the AI agent's message
  /// (web agentListeners). Not the visitor's own, not join / leave lines,
  /// not the frozen copy of choice buttons. [item] is a record row's JSON.
  static bool isArrivingMessage(dynamic item) {
    if (item is! Map) return false;
    final type = item['type'];
    return (type == 'bot-message' && item['shape'] != 'bot-choice-buttons') || _agentMessages.contains(type);
  }

  /// More new rows than this at once is a conversation put on screen whole
  /// (restored, the server's history), not news.
  static const bulkRows = 3;

  static String _rowId(dynamic item) => item is Map ? '${item['_id'] ?? item['id'] ?? ''}' : '';

  /// Whether the rows added since [prevIds] include an arriving message (and
  /// are not a bulk restore).
  static bool messageArrived(Set<String> prevIds, List<dynamic> next) {
    final added = next.where((item) => !prevIds.contains(_rowId(item))).toList();
    return added.isNotEmpty && added.length <= bulkRows && added.any(isArrivingMessage);
  }

  /// The ids of a conversation's rows, for the next [messageArrived].
  static Set<String> rowIds(List<dynamic> rows) => {for (final r in rows) _rowId(r)};
}

/// The gaps between sounds, per moment: a message sound at most every
/// [MessageSounds.minGapMs] (a pack's message too), each pack moment its own
/// gap. The launcher file has no gap (the web plays it on every toggle).
class SoundGate {
  final Map<SoundEvent, int> _last = {};

  /// True (and noted) when [event] may play at [nowMs].
  bool allow(dynamic c, SoundEvent event, int nowMs) {
    final pack = MessageSounds.soundPackOn(c);
    if (!pack && event != SoundEvent.message) return true;
    final gap = pack ? MessageSounds.packGapMs[event]! : MessageSounds.minGapMs;
    final last = _last[event];
    if (last != null && nowMs - last < gap) return false;
    _last[event] = nowMs;
    return true;
  }
}
