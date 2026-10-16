/// The German sweep of the screens (RN __tests__/components/i18nSweep.test.tsx,
/// its component part; the flow steps are in test/parity/i18n_flow_sweep_test.dart):
/// with the widget language set to "de", each screen the SDK draws is
/// pumped and every string it draws (texts, hints, tooltips, semantics) is
/// collected. None may be an English table value the German table words
/// differently. The owner content given here is German or neutral; what
/// the owner wrote is taken out before the check.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conferbot_flutter/conferbot_flutter.dart';
import 'package:conferbot_flutter/src/core/agent/agent_bot.dart';
import 'package:conferbot_flutter/src/core/home/home.dart';
import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
import 'package:conferbot_flutter/src/core/live_chat/handover_state.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_chat.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_events.dart';
import 'package:conferbot_flutter/src/core/waiting/games_card.dart';
import 'package:conferbot_flutter/src/core/customization/greeting.dart';
import 'package:conferbot_flutter/src/widgets/agent_reply.dart';
import 'package:conferbot_flutter/src/widgets/greeting_card.dart';
import 'package:conferbot_flutter/src/widgets/greeting_controller.dart';
import 'package:conferbot_flutter/src/widgets/handover/agent_info.dart';
import 'package:conferbot_flutter/src/widgets/handover/human_handover_overlay.dart';
import 'package:conferbot_flutter/src/widgets/handover/post_chat_survey.dart';
import 'package:conferbot_flutter/src/widgets/handover/pre_chat_form.dart';
import 'package:conferbot_flutter/src/widgets/handover/queue_status.dart';
import 'package:conferbot_flutter/src/widgets/launcher_fx_views.dart';
import 'package:conferbot_flutter/src/widgets/live_chat_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/requests/requests_portal_test.dart' show FakeApi, detail, summary, now;
import '../i18n_sweep.dart';

// ---------------------------------------------------------------- harness

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

/// The names and addresses used below: the owner's, not the SDK's.
const _ownerNames = ['you@example.com', 'Acme', 'Sam', 'Ada', 'Ava', 'Jamie', 'Pip', 'KI', 'sam@example.com', 'ada@example.com', 'jo@example.com'];

/// What Flutter itself draws (the menu's barrier): the app's own
/// localizations word it, not the widget's language.
final _framework = [
  const DefaultMaterialLocalizations().menuDismissLabel,
  const DefaultMaterialLocalizations().modalBarrierDismissLabel,
  const DefaultMaterialLocalizations().popupMenuLabel,
];

/// English words the SDK must not draw in German (RN's ENGLISH_WORDS; none
/// of them is German, checked below): they catch English the table lacks.
final _englishWords = RegExp(
  r'\b(the|your|please|tap|send|message|try again|loading|search|close|cancel|submit|typing|helpful|you|with|this|here|choose|select|click|upload|thanks|retry|error|failed|connecting|waiting|ago|today|yesterday|seconds?|and|or|not|now|done|skip|next|back|open|read|sent|delivered|seen)\b',
  caseSensitive: false,
);

/// Every string on screen that is English, the owner's own strings taken out:
/// an English table value (test/i18n_sweep.dart), or a tell-tale English word.
List<String> _english(WidgetTester tester, [List<String> owner = const []]) {
  final own = ownerStrings([_ownerNames, _framework, owner]);
  final drawn = drawnStrings(tester);
  final bad = englishIn(drawn, own);
  for (final s in drawn) {
    var rest = s;
    for (final o in own) {
      rest = rest.split(o).join(' ');
    }
    if (_englishWords.hasMatch(rest)) bad.add('"$s"');
  }
  return bad.toSet().toList();
}

/// The chat's own start-up (no network in tests) reports errors that have
/// nothing to do with the words; they are dropped here.
void _drain(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

Widget _host(Widget child, {ConferBotProvider? provider}) {
  final page = MediaQuery(
    data: const MediaQueryData(size: Size(390, 1600), disableAnimations: true),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  );
  return MaterialApp(home: provider == null ? page : ChangeNotifierProvider<ConferBotProvider>.value(value: provider, child: page));
}

ConferBotProvider _provider([Map<String, dynamic> customizations = const {}, Map<String, dynamic> extra = const {}]) {
  final p = ConferBotProvider(
    apiKey: 'k',
    botId: 'sweep-bot',
    config: const ConferBotConfig(autoConnect: false, enablePersistence: false, widgetLanguage: 'de'),
  );
  p.debugHandleChatbotData({
    'chatbotData': {
      'workspaceId': 'w1',
      'elements': [
        {'nodes': [], 'edges': []},
      ],
      'customizations': {'logoText': 'Acme', ...customizations},
      ...extra,
    },
  });
  return p;
}

/// A provider stand-in for the widgets that read a few of its fields.
class _FakeProvider extends ChangeNotifier implements ConferBotProvider {
  _FakeProvider({this.connected = true, this.shown = const [], this.custom});
  final bool connected;
  final List<RecordItem> shown;
  final Map<String, dynamic>? custom;

  @override
  bool get isConnected => connected;
  @override
  List<RecordItem> get record => shown;
  @override
  List<RecordItem> get paginatedMessages => const [];
  @override
  Map<String, dynamic>? get serverCustomizations => custom;
  @override
  bool get offerTalkToPerson => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _aiAgent = AgentDetails.fromJson(const {'_id': 'ai-agent-a1', 'isAIAgent': true, 'name': 'Ava'});

AgentMessageRecord _aiAnswer({Map<String, dynamic> extras = const {}}) => AgentMessageRecord(
      id: '0123456789abcdef01234567',
      time: DateTime(2026, 10, 16, 9, 30),
      text: 'Unsere Tarife beginnen bei 9 €.',
      agentDetails: _aiAgent,
      extras: AgentBotParser.aiReplyExtrasOf({
        'agentDetails': {'_id': 'ai-agent-a1', 'isAIAgent': true},
        ...extras,
      }),
    );

const _agent = Agent(id: 'a1', name: 'Sam', email: 'sam@example.com', title: 'Kundendienst');

// The help centre, as the server sends it (German owner content).
final _kbData = KnowledgeBaseData.fromJson({
  'categories': [
    {
      '_id': 'c1',
      'name': 'Grundlagen',
      'description': 'Anleitungen',
      'articles': [
        {'_id': 'a1', 'title': 'Erste Schritte', 'description': 'So legst du los.', 'readingTime': 3},
        {'_id': 'a2', 'title': 'Rechnungen', 'description': 'Alle Rechnungen an einem Ort.'},
      ],
    },
    {'_id': 'c2', 'name': 'Fragen', 'description': 'Häufige Fragen', 'articles': []},
  ],
  'recentArticles': [
    {'_id': 'a1', 'title': 'Erste Schritte', 'description': 'So legst du los.'},
  ],
});
const _kbOwner = ['Grundlagen', 'Anleitungen', 'Fragen', 'Häufige Fragen', 'Erste Schritte', 'So legst du los.', 'Rechnungen', 'Alle Rechnungen an einem Ort.', 'Inhalt des Artikels.'];

KnowledgeBaseProvider _kbProvider() {
  final client = MockClient((request) async {
    final path = request.url.path;
    if (path.contains('/knowledge-base/articles/')) {
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {'_id': path.split('/').last, 'title': 'Erste Schritte', 'content': '<p>Inhalt des Artikels.</p>', 'description': 'So legst du los.'},
          }),
          200);
    }
    return http.Response('{"success":true,"data":{}}', 200);
  });
  return KnowledgeBaseProvider(
    botId: 'sweep-bot',
    apiKey: 'k',
    initialData: _kbData,
    service: KnowledgeBaseService(apiKey: 'k', botId: 'sweep-bot', client: client),
  );
}

