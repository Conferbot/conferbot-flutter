// The human touches on screen (core/delight/delight_extras.dart,
// widgets/delight/delight_views.dart; RN __tests__/core/delight.test.ts's
// timing cases and __tests__/components/Delight.test.tsx): the tapback and
// the burst 550 ms after an answer, nothing moving with reduced motion,
// "Edit" under the latest answer once the bot is quiet and going back with
// it, the nudge, the rating's sparks and caption word, a booked time on the
// calendar card, the composer's draft.
import 'package:conferbot_flutter/src/core/delight/delight_extras.dart';
import 'package:conferbot_flutter/src/core/flow/flow_context.dart';
import 'package:conferbot_flutter/src/core/node_flow_engine.dart';
import 'package:conferbot_flutter/src/core/nodes/node_handler_registry.dart';
import 'package:conferbot_flutter/src/core/nodes/node_ui_state.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:conferbot_flutter/src/theme/default_theme.dart';
import 'package:conferbot_flutter/src/ui/widgets/date_steps.dart';
import 'package:conferbot_flutter/src/ui/widgets/node_widgets.dart';
import 'package:conferbot_flutter/src/widgets/chat_bottom_bar.dart';
import 'package:conferbot_flutter/src/widgets/delight/delight_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Socket implements FlowSocket {
  @override
  void emit(String event, dynamic payload) {}
  @override
  void Function() on(String event, void Function(dynamic payload) listener) => () {};
  @override
  void sendResponseRecord(Map<String, dynamic> responseData) {}
}

Map<String, dynamic> _node(String id, String type, [Map<String, dynamic> data = const {}]) =>
    {'id': id, 'type': type, 'data': data, 'position': {'x': 0, 'y': 0}};

