/// AI agent bots (Agent Studio): bots with no flow of their own, answered by
/// an AI agent from the first message.
///
/// The server marks one with `chatbotData.agentBot` on fetched-chatbot-data
/// (embed-server chatbotController getChatbotElementsSocket). Such a bot
/// still ships a one-node shell flow (welcome -> handover to the agent) for
/// older clients, but running it as-is stages a handover the visitor should
/// never see. With agentBot set the SDK opens straight into the agent chat
/// and reuses the handover socket path silently underneath (silentStart),
/// as the web widget does (conferbot-widget index.ts _startAgentBotChat,
/// ts/chat/agentShell.ts).
///
/// Also here: the AI reply's extras as the server sends them on
/// agent-message (sources, follow-ups, action buttons, cards, an action to
/// confirm), cleaned the same way the web widget cleans them. Pure Dart.
library;

class AgentBot {
  final String agentId;
  final String displayName;
  final String greeting;

  /// Suggested first questions, shown as chips under the greeting.
  final List<String> starters;
  final String? avatar;

  const AgentBot({
    required this.agentId,
    required this.displayName,
    required this.greeting,
    required this.starters,
    this.avatar,
  });

  /// The agent as the chat presents it - the id the server sends in agentDetails.
  String get agentDetailsId => 'ai-agent-$agentId';

  @override
  bool operator ==(Object other) =>
      other is AgentBot &&
      other.agentId == agentId &&
      other.displayName == displayName &&
      other.greeting == greeting &&
      _listEquals(other.starters, starters) &&
      other.avatar == avatar;

  @override
  int get hashCode => Object.hash(agentId, displayName, greeting, avatar);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class AgentSource {
  final String title;
  final String? url;
  final String? articleId;
  final String? snippet;
  const AgentSource({required this.title, this.url, this.articleId, this.snippet});

  Map<String, dynamic> toJson() => {
        'title': title,
        if (url != null) 'url': url,
        if (articleId != null) 'articleId': articleId,
        if (snippet != null) 'snippet': snippet,
      };
}

class AnswerAction {
  final String label;
  final String url;
  const AnswerAction(this.label, this.url);

  Map<String, dynamic> toJson() => {'label': label, 'url': url};

  @override
  bool operator ==(Object other) => other is AnswerAction && other.label == label && other.url == url;

  @override
  int get hashCode => Object.hash(label, url);
}

class CardRow {
  final String label;
  final String value;
  const CardRow(this.label, this.value);

  @override
  bool operator ==(Object other) => other is CardRow && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);
}

class AnswerCard {
  final String? title;
  final List<CardRow> rows;
  final String? note;
  final String? url;
  const AnswerCard({this.title, required this.rows, this.note, this.url});

  Map<String, dynamic> toJson() => {
        'title': title,
        'rows': rows.map((r) => [r.label, r.value]).toList(),
        'note': note,
        'url': url,
      };
}

class ResultCard {
  final String title;
  final String? status;

  /// done | moving | problem | neutral
  final String tone;
  final List<CardRow> rows;
  final String? linkUrl;
  final String? linkLabel;
  const ResultCard({
    required this.title,
    this.status,
    required this.tone,
    required this.rows,
    this.linkUrl,
    this.linkLabel,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'status': status,
        'tone': tone,
        'rows': rows.map((r) => [r.label, r.value]).toList(),
        'link': linkUrl != null ? {'url': linkUrl, 'label': linkLabel} : null,
      };
}

class ActionRequest {
  final String token;
  final String name;
  final List<CardRow> summary;
  const ActionRequest({required this.token, required this.name, required this.summary});
}

/// An article, quick replies or a card from the agent (agent-message-rich).
sealed class RichEntry {
  const RichEntry();
}

class RichArticle extends RichEntry {
  final String articleId;
  final String title;
  final String snippet;
  final String? url;
  const RichArticle({required this.articleId, required this.title, required this.snippet, this.url});
}

class RichQuickReplies extends RichEntry {
  final String text;
  final List<String> options;
  const RichQuickReplies({required this.text, required this.options});
}

class RichCard extends RichEntry {
  final String title;
  final String description;
  final String? imageUrl;
  final String? buttonLabel;
  final String? buttonUrl;
  const RichCard({required this.title, required this.description, this.imageUrl, this.buttonLabel, this.buttonUrl});
}

/// What an AI reply carries besides its text.
class AIReplyExtras {
  final List<AgentSource> sources;
  final List<AnswerAction> actions;
  final AnswerCard? card;
  final ResultCard? resultCard;
  final ActionRequest? actionRequest;
  final bool isFallback;