KnowledgeBaseArticle _article() => KnowledgeBaseArticle.fromJson({
      '_id': 'a1',
      'title': 'Erste Schritte',
      'description': 'So legst du los.',
      'content': '<p>Inhalt des Artikels.</p>',
      'category': {'_id': 'c1', 'name': 'Grundlagen'},
      'readingTime': 3,
      'tags': ['start'],
      'createdAt': '2024-01-15T00:00:00Z',
      'updatedAt': '2024-01-15T00:00:00Z',
    });

GamesCard _games() => GamesCard.create(GamesCardOptions(
      customizations: const {'headerBgColor': '#123456'},
      rng: () => 0.9,
      reducedMotion: true,
      setTimer: (fn, _) => 0,
      clearTimer: (_) {},
    ))!;

RequestsPortal _portal() => RequestsPortal(
      api: FakeApi(listAnswer: () => [summary(id: 'old_aaaaaa', lastFrom: 'you', status: 'solved'), summary()], openAnswer: () async => detail()),
      seen: () => {},
      markSeen: (_, __) {},
      isCurrentChat: (_) => false,
      openChat: () {},
      now: () => now,
      rand: () => 0.5,
    );
const _requestsOwner = ['My invoice is wrong', 'Fixed it'];

Widget _requests(RequestsPortal p) => MaterialApp(
      home: Scaffold(body: RequestsPortalView(portal: p, accent: requestsColorOf('#0808EE'), now: () => now, openUrl: (_) async {})),
    );

Widget _home(HomeModel m, {bool hasAgent = false}) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 1600), disableAnimations: true),
        child: HomeScreenView(
          model: m,
          palette: classicHomePalette,
          hasAgent: hasAgent,
          rawArticles: const [],
          onClose: () {},
          onShowChat: ([_]) {},
          onOpenArticle: (_) {},
          onShowHelp: ([_]) {},
          onOpenRequests: ([_]) {},
        ),
      ),
    );

const _homeC = <String, dynamic>{
  'enableInitialPage': true,
  'initialPageTitle': 'Hallo 👋',
  'logoText': 'Acme',
  'enableKnowledgeBase': true,
  'homeRating': {'average': 4.8, 'count': 120},
};
const _homeOwner = ['Hallo 👋', 'Preise?', 'Lieferzeit?', 'Meine Rechnung', 'Erledigt', ..._kbOwner];

HomeModel _homeModel({bool agent = false}) {
  final at = DateTime.now().millisecondsSinceEpoch;
  return homeModel(
    c: _homeC,
    agent: agent ? const HomeAgent(displayName: 'Ava', starters: ['Preise?']) : null,
    categories: [
      {
        '_id': 'c1',
        'name': 'Grundlagen',
        'articles': [
          {'_id': 'a1', 'title': 'Erste Schritte', 'description': 'So legst du los.'},
        ],
      },
    ],
    recentArticles: [
      {'_id': 'a2', 'title': 'Rechnungen', 'description': 'Alle Rechnungen an einem Ort.'},
    ],
    memory: VisitorMemory(at: at - liveChatMs, name: 'Jamie', topic: 'Lieferzeit?', session: 's0'),
    chatSessionId: 's1',
    requests: [
      RequestSummary(
          id: 'mobile_1_abcdef', title: 'Meine Rechnung', status: 'open', lastFrom: 'team', lastAt: DateTime.fromMillisecondsSinceEpoch(at - 3600000).toIso8601String(), lastText: 'Erledigt', teamName: 'Ada'),
    ],
    now: at,
    hour: 9,
  )!;
}

