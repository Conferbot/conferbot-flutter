/// The integration steps (React Native
/// src/core/nodes/handlers/IntegrationNodeHandlers.ts): webhook, GPT through
/// the server, delay, email, the server-run native integrations (gmail,
/// slack, discord, google sheets / calendar / meet / docs / drive, hubspot,
/// zoho, airtable, notion, stripe), the result integrations (mailchimp,
/// segment, salesforce) and zapier.
///
/// The human-handover step is in special_handlers.dart.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../flow/js.dart';
import '../../state/chat_state.dart';
import '../node_handler.dart';

// ========================================
// SHARED
// ========================================

String _str(dynamic v) => v == null ? '' : (v is String ? v : jsString(v));

/// The workspace the flow runs in.
String _workspaceId(ChatState state) {
  final v = state.getVariable('_workspaceId');
  if (v != null && _str(v).isNotEmpty) return _str(v);
  return state.workspaceId ?? '';
}

/// The transcript as the server reads it: [{by, message}].
List<Map<String, dynamic>> transcriptOf(ChatState state) => state.transcript
    .where((e) => (e.by == 'bot' || e.by == 'user') && e.message.trim().isNotEmpty)
    .map((e) => <String, dynamic>{'by': e.by, 'message': e.message})
    .toList();

/// The answer variables as the server reads them: [{nodeId, key, value}].
List<Map<String, dynamic>> answerVariablesOf(ChatState state) => state.answerVariables
    .map((v) => <String, dynamic>{'nodeId': v.nodeId, 'key': v.key, 'value': v.value})
    .toList();

/// The step's data without the socket client the RN engine slipped in.
Map<String, dynamic> _withoutSocket(Map<String, dynamic> data) =>
    Map<String, dynamic>.from(data)..remove('socketClient');

/// Stores an integration's outcome as internal variables.
void storeIntegrationResult(ChatState state, String prefix, bool success, [dynamic data, String? error]) {
  state.setVariable('_${prefix}Success', success);
  if (success && data != null) state.setVariable('_${prefix}Response', data);
  if (!success && error != null) state.setVariable('_${prefix}Error', error);
}

// ========================================
// 1. WEBHOOK
// ========================================

