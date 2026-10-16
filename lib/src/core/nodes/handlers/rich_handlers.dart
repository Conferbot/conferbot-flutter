/// The rich steps (conferbot-widget/src/ts/chat/richNodes.ts and
/// richNodesView.ts), run headless: dynamic-choices, hidden-fields, consent,
/// product-card, slider, datetime, ranking, otp, address, matrix,
/// ai-extract, ai-route, kb-answer, signature and payment. A port of the
/// React Native SDK's src/core/nodes/handlers/RichNodeHandlers.ts; the
/// rules are the web's, ported in core/flow/rich.dart.
///
/// Gates stay gates: payment leaves by "source" only when the server says
/// paid, OTP only when otp/verify says verified (the web's documented
/// fallback aside), required consent only once agreed.
library;

import 'dart:async';
import 'dart:math' as math;

import '../../flow/i18n_en.dart';
import '../../flow/inputs.dart' show linkHref;
import '../../flow/js.dart';
import '../../flow/rich.dart';
import '../../state/chat_state.dart';
import '../node_handler.dart';
import '../node_ui_state.dart';
import 'flow_kit.dart';

/// A server call as the rich steps read it (web richApi.ts richPost).
class _RichReply {
  final bool ok;
  final int status;
  final dynamic data;
  final String? code;

  const _RichReply(this.ok, this.status, this.data, [this.code]);
}

Future<_RichReply> _richPost(FlowContext ctx, String path, Map<String, dynamic> body, [int timeoutMs = 15000]) async {
  final r = await ctx.api(path, body, timeoutMs: timeoutMs);
  if (r.error != null) return _RichReply(false, 0, null, r.error);
  String? code;
  if (!r.ok) {
    final c = r.body is Map ? r.body['code'] : null;
    code = jsTruthy(c) ? jsString(c) : (r.status == 429 ? 'rate_limited' : 'error');
  }
  return _RichReply(r.ok, r.status, r.body, code);
}

/// A field of a server reply (null when the reply is not an object).
dynamic _f(dynamic data, String key) => data is Map ? data[key] : null;

/// Who a code / payment belongs to: the chat session (web richSessionId).
String _sessionOf(ChatState state) {
  dynamic v = state.chatSessionId;
  if (!jsTruthy(v)) v = state.getVariable('_visitorId');
  if (!jsTruthy(v)) v = 'anonymous';
  final s = jsString(v);
  return s.length > 100 ? s.substring(0, 100) : s;
}

/// A variable read the way the rich steps read it: the answers, by name.
dynamic Function(String key) _lookup(ChatState state) =>
    (key) => state.hasAnswerVariable(key) ? state.getAnswer(key) : null;

String _answerKey(FlowNode node) => jsString(node.data['answerVariable'] ?? '').trim();

/// Fills the step's own variable (registered when shown) and the rest by name.
void _saveVars(ChatState state, FlowNode node, Map<String, dynamic> vars) {
  final key = _answerKey(node);
  vars.forEach((k, v) => k == key ? state.setAnswerVariable(node.id, v) : state.saveVariableByName(k, v));
}

/// The visitor's answer (web richNodesView answer()): record, transcript, the step's variable.
void _answer(ChatState state, FlowNode node, Map<String, dynamic> entry, String text, dynamic value) {
  pushAnswer(state, {'id': node.id, ...entry}, node.ctx.now());
  userSay(state, text, node.id);
  if (jsTruthy(node.data['answerVariable'])) state.setAnswerVariable(node.id, value);
}

String _iso(FlowNode node) => jsIsoString(node.ctx.now());

abstract class _RichHandler extends BaseNodeHandler {
  String prompt(FlowNode node, ChatState state, [String fallback = '']) {
    final q = node.data['questionText'];
    return shownText(state, plainText(q).isNotEmpty ? q : fallback);
  }
}

// ========================================
// DYNAMIC CHOICES
// ========================================

/// dynamic-choices-node: options from the list in data.sourceVariable
/// (labelField / valueField); saves the item's value and <var>_label when it
/// differs. Nothing to choose: emptyMessage and source-empty (or "source"
/// when only that is wired). "webhook" waits up to 8 s for the list.
class DynamicChoicesHandler extends _RichHandler {
  @override
  String get nodeType => 'dynamic-choices-node';

  Future<dynamic> _sourceValue(FlowNode node, ChatState state) async {
    final key = dynamicSourceVariable(node.data);
    dynamic read() => key.isNotEmpty ? _lookup(state)(key) : null;
    var v = read();
    if (v != null || node.data['source'] != 'webhook') return v;
    final started = node.ctx.now().millisecondsSinceEpoch;
    while (node.ctx.now().millisecondsSinceEpoch - started <= 8000) {
      await node.ctx.delay(250);
      v = read();
      if (v != null) return v;
    }
    return v;
  }

  SingleChoiceUIState _ui(FlowNode node, ChatState state, List<DynamicOption> options) => SingleChoiceUIState(
        nodeId: node.id,
        questionText: prompt(node, state),
        choices: options.map((o) => ChoiceOption(id: o.id, text: o.label, value: o.value)).toList(),
      );

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final options = dynamicOptions(node.data, await _sourceValue(node, state));
    state.addRecord({
      '_id': node.id,
      'id': node.id,
      'type': node.type,
      'options': options.map((o) => {'label': o.label, 'value': o.value}).toList(),
    });
    if (options.isEmpty) {
      final e = node.data['emptyMessage'];
      final empty = jsTruthy(e) ? e : '<p>${t('rich.nothingToChoose')}</p>';
      botSay(state, shownText(state, empty), node.id, nodeType);
      return NodeResult.port(dynamicEmptyHandle, fallback: 'source');
    }
    final ui = _ui(node, state, options);
    botSay(state, ui.questionText ?? '', node.id, nodeType);
    state.setVariable('_dyn_${node.id}', options);
    return NodeResult.displayUI(ui);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final stored = state.getVariable('_dyn_${node.id}');
    final options = stored is List<DynamicOption> ? stored : <DynamicOption>[];
    final id = pickedId(response);
    DynamicOption? o;
    for (final x in options) {
      if (x.id == id) {
        o = x;
        break;
      }
    }
    final index = _f(response, 'index');
    if (o == null && index is int && index >= 0 && index < options.length) o = options[index];
    if (o == null) return NodeResult.displayUI(_ui(node, state, options));
    _answer(state, node, {'shape': 'user-selected-dynamic-choice', 'selectedChoice': o.label, 'value': o.value}, o.label, o.value);
    final key = node.data['answerVariable'];
    if (jsTruthy(key) && jsString(o.value) != o.label) state.saveVariableByName('${jsString(key)}_label', o.label);
    state.deleteVariable('_dyn_${node.id}');
    return NodeResult.port('source');
  }
}

// ========================================
// HIDDEN FIELDS
// ========================================

/// hidden-fields-node: shows nothing; saves the page's query parameters, its
/// URL and the referrer by name. An app has no page: the host app supplies
/// one (NodeFlowEngineConfig.page, e.g. a deep link) or nothing is captured.
class HiddenFieldsHandler extends _RichHandler {
  @override
  String get nodeType => 'hidden-fields-node';

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final page = node.ctx.page ?? const <String, String>{};
    Map<String, String> captured;
    try {
      captured = captureHiddenFields(node.data, {'href': page['url'], 'referrer': page['referrer'], 'landingSearch': ''});
    } catch (_) {
      captured = {};
    }
    captured.forEach((k, v) => state.saveVariableByName(k, v));
    state.addRecord({'_id': node.id, 'id': node.id, 'type': node.type, 'captured': captured});
    return NodeResult.port('source');
  }
}

