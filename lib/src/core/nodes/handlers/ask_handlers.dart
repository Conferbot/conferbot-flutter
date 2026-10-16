/// The question steps answered in the composer (ask-name, ask-email,
/// ask-phone-number, ask-number, ask-url, ask-location,
/// ask-custom-question) and the file step (ask-file) - React Native
/// src/core/nodes/handlers/AskNodeHandlers.ts. Field names, checks, records
/// and saved values follow the flow-node spec and the web widget's
/// ts/chat/handlers/askQuestions.ts:
///
/// - the prompt is data.questionText;
/// - the answer fills the variable the step registered when it was shown
///   (data.answerVariable) - a step without one stores nothing;
/// - phone numbers are saved normalised, numbers as numbers, bare links as
///   https;
/// - a refused answer says why and the step keeps waiting.
library;

import '../../flow/i18n_en.dart';
import '../../flow/inputs.dart';
import '../../flow/js.dart' show jsIsoString, jsNumber, jsString;
import '../../flow/text.dart' show fillVariables, nameGreetingHtml;
import '../../state/chat_state.dart';
import '../node_handler.dart';
import '../node_ui_state.dart';
import 'flow_kit.dart';

/// What an answer saves and records.
class AskSaved {
  final dynamic variable;
  final String text;
  const AskSaved(this.variable, this.text);
}

/// A composer question: shows questionText, takes typed text.
abstract class BaseAskHandler extends BaseNodeHandler {
  TextInputType get inputType;
  String get shape;
  String get placeholder => t('composer.answer');

  TextInputUIState ui(FlowNode node, ChatState state) => TextInputUIState(
        questionText: shownText(state, node.data['questionText']),
        inputType: inputType,
        placeholder: placeholder,
        answerKey: (node.data['answerVariable'] ?? '').toString(),
        nodeId: node.id,
      );

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final u = ui(node, state);
    botSay(state, u.questionText, node.id, nodeType);
    return NodeResult.displayUI(u);
  }

  /// The refusal message, or null when the answer is fine.
  String? problem(String value, FlowNode node, ChatState state) => null;

  /// What is saved and recorded for the answer.
  AskSaved saved(String value) => AskSaved(value, value);

  /// After the answer is saved: by default, on along the first edge.
  Future<NodeResult> after(String value, FlowNode node, ChatState state) async => NodeResult.next();

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final value = typedText(response);
    if (value.isEmpty) return NodeResult.displayUI(ui(node, state));
    final p = problem(value, node, state);
    if (p != null) return NodeResult.invalid(p, uiState: ui(node, state));
    final s = saved(value);
    pushAnswer(state, {'id': node.id, 'shape': shape, 'text': s.text}, node.ctx.now());
    userSay(state, s.text, node.id);
    state.setAnswerVariable(node.id, s.variable);
    return after(value, node, state);
  }
}

/// ask-name-node: any text. The full answer is saved; nameGreetResponse
/// greets by the first name after 2000 ms of typing (none set: the default
/// greeting; cleared in the builder: no greeting).
class AskNameHandler extends BaseAskHandler {
  @override
  String get nodeType => 'ask-name-node';
  @override
  TextInputType get inputType => TextInputType.text;
  @override
  String get shape => 'user-ask-name-response';
  @override
  String get placeholder => t('composer.name');

  @override
  Future<NodeResult> after(String value, FlowNode node, ChatState state) async {
    state.setUserName(value);
    final greeting = nameGreetingHtml(node.data['nameGreetResponse'], value);
    if (greeting.isEmpty) return NodeResult.next();
    await node.ctx.typing(2000);
    state.addRecord({
      '_id': node.id,
      'id': node.id,
      'shape': 'ask-name-response-greet',
      'type': 'ask-name-response-greet',
      'text': greeting,
      'renderedText': fillVariables(greeting, state.lookupVariable),
      'time': jsIsoString(node.ctx.now()),
    });
    botSay(state, shownText(state, greeting), node.id, nodeType);
    return NodeResult.next();
  }
}

