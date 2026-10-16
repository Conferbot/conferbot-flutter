/// The v1 steps still found in live bots: two-choices, three-choices,
/// select-option, user-input, user-range, user-rating and quiz (React
/// Native src/core/nodes/handlers/LegacyNodeHandlers.ts). Fields and
/// behaviour follow the flow-node spec and the web widget
/// (ts/chat/handlers/_legacy.ts, flowOperations.ts, displayStep.ts).
/// Legacy steps never register an answer variable.
library;

import '../../flow/i18n_en.dart';
import '../../flow/inputs.dart';
import '../../flow/js.dart';
import '../../flow/text.dart' show nameGreetingHtml;
import '../../state/chat_state.dart';
import '../node_handler.dart';
import '../node_ui_state.dart';
import 'flow_kit.dart';

String _str(dynamic v) => v == null ? '' : jsString(v);

/// `Number(x)` where a missing key is undefined (NaN), not 0.
double _numOf(Map<String, dynamic> data, String key) => data.containsKey(key) ? jsNumber(data[key]) : double.nan;

bool _isInteger(double n) => n.isFinite && n == n.truncateToDouble();

/// Numbered options (choiceText1.., option1..) as buttons, ids "1".."n".
List<ChoiceOption> _numberedButtons(ChatState state, Map<String, dynamic> data, String key, int count, bool Function(int n) hidden) {
  final buttons = <ChoiceOption>[];
  for (var n = 1; n <= count; n++) {
    if (hidden(n)) continue;
    buttons.add(ChoiceOption(id: '$n', text: shownLabel(state, data['$key$n']), value: savedText(data['$key$n'])));
  }
  return buttons;
}

/// `Number(pickedId(response))`, NaN when nothing was picked.
double _pickedNumber(dynamic response) {
  final id = pickedId(response);
  return id == null ? double.nan : jsNumber(id);
}

// ========================================
// TWO / THREE CHOICES
// ========================================

/// two-choices-node: choiceText1 -> source-1, choiceText2 -> source-2 (disableSecondChoice hides it).
class TwoChoicesNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'two-choices-node';

  int get count => 2;

  bool hidden(Map<String, dynamic> data, int n) => n == 2 && jsTruthy(data['disableSecondChoice']);

  SingleChoiceUIState _ui(FlowNode node, ChatState state) => SingleChoiceUIState(
        nodeId: node.id,
        questionText: shownText(state, node.data['choicePrompt']),
        choices: _numberedButtons(state, node.data, 'choiceText', count, (n) => hidden(node.data, n)),
      );

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    botSay(state, ui.questionText ?? '', ui.nodeId, nodeType);
    return NodeResult.displayUI(ui);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final id = pickedId(response);
    final n = id != null ? jsNumber(id) : (response is Map ? jsNumber(response['index']) + 1 : double.nan);
    if (!_isInteger(n) || n < 1 || n > count || hidden(node.data, n.toInt())) return NodeResult.displayUI(_ui(node, state));
    final i = n.toInt();
    final text = savedText(node.data['choiceText$i']);
    pushAnswer(state, {'id': node.id, 'shape': 'user-selected-choice', 'choices': node.data, 'selectedChoice': text},
        node.ctx.now());
    userSay(state, text, node.id);
    return NodeResult.port('source-$i');
  }
}

/// three-choices-node: choiceText1..3 -> source-1..3.
class ThreeChoicesNodeHandler extends TwoChoicesNodeHandler {
  @override
  String get nodeType => 'three-choices-node';

  @override
  int get count => 3;

  @override
  bool hidden(Map<String, dynamic> data, int n) => false;
}

// ========================================
// SELECT OPTION
// ========================================

/// select-option-node: option1..option5 (disableOption3..5); the first edge 600 ms after the pick.
class SelectOptionNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'select-option-node';

  bool _hidden(Map<String, dynamic> data, int n) => n >= 3 && jsTruthy(data['disableOption$n']);

  SingleChoiceUIState _ui(FlowNode node, ChatState state) => SingleChoiceUIState(
        nodeId: node.id,
        questionText: shownText(state, node.data['selectPrompt']),
        choices: _numberedButtons(state, node.data, 'option', 5, (n) => _hidden(node.data, n)),
      );

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    botSay(state, ui.questionText ?? '', ui.nodeId, nodeType);
    return NodeResult.displayUI(ui);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final n = _pickedNumber(response);
    if (!_isInteger(n) || n < 1 || n > 5 || _hidden(node.data, n.toInt())) return NodeResult.displayUI(_ui(node, state));
    final text = savedText(node.data['option${n.toInt()}']);
    pushAnswer(state, {'id': node.id, 'shape': 'user-selected-option', 'options': node.data, 'selectedOption': text},
        node.ctx.now());
    userSay(state, text, node.id);
    return NodeResult.delayedProceed(null, 600);
  }
}

