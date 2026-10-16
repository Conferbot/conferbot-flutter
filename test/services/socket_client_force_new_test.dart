// Each SocketClient owns its connection (#77): socket_io_client caches a
// Manager per host, so two clients to the same server shared one socket and
// the second used the first one's handshake.
import 'package:conferbot_flutter/src/services/socket_client.dart';
import 'package:flutter_test/flutter_test.dart';

// Nothing listens here; the sockets never connect.
const _url = 'http://127.0.0.1:9';
const _config = SocketClientConfig(
  enableOfflineQueue: false,
  autoReconnect: false,
  maxReconnectionAttempts: 0,
);

SocketClient _client(String visitorId) =>
    SocketClient(apiKey: 'k', botId: 'b1', socketUrl: _url, config: _config)
      ..visitorId = visitorId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('two clients to the same server each get their own socket and handshake', () async {
    final a = _client('v1');
    final b = _client('v2');
    await a.connect();
    await b.connect();

    expect(a.debugSocket, isNotNull);
    expect(b.debugSocket, isNotNull);
    expect(identical(a.debugSocket, b.debugSocket), isFalse);
    expect(identical(a.debugSocket!.io, b.debugSocket!.io), isFalse);
    expect(a.debugSocket!.query, contains('visitorId=v1'));
    expect(b.debugSocket!.query, contains('visitorId=v2'));
    expect(a.debugSocket!.auth, {'botId': 'b1', 'visitorId': 'v1'});
    expect(b.debugSocket!.auth, {'botId': 'b1', 'visitorId': 'v2'});

    // Disposing one leaves the other's connection alone.
    final bManager = b.debugSocket!.io;
    a.dispose();
    expect(a.debugSocket, isNull);
    expect(b.debugSocket!.io, same(bManager));
    expect(bManager.skipReconnect, isNot(true));
    b.dispose();
    expect(b.debugSocket, isNull);
  });

  test('a reset opens a fresh socket with the current visitor, not the old one', () async {
    final c = _client('v1');
    await c.connect();
    final first = c.debugSocket!;

    c.visitorId = 'v9';
    c.resetConnection();
    final second = c.debugSocket!;
    expect(identical(first, second), isFalse);
    expect(second.query, contains('visitorId=v9'));
    // The old socket's manager was closed and won't reconnect.
    expect(first.io.skipReconnect, isTrue);
    c.dispose();
    expect(second.io.skipReconnect, isTrue);
  });
}
