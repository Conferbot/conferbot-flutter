/// The step handlers on their own, with the fields the builder saves
/// (conferbot-react-native scripts/parity/flows/nodes.spec.json). Whole
/// flows, routing and timing are covered by the spec's fixtures in
/// test/parity/flows_test.dart.
library;

import 'dart:convert';

import 'package:conferbot_flutter/src/core/flow/flow_context.dart';
import 'package:conferbot_flutter/src/core/nodes/handlers/handlers.dart';
import 'package:conferbot_flutter/src/core/nodes/node_handler.dart';
import 'package:conferbot_flutter/src/core/nodes/node_handler_registry.dart';
import 'package:conferbot_flutter/src/core/nodes/node_ui_state.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// A step's context with no waiting: the bot API answers from [replies]
/// and records each call; [handles] are the edges wired from the step.
class _Ctx {
  final calls = <Map<String, dynamic>>[];
  final Map<String, dynamic> replies;
  final Set<String> handles;
  final emits = <String>[];

  _Ctx({this.replies = const {}, this.handles = const {}});

  FlowContext build() => FlowContext(
        botId: 'b1',
        sessionId: 's1',
        api: (path, body, {timeoutMs}) async {
          calls.add({'path': path, 'body': jsonDecode(jsonEncode(body))});
          final r = replies[path];
          if (r == null) return const ApiReply(ok: false, status: 0, error: 'network');
          return ApiReply(ok: true, status: 200, body: r);
        },
        upload: (_) async => const UploadResult(ok: true, url: 'https://api.test/media/f'),
        emit: (event, _) {
          emits.add(event);
          return true;
        },
        on: (_, __) => () {},
        typing: (_) async {},
        delay: (_) async {},
        edges: () => const [],
        edgesOf: (_) => const [],
        wired: handles.contains,
        random: () => 0.5,
        now: () => DateTime.utc(2026, 10, 15, 10),
        respond: (_) {},
        shown: () {},
        isStale: () => false,
        node: (_) => null,
      );
}

FlowNode _node(String type, Map<String, dynamic> data, [_Ctx? ctx]) =>
    FlowNode(id: 'n1', type: type, data: data, ctx: (ctx ?? _Ctx()).build());

NodeHandler _handler(String type) => NodeHandlerRegistry.withAll().getHandler(type)!;

String? _port(NodeResult r) => r is ProceedResult ? r.port : null;

