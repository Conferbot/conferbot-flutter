// onReconnect told on each connect after the first (#93): socket_io_client
// 2.0.3 emits reconnect, reconnect_attempt and reconnect_failed on the
// Manager (socket.io), never on the Socket.
import 'package:conferbot_flutter/src/services/socket_client.dart';
import 'package:flutter_test/flutter_test.dart';

// Nothing listens here; the socket never really connects. The events are
// told to the socket and its Manager as socket_io_client would.
const _url = 'http://127.0.0.1:9';
const _config = SocketClientConfig(
  enableOfflineQueue: false,
  autoReconnect: false,
  maxReconnectionAttempts: 5,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SocketClient client;
  setUp(() async {
    client = SocketClient(apiKey: 'k', botId: 'b1', socketUrl: _url, config: _config);
    await client.connect();
  });
  tearDown(() => client.dispose());

  test('the first connect is not a reconnect; each one after it is', () async {
    var reconnects = 0;
    final sub = client.onReconnect.listen((_) => reconnects++);
    final socket = client.debugSocket!;

    socket.emit('connect');
    await Future<void>.delayed(Duration.zero);
    expect(client.isConnected, isTrue);
    expect(reconnects, 0);

    socket.emit('disconnect', 'transport close');
    socket.emit('connect');
    await Future<void>.delayed(Duration.zero);
    expect(reconnects, 1);

    socket.emit('disconnect', 'transport close');
    socket.emit('connect');
    await Future<void>.delayed(Duration.zero);
    expect(reconnects, 2);
    await sub.cancel();
  });

  test('a reconnect told on the Socket alone is not one (the Manager tells it)', () async {
    var reconnects = 0;
    final sub = client.onReconnect.listen((_) => reconnects++);
    client.debugSocket!.emit('reconnect', 1);
    await Future<void>.delayed(Duration.zero);
    expect(reconnects, 0);
    await sub.cancel();
  });

  test('the attempts and the failure are heard on the Manager', () async {
    final attempts = <int>[];
    client.onReconnecting = (attempt, max) => attempts.add(attempt);
    final manager = client.debugSocket!.io;

    manager.emit('reconnect_attempt', 2);
    expect(attempts, [2]);
    expect(client.isReconnecting, isTrue);
    expect(client.reconnectionAttempts, 2);

    manager.emit('reconnect_failed');
    expect(client.hasFailed, isTrue);
  });

  test('after a disconnect the next connect is a first connect again', () async {
    var reconnects = 0;
    final sub = client.onReconnect.listen((_) => reconnects++);
    client.debugSocket!.emit('connect');

    client.disconnect();
    await client.connect();
    client.debugSocket!.emit('connect');
    await Future<void>.delayed(Duration.zero);
    expect(reconnects, 0);
    await sub.cancel();
  });
}
