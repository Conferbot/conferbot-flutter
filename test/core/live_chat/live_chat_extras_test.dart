// Live chat extras against a fake socket (lib/src/core/live_chat/
// live_chat_extras.dart): a blocked visitor (#43), one survey per end (#43)
// and "Email me this chat" (#42, the transcript call stubbed: no email is
// ever sent). The cases of the React Native SDK's
// __tests__/context/useLiveChatExtras.test.ts.
import 'package:conferbot_flutter/src/core/live_chat/email_transcript.dart';
import 'package:conferbot_flutter/src/core/live_chat/live_chat_extras.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_socket_client.dart';

void main() {
  late MockSocketClient socket;
  late LiveChatExtras live;
  late List<({String sid, String email})> posts;
  late TranscriptEmailResult answer;
  late int recordsSent;
  const sid = 'sess-1';
  final state = ChatState.instance;

  setUp(() {
    state.reset();
    state.initialize(chatSessionId: sid, visitorId: 'v1', botId: 'b1');
    socket = MockSocketClient()..mockIsConnected = true;
    posts = [];
    answer = const TranscriptEmailResult(true);
    recordsSent = 0;
    live = LiveChatExtras(
      socket: () => socket,
      sessionId: () => sid,
      addMessage: (_) {},
      sendRecord: () => recordsSent++,
      postTranscriptEmail: (s, email) async {
        posts.add((sid: s, email: email));
        return answer;
      },
    );
    live.setChatbotData({
      'csatConfig': {'enabled': true, 'ratingType': 'stars'},
    });
    live.setupListeners();
  });

  tearDown(() {
    live.dispose();
    state.reset();
  });

  test('blocked: the closed line, and every card and wait gone', () {
    socket.simulateEvent('no-agents-available', {});
    socket.simulateEvent('file-upload-requested', {'chatSessionId': sid, 'agentName': 'Sam'});
    live.openEmailTranscript();
    expect(live.noAgentsAvailable, isTrue);
    socket.simulateEvent('visitor-blocked', {'chatSessionId': sid});
    expect(live.blocked, 'This conversation has been closed.');
    expect(live.noAgentsAvailable, isFalse);
    expect(live.fileRequestedBy, isNull);
    expect(live.mailOpen, isFalse);
    expect(live.csatOpen, isFalse);
    // Its own words when the server gives them; another session's is not ours.
    socket.simulateEvent('visitor-blocked', {'chatSessionId': 'other', 'message': 'x'});
    expect(live.blocked, 'This conversation has been closed.');
    live.reset();
    expect(live.blocked, isNull);
  });

  test('the same end again opens no second survey', () {
    socket.simulateEvent('chat-ended', {'chatSessionId': sid});
    expect(live.csatOpen, isTrue);
    live.dismissCsat();
    // The provider records the end; the repeat finds it.
    state.pushToRecord(RecordEntry(id: 'agent-chat-ended-1', shape: 'agent-chat-ended', type: 'agent-chat-ended'));
    socket.simulateEvent('chat-ended', {'chatSessionId': sid});
    expect(live.csatOpen, isFalse);
    // A new live chat, a new end: its own survey.
    state.pushToRecord(RecordEntry(id: 'j2', shape: 'agent-joined-message', type: 'agent-joined-message'));
    socket.simulateEvent('chat-ended', {'chatSessionId': sid});
    expect(live.csatOpen, isTrue);
  });

  test("Email me this chat: the session and address posted; once sent the address is the visitor's", () async {
    live.openEmailTranscript();
    expect(live.mailOpen, isTrue);
    final r = await live.emailTranscript('  ada@example.com ');
    expect(r.ok, isTrue);
    expect(posts.single, (sid: sid, email: 'ada@example.com'));
    expect(live.mailSentTo, 'ada@example.com');
    expect(state.userMetadata.email, 'ada@example.com');
    expect(state.answerVariables.last.value, 'ada@example.com');
    expect(recordsSent, 1);
    expect(live.knownEmail(), 'ada@example.com');
    // Opening it again starts over.
    live.openEmailTranscript();
    expect(live.mailSentTo, isNull);
  });

  test("Email me this chat that did not go: the server's reason, nothing kept", () async {
    answer = const TranscriptEmailResult(false, 'Too many requests. Please try again later.');
    final r = await live.emailTranscript('ada@example.com');
    expect(r.message, 'Too many requests. Please try again later.');
    expect(live.mailSentTo, isNull);
    expect(state.userMetadata.email, isNull);
    expect(recordsSent, 0);
  });
}