// ========================================
// CONSENT
// ========================================

/// consent-node: the consent text and Continue. Answers: {agreed: bool}
/// (the box ticked or not, then Continue), or the buttons "agree" /
/// "continue". Required and not agreed: "Please tick the box to continue."
/// and it waits. Saves true / false and <var>_at; always leaves by "source".
class ConsentHandler extends _RichHandler {
  @override
  String get nodeType => 'consent-node';

  SingleChoiceUIState _ui(FlowNode node, ChatState state) {
    final text = markdownLitePlain(node.data['consentText']);
    return SingleChoiceUIState(
      nodeId: node.id,
      questionText: prompt(node, state),
      choices: [
        ChoiceOption(id: 'agree', text: text.isNotEmpty ? '✓ $text' : t('sdk.consent.agree'), value: true),
        ChoiceOption(id: 'continue', text: consentContinueLabel(node.data), value: false),
      ],
      // The card draws the text with its links (markdown-lite) and a box to tick.
      extra: {
        'step': 'consent',
        'required': consentRequired(node.data),
        'consentText': text,
        'markdown': jsString(node.data['consentText'] ?? ''),
        'continueLabel': consentContinueLabel(node.data),
      },
    );
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    if ((ui.questionText ?? '').isNotEmpty) botSay(state, ui.questionText!, node.id, nodeType);
    return NodeResult.displayUI(ui, awaitInput: true);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final data = node.data;
    final a = _f(response, 'agreed');
    final agreed = a is bool ? a : pickedId(response) == 'agree';
    final required = consentRequired(data);
    if (required && !agreed) return NodeResult.invalid(t('consent.tickBox'), uiState: _ui(node, state), inCard: true);
    final at = _iso(node);
    final reply = consentReply(data['consentText'], agreed);
    _answer(
      state,
      node,
      {
        'shape': 'user-consent',
        'agreed': agreed,
        'agreedAt': agreed ? at : null,
        'consentText': markdownLitePlain(data['consentText']),
        'documents': consentDocuments(data['consentText']),
        'required': required,
        'selectedChoice': reply,
      },
      reply,
      agreed,
    );
    final k = data['answerVariable'];
    if (jsTruthy(k) && agreed) state.saveVariableByName('${jsString(k)}_at', at);
    return NodeResult.port('source');
  }
}

// ========================================
// PRODUCT CARD
// ========================================

const String _carouselContinue = 'Continue';

/// The card as the web reads it (nodeKit carouselCards), the first one.
Map<String, dynamic>? _productCard(Map<String, dynamic> data) {
  final cards = productCarouselData(data)['cards'] as List;
  for (var ci = 0; ci < cards.length; ci++) {
    final card = cards[ci];
    final rawButtons = _f(card, 'buttons');
    final buttons = <Map<String, dynamic>>[];
    if (rawButtons is List) {
      for (var bi = 0; bi < rawButtons.length; bi++) {
        final b = rawButtons[bi];
        final action = _f(b, 'action') == 'link' ? 'link' : 'path';
        final btn = {
          'id': jsString(_f(b, 'id') ?? '$ci-$bi'),
          'label': jsString(_f(b, 'label') ?? '').trim(),
          'action': action,
          'href': action == 'link' ? linkHref(_f(b, 'url')) : '',
        };
        if ((btn['label'] as String).isNotEmpty && (action == 'path' || (btn['href'] as String).isNotEmpty)) buttons.add(btn);
        if (buttons.length == 3) break;
      }
    }
    final out = {
      'id': jsString(_f(card, 'id') ?? 'card-$ci'),
      'image': jsString(_f(card, 'image') ?? '').trim(),
      'title': jsString(_f(card, 'title') ?? '').trim(),
      'description': jsString(_f(card, 'description') ?? '').trim(),
      'price': jsString(_f(card, 'price') ?? '').trim(),
      'buttons': buttons,
    };
    if ((out['title'] as String).isNotEmpty || (out['description'] as String).isNotEmpty || (out['image'] as String).isNotEmpty) {
      return out;
    }
  }
  return null;
}

List<Map<String, dynamic>> _buttonsOf(Map<String, dynamic>? card) =>
    card == null ? const [] : (card['buttons'] as List).cast<Map<String, dynamic>>();

/// product-card-node: one card (image, title, price, description) with up
/// to three buttons. A path button leaves by "source-" + its id and saves
/// its label; with only link buttons, Continue leaves by "source".
class ProductCardHandler extends _RichHandler {
  @override
  String get nodeType => 'product-card-node';

  CarouselUIState _ui(FlowNode node, ChatState state) {
    final card = _productCard(node.data);
    final buttons = _buttonsOf(card);
    final hasPath = buttons.any((b) => b['action'] == 'path');
    final desc = card == null
        ? ''
        : [card['price'], card['description']].where((x) => (x as String).isNotEmpty).join(' · ');
    return CarouselUIState(
      nodeId: node.id,
      questionText: prompt(node, state),
      showContinue: !hasPath,
      cards: card == null
          ? const []
          : [
              CarouselCard(
                id: card['id'] as String,
                title: shownLabel(state, card['title']),
                description: desc.isEmpty ? null : desc,
                imageUrl: (card['image'] as String).isEmpty ? null : card['image'] as String,
                buttons: buttons
                    .map((b) => CarouselButton(
                        id: b['id'] as String,
                        label: b['label'] as String,
                        url: (b['href'] as String).isEmpty ? null : b['href'] as String))
                    .toList(),
              ),
            ],
    );
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    final q = ui.questionText ?? '';
    if (q.isNotEmpty) botSay(state, q, node.id, nodeType);
    return NodeResult.displayUI(ui);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final card = _productCard(node.data);
    final buttons = _buttonsOf(card);
    final id = _f(response, 'action') == 'continue' ? null : pickedId(response);
    Map<String, dynamic>? button;
    for (final b in buttons) {
      if (b['id'] == id && b['action'] == 'path') {
        button = b;
        break;
      }
    }
    if (id != null && id.isNotEmpty && button == null) return NodeResult.displayUI(_ui(node, state));
    if (button != null) {
      final label = button['label'] as String;
      _answer(
        state,
        node,
        {
          'shape': 'user-selected-product-card',
          'selectedChoice': label,
          'selectedButtonId': button['id'],
          'product': {'title': card!['title'], 'price': card['price'] ?? ''},
        },
        label,
        label,
      );
      return NodeResult.port('source-${button['id']}');
    }
    if (buttons.any((b) => b['action'] == 'path')) return NodeResult.displayUI(_ui(node, state));
    pushAnswer(state, {'id': node.id, 'shape': 'user-selected-product-card', 'selectedChoice': _carouselContinue, 'selectedButtonId': null},
        node.ctx.now());
    userSay(state, _carouselContinue, node.id);
    return NodeResult.port('source');
  }
}

// ========================================
// SLIDER
// ========================================