/// ask-email-node: the widget's e-mail check (incorrectEmailResponse, else
/// the default). A likely domain typo is refused once with the fix offered;
/// the same address sent again is kept as typed.
class AskEmailHandler extends BaseAskHandler {
  @override
  String get nodeType => 'ask-email-node';
  @override
  TextInputType get inputType => TextInputType.email;
  @override
  String get shape => 'user-ask-email-response';
  @override
  String get placeholder => t('composer.email');

  @override
  String? problem(String value, FlowNode node, ChatState state) {
    if (!isValidEmail(value)) {
      return ownerTextOr(node.data['incorrectEmailResponse'], en.emailInvalid, const ['Please enter a valid email']);
    }
    final fix = suggestEmailFix(value);
    final typed = value.trim().toLowerCase();
    if (fix != null && state.getVariable('_lastEmailTypo') != typed) {
      state.setVariable('_lastEmailTypo', typed);
      return en.emailTypo(fix);
    }
    state.setVariable('_lastEmailTypo', '');
    return null;
  }

  @override
  Future<NodeResult> after(String value, FlowNode node, ChatState state) async => NodeResult.next({'email': value});

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final result = await super.handleResponse(response, node, state);
    if (result is ProceedResult) state.setUserEmail(typedText(response));
    return result;
  }
}

/// ask-phone-number-node: 6-15 digits once normalised; saved normalised.
class AskPhoneHandler extends BaseAskHandler {
  @override
  String get nodeType => 'ask-phone-number-node';
  @override
  TextInputType get inputType => TextInputType.phone;
  @override
  String get shape => 'user-ask-phone-number-response';
  @override
  String get placeholder => t('composer.phone');

  @override
  String? problem(String value, FlowNode node, ChatState state) =>
      isValidPhone(value) ? null : phoneErrorText(node.data);

  @override
  AskSaved saved(String value) {
    final phone = normalizePhone(value);
    return AskSaved(phone, phone);
  }

  @override
  Future<NodeResult> after(String value, FlowNode node, ChatState state) async {
    state.setUserPhone(normalizePhone(value));
    return NodeResult.next();
  }
}

/// ask-number-node: "1,200" is 1200, "3,5" is 3.5; enableConditions bounds;
/// invalidNumberResponse ({min}/{max} filled). Saved as a NUMBER.
class AskNumberHandler extends BaseAskHandler {
  @override
  String get nodeType => 'ask-number-node';
  @override
  TextInputType get inputType => TextInputType.number;
  @override
  String get shape => 'user-ask-number-response';
  @override
  String get placeholder => t('composer.number');

  @override
  String? problem(String value, FlowNode node, ChatState state) => numberProblem(value, node.data);

  @override
  AskSaved saved(String value) {
    final n = parseNumberInput(value);
    return AskSaved(n ?? value, n == null ? value : jsString(n));
  }
}

/// ask-url-node: a link people would type; a bare host is saved with https://.
class AskUrlHandler extends BaseAskHandler {
  @override
  String get nodeType => 'ask-url-node';
  @override
  TextInputType get inputType => TextInputType.url;
  @override
  String get shape => 'user-ask-url-response';

  @override
  String? problem(String value, FlowNode node, ChatState state) => isValidLink(value) ? null : en.link;

  @override
  AskSaved saved(String value) {
    final href = linkHref(value);
    final url = href.isNotEmpty ? href : value.trim();
    return AskSaved(url, url);
  }
}

/// ask-location-node: any text.
class AskLocationHandler extends BaseAskHandler {
  @override
  String get nodeType => 'ask-location-node';
  @override
  TextInputType get inputType => TextInputType.text;
  @override
  String get shape => 'user-ask-location-response';
  @override
  String get placeholder => t('composer.location');
}

/// ask-custom-question-node: any text.
class AskCustomQuestionHandler extends BaseAskHandler {
  @override
  String get nodeType => 'ask-custom-question-node';
  @override
  TextInputType get inputType => TextInputType.text;
  @override
  String get shape => 'user-ask-custom-question-response';
}

