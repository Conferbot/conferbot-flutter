// ApiClient push methods (embed-server POST /api/v1/mobile/push/register,
// /unregister; docs/mobile-push.md): the bot's headers, chatSessionId and
// tokenType, the server's error codes. Only ever against MockClient.
import 'dart:convert';

import 'package:conferbot_flutter/src/config/constants.dart';
import 'package:conferbot_flutter/src/core/push/push.dart';
import 'package:conferbot_flutter/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient client(MockClientHandler h) => ApiClient(apiKey: 'k', botId: 'bot1', baseUrl: 'http://x/api/v1/mobile', client: MockClient(h));

  test('registers with the bot headers, chatSessionId and tokenType', () async {
    late http.Request sent;
    final api = client((r) async {
      sent = r;
      return http.Response(jsonEncode({'success': true, 'data': {'id': 'p1'}}), 200);
    });
    final r = await api.registerPush(pushRegisterBody('fcm:tok-1234567890123456', 's1', PushTokenType.fcm));
    expect(r, const PushRegisterResult.registered());
    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://x/api/v1/mobile/push/register');
    expect(sent.headers[ConferBotConstants.headerBotId], 'bot1');
    expect(sent.headers[ConferBotConstants.headerPlatform], ConferBotConstants.platformIdentifier);
    expect(jsonDecode(sent.body), {'token': 'fcm:tok-1234567890123456', 'chatSessionId': 's1', 'tokenType': 'fcm'});
  });

  test('reads the server\'s refusal and the network, never throws, never retries', () async {
    var calls = 0;
    final api = client((r) async {
      calls++;
      return http.Response(jsonEncode({'success': false, 'error': 'SESSION_NOT_FOUND'}), 404);
    });
    expect(await api.registerPush(pushRegisterBody('t', 's1', PushTokenType.fcm)), const PushRegisterResult.failed(PushRegisterError.sessionNotFound));
    expect(calls, 1);
    final down = client((r) async => throw http.ClientException('offline'));
    expect(await down.registerPush(pushRegisterBody('t', 's1', PushTokenType.fcm)), const PushRegisterResult.failed(PushRegisterError.network));
    final missing = client((r) async => http.Response(jsonEncode({'success': false, 'error': 'MISSING_SESSION'}), 400));
    expect(await missing.registerPush(pushRegisterBody('t', '', PushTokenType.fcm)), const PushRegisterResult.failed(PushRegisterError.missingSession));
  });

  test('unregisters the token', () async {
    late http.Request sent;
    final api = client((r) async {
      sent = r;
      return http.Response(jsonEncode({'success': true}), 200);
    });
    expect(await api.unregisterPush('fcm:tok'), isTrue);
    expect(sent.url.path, '/api/v1/mobile/push/unregister');
    expect(jsonDecode(sent.body), {'token': 'fcm:tok'});
    final down = client((r) async => throw http.ClientException('offline'));
    expect(await down.unregisterPush('fcm:tok'), isFalse);
  });

  test('the older registerPushToken sends tokenType too', () async {
    late Map body;
    final api = client((r) async {
      body = jsonDecode(r.body) as Map;
      return http.Response(jsonEncode({'success': true}), 200);
    });
    // ignore: deprecated_member_use_from_same_package
    await api.registerPushToken(token: 'a' * 64, chatSessionId: 's1');
    expect(body['tokenType'], 'apns');
    expect(body['chatSessionId'], 's1');
  });
}
