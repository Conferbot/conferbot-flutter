/// What a step handler may use besides the chat state: the bot's server
/// endpoints, the socket, timers, the flow's edges (React Native
/// src/core/flow/context.ts). The engine gives every handler one as
/// `node.ctx`; a handler run on its own gets [FlowContext.standalone].
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:http/http.dart' as http;

import 'zones.dart' show deviceTimeZone;

/// A bot API answer. [error] is "network" when the server could not be
/// reached and "timeout" when it took too long.
class ApiReply {
  final bool ok;
  final int status;
  final dynamic body;
  final String? error;

  const ApiReply({required this.ok, required this.status, this.body, this.error});
}

/// A file the visitor picked (or a generated one, as a data URL).
class UploadFile {
  final String? uri;
  final String? name;
  final String? type;
  final int? size;

  /// Raw content for a generated file (a signature PNG as a data URL).
  final String? dataUrl;

  /// The bytes, when the picker gave them.
  final List<int>? bytes;

  const UploadFile({this.uri, this.name, this.type, this.size, this.dataUrl, this.bytes});

  /// From the chat UI's answer (`{name, size, type, uri|path, bytes}`).
  factory UploadFile.fromMap(Map<dynamic, dynamic> m) => UploadFile(
        uri: (m['uri'] ?? m['path'])?.toString(),
        name: m['name']?.toString(),
        type: (m['type'] ?? m['mimeType'])?.toString(),
        size: m['size'] is num ? (m['size'] as num).toInt() : int.tryParse('${m['size'] ?? ''}'),
        dataUrl: m['dataUrl']?.toString(),
        bytes: m['bytes'] is List<int> ? m['bytes'] as List<int> : null,
      );
}

/// An upload's result: the file's URL when it worked.
class UploadResult {
  final bool ok;
  final String? url;
  final String? error;

  const UploadResult({required this.ok, this.url, this.error});
}

/// The socket as the flow uses it.
abstract class FlowSocket {
  /// A socket event to the server.
  void emit(String event, dynamic payload);

  /// Listen to a server event; returns the unsubscribe.
  void Function() on(String event, void Function(dynamic payload) listener);

  /// The record (and answers) to the server (`response-record`).
  void sendResponseRecord(Map<String, dynamic> responseData);
}

/// What a handler may use while its step runs.
class FlowContext {
  final String botId;
  final String sessionId;

  /// POST JSON to {api}/api/v1/bot/:botId/<path>. Never throws.
  final Future<ApiReply> Function(String path, dynamic body, {int? timeoutMs}) api;

  /// Upload a file to {api}/api/v1/bot/:botId/media.
  final Future<UploadResult> Function(UploadFile file) upload;

  /// A socket event to the server; false when there is no socket.
  final bool Function(String event, dynamic payload) emit;

  /// Listen to a socket event; returns the unsubscribe.
  final void Function() Function(String event, void Function(dynamic payload) listener) on;

  /// Typing dots for `ms`, then resolves.
  final Future<void> Function(int ms) typing;
  final Future<void> Function(int ms) delay;

  /// The edges that leave this step, in flow order.
  final List<Map<String, dynamic>> Function() edges;

  /// The edges that leave another step, in flow order.
  final List<Map<String, dynamic>> Function(String nodeId) edgesOf;

  /// Whether an edge leaves this step by exactly this handle.
  final bool Function(String handle) wired;

  /// The step's place in the conversation (0 = the welcome).
  final int stepIndex;

  /// How this step was reached: "start", "edge:<h>", "port:<h>" or "jump".
  final String via;
  final double Function() random;
  final DateTime Function() now;
  final Map<String, dynamic> customizations;

  /// The visitor's IANA time zone.
  final String visitorTimeZone;

  /// The page the chat runs on, when the host app supplies one
  /// ({url, referrer}; hidden-fields).
  final Map<String, String>? page;

  /// The bot's bookings (the bot data's calendarBookings), for a calendar's
  /// taken slots.
  final List<dynamic> calendarBookings;

  /// Give the waiting step an answer from outside (a socket event).
  final void Function(dynamic response) respond;

  /// The step's content is on screen now (a step that speaks before it returns).
  final void Function() shown;

  /// True once the flow has moved past this step.
  final bool Function() isStale;

  /// A node of the flow by id.
  final Map<String, dynamic>? Function(String id) node;

  /// The HTTP client the flow uses (a webhook's own calls).
  final http.Client? httpClient;

  const FlowContext({
    required this.botId,
    required this.sessionId,
    required this.api,
    required this.upload,
    required this.emit,
    required this.on,
    required this.typing,
    required this.delay,
    required this.edges,
    required this.edgesOf,
    required this.wired,
    this.stepIndex = 0,
    this.via = 'edge',
    required this.random,
    required this.now,
    this.customizations = const {},
    this.visitorTimeZone = 'UTC',
    this.page,
    this.calendarBookings = const [],
    required this.respond,
    required this.shown,
    required this.isStale,
    required this.node,
    this.httpClient,
  });

