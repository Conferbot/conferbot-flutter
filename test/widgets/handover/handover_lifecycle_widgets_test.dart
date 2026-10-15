// The handover lifecycle on screen: the Connecting line with its dots and
// how it settles (#27), the note after an AI handover, the header's status
// line (#28), Leave queue on the wait card (#37), and "Talk to a person"
// only while nobody is coming or here (#26).
import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/core/customization/customizations.dart';
import 'package:conferbot_flutter/src/core/live_chat/handover_state.dart';
import 'package:conferbot_flutter/src/widgets/live_chat_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

SystemMessageRecord line({bool handover = true, String? settled, String? note, String kind = 'agent-left-chat', String? text}) {
  final o = HandoverRecord.outcomeOf(settled);
  return SystemMessageRecord(
    id: 'l1',
    time: DateTime(2026),
    text: text ?? HandoverRecord.lineText(o),
    kind: kind,
    handover: handover,
    settled: settled,
    note: note,
  );
}

ConferBotProvider agentBotProvider({bool talkToHuman = true}) {
  final provider = ConferBotProvider(apiKey: 'k', botId: 'b1', config: const ConferBotConfig(autoConnect: false, enablePersistence: false));
  provider.debugHandleChatbotData({
    'chatbotData': {
      'workspaceId': 'w1',
      'agentBot': {'agentId': 'a1', 'displayName': 'Ava'},
      'customizations': {'chatTalkToHuman': talkToHuman, 'botName': 'Help'},
    },
  });
  return provider;
}

void main() {
  setUp(() => ChatState.instance.reset());

  group('the Connecting line', () {
    testWidgets('pending: the words and the dots', (tester) async {
      await tester.pumpWidget(host(MessageBubble(message: line())));
      expect(find.text('Connecting you with the team…'), findsOneWidget);
      expect(find.byKey(const ValueKey('cb-handover-dots')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('cb-handover-dots')), findsOneWidget);
    });

    testWidgets('settled: each outcome in words, the dots stop', (tester) async {
      for (final o in HandoverOutcome.values) {
        await tester.pumpWidget(host(MessageBubble(message: line(settled: o.name))));
        expect(find.text(HandoverRecord.lineText(o)), findsOneWidget);
        expect(find.byKey(const ValueKey('cb-handover-dots')), findsNothing);
      }
    });

    testWidgets("a person's join after an AI handover keeps its note", (tester) async {
      await tester.pumpWidget(host(MessageBubble(
        message: line(handover: false, kind: 'agent-joined-message', text: 'Sam joined the chat', note: HandoverRecord.handedOverNote),
      )));
      expect(find.text('Sam joined the chat'), findsOneWidget);
      expect(find.text('They can see your conversation so far'), findsOneWidget);
      expect(find.byKey(const ValueKey('cb-handover-dots')), findsNothing);
    });

    test('kept with its marks on the device (a restart draws it the same)', () {
      final saved = line(settled: 'joined', note: 'n').toJson();
      final back = RecordItem.fromJson(saved) as SystemMessageRecord;
      expect([back.kind, back.handover, back.settled, back.note, back.handoverPending], ['agent-left-chat', true, 'joined', 'n', false]);
      expect((RecordItem.fromJson(SystemMessageRecord(id: 'x', time: DateTime(2026), text: 'Hi').toJson()) as SystemMessageRecord).kind, isNull);
    });
  });

  group('the header keeps the bot', () {
    testWidgets('its name with the reply time, never the agent', (tester) async {
      const look = ResolvedCustomizations(title: 'Help', hideLogo: true);
      await tester.pumpWidget(host(const ChatHeaderWithKB(title: 'Help', look: look, statusText: 'Typically replies in a few minutes')));
      expect(find.text('Help'), findsOneWidget);
      expect(find.text('Typically replies in a few minutes'), findsOneWidget);
      expect(find.text('Live Agent'), findsNothing);
    });

    testWidgets('no status line when the owner turned it off', (tester) async {
      const look = ResolvedCustomizations(title: 'Help', hideLogo: true);
      await tester.pumpWidget(host(const ChatHeaderWithKB(title: 'Help', look: look, statusText: null)));
      expect(find.text('Online'), findsNothing);
    });

    test("the provider's status: the reply time, then Online once a person is in", () {
      final provider = ConferBotProvider(apiKey: 'k', botId: 'b1', config: const ConferBotConfig(autoConnect: false, enablePersistence: false));
      provider.debugHandleChatbotData({
        'chatbotData': {
          'customizations': {
            'replyTime': {'mode': 'auto', 'handover': true, 'state': 'online', 'bucket': 'few_minutes'},
          },
        },
      });
      expect(provider.headerStatus, 'Typically replies in a few minutes');
      ChatState.instance.pushToRecord(RecordEntry(id: 'j1', shape: 'agent-joined-message', type: 'agent-joined-message', data: {'agentId': 'u1'}));
      expect(provider.personInChat, isTrue);
      expect(provider.headerStatus, 'Online');
      provider.dispose();
    });
  });

  testWidgets('the wait card offers Leave queue', (tester) async {
    final provider = ConferBotProvider(apiKey: 'k', botId: 'b1', config: const ConferBotConfig(autoConnect: false, enablePersistence: false));
    var left = 0;
    await tester.pumpWidget(host(HandoverWaitCard(liveChat: provider.liveChat, theme: defaultTheme, onLeave: () => left++)));
    await tester.tap(find.byKey(const ValueKey('cb-leave-queue')));
    expect(left, 1);
    await tester.pumpWidget(host(HandoverWaitCard(liveChat: provider.liveChat, theme: defaultTheme)));
    expect(find.text('Leave queue'), findsNothing);
  });

  group('Talk to a person (web quickActions.ts)', () {
    test('offered on an agent bot whose owner turned it on, while nobody is coming or here', () {
      final provider = agentBotProvider();
      expect(provider.offerTalkToPerson, isTrue);
      // An AI handing the visitor on: connecting.
      final pending = RecordEntry(id: 'l1', shape: 'agent-left-chat', type: 'agent-left-chat', data: {'handover': true});
      ChatState.instance.pushToRecord(pending);
      expect(provider.talkToPersonAllowed, isFalse);
      expect(provider.offerTalkToPerson, isFalse);
      provider.dispose();
      expect(agentBotProvider(talkToHuman: false).offerTalkToPerson, isFalse);
    });

    test('gone once tapped, and not back', () async {
      final provider = agentBotProvider();
      await provider.talkToPerson();
      expect(provider.offerTalkToPerson, isFalse);
      provider.dispose();
    });
  });
}