// ========================================
// USER INPUT
// ========================================

// The web's /^(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*\/?$/i, with
// the nested repeat (same language) flattened so it cannot backtrack forever.
final RegExp _legacyUrlRe = RegExp(r'^(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)\/?$', caseSensitive: false);

/// user-input-node: data.type name | email | number | url | date | file |
/// phone | mobile. email / number / url are checked (incorrect*Response);
/// name greets with nameGreet after 1000 ms of typing and moves on at 2000
/// ms; others at 500 ms; a date or a file at once.
class UserInputNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'user-input-node';

  NodeUIState _ui(FlowNode node, ChatState state) {
    final type = _str(node.data['type']);
    final question = shownText(state, node.data['inputPrompt']);
    if (type == 'file') return FileUploadUIState(nodeId: node.id, questionText: question, maxSizeMb: 5);
    final inputType = switch (type) {
      'email' => TextInputType.email,
      'number' => TextInputType.number,
      'url' => TextInputType.url,
      'phone' || 'mobile' => TextInputType.phone,
      _ => TextInputType.text,
    };
    return TextInputUIState(nodeId: node.id, questionText: question, inputType: inputType, answerKey: '',
        extra: type == 'date' ? const {'inputType': 'date'} : const {});
  }

  String _question(NodeUIState ui) =>
      ui is FileUploadUIState ? ui.questionText : (ui is TextInputUIState ? ui.questionText : '');

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    botSay(state, _question(ui), ui.nodeId, nodeType);
    return NodeResult.displayUI(ui);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final data = node.data;
    final type = data['type'];
    final ctx = node.ctx;

    if (type == 'file') {
      dynamic url = response is Map ? response['url'] : null;
      if (!jsTruthy(url) && response is Map && response['file'] is Map) {
        final file = response['file'] as Map;
        if (jsNumber(file['size']) > 5000000) {
          return NodeResult.invalid(t('upload.tooBig', {'mb': 5}), uiState: _ui(node, state));
        }
        final up = await ctx.upload(UploadFile.fromMap(file));
        if (!up.ok) return NodeResult.invalid(t('upload.failed'), uiState: _ui(node, state));
        url = up.url;
      }
      if (!jsTruthy(url)) return NodeResult.displayUI(_ui(node, state));
      pushAnswer(state, {'id': node.id, 'shape': 'user-input-response', 'type': type, 'url': url}, ctx.now());
      userSay(state, _str(url), node.id);
      return NodeResult.next();
    }

    final value = typedText(response);
    if (value.isEmpty) return NodeResult.displayUI(_ui(node, state));
    if (type == 'email' && !isValidEmail(value)) {
      return NodeResult.invalid(ownerTextOr(data['incorrectEmailResponse'], en.emailInvalid, ['Please enter a valid email']),
          uiState: _ui(node, state));
    }
    if (type == 'number' && (value.trim().isEmpty || jsNumber(value.trim()).isNaN)) {
      return NodeResult.invalid(ownerTextOr(data['incorrectNumberResponse'], en.numberInvalid), uiState: _ui(node, state));
    }
    if (type == 'url' && !_legacyUrlRe.hasMatch(value.toLowerCase())) {
      return NodeResult.invalid(ownerTextOr(data['incorrectUrlResponse'], en.urlInvalid), uiState: _ui(node, state));
    }
    if (type == 'name') state.setUserName(value);
    if (type == 'email') state.setUserEmail(value);
    if (type == 'phone' || type == 'mobile') state.setUserPhone(value);

    pushAnswer(state, {'id': node.id, 'shape': 'user-input-response', 'type': type, 'text': value}, ctx.now());
    userSay(state, value, node.id);

    if (type == 'date') return NodeResult.next();
    if (type == 'name') {
      final greet = data['nameGreet'];
      final greeting = nameGreetingHtml(jsTruthy(greet) ? greet : null, value);
      await ctx.typing(1000);
      if (greeting.isNotEmpty) botSay(state, shownText(state, greeting), node.id, nodeType);
      return NodeResult.delayedProceed(null, 1000);
    }
    return NodeResult.delayedProceed(null, 500);
  }
}

// ========================================
// USER RANGE
// ========================================

/// user-range-node: a number; below minVal -> source-1, within -> source-2, above maxVal -> source-3.
class UserRangeNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'user-range-node';

  TextInputUIState _ui(FlowNode node, ChatState state) => TextInputUIState(
        nodeId: node.id,
        questionText: shownText(state, node.data['rangePrompt']),
        inputType: TextInputType.number,
        answerKey: '',
      );

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    botSay(state, ui.questionText, ui.nodeId, nodeType);
    return NodeResult.displayUI(ui);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final value = typedText(response);
    final n = parseNumberInput(value);
    if (n == null) return NodeResult.invalid(en.numberLike, uiState: _ui(node, state));
    pushAnswer(state, {'id': node.id, 'shape': 'user-input-response-range', 'type': node.data['type'], 'text': value},
        node.ctx.now());
    userSay(state, value, node.id);
    final handle = n < _numOf(node.data, 'minVal')
        ? 'source-1'
        : n > _numOf(node.data, 'maxVal')
            ? 'source-3'
            : 'source-2';
    return NodeResult.port(handle);
  }
}

