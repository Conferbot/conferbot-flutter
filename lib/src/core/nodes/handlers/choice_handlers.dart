import '../node_types.dart';
import 'legacy_handlers.dart';

// ============================================================================
// CHOICE UI STATES
// ============================================================================

/// Single choice selection (buttons)
class SingleChoiceState extends NodeUIState {
  final String? questionText;
  final List<Choice> choices;
  final String nodeId;
  final String answerKey;

  const SingleChoiceState({
    this.questionText,
    required this.choices,
    required this.nodeId,
    required this.answerKey,
  });
}

/// Choice option
class Choice {
  final String id;
  final String text;
  final String? imageUrl;
  final String? targetPort;

  const Choice({
    required this.id,
    required this.text,
    this.imageUrl,
    this.targetPort,
  });
}

/// Multiple choice selection (checkboxes)
class MultipleChoiceState extends NodeUIState {
  final String? questionText;
  final List<ChoiceOption> options;
  final String nodeId;
  final String answerKey;

  const MultipleChoiceState({
    this.questionText,
    required this.options,
    required this.nodeId,
    required this.answerKey,
  });
}

/// Choice option for multiple choice
class ChoiceOption {
  final String id;
  final String text;

  const ChoiceOption({
    required this.id,
    required this.text,
  });
}

/// Dropdown selection
class DropdownState extends NodeUIState {
  final String? questionText;
  final List<DropdownOption> options;
  final String nodeId;
  final String answerKey;

  const DropdownState({
    this.questionText,
    required this.options,
    required this.nodeId,
    required this.answerKey,
  });
}

/// Dropdown option
class DropdownOption {
  final String id;
  final String text;

  const DropdownOption({
    required this.id,
    required this.text,
  });
}

/// Image choice grid
class ImageChoiceState extends NodeUIState {
  final String? questionText;
  final List<ImageOption> images;
  final String nodeId;
  final String answerKey;

  const ImageChoiceState({
    this.questionText,
    required this.images,
    required this.nodeId,
    required this.answerKey,
  });
}

/// Image option
class ImageOption {
  final String id;
  final String imageUrl;
  final String label;
  final String? targetPort;

  const ImageOption({
    required this.id,
    required this.imageUrl,
    required this.label,
    this.targetPort,
  });
}

/// Rating types
enum RatingType { star, number, smiley, opinionScale }

/// Rating selection (stars/numbers/smiley)
class RatingState extends NodeUIState {
  final String? questionText;
  final RatingType ratingType;
  final int minValue;
  final int maxValue;
  final String nodeId;
  final String answerKey;

  const RatingState({
    this.questionText,
    required this.ratingType,
    required this.minValue,
    required this.maxValue,
    required this.nodeId,
    required this.answerKey,
  });
}

// ============================================================================
// CHOICE NODE HANDLERS
// ============================================================================

/// Handler for two-choices-node
/// Displays two choice buttons with port-based routing
class TwoChoicesNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.twoChoices;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final choice1 = getString(nodeData, 'choice1', 'Option 1');
    final choice2 = getString(nodeData, 'choice2', 'Option 2');
    final disableSecond = getBoolean(nodeData, 'disableSecondChoice', false);
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state?.addAnswerVariable(nodeId, answerKey);

    final choices = <Choice>[
      Choice(
        id: '0',
        text: stripHtml(choice1),
        targetPort: 'source-1',
      ),
    ];

    if (!disableSecond) {
      choices.add(
        Choice(
          id: '1',
          text: stripHtml(choice2),
          targetPort: 'source-2',
        ),
      );
    }

    return DisplayUI(
      SingleChoiceState(
        questionText: null,
        choices: choices,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    Map<String, dynamic> responseMap;
    if (response is Map) {
      responseMap = Map<String, dynamic>.from(response);
    } else {
      responseMap = {'id': response.toString()};
    }

    final choiceId = responseMap['id']?.toString() ?? '0';
    final choiceText = responseMap['text']?.toString() ??
        (choiceId == '0'
            ? getString(nodeData, 'choice1', 'Option 1')
            : getString(nodeData, 'choice2', 'Option 2'));

    final cleanText = stripHtml(choiceText);

    state?.setAnswerVariable(nodeId, cleanText);
    state?.addToTranscript('user', cleanText);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-selected-choice',
      text: cleanText,
      type: nodeType,
      additionalData: {
        'choiceId': choiceId,
        'choices': {
          'choice1': nodeData['choice1'],
          'choice2': nodeData['choice2'],
        },
      },
    );

    final portIndex = int.tryParse(choiceId) ?? 0;
    final targetPort = 'source-${portIndex + 1}';
    return DelayedProceed(delayMs: 600, targetPort: targetPort);
  }
}