void main() {
  late ChatState state;

  setUp(() {
    state = ChatState.instance..reset();
    state.initialize(chatSessionId: 's1', visitorId: 'v1', botId: 'b1');
  });

  tearDown(() => state.reset());

  test('every node type the spec covers has a handler', () {
    final registry = NodeHandlerRegistry.withAll();
    // Flow-control steps are run by the engine itself.
    const engineRun = {'loop-node', 'subflow-node', 'run-subflow-node', 'subflow-return-node'};
    for (final type in [
      'welcome-node', 'message-node', 'image-node', 'video-node', 'audio-node', 'file-node', 'html-node',
      'user-redirect-node', 'navigate-node', 'ask-name-node', 'ask-email-node', 'ask-phone-number-node',
      'ask-number-node', 'ask-url-node', 'ask-file-node', 'ask-location-node', 'ask-custom-question-node',
      'ask-multiple-questions-node', 'calendar-node', 'n-choices-node', 'image-choice-node', 'yes-or-no-choice-node',
      'rating-choice-node', 'opinion-scale-choice-node', 'n-select-option-node', 'n-check-options-node',
      'carousel-node', 'two-choices-node', 'three-choices-node', 'select-option-node', 'user-rating-node',
      'quiz-node', 'user-input-node', 'user-range-node', 'condition-node', 'boolean-logic-node',
      'math-operation-node', 'variable-node', 'random-flow-node', 'jump-to-node', 'business-hours-node',
      'gpt-node', 'webhook-node', 'email-node', 'zapier-node', 'stripe-node', 'delay-node', 'human-handover-node',
      'google-sheets-node', 'google-calendar-node', 'google-meet-node', 'hubspot-node', 'mailchimp-node',
      'segment-node', 'salesforce-node', 'dynamic-choices-node', 'hidden-fields-node', 'consent-node',
      'product-card-node', 'slider-node', 'datetime-node', 'ranking-node', 'otp-node', 'address-node',
      'matrix-node', 'ai-extract-node', 'ai-route-node', 'kb-answer-node', 'signature-node', 'payment-node',
    ]) {
      if (engineRun.contains(type)) continue;
      expect(registry.hasHandler(type), isTrue, reason: type);
    }
  });

  group('fields the builder saves (#31)', () {
    test('two-choices reads choiceText1/2 and leaves by source-1/2', () async {
      final h = _handler('two-choices-node');
      final node = _node('two-choices-node', {'choicePrompt': '<p>Pick</p>', 'choiceText1': '<p>Yes</p>', 'choiceText2': '<p>No</p>'});
      final ui = (await h.handle(node, state) as DisplayUIResult).uiState as SingleChoiceUIState;
      expect(ui.choices.map((c) => c.text), ['Yes', 'No']);
      final r = await h.handleResponse({'buttonId': ui.choices[1].id}, node, state)!;
      expect(_port(r), 'source-2');
    });

    test('math saves its result by name, made or not (setAnswerVariable kept new entries)', () async {
      final h = _handler('math-operation-node');
      state.registerAnswerVariable('q', 'price');
      state.setAnswerVariable('q', 20);
      await h.handle(
          _node('math-operation-node', {'leftValue': 'price', 'operator': '*', 'rightValue': '2', 'answerVariable': 'total'}), state);
      expect(state.getAnswer('total'), 40);
    });

    test('a question without answerVariable stores nothing', () async {
      final h = _handler('ask-name-node');
      final node = _node('ask-name-node', {'questionText': '<p>Name?</p>'});
      await h.handle(node, state);
      await h.handleResponse('Ana', node, state);
      expect(state.answerVariables, isEmpty);
    });
  });

  group('condition-node (#32)', () {
    Future<String?> run(Map<String, dynamic> data) async => _port(await _handler('condition-node').handle(_node('condition-node', data), state));

    test('a bare variable name on the left is looked up', () async {
      state.saveVariableByName('plan', 'Pro');
      expect(await run({'leftValue': 'plan', 'operator': '=', 'rightValue': 'pro', 'customRightValue': true, 'caseInsensitive': true}), 'source-0');
      expect(await run({'leftValue': 'plan', 'operator': '=', 'rightValue': 'pro', 'customRightValue': true}), 'source-1');
    });

    test('numbers, regex and the operator aliases', () async {
      state.saveVariableByName('age', '42');
      expect(await run({'leftValue': 'age', 'operator': '>', 'rightValue': '40', 'customRightValue': true, 'isNumber': true}), 'source-0');
      expect(await run({'leftValue': 'age', 'operator': 'matches', 'rightValue': r'^\d+$', 'customRightValue': true}), 'source-0');
      expect(await run({'leftValue': 'age', 'operator': 'matches', 'rightValue': '(', 'customRightValue': true}), 'source-1');
      expect(await run({'leftValue': 'missing', 'operator': 'is_not_set', 'customRightValue': true}), 'source-0');
    });
  });

  group('server calls (#29, #34)', () {
    test('GPT goes through the server with the transcript, never an API key', () async {
      state.addBotMessage('Hi', 'w', 'welcome-node');
      state.addUserMessage('What is the price?', 'q');
      final ctx = _Ctx(replies: {
        'gpt': {'reply': 'It is \$10.'}
      });
      final r = await _handler('gpt-node').handle(_node('gpt-node', {'apiKey': 'sk-should-not-travel', 'prompt': 'x'}, ctx), state);
      expect(r, isA<ProceedResult>());
      expect(ctx.calls.single['path'], 'gpt');
      final body = ctx.calls.single['body'] as Map;
      expect(body.keys, unorderedEquals(['nodeId', 'transcript']));
      expect(jsonEncode(body), isNot(contains('sk-should-not-travel')));
      expect(state.transcript.last.message, 'It is \$10.');
    });

    test('a failed GPT call says nothing and moves on', () async {
      final r = await _handler('gpt-node').handle(_node('gpt-node', const {}, _Ctx()), state);
      expect(r, isA<ProceedResult>());
      expect(state.transcript, isEmpty);
    });

    test('ai-route asks the server and leaves by the intent, else the fallback', () async {
      final h = _handler('ai-route-node');
      final data = {
        'questionText': '<p>How can we help?</p>',
        'intents': [
          {'id': 'billing', 'name': 'Billing'},
        ],
        'answerVariable': 'route',
      };
      final ctx = _Ctx(replies: {
        'ai/route': {'intentId': 'billing', 'intent': 'Billing', 'confidence': 0.9}
      }, handles: {'source-billing'});
      final node = _node('ai-route-node', data, ctx);
      await h.handle(node, state);
      final r = await h.handleResponse('I was charged twice', node, state)!;
      expect(ctx.calls.single['path'], 'ai/route');
      expect(_port(r), 'source-billing');
      final unwired = _Ctx(replies: ctx.replies);
      final node2 = _node('ai-route-node', data, unwired);
      expect(_port(await h.handleResponse('I was charged twice', node2, state)!), 'source-fallback');
    });

    test('ai-extract saves the fields the server found', () async {
      final h = _handler('ai-extract-node');
      final ctx = _Ctx(replies: {
        'ai/extract': {
          'ok': true,
          'values': {'city': 'Paris'},
          'missing': <String>[],
        }
      });
      final node = _node(
          'ai-extract-node',
          {
            'questionText': '<p>Where?</p>',
            'source': 'ask',
            'fields': [
              {'id': 'f1', 'name': 'city', 'type': 'text', 'required': true},
            ],
            'answerVariable': 'place',
          },
          ctx);
      await h.handle(node, state);
      await h.handleResponse('I live in Paris', node, state);
      expect(ctx.calls.single['path'], 'ai/extract');
      expect(state.getAnswer('city'), 'Paris');
    });
  });

  test('the payment step is a gate: typed text does not get past it (#30)', () async {
    final h = _handler('payment-node');
    final ctx = _Ctx(replies: {
      'payment/session': {'url': 'https://checkout.stripe.com/c/pay/x', 'sessionId': 'cs_1', 'amount': 1250, 'currency': 'usd'}
    });
    final node = _node('payment-node', {'questionText': '<p>Pay</p>', 'amount': 12.5, 'currency': 'usd'}, ctx);
    await h.handle(node, state);
    final r = await h.handleResponse('I paid, honest', node, state)!;
    expect(r, isNot(isA<ProceedResult>()));
  });

  group('a live chat ends: the post-chat survey (#74)', () {
    HumanHandoverNodeHandler handover() => _handler('human-handover-node') as HumanHandoverNodeHandler;
    const questions = [
      {'id': 'q1', 'questionText': 'How did we do?', 'answerVariable': 'text'},
    ];

    test('asked when the builder switched enablePostChatSurveyQuestions on', () {
      final r = handover().onChatEnded('n1', {'enablePostChatSurveyQuestions': true, 'postChatSurveyQuestions': questions});
      final ui = (r as DisplayUIResult).uiState as HumanHandoverUIState;
      expect(ui.state, HandoverState.postChatSurvey);
      expect(ui.preChatQuestions!.single.questionText, 'How did we do?');
    });

    test('the older enablePostChatSurvey still counts, as in the Android SDK', () {
      expect(handover().onChatEnded('n1', {'enablePostChatSurvey': true, 'postChatSurveyQuestions': questions}), isA<DisplayUIResult>());
    });

    test('not asked when it is off, or with no questions', () {
      expect(handover().onChatEnded('n1', {'enablePostChatSurveyQuestions': false, 'postChatSurveyQuestions': questions}),
          isA<ProceedResult>());
      expect(handover().onChatEnded('n1', {'enablePostChatSurveyQuestions': true, 'postChatSurveyQuestions': []}), isA<ProceedResult>());
    });
  });
}