// ========================================
// USER RATING
// ========================================

/// user-rating-node: type number (data.range buttons), star or smiley (five); the first edge.
class UserRatingNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'user-rating-node';

  int _count(Map<String, dynamic> data) {
    if (data['type'] != 'number') return 5;
    final r = _numOf(data, 'range');
    final v = (r.isNaN || r == 0) ? 5.0 : r;
    return v < 1 ? 1 : v.toInt();
  }

  RatingUIState _ui(FlowNode node, ChatState state) {
    final type = node.data['type'];
    return RatingUIState(
      nodeId: node.id,
      questionText: shownText(state, node.data['ratingPrompt']),
      ratingType: type == 'number' ? RatingType.number : (type == 'smiley' ? RatingType.smiley : RatingType.star),
      minValue: 1,
      maxValue: _count(node.data),
    );
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    botSay(state, ui.questionText ?? '', ui.nodeId, nodeType);
    return NodeResult.displayUI(ui);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final raw = response is Map ? (response['value'] ?? response['rating']) : response;
    final rating = raw == null && response is Map ? double.nan : jsNumber(raw);
    if (!_isInteger(rating) || rating < 1 || rating > _count(node.data)) return NodeResult.displayUI(_ui(node, state));
    final r = rating.toInt();
    pushAnswer(state, {'id': node.id, 'shape': 'user-selected-rating', 'type': node.data['type'], 'rating': r}, node.ctx.now());
    userSay(state, '$r', node.id);
    return NodeResult.next();
  }
}

// ========================================
// QUIZ
// ========================================

/// quiz-node: option1..5 (disableOption3..5), correctAnswer "optionN".
/// Wrong -> source-1, right -> source-2. When source-2 leads to a
/// variable-node, that step is not run: its value is ADDED to the flow
/// variable (the score) and the flow jumps to the step after it.
class QuizNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'quiz-node';

  bool _hidden(Map<String, dynamic> data, int n) => n >= 3 && jsTruthy(data['disableOption$n']);

  SingleChoiceUIState _ui(FlowNode node, ChatState state) => SingleChoiceUIState(
        nodeId: node.id,
        questionText: shownText(state, node.data['quizPrompt']),
        choices: _numberedButtons(state, node.data, 'option', 5, (n) => _hidden(node.data, n)),
      );

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    botSay(state, ui.questionText ?? '', ui.nodeId, nodeType);
    return NodeResult.displayUI(ui);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final data = node.data;
    final n = _pickedNumber(response);
    if (!_isInteger(n) || n < 1 || n > 5 || _hidden(data, n.toInt())) return NodeResult.displayUI(_ui(node, state));
    final option = 'option${n.toInt()}';
    final correctAnswer = data['correctAnswer'];
    pushAnswer(
        state,
        {
          'id': node.id,
          'shape': 'user-selected-quiz-option',
          'options': data,
          'selectedOption': data[option],
          'correctAnswer': correctAnswer,
          'correct': option == correctAnswer,
        },
        node.ctx.now());
    userSay(state, savedText(data[option]), node.id);
    if (option != correctAnswer) return NodeResult.port('source-1');

    final ctx = node.ctx;
    final rightEdge = ctx.edges().where((e) => e['sourceHandle'] == 'source-2').firstOrNull;
    final nextNode = rightEdge == null ? null : ctx.node(_str(rightEdge['target']));
    if (nextNode != null && nextNode['type'] == 'variable-node') {
      final nd = nextNode['data'] is Map ? Map<String, dynamic>.from(nextNode['data'] as Map) : <String, dynamic>{};
      final name = _str(nd['name']);
      final current = state.getVariable(name);
      final add = _numOf(nd, 'value');
      final value = jsTruthy(current) ? jsNumber(current) + add : add;
      state.setVariable(name, value.isFinite ? jsNum(value) : value);
      final after = ctx.edgesOf(_str(nextNode['id'])).firstOrNull;
      final target = after?['target'];
      if (jsTruthy(target)) return NodeResult.jumpTo(_str(target));
      return NodeResult.port('source-1');
    }
    return NodeResult.port('source-2');
  }
}

// ========================================
// REGISTRATION
// ========================================

final List<NodeHandler> legacyHandlers = [
  UserInputNodeHandler(),
  UserRangeNodeHandler(),
  QuizNodeHandler(),
  TwoChoicesNodeHandler(),
  ThreeChoicesNodeHandler(),
  SelectOptionNodeHandler(),
  UserRatingNodeHandler(),
];
