/// Button choice handlers
///
/// Handlers for button-based choice selections:
/// - TwoChoicesNodeHandler (2 options)
/// - ThreeChoicesNodeHandler (3 options)
/// - NChoicesNodeHandler (N dynamic options)
/// - YesOrNoChoiceNodeHandler (Yes/No toggle)
library;

import '../../node_types.dart';
import '../legacy_handlers.dart';
import 'choice_ui_states.dart';

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