/// webhook-node: its answerVariable is registered at once and filled later;
/// the call runs in the background and the flow moves on at once (web
/// integrations.ts _handleWebhookNode).
class WebhookHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'webhook-node';

  /// Tokens fetched for OAuth2 / custom auth, by tokenUrl + user.
  static final Map<String, ({String token, DateTime expires})> _tokenCache = {};

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final answerVariable = getString(node.data, 'answerVariable');
    if (answerVariable.isNotEmpty) state.registerAnswerVariable(node.id, answerVariable);
    unawaited(_run(node, state).catchError((_) {}));
    return NodeResult.next();
  }

  /// The HTTP client the engine uses (tests script it), else a new one.
  http.Client _client(FlowNode node) => node.ctx.httpClient ?? http.Client();

  /// The request, in the background; the reply fills the step's variable.
  Future<void> _run(FlowNode node, ChatState state) async {
    final data = node.data;
    final url = getString(data, 'url').isNotEmpty ? getString(data, 'url') : getString(data, 'webhookUrl');
    if (url.isEmpty || !_validUrl(url)) return;
    final method = getString(data, 'method', 'POST').toUpperCase();
    final timeoutMs = getNumber(data, 'timeout', 30000).toInt();
    final retries = getNumber(data, 'retryCount') != 0 ? getNumber(data, 'retryCount').toInt() : getNumber(data, 'maxRetries', 3).toInt();
    final includeAnswers = getBoolean(data, 'includeAnswerVariables', false);
    final rawBody = jsTruthy(data['body']) ? data['body'] : data['payload'];
    final client = _client(node);
    final answers = state.getAnswerVariablesMap();
    final variables = <String, dynamic>{
      ...state.variables,
      ...answers,
      'name': state.userMetadata.name,
      'email': state.userMetadata.email,
      'phone': state.userMetadata.phone,
      ...state.userMetadata.metadata,
      'sessionId': state.chatSessionId,
      'botId': state.botId,
      'timestamp': jsIsoString(node.ctx.now()),
      ...answers,
    };
    final started = node.ctx.now();
    final extracted = <String, dynamic>{};
    String? error;
    _WebhookResponse? response;

    try {
      final auth = _authOf(data);
      var target = _interpolate(url, variables);
      if (auth != null) {
        _interpolateAuth(auth, variables);
        if (auth['type'] == 'apiKey' && auth['apiKeyLocation'] == 'query' && auth['apiKeyName'] != null && auth['apiKeyValue'] != null) {
          final sep = target.contains('?') ? '&' : '?';
          target = '$target$sep${Uri.encodeComponent(_str(auth['apiKeyName']))}=${Uri.encodeComponent(_str(auth['apiKeyValue']))}';
        }
        if (auth['type'] == 'oauth2' && auth['tokenUrl'] != null) {
          auth['token'] = await _fetchOAuth2Token(client, auth);
        } else if (auth['type'] == 'custom' && auth['tokenUrl'] != null) {
          auth['token'] = await _fetchCustomToken(client, auth);
        }
      }
      final headers = <String, String>{};
      if (rawBody != null && method != 'GET') headers['Content-Type'] = 'application/json';
      final h = data['headers'];
      if (h is Map) {
        h.forEach((k, v) => headers[k.toString()] = v is String ? _interpolate(v, variables) : _str(v));
      }
      headers.addAll(_authHeader(auth));
      final body = _prepareBody(method, rawBody, variables, includeAnswers ? answers : null);
      response = await _withRetry(client, node, target, method, headers, body, timeoutMs, retries);
      extracted.addAll(_parseResponse(response.data, _extractOf(data)));
      extracted['_webhookStatusCode'] = response.statusCode;
      extracted['_webhookSuccess'] = response.success;
      if (!response.success) {
        error = response.error;
        extracted['_webhookError'] = error;
      }
    } catch (e) {
      error = e.toString();
      extracted['_webhookError'] = error;
    }
    extracted['_webhookDuration'] = node.ctx.now().difference(started).inMilliseconds;

    extracted.forEach(state.setVariable);
    if (response != null && response.success && response.data != null) {
      state.setAnswerVariable(node.id, response.data);
    } else if (response == null || !response.success) {
      storeIntegrationResult(state, 'webhook', false, null, error);
    }
  }

  bool _validUrl(String url) {
    final u = Uri.tryParse(url.trim());
    if (u == null || (u.scheme != 'http' && u.scheme != 'https') || u.host.isEmpty) return false;
    const release = bool.fromEnvironment('dart.vm.product');
    if (!release) return true;
    const blocked = ['localhost', '127.0.0.1', '0.0.0.0', '::1', '[::1]', 'metadata.google.internal', '169.254.169.254'];
    final host = u.host.toLowerCase();
    if (blocked.contains(host)) return false;
    if (host.startsWith('10.') || host.startsWith('192.168.')) return false;
    final m = RegExp(r'^172\.(\d+)\.').firstMatch(host);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      if (n >= 16 && n <= 31) return false;
    }
    return true;
  }

  /// {{name}} and {{a.b}} from the variables; unknown ones stay as written.
  String _interpolate(String template, Map<String, dynamic> vars) =>
      template.replaceAllMapped(RegExp(r'\{\{([^}]+)\}\}'), (m) {
        final v = _nested(vars, m.group(1)!.trim());
        if (v == null) return m.group(0)!;
        if (v is Map || v is List) return jsonStringify(v);
        return jsString(v);
      });

  dynamic _interpolateDeep(dynamic v, Map<String, dynamic> vars) {
    if (v is String) return _interpolate(v, vars);
    if (v is Map) return v.map((k, x) => MapEntry(k.toString(), _interpolateDeep(x, vars)));
    if (v is List) return v.map((x) => _interpolateDeep(x, vars)).toList();
    return v;
  }

  dynamic _nested(dynamic obj, String path) {
    dynamic cur = obj;
    for (final part in path.split('.')) {
      if (cur is Map) {
        cur = cur[part];
      } else if (cur is List) {
        final i = int.tryParse(part);
        cur = i != null && i >= 0 && i < cur.length ? cur[i] : null;
      } else {
        return null;
      }
    }
    return cur;
  }

  Map<String, dynamic>? _authOf(Map<String, dynamic> data) {
    final a = data['authentication'];
    if (a is! Map) return null;
    final auth = Map<String, dynamic>.from(a);
    final type = _authType(auth);
    if (type == 'none') return null;
    final c = <String, dynamic>{'type': type};
    switch (type) {
      case 'bearer':
        c['token'] = auth['token'] ?? auth['bearerToken'];
      case 'basic':
        c['username'] = auth['username'];
        c['password'] = auth['password'];
      case 'apiKey':
        c['apiKeyName'] = jsTruthy(auth['key']) ? auth['key'] : (jsTruthy(auth['headerName']) ? auth['headerName'] : 'X-API-Key');
        c['apiKeyValue'] = jsTruthy(auth['value']) ? auth['value'] : auth['apiKey'];
        c['apiKeyLocation'] = auth['location'] == 'query' ? 'query' : 'header';
      case 'oauth2':
        c['tokenUrl'] = auth['tokenUrl'];
        c['clientId'] = auth['clientId'];
        c['clientSecret'] = auth['clientSecret'];
        c['scope'] = auth['scope'];
        c['grantType'] = jsTruthy(auth['grantType']) ? auth['grantType'] : 'client_credentials';
      case 'custom':
        c['tokenUrl'] = auth['tokenUrl'];
        c['username'] = auth['username'];
        c['password'] = auth['password'];
        c['tokenPath'] = jsTruthy(auth['tokenPath']) ? auth['tokenPath'] : 'access_token';
        c['expiresInPath'] = jsTruthy(auth['expiresInPath']) ? auth['expiresInPath'] : 'expires_in';
    }
    return c;
  }

  String _authType(Map<String, dynamic> auth) {
    if (jsTruthy(auth['type'])) {
      switch (_str(auth['type']).toLowerCase()) {
        case 'bearer':
          return 'bearer';
        case 'basic':
          return 'basic';
        case 'apikey':
        case 'api_key':
        case 'api-key':
          return 'apiKey';
        case 'oauth2':
        case 'oauth':
          return 'oauth2';
        case 'custom':
        case 'token':
          return 'custom';
        case 'none':
          return 'none';
      }
    }
    bool t(String k) => jsTruthy(auth[k]);
    if (t('token') && !t('tokenUrl')) return 'bearer';
    if (t('apiKey') || t('headerName')) return 'apiKey';
    if (t('clientId') && t('clientSecret')) return 'oauth2';
    if (t('tokenUrl') && t('username')) return 'custom';
    if (t('username') && t('password') && !t('tokenUrl')) return 'basic';
    return 'none';
  }

  void _interpolateAuth(Map<String, dynamic> c, Map<String, dynamic> vars) {
    for (final k in ['token', 'username', 'password', 'apiKeyValue', 'tokenUrl', 'clientId', 'clientSecret']) {
      if (jsTruthy(c[k])) c[k] = _interpolate(_str(c[k]), vars);
    }
  }

  Map<String, String> _authHeader(Map<String, dynamic>? c) {
    if (c == null) return const {};
    switch (c['type']) {
      case 'bearer':
      case 'oauth2':
      case 'custom':
        return jsTruthy(c['token']) ? {'Authorization': 'Bearer ${_str(c['token'])}'} : const {};
      case 'basic':
        if (!jsTruthy(c['username'])) return const {};
        final creds = '${_str(c['username'])}:${c['password'] == null ? '' : _str(c['password'])}';
        return {'Authorization': 'Basic ${base64Encode(utf8.encode(creds))}'};
      case 'apiKey':
        if (jsTruthy(c['apiKeyName']) && jsTruthy(c['apiKeyValue']) && c['apiKeyLocation'] != 'query') {
          return {_str(c['apiKeyName']): _str(c['apiKeyValue'])};
        }
    }
    return const {};
  }

  String? _cached(String key) {
    final c = _tokenCache[key];
    if (c == null || DateTime.now().isAfter(c.expires)) return null;
    return c.token;
  }

  Future<String> _fetchOAuth2Token(http.Client client, Map<String, dynamic> c) async {
    if (!jsTruthy(c['tokenUrl']) || !jsTruthy(c['clientId']) || !jsTruthy(c['clientSecret'])) {
      throw Exception('Failed to fetch OAuth2 token');
    }
    final key = 'oauth2:${c['tokenUrl']}:${c['clientId']}';
    final hit = _cached(key);
    if (hit != null) return hit;
    try {
      final res = await client.post(
        Uri.parse(_str(c['tokenUrl'])),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': _str(c['grantType'] ?? 'client_credentials'),
          'client_id': _str(c['clientId']),
          'client_secret': _str(c['clientSecret']),
          if (jsTruthy(c['scope'])) 'scope': _str(c['scope']),
        },
      );
      if (res.statusCode < 200 || res.statusCode >= 300) throw Exception('HTTP ${res.statusCode}');
      final json = jsonDecode(res.body);
      final token = json is Map ? json['access_token'] : null;
      if (token == null) throw Exception('No access_token');
      final exp = json['expires_in'] is num ? (json['expires_in'] as num).toInt() : 3600;
      _tokenCache[key] = (token: _str(token), expires: DateTime.now().add(Duration(seconds: exp)));
      return _str(token);
    } catch (_) {
      throw Exception('Failed to fetch OAuth2 token');
    }
  }

  Future<String> _fetchCustomToken(http.Client client, Map<String, dynamic> c) async {
    if (!jsTruthy(c['tokenUrl']) || !jsTruthy(c['username'])) throw Exception('Failed to fetch custom token');
    final key = 'custom:${c['tokenUrl']}:${c['username']}';
    final hit = _cached(key);
    if (hit != null) return hit;
    try {
      final res = await client.post(
        Uri.parse(_str(c['tokenUrl'])),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'username': c['username'], 'password': c['password'] ?? ''}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) throw Exception('HTTP ${res.statusCode}');
      final json = jsonDecode(res.body);
      final token = _nested(json, _str(c['tokenPath'] ?? 'access_token'));
      if (!jsTruthy(token)) throw Exception('No token');
      final exp = jsNumber(_nested(json, _str(c['expiresInPath'] ?? 'expires_in')) ?? 3600);
      _tokenCache[key] = (token: _str(token), expires: DateTime.now().add(Duration(seconds: exp.isFinite ? exp.toInt() : 3600)));
      return _str(token);
    } catch (_) {
      throw Exception('Failed to fetch custom token');
    }
  }

  String? _prepareBody(String method, dynamic body, Map<String, dynamic> vars, Map<String, dynamic>? answers) {
    if (method == 'GET' || body == null) return null;
    dynamic out;
    if (body is String) {
      try {
        out = _interpolateDeep(jsonDecode(body), vars);
      } catch (_) {
        return _interpolate(body, vars);
      }
    } else if (body is Map || body is List) {
      out = _interpolateDeep(body, vars);
    } else {
      return null;
    }
    if (answers != null && out is Map) out['answerVariables'] = answers;
    return jsonStringify(out);
  }

  Map<String, dynamic>? _extractOf(Map<String, dynamic> data) {
    final e = data['responseExtract'] ?? data['extract'];
    final variableName = getString(data, 'variableName').isNotEmpty ? getString(data, 'variableName') : getString(data, 'answerVariable');
    if (e is! Map) {
      if (variableName.isNotEmpty) return {'storeFullResponse': true, 'fullResponseVariableName': variableName};
      return null;
    }
    final c = <String, dynamic>{};
    if (jsTruthy(e['path'])) {
      c['path'] = e['path'];
      c['variableName'] = jsTruthy(e['variableName']) ? e['variableName'] : getString(data, 'variableName');
    }
    if (e['extractions'] is List) c['extractions'] = e['extractions'];
    if (e['storeFullResponse'] != false) {
      c['storeFullResponse'] = true;
      c['fullResponseVariableName'] = jsTruthy(e['fullResponseVariableName']) ? e['fullResponseVariableName'] : '_webhookResponse';
    }
    return c;
  }

  Map<String, dynamic> _parseResponse(dynamic response, Map<String, dynamic>? c) {
    final out = <String, dynamic>{};
    if (c == null || !jsTruthy(response)) return out;
    if (c['storeFullResponse'] == true) out[_str(c['fullResponseVariableName'] ?? '_webhookResponse')] = response;
    if (jsTruthy(c['path']) && jsTruthy(c['variableName'])) {
      final v = _nested(response, _str(c['path']));
      if (v != null) out[_str(c['variableName'])] = v;
    }
    final list = c['extractions'];
    if (list is List) {
      for (final x in list) {
        if (x is Map && jsTruthy(x['path']) && jsTruthy(x['variableName'])) {
          out[_str(x['variableName'])] = _nested(response, _str(x['path'])) ?? x['defaultValue'];
        }
      }
    }
    return out;
  }

  Future<_WebhookResponse> _withRetry(http.Client client, FlowNode node, String url, String method,
      Map<String, String> headers, String? body, int timeoutMs, int maxRetries) async {
    _WebhookResponse? last;
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final r = await _once(client, url, method, headers, body, timeoutMs);
        if (r.success || !const [408, 429, 500, 502, 503, 504].contains(r.statusCode)) return r;
        last = r;
      } catch (e) {
        lastError = e;
        final network = e is http.ClientException || e.toString().toLowerCase().contains('network') || e.toString().contains('SocketException');
        if (!network && attempt == 0) rethrow;
      }
      if (attempt < maxRetries) {
        final exp = (1 << attempt) * 1000.0;
        final backoff = (exp + node.ctx.random() * exp * 0.1).clamp(0, 30000).toInt();
        await node.ctx.delay(backoff);
      }
    }
    return last ??
        _WebhookResponse(false, -1, null, lastError?.toString() ?? 'All retry attempts exhausted');
  }

  Future<_WebhookResponse> _once(http.Client client, String url, String method, Map<String, String> headers, String? body, int timeoutMs) async {
    final req = http.Request(method, Uri.parse(url));
    req.headers.addAll(headers);
    if (body != null && method != 'GET') req.body = body;
    final timeout = Completer<_WebhookResponse>();
    final t = Timer(Duration(milliseconds: timeoutMs), () {
      if (!timeout.isCompleted) timeout.complete(_WebhookResponse(false, 408, null, 'Request timeout'));
    });
    Future<_WebhookResponse> send() async {
      final res = await http.Response.fromStream(await client.send(req));
      dynamic data;
      final type = res.headers['content-type'] ?? '';
      if (type.contains('application/json')) {
        try {
          data = jsonDecode(res.body);
        } catch (_) {
          data = res.body;
        }
      } else {
        data = res.body;
      }
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      return _WebhookResponse(ok, res.statusCode, data, ok ? null : 'HTTP ${res.statusCode}: ${res.reasonPhrase ?? ''}');
    }

    try {
      return await Future.any([send(), timeout.future]);
    } finally {
      t.cancel();
    }
  }
}