  const AIReplyExtras({
    this.sources = const [],
    this.actions = const [],
    this.card,
    this.resultCard,
    this.actionRequest,
    this.isFallback = false,
  });

  bool get isEmpty => sources.isEmpty && actions.isEmpty && card == null && resultCard == null && actionRequest == null;

  /// The lasting part, in the server's shapes (what [AgentBotParser.aiReplyExtrasOf]
  /// reads back on restore). An action awaiting confirmation is not kept.
  Map<String, dynamic> toJson() => {
        'agentDetails': {'isAIAgent': true},
        if (sources.isNotEmpty) 'sources': sources.map((s) => s.toJson()).toList(),
        if (actions.isNotEmpty) 'actions': actions.map((a) => a.toJson()).toList(),
        if (card != null) 'card': card!.toJson(),
        if (resultCard != null) 'resultCard': resultCard!.toJson(),
        if (isFallback) 'isFallback': true,
      };
}

/// A visitor's vote on one AI answer.
class AnswerFeedback {
  final bool helpful;
  final String? reason;
  const AnswerFeedback(this.helpful, [this.reason]);

  Map<String, dynamic> toJson() => {'helpful': helpful, if (reason != null) 'reason': reason};

  static AnswerFeedback? fromJson(dynamic raw) =>
      raw is Map && raw['helpful'] is bool ? AnswerFeedback(raw['helpful'] as bool, raw['reason'] as String?) : null;
}

class AgentBotParser {
  AgentBotParser._();

  static const defaultAgentName = 'AI Assistant';
  static const defaultGreeting = 'Hi! How can I help you today?';
  static const maxSources = 3;
  static const feedbackReasons = [
    ('wrong', 'Wrong'),
    ('outdated', 'Outdated'),
    ('unanswered', "Didn't answer"),
    ('other', 'Other'),
  ];

  static final _objectId = RegExp(r'^[a-f0-9]{24}$', caseSensitive: false);
  static final _httpUrl = RegExp(r'''^https?://[^\s"'<>]+$''', caseSensitive: false);
  static final _httpsUrl = RegExp(r'''^https://[^\s"'<>]+$''', caseSensitive: false);

  static String _clean(dynamic v, int max) {
    String s;
    if (v is String) {
      s = v.replaceAll(RegExp(r'\s+'), ' ').trim();
    } else if (v is num) {
      s = v == v.roundToDouble() && v.abs() < 1e15 ? v.toInt().toString() : v.toString();
    } else {
      return '';
    }
    return s.length > max ? s.substring(0, max) : s;
  }

  static String? _http(dynamic v) {
    final s = v is String ? v.trim() : '';
    return _httpUrl.hasMatch(s) ? s : null;
  }

  static String? _https(dynamic v) {
    final s = v is String ? v.trim() : '';
    return _httpsUrl.hasMatch(s) ? s : null;
  }

  static List<dynamic> _list(dynamic v) => v is List ? v : const [];
  static Map<String, dynamic>? _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
  static String? _nonEmpty(String s) => s.isEmpty ? null : s;
  static T? _first<T>(Iterable<T> items) => items.isEmpty ? null : items.first;

