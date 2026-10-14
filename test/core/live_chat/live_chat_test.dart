import 'package:conferbot_flutter/src/core/live_chat/live_chat.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_chat_extras.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a waiting queue status and drops none', () {
    expect(LiveChat.queueStatusOf({'status': 'none'}), isNull);
    expect(LiveChat.queueStatusOf(null), isNull);
    expect(
      LiveChat.queueStatusOf({'status': 'waiting', 'position': 2, 'ahead': 1, 'agentsOnline': 3, 'estimate': {'label': ' About 2 min '}}),
      const QueueStatus(status: 'waiting', position: 2, ahead: 1, agentsOnline: 3, estimateLabel: 'About 2 min'),
    );
  });

  test('says where the visitor stands', () {
    expect(LiveChat.queueLine(const QueueStatus(status: 'waiting', position: 1)), "You're next in line");
    expect(LiveChat.queueLine(const QueueStatus(status: 'waiting', position: 3)), "You're 3rd in line");
    expect(LiveChat.queueLine(null), 'Connecting you to the team');
    expect(LiveChat.queueSubline(const QueueStatus(status: 'waiting', estimateLabel: 'Under a minute')), 'Under a minute');
    expect(LiveChat.queueSubline(null), 'Our team will be with you soon');
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 101, 111].map(LiveChat.ordinal).toList(),
        ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd', '101st', '111th']);
  });

  test('reads handover waiting and words it', () {
    final w = LiveChat.handoverWaitingOf({'offline': false, 'askEmail': true})!;
    expect(w.reason, 'busy');
    expect(LiveChat.handoverWaitingLine(w), "Everyone's busy right now. Leave your email and they will reply.");
    expect(LiveChat.handoverWaitingLine(w.copyWith(email: 'jo@example.com')), endsWith("They'll reply to jo@example.com."));
  });

  test('keeps a translation only with an original', () {
    expect(LiveChat.agentTranslationOf({'translation': {'from': 'en', 'to': 'es', 'original': 'Hi'}}),
        const AgentTranslation(from: 'en', to: 'es', original: 'Hi'));
    expect(LiveChat.agentTranslationOf({'translation': {'to': 'es', 'original': ' '}}), isNull);
    expect(LiveChat.translationLabels('es-MX')[0], 'Ver original');
    expect(LiveChat.translationLabels('xx')[1], 'See translation');
  });

  test('marks the latest visitor message', () {
    const record = [LiveEntry('a1', 'agent-message'), LiveEntry('v1', 'user-live-message'), LiveEntry('v2', 'user-live-message')];
    expect(LiveChat.visitorReceiptOf(record, const ReceiptMarks()), const VisitorReceipt('v2', ReceiptState.sent));
    expect(LiveChat.visitorReceiptOf(record, const ReceiptMarks(deliveredMessageId: 'v2'))?.state, ReceiptState.delivered);
    expect(LiveChat.visitorReceiptOf(record, const ReceiptMarks(deliveredMessageId: 'v2', seenMessageId: 'v2'))?.state, ReceiptState.seen);
    expect(LiveChat.visitorReceiptOf(record, const ReceiptMarks(seenMessageId: 'v1'))?.state, ReceiptState.sent);
    expect(LiveChat.visitorReceiptOf([...record, const LiveEntry('a2', 'agent-message')], const ReceiptMarks()), isNull);
    expect(LiveChat.latestAgentMessageId([...record, const LiveEntry('f1', 'agent-message-file'), const LiveEntry('v3', 'user-live-message')]), 'f1');
    expect(LiveChat.latestAgentMessageId(const []), '');
  });

  test('receipt entries come from the server record', () {
    final entries = LiveChatExtras.entriesOf([
      {'id': 'm1', 'shape': 'user-live-message'},
      {'_id': 'a1', 'type': 'agent-message'},
    ]);
    expect(entries.map((e) => '${e.id}:${e.kind}').toList(), ['m1:user-live-message', 'a1:agent-message']);
  });

  test('checks emails and uploads', () {
    expect(LiveChat.isEmail(' a@b.co '), isTrue);
    expect(LiveChat.isEmail('a@b'), isFalse);
    expect(LiveChat.visitorUploadsOn(null), isTrue);
    expect(LiveChat.visitorUploadsOn({'enableVisitorFileUpload': false}), isFalse);
  });

  test('reads rating settings and builds the payload', () {
    expect(LiveChat.csatConfigOf(null), isNull);
    expect(LiveChat.csatConfigOf({'ratingType': 'stars'}), isNull);
    final c = LiveChat.csatConfigOf({'enabled': true, 'ratingType': 'bogus'})!;
    expect(c.ratingType, 'stars');
    expect(c.titleText, 'How was your experience?');
    final stars = LiveChat.ratingPayload('s1', 'stars', 4, ' great ');
    expect(stars['csatScore'], 4);
    expect(stars['feedback'], 'great');
    expect(LiveChat.ratingPayload('s1', 'thumbs', false)['thumbsUp'], isFalse);
    expect(LiveChat.ratingPayload('s1', 'nps', 9, '  ').containsKey('feedback'), isFalse);
  });

  test('resolves file links and names them', () {
    expect(LiveChat.resolveMediaUrl('/api/v1/media/1', 'https://api.example.com/'), 'https://api.example.com/api/v1/media/1');
    expect(LiveChat.resolveMediaUrl('java\nscript:alert(1)', 'https://a'), isNull);
    expect(LiveChat.isImageUrl('https://x/a.JPG?x=1'), isTrue);
    expect(LiveChat.isImageUrl('/media/abc', 'image/png'), isTrue);
    expect(LiveChat.isImageUrl('/media/abc'), isFalse);
    expect(LiveChat.fileNameOf('Invoice.pdf', '/media/1'), 'Invoice.pdf');
    expect(LiveChat.fileNameOf(null, 'https://x/My%20File.pdf?sig=1'), 'My File.pdf');
  });

  test('plain text, wait minutes and the leave-a-message prefill', () {
    expect(LiveChat.plainText('<p>Please wait &amp; relax.</p>'), 'Please wait & relax.');
    expect(LiveChat.waitMinutes('0.5'), 0.5);
    expect(LiveChat.waitMinutes('3'), 3);
    expect(LiveChat.waitMinutes(1.5), 1.5);
    expect(LiveChat.waitMinutes(null), 2);
    expect(LiveChat.waitMinutes('x'), 2);
    expect(LiveChat.knownEmail(null, ['Jo', 'jo@example.com', 'Pricing']), 'jo@example.com');
    expect(LiveChat.knownEmail('me@x.io', ['jo@example.com']), 'me@x.io');
    expect(
      LiveChat.lastQuestion([
        {'shape': 'user-message', 'text': 'How much is Pro?'},
        {'shape': 'user-input', 'text': 'jo@example.com'},
        {'shape': 'bot-message', 'text': 'Hi'},
      ]),
      'How much is Pro?',
    );
  });

  test('asks the server to decide once the max wait passes', () {
    final p = LiveChat.handoverTimeoutPayload('s1', {'assignmentType': 'manual', 'assignedAgents': ['a2'], 'agentAssignmentStrategy': 'round_robin'}, 'w1');
    expect(p['chatSessionId'], 's1');
    expect(p['workspaceId'], 'w1');
    expect(p['assignmentData'], {'assignmentType': 'manual', 'assignmentStrategy': 'round_robin', 'assignedAgents': ['a2']});
  });
}
