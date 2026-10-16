/// "Your requests" drawn (widgets/requests/requests_portal_view.dart; web
/// view.ts, polish-requests.css): the list, one request, the reply box,
/// Back and Android's back, and the chat menu's item.
library;

import 'dart:async';

import 'package:conferbot_flutter/src/core/requests/requests.dart';
import 'package:conferbot_flutter/src/core/requests/requests_portal.dart';
import 'package:conferbot_flutter/src/widgets/chat_widget.dart';
import 'package:conferbot_flutter/src/widgets/requests/requests_portal_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/requests/requests_portal_test.dart' show FakeApi, detail, summary, now;

RequestsPortal portalWith(FakeApi api, {Map<String, int>? seen}) {
  final marks = seen ?? <String, int>{};
  return RequestsPortal(
    api: api,
    seen: () => marks,
    markSeen: (id, at) => marks[id] = at,
    isCurrentChat: (_) => false,
    openChat: () {},
    now: () => now,
    rand: () => 0.5,
  );
}

Widget host(RequestsPortal portal, {List<String>? opened}) => MaterialApp(
      home: Scaffold(
        body: RequestsPortalView(
          portal: portal,
          accent: requestsColorOf('#0808EE'),
          now: () => now,
          openUrl: (u) async => opened?.add(u),
        ),
      ),
    );