/// Handler for three-choices-node
/// Displays three choice buttons with port-based routing
class ThreeChoicesNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.threeChoices;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final choice1 = getString(nodeData, 'choice1', 'Option 1');
    final choice2 = getString(nodeData, 'choice2', 'Option 2');
    final choice3 = getString(nodeData, 'choice3', 'Option 3');
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state?.addAnswerVariable(nodeId, answerKey);

    final choices = [
      Choice(id: '0', text: stripHtml(choice1), targetPort: 'source-1'),
      Choice(id: '1', text: stripHtml(choice2), targetPort: 'source-2'),
      Choice(id: '2', text: stripHtml(choice3), targetPort: 'source-3'),
    ];

    return DisplayUI(
      SingleChoiceState(
        questionText: null,
        choices: choices,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    Map<String, dynamic> responseMap;
    if (response is Map) {
      responseMap = Map<String, dynamic>.from(response);
    } else {
      responseMap = {'id': response.toString()};
    }

    final choiceId = responseMap['id']?.toString() ?? '0';
    String choiceText;
    switch (choiceId) {
      case '0':
        choiceText = responseMap['text']?.toString() ??
            getString(nodeData, 'choice1', 'Option 1');
        break;
      case '1':
        choiceText = responseMap['text']?.toString() ??
            getString(nodeData, 'choice2', 'Option 2');
        break;
      case '2':
        choiceText = responseMap['text']?.toString() ??
            getString(nodeData, 'choice3', 'Option 3');
        break;
      default:
        choiceText = responseMap['text']?.toString() ?? 'Unknown';
    }

    final cleanText = stripHtml(choiceText);

    state?.setAnswerVariable(nodeId, cleanText);
    state?.addToTranscript('user', cleanText);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-selected-choice',
      text: cleanText,
      type: nodeType,
    );

    final portIndex = int.tryParse(choiceId) ?? 0;
    final targetPort = 'source-${portIndex + 1}';
    return DelayedProceed(delayMs: 600, targetPort: targetPort);
  }
}

/// Handler for n-choices-node
/// Displays N choice buttons dynamically with port-based routing
class NChoicesNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.nChoices;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final choicesData = getList<Map<String, dynamic>>(nodeData, 'choices');
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state?.addAnswerVariable(nodeId, answerKey);

    final choices = choicesData.map((choice) {
      final id = choice['id']?.toString() ?? '';
      final text =
          choice['choiceText']?.toString() ?? choice['text']?.toString() ?? '';
      return Choice(
        id: id,
        text: stripHtml(text),
        targetPort: 'source-$id',
      );
    }).toList();

    return DisplayUI(
      SingleChoiceState(
        questionText: null,
        choices: choices,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    Map<String, dynamic> responseMap;
    if (response is Map) {
      responseMap = Map<String, dynamic>.from(response);
    } else {
      responseMap = {'id': response.toString()};
    }

    final choiceId = responseMap['id']?.toString() ?? '';
    final choiceText = responseMap['text']?.toString() ?? choiceId;

    final cleanText = stripHtml(choiceText);

    state?.setAnswerVariable(nodeId, cleanText);
    state?.addToTranscript('user', cleanText);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-selected-choice',
      text: cleanText,
      type: nodeType,
      additionalData: {'choiceId': choiceId},
    );

    return DelayedProceed(delayMs: 600, targetPort: 'source-$choiceId');
  }
}

/// Handler for select-option-node (legacy)
/// Displays dropdown/option selection
class SelectOptionNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.selectOption;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final answerKey = getString(nodeData, 'answerVariable', nodeId);
    state?.addAnswerVariable(nodeId, answerKey);

    // Build options from option1, option2, etc.
    final options = <DropdownOption>[];

    for (int i = 1; i <= 5; i++) {
      final optionKey = 'option$i';
      final disableKey = 'disableOption$i';

      if (getBoolean(nodeData, disableKey, false)) continue;

      final optionText = nodeData[optionKey]?.toString();
      if (optionText != null && optionText.isNotEmpty) {
        options.add(DropdownOption(
          id: (i - 1).toString(),
          text: stripHtml(optionText),
        ));
      }
    }

    return DisplayUI(
      DropdownState(
        questionText: null,
        options: options,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    Map<String, dynamic> responseMap;
    if (response is Map) {
      responseMap = Map<String, dynamic>.from(response);
    } else {
      responseMap = {'text': response.toString()};
    }

    final optionText = responseMap['text']?.toString() ?? '';
    final cleanText = stripHtml(optionText);

    state?.setAnswerVariable(nodeId, cleanText);
    state?.addToTranscript('user', cleanText);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-selected-option',
      text: cleanText,
      type: nodeType,
    );

    return const DelayedProceed(delayMs: 600);
  }
}

