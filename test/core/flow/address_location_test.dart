// "Use my location" on the address step (#48), as an optional capability:
// the app's location provider gives the point, the step asks the server
// for its address (web richNodesView.ts locateBtn, POST geo/reverse) and
// the visitor confirms it as a pick, saved with source "location".
import 'package:conferbot_flutter/src/core/flow/flow_context.dart';
import 'package:conferbot_flutter/src/core/flow/location.dart';
import 'package:conferbot_flutter/src/core/nodes/node_handler.dart';
import 'package:conferbot_flutter/src/core/nodes/node_handler_registry.dart';
import 'package:conferbot_flutter/src/core/nodes/node_result.dart';
import 'package:conferbot_flutter/src/core/nodes/node_ui_state.dart';
import 'package:conferbot_flutter/src/core/state/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

final calls = <(String, dynamic)>[];
ApiReply Function(String path, dynamic body) reply = (_, __) => const ApiReply(ok: false, status: 0, error: 'network');

FlowContext _ctx() => FlowContext(
      botId: 'b1',
      sessionId: 's1',
      api: (path, body, {timeoutMs}) async {
        calls.add((path, body));
        return reply(path, body);
      },
      upload: (_) async => const UploadResult(ok: false),
      emit: (_, __) => true,
      on: (_, __) => () {},
      typing: (_) async {},
      delay: (_) async {},
      edges: () => const [],
      edgesOf: (_) => const [],
      wired: (_) => false,
      random: () => 0.5,
      now: () => DateTime.utc(2026, 10, 16, 9),
      visitorTimeZone: 'UTC',
      calendarBookings: const [],
      respond: (_) {},
      shown: () {},
      isStale: () => false,
      node: (_) => null,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final handler = NodeHandlerRegistry.withAll().getHandler('address-node')!;
  final state = ChatState.instance;
  FlowNode node([Map<String, dynamic> data = const {}]) =>
      FlowNode(id: 'ad', type: 'address-node', data: {'answerVariable': 'home', ...data}, ctx: _ctx());

  setUp(() {
    calls.clear();
    state.reset();
    state.initialize(chatSessionId: 's1', visitorId: 'v1', botId: 'b1');
  });

  group('the step', () {
    test('says the owner allows it (allowMyLocation, on unless false)', () async {
      final on = ((await handler.handle(node(), state)) as DisplayUIResult).uiState as AddressUIState;
      expect(on.extra['allowMyLocation'], isTrue);
      final off = ((await handler.handle(node({'allowMyLocation': false}), state)) as DisplayUIResult).uiState as AddressUIState;
      expect(off.extra['allowMyLocation'], isFalse);
    });

    test("locate: geo/reverse, the server's address to confirm, then saved as the location", () async {
      reply = (path, _) => const ApiReply(ok: true, status: 200, body: {
            'results': [
              {'formatted': '1 Marina Walk, Dubai, United Arab Emirates', 'line1': '1 Marina Walk', 'city': 'Dubai', 'country': 'United Arab Emirates'},
            ],
          });
      final n = node();
      await handler.handle(n, state);
      final shown = await handler.handleResponse({'action': 'locate', 'lat': 25.08, 'lng': 55.14}, n, state);
      expect(calls.single.$1, 'geo/reverse');
      expect(calls.single.$2, {'nodeId': 'ad', 'lat': 25.08, 'lng': 55.14});
      final ui = (shown as DisplayUIResult).uiState as AddressUIState;
      expect(ui.extra['located'], isTrue);
      expect(ui.results.single['formatted'], '1 Marina Walk, Dubai, United Arab Emirates');
      // The point is kept when the server's result has none.
      expect(ui.results.single['lat'], 25.08);
      expect(ui.results.single['lng'], 55.14);

      final done = await handler.handleResponse({'action': 'pick', 'index': 0}, n, state);
      expect(done, isNot(isA<DisplayUIResult>()));
      expect(done, isNot(isA<InvalidResult>()));
      final entry = state.getRecordForServer().lastWhere((e) => e['shape'] == 'user-address');
      expect(entry['display'], '1 Marina Walk, Dubai, United Arab Emirates');
      expect(entry['source'], 'location');
    });

    test('no address for the point: the point itself, to five places', () async {
      reply = (_, __) => const ApiReply(ok: true, status: 200, body: {'results': []});
      final n = node();
      await handler.handle(n, state);
      final ui = ((await handler.handleResponse({'action': 'locate', 'lat': 25.0812345, 'lng': 55.1412345}, n, state)) as DisplayUIResult).uiState
          as AddressUIState;
      expect(ui.results.single['formatted'], '25.08123, 55.14123');
    });

    test("the server's refusal is said on the card; a plain failure falls back to the point", () async {
      reply = (_, __) => const ApiReply(ok: false, status: 429, body: {'code': 'rate_limited'});
      final n = node();
      await handler.handle(n, state);
      final busy = await handler.handleResponse({'action': 'locate', 'lat': 1, 'lng': 2}, n, state);
      expect(busy, isA<InvalidResult>());
      expect((busy as InvalidResult).message, contains('busy'));

      reply = (_, __) => const ApiReply(ok: false, status: 500, body: {});
      final point = await handler.handleResponse({'action': 'locate', 'lat': 1, 'lng': 2}, n, state);
      expect(((point as DisplayUIResult).uiState as AddressUIState).results.single['formatted'], '1.00000, 2.00000');
    });

    test('a search after locating saves a pick as a search again', () async {
      reply = (path, _) => ApiReply(ok: true, status: 200, body: {
            'results': [
              {'formatted': path == 'geo/reverse' ? 'Here, Dubai' : 'There, Abu Dhabi', 'lat': 1, 'lng': 2},
            ],
          });
      final n = node();
      await handler.handle(n, state);
      await handler.handleResponse({'action': 'locate', 'lat': 1, 'lng': 2}, n, state);
      await handler.handleResponse({'action': 'search', 'q': 'there'}, n, state);
      await handler.handleResponse({'action': 'pick', 'index': 0}, n, state);
      expect(state.getRecordForServer().lastWhere((e) => e['shape'] == 'user-address')['source'], 'search');
    });

    test('off for this step, or not a real point: refused, no call', () async {
      final n = node({'allowMyLocation': false});
      await handler.handle(n, state);
      expect(await handler.handleResponse({'action': 'locate', 'lat': 1, 'lng': 2}, n, state), isA<InvalidResult>());
      final m = node();
      expect(await handler.handleResponse({'action': 'locate', 'lat': 91, 'lng': 2}, m, state), isA<InvalidResult>());
      expect(await handler.handleResponse({'action': 'locate', 'lat': 'x', 'lng': 2}, m, state), isA<InvalidResult>());
      expect(calls, isEmpty);
    });
  });

  group("the app's provider", () {
    test('a point', () async {
      final r = await locate(() async => const ConferBotLatLng(25.08, 55.14));
      expect(r.at, const ConferBotLatLng(25.08, 55.14));
      expect(r.error, isNull);
    });

    test('null or not a real point: unavailable', () async {
      expect((await locate(() async => null)).error, 'unavailable');
      expect((await locate(() async => const ConferBotLatLng(double.nan, 0))).error, 'unavailable');
      expect((await locate(() async => const ConferBotLatLng(0, 181))).error, 'unavailable');
    });

    test('ConferBotLocationDenied: denied; any other error: unavailable', () async {
      expect((await locate(() async => throw const ConferBotLocationDenied())).error, 'denied');
      expect((await locate(() async => throw StateError('gps'))).error, 'unavailable');
    });

    test('no answer in time: unavailable', () async {
      final r = await locate(() => Future<ConferBotLatLng?>.delayed(const Duration(seconds: 1), () => null), timeout: const Duration(milliseconds: 10));
      expect(r.error, 'unavailable');
    });
  });
}
