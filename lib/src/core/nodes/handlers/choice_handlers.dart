/// The choice steps: n-choices, image-choice, yes-or-no, rating-choice,
/// opinion-scale, n-select-option, n-check-options and carousel (React
/// Native src/core/nodes/handlers/ChoiceNodeHandlers.ts). Fields, ports,
/// saved values and records follow the flow-node spec and the web widget
/// (ts/chat/displayStep.ts, handlers/flowOperations.ts, handlers/askQuestions.ts):
///
/// - n-choices / image-choice / yes-or-no / carousel leave by
///   "source-" + the picked item's id; rating by source-<value-1>; opinion
///   scale by source-<value-from>. No edge there ends the chat.
/// - n-select-option and n-check-options have no ports: the first edge,
///   600 ms after the pick.
/// - Labels are shown with the answers filled in; what is saved is the
///   option's own text, HTML stripped.
library;

import '../../flow/inputs.dart' show linkHref;
import '../../flow/js.dart';
import '../../flow/text.dart' show inListOrder;
import '../../state/chat_state.dart';
import '../node_handler.dart';
import '../node_ui_state.dart';
import 'flow_kit.dart';

List<dynamic> _list(dynamic v) => v is List ? v : const [];

String _str(dynamic v) => v == null ? '' : jsString(v);

/// A whole number as the web reads `Number(x)`, or null.
num? _wholeNumber(dynamic v) {
  final d = jsNumber(v);
  if (!d.isFinite || d != d.truncateToDouble()) return null;
  return d.toInt();
}

/// The number picked: `response.value ?? response.rating`, or the answer itself.
dynamic _pickedValue(dynamic response, {bool rating = false}) {
  if (response is Map) return response['value'] ?? (rating ? response['rating'] : null);
  return response;
}

// ========================================
// N CHOICES
// ========================================

/// n-choices-node: choicePrompt, choices [{id, choiceText}] (blank ones hidden).
class ButtonsHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'n-choices-node';

  List<dynamic> _choices(FlowNode node) =>
      _list(node.data['choices']).where((c) => c is Map && _str(c['choiceText']).trim() != '').toList();

  SingleChoiceUIState _ui(FlowNode node, ChatState state) => SingleChoiceUIState(
        nodeId: node.id,
        questionText: shownText(state, node.data['choicePrompt']),
        choices: _choices(node)
            .map((c) => ChoiceOption(
                id: _str(c['id']), text: shownLabel(state, c['choiceText']), value: savedText(c['choiceText'])))
            .toList(),
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
    final choice = _choices(node).cast<Map>().where((c) => _str(c['id']) == id).firstOrNull;
    if (choice == null) return NodeResult.displayUI(_ui(node, state));
    final text = savedText(choice['choiceText']);
    pushAnswer(state, {'id': node.id, 'shape': 'user-selected-choice', 'choices': node.data, 'selectedChoice': text},
        node.ctx.now());
    userSay(state, text, node.id);
    state.setAnswerVariable(node.id, text);
    return NodeResult.port('source-${_str(choice['id'])}');
  }
}

// ========================================
// IMAGE CHOICE
// ========================================

/// image-choice-node: questionText, images [{id, image, label}] (both non-blank to show).
class PictureChoiceHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'image-choice-node';

  List<dynamic> _images(FlowNode node) => _list(node.data['images'])
      .where((i) => i is Map && _str(i['image']).trim() != '' && _str(i['label']).trim() != '')
      .toList();

  ImageChoiceUIState _ui(FlowNode node, ChatState state) => ImageChoiceUIState(
        nodeId: node.id,
        questionText: shownText(state, node.data['questionText']),
        images: _images(node)
            .map((i) => ImageChoiceOption(id: _str(i['id']), label: shownLabel(state, i['label']), imageUrl: _str(i['image'])))
            .toList(),
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
    final image = _images(node).cast<Map>().where((i) => _str(i['id']) == id).firstOrNull;
    if (image == null) return NodeResult.displayUI(_ui(node, state));
    final label = savedText(image['label']);
    pushAnswer(
        state,
        {
          'id': node.id,
          'shape': 'user-selected-image-choice',
          'images': node.data,
          'selectedImageLabel': label,
          'selectedImage': image['image'],
        },
        node.ctx.now());
    userSay(state, label, node.id);
    state.setAnswerVariable(node.id, label);
    return NodeResult.port('source-${_str(image['id'])}');
  }
}

