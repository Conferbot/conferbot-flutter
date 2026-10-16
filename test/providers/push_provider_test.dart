// The provider's push API (setPushToken, handlePushNotification,
// unregisterPush; core/push/push_extras.dart). No token is set here, so
// nothing reaches the network.
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:conferbot_flutter/src/models/user.dart';
import 'package:conferbot_flutter/src/providers/conferbot_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _push(String botId) => {
      'source': 'conferbot',
      'type': 'conferbot_message',
      'botId': botId,
      'chatSessionId': 's1',
      'messageId': 'm1',
      'senderType': 'agent',
      'senderName': 'Maya',
      'body': 'Hi',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConferBotProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = ConferBotProvider(
      apiKey: 'k',
      botId: 'b1',
      config: const ConferBotConfig(autoConnect: false, enablePersistence: false),
      user: const ConferBotUser(id: 'u1'),
    );
  });

  tearDown(() {
    provider.dispose();
    ChatState.instance.visitorContext = null;
  });

  test('another app\'s or another bot\'s notification is not ours', () {
    expect(provider.handlePushNotification({'foo': 'bar'}), isFalse);
    expect(provider.handlePushNotification(null), isFalse);
    expect(provider.handlePushNotification(_push('other')), isFalse);
  });

  test('ours, arrived in the foreground with { open: false }: counted unread', () {
    final before = provider.unreadCount;
    expect(provider.handlePushNotification(_push('b1'), open: false), isTrue);
    expect(provider.unreadCount, before + 1);
  });

  test('push is opt-in: no token, nothing registered; signing out without one sends nothing', () async {
    expect(provider.push.registrar.token, isNull);
    provider.identify(null);
    await provider.unregisterPush();
    expect(provider.push.registrar.registered, isNull);
  });
}
