/// The chat's sounds on the phone (core/customization/message_sound.dart;
/// web ts/chat/messageSound.ts and index.ts _playToggleSound): a message
/// arriving, the chat opening and closing, the visitor sending, under the
/// owner's messageSound, soundPack and launcher sound, and the visitor's
/// Sound on / off kept on the device under the web's key. Ported from the
/// React Native SDK (context/hooks/useChatSounds.ts, utils/chatSounds.ts).
///
/// The tones the web synthesises with Web Audio are rendered once per sound
/// into a small WAV (MessageSounds.renderWav) and played with audioplayers,
/// the package the SDK's voice messages already use: from the bytes on
/// Android, from a file in the app's temporary folder on iOS and macOS
/// (audioplayers has no bytes source there). The owner's launcher sound is
/// played from its URL.
///
/// Silent and mute: the sounds are short interface sounds, so they follow
/// the phone's own rules. On Android they play as sonification
/// (USAGE_ASSISTANCE_SONIFICATION) without taking the audio focus, so music
/// keeps playing and the ringer / Do Not Disturb policy applies; on iOS in
/// the ambient category, which the silent switch mutes and which mixes with
/// other audio. iOS has one audio session for the app, so the category goes
/// back to audioplayers' default (playback) once the sound is done.
library;

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/customization/message_sound.dart';

/// Plays one cue; never throws, resolves false when nothing could play.
abstract class SoundPlayer {
  Future<bool> play(SoundCue cue);
}

/// Where the visitor's Sound on / off is kept.
abstract class SoundSwitchStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesSoundSwitch implements SoundSwitchStore {
  const SharedPreferencesSoundSwitch();

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(MessageSounds.soundEnabledKey);

  @override
  Future<void> write(String value) async => (await SharedPreferences.getInstance()).setString(MessageSounds.soundEnabledKey, value);
}

/// [SoundPlayer] with audioplayers.
class AudioplayersSoundPlayer implements SoundPlayer {
  AudioplayersSoundPlayer();

  final Map<String, Uint8List> _wavs = {};
  final Map<String, Future<String?>> _files = {};
  int _playing = 0;

  /// Interface sounds, by the phone's rules (see the library comment).
  static const AudioContext soundContext = AudioContext(
    android: AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  static bool get _apple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  Uint8List _wav(ToneCue cue) => _wavs.putIfAbsent(cue.key, () => MessageSounds.renderWav(cue.steps));

  /// The tone written once to the temporary folder (iOS and macOS).
  Future<String?> _file(ToneCue cue) => _files.putIfAbsent(cue.key, () async {
        try {
          final dir = await getTemporaryDirectory();
          final f = File('${dir.path}/conferbot-sound-${cue.key.replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '_')}.wav');
          await f.writeAsBytes(_wav(cue), flush: true);
          return f.path;
        } catch (_) {
          _files.remove(cue.key);
          return null;
        }
      });

  @override
  Future<bool> play(SoundCue cue) async {
    AudioPlayer? player;
    try {
      final Source source;
      if (cue is UrlCue) {
        source = UrlSource(cue.url);
      } else {
        final tone = cue as ToneCue;
        if (_apple) {
          final path = await _file(tone);
          if (path == null) return false;
          source = DeviceFileSource(path);
        } else {
          source = BytesSource(_wav(tone));
        }
      }
      player = AudioPlayer();
      final p = player;
      _playing++;
      var done = false;
      void finish() {
        if (done) return;
        done = true;
        _playing--;
        unawaited(p.dispose().catchError((_) {}));
        // The app's one audio session back to audioplayers' default.
        if (_apple && _playing == 0) {
          unawaited(AudioPlayer.global.setAudioContext(const AudioContext()).catchError((_) {}));
        }
      }

      p.onPlayerComplete.first.then((_) => finish(), onError: (_) => finish());
      // A sound is never longer than a few seconds; let go of the player anyway.
      Timer(const Duration(seconds: 8), finish);
      await p.play(source, ctx: soundContext, volume: 1.0);
      return true;
    } catch (_) {
      unawaited(player?.dispose().catchError((_) {}));
      return false;
    }
  }
}

/// The chat's sounds for one chat (owned by the provider).
class ChatSounds extends ChangeNotifier {
  ChatSounds({
    required dynamic Function() customizations,
    SoundPlayer? player,
    SoundSwitchStore? store,
    int Function()? now,
  })  : _customizations = customizations,
        _player = player,
        _store = store ?? const SharedPreferencesSoundSwitch(),
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final dynamic Function() _customizations;
  SoundPlayer? _player;
  SoundSwitchStore _store;
  final int Function() _now;
  final SoundGate _gate = SoundGate();

  SoundPlayer get _audio => _player ??= AudioplayersSoundPlayer();

  /// A player and a store of a test's own.
  @visibleForTesting
  void debugUse({SoundPlayer? player, SoundSwitchStore? store}) {
    if (player != null) _player = player;
    if (store != null) {
      _store = store;
      _loaded = false;
    }
  }

  bool _soundOn = true;

  /// The visitor's switch (chat menu): sounds on unless they turned them off.
  bool get soundOn => _soundOn;

  /// The chat menu offers Sound on / off only when the bot has a sound.
  bool get hasSounds => MessageSounds.hasAnySound(_customizations());

  bool _loaded = false;

  /// The visitor's switch, as they left it (blocked storage reads as on).
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final stored = await _store.read();
      final on = MessageSounds.soundEnabledFrom(stored);
      if (on != _soundOn) {
        _soundOn = on;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Sound on / off from the chat menu, kept on the device.
  void toggle() {
    _soundOn = !_soundOn;
    notifyListeners();
    unawaited(_store.write('$_soundOn').catchError((_) {}));
  }

  /// Plays [event]'s sound when the owner set one, the visitor has sounds on
  /// and its gap allows; true when a sound was started.
  bool play(SoundEvent event) {
    if (!_soundOn) return false;
    final c = _customizations();
    final cue = MessageSounds.cueFor(c, event);
    if (cue == null || !_gate.allow(c, event, _now())) return false;
    unawaited(_audio.play(cue).catchError((_) => false));
    return true;
  }

  /// A row was added to the conversation: a message arriving plays the
  /// message sound (the bot's step, a person's or the AI's message).
  bool rowAdded(Map<String, dynamic> row) => MessageSounds.isArrivingMessage(row) && play(SoundEvent.message);
}