class _WebhookResponse {
  final bool success;
  final int statusCode;
  final dynamic data;
  final String? error;

  _WebhookResponse(this.success, this.statusCode, this.data, this.error);
}

// ========================================
// 2. GPT
// ========================================

/// The most turns of the conversation sent with a GPT step.
const int gptMaxTurns = 30;

/// gpt-node: the server makes the AI call with the owner's key (it strips
/// apiKey from every flow it sends): POST {api}/api/v1/bot/:botId/gpt with
/// {nodeId, transcript (last 30 {by, message})} -> {reply}. The reply is
/// shown after 1000 ms of typing; a failed call shows nothing. Either way
/// the flow moves on along the first edge (web gptRequest.ts).
class GPTHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'gpt-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final all = transcriptOf(state);
    final transcript = all.length > gptMaxTurns ? all.sublist(all.length - gptMaxTurns) : all;
    final reply = await node.ctx.api('gpt', {'nodeId': node.id, 'transcript': transcript});
    final body = reply.body;
    final text = reply.ok && body is Map && body['reply'] is String ? body['reply'] as String : '';
    if (text.isEmpty) {
      storeIntegrationResult(state, 'gpt', false, null, reply.error ?? 'HTTP ${reply.status}');
      return NodeResult.next();
    }
    state.addRecord({'_id': node.id, 'id': node.id, 'shape': 'gpt-node-response', 'value': text, 'time': jsIsoString(node.ctx.now())});
    await node.ctx.typing(1000);
    state.addBotMessage(text, node.id, nodeType);
    storeIntegrationResult(state, 'gpt', true);
    return NodeResult.next({'gptResponse': text});
  }
}