/// slider-node: min / max / step / unit; the value snapped to the step,
/// saved as a number. Answer {value}.
class SliderNodeHandler extends _RichHandler {
  @override
  String get nodeType => 'slider-node';

  SliderUIState _ui(FlowNode node, ChatState state) {
    final cfg = sliderConfig(node.data);
    return SliderUIState(
      nodeId: node.id,
      questionText: prompt(node, state),
      min: cfg.min,
      max: cfg.max,
      step: cfg.step,
      defaultValue: cfg.start,
      unit: cfg.unit,
      unitPosition: cfg.unitPosition,
      submitLabel: submitLabel(node.data),
    );
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    botSay(state, ui.questionText ?? '', node.id, nodeType);
    return NodeResult.displayUI(ui);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final cfg = sliderConfig(node.data);
    final raw = jsNumber(response is Map ? response['value'] : response);
    if (!raw.isFinite) return NodeResult.displayUI(_ui(node, state));
    final value = snapToStep(raw, min: cfg.min, max: cfg.max, step: cfg.step);
    final text = sliderLabel(value, unit: cfg.unit, unitPosition: cfg.unitPosition);
    _answer(state, node, {'shape': 'user-slider', 'value': value, 'display': text, 'min': cfg.min, 'max': cfg.max, 'unit': cfg.unit}, text,
        value);
    return NodeResult.port('source');
  }
}

// ========================================
// DATE / TIME
// ========================================

/// datetime-node: mode date / time / datetime with minDate / maxDate,
/// disabledWeekdays, minTime / maxTime. A refused pick says why on the
/// card. Saves the ISO value and <var>_display. Answer {value}
/// ("2026-10-19", "14:30", "2026-10-19T14:30") or the calendar's {date, time}.
class DateTimeNodeHandler extends _RichHandler {
  @override
  String get nodeType => 'datetime-node';

  CalendarUIState _ui(FlowNode node, ChatState state) {
    final mode = dateMode(node.data);
    return CalendarUIState(
      nodeId: node.id,
      questionText: prompt(node, state),
      answerKey: node.data['answerVariable']?.toString(),
      mode: mode,
      showTimeSelection: mode != 'date',
      // The picker's bounds, the closed days and the button, as the web card.
      extra: {
        'datetime': true,
        ...dateInputAttrs(node.data, node.ctx.now()),
        'note': closedDaysNote(node.data),
        'submitLabel': submitLabel(node.data),
      },
    );
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    botSay(state, ui.questionText ?? '', node.id, nodeType);
    return NodeResult.displayUI(ui);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final mode = dateMode(node.data);
    dynamic raw = response is Map ? (response['value'] ?? response['datetime']) : response;
    if (raw == null && jsTruthy(_f(response, 'date'))) {
      raw = mode == 'datetime' ? '${jsString(response['date'])}T${jsString(response['time'] ?? '')}' : response['date'];
    }
    if (raw == null && jsTruthy(_f(response, 'time'))) raw = response['time'];
    final iso = isoFromInput(mode, raw);
    final problem = dateTimeError(node.data, iso, node.ctx.now());
    if (problem != null) return NodeResult.invalid(problem, uiState: _ui(node, state), inCard: true);
    final display = dateTimeDisplay(node.data, iso, 'en-US');
    _answer(state, node, {'shape': 'user-datetime', 'value': iso, 'display': display, 'mode': mode}, display, iso);
    final k = node.data['answerVariable'];
    if (jsTruthy(k)) state.saveVariableByName('${jsString(k)}_display', display);
    return NodeResult.port('source');
  }
}

// ========================================
// RANKING
// ========================================

/// ranking-node: the items in the visitor's order. Answer {order: [ids]},
/// or the multi-select buttons' ids in the order tapped (unpicked items follow).
class RankingNodeHandler extends _RichHandler {
  @override
  String get nodeType => 'ranking-node';

  RankingUIState _ui(FlowNode node, ChatState state) => RankingUIState(
        nodeId: node.id,
        questionText: prompt(node, state),
        items: rankingItems(node.data).map((it) => ChoiceOption(id: it.id, text: it.text, value: it.text)).toList(),
        submitLabel: submitLabel(node.data),
      );

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    botSay(state, ui.questionText ?? '', node.id, nodeType);
    return NodeResult.displayUI(ui, awaitInput: true);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final items = rankingItems(node.data);
    final o = _f(response, 'order');
    final b = _f(response, 'buttonIds');
    final ids = (o is List ? o : (b is List ? b : const [])).map(jsString).toList();
    final picked = <RankItem>[];
    for (final id in ids) {
      for (final it in items) {
        if (it.id == id) {
          picked.add(it);
          break;
        }
      }
    }
    final order = [...picked, ...items.where((it) => !picked.contains(it))];
    final text = rankingText(order);
    final values = order.map((it) => it.text).toList();
    _answer(state, node, {'shape': 'user-ranking', 'order': order.map((it) => it.toJson()).toList(), 'value': values, 'display': text},
        text, values);
    return NodeResult.port('source');
  }
}

// ========================================
// OTP
// ========================================

/// otp-node: an e-mail, then a six-digit code checked on the server
/// (POST otp/send, otp/verify). Answers: {action: "send", email} (or the
/// typed e-mail), {action: "verify", code} (or six typed digits),
/// {action: "skip"} (allowSkip). Verified leaves by "source"; locked,
/// skipped, sms or a failed send by "source-failed" - or "source" when
/// only that edge is drawn (the web's goPort fallback). A network error
/// says so and keeps waiting.
class OtpNodeHandler extends _RichHandler {
  @override
  String get nodeType => 'otp-node';

  String _key(FlowNode node) => '_otp_${node.id}';

  TextInputUIState _ui(FlowNode node, ChatState state, String stage, [String sentTo = '', num resendIn = otpResendSeconds]) {
    final p = prompt(node, state);
    final question = stage == 'email' ? (p.isNotEmpty ? p : t('otp.emailLabel')) : t('sdk.flow.otpEnterCode', {'n': otpLength});
    final skip = jsString(node.data['skipLabel'] ?? '').trim();
    return TextInputUIState(
      nodeId: node.id,
      questionText: question,
      inputType: stage == 'email' ? TextInputType.email : TextInputType.number,
      placeholder: stage == 'email' ? 'name@example.com' : '123456',
      answerKey: node.data['answerVariable']?.toString() ?? '',
      extra: {
        'step': 'otp',
        'stage': stage,
        'allowSkip': jsTruthy(node.data['allowSkip']),
        'skipLabel': skip.isNotEmpty ? skip : t('common.skip'),
        // The code card: where the code went and when it may be sent again.
        if (sentTo.isNotEmpty) 'sentTo': sentTo,
        if (stage == 'code') 'resendIn': resendIn,
      },
    );
  }

  NodeResult _finish(FlowNode node, ChatState state, bool verified, String email, [String? reason]) {
    final text = otpReplyText(verified, email);
    pushAnswer(
      state,
      {
        'id': node.id,
        'shape': 'user-otp',
        'verified': verified,
        if (verified) 'email': email,
        'channel': 'email',
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        'at': _iso(node),
      },
      node.ctx.now(),
    );
    userSay(state, text, node.id);
    final k = _answerKey(node);
    if (k.isNotEmpty) {
      if (verified) state.setAnswerVariable(node.id, email);
      state.saveVariableByName('${k}_verified', verified);
    }
    state.deleteVariable(_key(node));
    return verified ? NodeResult.port('source') : NodeResult.port('source-failed', fallback: 'source');
  }