// ========================================
// YES OR NO
// ========================================

const List<Map<String, dynamic>> _yesNoDefault = [
  {'id': '1', 'label': 'Yes'},
  {'id': '2', 'label': 'No'},
];

/// yes-or-no-choice-node: questionText, options [{id, label}] (default Yes "1" / No "2").
class YesOrNoChoiceHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'yes-or-no-choice-node';

  List<dynamic> _options(FlowNode node) {
    final o = node.data['options'];
    return o is List && o.isNotEmpty ? o : _yesNoDefault;
  }

  SingleChoiceUIState _ui(FlowNode node, ChatState state) => SingleChoiceUIState(
        nodeId: node.id,
        questionText: shownText(state, node.data['questionText']),
        choices: _options(node)
            .map((o) => ChoiceOption(id: _str(o['id']), text: shownLabel(state, o['label']), value: savedText(o['label'])))
            .toList(),
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
    final option = _options(node).where((o) => o is Map && _str(o['id']) == id).firstOrNull;
    if (option == null) return NodeResult.displayUI(_ui(node, state));
    final text = savedText(option['label']);
    pushAnswer(
        state,
        {'id': node.id, 'shape': 'user-selected-yes-or-no-choice', 'options': node.data, 'selectedYesOrNoChoice': text},
        node.ctx.now());
    userSay(state, text, node.id);
    state.setAnswerVariable(node.id, text);
    return NodeResult.port('source-${_str(option['id'])}');
  }
}

// ========================================
// RATING
// ========================================

/// What the faces have always recorded (web nodeKit FACE_VALUES).
const List<String> faceValues = ['😡', '😐', '😊', '😀', '😁'];
const List<String> _faceLabels = ['Very unhappy', 'Unhappy', 'Neutral', 'Happy', 'Very happy'];

/// How many buttons a rating shows: five faces, else 1..10 stars (default 5).
int ratingCount(dynamic ratingType) {
  if (ratingType == 'smiley') return 5;
  final n = jsNumber(ratingType);
  final v = (n.isNaN || n == 0) ? 5.0 : n;
  return v.clamp(1, 10).toInt();
}

/// What each score means (web nodeKit ratingWords, English).
List<String> ratingWords(dynamic ratingType, int n) {
  if (ratingType == 'smiley') return _faceLabels;
  if (n == 3) return const ['Bad', 'Okay', 'Great'];
  if (n == 5) return const ['Terrible', 'Bad', 'Okay', 'Good', 'Amazing'];
  return List.generate(n, (i) => '${i + 1} out of $n');
}

/// The value a rating button records: stars, or the face.
String ratingValue(dynamic ratingType, int i) {
  if (ratingType == 'smiley') return (i >= 1 && i <= faceValues.length) ? faceValues[i - 1] : '😊';
  return '⭐' * i;
}

