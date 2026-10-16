// The chat's sounds (lib/src/core/customization/message_sound.dart): the
// React Native SDK's __tests__/core/messageSound.test.ts ported (web
// ts/chat/messageSound.ts, index.ts _playToggleSound), and every tone
// rendered byte for byte as RN's renderWav (test/fixtures/message_sounds.json,
// rebuilt by tool/message_sound_fixture.sh).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:conferbot_flutter/src/core/customization/message_sound.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const events = SoundEvent.values;
  final packs = MessageSounds.soundPacks.where((p) => p != 'off');

  test("has the web's three message sounds, off by default", () {
    expect(MessageSounds.soundRecipe('off'), isEmpty);
    expect(MessageSounds.soundRecipe(null), isEmpty);
    expect(MessageSounds.soundRecipe('ding'), isEmpty);
    expect(MessageSounds.soundRecipe('pop'), [const ToneStep(at: 0, from: 520, to: 880, dur: 0.09, type: Wave.sine, gain: 0.18)]);
    expect(MessageSounds.soundRecipe('chime').map((s) => s.from), [880, 1318.5]);
    expect(MessageSounds.soundRecipe('bubble').map((s) => [s.from, s.to]), [
      [380, 760],
      [520, 1040],
    ]);
    expect(MessageSounds.normalizeMessageSound('chime'), 'chime');
    expect(MessageSounds.normalizeMessageSound('loud'), 'off');
  });

  test('has five packs with all four moments, quiet and short', () {
    expect(MessageSounds.soundPacks, ['off', 'soft', 'playful', 'retro', 'bubbly', 'premium']);
    expect(MessageSounds.normalizeSoundPack('nope'), 'off');
    for (final pack in packs) {
      for (final ev in events) {
        final steps = MessageSounds.packRecipe(pack, ev);
        expect(steps, isNotEmpty);
        for (final s in steps) {
          expect(s.gain, lessThanOrEqualTo(0.2));
        }
        expect(MessageSounds.toneLength(steps), lessThan(0.5));
      }
    }
    expect(MessageSounds.packRecipe('retro', SoundEvent.send), [const ToneStep(at: 0, from: 660, to: 660, dur: 0.04, type: Wave.square, gain: 0.04)]);
    expect(MessageSounds.packRecipe('playful', SoundEvent.open).map((s) => s.at), [0, 0.065, 0.13]);
    expect(MessageSounds.packRecipe('off', SoundEvent.open), isEmpty);
  });

  test('plays the launcher file for open and close, unless a pack plays them', () {
    const url = 'https://cdn.conferbot.com/sounds/sound-1.mp3';
    final c = {'enableWidgetToggleSound': true, 'checkedSoundTab': 'choose', 'widgetToggleSound': url};
    expect(MessageSounds.toggleSoundUrl(c), url);
    expect(MessageSounds.toggleSoundUrl({...c, 'checkedSoundTab': null}), url);
    expect(MessageSounds.toggleSoundUrl({...c, 'checkedSoundTab': 'upload', 'customWidgetSoundUrl': 'https://x.test/a.wav'}), 'https://x.test/a.wav');
    expect(MessageSounds.toggleSoundUrl({...c, 'enableWidgetToggleSound': false}), '');
    expect(MessageSounds.toggleSoundUrl({...c, 'soundPack': 'soft'}), '');
    expect(MessageSounds.toggleSoundUrl({...c, 'widgetToggleSound': 'javascript:alert(1)'}), '');
    expect((MessageSounds.cueFor(c, SoundEvent.open) as UrlCue).url, url);
    expect((MessageSounds.cueFor(c, SoundEvent.close) as UrlCue).url, url);
    expect(MessageSounds.cueFor(c, SoundEvent.send), isNull);
    expect(MessageSounds.cueFor(c, SoundEvent.message), isNull);
  });

  test('picks the pack over the single message sound', () {
    expect((MessageSounds.cueFor({'messageSound': 'pop'}, SoundEvent.message) as ToneCue).key, 'message.pop');
    expect((MessageSounds.cueFor({'messageSound': 'pop', 'soundPack': 'retro'}, SoundEvent.message) as ToneCue).key, 'retro.message');
    expect((MessageSounds.cueFor({'soundPack': 'retro'}, SoundEvent.send) as ToneCue).key, 'retro.send');
    expect(MessageSounds.cueFor(<String, dynamic>{}, SoundEvent.message), isNull);
    expect(MessageSounds.cueFor(null, SoundEvent.message), isNull);
    expect(MessageSounds.hasAnySound(<String, dynamic>{}), isFalse);
    expect(MessageSounds.hasAnySound({'messageSound': 'chime'}), isTrue);
    expect(MessageSounds.hasAnySound({'soundPack': 'soft'}), isTrue);
  });

  test("keeps the web's gaps: a message at most every 800 ms, each pack moment its own", () {
    final gate = SoundGate();
    const c = {'messageSound': 'pop'};
    expect(gate.allow(c, SoundEvent.message, 1000), isTrue);
    expect(gate.allow(c, SoundEvent.message, 1000 + MessageSounds.minGapMs - 1), isFalse);
    expect(gate.allow(c, SoundEvent.message, 1000 + MessageSounds.minGapMs), isTrue);
    // The launcher file plays on every toggle.
    expect(gate.allow(c, SoundEvent.open, 1000), isTrue);
    expect(gate.allow(c, SoundEvent.open, 1001), isTrue);
    const p = {'soundPack': 'soft'};
    final g2 = SoundGate();
    expect(g2.allow(p, SoundEvent.send, 0), isTrue);
    expect(g2.allow(p, SoundEvent.send, MessageSounds.packGapMs[SoundEvent.send]! - 1), isFalse);
    expect(g2.allow(p, SoundEvent.open, 10), isTrue);
    expect(g2.allow(p, SoundEvent.send, MessageSounds.packGapMs[SoundEvent.send]!), isTrue);
  });

  test('reads the visitor\'s switch as the web does: only "false" is off', () {
    expect(MessageSounds.soundEnabledFrom('false'), isFalse);
    expect(MessageSounds.soundEnabledFrom('true'), isTrue);
    expect(MessageSounds.soundEnabledFrom(null), isTrue);
  });

  test('renders a tone as Web Audio does: exponential glides, a 12 ms attack, a quiet tail', () {
    final pop = MessageSounds.soundRecipe('pop').first;
    expect(MessageSounds.stepFrequency(pop, 0), closeTo(520, 1e-6));
    expect(MessageSounds.stepFrequency(pop, pop.dur), closeTo(880, 1e-6));
    expect(MessageSounds.stepFrequency(pop, pop.dur / 2), closeTo(math.sqrt(520 * 880), 1e-6));
    expect(MessageSounds.stepGain(pop, 0), closeTo(0.0001, 1e-7));
    expect(MessageSounds.stepGain(pop, 0.012), closeTo(0.18, 1e-6));
    expect(MessageSounds.stepGain(pop, pop.dur), closeTo(0.0001, 1e-7));
    expect(MessageSounds.stepGain(pop, pop.dur + 0.05), 0);
    final samples = MessageSounds.renderSamples(MessageSounds.soundRecipe('pop'), 8000);
    expect(samples.length, (MessageSounds.toneLength(MessageSounds.soundRecipe('pop')) * 8000).ceil());
    final peak = samples.map((s) => s.abs()).reduce(math.max);
    expect(peak, greaterThan(0.1));
    expect(peak, lessThanOrEqualTo(0.18 + 1e-6));
  });

  test('writes a valid 16-bit mono WAV, about 20 KB for the longest sound', () {
    final wav = MessageSounds.renderWav(MessageSounds.packRecipe('premium', SoundEvent.open));
    String text(int o, int n) => String.fromCharCodes(wav.sublist(o, o + n));
    final view = ByteData.view(wav.buffer);
    expect(text(0, 4), 'RIFF');
    expect(text(8, 4), 'WAVE');
    expect(view.getUint16(22, Endian.little), 1);
    expect(view.getUint32(24, Endian.little), 22050);
    expect(view.getUint16(34, Endian.little), 16);
    expect(view.getUint32(40, Endian.little), wav.length - 44);
    expect(wav.length, lessThan(25000));
  });

  test("renders every tone byte for byte as RN's renderWav", () {
    final fixture = jsonDecode(File('test/fixtures/message_sounds.json').readAsStringSync()) as Map<String, dynamic>;
    final sounds = fixture['sounds'] as Map<String, dynamic>;
    final ours = <String, List<ToneStep>>{
      for (final k in ['pop', 'chime', 'bubble']) 'message.$k': MessageSounds.soundRecipe(k),
      for (final p in packs)
        for (final ev in events) '$p.${ev.name}': MessageSounds.packRecipe(p, ev),
    };
    expect(ours.keys.toSet(), sounds.keys.toSet());
    for (final e in ours.entries) {
      final wav = MessageSounds.renderWav(e.value);
      final want = sounds[e.key] as Map<String, dynamic>;
      expect(wav.length, want['bytes'], reason: e.key);
      expect(sha256.convert(wav).toString(), want['sha256'], reason: e.key);
    }
  });

  test("hears a message arriving, not the visitor's own nor a restored conversation", () {
    expect(MessageSounds.isArrivingMessage({'type': 'bot-message', 'shape': 'bot-text-message'}), isTrue);
    expect(MessageSounds.isArrivingMessage({'type': 'bot-message', 'shape': 'bot-choice-buttons'}), isFalse);
    expect(MessageSounds.isArrivingMessage({'type': 'agent-message'}), isTrue);
    expect(MessageSounds.isArrivingMessage({'type': 'agent-joined-message'}), isFalse);
    expect(MessageSounds.isArrivingMessage({'type': 'user-message'}), isFalse);
    final before = [
      {'_id': 'a', 'type': 'bot-message'},
    ];
    expect(MessageSounds.messageArrived(MessageSounds.rowIds(before), [...before, {'_id': 'b', 'type': 'bot-message'}]), isTrue);
    expect(MessageSounds.messageArrived(MessageSounds.rowIds(before), [...before, {'_id': 'u', 'type': 'user-message'}]), isFalse);
    final restored = [for (var i = 0; i <= MessageSounds.bulkRows; i++) {'_id': 'r$i', 'type': 'bot-message'}];
    expect(MessageSounds.messageArrived(<String>{}, restored), isFalse);
    expect(MessageSounds.messageArrived(<String>{}, [{'_id': 'w', 'type': 'bot-message'}]), isTrue);
  });
}