  Future<NodeResult> _send(FlowNode node, ChatState state, String to) async {
    if (!isEmailAddress(to)) {
      return NodeResult.invalid(otpErrorText('invalid_email'), uiState: _ui(node, state, 'email'), inCard: true);
    }
    final target = to.trim().toLowerCase();
    final r = await _richPost(node.ctx, 'otp/send', {'nodeId': node.id, 'sessionId': _sessionOf(state), 'email': target});
    if (r.ok || r.code == 'resend_wait') {
      state.setVariable(_key(node), {'stage': 'code', 'email': target});
      final sentTo = _f(r.data, 'sentTo');
      botSay(state, t('otp.sentTo', {'n': otpLength, 'email': jsTruthy(sentTo) ? jsString(sentTo) : target}), node.id, nodeType);
      final shownTo = jsTruthy(sentTo) ? jsString(sentTo) : maskEmail(target);
      if (r.code == 'resend_wait') {
        final wait = jsNumber(_f(r.data, 'retryAfter'));
        return NodeResult.invalid(otpErrorText('resend_wait', {'retryAfter': _f(r.data, 'retryAfter')}),
            uiState: _ui(node, state, 'code', shownTo, wait.isFinite && wait > 0 ? jsNum(wait) : otpResendSeconds), inCard: true);
      }
      final again = jsNumber(_f(r.data, 'resendIn'));
      return NodeResult.displayUI(_ui(node, state, 'code', shownTo, again.isFinite && again > 0 ? jsNum(again) : otpResendSeconds),
          awaitInput: true);
    }
    if (otpEndsStep(r.code)) {
      return _finish(node, state, false, '',
          r.code == 'locked' ? 'locked' : (r.code == 'sms_unavailable' ? 'sms_unavailable' : 'send_failed'));
    }
    return NodeResult.invalid(otpErrorText(r.code), uiState: _ui(node, state, 'email'), inCard: true);
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    state.deleteVariable(_key(node));
    if (otpChannel(node.data) == 'sms') return _finish(node, state, false, '', 'sms_unavailable');
    final ui = _ui(node, state, 'email');
    botSay(state, ui.questionText, node.id, nodeType);
    final preset = otpPresetEmail(node.data, _lookup(state));
    if (preset.isNotEmpty) return _send(node, state, preset);
    return NodeResult.displayUI(ui, awaitInput: true);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final saved = state.getVariable(_key(node));
    final st = saved is Map ? saved : const {'stage': 'email'};
    final stage = jsString(st['stage'] ?? 'email');
    final action = _f(response, 'action');
    if (action == 'skip') {
      if (!jsTruthy(node.data['allowSkip'])) return NodeResult.displayUI(_ui(node, state, stage), awaitInput: true);
      return _finish(node, state, false, '', 'skipped');
    }
    if (action == 'send' || action == 'resend' || (action == null && stage == 'email')) {
      final email = _f(response, 'email');
      return _send(node, state,
          action == 'resend' ? jsString(st['email'] ?? '') : (email != null ? jsString(email) : typedText(response)));
    }
    // verify
    final rawCode = _f(response, 'code');
    final code = (rawCode != null ? jsString(rawCode) : typedText(response)).replaceAll(RegExp(r'\D'), '');
    if (code.length != otpLength) {
      return NodeResult.invalid(otpErrorText('invalid_code'), uiState: _ui(node, state, 'code', maskEmail(st['email'])), inCard: true);
    }
    final r = await _richPost(node.ctx, 'otp/verify', {'nodeId': node.id, 'sessionId': _sessionOf(state), 'code': code});
    final res = r.ok ? r.data : {'verified': false, 'code': r.code};
    if (jsTruthy(_f(res, 'verified'))) {
      final email = _f(res, 'email');
      final e = jsTruthy(email) ? email : (st['email'] ?? '');
      return _finish(node, state, true, jsString(e).toLowerCase());
    }
    if (_f(res, 'code') == 'locked') return _finish(node, state, false, '', 'locked');
    return NodeResult.invalid(otpErrorText(_f(res, 'code'), {'attemptsLeft': _f(res, 'attemptsLeft')}),
        uiState: _ui(node, state, 'code', maskEmail(st['email'])), inCard: true);
  }
}

// ========================================
// ADDRESS
// ========================================

/// address-node: search (POST geo/search, results to pick and confirm),
/// the device's position (POST geo/reverse, the address to confirm; only
/// with the app's location provider) or typed by hand (street required).
/// Answers: {action: "search", q}, {action: "locate", lat, lng},
/// {action: "pick", index} (confirms), {action: "manual", line1, city,
/// region, postal, country}, or the location picker's {address} (manual,
/// the address as the street line). Saves the formatted address and
/// <var>_line1 / _city / _region / _postal / _country / _country_code /
/// _lat / _lng.
class AddressNodeHandler extends _RichHandler {
  @override
  String get nodeType => 'address-node';

  AddressUIState _ui(FlowNode node, ChatState state, [List<AddressValue> results = const [], bool located = false]) => AddressUIState(
        nodeId: node.id,
        questionText: prompt(node, state),
        results: results.map((a) => a.toJson()).toList(),
        allowManualEntry: node.data['allowManual'] != false,
        extra: {
          'showMap': node.data['showMap'] != false,
          'allowMyLocation': node.data['allowMyLocation'] != false,
          // The results are the device's position, to confirm.
          if (located) 'located': true,
          'placeholder': jsString(node.data['placeholder'] ?? '').trim(),
        },
      );

