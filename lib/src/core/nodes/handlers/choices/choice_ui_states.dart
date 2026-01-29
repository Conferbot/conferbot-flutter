/// Choice UI state classes
///
/// Contains all UI state classes for choice-based interactions:
/// - SingleChoiceState (button selection)
/// - MultipleChoiceState (checkbox selection)
/// - DropdownState (dropdown selection)
/// - ImageChoiceState (image grid selection)
/// - RatingState (star/number/smiley ratings)
library;

import '../legacy_handlers.dart' show NodeUIState;

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

/// Choice option for single/multiple choice
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
