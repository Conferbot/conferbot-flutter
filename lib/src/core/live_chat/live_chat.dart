/// Live chat around a person or the AI, as the web widget shows it: where the
/// visitor stands in the queue, the "Sent / Delivered / Seen" line under
/// their latest message, an agent's translated message, the cards that keep
/// a conversation going when nobody can join (leave a message, an email for
/// the reply), and the post-chat rating. The shapes are the embed-server's
/// (queueService, readReceipts, liveTranslation, aiFallback,
/// handoverHandler). Pure: works on the maps the socket JSON decodes to.
library;

import 'package:intl/intl.dart';

import '../i18n/i18n.dart';

class QueueStatus {
  final String status;
  final int? position;
  final int? ahead;
  final int? agentsOnline;
  final String? estimateLabel;

  /// The server's estimate bucket (under_minute, about_1 ... longer), worded here.
  final String? estimateBucket;

  /// The routed team's usual first reply (embed-server replyTimeService):
  /// `{bucket, phrase, wait}`.
  final Map<String, dynamic>? typical;

  const QueueStatus({
    required this.status,
    this.position,
    this.ahead,
    this.agentsOnline,
    this.estimateLabel,
    this.estimateBucket,
    this.typical,
  });

  @override
  bool operator ==(Object other) =>
      other is QueueStatus &&
      other.status == status &&
      other.position == position &&
      other.ahead == ahead &&
      other.agentsOnline == agentsOnline &&
      other.estimateLabel == estimateLabel &&
      other.estimateBucket == estimateBucket &&
      _sameMap(other.typical, typical);

  static bool _sameMap(Map? a, Map? b) =>
      a == null || b == null ? a == b : a.length == b.length && a.keys.every((k) => b.containsKey(k) && a[k] == b[k]);

  @override
  int get hashCode => Object.hash(status, position, ahead, agentsOnline, estimateLabel, estimateBucket, typical?.length);
}

class HandoverWaiting {
  final bool offline;
  final String reason;
  final String? backAt;
  final bool askEmail;
  final String? email;

  const HandoverWaiting({required this.offline, required this.reason, this.backAt, required this.askEmail, this.email});

  HandoverWaiting copyWith({bool? askEmail, String? email}) =>
      HandoverWaiting(offline: offline, reason: reason, backAt: backAt, askEmail: askEmail ?? this.askEmail, email: email ?? this.email);
}

class AgentTranslation {
  final String from;
  final String to;
  final String original;

  const AgentTranslation({required this.from, required this.to, required this.original});

  Map<String, dynamic> toJson() => {'from': from, 'to': to, 'original': original};

  static AgentTranslation? fromJson(dynamic raw) => LiveChat.agentTranslationOf({'translation': raw});

  @override
  bool operator ==(Object other) => other is AgentTranslation && other.from == from && other.to == to && other.original == original;

  @override
  int get hashCode => Object.hash(from, to, original);
}

class ReceiptMarks {
  final String deliveredMessageId;
  final String seenMessageId;
  const ReceiptMarks({this.deliveredMessageId = '', this.seenMessageId = ''});
}

enum ReceiptState { sent, delivered, seen }

class VisitorReceipt {
  final String id;
  final ReceiptState state;
  const VisitorReceipt(this.id, this.state);

  @override
  bool operator ==(Object other) => other is VisitorReceipt && other.id == id && other.state == state;

  @override
  int get hashCode => Object.hash(id, state);
}

/// Post-chat rating: from the bot's csatConfig; on only with enabled = true.
class CsatConfig {
  final String ratingType;
  final String titleText;
  final String subtitleText;
  final String thankYouText;
  final bool showFeedbackInput;
  final String feedbackPlaceholder;

  const CsatConfig({
    required this.ratingType,
    required this.titleText,
    required this.subtitleText,
    required this.thankYouText,
    required this.showFeedbackInput,
    required this.feedbackPlaceholder,
  });
}

/// A record entry as the receipt logic needs it.
class LiveEntry {
  final String id;
  final String kind;
  const LiveEntry(this.id, this.kind);
}

class LiveChat {
  LiveChat._();

  /// What "Talk to a person" sends, in the active language (web chat.talkToPersonAsk).
  static String get talkToPersonAsk => t('chat.talkToPersonAsk');
  static const queuePoll = Duration(seconds: 20);

  static int? _int(dynamic v) => v is int ? v : (v is num && v.isFinite ? v.toInt() : null);