  NodeResult _finish(FlowNode node, ChatState state, AddressValue value, String source) {
    pushAnswer(
      state,
      {'id': node.id, 'shape': 'user-address', 'value': value.toJson(), 'display': value.formatted, 'source': source, 'at': _iso(node)},
      node.ctx.now(),
    );
    userSay(state, value.formatted, node.id);
    final k = _answerKey(node);
    if (k.isNotEmpty) _saveVars(state, node, addressVariables(k, value));
    state.deleteVariable('_addr_${node.id}');
    state.deleteVariable('_addr_src_${node.id}');
    return NodeResult.port('source');
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    botSay(state, ui.questionText ?? '', node.id, nodeType);
    return NodeResult.displayUI(ui, awaitInput: true);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final action = _f(response, 'action');
    if (action == 'search') {
      final q = jsString(response['q'] ?? '').trim();
      if (q.length < 3) return NodeResult.displayUI(_ui(node, state), awaitInput: true);
      final r = await _richPost(node.ctx, 'geo/search', {'nodeId': node.id, 'q': q});
      final list = _f(r.data, 'results');
      final found = r.ok && list is List
          ? list.map(normalizeAddress).where((a) => a.formatted.isNotEmpty).take(5).toList()
          : <AddressValue>[];
      state.setVariable('_addr_${node.id}', found);
      state.deleteVariable('_addr_src_${node.id}');
      if (!r.ok) return NodeResult.invalid(addressErrorText(r.code), uiState: _ui(node, state), inCard: true);
      if (found.isEmpty) return NodeResult.invalid(addressErrorText('no_results'), uiState: _ui(node, state), inCard: true);
      return NodeResult.displayUI(_ui(node, state, found), awaitInput: true);
    }
    if (action == 'locate') {
      // Web richNodesView.ts locateBtn: the server's first address for the
      // point, else the point itself; confirmed on the map like a pick.
      final lat = jsNumber(response['lat']);
      final lng = jsNumber(response['lng']);
      if (node.data['allowMyLocation'] == false || !lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) {
        return NodeResult.invalid(addressErrorText('unavailable'), uiState: _ui(node, state), inCard: true);
      }
      final r = await _richPost(node.ctx, 'geo/reverse', {'nodeId': node.id, 'lat': lat, 'lng': lng});
      final list = _f(r.data, 'results');
      final first = r.ok && list is List && list.isNotEmpty ? list.first : null;
      AddressValue? value;
      if (first is Map) {
        value = normalizeAddress({...first, 'lat': first['lat'] ?? lat, 'lng': first['lng'] ?? lng});
        if (value.formatted.isEmpty) value = null;
      } else if (!r.ok && r.code != 'error') {
        return NodeResult.invalid(addressErrorText(r.code), uiState: _ui(node, state), inCard: true);
      }
      value ??= normalizeAddress({'formatted': '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}', 'lat': lat, 'lng': lng});
      state.setVariable('_addr_${node.id}', [value]);
      state.setVariable('_addr_src_${node.id}', 'location');
      return NodeResult.displayUI(_ui(node, state, [value], true), awaitInput: true);
    }
    if (action == 'pick') {
      final stored = state.getVariable('_addr_${node.id}');
      final results = stored is List<AddressValue> ? stored : <AddressValue>[];
      final i = jsNumber(response['index']);
      final picked = i.isFinite && i == i.truncateToDouble() && i >= 0 && i < results.length ? results[i.toInt()] : null;
      if (picked == null) return NodeResult.displayUI(_ui(node, state, results), awaitInput: true);
      final source = state.getVariable('_addr_src_${node.id}') == 'location' ? 'location' : 'search';
      return _finish(node, state, picked, source);
    }
    final Map<String, dynamic> fields = action == 'manual'
        ? Map<String, dynamic>.from(response as Map)
        : {'line1': response is String ? response : (_f(response, 'address') ?? '')};
    final value = node.data['allowManual'] == false ? null : manualAddress(fields);
    if (value == null) return NodeResult.invalid(t('sdk.flow.streetRequired'), uiState: _ui(node, state), inCard: true);
    return _finish(node, state, value, 'manual');
  }
}

// ========================================
// MATRIX
// ========================================

/// matrix-node: rows x columns, one column per row (single) or several
/// (multiple). requireAll: every row; else at least one. Saves
/// {row: column} (or {row: [columns]}). No rows, or fewer than two
/// columns: straight on by "source". Answers: {cells: {rowId: colId |
/// [colIds]}}, or the form's {formData: {...}}.
class MatrixNodeHandler extends _RichHandler {
  @override
  String get nodeType => 'matrix-node';

  MatrixUIState _ui(FlowNode node, ChatState state) {
    final data = node.data;
    final label = jsString(data['submitLabel'] ?? '').trim();
    return MatrixUIState(
      nodeId: node.id,
      questionText: prompt(node, state),
      rows: matrixRows(data).map((r) => ChoiceOption(id: r.id, text: r.text)).toList(),
      columns: matrixColumns(data).map((c) => ChoiceOption(id: c.id, text: c.text, value: c.id)).toList(),
      mode: matrixMode(data),
      requireAll: matrixRequireAll(data),
      submitLabel: label.isNotEmpty ? label : t('common.submit'),
    );
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final data = node.data;
    if (matrixRows(data).isEmpty || matrixColumns(data).length < 2) return NodeResult.port('source');
    final ui = _ui(node, state);
    botSay(state, ui.questionText ?? '', node.id, nodeType);
    return NodeResult.displayUI(ui, awaitInput: true);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final data = node.data;
    final rows = matrixRows(data);
    final cols = matrixColumns(data);
    final mode = matrixMode(data);
    final c = _f(response, 'cells') ?? _f(response, 'formData');
    final cells = c is Map ? c : const {};
    MatrixSelection sel = {};
    cells.forEach((rowId, picked) {
      final list = picked == null ? const [] : (picked is List ? picked : [picked]);
      for (final colId in list) {
        sel = matrixToggle(sel, jsString(rowId), jsString(colId), mode, true);
      }
    });
    final problem = matrixError(sel, rows, matrixRequireAll(data));
    if (problem.isNotEmpty) return NodeResult.invalid(problem, uiState: _ui(node, state), inCard: true);
    final value = matrixValue(sel, rows, cols, mode);
    final display = matrixDisplay(value);
    _answer(
      state,
      node,
      {
        'shape': 'user-matrix',
        'value': value,
        'rows': matrixRowAnswers(sel, rows, cols, mode),
        'mode': mode,
        'display': display,
        'at': _iso(node),
      },
      display,
      value,
    );
    return NodeResult.port('source');
  }
}

// ========================================
// AI EXTRACT / AI ROUTE / KB ANSWER
// ========================================

/// The text an AI or KB step reads without asking (source last_message /
/// variable), else null.
String? _presetText(FlowNode node, ChatState state) {
  final data = node.data;
  final transcript = state.transcript.map((e) => {'by': e.by, 'message': e.message}).toList();
  final variable = aiSourceOf(data) == 'variable' ? _lookup(state)(jsString(data['sourceVariable'] ?? '').trim()) : null;
  return aiPresetText(data, lastUserMessage(transcript), variable);
}

/// Thinking dots for at least aiMinThinkMs around the server call.
Future<T> _think<T>(FlowContext ctx, Future<T> Function() work) async {
  final started = ctx.now().millisecondsSinceEpoch;
  final result = await work();
  final wait = aiMinThinkMs - (ctx.now().millisecondsSinceEpoch - started);
  if (wait > 0) await ctx.typing(wait);
  return result;
}

String _clip(String s, int n) => s.length > n ? s.substring(0, n) : s;

TextInputUIState _askUi(FlowNode node, ChatState state, String question) => TextInputUIState(
      nodeId: node.id,
      questionText: question,
      inputType: TextInputType.text,
      answerKey: node.data['answerVariable']?.toString() ?? '',
    );

/// ai-extract-node: the visitor's reply (or the last message / a variable)
/// goes to POST ai/extract {nodeId, text}; every field is saved by name,
/// <var> = all values, <var>_missing = what is missing. ok -> "source";
/// missing or failed -> "source-missing" (or "source" when only that is
/// wired). Answer: the typed reply.
class AiExtractNodeHandler extends _RichHandler {
  @override
  String get nodeType => 'ai-extract-node';

  TextInputUIState _ui(FlowNode node, ChatState state) => _askUi(node, state, prompt(node, state, '<p>${t('sdk.flow.aiExtractPrompt')}</p>'));