void main() {
  testWidgets('closed: nothing drawn', (tester) async {
    await tester.pumpWidget(host(portalWith(FakeApi())));
    expect(find.byKey(const ValueKey('cb-requests')), findsNothing);
  });

  testWidgets('the list: each request in words, a new reply bold with a dot; a row opens it, Back returns', (tester) async {
    final api = FakeApi(listAnswer: () => [summary(id: 'old_aaaaaa', lastFrom: 'you'), summary()]);
    final portal = portalWith(api);
    await tester.pumpWidget(host(portal));
    unawaited(portal.openList());
    await tester.pumpAndSettle();
    expect(find.text('Your requests'), findsOneWidget);
    expect(find.text('New reply from Ada · 1 min ago'), findsOneWidget);
    expect(find.text("We're on it · 1 min ago"), findsOneWidget);
    expect(find.byKey(const ValueKey('cb-requests-new-mobile_1_abcdef')), findsOneWidget);
    expect(find.byKey(const ValueKey('cb-requests-new-old_aaaaaa')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cb-requests-row-mobile_1_abcdef')));
    await tester.pumpAndSettle();
    expect(find.text('Your request'), findsOneWidget);
    expect(find.text('We replied'), findsOneWidget);
    expect(find.text('Read it below. If you need anything else, just write back.'), findsOneWidget);
    expect(find.byKey(const ValueKey('cb-requests-msg-m1')), findsOneWidget);
    expect(find.byKey(const ValueKey('cb-requests-msg-m2')), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cb-requests-back')));
    await tester.pumpAndSettle();
    expect(api.closes, ['mobile_1_abcdef']);
    expect(find.text('Your requests'), findsOneWidget);
    // Read now: no dot.
    expect(find.byKey(const ValueKey('cb-requests-new-mobile_1_abcdef')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('cb-requests-back')));
    await tester.pumpAndSettle();
    expect(portal.isOpen, isFalse);
    expect(find.byKey(const ValueKey('cb-requests')), findsNothing);
  });

  testWidgets("Android's back steps back one screen", (tester) async {
    final portal = portalWith(FakeApi());
    await tester.pumpWidget(host(portal));
    unawaited(portal.openList());
    await tester.pumpAndSettle();
    unawaited(portal.pick('mobile_1_abcdef'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(portal.state.screen, RequestsScreen.list);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(portal.isOpen, isFalse);
  });

  testWidgets('empty, and could not load with Try again', (tester) async {
    final api = FakeApi(listAnswer: () => []);
    final portal = portalWith(api);
    await tester.pumpWidget(host(portal));
    unawaited(portal.openList());
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet. When you ask us something, you can follow it here.'), findsOneWidget);
    portal.close();
    api.listAnswer = () => null;
    unawaited(portal.openList());
    await tester.pumpAndSettle();
    expect(find.text("We couldn't load this just now."), findsOneWidget);
    api.listAnswer = () => [summary()];
    await tester.tap(find.byKey(const ValueKey('cb-requests-reload')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cb-requests-row-mobile_1_abcdef')), findsOneWidget);
  });

  testWidgets('the reply box: Send only with words, Sending..., Not sent with Try again, closed for replies', (tester) async {
    final answer = Completer<ReplyResult>();
    final api = FakeApi(replyAnswer: (_, __, ___) => answer.future);
    final portal = portalWith(api);
    await tester.pumpWidget(host(portal));
    unawaited(portal.openRequest('mobile_1_abcdef'));
    await tester.pumpAndSettle();
    expect(find.text('Write your reply...'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cb-requests-send')));
    expect(api.replies, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('cb-requests-input')), 'Still wrong');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cb-requests-send')));
    await tester.pump();
    expect(api.replies.single.$2, 'Still wrong');
    expect(find.text('Sending...'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('cb-requests-input'))).controller!.text, '');

    answer.complete(const ReplyResult(ok: false, reason: 'offline'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cb-requests-not-sent')), findsOneWidget);
    api.replyAnswer = (_, __, ___) async => const ReplyResult(ok: false, reason: 'locked');
    await tester.tap(find.byKey(const ValueKey('cb-requests-retry')));
    await tester.pumpAndSettle();
    expect(api.replies, hasLength(2));
    expect(api.replies[1].$3, api.replies[0].$3);
    expect(find.text('This conversation is closed for replies.'), findsOneWidget);
    expect(find.byKey(const ValueKey('cb-requests-retry')), findsNothing);
  });

  testWidgets('a solved request asks to write to open it again; links in a message open', (tester) async {
    final opened = <String>[];
    final api = FakeApi(
      openAnswer: () async => detail(status: 'solved', messages: const [
        RequestMessage(id: 'm1', from: 'team', name: '', text: 'See https://example.com/help. Thanks'),
      ]),
    );
    final portal = portalWith(api);
    await tester.pumpWidget(host(portal, opened: opened));
    unawaited(portal.openRequest('mobile_1_abcdef'));
    await tester.pumpAndSettle();
    expect(find.text('Solved'), findsOneWidget);
    expect(find.text('Write here to open it again...'), findsOneWidget);
    expect(find.text('Support team'), findsOneWidget);
    // The link's run is tapped through its recogniser.
    final rich = tester.widget<SelectableText>(find.byType(SelectableText));
    final link = rich.textSpan!.children!.whereType<TextSpan>().firstWhere((s) => s.text == 'https://example.com/help');
    (link.recognizer! as dynamic).onTap();
    expect(opened, ['https://example.com/help']);
  });

  testWidgets('the chat menu offers Your requests, with New reply when one is unread', (tester) async {
    var opened = 0;
    Widget header(int unread) => MaterialApp(
          home: Scaffold(
            body: ChatHeaderWithKB(title: 'Help', onRequests: () => opened++, requestsUnread: unread),
          ),
        );
    await tester.pumpWidget(header(1));
    await tester.tap(find.byKey(const ValueKey('cb-chat-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Your requests · New reply'), findsOneWidget);
    expect(find.text('Email me this chat'), findsNothing);
    await tester.tap(find.text('Your requests · New reply'));
    await tester.pumpAndSettle();
    expect(opened, 1);

    await tester.pumpWidget(header(0));
    await tester.tap(find.byKey(const ValueKey('cb-chat-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Your requests'), findsOneWidget);

    // No request yet: no item (and no menu without another item).
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ChatHeaderWithKB(title: 'Help'))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cb-chat-menu')), findsNothing);
  });
}