  static String? _str(dynamic v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  /// queue-status as the visitor sees it, or null when they are not waiting.
  static QueueStatus? queueStatusOf(dynamic raw) {
    if (raw is! Map) return null;
    final status = raw['status'];
    if (status != 'waiting' && status != 'busy') return null;
    final estimate = raw['estimate'];
    return QueueStatus(
      status: status as String,
      position: _int(raw['position']),
      ahead: _int(raw['ahead']),
      agentsOnline: _int(raw['agentsOnline']),
      estimateLabel: estimate is Map ? _str(estimate['label']) : null,
      estimateBucket: estimate is Map && estimate['bucket'] is String ? estimate['bucket'] as String : null,
      typical: raw['typical'] is Map ? Map<String, dynamic>.from(raw['typical'] as Map) : null,
    );
  }

  // The server's estimate buckets (embed-server liveChat/queueService),
  // worded here (web queueCard.ts ESTIMATE_WORDS).
  static const _estimateWords = {
    'under_minute': 'queue.estimate.underMinute',
    'about_1': 'queue.estimate.about1',
    'about_2': 'queue.estimate.about2',
    'about_3': 'queue.estimate.about3',
    'few': 'queue.estimate.few',
    'longer': 'queue.estimate.longer',
  };

  /// The wait card's lines under the headline (web queueCard.ts
  /// estimateText and the card's third line): the live estimate in the
  /// visitor's language, else the usual wait ("Typical wait: a few
  /// minutes", ReplyTime.typicalWait), else a calm promise; then the usual
  /// wait again under a live estimate, when it says something else.
  static ({String estimate, String typical}) waitCardLines(QueueStatus? q, String? typical) {
    String estimate;
    if (q != null && q.status == 'waiting' && q.estimateLabel != null) {
      final key = _estimateWords[q.estimateBucket];
      estimate = key != null ? t(key) : q.estimateLabel!;
    } else {
      estimate = typical ?? t('queue.soon');
    }
    return (estimate: estimate, typical: typical != null && estimate != typical ? typical : '');
  }

  /// "1st", "2nd", "3rd", "11th"
  static String ordinal(int n) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  /// "You're next in line", "You're 3rd in line", "Connecting you to the team".
  static String queueLine(QueueStatus? q) {
    final p = q?.position;
    // In the active language (web queueCard.ts positionText: queue.*; {ord} is English's "3rd").
    if (p == 1) return t('queue.next');
    if (p != null && p > 1) return t('queue.position', {'n': p, 'ord': ordinal(p)});
    return t('queue.connecting');
  }

  /// The server's label is already a phrase ("Under a minute", "About 2 min").
  static String queueSubline(QueueStatus? q) => q?.estimateLabel ?? t('queue.soon');

  /// handover-waiting: nobody could take the chat (the AI took it back).
  static HandoverWaiting? handoverWaitingOf(dynamic raw) {
    if (raw is! Map) return null;
    return HandoverWaiting(
      offline: raw['offline'] == true,
      reason: raw['reason'] == 'offline' ? 'offline' : 'busy',
      backAt: raw['backAt'] is String ? raw['backAt'] as String : null,
      askEmail: raw['askEmail'] == true,
      email: _str(raw['email']),
    );
  }

  /// The line on that card.
  static String handoverWaitingLine(HandoverWaiting w, {DateTime? now}) {
    final back = backAtLabel(w.backAt, now: now);
    final first = w.offline
        ? (back != null ? t('sdk.waiting.offlineBack', {'when': back}) : t('sdk.waiting.offline'))
        : t('sdk.waiting.busy');
    final second = w.email != null ? t('sdk.waiting.replyTo', {'email': w.email}) : t('sdk.waiting.leaveEmail');
    return '$first $second';
  }

  /// An agent message sent in the visitor's language: the original kept.
  static AgentTranslation? agentTranslationOf(dynamic data) {
    if (data is! Map) return null;
    final t = data['translation'];
    if (t is! Map) return null;
    final original = t['original'];
    final to = t['to'];
    if (original is! String || to is! String || original.trim().isEmpty) return null;
    return AgentTranslation(from: t['from']?.toString() ?? '', to: to, original: original);
  }

  static ReceiptMarks receiptMarksOf(dynamic raw) => ReceiptMarks(
        deliveredMessageId: raw is Map ? raw['deliveredMessageId']?.toString() ?? '' : '',
        seenMessageId: raw is Map ? raw['seenMessageId']?.toString() ?? '' : '',
      );

  static const _visitorKinds = {'user-live-message', 'user-live-message-file'};
  static const _agentKinds = {'agent-message', 'agent-message-file', 'agent-message-audio', 'agent-message-rich'};

  /// The line under the visitor's latest live message while it is the newest
  /// thing in the chat (an agent reply takes it away), or null. Only while a
  /// person is on the other end - an AI answers at once.
  static VisitorReceipt? visitorReceiptOf(List<LiveEntry> record, ReceiptMarks marks) {
    for (var i = record.length - 1; i >= 0; i--) {
      final r = record[i];
      if (_agentKinds.contains(r.kind)) return null;
      if (_visitorKinds.contains(r.kind)) {
        if (r.id.isEmpty) return null;
        final seenAt = marks.seenMessageId.isEmpty ? -1 : record.indexWhere((e) => e.id == marks.seenMessageId);
        final deliveredAt = marks.deliveredMessageId.isEmpty ? -1 : record.indexWhere((e) => e.id == marks.deliveredMessageId);
        final state = seenAt >= i ? ReceiptState.seen : (deliveredAt >= i ? ReceiptState.delivered : ReceiptState.sent);
        return VisitorReceipt(r.id, state);
      }
    }
    return null;
  }

  static String receiptLabel(ReceiptState s) => switch (s) {
        ReceiptState.seen => t('receipt.seen'),
        ReceiptState.delivered => t('receipt.delivered'),
        ReceiptState.sent => t('receipt.sent'),
      };

  /// The newest agent message id: what the visitor reports delivered / seen.
  static String latestAgentMessageId(List<LiveEntry> record) {
    for (var i = record.length - 1; i >= 0; i--) {
      if (_agentKinds.contains(record[i].kind)) return record[i].id;
    }
    return '';
  }

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static bool isEmail(String? v) => _email.hasMatch((v ?? '').trim());

  /// "9:00 AM" (same day) or "Friday 9:00 AM" from an ISO time; null when unknown.
  static String? backAtLabel(String? iso, {DateTime? now}) {
    if (iso == null) return null;
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return null;
    final n = (now ?? DateTime.now()).toLocal();
    final locale = I18n.intlLocale;
    final time = DateFormat.jm(locale).format(d);
    final sameDay = d.year == n.year && d.month == n.month && d.day == n.day;
    return sameDay ? time : '${DateFormat.EEEE(locale).format(d)} $time';
  }

  /// Visitor uploads in a live chat: on unless the owner turned them off.
  static bool visitorUploadsOn(Map<String, dynamic>? customizations) => customizations?['enableVisitorFileUpload'] != false;

  static CsatConfig? csatConfigOf(dynamic raw) {
    if (raw is! Map || raw['enabled'] != true) return null;
    const types = {'stars', 'thumbs', 'emoji', 'nps'};
    final type = types.contains(raw['ratingType']) ? raw['ratingType'] as String : 'stars';
    // The owner's words, else the web's (postChatRating.ts csat.*) in the visitor's language.
    String s(String field, String key, [List<String> stock = const []]) {
      final v = raw[field];
      return I18n.ownerTextOr(v is String ? v.trim() : v, key, stock);
    }

    return CsatConfig(
      ratingType: type,
      titleText: s('titleText', 'csat.title'),
      subtitleText: s('subtitleText', 'csat.subtitle'),
      thankYouText: s('thankYouText', 'csat.thanks'),
      showFeedbackInput: raw['showFeedbackInput'] != false,
      feedbackPlaceholder: s('feedbackPlaceholder', 'csat.placeholder', const ['Tell us more...']),
    );
  }

  /// submit-chat-rating payload for a rating of the given type (value: int, or bool for thumbs).
  static Map<String, dynamic> ratingPayload(String chatSessionId, String type, Object value, [String? feedback]) {
    final out = <String, dynamic>{'chatSessionId': chatSessionId, 'source': 'post_chat_survey'};
    switch (type) {
      case 'thumbs':
        out['thumbsUp'] = value == true;
        break;
      case 'nps':
        out['npsScore'] = value is num ? value.toInt() : 0;
        break;
      default:
        out['csatScore'] = value is num ? value.toInt() : 0;
    }
    final f = feedback?.trim();
    if (f != null && f.isNotEmpty) out['feedback'] = f.length > 1000 ? f.substring(0, 1000) : f;
    return out;
  }

  // "See original" / "See translation" in the visitor's language (the web
  // widget's list, ts/chat/translatedMessage.ts).
  static const _translationLabels = {
    'en': ['See original', 'See translation'],
    'es': ['Ver original', 'Ver traducción'],
    'fr': ["Voir l'original", 'Voir la traduction'],
    'de': ['Original anzeigen', 'Übersetzung anzeigen'],
    'pt': ['Ver original', 'Ver tradução'],
    'it': ['Vedi originale', 'Vedi traduzione'],
    'nl': ['Origineel bekijken', 'Vertaling bekijken'],
    'pl': ['Zobacz oryginał', 'Zobacz tłumaczenie'],
    'tr': ['Orijinali gör', 'Çeviriyi gör'],
    'ru': ['Показать оригинал', 'Показать перевод'],
    'uk': ['Показати оригінал', 'Показати переклад'],
    'ar': ['عرض النص الأصلي', 'عرض الترجمة'],
    'hi': ['मूल देखें', 'अनुवाद देखें'],
    'ja': ['原文を表示', '翻訳を表示'],
    'ko': ['원문 보기', '번역 보기'],
    'zh': ['查看原文', '查看翻译'],
    'id': ['Lihat asli', 'Lihat terjemahan'],
    'vi': ['Xem bản gốc', 'Xem bản dịch'],
    'th': ['ดูต้นฉบับ', 'ดูคำแปล'],
    'sv': ['Visa original', 'Visa översättning'],
  };

  static List<String> translationLabels(String? lang) {
    final key = (lang ?? '').toLowerCase().split(RegExp('[-_]')).first;
    return _translationLabels[key] ?? _translationLabels['en']!;
  }

  /// A file URL ready to open: the relative /media proxy on the API origin; never script / data URLs.
  static String? resolveMediaUrl(String? url, String origin) {
    final raw = (url ?? '').trim();
    if (raw.isEmpty) return null;
    if (RegExp(r'^(javascript|vbscript|data):', caseSensitive: false).hasMatch(raw.replaceAll(RegExp(r'\s'), ''))) return null;
    if (raw.startsWith('/')) return origin.replaceAll(RegExp(r'/+$'), '') + raw;
    return raw;
  }

  static bool isImageUrl(String? url, [String? mimeType]) =>
      (mimeType ?? '').startsWith('image/') ||
      RegExp(r'\.(png|jpe?g|gif|webp|heic|bmp)(\?|#|$)', caseSensitive: false).hasMatch(url ?? '');

  /// The name on a file row: the record's own, or the URL's last part.
  static String fileNameOf(String? own, String url) {
    final o = own?.trim();
    if (o != null && o.isNotEmpty) return o;
    final last = url.split(RegExp('[?#]')).first.split('/').last;
    String decoded;
    try {
      decoded = Uri.decodeComponent(last);
    } catch (_) {
      decoded = last;
    }
    return decoded.isEmpty ? 'File' : decoded;
  }

  /// The builder's rich text as plain text (<p>...</p>, <br>, entities).
  static String plainText(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();

  /// Minutes, as the builder wrote them: half a minute is 0.5, not 2 (the default).
  static num waitMinutes(dynamic v) {
    if (v is num && v > 0) return v % 1 == 0 ? v.toInt() : v;
    if (v is String) {
      final d = double.tryParse(v.trim());
      if (d != null && d > 0) return d % 1 == 0 ? d.toInt() : d;
    }
    return 2;
  }

  /// handover-timeout, sent once the handover step's max wait passes with
  /// nobody joined: the server then decides (no-agents-available), as the
  /// web widget's maxWaitTimer does.
  static Map<String, dynamic> handoverTimeoutPayload(String chatSessionId, Map<String, dynamic>? nodeData, String? workspaceId) => {
        'chatSessionId': chatSessionId,
        'assignmentData': {
          'assignmentType': nodeData?['assignmentType'],
          'assignmentStrategy': nodeData?['agentAssignmentStrategy'],
          'assignedAgents': nodeData?['assignedAgents'],
        },
        'workspaceId': workspaceId,
      };

  /// The visitor's email for leave a message: their own, else the latest email they answered.
  static String knownEmail(String? visitorEmail, List<dynamic> answerValues) {
    if (isEmail(visitorEmail)) return visitorEmail!.trim();
    for (var i = answerValues.length - 1; i >= 0; i--) {
      final v = answerValues[i]?.toString();
      if (isEmail(v)) return v!.trim();
    }
    return '';
  }

  /// What they last asked in their own words: the newest typed visitor message, not a button tap.
  static String lastQuestion(List<Map<String, dynamic>> record) {
    const kinds = {'user-live-message', 'user-input', 'user-message', 'ask-question-answer'};
    for (final r in record.reversed) {
      final kind = (r['shape'] ?? r['type'])?.toString() ?? '';
      if (kinds.contains(kind)) {
        final text = (r['text'] ?? r['userInput'] ?? r['value'])?.toString().replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
        if (text.isNotEmpty && !isEmail(text)) return text.length > 2000 ? text.substring(0, 2000) : text;
      }
    }
    return '';
  }
}