  /// A context for a handler run on its own: real timers, the given
  /// socket and server, no flow around it.
  factory FlowContext.standalone({
    String botId = '',
    String sessionId = '',
    FlowSocket? socket,
    String apiOrigin = '',
    http.Client? client,
    Map<String, dynamic> customizations = const {},
  }) {
    Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms < 0 ? 0 : ms));
    return FlowContext(
      botId: botId,
      sessionId: sessionId,
      api: (path, body, {timeoutMs}) =>
          postBotApi(client ?? http.Client(), apiOrigin, botId, path, body, timeoutMs: timeoutMs),
      upload: (file) => uploadBotMedia(client ?? http.Client(), apiOrigin, botId, sessionId, sessionId, file),
      emit: (event, payload) {
        if (socket == null) return false;
        socket.emit(event, payload);
        return true;
      },
      on: (event, listener) => socket == null ? () {} : socket.on(event, listener),
      typing: wait,
      delay: wait,
      edges: () => const [],
      edgesOf: (_) => const [],
      wired: (_) => false,
      random: () => _random.nextDouble(),
      now: DateTime.now,
      customizations: customizations,
      visitorTimeZone: deviceTimeZone(),
      respond: (_) {},
      shown: () {},
      isStale: () => false,
      node: (_) => null,
      httpClient: client,
    );
  }
}

final _random = _Rand();

class _Rand {
  int _seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x80000000;
  }
}

/// POST JSON to the bot API, with an optional client timeout. Never throws.
Future<ApiReply> postBotApi(
  http.Client client,
  String apiOrigin,
  String botId,
  String path,
  dynamic body, {
  int? timeoutMs,
}) async {
  final url = Uri.parse('$apiOrigin/api/v1/bot/${Uri.encodeComponent(botId)}/$path');
  Future<ApiReply> request() async {
    try {
      final res = await client.post(
        url,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body ?? const <String, dynamic>{}),
      );
      dynamic json;
      try {
        json = res.body.isEmpty ? null : jsonDecode(res.body);
      } catch (_) {
        json = null;
      }
      return ApiReply(ok: res.statusCode >= 200 && res.statusCode < 300, status: res.statusCode, body: json);
    } catch (_) {
      return const ApiReply(ok: false, status: 0, error: 'network');
    }
  }

  if (timeoutMs == null) return request();
  final timer = Completer<ApiReply>();
  final t = Timer(Duration(milliseconds: timeoutMs), () {
    if (!timer.isCompleted) timer.complete(const ApiReply(ok: false, status: 0, error: 'timeout'));
  });
  final reply = await Future.any([request(), timer.future]);
  t.cancel();
  return reply;
}

/// Upload a file to the bot's media endpoint (multipart "file"). Only a 2xx
/// answer that carries the file's URL is an upload (web nodeLogic.uploadSucceeded).
Future<UploadResult> uploadBotMedia(
  http.Client client,
  String apiOrigin,
  String botId,
  String sessionId,
  String visitorId,
  UploadFile file,
) async {
  final url = Uri.parse('$apiOrigin/api/v1/bot/${Uri.encodeComponent(botId)}/media'
      '?chatSessionId=${Uri.encodeComponent(sessionId)}&visitorId=${Uri.encodeComponent(visitorId)}');
  try {
    final req = http.MultipartRequest('POST', url);
    final name = file.name ?? 'file';
    final bytes = file.bytes ?? _dataUrlBytes(file.dataUrl);
    if (bytes != null) {
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
    } else if (file.uri != null) {
      final path = file.uri!.startsWith('file://') ? Uri.parse(file.uri!).toFilePath() : file.uri!;
      if (File(path).existsSync()) req.files.add(await http.MultipartFile.fromPath('file', path, filename: name));
    }
    final res = await http.Response.fromStream(await client.send(req));
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      json = null;
    }
    final u = json is Map ? json['url'] : null;
    if (res.statusCode >= 200 && res.statusCode < 300 && u is String && u.trim().isNotEmpty) {
      return UploadResult(ok: true, url: u);
    }
    return UploadResult(ok: false, error: 'HTTP ${res.statusCode}');
  } catch (_) {
    return const UploadResult(ok: false, error: 'network');
  }
}

List<int>? _dataUrlBytes(String? dataUrl) {
  if (dataUrl == null) return null;
  final i = dataUrl.indexOf('base64,');
  if (i < 0) return null;
  try {
    return base64Decode(dataUrl.substring(i + 7));
  } catch (_) {
    return null;
  }
}