/// Handler for n-select-option-node
/// Displays dropdown with dynamic options
class NSelectOptionNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.nSelectOption;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final optionsData = getList<Map<String, dynamic>>(nodeData, 'options');
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state?.addAnswerVariable(nodeId, answerKey);

    final options = optionsData.map((option) {
      return DropdownOption(
        id: option['id']?.toString() ?? '',
        text: stripHtml(option['optionText']?.toString() ?? ''),
      );
    }).toList();

    return DisplayUI(
      DropdownState(
        questionText: null,
        options: options,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    Map<String, dynamic> responseMap;
    if (response is Map) {
      responseMap = Map<String, dynamic>.from(response);
    } else {
      responseMap = {'text': response.toString()};
    }

    final optionText = responseMap['text']?.toString() ?? '';
    final cleanText = stripHtml(optionText);

    state?.setAnswerVariable(nodeId, cleanText);
    state?.addToTranscript('user', cleanText);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-selected-option',
      text: cleanText,
      type: nodeType,
    );

    return const DelayedProceed(delayMs: 600);
  }
}

/// Handler for n-check-options-node
/// Displays multiple checkboxes (multi-select)
class NCheckOptionsNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.nCheckOptions;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final optionsData = getList<Map<String, dynamic>>(nodeData, 'options');
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state?.addAnswerVariable(nodeId, answerKey);

    final options = optionsData.map((option) {
      return ChoiceOption(
        id: option['id']?.toString() ?? '',
        text: stripHtml(option['optionText']?.toString() ?? ''),
      );
    }).toList();

    return DisplayUI(
      MultipleChoiceState(
        questionText: null,
        options: options,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    // Response should be list of selected options
    List<String> selectedOptions;
    if (response is List) {
      selectedOptions = response.whereType<String>().toList();
    } else if (response is String) {
      selectedOptions = response.split(',').map((s) => s.trim()).toList();
    } else {
      selectedOptions = [response.toString()];
    }

    final combinedText = selectedOptions.join(', ');

    state?.setAnswerVariable(nodeId, combinedText);
    state?.addToTranscript('user', combinedText);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-check-options-response',
      text: combinedText,
      type: nodeType,
      additionalData: {'selectedOptions': selectedOptions},
    );

    return const Proceed();
  }
}

/// Handler for image-choice-node
/// Displays image selection grid with port-based routing
class ImageChoiceNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.imageChoice;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final imagesData = getList<Map<String, dynamic>>(nodeData, 'images');
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state?.addAnswerVariable(nodeId, answerKey);

    final images = imagesData.map((image) {
      return ImageOption(
        id: image['id']?.toString() ?? '',
        imageUrl: image['image']?.toString() ?? '',
        label: image['label']?.toString() ?? '',
        targetPort: 'source-${image['id']}',
      );
    }).toList();

    return DisplayUI(
      ImageChoiceState(
        questionText: null,
        images: images,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    Map<String, dynamic> responseMap;
    if (response is Map) {
      responseMap = Map<String, dynamic>.from(response);
    } else {
      responseMap = {'label': response.toString()};
    }

    final imageId = responseMap['id']?.toString() ?? '';
    final label = responseMap['label']?.toString() ?? '';

    state?.setAnswerVariable(nodeId, label);
    state?.addToTranscript('user', label);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-image-choice',
      text: label,
      type: nodeType,
      additionalData: {
        'imageId': imageId,
        'imageUrl': responseMap['imageUrl'] ?? '',
      },
    );

    return DelayedProceed(delayMs: 600, targetPort: 'source-$imageId');
  }
}