  /// The agent bot config from chatbotData, or null for every flow bot.
  static AgentBot? parseAgentBot(Map<String, dynamic>? chatbotData) {
    final a = _map(chatbotData?['agentBot']);
    final agentId = a?['agentId']?.toString() ?? '';
    if (a == null || agentId.trim().isEmpty) return null;
    final seen = <String>{};
    final starters = _list(a['starters'])
        .map((s) => _clean(s is String ? s : _map(s)?['text'], 80))
        .where((s) => s.isNotEmpty && seen.add(s.toLowerCase()))
        .take(4)
        .toList();
    var name = _clean(a['displayName'], 60);
    if (name.isEmpty) name = _clean(chatbotData?['name'], 60);
    if (name.isEmpty) name = defaultAgentName;
    final avatar = a['avatar'] is String && (a['avatar'] as String).isNotEmpty ? a['avatar'] as String : null;
    return AgentBot(
      agentId: agentId,
      displayName: name,
      greeting: a['greeting'] is String ? (a['greeting'] as String).trim() : '',
      starters: starters,
      avatar: avatar,
    );
  }

  /// The agentDetails map the server sends for this agent.
  static Map<String, dynamic> agentDetailsOf(AgentBot bot) =>
      {'_id': bot.agentDetailsId, 'name': bot.displayName, 'avatar': bot.avatar ?? '', 'isAIAgent': true};

  /// Is this agentDetails an AI agent rather than a person?
  static bool isAIAgent(Map<String, dynamic>? details) {
    if (details == null) return false;
    if (details['isAIAgent'] == true) return true;
    return details['_id']?.toString().startsWith('ai-agent-') == true;
  }

  static bool isAgentShellHandover(Map<String, dynamic> node, String agentId) {
    if (node['type'] != 'human-handover-node') return false;
    return _list(_map(node['data'])?['assignedAIAgents']).map((e) => e.toString()).contains(agentId);
  }

  /// The shell's welcome and handover nodes. A bot switched from a flow keeps
  /// the owner's flow too, so only the handover assigned to this agent counts.
  static ({Map<String, dynamic>? welcome, Map<String, dynamic>? handover}) agentShellNodes(
      List<Map<String, dynamic>> nodes, String agentId) {
    final handover = _first(nodes.where((n) => isAgentShellHandover(n, agentId)));
    if (handover == null) return (welcome: null, handover: null);
    return (welcome: _first(nodes.where((n) => n['type'] == 'welcome-node')), handover: handover);
  }

  /// Handover data for the agent chat: never a form, message or wait before it.
  static Map<String, dynamic> agentHandoverData(Map<String, dynamic>? shellData, String agentId) => {
        'assignmentType': 'auto',
        'assignedAgents': <String>[],
        ...?shellData,
        'assignedAIAgents': [agentId],
        'handoverMessage': '',
        'enablePreChatQuestions': false,
        'preChatQuestions': <dynamic>[],
      };

  /// Is the AI still answering? The latest word wins.
  static bool isAgentAIActive(List<String?> recordTypes) {
    for (final type in recordTypes.reversed) {
      if (type == 'ai-agent-resumed') return true;
      if (type == 'agent-left-chat' || type == 'agent-chat-ended' || type == 'ai-agent-inactive-close') return false;
    }
    return true;
  }