Map<String, dynamic> _edge(String source, String target) =>
    {'id': 'e-$source-$target', 'source': source, 'sourceHandle': 'source', 'target': target};

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduced),
        child: Scaffold(body: Center(child: child)),
      ),
    );

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void main() {
  group('the touches, timed', () {
    late NodeFlowEngine engine;
    late List<DelightRow> rows;
    late List<int> cuts;
    late DelightExtras delight;
    Map<String, dynamic> customizations = {};

    Future<void> setUpFlow(WidgetTester tester) async {
      ChatState.instance.reset();
      ChatState.instance.initialize(chatSessionId: 's1', visitorId: 'v1', botId: 'b1');
      engine = NodeFlowEngine(socket: _Socket(), registry: NodeHandlerRegistry.withAll(), config: const NodeFlowEngineConfig(typingDelay: 0));
      engine.loadFlow([
        _node('w', 'welcome-node', {'text': '<p>Hi</p>', 'disableImage': true}),
        _node('q1', 'ask-name-node', {'questionText': '<p>Your name?</p>', 'answerVariable': 'name'}),
        _node('q2', 'ask-email-node', {'questionText': '<p>Your email?</p>', 'answerVariable': 'email'}),
      ], [
        _edge('w', 'q1'),
        _edge('q1', 'q2'),
      ]);
      rows = [];
      cuts = [];
      delight = DelightExtras(
        customizations: () => customizations,
        engine: () => engine,
        rows: () => rows,
        chatVisible: () => true,
        locked: () => false,
        cut: (i) {
          cuts.add(i);
          rows.removeRange(i, rows.length);
        },
        now: () => tester.binding.clock.now(),
      );
      engine.start();
      await settle(tester);
    }

    testWidgets('a wave 550 ms after a name; Edit once the bot is quiet; going back with it', (tester) async {
      customizations = {};
      await setUpFlow(tester);
      rows.add(DelightRow(id: 'b1', nodeId: 'q1', time: DateTime.now()));
      engine.submitResponse('Jamie');
      // The answer's own short pause, then the next question.
      await tester.pump(const Duration(seconds: 2));
      rows.add(DelightRow(id: 'u1', nodeId: 'q1', visitor: true, time: DateTime.now()));
      delight.answered('u1', const AnswerOf(nodeId: 'q1', type: 'ask-name-node', text: 'Jamie'), at: tester.binding.clock.now());
      await tester.pump(const Duration(milliseconds: 549));
      expect(delight.touches['u1'], isNull);
      await tester.pump(const Duration(milliseconds: 1));
      expect(delight.touches['u1']!.reaction, '👋');
      expect(delight.touches['u1']!.celebrate, isNull);

      expect(engine.currentNodeId, 'q2');
      delight.conversationChanged();
      await tester.pump(const Duration(milliseconds: 899));
      expect(delight.changeRowId, isNull);
      await tester.pump(const Duration(milliseconds: 1));
      expect(delight.changeRowId, 'u1');

      expect(await delight.changeAnswer(), isTrue);
      await tester.pump();
      // Cut at the question's own bubble, the answer and everything after gone.
      expect(cuts, [0]);
      expect(delight.changeRowId, isNull);
      expect(engine.currentNodeId, 'q1');
      expect(ChatState.instance.getAnswer('name'), isNull);
      engine.dispose();
      delight.dispose();
    });

    testWidgets("the owner's switches: no tapback, no Edit", (tester) async {
      customizations = {'botReactions': false, 'allowChangeAnswer': false};
      await setUpFlow(tester);
      engine.submitResponse('Jamie');
      rows.add(DelightRow(id: 'u1', nodeId: 'q1', visitor: true, time: DateTime.now()));
      delight.answered('u1', const AnswerOf(nodeId: 'q1', type: 'ask-name-node', text: 'Jamie'), at: tester.binding.clock.now());
      delight.conversationChanged();
      await tester.pump(const Duration(seconds: 2));
      expect(delight.touches, isEmpty);
      expect(delight.changeRowId, isNull);
      engine.dispose();
      delight.dispose();
    });

    testWidgets('a booking bursts; not with reduced motion; a restored answer gets nothing', (tester) async {
      customizations = {};
      await setUpFlow(tester);
      delight.answered('u1', const AnswerOf(nodeId: 'c', type: 'calendar-node', text: 'Tue'), at: tester.binding.clock.now());
      await tester.pump(const Duration(milliseconds: 600));
      expect(delight.touches['u1']!.reaction, '🎉');
      expect(delight.touches['u1']!.celebrate, isNotNull);
      delight.clearBurst('u1');
      expect(delight.touches['u1']!.celebrate, isNull);
      delight.reducedMotion = true;
      delight.answered('u2', const AnswerOf(nodeId: 'c', type: 'calendar-node', text: 'Tue'), at: tester.binding.clock.now());
      delight.answered('u3', const AnswerOf(nodeId: 'q1', type: 'ask-name-node', text: 'Jo'), at: tester.binding.clock.now().subtract(const Duration(minutes: 5)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(delight.touches['u2']!.celebrate, isNull);
      expect(delight.touches['u3'], isNull);
      engine.dispose();
      delight.dispose();
    });

    testWidgets('the nudge 40 s into a waiting question, gone once answered', (tester) async {
      customizations = {};
      await setUpFlow(tester);
      await tester.pump(const Duration(seconds: 15)); // quiet since it started
      delight.stepChanged('q1', 'ask-name-node');
      await tester.pump(const Duration(seconds: 40));
      expect(delight.stallHint, "No rush - type your answer below whenever you're ready.");
      delight.answered('u1', const AnswerOf(nodeId: 'q1', type: 'ask-name-node', text: 'Jo'));
      expect(delight.stallHint, isNull);
      // Off when the owner turned it off.
      customizations = {'stallNudges': false};
      delight.stepChanged('q2', 'ask-email-node');
      await tester.pump(const Duration(minutes: 2));
      expect(delight.stallHint, isNull);
      engine.dispose();
      delight.dispose();
    });
  });

  group('drawn', () {
    testWidgets('the tapback badge and the burst; nothing moving with reduced motion', (tester) async {
      Widget overlay({bool reduced = false}) => _host(
            const SizedBox(
              width: 120,
              height: 40,
              child: AnswerTouchOverlay(reaction: '❤️', celebrate: 1, accent: Color(0xFF4F46E5), card: Colors.white, ring: Colors.white),
            ),
            reduced: reduced,
          );
      await tester.pumpWidget(overlay());
      expect(find.byKey(const ValueKey('cb-reaction-badge')), findsOneWidget);
      expect(find.bySemanticsLabel('The bot loved this'), findsOneWidget);
      expect(find.byKey(const ValueKey('cb-confetti')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      await tester.pumpWidget(overlay(reduced: true));
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpWidget(overlay(reduced: true));
      expect(find.byKey(const ValueKey('cb-reaction-badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('cb-confetti')), findsNothing);
    });

    testWidgets('"Edit" and the nudge', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_host(Column(children: [
        ChangeAnswerLink(onPressed: () => tapped++, muted: Colors.grey),
        const StallHint(text: 'No rush', accent: Colors.indigo, muted: Colors.grey),
      ])));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Edit'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cb-change-answer')));
      expect(tapped, 1);
      expect(find.text('No rush'), findsOneWidget);
    });

    testWidgets("the rating's sparks and its word on a pick", (tester) async {
      dynamic sent;
      await tester.pumpWidget(_host(RatingNodeWidget(
        state: const RatingUIState(nodeId: 'r', ratingType: RatingType.star, minValue: 1, maxValue: 5, labels: ['Bad', 'Meh', 'Okay', 'Good', 'Great']),
        onResponse: (r) => sent = r,
        primaryColor: Colors.indigo,
        theme: defaultTheme,
      )));
      expect(find.byKey(const ValueKey('cb-rating-sparks')), findsNothing);
      await tester.tap(find.byIcon(Icons.star_outline).at(3));
      await tester.pump();
      expect(sent, {'value': 4, 'label': '4'});
      expect(find.byKey(const ValueKey('cb-rating-sparks')), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('a booked time is drawn, greyed out and not pickable', (tester) async {
      const key = '2026-10-17';
      dynamic sent;
      await tester.pumpWidget(_host(SingleChildScrollView(
        child: CalendarStepWidget(
          state: const CalendarUIState(
            nodeId: 'cal',
            showTimeSelection: true,
            mode: 'datetime',
            timezone: 'UTC',
            availableSlots: {
              key: ['09:00', '09:30'],
            },
            bookedSlots: {
              key: ['09:00'],
            },
          ),
          onResponse: (r) => sent = r,
          theme: defaultTheme,
          primaryColor: Colors.indigo,
          today: DateTime(2026, 10, 15),
        ),
      )));
      await tester.pump();
      await tester.tap(find.text('17').last);
      await tester.pump();
      expect(find.bySemanticsLabel('09:00, booked'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cal-slot-09:00')));
      await tester.pump();
      expect(sent, isNull);
      await tester.tap(find.byKey(const ValueKey('cal-slot-09:30')));
      await tester.pump();
      expect((sent as Map)['slot'], '09:30');
    });

    testWidgets("the composer reports its draft, and clears it on send", (tester) async {
      final drafts = <String>[];
      await tester.pumpWidget(_host(ChatBottomBar(
        onSend: (_) async {},
        onDraftChanged: (text, {bool secret = false}) {
          expect(secret, isFalse);
          drafts.add(text);
        },
      )));
      await tester.enterText(find.byType(TextField), 'hel');
      await tester.pump();
      expect(drafts.last, 'hel');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(drafts.last, '');
    });
  });
}
