/// Selection-based choice handlers
///
/// Handlers for dropdown and multi-select choices:
/// - SelectOptionNodeHandler (legacy dropdown)
/// - NSelectOptionNodeHandler (dynamic dropdown)
/// - NCheckOptionsNodeHandler (checkbox multi-select)
/// - ImageChoiceNodeHandler (image grid selection)
library;

import '../../node_types.dart';
import '../legacy_handlers.dart';
import 'choice_ui_states.dart';

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
          text: resolveText(stripHtml(optionText)),
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
    state?.setVariable('_lastUserChoice', cleanText);
    state?.addToTranscript('user', cleanText);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-selected-option',
      text: cleanText,
      type: nodeType,
    );

    // Use __targetPort from response for port-based edge resolution
    final targetPort = responseMap['__targetPort']?.toString();
    return DelayedProceed(delayMs: 600, targetPort: targetPort);
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
        text: resolveText(stripHtml(option['optionText']?.toString() ?? '')),
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
    state?.setVariable('_lastUserChoice', cleanText);
    state?.addToTranscript('user', cleanText);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-selected-option',
      text: cleanText,
      type: nodeType,
    );

    // Use __targetPort from response for port-based edge resolution
    final targetPort = responseMap['__targetPort']?.toString();
    return DelayedProceed(delayMs: 600, targetPort: targetPort);
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
        text: resolveText(stripHtml(option['optionText']?.toString() ?? '')),
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
    // Response should be list of selected options or a map with selections
    List<String> selectedOptions;
    String? targetPort;

    if (response is Map) {
      final responseMap = Map<String, dynamic>.from(response);
      targetPort = responseMap['__targetPort']?.toString();
      final selections = responseMap['selections'];
      if (selections is List) {
        selectedOptions = selections.whereType<String>().toList();
      } else {
        selectedOptions = [responseMap['text']?.toString() ?? response.toString()];
      }
    } else if (response is List) {
      selectedOptions = response.whereType<String>().toList();
    } else if (response is String) {
      selectedOptions = response.split(',').map((s) => s.trim()).toList();
    } else {
      selectedOptions = [response.toString()];
    }

    final combinedText = selectedOptions.join(', ');

    state?.setAnswerVariable(nodeId, combinedText);
    state?.setVariable('_lastUserChoice', combinedText);
    state?.addToTranscript('user', combinedText);

    recordResponse(
      nodeId: nodeId,
      shape: 'user-check-options-response',
      text: combinedText,
      type: nodeType,
      additionalData: {'selectedOptions': selectedOptions},
    );

    // Use __targetPort from response for port-based edge resolution
    return Proceed(targetPort: targetPort);
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
        label: resolveText(image['label']?.toString() ?? ''),
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
    state?.setVariable('_lastUserChoice', label);
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