/// rating-choice-node: ratingType 1..10 stars or "smiley" (five faces).
/// Saves the NUMBER; leaves by source-<value-1>.
class RatingHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'rating-choice-node';

  RatingUIState _ui(FlowNode node, ChatState state) {
    final ratingType = node.data['ratingType'];
    final n = ratingCount(ratingType);
    return RatingUIState(
      nodeId: node.id,
      questionText: shownText(state, node.data['questionText']),
      ratingType: ratingType == 'smiley' ? RatingType.smiley : (n > 5 ? RatingType.number : RatingType.star),
      minValue: 1,
      maxValue: n,
      labels: ratingWords(ratingType, n),
      faces: ratingType == 'smiley' ? faceValues : null,
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
    final ratingType = node.data['ratingType'];
    final n = ratingCount(ratingType);
    final value = _wholeNumber(_pickedValue(response, rating: true));
    if (value == null || value < 1 || value > n) return NodeResult.displayUI(_ui(node, state));
    final v = value.toInt();
    final selected = ratingValue(ratingType, v);
    final words = ratingWords(ratingType, n);
    pushAnswer(
        state,
        {
          'id': node.id,
          'shape': 'user-selected-rating-choice',
          'options': node.data,
          'selectedRatingChoice': selected,
          'value': v,
          'label': v - 1 < words.length ? words[v - 1] : '',
          'ratingType': ratingType,
        },
        node.ctx.now());
    userSay(state, selected, node.id);
    state.setAnswerVariable(node.id, v);
    return NodeResult.port('source-${v - 1}');
  }
}

// ========================================
// OPINION SCALE
// ========================================

/// A scale's range; blank is 0 to 10 (web nodeKit scaleRange).
({num from, num to}) scaleRange(dynamic rawFrom, dynamic rawTo) {
  bool blank(dynamic v) => v == '' || v == null || !jsNumber(v).isFinite;
  final num from = blank(rawFrom) ? 0 : jsNum(jsNumber(rawFrom));
  final num to = blank(rawTo) || jsNumber(rawTo) < from ? (from > 10 ? from : 10) : jsNum(jsNumber(rawTo));
  return (from: from, to: to);
}

/// opinion-scale-choice-node: from..to buttons; saves the NUMBER; leaves by source-<value-from>.
class OpinionScaleHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'opinion-scale-choice-node';

  RatingUIState _ui(FlowNode node, ChatState state) {
    final r = scaleRange(node.data['from'], node.data['to']);
    return RatingUIState(
      nodeId: node.id,
      questionText: shownText(state, node.data['questionText']),
      ratingType: RatingType.opinionScale,
      minValue: r.from.toInt(),
      maxValue: r.to.toInt(),
      minLabel: node.data['fromLabel']?.toString(),
      maxLabel: node.data['toLabel']?.toString(),
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
    final r = scaleRange(node.data['from'], node.data['to']);
    final d = jsNumber(_pickedValue(response));
    if (!d.isFinite || d < r.from || d > r.to) return NodeResult.displayUI(_ui(node, state));
    final value = jsNum(d);
    pushAnswer(
        state,
        {
          'id': node.id,
          'shape': 'user-selected-opinion-scale-choice',
          'options': node.data,
          'selectedOpinionScaleChoice': jsString(value),
          'value': value,
        },
        node.ctx.now());
    userSay(state, jsString(value), node.id);
    state.setAnswerVariable(node.id, value);
    return NodeResult.port('source-${jsString(jsNum((value - r.from).toDouble()))}');
  }
}

// ========================================
// N SELECT OPTION
// ========================================

/// n-select-option-node: selectPrompt, options [{id, optionText}]; no ports - first edge after 600 ms.
class DropdownHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'n-select-option-node';

  List<dynamic> _options(FlowNode node) =>
      _list(node.data['options']).where((o) => o is Map && _str(o['optionText']).trim() != '').toList();

  DropdownUIState _ui(FlowNode node, ChatState state) => DropdownUIState(
        nodeId: node.id,
        questionText: shownText(state, node.data['selectPrompt']),
        options: _options(node).map((o) => SelectOption(id: _str(o['id']), text: shownLabel(state, o['optionText']))).toList(),
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
    final option = _options(node).where((o) => _str(o['id']) == id).firstOrNull;
    if (option == null) return NodeResult.displayUI(_ui(node, state));
    final text = savedText(option['optionText']);
    pushAnswer(state, {'id': node.id, 'shape': 'user-selected-option', 'options': node.data, 'selectedOption': text},
        node.ctx.now());
    userSay(state, text, node.id);
    state.setAnswerVariable(node.id, text);
    return NodeResult.delayedProceed(null, 600);
  }
}