// ========================================
// 3. DELAY
// ========================================

/// delay-node: shows nothing, waits data.delay seconds (missing: no wait),
/// then the first edge.
class DelayHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'delay-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final seconds = jsNumber(node.data.containsKey('delay') ? node.data['delay'] : double.nan);
    final delayMs = seconds.isFinite && seconds > 0 ? (seconds * 1000 < 600000 ? seconds * 1000 : 600000.0) : 0.0;
    final ms = jsNum(delayMs);
    state.setVariable('_lastDelay', ms);
    if (delayMs == 0) return NodeResult.next();
    return NodeResult.delayedProceed(null, delayMs.round(), {'delayMs': ms});
  }
}

// ========================================
// 4. EMAIL
// ========================================

/// email-node: emits "email-node-trigger" with the node data, the
/// transcript, the visitor and every answer, and moves on at once. Reached
/// by a jump-to-node it sends nothing and only moves on (web index.ts).
class EmailHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'email-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ctx = node.ctx;
    if (ctx.via == 'jump') return NodeResult.next();
    final meta = state.userMetadata;
    final payload = <String, dynamic>{
      'nodeData': _withoutSocket(node.data),
      'botName': state.getVariable('_botName') ?? '',
      'transcript': transcriptOf(state),
      'visitorName': meta.name ?? '',
      'visitorEmail': meta.email ?? '',
    };
    for (final v in state.answerVariables) {
      payload[v.key] = v.value;
    }
    payload['answerVariables'] = answerVariablesOf(state);
    payload['chatDate'] = jsIsoString(ctx.now());
    payload['workspaceId'] = _workspaceId(state);
    ctx.emit('email-node-trigger', payload);
    return NodeResult.next();
  }
}