  /// "https://www.conferbot.com/pricing" -> "conferbot.com"
  static String sourceHost(String? url) {
    final m = RegExp(r'^https?://([^/?#:]+)', caseSensitive: false).firstMatch(url ?? '');
    if (m == null) return '';
    final host = m.group(1)!.toLowerCase();
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  /// Sources an AI reply was grounded in: http(s) pages or help articles, at most three.
  static List<AgentSource> normalizeSources(dynamic raw) {
    final seen = <String>{};
    final out = <AgentSource>[];
    for (final item in _list(raw)) {
      final m = _map(item);
      if (m == null) continue;
      final articleId = m['articleId'] is String && _objectId.hasMatch(m['articleId'] as String) ? m['articleId'] as String : null;
      final url = (m['url'] ?? m['sourceUrl'])?.toString().trim() ?? '';
      final key = articleId != null ? 'article:$articleId' : url;
      if ((articleId == null && !RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) || !seen.add(key)) continue;
      final snippet = _nonEmpty(_clean(m['snippet'] ?? m['description'] ?? m['excerpt'], 220));
      final title = _clean(m['title'], 160);
      out.add(articleId != null
          ? AgentSource(title: title.isEmpty ? 'Help article' : title, url: _http(url), articleId: articleId, snippet: snippet)
          : AgentSource(title: title.isEmpty ? sourceHost(url) : title, url: url, snippet: snippet));
      if (out.length >= maxSources) break;
    }
    return out;
  }

  /// The buttons under an answer: labelled, http(s), at most two, once each.
  static List<AnswerAction> answerActionsOf(dynamic raw) {
    final seen = <String>{};
    final out = <AnswerAction>[];
    for (final a in _list(raw)) {
      final m = _map(a);
      final url = _http(m?['url']);
      final label = _clean(m?['label'], 28);
      if (url == null || label.isEmpty || !seen.add(url)) continue;
      out.add(AnswerAction(label, url));
    }
    return out.take(2).toList();
  }

  static List<CardRow> _rows(dynamic raw, int max) => _list(raw)
      .whereType<List>()
      .where((r) => r.length >= 2)
      .map((r) => CardRow(_clean(r[0], 40), _clean(r[1], 60)))
      .where((r) => r.label.isNotEmpty && r.value.isNotEmpty)
      .take(max)
      .toList();

  /// Facts from the knowledge as a card: a title, two to six rows, a note, a link.
  static AnswerCard? answerCardOf(dynamic raw) {
    final m = _map(raw);
    if (m == null) return null;
    final rows = _rows(m['rows'], 6);
    if (rows.length < 2) return null;
    return AnswerCard(title: _nonEmpty(_clean(m['title'], 60)), rows: rows, note: _nonEmpty(_clean(m['note'], 120)), url: _https(m['url']));
  }

  /// What an action did ("Order #1042 · In transit"), as a card.
  static ResultCard? resultCardOf(dynamic raw) {
    final m = _map(raw);
    if (m == null) return null;
    final rows = _rows(m['rows'], 5);
    final status = _nonEmpty(_clean(m['status'], 30));
    if (rows.isEmpty && status == null) return null;
    final tone = const ['done', 'moving', 'problem', 'neutral'].contains(m['tone']) ? m['tone'] as String : 'neutral';
    final link = _map(m['link']);
    final url = _https(link?['url']);
    final label = _clean(link?['label'], 24);
    return ResultCard(
      title: _nonEmpty(_clean(m['title'], 50)) ?? 'Done',
      status: status,
      tone: tone,
      rows: rows,
      linkUrl: url,
      linkLabel: url == null ? null : (label.isEmpty ? 'Open' : label),
    );
  }

  /// An action the AI is about to take, for the visitor to confirm.
  static ActionRequest? actionRequestOf(dynamic raw) {
    final m = _map(raw);
    final token = m?['token'];
    final name = m?['name'];
    if (token is! String || token.isEmpty || name is! String) return null;
    final summary = _list(m!['summary'])
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .where((l) => l['label'] is String && l.containsKey('value'))
        .take(8)
        .map((l) {
      final label = l['label'] as String;
      final value = _clean(l['value'], 120);
      return CardRow(label.length > 40 ? label.substring(0, 40) : label, value.isEmpty ? '${l['value']}' : value);
    }).toList();
    return ActionRequest(token: token, name: name.length > 80 ? name.substring(0, 80) : name, summary: summary);
  }

  /// What the visitor may ask next: at most three short questions.
  static List<String> followUpsOf(dynamic raw) =>
      _list(raw).whereType<String>().map((q) => _clean(q, 120)).where((q) => q.isNotEmpty).take(3).toList();

  /// An agent's rich message as it may be drawn, or null.
  static RichEntry? safeRich(dynamic raw) {
    final m = _map(raw);
    if (m == null) return null;
    switch (m['kind']) {
      case 'article':
        final title = _clean(m['title'], 80);
        if (title.isEmpty) return null;
        return RichArticle(articleId: _clean(m['articleId'], 40), title: title, snippet: _clean(m['snippet'], 200), url: _https(m['url']));
      case 'quick_replies':
        final options = _list(m['options']).map((o) => _clean(o, 40)).where((o) => o.isNotEmpty).take(4).toList();
        if (options.length < 2) return null;
        return RichQuickReplies(text: _clean(m['text'], 300), options: options);
      case 'card':
        final title = _clean(m['title'], 80);
        if (title.isEmpty) return null;
        final button = _map(m['button']);
        final label = _clean(button?['label'], 30);
        final url = _https(button?['url']);
        final hasButton = label.isNotEmpty && url != null;
        return RichCard(
          title: title,
          description: _clean(m['description'], 300),
          imageUrl: _https(m['imageUrl']),
          buttonLabel: hasButton ? label : null,
          buttonUrl: hasButton ? url : null,
        );
    }
    return null;
  }

  /// A rich entry back in its server shape (record and persistence).
  static Map<String, dynamic> richToJson(RichEntry rich) => switch (rich) {
        RichArticle r => {'kind': 'article', 'articleId': r.articleId, 'title': r.title, 'snippet': r.snippet, 'url': r.url},
        RichQuickReplies r => {'kind': 'quick_replies', 'text': r.text, 'options': r.options},
        RichCard r => {
            'kind': 'card',
            'title': r.title,
            'description': r.description,
            'imageUrl': r.imageUrl,
            if (r.buttonLabel != null) 'button': {'label': r.buttonLabel, 'url': r.buttonUrl},
          },
      };

  /// The owner's quick actions above the composer: labelled, safe links, at most three.
  static List<AnswerAction> quickActionsOf(Map<String, dynamic>? customizations) {
    final out = <AnswerAction>[];
    for (final a in _list(customizations?['chatQuickActions'])) {
      final m = _map(a);
      final label = _clean(m?['label'], 30);
      final raw = m?['url']?.toString().trim() ?? '';
      final url = _http(raw) ?? (RegExp(r'^(mailto|tel):', caseSensitive: false).hasMatch(raw) ? raw : null);
      if (label.isEmpty || url == null) continue;
      out.add(AnswerAction(label, url));
    }
    return out.take(3).toList();
  }

  /// "Helpful?" under AI answers unless the owner turned it off.
  static bool answerFeedbackOn(Map<String, dynamic>? customizations) => customizations?['hideAnswerFeedback'] != true;

  /// Only an AI answer stored under its server id can be rated.
  static bool canRate(String? messageId) => messageId != null && _objectId.hasMatch(messageId);

  /// The conversion a link stands for, in the analytics vocabulary.
  static String conversionEventOf(String label, [String url = '']) {
    final t = '$label $url'.toLowerCase();
    if (RegExp(r'demo|book|meeting|call|calendly').hasMatch(t)) return 'demo_booked';
    if (RegExp(r'trial|sign ?up|register|get started|start free').hasMatch(t)) return 'signup';
    if (RegExp(r'buy|purchase|checkout|order|cart').hasMatch(t)) return 'purchase';
    if (RegExp(r'contact|email|quote').hasMatch(t)) return 'contact_form';
    if (RegExp(r'download').hasMatch(t)) return 'download';
    return 'custom';
  }

  /// The extras of an agent-message payload; null for a person's message.
  static AIReplyExtras? aiReplyExtrasOf(Map<String, dynamic> data) {
    if (!isAIAgent(_map(data['agentDetails']))) return null;
    final sources = normalizeSources(data['sources'] ?? data['citations']);
    if (data['isFallback'] == true) return AIReplyExtras(sources: sources, isFallback: true);
    return AIReplyExtras(
      sources: sources,
      actions: answerActionsOf(data['actions']),
      card: answerCardOf(data['card']),
      resultCard: resultCardOf(data['resultCard']),
      actionRequest: actionRequestOf(data['actionRequest']),
    );
  }
}