GreetingCardData _greeting(String style) {
  final c = {
    'chatIconCta': true,
    'chatIconCtaText': 'Hallo! Wie können wir helfen?',
    'greetingDelay': 0,
    'logoText': 'Acme',
    'headerBgColor': '#0808EE',
    'widgetIconBgColor': '#0808EE',
    'greetingStyle': style,
  };
  final g = Greeting.decide(c, const GreetingFacts(returning: false, signedIn: false))!;
  final d = GreetingCardData.from(c, g, firstShow: false);
  return GreetingCardData(
    style: d.style, text: d.text, head: d.head, starters: const ['Preise'], bubble: d.bubble, accent: d.accent,
    font: d.font, firstShow: d.firstShow, click: d.click, linkUrl: d.linkUrl,
  );
}

/// One screen to draw: [pump] puts it up (and taps into it), [owner] is what the owner wrote.
class _Row {
  const _Row(this.name, this.pump, [this.owner = const []]);
  final String name;
  final Future<void> Function(WidgetTester tester) pump;
  final List<String> owner;
}

Future<void> _put(WidgetTester tester, Widget w, {ConferBotProvider? provider}) async {
  await tester.pumpWidget(_host(w, provider: provider));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.tap(f.first, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _key(String k) => find.byKey(ValueKey(k));

Widget _helpful({AnswerFeedback? initial, bool canTalk = true}) => HelpfulRow(
      key: UniqueKey(),
      initial: initial,
      theme: defaultTheme,
      onSend: (_) {},
      onAsk: canTalk ? (_) {} : null,
      onRetry: () {},
    );

SystemMessageRecord _line({String? settled, bool handover = true, String? text, String kind = 'agent-left-chat', String? note}) => SystemMessageRecord(
      id: 'l1',
      time: DateTime(2026),
      text: text ?? HandoverRecord.lineText(HandoverRecord.outcomeOf(settled)),
      kind: kind,
      handover: handover,
      settled: settled,
      note: note,
    );

final List<_Row> _rows = [
  // ------------------------------------------------ the chat on the real provider
  _Row('ChatWidget: header, composer, empty state', (tester) async {
    final p = _provider({'enableKnowledgeBase': true, 'chatEmailTranscript': true});
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
        child: ChangeNotifierProvider.value(value: p, child: const ChatWidget()),
      ),
    ));
    await tester.pump();
    _drain(tester);
  }),
  _Row('ChatWidget: the menu opened', (tester) async {
    final p = _provider({'enableKnowledgeBase': true, 'chatEmailTranscript': true, 'enableRequests': true});
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
        child: ChangeNotifierProvider.value(value: p, child: const ChatWidget()),
      ),
    ));
    await tester.pump();
    _drain(tester);
    if (_key('cb-chat-menu').evaluate().isNotEmpty) {
      await tester.tap(_key('cb-chat-menu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    _drain(tester);
  }),
  _Row('ChatInput', (tester) => _put(tester, ChatInput(onSend: (_) {}, enableAttachments: true, onAttachmentPress: () {}))),
  _Row('ChatInput disabled', (tester) => _put(tester, ChatInput(onSend: (_) {}, disabled: true))),
  _Row('ChatBottomBar', (tester) => _put(tester, ChatBottomBar(onSend: (_) {}, enableAttachments: true, onAttachmentPress: () {}, onKnowledgeBaseTap: () {}))),
  _Row('ChatHeader', (tester) => _put(tester, ChatHeader(title: 'Acme', onClose: () {}), provider: _FakeProvider())),
  _Row('ChatHeader offline, with an agent', (tester) => _put(tester, ChatHeader(title: 'Acme', onClose: () {}, agent: _agent), provider: _FakeProvider(connected: false))),
  _Row('EmptyState', (tester) => _put(tester, const EmptyState())),
  // ------------------------------------------------ the messages
  _Row('MessageList: bot, user, agent, edited, deleted, times', (tester) async {
    final at = DateTime.now();
    await tester.pumpWidget(_host(SizedBox(
      height: 1200,
      child: MessageList(
        showTypingIndicator: true,
        showTimestamps: true,
        showAvatars: true,
        hasMoreMessages: true,
        messages: [
          BotMessageRecord(id: 'b0', time: at.subtract(const Duration(days: 3)), text: 'Willkommen'),
          BotMessageRecord(id: 'b1', time: at.subtract(const Duration(days: 1)), text: 'Willkommen'),
          UserMessageRecord(id: 'u1', time: at, text: 'Hallo'),
          AgentMessageRecord(id: 'g1', time: at, text: 'Moin', agentDetails: const AgentDetails(id: 'a1', name: 'Sam', email: 'sam@example.com'), edited: true),
          AgentMessageRecord(id: 'g2', time: at, text: 'weg', agentDetails: const AgentDetails(id: 'a1', name: 'Sam', email: 'sam@example.com'), deleted: true),
          _aiAnswer(),
        ],
      ),
    )));
    await tester.pump(const Duration(milliseconds: 600));
  }, ['Willkommen', 'Hallo', 'Moin', 'Unsere Tarife beginnen bei 9 €.']),
  for (final s in MessageDeliveryStatus.values)
    _Row('MessageBubble user ${s.name}', (tester) => _put(
        tester,
        MessageBubble(
          message: UserMessageRecord(id: 'u1', time: DateTime.now(), text: 'Hallo'),
          showTimestamp: true,
          showDeliveryStatus: true,
          deliveryStatus: s,
          onRetry: () {},
        )), ['Hallo']),
  _Row('MessageBubble agent with avatar and time', (tester) => _put(
      tester,
      MessageBubble(
        message: AgentMessageRecord(id: 'g1', time: DateTime.now().subtract(const Duration(days: 2)), text: 'Moin', agentDetails: const AgentDetails(id: 'a1', name: 'Sam', email: 'sam@example.com')),
        showTimestamp: true,
        showAvatar: true,
      )), ['Moin']),
  for (final style in ['dots', 'wave', 'shimmer', 'pencil', 'mascot'])
    _Row('TypingIndicator $style', (tester) => _put(tester, TypingIndicator(style: style, mascot: style == 'mascot' ? const MascotLook(shape: 'owl', name: 'Pip') : null))),
  _Row('TypingIndicator mascot without a name', (tester) => _put(tester, const TypingIndicator(style: 'mascot'))),
  _Row('OfflineBadge', (tester) => _put(tester, const OfflineBadge(showWhenOnline: true))),
  for (final v in ConnectionStatusVariant.values) ...[
    _Row('ConnectionStatus ${v.name} online', (tester) => _put(tester, ConnectionStatus(variant: v, showWhenOnline: true), provider: _FakeProvider())),
    _Row('ConnectionStatus ${v.name} offline', (tester) => _put(tester, ConnectionStatus(variant: v), provider: _FakeProvider(connected: false))),
  ],
  // ------------------------------------------------ Helpful? and the AI's extras
  _Row('HelpfulRow', (tester) => _put(tester, _helpful())),
  _Row('HelpfulRow No: the reasons', (tester) async {
    await _put(tester, _helpful());
    await _tap(tester, _key('cb-helpful-down'));
  }),
  _Row('HelpfulRow No, a reason: the comment', (tester) async {
    await _put(tester, _helpful());
    await _tap(tester, _key('cb-helpful-down'));
    await _tap(tester, _key('cb-helpful-reason-outdated'));
  }),
  _Row('HelpfulRow comment sent', (tester) async {
    await _put(tester, _helpful());
    await _tap(tester, _key('cb-helpful-down'));
    await _tap(tester, _key('cb-helpful-reason-outdated'));
    await tester.enterText(_key('cb-helpful-comment'), 'zu alt');
    await _tap(tester, _key('cb-helpful-comment-send'));
  }, ['zu alt']),
  _Row('HelpfulRow No, no person to talk to', (tester) async {
    await _put(tester, _helpful(canTalk: false));
    await _tap(tester, _key('cb-helpful-down'));
  }),
  _Row('HelpfulRow Yes: the thanks', (tester) async {
    await _put(tester, _helpful());
    await _tap(tester, _key('cb-helpful-up'));
  }),
  _Row('HelpfulRow rated helpful', (tester) async {
    await _put(tester, _helpful());
    await _tap(tester, _key('cb-helpful-up'));
    await tester.pump(const Duration(milliseconds: 1800));
  }),
  _Row('HelpfulRow restored: not helpful, a reason', (tester) => _put(tester, _helpful(initial: const AnswerFeedback(false, 'wrong')))),
  _Row('AgentReplyExtras: sources, card, result, action, chips', (tester) async {
    final p = _provider({'enableKnowledgeBase': true}, {'knowledgeBaseData': _kbJson});
    p.articleOpener = (_) {};
    await _put(
        tester,
        AgentReplyExtras(
          message: _aiAnswer(extras: {
            'sources': [
              {'title': 'Erste Schritte', 'articleId': 'a1'},
              {'title': 'Preisliste', 'url': 'https://example.com/preise'},
            ],
            'actions': [
              {'label': 'Demo buchen', 'url': 'https://example.com/demo'},
            ],
            'card': {
              'title': 'Tarif Pro',
              'rows': [
                ['Preis', '9 €'],
                ['Laufzeit', '1 Monat'],
              ],
              'note': 'Monatlich',
              'url': 'https://example.com/pro',
            },
            'resultCard': {
              'title': 'Bestellung 42',
              'status': 'Versandt',
              'tone': 'moving',
              'link': {'url': 'https://example.com/b/42'},
            },
            'actionRequest': {
              'token': 'tok',
              'name': 'Termin buchen',
              'summary': [
                {'label': 'Datum', 'value': 'Montag'},
              ],
            },
          }),
          theme: defaultTheme,
        ),
        provider: p);
  }, ['Erste Schritte', 'Preisliste', 'example.com', 'Demo buchen', 'Tarif Pro', 'Preis', '9 €', 'Laufzeit', '1 Monat', 'Monatlich', 'Bestellung 42', 'Versandt', 'Termin buchen', 'Datum', 'Montag']),
  _Row('RichAgentMessage: article, quick replies, card', (tester) async {
    for (final rich in [
      const RichArticle(articleId: 'a1', title: 'Erste Schritte', snippet: 'So legst du los.'),
      const RichQuickReplies(text: 'Was brauchst du?', options: ['Preise', 'Support']),
      const RichCard(title: 'Tarif Pro', description: 'Für Teams', buttonLabel: 'Ansehen', buttonUrl: 'https://example.com'),
    ]) {
      await _put(tester, RichAgentMessage(message: AgentRichMessageRecord(id: 'r1', time: DateTime(2026), rich: rich), theme: defaultTheme, avatar: const SizedBox.shrink()), provider: _provider());
      expect(_english(tester, const ['Erste Schritte', 'So legst du los.', 'Was brauchst du?', 'Preise', 'Support', 'Tarif Pro', 'Für Teams', 'Ansehen']), isEmpty, reason: '$rich');
    }
  }, ['Erste Schritte', 'So legst du los.', 'Was brauchst du?', 'Preise', 'Support', 'Tarif Pro', 'Für Teams', 'Ansehen']),
  // ------------------------------------------------ the handover
  _Row('QueueStatusWidget', (tester) => _put(tester, QueueStatusWidget(maxWaitMinutes: 5, primaryColor: Colors.blue, onCancel: () {}))),
  _Row('QueueStatusWidget with a place in line', (tester) => _put(
      tester,
      QueueStatusWidget(
        maxWaitMinutes: 5,
        primaryColor: Colors.blue,
        onCancel: () {},
        queueInfo: const QueueInfo(position: 3, estimatedWaitSeconds: 180, availableAgentCount: 2),
      ))),
  _Row('QueueStatusWidget nobody available', (tester) => _put(
      tester,
      QueueStatusWidget(maxWaitMinutes: 5, primaryColor: Colors.blue, onCancel: () {}, queueInfo: const QueueInfo(position: 1, estimatedWaitSeconds: 30, agentsAvailable: false)))),
  _Row('QueueStatusWidget connecting', (tester) => _put(
      tester,
      const QueueStatusWidget(maxWaitMinutes: 5, primaryColor: Colors.blue, queueInfo: QueueInfo(position: 1, estimatedWaitSeconds: 0, isConnecting: true)))),
  _Row('PreChatFormWidget', (tester) => _put(
      tester,
      PreChatFormWidget(
        fields: [PreChatFormField.name(), PreChatFormField.email(), PreChatFormField.phone()],
        onSubmit: (_) {},
        primaryColor: Colors.blue,
      ))),
  _Row('PreChatFormWidget sent empty', (tester) async {
    await _put(
        tester,
        PreChatFormWidget(
          fields: [PreChatFormField.name(), PreChatFormField.email(), PreChatFormField.phone(required: true)],
          onSubmit: (_) {},
          primaryColor: Colors.blue,
        ));
    await _tap(tester, find.text(I18n.t('sdk.prechat.start')));
  }),
  _Row('PreChatFormWidget a bad email', (tester) async {
    await _put(tester, PreChatFormWidget(fields: [PreChatFormField.email(), PreChatFormField.phone(required: true)], onSubmit: (_) {}, primaryColor: Colors.blue));
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'nope');
    await tester.enterText(fields.last, 'x');
    await _tap(tester, find.text(I18n.t('sdk.prechat.start')));
  }, ['nope', 'x']),
  _Row('SequentialPreChatWidget', (tester) => _put(
      tester,
      SequentialPreChatWidget(
        questions: [PreChatFormField.name(), PreChatFormField.email()],
        onQuestionAnswered: (_, __) {},
        onComplete: (_) {},
        primaryColor: Colors.blue,
        animateTransitions: false,
      ))),
  _Row('SequentialPreChatWidget sent empty', (tester) async {
    await _put(
        tester,
        SequentialPreChatWidget(
          questions: [PreChatFormField.name(), PreChatFormField.email()],
          onQuestionAnswered: (_, __) {},
          onComplete: (_) {},
          primaryColor: Colors.blue,
          animateTransitions: false,
        ));
    await _tap(tester, find.byType(ElevatedButton));
  }),
  _Row('SequentialPreChatWidget a bad email', (tester) async {
    await _put(
        tester,
        SequentialPreChatWidget(
          questions: [PreChatFormField.email()],
          onQuestionAnswered: (_, __) {},
          onComplete: (_) {},
          primaryColor: Colors.blue,
          animateTransitions: false,
        ));
    await tester.enterText(find.byType(TextField), 'nope');
    await _tap(tester, find.byType(ElevatedButton));
  }, ['nope']),
  _Row('PostChatSurveyWidget', (tester) => _put(tester, PostChatSurveyWidget(onSubmit: (_) {}, onSkip: () {}, primaryColor: Colors.blue, agent: _agent))),
  _Row('PostChatSurveyWidget rated low', (tester) async {
    await _put(tester, PostChatSurveyWidget(onSubmit: (_) {}, onSkip: () {}, primaryColor: Colors.blue, requireFeedbackForLowRating: true));
    await _tap(tester, find.byIcon(Icons.star_border_rounded));
    await _tap(tester, find.text(I18n.t('common.send')));
  }),
  for (final size in AgentInfoSize.values)
    _Row('AgentInfoWidget ${size.name}', (tester) => _put(tester, AgentInfoWidget(agent: _agent, primaryColor: Colors.blue, size: size, isTyping: size == AgentInfoSize.large)), ['Kundendienst']),
  _Row('AgentInfoHeader', (tester) => _put(tester, AgentInfoHeader(agent: _agent, primaryColor: Colors.blue, isTyping: true, onClose: () {})), ['Kundendienst']),
  _Row('AgentConnectedBanner', (tester) => _put(tester, AgentConnectedBanner(agent: _agent, primaryColor: Colors.blue, onDismiss: () {})), ['Kundendienst']),
  for (final s in HandoverState.values) ...[
    _Row('HumanHandoverOverlay ${s.name}', (tester) => _put(
        tester,
        SizedBox(
          height: 1400,
          child: HumanHandoverOverlay(
            uiState: HumanHandoverUIState(nodeId: 'h1', state: s),
            agent: _agent,
            queueInfo: const QueueInfo(position: 2, estimatedWaitSeconds: 120),
            primaryColor: Colors.blue,
            onCancel: () {},
            onEndChat: () {},
            onSurveySkip: () {},
            onSurveySubmit: (_) {},
            onPreChatSubmit: (_) {},
          ),
        )), ['Kundendienst']),
    _Row('HandoverStatusIndicator ${s.name}', (tester) => _put(
        tester,
        HandoverStatusIndicator(
          uiState: HumanHandoverUIState(nodeId: 'h1', state: s),
          agent: _agent,
          queueInfo: const QueueInfo(position: 2, estimatedWaitSeconds: 120),
          primaryColor: Colors.blue,
        )), ['Kundendienst']),
  ],
  // ------------------------------------------------ the live chat's cards
  _Row('HandoverWaitCard waiting, Leave queue', (tester) async {
    final p = _provider();
    p.liveChat.queue = LiveChat.queueStatusOf({'status': 'waiting', 'position': 2, 'ahead': 1, 'agentsOnline': 1});
    await _put(tester, HandoverWaitCard(liveChat: p.liveChat, theme: defaultTheme, onLeave: () {}), provider: p);
  }),
  _Row('HandoverWaitCard busy', (tester) async {
    final p = _provider();
    p.liveChat.queue = LiveChat.queueStatusOf({'status': 'busy', 'position': 0, 'ahead': 0, 'agentsOnline': 0});
    await _put(tester, HandoverWaitCard(liveChat: p.liveChat, theme: defaultTheme), provider: p);
  }),
  _Row('HandoverWaitCard nothing known yet', (tester) async {
    final p = _provider();
    await _put(tester, HandoverWaitCard(liveChat: p.liveChat, theme: defaultTheme, onLeave: () {}), provider: p);
  }),
  _Row('LiveChatFooter: waiting busy (ask email), leave a message, file request, lead', (tester) async {
    final p = _provider();
    final live = p.liveChat;
    live.handoverWaiting = const HandoverWaiting(offline: false, reason: 'busy', askEmail: true);
    live.noAgentsAvailable = true;
    live.fileRequestedBy = 'Sam';
    live.leadCardOpen = true;
    await _put(tester, LiveChatFooter(provider: p, theme: defaultTheme, onUpload: () {}), provider: p);
  }),
  _Row('LiveChatFooter: offline wait, left a message, lead done', (tester) async {
    final p = _provider();
    final live = p.liveChat;
    live.handoverWaiting = const HandoverWaiting(offline: true, reason: 'offline', askEmail: false, email: 'jo@example.com');
    live.leftMessageTo = 'jo@example.com';
    live.leadEmail = 'jo@example.com';
    await _put(tester, LiveChatFooter(provider: p, theme: defaultTheme), provider: p);
  }),
  for (final type in ['stars', 'thumbs', 'emoji', 'nps'])
    _Row('LiveChatFooter: CSAT $type', (tester) async {
      final p = _provider();
      p.liveChat.csatConfig = LiveChat.csatConfigOf({'enabled': true, 'ratingType': type});
      p.liveChat.csatOpen = true;
      await _put(tester, LiveChatFooter(provider: p, theme: defaultTheme), provider: p);
      // A rating picked: the feedback box.
      final pick = type == 'stars' ? find.text('★') : (type == 'thumbs' ? find.text(I18n.t('sdk.csat.yes')) : find.byType(InkWell));
      if (pick.evaluate().isNotEmpty) await _tap(tester, pick);
    }),
  _Row('LiveChatFooter: CSAT sent', (tester) async {
    final p = _provider();
    p.liveChat.csatConfig = LiveChat.csatConfigOf({'enabled': true});
    p.liveChat.csatOpen = true;
    p.liveChat.csatSent = true;
    await _put(tester, LiveChatFooter(provider: p, theme: defaultTheme), provider: p);
  }),
  _Row('EmailTranscriptCard', (tester) async {
    final p = _provider();
    p.liveChat.openEmailTranscript();
    await _put(tester, EmailTranscriptCard(liveChat: p.liveChat, theme: defaultTheme), provider: p);
  }),
  _Row('EmailTranscriptCard a bad address', (tester) async {
    final p = _provider();
    p.liveChat.openEmailTranscript();
    await _put(tester, EmailTranscriptCard(liveChat: p.liveChat, theme: defaultTheme), provider: p);
    await tester.enterText(find.byType(TextField).first, 'nope');
    await _tap(tester, _key('cb-mailchat-send'));
  }, ['nope']),
  _Row('EmailTranscriptCard sent', (tester) async {
    final p = _provider();
    p.liveChat.mailSentTo = 'sam@example.com';
    await _put(tester, EmailTranscriptCard(liveChat: p.liveChat, theme: defaultTheme), provider: p);
  }),
  _Row('ClosedChatCard ended: Start a new chat', (tester) => _put(
      tester,
      ClosedChatCard(
        closed: LiveEvents.closedStateOf(const [
          {'type': 'agent-chat-ended'},
        ])!,
        theme: defaultTheme,
        onNewChat: () {},
      ))),
  _Row('ClosedChatCard blocked', (tester) => _put(tester, ClosedChatCard(closed: LiveEvents.closedStateOf(const [], blocked: LiveEvents.blockedText(const {}))!, theme: defaultTheme))),
  _Row('LiveChatComposerTop: locked, connection lost, quick actions', (tester) async {
    final p = _provider({'chatTalkToHuman': true, 'chatQuickActions': [
      {'label': 'Demo buchen', 'url': 'https://example.com/demo'},
    ]});
    p.liveChat.lockedBy = 'Sam';
    p.liveChat.agentConnectionLost = 'Sam';
    await _put(tester, LiveChatComposerTop(provider: p, theme: defaultTheme), provider: p);
  }, ['Demo buchen']),
  _Row('QuickActionsStrip', (tester) => _put(
      tester,
      QuickActionsStrip(
        provider: _FakeProvider(shown: [_aiAnswer()], custom: {
          'chatTalkToHuman': true,
          'chatQuickActions': [
            {'label': 'Demo buchen', 'url': 'https://example.com/demo'},
          ],
        }),
        theme: defaultTheme,
      )), ['Demo buchen']),
  _Row('LiveChatLine pending', (tester) => _put(tester, MessageBubble(message: _line()))),
  for (final o in HandoverOutcome.values) _Row('LiveChatLine ${o.name}', (tester) => _put(tester, MessageBubble(message: _line(settled: o.name)))),
  _Row('LiveChatLine a join with its note', (tester) => _put(
      tester,
      MessageBubble(message: _line(handover: false, kind: 'agent-joined-message', text: HandoverRecord.joinedText('Sam'), note: HandoverRecord.handedOverNote)))),
  _Row('LiveChatLine a person left', (tester) => _put(tester, MessageBubble(message: _line(handover: false, text: HandoverRecord.agentLeftText('Sam', false))))),
  // ------------------------------------------------ while you wait
  _Row('WaitHelpCard', (tester) => _put(
      tester,
      WaitHelpCard(
        card: const HelpCardState(key: 1, items: [HelpItem(kind: 'article', id: 'a1', title: 'Rechnungen', description: 'Alle Rechnungen an einem Ort.')], solvable: true),
        theme: defaultTheme,
        onOpen: (_) {},
        onSolved: () {},
      )), ['Rechnungen', 'Alle Rechnungen an einem Ort.']),
  _Row('WaitHelpCard done', (tester) => _put(
      tester,
      WaitHelpCard(
        card: const HelpCardState(key: 1, items: [HelpItem(kind: 'page', id: 'p1', title: 'Preise', url: 'https://example.com/preise')], solvable: true, settled: true, done: true),
        theme: defaultTheme,
        onOpen: (_) {},
        onSolved: () {},
      )), ['Preise']),
  _Row('WaitHelpCard settled', (tester) => _put(
      tester,
      WaitHelpCard(
        card: const HelpCardState(key: 1, items: [HelpItem(kind: 'article', id: 'a1', title: 'Rechnungen')], solvable: true, settled: true),
        theme: defaultTheme,
        onOpen: (_) {},
        onSolved: () {},
      )), ['Rechnungen']),
  for (final game in ['menu', 'rps', 'ttt', 'quiz', 'memory', 'reaction', 'scramble', 'paused'])
    _Row('GamesCard $game', (tester) async {
      final c = _games();
      if (game == 'paused') {
        c.open('memory');
        c.wrapUp('Sam');
      } else if (game != 'menu') {
        c.open(game);
      }
      await _put(tester, GamesCardView(card: c, theme: defaultTheme, customizations: const {'headerBgColor': '#123456'}));
    }),
  _Row('GamesCard rps played out', (tester) async {
    final c = _games();
    c.open('rps');
    await _put(tester, GamesCardView(card: c, theme: defaultTheme, customizations: const {'headerBgColor': '#123456'}));
    await _tap(tester, _key('cb-games-rps-rock'));
    await _tap(tester, _key('cb-games-rps-rock'));
  }),
  _Row('GamesCard ttt a move', (tester) async {
    final c = _games();
    c.open('ttt');
    await _put(tester, GamesCardView(card: c, theme: defaultTheme, customizations: const {'headerBgColor': '#123456'}));
    await _tap(tester, _key('cb-games-ttt-4'));
  }),
  // ------------------------------------------------ the home screen
  _Row('HomeScreenView: flow bot, every card', (tester) async {
    await tester.pumpWidget(_home(_homeModel()));
    await tester.pump();
  }, _homeOwner),
  _Row('HomeScreenView: an agent, the ask box', (tester) async {
    await tester.pumpWidget(_home(_homeModel(agent: true), hasAgent: true));
    await tester.pump();
    if (_key('cb-home-ask-input').evaluate().isNotEmpty) {
      await tester.enterText(_key('cb-home-ask-input'), 'Lieferung');
      await tester.pump(const Duration(milliseconds: 300));
    }
  }, [..._homeOwner, 'Lieferung']),
  _Row('HomeScreenView: the help card search, no match', (tester) async {
    final m = homeModel(c: {..._homeC, 'homeAskBox': false, 'hideRecentArticles': true}, categories: [
      {
        '_id': 'c1',
        'name': 'Grundlagen',
        'articles': [
          {'_id': 'a1', 'title': 'Erste Schritte', 'description': 'So legst du los.'},
        ],
      },
    ], now: DateTime.now().millisecondsSinceEpoch)!;
    await tester.pumpWidget(_home(m));
    await tester.pump();
    if (_key('cb-home-help-input').evaluate().isNotEmpty) {
      await tester.enterText(_key('cb-home-help-input'), 'mars');
      await tester.pump();
    }
  }, [..._homeOwner, 'mars']),
  // ------------------------------------------------ the help centre
  _Row('KnowledgeBaseScreen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(value: _kbProvider(), child: KnowledgeBaseScreen(theme: defaultTheme, onClose: () {})),
    ));
    await tester.pumpAndSettle();
  }, _kbOwner),
  _Row('KnowledgeBaseScreen an article', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(value: _kbProvider(), child: KnowledgeBaseScreen(theme: defaultTheme, onClose: () {})),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erste Schritte').first);
    await tester.pumpAndSettle();
  }, _kbOwner),
  _Row('KnowledgeBaseScreen a search with no match', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(value: _kbProvider(), child: KnowledgeBaseScreen(theme: defaultTheme, onClose: () {})),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'mars');
    await tester.pumpAndSettle();
  }, [..._kbOwner, 'mars']),
  _Row('KBSearchBar', (tester) => _put(tester, KBSearchBar(onSearch: (_) {}))),
  _Row('KBSearchBar typed', (tester) async {
    await _put(tester, KBSearchBar(onSearch: (_) {}));
    await tester.enterText(find.byType(TextField), 'Rech');
    await tester.pump(const Duration(milliseconds: 600));
  }, ['Rech']),
  _Row('ArticleList', (tester) => _put(tester, SizedBox(height: 900, child: ArticleList(articles: [_article()], onArticleTap: (_) {}))), [..._kbOwner, 'start']),
  _Row('ArticleList empty', (tester) => _put(tester, SizedBox(height: 900, child: ArticleList(articles: const [], onArticleTap: (_) {})))),
  _Row('ArticleList loading', (tester) => _put(tester, SizedBox(height: 900, child: ArticleList(articles: const [], isLoading: true, onArticleTap: (_) {})))),
  _Row('ArticleDetail: Was this article helpful?', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ArticleDetail(article: _article(), onBack: () {}, onRate: (_, {feedback}) async => true, onInsertToChat: () {})));
    await tester.pump(const Duration(milliseconds: 600));
  }, [..._kbOwner, 'start']),
  _Row('ArticleDetail rated', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ArticleDetail(article: _article(), onBack: () {}, onRate: (_, {feedback}) async => true, userRating: 5)));
    await tester.pump(const Duration(milliseconds: 600));
  }, [..._kbOwner, 'start']),
  _Row('ArticleDetail loading, then an error', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ArticleDetail(article: _article(), isLoadingContent: true, onBack: () {})));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_english(tester, [..._kbOwner, 'start']), isEmpty);
    await tester.pumpWidget(MaterialApp(home: ArticleDetail(article: _article(), contentError: 'x', onBack: () {})));
    await tester.pump(const Duration(milliseconds: 600));
  }, [..._kbOwner, 'start', 'x']),
  _Row('ArticleThumbsRating', (tester) => _put(tester, ArticleThumbsRating(theme: defaultTheme, onRate: (_) {}))),
  _Row('ArticleRatingWidget', (tester) => _put(tester, ArticleRatingWidget(theme: defaultTheme, onRate: (_) async => true))),
  _Row('CategoryChips', (tester) => _put(
      tester,
      CategoryChips(
        categories: const [KnowledgeBaseCategory(id: 'c1', name: 'Grundlagen', articleCount: 2), KnowledgeBaseCategory(id: 'c2', name: 'Fragen', articleCount: 1)],
        onCategorySelected: (_) {},
        showAllChip: true,
      )), _kbOwner),
  _Row('CategoryGrid', (tester) => _put(
      tester,
      CategoryGrid(
        categories: const [KnowledgeBaseCategory(id: 'c1', name: 'Grundlagen', articleCount: 2), KnowledgeBaseCategory(id: 'c2', name: 'Fragen', articleCount: 1)],
        onCategorySelected: (_) {},
      )), _kbOwner),
  // ------------------------------------------------ your requests
  _Row('RequestsPortalView list', (tester) async {
    final p = _portal();
    await tester.pumpWidget(_requests(p));
    unawaited(p.openList());
    await tester.pumpAndSettle();
  }, _requestsOwner),
  _Row('RequestsPortalView one request', (tester) async {
    final p = _portal();
    await tester.pumpWidget(_requests(p));
    unawaited(p.openList());
    await tester.pumpAndSettle();
    await tester.tap(_key('cb-requests-row-mobile_1_abcdef'));
    await tester.pumpAndSettle();
  }, _requestsOwner),
  // ------------------------------------------------ the greeting card and the launcher
  for (final style in ['card', 'note', 'imessage', 'postcard', 'notification', 'voice', 'typewriter'])
    _Row('GreetingCard $style', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Center(child: GreetingCard(data: _greeting(style), reduceMotion: true, onPress: () {}, onClose: () {}, onStarter: (_) {})),
      ));
      await tester.pump(const Duration(seconds: 3));
    }, ['Hallo! Wie können wir helfen?', 'Preise']),
  _Row('ConferBotFAB label style', (tester) async {
    final p = _provider({'launcherStyle': 'label'});
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(800, 844), disableAnimations: true),
      child: MaterialApp(home: ChangeNotifierProvider<ConferBotProvider>.value(value: p, child: const ConferBotFAB(child: SizedBox.expand()))),
    ));
    await tester.pump();
    _drain(tester);
  }),
  _Row('IdleCallBubble', (tester) => _put(tester, IdleCallBubble(line: 'Klopf klopf!', tail: 20, onTap: () {})), ['Klopf klopf!']),
];