// ========================================
// 5. NATIVE INTEGRATIONS (server-run)
// ========================================

/// Runs a step on the embed server: emits "execute-integration" with the
/// step's own data and resolves with the "integration-result" for this
/// step, or a failure after 30 s. On success, result.answerVariable =
/// answerValue and every columnMappedValues entry are saved by name (web
/// _executeNativeIntegration).
Future<Map<String, dynamic>> executeNativeIntegration(
  FlowContext ctx,
  ChatState state,
  String nodeType,
  String nodeId,
  Map<String, dynamic> nodeData, [
  int timeoutMs = 30000,
]) {
  final done = Completer<Map<String, dynamic>>();
  Timer? timer;
  void Function() off = () {};
  void finish(Map<String, dynamic> result) {
    if (done.isCompleted) return;
    timer?.cancel();
    off();
    done.complete(result);
  }

  off = ctx.on('integration-result', (dynamic result) {
    if (result is! Map || result['nodeId']?.toString() != nodeId) return;
    final r = Map<String, dynamic>.from(result);
    if (r['success'] == true) {
      final av = r['answerVariable'];
      if (jsTruthy(av) && r.containsKey('answerValue')) state.saveVariableByName(_str(av), r['answerValue']);
      final cols = r['columnMappedValues'];
      if (cols is Map) {
        cols.forEach((name, value) {
          if (jsTruthy(name)) state.saveVariableByName(name.toString(), value);
        });
      }
    }
    finish(r);
  });
  final sent = ctx.emit('execute-integration', {
    'nodeType': nodeType,
    'nodeId': nodeId,
    'nodeData': _withoutSocket(nodeData),
    'chatSessionId': state.chatSessionId,
    'chatbotId': state.botId,
    'workspaceId': _workspaceId(state),
    'answerVariables': answerVariablesOf(state),
    'visitorData': <String, dynamic>{},
  });
  if (!sent) {
    finish({'success': false, 'error': 'Socket not connected'});
  } else if (!done.isCompleted) {
    timer = Timer(Duration(milliseconds: timeoutMs),
        () => finish({'success': false, 'error': 'Integration execution timed out', 'continueFlow': true}));
  }
  return done.future;
}

