// The socket's handshake carries the visitor, and a handshake refused for a
// blocked visitor is told as visitor-blocked (#43; web core/socket.ts, RN
// services/socket.ts).
import 'package:conferbot_flutter/src/models/socket_events.dart';
import 'package:conferbot_flutter/src/services/socket_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the handshake carries the bot, and the visitor when known', () {
    expect(SocketClient.handshake('b1', 'v1'), {'botId': 'b1', 'visitorId': 'v1'});
    expect(SocketClient.handshake('b1', null), {'botId': 'b1'});
    expect(SocketClient.handshake('b1', ''), {'botId': 'b1'});
  });

  test('refused as blocked: told to its listeners, before or after they listen, and no reconnecting', () async {
    final client = SocketClient(apiKey: 'k', botId: 'b1')..visitorId = 'v1';
    final heard = <dynamic>[];
    client.on(SocketEvents.visitorBlocked, heard.add);
    client.debugBlockedAtHandshake();
    expect(heard, [
      {'handshake': true},
    ]);
    expect(client.isBlocked, isTrue);
    expect(client.connectionState, SocketConnectionState.failed);
    // A listener that comes later hears it too.
    final late = <dynamic>[];
    client.on(SocketEvents.visitorBlocked, late.add);
    await Future<void>.delayed(Duration.zero);
    expect(late, hasLength(1));
    // Off stops it.
    client.off(SocketEvents.visitorBlocked, heard.add);
    client.debugBlockedAtHandshake();
    expect(heard, hasLength(1));
  });
}
