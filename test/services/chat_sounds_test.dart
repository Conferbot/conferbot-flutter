// The chat's sounds on the phone (lib/src/services/chat_sounds.dart) and in
// the provider: a message arriving, opening and closing, the pack's send,
// Sound off kept on the device, a restored conversation not news (RN
// __tests__/context/useChatSounds and ChatWidget's menu, web
// ts/chat/messageSound.ts and index.ts _playToggleSound).
import 'dart:io';

import 'package:conferbot_flutter/src/core/customization/message_sound.dart';
import 'package:conferbot_flutter/src/providers/conferbot_provider.dart';
import 'package:conferbot_flutter/src/services/chat_sounds.dart';
import 'package:conferbot_flutter/src/services/storage_service.dart';
import 'package:conferbot_flutter/src/widgets/chat_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePlayer implements SoundPlayer {
  final played = <String>[];
  @override
  Future<bool> play(SoundCue cue) async {
    played.add(cue is ToneCue ? cue.key : (cue as UrlCue).url);
    return true;
  }
}

class MemoryStore implements SoundSwitchStore {
  MemoryStore([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async => value = v;
}

class _TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TempPaths(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

void main() {
  group('ChatSounds', () {
    test('plays the owner\'s sound for each moment, within its gap', () {
      var now = 1000;
      final player = FakePlayer();
      final s = ChatSounds(customizations: () => {'messageSound': 'pop'}, player: player, store: MemoryStore(), now: () => now);
      expect(s.hasSounds, isTrue);
      expect(s.rowAdded({'_id': 'a', 'type': 'bot-message'}), isTrue);
      now += 100;
      expect(s.rowAdded({'_id': 'b', 'type': 'bot-message'}), isFalse); // within 800 ms
      now += 800;
      expect(s.rowAdded({'_id': 'c', 'type': 'user-message'}), isFalse); // the visitor's own
      expect(s.rowAdded({'_id': 'd', 'type': 'agent-message'}), isTrue);
      expect(s.play(SoundEvent.send), isFalse); // send only in a pack
      expect(s.play(SoundEvent.open), isFalse); // no launcher sound
      expect(player.played, ['message.pop', 'message.pop']);
    });

    test('a pack plays open, message, send and close', () {
      var now = 0;
      final player = FakePlayer();
      final s = ChatSounds(customizations: () => {'soundPack': 'retro', 'messageSound': 'pop'}, player: player, store: MemoryStore(), now: () => now);
      for (final e in SoundEvent.values) {
        expect(s.play(e), isTrue);
        now += 1000;
      }
      expect(player.played, ['retro.open', 'retro.message', 'retro.send', 'retro.close']);
    });

    test('the launcher file on open and close', () {
      final player = FakePlayer();
      const url = 'https://cdn.conferbot.com/sounds/sound-2.mp3';
      final s = ChatSounds(
        customizations: () => {'enableWidgetToggleSound': true, 'widgetToggleSound': url},
        player: player,
        store: MemoryStore(),
      );
      expect(s.play(SoundEvent.open), isTrue);
      expect(s.play(SoundEvent.close), isTrue);
      expect(player.played, [url, url]);
    });

    test('Sound off is kept on the device and silences everything', () async {
      final player = FakePlayer();
      final store = MemoryStore();
      final s = ChatSounds(customizations: () => {'soundPack': 'soft'}, player: player, store: store);
      await s.load();
      expect(s.soundOn, isTrue);
      s.toggle();
      expect(s.soundOn, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(store.value, 'false');
      expect(s.play(SoundEvent.open), isFalse);
      expect(player.played, isEmpty);
      // The next launch reads it back.
      final again = ChatSounds(customizations: () => {'soundPack': 'soft'}, player: player, store: store);
      await again.load();
      expect(again.soundOn, isFalse);
      again.toggle();
      expect(store.value, 'true');
    });

    test('no sound set: nothing to offer, nothing played', () {
      final player = FakePlayer();
      final s = ChatSounds(customizations: () => null, player: player, store: MemoryStore());
      expect(s.hasSounds, isFalse);
      for (final e in SoundEvent.values) {
        expect(s.play(e), isFalse);
      }
      expect(player.played, isEmpty);
    });
  });

  group('in the chat', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      PathProviderPlatform.instance = _TempPaths(Directory.systemTemp.createTempSync('cb_sounds_').path);
      await StorageService.init();
    });

    Map<String, dynamic> payload(Map<String, dynamic> c) => {
          'chatbotData': {
            'elements': [
              {
                'nodes': [
                  {'id': 'w', 'type': 'welcome-node', 'data': {'text': 'Hi there'}},
                  {'id': 'm', 'type': 'message-node', 'data': {'text': 'How can we help?'}},
                ],
                'edges': [
                  {'id': 'e1', 'source': 'w', 'target': 'm'},
                ],
              },
            ],
            'customizations': c,
          },
        };

    testWidgets('opening and closing; the menu offers Sound on / off, kept off', (tester) async {
      final player = FakePlayer();
      final store = MemoryStore();
      final p = ConferBotProvider(apiKey: 'k', botId: 'sound-bot', config: const ConferBotConfig(autoConnect: false, enablePersistence: false));
      p.sounds.debugUse(player: player, store: store);
      p.debugHandleChatbotData(payload({'soundPack': 'bubbly'}));
      // Real time: the chat's start-up waits on the network and the socket.
      await tester.runAsync(() async {
        await p.openChat();
        await Future<void>.delayed(const Duration(seconds: 3));
      });
      // The provider's listeners live in the test's zone.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(player.played.first, 'bubbly.open');
      p.closeChat();
      expect(player.played.last, 'bubbly.close');

      // The header's menu: "Sound On", then "Sound Off" once tapped.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: p,
            builder: (_, __) => ChatHeaderWithKB(title: 'Bot', onToggleSound: p.toggleSound, soundOn: p.sounds.soundOn),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('cb-chat-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Sound On'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cb-menu-sound')));
      await tester.pumpAndSettle();
      expect(p.sounds.soundOn, isFalse);
      expect(store.value, 'false');
      await tester.tap(find.byKey(const ValueKey('cb-chat-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Sound Off'), findsOneWidget);
      final before = player.played.length;
      p.closeChat();
      await tester.runAsync(() => p.openChat());
      expect(player.played.length, before);
      p.dispose();
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(minutes: 1));
      }
      while (tester.takeException() != null) {}
    });
  });
}