dynamic _resultData(Map<String, dynamic> r, String key) {
  final d = r['data'];
  return d is Map ? d[key] : null;
}

/// A server-run integration that does not hold the flow (gmail, google
/// sheets / docs / drive, slack, discord, airtable, hubspot, notion,
/// zohocrm): the step data goes to the server and the flow moves on at
/// once; values that come back later fill variables.
class NativeIntegrationHandler extends BaseNodeHandler {
  final String _type;

  NativeIntegrationHandler(this._type);

  @override
  String get nodeType => _type;

  /// The node type the server runs (google-sheets runs as its read / write node).
  String serverType(Map<String, dynamic> data) => nodeType;

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ctx = node.ctx;
    unawaited(executeNativeIntegration(ctx, state, serverType(node.data), node.id, node.data).then((result) {
      state.addRecord({
        '_id': node.id,
        'id': node.id,
        'shape': nodeType,
        'data': {
          'result': {'success': result['success'] == true, 'error': jsTruthy(result['error']) ? result['error'] : null},
        },
        'time': jsIsoString(ctx.now()),
      });
    }));
    return NodeResult.next();
  }
}

/// google-sheets-node: runs on the server as google-sheets-read-node or
/// -write-node (data.operation).
class GoogleSheetsHandler extends NativeIntegrationHandler {
  GoogleSheetsHandler() : super('google-sheets-node');