// ========================================
// N CHECK OPTIONS
// ========================================

/// n-check-options-node: checkOptionsPrompt, options; the ticked texts in LIST
/// order joined ", "; first edge after 600 ms.
class NCheckOptionsHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'n-check-options-node';

  List<dynamic> _options(FlowNode node) =>
      _list(node.data['options']).where((o) => o is Map && _str(o['optionText']).trim() != '').toList();

  MultipleChoiceUIState _ui(FlowNode node, ChatState state) => MultipleChoiceUIState(
        nodeId: node.id,
        questionText: shownText(state, node.data['checkOptionsPrompt']),
        options: _options(node).map((o) => SelectOption(id: _str(o['id']), text: shownLabel(state, o['optionText']))).toList(),
      );

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    botSay(state, ui.questionText ?? '', ui.nodeId, nodeType);
    return NodeResult.displayUI(ui);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final options = _options(node);
    final raw = response is Map
        ? (response['buttonIds'] is List ? response['buttonIds'] : (response['optionIds'] is List ? response['optionIds'] : const []))
        : const [];
    final ids = (raw as List).map(_str).toList();
    final ticked = inListOrder(ids, options.map((o) => _str(o['id'])).toList())
        .map((id) => options.where((o) => _str(o['id']) == id).firstOrNull)
        .whereType<Map>()
        .toList();
    if (ticked.isEmpty) return NodeResult.displayUI(_ui(node, state));
    final text = ticked.map((o) => savedText(o['optionText'])).join(', ');
    pushAnswer(
        state,
        {'id': node.id, 'shape': 'user-selected-check-options', 'options': node.data, 'selectedCheckOptions': text},
        node.ctx.now());
    userSay(state, text, node.id);
    state.setAnswerVariable(node.id, text);
    return NodeResult.delayedProceed(null, 600);
  }
}

// ========================================
// CAROUSEL
// ========================================

const String carouselContinue = 'Continue';

/// A carousel card as the web reads it (nodeKit carouselCards).
class CarouselCardData {
  final String id;
  final String image;
  final String title;
  final String description;
  final String price;
  final List<CarouselButtonData> buttons;

  const CarouselCardData(this.id, this.image, this.title, this.description, this.price, this.buttons);
}

/// A carousel button: "path" (leaves by its handle) or "link" (href).
class CarouselButtonData {
  final String id;
  final String label;
  final String action;
  final String href;

  const CarouselButtonData(this.id, this.label, this.action, this.href);
}

/// The cards as the web reads them (nodeKit carouselCards): at most 10, 3 buttons each.
List<CarouselCardData> carouselCards(dynamic data) {
  final cards = data is Map ? _list(data['cards']) : const [];
  final out = <CarouselCardData>[];
  for (var ci = 0; ci < cards.length; ci++) {
    final card = cards[ci] is Map ? cards[ci] as Map : const {};
    final buttons = <CarouselButtonData>[];
    final rawButtons = _list(card['buttons']);
    for (var bi = 0; bi < rawButtons.length; bi++) {
      final b = rawButtons[bi] is Map ? rawButtons[bi] as Map : const {};
      final action = b['action'] == 'link' ? 'link' : 'path';
      final btn = CarouselButtonData(
        b['id'] != null ? _str(b['id']) : '$ci-$bi',
        _str(b['label']).trim(),
        action,
        action == 'link' ? linkHref(b['url']) : '',
      );
      if (btn.label.isNotEmpty && (btn.action == 'path' || btn.href.isNotEmpty)) buttons.add(btn);
    }
    final c = CarouselCardData(
      card['id'] != null ? _str(card['id']) : 'card-$ci',
      _str(card['image']).trim(),
      _str(card['title']).trim(),
      _str(card['description']).trim(),
      _str(card['price']).trim(),
      buttons.take(3).toList(),
    );
    if (c.title.isNotEmpty || c.description.isNotEmpty || c.image.isNotEmpty) out.add(c);
  }
  return out.take(10).toList();
}

