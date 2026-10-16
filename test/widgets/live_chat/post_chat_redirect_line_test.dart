// The post-chat redirect's line (live_chat_cards.dart PostChatRedirectLine),
// the cases of React Native's __tests__/components/PostChatRedirectLine.test.tsx:
// the countdown with Cancel, said once to a screen reader, "Taking you to…"
// once it opened, "Continue to" when the system could not open it, and the
// app going to the background stopping it.
import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
import 'package:conferbot_flutter/src/core/live_chat/post_chat_redirect.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/widgets/live_chat_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => I18n.setWidgetLanguage('en'));

  late bool refuse;
  late List<String> went;

  PostChatRedirect redirect() => PostChatRedirect(
        redirectUrl: () => 'https://www.example.com/thanks',
        sessionId: () => 's1',
        chatVisible: () => true,
        blocked: () => false,
        live: () => false,
        ratingPending: () => false,
        open: (href) async {
          if (refuse) return false;
          went.add(href);
          return true;
        },
      );

  Future<PostChatRedirect> pump(WidgetTester tester) async {
    refuse = false;
    went = [];
    final r = redirect();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: r,
          builder: (_, __) => r.line == null ? const SizedBox() : PostChatRedirectLine(redirect: r, theme: defaultTheme),
        ),
      ),
    ));
    r.conversationEnded();
    await tester.pump(redirectSettle);
    await tester.pump();
    return r;
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets('the countdown and Cancel, said once', (tester) async {
    final handle = tester.ensureSemantics();
    final r = await pump(tester);
    expect(find.text('Taking you to example.com in 10s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Taking you to example.com in 7s'), findsOneWidget);
    // The ticking text is hidden; the first sentence is the live region's.
    expect(find.bySemanticsLabel('Taking you to example.com in 10s'), findsOneWidget);
    expect(find.bySemanticsLabel('Taking you to example.com in 7s'), findsNothing);
    expect(find.bySemanticsLabel('Cancel going to example.com'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(key('cb-redirect-cancel'));
    await tester.pump();
    expect(key('cb-redirect'), findsNothing);
    await tester.pump(const Duration(seconds: 20));
    expect(went, isEmpty);
    expect(r.line, isNull);
    handle.dispose();
  });

  testWidgets('at 0 the browser opens, and the line has no Cancel', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(went, ['https://www.example.com/thanks']);
    expect(find.text('Taking you to example.com…'), findsOneWidget);
    expect(key('cb-redirect-cancel'), findsNothing);
  });

  testWidgets('a Continue button when the system could not open it', (tester) async {
    final r = await pump(tester);
    refuse = true;
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.text('Continue to example.com'), findsOneWidget);
    refuse = false;
    await tester.tap(key('cb-redirect-go'));
    await tester.pump();
    expect(went, ['https://www.example.com/thanks']);
    expect(r.line, isNull);
  });

  testWidgets('the app going to the background stops it', (tester) async {
    final r = await pump(tester);
    expect(r.line, isNotNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(r.line, isNull);
    // Back in the app: no line, nothing opened.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 20));
    expect(key('cb-redirect'), findsNothing);
    expect(went, isEmpty);
  });
}
