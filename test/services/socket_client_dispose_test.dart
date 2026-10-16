// SocketClient.dispose with the socket not already disconnected (#75).
import 'package:conferbot_flutter/src/services/socket_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('disposes whatever state the connection is in', () {
    final client = SocketClient(apiKey: 'k', botId: 'b1');
    // Refused at the handshake: the state is failed, not disconnected.
    client.debugBlockedAtHandshake();
    expect(client.connectionState, SocketConnectionState.failed);
    expect(client.dispose, returnsNormally);
  });
}