  Future<NodeResult> _run(FlowNode node, ChatState state, String text, bool asked) async {
    final data = node.data;
    final ctx = node.ctx;
    final input = _clip(text.trim(), aiMaxInput);
    final r = await _think(ctx, () => _richPost(ctx, 'ai/extract', {'nodeId': node.id, 'text': input}, aiClientTimeoutMs));
    final ex = aiExtractResultOf(data, r.ok ? r.data : null, r.ok ? null : r.code);
    pushAnswer(
      state,
      {
        'id': node.id,
        'shape': 'user-ai-extract',
        'asked': asked,
        'input': input,
        'values': ex.values,
        'missing': ex.missing,
        'ok': ex.ok,
        if (ex.error != null && ex.error!.isNotEmpty) 'error': ex.error,
        'at': _iso(node),
      },
      ctx.now(),
    );
    _saveVars(state, node, aiExtractVariables(data, ex));
    if (asked) userSay(state, input, node.id);
    return ex.ok ? NodeResult.port('source') : NodeResult.port('source-missing', fallback: 'source');
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final preset = _presetText(node, state);
    if (preset != null && preset.isNotEmpty) return _run(node, state, preset, false);
    final ui = _ui(node, state);
    botSay(state, ui.questionText, node.id, nodeType);
    return NodeResult.displayUI(ui, awaitInput: true);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final text = typedText(response);
    if (text.isEmpty) return NodeResult.displayUI(_ui(node, state), awaitInput: true);
    return _run(node, state, text, true);
  }
}

/// ai-route-node: POST ai/route {nodeId, text} -> an intent. Leaves by
/// "source-" + the intent id when that edge is drawn; no match, a failure
/// or an intent with no edge -> "source-fallback" (no further fallback: no
/// edge there ends the chat). Saves <var> (the intent name, "" on no
/// match) and <var>_confidence.
class AiRouteNodeHandler extends _RichHandler {
  @override
  String get nodeType => 'ai-route-node';

  TextInputUIState _ui(FlowNode node, ChatState state) => _askUi(node, state, prompt(node, state, '<p>${t('sdk.flow.aiExtractPrompt')}</p>'));

  Future<NodeResult> _run(FlowNode node, ChatState state, String text, bool asked) async {
    final data = node.data;
    final ctx = node.ctx;
    final input = _clip(text.trim(), aiMaxInput);
    final r = await _think(ctx, () => _richPost(ctx, 'ai/route', {'nodeId': node.id, 'text': input}, aiClientTimeoutMs));
    final rt = aiRouteResultOf(r.ok ? r.data : null, r.ok ? null : r.code);
    pushAnswer(
      state,
      {
        'id': node.id,
        'shape': 'user-ai-route',
        'asked': asked,
        'input': input,
        'intentId': rt.intentId,
        'intent': rt.intent,
        'confidence': rt.confidence,
        'fallback': rt.fallback,
        if (rt.error != null && rt.error!.isNotEmpty) 'error': rt.error,
        'at': _iso(node),
      },
      ctx.now(),
    );
    _saveVars(state, node, aiRouteVariables(data, rt));
    if (asked) userSay(state, input, node.id);
    final intentId = rt.intentId;
    if (!rt.fallback && intentId != null && intentId.isNotEmpty && ctx.wired('source-$intentId')) {
      return NodeResult.port('source-$intentId');
    }
    return NodeResult.port('source-fallback');
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final preset = _presetText(node, state);
    if (preset != null && preset.isNotEmpty) return _run(node, state, preset, false);
    final ui = _ui(node, state);
    botSay(state, ui.questionText, node.id, nodeType);
    return NodeResult.displayUI(ui, awaitInput: true);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final text = typedText(response);
    if (text.isEmpty) return NodeResult.displayUI(_ui(node, state), awaitInput: true);
    return _run(node, state, text, true);
  }
}

/// kb-answer-node: POST kb/answer {nodeId, question}; the answer is shown
/// with its sources and saved (<var>, <var>_found, <var>_sources). Found ->
/// "source"; not found or failed -> notFoundMessage and "source-notfound"
/// (or "source" when only that is wired).
class KbAnswerNodeHandler extends _RichHandler {
  @override
  String get nodeType => 'kb-answer-node';

  TextInputUIState _ui(FlowNode node, ChatState state) =>
      _askUi(node, state, prompt(node, state, '<p>${t('kb.askPrompt')}</p>'));

  Future<NodeResult> _run(FlowNode node, ChatState state, String text, bool asked) async {
    final data = node.data;
    final ctx = node.ctx;
    final input = _clip(text.trim(), 1000);
    final res = await _think(ctx, () => _richPost(ctx, 'kb/answer', {'nodeId': node.id, 'question': input}, kbClientTimeoutMs));
    final r = kbResultOf(data, res.ok ? res.data : null, res.ok ? null : res.code);
    final shown = r.found ? r.answer : plainText(kbNotFoundHtml(data));
    final sources = r.found && r.sources.isNotEmpty
        ? '\n\n${r.sources.map((s) => '• ${s.title}${s.url.isNotEmpty ? ' (${s.url})' : ''}').join('\n')}'
        : '';
    final sourceMaps = r.sources.map((s) => s.toJson()).toList();
    botSay(state, '$shown$sources', node.id, nodeType, r.found ? {'sources': sourceMaps} : null);
    pushAnswer(
      state,
      {
        'id': node.id,
        'shape': 'kb-answer',
        'asked': asked,
        'input': input,
        'found': r.found,
        if (r.found) 'answer': r.answer,
        'sources': sourceMaps,
        if (r.error != null && r.error!.isNotEmpty) 'error': r.error,
        'at': _iso(node),
      },
      ctx.now(),
    );
    if (asked) userSay(state, input, node.id);
    _saveVars(state, node, kbVariables(data, r));
    return r.found ? NodeResult.port('source') : NodeResult.port('source-notfound', fallback: 'source');
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final preset = _presetText(node, state);
    if (preset != null && preset.isNotEmpty) return _run(node, state, preset, false);
    final ui = _ui(node, state);
    botSay(state, ui.questionText, node.id, nodeType);
    return NodeResult.displayUI(ui, awaitInput: true);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final text = typedText(response);
    if (text.isEmpty) return NodeResult.displayUI(_ui(node, state), awaitInput: true);
    return _run(node, state, text, true);
  }
}

// ========================================
// SIGNATURE
// ========================================

String _xmlEscape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// A typed name drawn as a signature image (SVG), sized to the name.
class TypedSignature {
  final String dataUrl;
  final int width;
  final int height;

  const TypedSignature(this.dataUrl, this.width, this.height);
}

/// A typed name as a signature image (SVG data URL).
TypedSignature typedSignatureSvg(String name) {
  final clean = cleanSignatureName(name);
  final width = math.max(96, (clean.length * 16 + 64).round());
  const height = 114;
  final svg = '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">'
      '<text x="50%" y="62%" text-anchor="middle" font-family="Segoe Script, Bradley Hand, Snell Roundhand, cursive" '
      'font-style="italic" font-size="40" fill="#111827">${_xmlEscape(clean)}</text></svg>';
  return TypedSignature('data:image/svg+xml;charset=utf-8,${encodeUriComponent(svg)}', width, height);
}

