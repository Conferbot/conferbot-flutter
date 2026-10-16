// The help centre's ratings and reading over the chat's socket (#59), as
// the web widget's knowledgeBase.ts sends them and embed-server's
// chatbotHandler.js reads them.
import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/core/help_centre/article_engagement.dart';

class _Socket {
  bool connected = true;
  final sent = <(String, Map<String, dynamic>)>[];
  HelpCentreLink link({String? session = 'cs_1'}) => HelpCentreLink(
        emit: (event, payload) {
          if (!connected) return false;
          sent.add((event, payload));
          return true;
        },
        sessionId: () => session,
      );
}

void main() {
  late _Socket socket;
  late int clock;
  late ArticleEngagement e;

  setUp(() {
    socket = _Socket();
    clock = 1000000;
    e = ArticleEngagement(link: socket.link(), visitorId: 'v_1', now: () => clock);
  });

  group('rate-article', () {
    test('helpful is 5, not helpful 1, with the visitor and the conversation', () {
      expect(e.rate('a1', true), ArticleVote.sent);
      expect(e.rate('a2', false), ArticleVote.sent);
      expect(socket.sent.map((s) => s.$1), ['rate-article', 'rate-article']);
      expect(socket.sent[0].$2, {'articleId': 'a1', 'visitorId': 'v_1', 'sessionId': 'cs_1', 'helpful': true, 'rating': 5, 'device': 'mobile'});
      expect(socket.sent[1].$2, {'articleId': 'a2', 'visitorId': 'v_1', 'sessionId': 'cs_1', 'helpful': false, 'rating': 1, 'device': 'mobile'});
    });

    test('once per article per session', () {
      e.rate('a1', true);
      expect(e.rate('a1', false), ArticleVote.already);
      expect(e.hasRated('a1'), isTrue);
      expect(socket.sent, hasLength(1));
      e.reset();
      expect(e.rate('a1', false), ArticleVote.sent);
    });

    test('not connected: nothing sent, offline (the caller uses REST)', () {
      socket.connected = false;
      expect(e.rate('a1', true), ArticleVote.offline);
      expect(socket.sent, isEmpty);
      expect(e.rate('a1', true), ArticleVote.already);
    });

    test('no link at all is offline', () {
      expect(ArticleEngagement().rate('a1', true), ArticleVote.offline);
    });

    test('an unknown visitor or conversation is left out', () {
      expect(ArticleEngagement.ratePayload(articleId: 'a', helpful: true), {'articleId': 'a', 'helpful': true, 'rating': 5});
    });
  });

  group('track-article-engagement', () {
    test('reading time in seconds, the deepest scroll, read to the end at 90', () {
      e.start('a1');
      e.scrolled(40);
      e.scrolled(91.6);
      e.scrolled(20);
      clock += 12400;
      final sent = e.send();
      expect(sent, {
        'articleId': 'a1',
        'visitorId': 'v_1',
        'sessionId': 'cs_1',
        'timeSpent': 12,
        'scrollDepth': 92,
        'isCompleted': true,
        'device': 'mobile',
      });
      expect(socket.sent.single.$1, 'track-article-engagement');
      expect(e.articleId, isNull);
    });

    test('under 2 seconds is an accidental tap: not sent', () {
      e.start('a1');
      clock += 1400;
      expect(e.send(), isNull);
      expect(socket.sent, isEmpty);
      expect(e.articleId, isNull);
    });

    test('opening another article sends the one before', () {
      e.start('a1');
      e.scrolled(50);
      clock += 5000;
      e.start('a2');
      expect(socket.sent.single.$2['articleId'], 'a1');
      expect(socket.sent.single.$2['isCompleted'], false);
      expect(e.articleId, 'a2');
      expect(e.maxDepth, 0);
    });

    test('scrolling with nothing open, or past 100, is ignored or capped', () {
      e.scrolled(80);
      expect(e.maxDepth, 0);
      e.start('a1');
      e.scrolled(140);
      expect(e.maxDepth, 100);
      e.scrolled(double.nan);
      expect(e.maxDepth, 100);
    });

    test('nothing open: nothing sent; not connected: lost, reading stops', () {
      expect(e.send(), isNull);
      e.start('a1');
      clock += 3000;
      socket.connected = false;
      expect(e.send(), isNull);
      expect(e.articleId, isNull);
    });
  });
}