/// Handler for yes-or-no-choice-node
/// Displays Yes/No buttons with port-based routing
class YesOrNoChoiceNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.yesOrNoChoice;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final optionsData = getList<Map<String, dynamic>>(nodeData, 'options');
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state?.addAnswerVariable(nodeId, answerKey);

    List<Choice> choices;
    if (optionsData.isNotEmpty) {
      choices = optionsData.map((option) {
        return Choice(
          id: option['id']?.toString() ?? '',
          text: option['label']?.toString() ?? '',
          targetPort: 'source-${option['id']}',
        );
      }).toList();
    } else {
      // Default Yes/No
      choices = [
        const Choice(id: 'yes', text: 'Yes', targetPort: 'source-yes'),
        const Choice(id: 'no', text: 'No', targetPort: 'source-no'),
      ];
    }

    return DisplayUI(
      SingleChoiceState(
        questionText: null,
        choices: choices,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    Map<String, dynamic> responseMap;
    if (response is Map) {
      responseMap = Map<String, dynamic>.from(response);
    } else {
      responseMap = {'id': response.toString(), 'text': response.toString()};
    }

    final optionId = responseMap['id']?.toString() ?? '';
    final label = responseMap['text']?.toString() ?? optionId;

    state?.setAnswerVariable(nodeId, label);
    state?.addToTranscript('user', label);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-yes-or-no-choice',
      text: label,
      type: nodeType,
    );

    return DelayedProceed(delayMs: 600, targetPort: 'source-$optionId');
  }
}

/// Handler for rating-choice-node
/// Displays rating selector (smiley, 5-star, 10-point) with port-based routing
class RatingChoiceNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.ratingChoice;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final ratingTypeStr = getString(nodeData, 'ratingType', '5');
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state?.addAnswerVariable(nodeId, answerKey);

    RatingType type;
    int min;
    int max;

    switch (ratingTypeStr.toLowerCase()) {
      case 'smiley':
        type = RatingType.smiley;
        min = 1;
        max = 5;
        break;
      case '10':
        type = RatingType.number;
        min = 1;
        max = 10;
        break;
      default:
        type = RatingType.star;
        min = 1;
        max = 5;
    }

    return DisplayUI(
      RatingState(
        questionText: null,
        ratingType: type,
        minValue: min,
        maxValue: max,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    int rating;
    if (response is num) {
      rating = response.toInt();
    } else if (response is String) {
      rating = int.tryParse(response) ?? 0;
    } else {
      rating = 0;
    }

    state?.setAnswerVariable(nodeId, rating);
    state?.addToTranscript('user', rating.toString());

    recordResponse(
      nodeId: nodeId,
      shape: 'user-rating-choice',
      text: rating.toString(),
      type: nodeType,
    );

    // Port is 0-indexed (rating 1 -> source-0, etc.)
    final targetPort = 'source-${rating - 1}';
    return DelayedProceed(delayMs: 600, targetPort: targetPort);
  }
}

/// Handler for opinion-scale-choice-node
/// Displays NPS-style opinion scale with port-based routing
class OpinionScaleChoiceNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.opinionScaleChoice;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final from = getInt(nodeData, 'from', 1);
    final to = getInt(nodeData, 'to', 10);
    final answerKey = getString(nodeData, 'answerVariable', nodeId);

    state?.addAnswerVariable(nodeId, answerKey);

    return DisplayUI(
      RatingState(
        questionText: null,
        ratingType: RatingType.opinionScale,
        minValue: from,
        maxValue: to,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    int value;
    if (response is num) {
      value = response.toInt();
    } else if (response is String) {
      value = int.tryParse(response) ?? 0;
    } else {
      value = 0;
    }

    state?.setAnswerVariable(nodeId, value);
    state?.addToTranscript('user', value.toString());

    recordResponse(
      nodeId: nodeId,
      shape: 'user-opinion-scale-choice',
      text: value.toString(),
      type: nodeType,
    );

    // Calculate port index based on from value
    final from = getInt(nodeData, 'from', 1);
    final portIndex = value - from;
    return DelayedProceed(delayMs: 600, targetPort: 'source-$portIndex');
  }
}

/// Handler for user-rating-node (legacy)
/// Displays simple 5-star rating
class UserRatingNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.userRating;

  @override
  Future<NodeResult> process(
      Map<String, dynamic> nodeData, String nodeId) async {
    final answerKey = getString(nodeData, 'answerVariable', nodeId);
    state?.addAnswerVariable(nodeId, answerKey);

    return DisplayUI(
      RatingState(
        questionText: null,
        ratingType: RatingType.star,
        minValue: 1,
        maxValue: 5,
        nodeId: nodeId,
        answerKey: answerKey,
      ),
    );
  }

  @override
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    int rating;
    if (response is num) {
      rating = response.toInt();
    } else if (response is String) {
      rating = int.tryParse(response) ?? 0;
    } else {
      rating = 0;
    }

    state?.setAnswerVariable(nodeId, rating);
    state?.addToTranscript('user', rating.toString());

    recordResponse(
      nodeId: nodeId,
      shape: 'user-rating-response',
      text: rating.toString(),
      type: nodeType,
    );

    return const Proceed();
  }
}