/// signature-node: a typed name (allowTyped) or a drawing the UI exports
/// as an image, uploaded to POST media; saves the URL and <var>_at /
/// _method / _name. Answers: {action: "sign", method: "typed", name,
/// fullName?}, {action: "sign", method: "drawn", dataUrl, width, height}
/// (strokes 0: nothing drawn), or a typed name.
class SignatureNodeHandler extends _RichHandler {
  @override
  String get nodeType => 'signature-node';

  TextInputUIState _ui(FlowNode node, ChatState state) {
    final p = prompt(node, state);
    return TextInputUIState(
      nodeId: node.id,
      questionText: p.isNotEmpty ? p : t('signature.typeToSign'),
      inputType: TextInputType.text,
      placeholder: t('signature.namePlaceholder'),
      answerKey: node.data['answerVariable']?.toString() ?? '',
      // The signature card: a pad to draw on, typing when allowed, the full name when asked.
      extra: {'step': 'signature', ...signatureConfig(node.data)},
    );
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    botSay(state, ui.questionText, node.id, nodeType);
    return NodeResult.displayUI(ui, awaitInput: true);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final cfg = signatureConfig(node.data);
    final allowTyped = cfg['allowTyped'] == true;
    final requireName = cfg['requireName'] == true;
    final typed = response is String || _f(response, 'method') == 'typed';
    final method = typed ? 'typed' : 'drawn';
    final name = typed ? cleanSignatureName(response is String ? response : _f(response, 'name')) : '';
    final fullName = cleanSignatureName(_f(response, 'fullName') ?? (requireName ? name : ''));
    if (requireName && !isSignatureName(fullName)) {
      return NodeResult.invalid(t('sdk.flow.signatureName'), uiState: _ui(node, state), inCard: true);
    }
    if (method == 'drawn' && !jsTruthy(_f(response, 'dataUrl'))) {
      return NodeResult.invalid(
        allowTyped ? t('sdk.flow.signatureDrawOrType') : t('sdk.flow.signatureDraw'),
        uiState: _ui(node, state),
        inCard: true,
      );
    }
    if (method == 'typed' && (!allowTyped || !isSignatureName(name))) {
      return NodeResult.invalid(t('sdk.flow.signatureType'), uiState: _ui(node, state), inCard: true);
    }
    final String dataUrl;
    final num width;
    final num height;
    if (method == 'typed') {
      final img = typedSignatureSvg(name);
      dataUrl = img.dataUrl;
      width = img.width;
      height = img.height;
    } else {
      dataUrl = jsString(response['dataUrl']);
      final w = jsNumber(response['width']);
      final h = jsNumber(response['height']);
      width = w.isFinite && w != 0 ? jsNum(w) : 0;
      height = h.isFinite && h != 0 ? jsNum(h) : 0;
    }
    final up = await node.ctx.upload(UploadFile(
      dataUrl: dataUrl,
      name: 'signature-${node.ctx.now().millisecondsSinceEpoch}.${method == 'typed' ? 'svg' : 'png'}',
      type: method == 'typed' ? 'image/svg+xml' : 'image/png',
    ));
    final url = up.url;
    if (!up.ok || url == null || url.isEmpty) {
      return NodeResult.invalid(t('sdk.flow.signatureSaveFailed'), uiState: _ui(node, state), inCard: true);
    }
    final at = _iso(node);
    final shownName = fullName.isNotEmpty ? fullName : name;
    pushAnswer(
      state,
      {
        'id': node.id,
        'shape': 'user-signature',
        'url': url,
        'at': at,
        'method': method,
        if (shownName.isNotEmpty) 'name': shownName,
        'width': width,
        'height': height,
      },
      node.ctx.now(),
    );
    userSay(state, 'Signed: $url', node.id);
    final k = _answerKey(node);
    if (k.isNotEmpty) {
      state.setAnswerVariable(node.id, url);
      signatureVariables(k, {'url': url, 'at': at, 'name': shownName, 'method': method}).forEach((vk, vv) {
        if (vk != k) state.saveVariableByName(vk, vv);
      });
    }
    return NodeResult.port('source');
  }
}

// ========================================
// PAYMENT
// ========================================

class _PaymentSession {
  String paymentId = '';
  num? amount;
  String currency;
  String amountText = '';
  int deadline;
  bool waiting = false;
  bool done = false;
  final List<Timer> timers = [];
  void Function() off = () {};

  _PaymentSession(this.currency, this.deadline);
}

/// payment-node: POST pay/start makes a Stripe Checkout on the server. The
/// visitor opens it ("Pay now"); while they are away the status is peeked
/// every 5 s (POST pay/status) and the socket's "payment-status" counts
/// too. Paid -> "source"; failed or cancelled -> "source-failed" (never the
/// paid path); timed out -> "source-timeout", else "source-failed".
/// Answers: {action: "open"} (the button carries the Checkout URL to open),
/// {action: "check"}, {action: "cancel"}.
class PaymentNodeHandler extends _RichHandler {
  @override
  String get nodeType => 'payment-node';

  final Map<String, _PaymentSession> _sessions = {};

  PaymentUIState _ui(FlowNode node, ChatState state, [_PaymentSession? s, String? url]) {
    final p = plainText(node.data['buttonLabel']);
    final label = p.isNotEmpty ? p : t('pay.payNow');
    final amountText = s?.amountText ?? '';
    final buttons = <Map<String, dynamic>>[
      {'id': 'open', 'label': amountText.isNotEmpty ? '$label · $amountText' : label, 'value': url ?? ''},
      if (s?.waiting == true) {'id': 'check', 'label': t('pay.ivePaid')},
      {'id': 'cancel', 'label': t('common.cancel')},
    ];
    return PaymentUIState(
      nodeId: node.id,
      paymentUrl: url ?? '',
      questionText: prompt(node, state),
      buttonLabel: buttons.first['label'] as String,
      amount: s?.amount?.toDouble(),
      currency: s?.currency,
      extra: {
        'checkoutUrl': url,
        'buttons': buttons,
        'waiting': s?.waiting == true,
        'amountText': amountText,
        // The card's head: what is paid for.
        'productName': plainText(node.data['productName']),
        'description': plainText(node.data['description']),
      },
    );
  }

  void _stop(_PaymentSession s) {
    for (final x in s.timers) {
      x.cancel();
    }
    s.timers.clear();
    s.off();
  }

  NodeResult _finish(FlowNode node, ChatState state, _PaymentSession s, String outcome, [dynamic r]) {
    s.done = true;
    _stop(s);
    _sessions.remove(node.id);
    final st = _f(r, 'status');
    final status = jsTruthy(st) ? jsString(st) : (outcome == 'paid' ? 'paid' : (outcome == 'timeout' ? 'timeout' : 'cancelled'));
    final receiptUrl = isReceiptUrl(_f(r, 'receiptUrl')) ? jsString(_f(r, 'receiptUrl')) : '';
    final amt = _f(r, 'amount');
    if (amt != null && jsNumber(amt).isFinite) s.amount = jsNum(jsNumber(amt));
    final cur = _f(r, 'currency');
    if (jsTruthy(cur)) s.currency = jsString(cur).toLowerCase();
    final shownAmount = s.amount != null ? paymentAmountText(s.amount, s.currency) : s.amountText;
    final text = paymentReplyText(outcome, shownAmount);
    pushAnswer(
      state,
      {
        'id': node.id,
        'shape': 'user-payment',
        'outcome': outcome,
        'status': status,
        'amount': s.amount,
        'currency': s.currency,
        'amountText': shownAmount,
        if (receiptUrl.isNotEmpty) 'receiptUrl': receiptUrl,
        if (s.paymentId.isNotEmpty) 'paymentId': s.paymentId,
        'at': _iso(node),
      },
      node.ctx.now(),
    );
    userSay(state, text, node.id);
    _saveVars(
      state,
      node,
      paymentVariables(_answerKey(node),
          PaymentResult(status: status, amount: s.amount, currency: s.currency, receiptUrl: receiptUrl, paymentId: s.paymentId)),
    );
    if (outcome == 'timeout') return NodeResult.port('source-timeout', fallback: 'source-failed');
    return NodeResult.port(paymentHandleOf(outcome));
  }

