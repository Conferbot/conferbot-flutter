import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/core/agent/agent_bot.dart';
import 'package:conferbot_flutter/src/models/message.dart';
import 'package:conferbot_flutter/src/utils/chat_markdown.dart';

void main() {
  group('agent bots', () {
    test('reads agentBot only when it is well formed', () {
      expect(AgentBotParser.parseAgentBot({}), isNull);
      expect(AgentBotParser.parseAgentBot({'agentBot': null}), isNull);
      expect(AgentBotParser.parseAgentBot({'agentBot': {'displayName': 'x'}}), isNull);
      final bot = AgentBotParser.parseAgentBot({
        'name': 'Shop',
        'agentBot': {
          'agentId': 'a1',
          'greeting': ' Hi there ',
          'starters': ['Pricing?', 'pricing?', '', {'text': 'Refunds'}],
          'avatar': 'https://x/a.png',
        },
      });
      expect(bot, const AgentBot(agentId: 'a1', displayName: 'Shop', greeting: 'Hi there', starters: ['Pricing?', 'Refunds'], avatar: 'https://x/a.png'));
      expect(bot!.agentDetailsId, 'ai-agent-a1');
    });

    test('knows an AI agent from a person, and decodes one without an email', () {
      expect(AgentBotParser.isAIAgent({'isAIAgent': true}), isTrue);
      expect(AgentBotParser.isAIAgent({'_id': 'ai-agent-x'}), isTrue);
      expect(AgentBotParser.isAIAgent({'_id': '64f0', 'name': 'Sam'}), isFalse);
      final details = AgentDetails.fromJson({'_id': 'ai-agent-a1', 'name': 'Ava'});
      expect(details.isAIAgent, isTrue);
      expect(details.email, '');
    });

    test('uses only the agent\'s own handover, never a form before it', () {
      final nodes = <Map<String, dynamic>>[
        {'id': 'w', 'type': 'welcome-node'},
        {'id': 'h1', 'type': 'human-handover-node', 'data': {'assignedAIAgents': ['other']}},
        {'id': 'h2', 'type': 'human-handover-node', 'data': {'assignedAIAgents': ['a1'], 'enablePreChatQuestions': true, 'handoverMessage': 'wait', 'priority': 'high'}},
      ];
      final shell = AgentBotParser.agentShellNodes(nodes, 'a1');
      expect(shell.welcome?['id'], 'w');
      expect(shell.handover?['id'], 'h2');
      expect(AgentBotParser.agentShellNodes(nodes.sublist(0, 2), 'a1').handover, isNull);
      final data = AgentBotParser.agentHandoverData(Map<String, dynamic>.from(shell.handover!['data'] as Map), 'a1');
      expect(data['assignedAIAgents'], ['a1']);
      expect(data['handoverMessage'], '');
      expect(data['enablePreChatQuestions'], false);
      expect(data['priority'], 'high');
    });

    test('knows when the AI is still answering', () {
      expect(AgentBotParser.isAgentAIActive([]), isTrue);
      expect(AgentBotParser.isAgentAIActive(['agent-left-chat']), isFalse);
      expect(AgentBotParser.isAgentAIActive(['ai-agent-inactive-close', 'ai-agent-resumed']), isTrue);
    });

    test('cleans sources, buttons and cards like the web widget', () {
      final sources = AgentBotParser.normalizeSources([
        {'title': 'Pricing', 'url': 'https://www.acme.com/pricing'},
        {'title': 'dup', 'url': 'https://www.acme.com/pricing'},
        {'title': 'bad', 'url': 'javascript:alert(1)'},
        {'title': 'Refunds', 'articleId': '0123456789abcdef01234567'},
        {'url': 'https://acme.com/a'},
        {'url': 'https://acme.com/b'},
      ]);
      expect(sources.map((s) => s.title).toList(), ['Pricing', 'Refunds', 'acme.com']);
      expect(AgentBotParser.sourceHost('https://www.conferbot.com/pricing'), 'conferbot.com');
      expect(
        AgentBotParser.answerActionsOf([
          {'label': 'See pricing', 'url': 'https://a.co/p'},
          {'label': 'x', 'url': 'ftp://a'},
          {'label': 'Again', 'url': 'https://a.co/p'},
        ]),
        [const AnswerAction('See pricing', 'https://a.co/p')],
      );
      expect(AgentBotParser.answerCardOf({'rows': [['Pro', r'$49']]}), isNull);
      final card = AgentBotParser.answerCardOf({'title': 'Plans', 'rows': [['Pro', r'$49'], ['Team', 99]], 'url': 'http://insecure'})!;
      expect(card.rows, [const CardRow('Pro', r'$49'), const CardRow('Team', '99')]);
      expect(card.url, isNull);
      final result = AgentBotParser.resultCardOf({'title': 'Order', 'status': 'In transit', 'tone': 'weird', 'link': {'url': 'https://t.co/1'}})!;
      expect(result.tone, 'neutral');
      expect(result.linkLabel, 'Open');
      final request = AgentBotParser.actionRequestOf({'token': 't', 'name': 'Cancel order', 'summary': [{'label': 'Order', 'value': 1042}, {'nope': 1}]})!;
      expect(request.summary, [const CardRow('Order', '1042')]);
      expect(AgentBotParser.actionRequestOf({'name': 'x'}), isNull);
      expect(AgentBotParser.followUpsOf(['a', '', 3, 'b', 'c', 'd']), ['a', 'b', 'c']);
    });

    test('keeps only drawable rich messages, and they survive the round trip', () {
      expect(AgentBotParser.safeRich({'kind': 'quick_replies', 'options': ['Yes']}), isNull);
      final quick = AgentBotParser.safeRich({'kind': 'quick_replies', 'text': 'Pick', 'options': ['Yes', 'No']});
      expect(quick, isA<RichQuickReplies>());
      final card = AgentBotParser.safeRich({'kind': 'card', 'title': 'Pro', 'imageUrl': 'http://x', 'button': {'label': 'Buy', 'url': 'https://b'}}) as RichCard;
      expect(card.imageUrl, isNull);
      expect(card.buttonUrl, 'https://b');
      expect(AgentBotParser.safeRich({'kind': 'video'}), isNull);
      final record = AgentRichMessageRecord(id: 'r1', time: DateTime(2026), rich: card, answered: 'Buy');
      final back = RecordItem.fromJson(record.toJson()) as AgentRichMessageRecord;
      expect((back.rich as RichCard).buttonLabel, 'Buy');
      expect(back.answered, 'Buy');
    });

    test('extras only on AI replies, only sources on a fallback, and they persist', () {
      expect(AgentBotParser.aiReplyExtrasOf({'agentDetails': {'_id': 'u1'}, 'sources': [{'url': 'https://a.co'}]}), isNull);
      const ai = {'_id': 'ai-agent-a1', 'isAIAgent': true};
      final fallback = AgentBotParser.aiReplyExtrasOf({'agentDetails': ai, 'isFallback': true, 'actions': [{'label': 'x', 'url': 'https://a.co'}]})!;
      expect(fallback.isFallback, isTrue);
      expect(fallback.actions, isEmpty);
      final reply = AgentBotParser.aiReplyExtrasOf({
        'agentDetails': ai,
        'actions': [{'label': 'Go', 'url': 'https://a.co'}],
        'sources': [{'title': 'Pricing', 'url': 'https://a.co/p'}],
      })!;
      final message = AgentMessageRecord(
        id: '0123456789abcdef01234567',
        time: DateTime(2026),
        text: 'Hi',
        agentDetails: AgentDetails.fromJson(Map<String, dynamic>.from(ai)..['name'] = 'Ava'),
        extras: reply,
        feedback: const AnswerFeedback(false, 'outdated'),
      );
      final back = RecordItem.fromJson(message.toJson()) as AgentMessageRecord;
      expect(back.extras!.actions, [const AnswerAction('Go', 'https://a.co')]);
      expect(back.extras!.sources.single.title, 'Pricing');
      expect(back.feedback!.reason, 'outdated');
      expect(back.agentDetails.isAIAgent, isTrue);
    });

    test('quick actions, ratings and goals', () {
      final actions = AgentBotParser.quickActionsOf({
        'chatQuickActions': [
          {'label': 'Book a demo', 'url': 'https://cal.com/x'},
          {'label': 'Mail', 'url': 'mailto:a@b.co'},
          {'label': 'x', 'url': 'javascript:1'},
        ],
      });
      expect(actions.map((a) => a.label).toList(), ['Book a demo', 'Mail']);
      expect(AgentBotParser.answerFeedbackOn({'hideAnswerFeedback': true}), isFalse);
      expect(AgentBotParser.answerFeedbackOn(null), isTrue);
      expect(AgentBotParser.canRate('0123456789abcdef01234567'), isTrue);
      expect(AgentBotParser.canRate('agent-greeting-s1'), isFalse);
      expect(AgentBotParser.conversionEventOf('Book a demo'), 'demo_booked');
    });
  });

  group('chat markdown', () {
    test('turns the inbox HTML into markdown', () {
      expect(ChatMarkdown.htmlToMarkdown('<p>Hi <strong>Sam</strong></p><p>See <a href="https://a.co/x">this</a> &amp; that</p>'),
          'Hi **Sam**\n\nSee [this](https://a.co/x) & that');
      expect(ChatMarkdown.htmlToMarkdown('<a href="javascript:alert(1)">click</a>'), 'click');
      expect(ChatMarkdown.htmlToMarkdown(r'<p>**Pro** is $49</p>'), r'**Pro** is $49');
    });

    test('parses inline runs', () {
      expect(ChatMarkdown.parseInline('a **b** _c_ `d` [e](https://e.co) https://f.co/x.'), const [
        ChatInline(InlineKind.plain, 'a '),
        ChatInline(InlineKind.bold, 'b'),
        ChatInline(InlineKind.plain, ' '),
        ChatInline(InlineKind.italic, 'c'),
        ChatInline(InlineKind.plain, ' '),
        ChatInline(InlineKind.code, 'd'),
        ChatInline(InlineKind.plain, ' '),
        ChatInline(InlineKind.link, 'e', 'https://e.co'),
        ChatInline(InlineKind.plain, ' '),
        ChatInline(InlineKind.link, 'https://f.co/x', 'https://f.co/x'),
        ChatInline(InlineKind.plain, '.'),
      ]);
      expect(ChatMarkdown.parseInline('snake_case_name stays'), const [ChatInline(InlineKind.plain, 'snake_case_name stays')]);
      expect(ChatMarkdown.parseInline('[x](javascript:1)'), const [ChatInline(InlineKind.plain, 'x')]);
    });

    test('parses lists and paragraphs', () {
      final blocks = ChatMarkdown.parse('## Plans\nWe have:\n- Pro\n2. Team\n\nBye');
      expect(blocks.map((b) => b.kind).toList(), [BlockKind.paragraph, BlockKind.bullet, BlockKind.numbered, BlockKind.paragraph]);
      expect(ChatMarkdown.plainText(blocks), 'Plans\nWe have:\n• Pro\n2. Team\nBye');
    });
  });
}