/// ask-file-node: an upload card. A file over maxFileSizeMB (default 5) or
/// not in allowedFileTypes is refused on the card; the picked file is
/// uploaded to POST /api/v1/bot/:id/media and its URL saved. A failed upload
/// keeps the step waiting. Optional ("(optional)" in the question, or
/// data.optional) offers Skip: recorded as skipped, no variable.
///
/// Answers: {file: {uri, name, type, size}} (uploaded here), {url, fileName}
/// (uploaded by the UI already), or {skip: true}.
class AskFileHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'ask-file-node';

  FileUploadUIState _ui(FlowNode node, ChatState state) {
    final data = node.data;
    final raw = data['allowedFileTypes'];
    final types = raw is List ? raw.map((t) => jsString(t)).toList() : <String>[];
    final mb = jsNumber(data['maxFileSizeMB']);
    return FileUploadUIState(
      questionText: shownText(state, data['questionText']),
      answerKey: data['answerVariable']?.toString(),
      allowedTypes: types.isEmpty ? null : types,
      maxSizeMb: mb > 0 ? mb.ceil() : defaultMaxFileMb,
      optional: isOptionalUpload(data),
      typesInWords: fileTypesWords(types),
      nodeId: node.id,
    );
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final u = _ui(node, state);
    botSay(state, u.questionText, node.id, nodeType);
    return NodeResult.displayUI(u);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final data = node.data;
    final r = response is Map ? response : const {};

    if (r['skip'] == true || r['action'] == 'skip') {
      if (!isOptionalUpload(data)) return NodeResult.displayUI(_ui(node, state));
      pushAnswer(state, {'id': node.id, 'shape': 'user-ask-file-response', 'skipped': true}, node.ctx.now());
      userSay(state, en.skipped, node.id);
      return NodeResult.next();
    }

    final files = r['files'];
    final firstFile = files is List && files.isNotEmpty && files[0] is Map ? files[0] as Map : null;
    String? url = r['url'] is String && (r['url'] as String).trim().isNotEmpty ? r['url'] as String : null;
    final fileMap = r['file'] is Map ? r['file'] as Map : null;
    String fileName = _firstTruthy([r['fileName'], fileMap?['name'], firstFile?['name']]) ?? 'file';
    if (url == null && firstFile != null && _truthy(firstFile['url'])) url = jsString(firstFile['url']);

    if (url == null) {
      if (fileMap == null) return NodeResult.displayUI(_ui(node, state));
      final problem = fileUploadProblem(fileMap, data);
      if (problem != null) return NodeResult.invalid(problem, uiState: _ui(node, state), inCard: true);
      final uploaded = await node.ctx.upload(UploadFile.fromMap(fileMap));
      if (!uploaded.ok || uploaded.url == null || uploaded.url!.isEmpty) {
        return NodeResult.invalid(en.uploadRetry, uiState: _ui(node, state), inCard: true);
      }
      url = uploaded.url!;
      if (_truthy(fileMap['name'])) fileName = jsString(fileMap['name']);
    }

    pushAnswer(state, {'id': node.id, 'shape': 'user-ask-file-response', 'fileName': fileName, 'url': url}, node.ctx.now());
    userSay(state, url, node.id);
    state.setAnswerVariable(node.id, url);
    return NodeResult.next();
  }
}

bool _truthy(dynamic v) => v != null && v != '' && v != false && v != 0;

String? _firstTruthy(List<dynamic> values) {
  for (final v in values) {
    if (_truthy(v)) return jsString(v);
  }
  return null;
}

/// The ask steps.
final List<NodeHandler> askHandlers = [
  AskNameHandler(),
  AskEmailHandler(),
  AskPhoneHandler(),
  AskNumberHandler(),
  AskUrlHandler(),
  AskFileHandler(),
  AskLocationHandler(),
  AskCustomQuestionHandler(),
];