  Future<_RichReply> _ask(FlowContext ctx, FlowNode node, ChatState state, _PaymentSession s, String action) => _richPost(
      ctx, 'pay/status', {'nodeId': node.id, 'sessionId': _sessionOf(state), 'paymentId': s.paymentId, 'action': action});

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final data = node.data;
    final ctx = node.ctx;
    final p = prompt(node, state);
    if (p.isNotEmpty) botSay(state, p, node.id, nodeType);
    final c = data['currency'];
    final s = _PaymentSession(
      (jsTruthy(c) ? jsString(c) : 'usd').toLowerCase(),
      ctx.now().millisecondsSinceEpoch + paymentTimeoutMs(data),
    );
    final old = _sessions[node.id];
    if (old != null) _stop(old);
    _sessions[node.id] = s;
    final v = jsString(data['amountVariable'] ?? '').trim();
    final res = await _richPost(ctx, 'pay/start', {
      'nodeId': node.id,
      'sessionId': _sessionOf(state),
      'step': jsString(ctx.stepIndex),
      if (data['amountMode'] == 'variable' && v.isNotEmpty)
        'variables': {v: _lookup(state)(v)},
    });
    final d = res.data;
    if (res.ok && jsTruthy(_f(d, 'paymentId'))) {
      final outcome = paymentOutcomeOf(_f(d, 'status'));
      if (outcome != null) return _finish(node, state, s, outcome, d);
      s.paymentId = jsString(d['paymentId']);
      final a = jsNumber(d['amount']);
      if (a.isFinite) s.amount = jsNum(a);
      if (jsTruthy(d['currency'])) s.currency = jsString(d['currency']).toLowerCase();
      s.amountText = s.amount != null ? paymentAmountText(s.amount, s.currency) : '';
      final exp = d['expiresAt'];
      if (jsTruthy(exp)) {
        final parsed = DateTime.tryParse(jsString(exp));
        if (parsed != null) s.deadline = parsed.millisecondsSinceEpoch;
      }
      final url = isCheckoutUrl(d['url']) ? jsString(d['url']) : '';
      state.setVariable('_pay_${node.id}', url);
      // The server's word, from the socket.
      s.off = ctx.on('payment-status', (r) {
        if (!s.done &&
            r is Map &&
            r['paymentId'] == s.paymentId &&
            jsString(r['nodeId'] ?? node.id) == node.id &&
            paymentOutcomeOf(r['status']) != null) {
          ctx.respond({'action': '__status', 'status': r});
        }
      });
      // The countdown: at the deadline, ask the server once more, then time out.
      var asked = false;
      s.timers.add(Timer.periodic(const Duration(milliseconds: 1000), (_) {
        if (s.done || asked || ctx.now().millisecondsSinceEpoch < s.deadline) return;
        asked = true;
        _ask(ctx, node, state, s, 'timeout').then((r) {
          if (s.done) return;
          if (r.ok && paymentOutcomeOf(_f(r.data, 'status')) != null) {
            ctx.respond({'action': '__status', 'status': r.data});
          } else if (r.ok) {
            Timer(const Duration(milliseconds: 6000), () {
              if (s.done) return;
              _ask(ctx, node, state, s, 'timeout').then((r2) {
                if (s.done) return;
                ctx.respond({
                  'action': '__status',
                  'status': r2.ok && paymentOutcomeOf(_f(r2.data, 'status')) != null ? r2.data : {'status': 'timeout'},
                });
              });
            });
          } else {
            ctx.respond({
              'action': '__status',
              'status': {'status': 'timeout'},
            });
          }
        });
      }));
      return NodeResult.displayUI(_ui(node, state, s, url), awaitInput: true);
    }
    final code = res.code;
    if (code == 'not_configured' || code == 'invalid_amount' || code == 'node_not_found') {
      botSay(state, paymentErrorText(code), node.id, nodeType);
      await ctx.delay(1600);
      return _finish(node, state, s, 'failed', {'status': 'failed'});
    }
    return NodeResult.invalid(paymentErrorText(code), uiState: _ui(node, state, s), inCard: true);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final ctx = node.ctx;
    final s = _sessions[node.id];
    if (s == null || s.done) return handle(node, state);
    final url = jsString(state.getVariable('_pay_${node.id}') ?? '');
    final action = _f(response, 'action') ?? pickedId(response);
    if (action == '__status') {
      final status = response['status'];
      final outcome = paymentOutcomeOf(_f(status, 'status')) ?? 'timeout';
      return _finish(node, state, s, outcome, status);
    }
    if (action == 'open') {
      if (!s.waiting) {
        s.waiting = true;
        s.timers.add(Timer.periodic(const Duration(milliseconds: paymentPeekMs), (_) {
          if (s.done) return;
          _ask(ctx, node, state, s, 'peek').then((r) {
            if (!s.done && r.ok && paymentOutcomeOf(_f(r.data, 'status')) != null) {
              ctx.respond({'action': '__status', 'status': r.data});
            }
          });
        }));
      }
      return NodeResult.displayUI(_ui(node, state, s, url), awaitInput: true);
    }
    if (action == 'check') {
      final r = await _ask(ctx, node, state, s, 'check');
      final outcome = r.ok ? paymentOutcomeOf(_f(r.data, 'status')) : null;
      if (outcome != null) return _finish(node, state, s, outcome, r.data);
      return NodeResult.invalid(r.ok ? t('pay.notYet') : paymentErrorText(r.code), uiState: _ui(node, state, s, url), inCard: true);
    }
    if (action == 'cancel') {
      final r = await _ask(ctx, node, state, s, 'cancel');
      return _finish(node, state, s, 'failed', {
        'status': 'cancelled',
        if (r.ok && r.data is Map) ...Map<String, dynamic>.from(r.data as Map),
      });
    }
    return NodeResult.displayUI(_ui(node, state, s, url), awaitInput: true);
  }
}

// ========================================
// REGISTRATION
// ========================================

/// The rich steps' handlers.
final List<NodeHandler> richHandlers = [
  DynamicChoicesHandler(),
  HiddenFieldsHandler(),
  ConsentHandler(),
  ProductCardHandler(),
  SliderNodeHandler(),
  DateTimeNodeHandler(),
  RankingNodeHandler(),
  OtpNodeHandler(),
  AddressNodeHandler(),
  MatrixNodeHandler(),
  AiExtractNodeHandler(),
  AiRouteNodeHandler(),
  KbAnswerNodeHandler(),
  SignatureNodeHandler(),
  PaymentNodeHandler(),
];