/// carousel-node: a path button leaves by "source-" + its id and saves
/// "Card title - Button label"; link buttons only open their page. With no
/// path button anywhere, Continue leaves by "source" and saves nothing.
/// Answers: {buttonId} (cardId optional) or {action: "continue"}.
class CarouselHandler extends BaseNodeHandler {
  @override
  String get nodeType => 'carousel-node';

  CarouselUIState _ui(FlowNode node, ChatState state) {
    final cards = carouselCards(node.data);
    final hasPath = cards.any((c) => c.buttons.any((b) => b.action == 'path'));
    return CarouselUIState(
      nodeId: node.id,
      questionText: shownText(state, node.data['questionText']),
      showContinue: !hasPath,
      cards: cards
          .map((c) => CarouselCard(
                id: c.id,
                title: shownLabel(state, c.title),
                description: c.description.isNotEmpty ? shownLabel(state, c.description) : null,
                imageUrl: c.image.isNotEmpty ? c.image : null,
                price: c.price.isNotEmpty ? c.price : null,
                buttons: c.buttons
                    .map((b) => CarouselButton(id: b.id, label: b.label, url: b.href.isNotEmpty ? b.href : null))
                    .toList(),
              ))
          .toList(),
    );
  }

  @override
  Future<NodeResult> handle(FlowNode node, ChatState state) async {
    final ui = _ui(node, state);
    final question = ui.questionText ?? '';
    if (question.isNotEmpty) botSay(state, question, ui.nodeId, nodeType);
    return NodeResult.displayUI(ui);
  }

  @override
  Future<NodeResult> handleResponse(dynamic response, FlowNode node, ChatState state) async {
    final cards = carouselCards(node.data);
    final isContinue = response is Map && response['action'] == 'continue';
    final buttonId = isContinue ? null : pickedId(response);
    final cardId = response is Map ? response['cardId'] : null;
    CarouselCardData? card;
    CarouselButtonData? button;
    for (final c in cards) {
      final b = c.buttons.where((x) => x.id == buttonId && x.action == 'path').firstOrNull;
      if (b != null && (!jsTruthy(cardId) || cardId == c.id)) {
        card = c;
        button = b;
        break;
      }
    }
    // A link button: it opens its page and the step keeps waiting.
    if (buttonId != null && button == null) return NodeResult.displayUI(_ui(node, state));
    if (button == null && cards.any((c) => c.buttons.any((b) => b.action == 'path'))) {
      return NodeResult.displayUI(_ui(node, state));
    }
    final title = card?.title ?? '';
    final label = button?.label ?? '';
    final answer = button != null
        ? (title.isNotEmpty && label.isNotEmpty ? '$title - $label' : (title.isNotEmpty ? title : label))
        : carouselContinue;
    final text = savedText(answer);
    pushAnswer(
        state,
        {
          'id': node.id,
          'shape': 'user-selected-carousel',
          'carousel': node.data,
          'selectedChoice': text,
          'selectedCardId': card?.id,
          'selectedButtonId': button?.id,
        },
        node.ctx.now());
    userSay(state, text, node.id);
    if (button != null) state.setAnswerVariable(node.id, text);
    return NodeResult.port(button != null ? 'source-${button.id}' : 'source');
  }
}

// ========================================
// REGISTRATION
// ========================================

final List<NodeHandler> choiceHandlers = [
  ButtonsHandler(),
  CarouselHandler(),
  PictureChoiceHandler(),
  DropdownHandler(),
  RatingHandler(),
  OpinionScaleHandler(),
  YesOrNoChoiceHandler(),
  NCheckOptionsHandler(),
];