final _kbJson = {
  'categories': [
    {
      '_id': 'c1',
      'name': 'Grundlagen',
      'articles': [
        {'_id': 'a1', 'title': 'Erste Schritte', 'description': 'So legst du los.'},
      ],
    },
  ],
  'recentArticles': [],
};

// ---------------------------------------------------------------- tests

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _TempPaths(Directory.systemTemp.createTempSync('cb_sweep_').path);
    await StorageService.init();
  });

  setUp(() {
    ChatState.instance.reset();
    I18n.setWidgetLanguage('de', const []);
  });

  tearDown(() {
    ChatState.instance.reset();
    I18n.debugReset();
  });

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(minutes: 1));
    }
    _drain(tester);
  }

  group('nothing the SDK draws is English under "de"', () {
    for (final row in _rows) {
      testWidgets(row.name, (tester) async {
        tester.view.physicalSize = const Size(900, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await row.pump(tester);
        final bad = _english(tester, row.owner);
        await finish(tester);
        expect(bad, isEmpty, reason: row.name);
      });
    }
  });

  group('the check itself', () {
    test('no German string looks English to it', () {
      final hole = RegExp(r'\{\w+\}');
      final de = I18n.dictionary('de');
      final looks = [
        for (final e in de.entries)
          if (_englishWords.hasMatch(e.value.replaceAll(hole, ''))) '${e.key}: ${e.value}',
      ];
      expect(looks, isEmpty);
    });

    test('it catches English and lets German through', () {
      expect(englishIn(['Type a message...']), isNotEmpty);
      expect(englishIn(['Sam is typing']), isNotEmpty);
      expect(englishIn([I18n.tFor('de', 'chat.composer.placeholder'), 'Sam']), isEmpty);
    });

    testWidgets('the same screens in English are caught', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      I18n.setWidgetLanguage('en', const []);
      const names = ['ChatInput', 'QueueStatusWidget', 'HelpfulRow No: the reasons', 'GamesCard menu', 'HomeScreenView: flow bot, every card', 'ArticleDetail: Was this article helpful?'];
      final caught = <String, int>{};
      for (final row in _rows.where((r) => names.contains(r.name))) {
        await row.pump(tester);
        caught[row.name] = _english(tester, row.owner).length;
        await finish(tester);
      }
      expect(caught.keys.toSet(), names.toSet());
      expect(caught.values.every((n) => n > 0), isTrue, reason: '$caught');
    });
  });
}