  @override
  String serverType(Map<String, dynamic> data) {
    final inputs = data['inputs'];
    final op = jsTruthy(data['operation'])
        ? data['operation']
        : (inputs is Map && jsTruthy(inputs['operation']) ? inputs['operation'] : 'read');
    return op == 'write' ? 'google-sheets-write-node' : 'google-sheets-read-node';
  }
}

/// google-calendar-node: an operation other than "book" runs in the
/// background and the flow moves on at once; "book" waits for the server
/// (the web's slot picker is web-only) and then moves on.
class GoogleCalendarHandler extends NativeIntegrationHandler {
  GoogleCalendarHandler() : super('google-calendar-node');

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final op = jsTruthy(node.data['operation']) ? node.data['operation'] : 'list';
    if (op != 'book') return super.handle(node, state);
    await executeNativeIntegration(node.ctx, state, nodeType, node.id, node.data);
    return NodeResult.next();
  }
}

/// google-meet-node: waits for the server's result (30 s at most), then the
/// first edge.
class GoogleMeetHandler extends NativeIntegrationHandler {
  GoogleMeetHandler() : super('google-meet-node');

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final result = await executeNativeIntegration(node.ctx, state, nodeType, node.id, node.data);
    if (result['success'] == true && !jsTruthy(result['waitForInput'])) {
      state.addRecord({
        '_id': node.id,
        'id': node.id,
        'shape': 'google-meet-node',
        'data': {
          'summary': node.data['summary'],
          'meetingUri': jsTruthy(_resultData(result, 'meetingUri')) ? _resultData(result, 'meetingUri') : null,
          'eventLink': jsTruthy(_resultData(result, 'eventLink')) ? _resultData(result, 'eventLink') : null,
          'booking': jsTruthy(_resultData(result, 'booking')) ? _resultData(result, 'booking') : null,
          'result': {'success': true, 'error': null},
        },
        'time': jsIsoString(node.ctx.now()),
      });
    }
    return NodeResult.next();
  }
}

/// stripe-node: the server makes the payment link; it is shown and the flow
/// moves on 500 ms later. It never waits for the payment (payment-node does).
class StripeHandler extends NativeIntegrationHandler {
  StripeHandler() : super('stripe-node');

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final op = jsTruthy(node.data['operation']) ? _str(node.data['operation']) : 'createPaymentLink';
    final result = await executeNativeIntegration(node.ctx, state, nodeType, node.id, node.data);
    dynamic orNull(dynamic v) => jsTruthy(v) ? v : null;
    final url = _resultData(result, 'url');
    state.addRecord({
      '_id': node.id,
      'id': node.id,
      'shape': 'stripe-node',
      'data': {
        'operation': op,
        'url': orNull(url),
        'id': orNull(_resultData(result, 'id')),
        'customerId': orNull(_resultData(result, 'customerId')),
        'message': orNull(result['message']),
        'result': {'success': result['success'] == true, 'error': orNull(result['error'])},
      },
      'time': jsIsoString(node.ctx.now()),
    });
    if (result['success'] == true && jsTruthy(url)) {
      if (op == 'createPaymentLink' || op == 'createCheckoutSession') {
        final text = [result['message'], url].where(jsTruthy).map(_str).join('\n');
        state.addBotMessage(text, node.id, nodeType, {'linkUrl': _str(url)});
      }
      return NodeResult.delayedProceed(null, 500);
    }
    return NodeResult.next();
  }
}

/// mailchimp / segment / salesforce: the flow waits for the server, then
/// success leaves by "source" (or an edge with no handle), failure by
/// "source-failure" - or the success edge when no failure edge is drawn.
class ResultIntegrationHandler extends NativeIntegrationHandler {
  ResultIntegrationHandler(super.type);

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ctx = node.ctx;
    final result = await executeNativeIntegration(ctx, state, nodeType, node.id, node.data);
    final outgoing = ctx.edges();
    bool isSuccess(Map<String, dynamic> e) => e['sourceHandle'] == 'source' || e['sourceHandle'] == null;
    Map<String, dynamic>? successEdge;
    for (final e in outgoing) {
      if (isSuccess(e)) {
        successEdge = e;
        break;
      }
    }
    Map<String, dynamic>? edge;
    if (result['success'] == true) {
      edge = successEdge;
    } else {
      for (final e in outgoing) {
        if (e['sourceHandle'] == 'source-failure') {
          edge = e;
          break;
        }
      }
      edge ??= successEdge;
    }
    if (edge == null) return NodeResult.next();
    if (edge['sourceHandle'] == null) return NodeResult.jumpTo(_str(edge['target']));
    return NodeResult.port(_str(edge['sourceHandle']));
  }
}

// ========================================
// 6. ZAPIER
// ========================================

/// zapier-node: when the bot has an active webhook for the node, relays the
/// answers through the server ("zapier-node-trigger"); moves on at once.
class ZapierHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'zapier-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final data = node.data;
    final fromVar = state.getVariable('_integrationWebhooks');
    final webhooks = fromVar is List ? fromVar : state.integrationWebhooks;
    final wantedId = data['nodeId'] ?? node.id;
    Map? hook;
    for (final w in webhooks) {
      if (w is Map && w['nodeId'] == wantedId && w['botId'] == state.botId && jsTruthy(w['active'])) {
        hook = w;
        break;
      }
    }
    if (hook == null || !jsTruthy(hook['webhookURL'])) return NodeResult.next();
    node.ctx.emit('zapier-node-trigger', {
      'nodeData': {..._withoutSocket(data), 'nodeId': wantedId, 'webhookURL': hook['webhookURL']},
      'payload': state.getAnswerVariablesMap(),
      'chatSessionId': state.chatSessionId,
      'workspaceId': _workspaceId(state),
    });
    return NodeResult.next();
  }
}

// ========================================
// REGISTRATION
// ========================================

/// Every integration step's handler (the handover step is in special_handlers.dart).
final List<NodeHandler> integrationHandlers = [
  WebhookHandler(),
  GPTHandler(),
  DelayHandler(),
  EmailHandler(),
  NativeIntegrationHandler('gmail-node'),
  NativeIntegrationHandler('slack-node'),
  NativeIntegrationHandler('discord-node'),
  GoogleSheetsHandler(),
  GoogleCalendarHandler(),
  GoogleMeetHandler(),
  NativeIntegrationHandler('google-docs-node'),
  NativeIntegrationHandler('google-drive-node'),
  NativeIntegrationHandler('hubspot-node'),
  ResultIntegrationHandler('salesforce-node'),
  ResultIntegrationHandler('segment-node'),
  NativeIntegrationHandler('zohocrm-node'),
  ResultIntegrationHandler('mailchimp-node'),
  ZapierHandler(),
  NativeIntegrationHandler('airtable-node'),
  NativeIntegrationHandler('notion-node'),
  StripeHandler(),
];
