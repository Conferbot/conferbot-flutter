import 'package:flutter/material.dart' show TextInputType;

/// Sealed class representing the possible UI states from a node handler
sealed class NodeUIState {
  final String nodeId;

  const NodeUIState({required this.nodeId});
}

// ==================== MESSAGE UI STATES ====================

/// Simple text message display
class MessageUIState extends NodeUIState {
  final String text;

  const MessageUIState({
    required this.text,
    required super.nodeId,
  });
}

/// Image display
class ImageUIState extends NodeUIState {
  final String url;
  final String? caption;
  final String? altText;

  const ImageUIState({
    required this.url,
    this.caption,
    this.altText,
    required super.nodeId,
  });
}

/// Video display
class VideoUIState extends NodeUIState {
  final String url;
  final String? caption;
  final bool autoplay;

  const VideoUIState({
    required this.url,
    this.caption,
    this.autoplay = false,
    required super.nodeId,
  });
}

/// Audio player display
class AudioUIState extends NodeUIState {
  final String url;
  final String? title;

  const AudioUIState({
    required this.url,
    this.title,
    required super.nodeId,
  });
}

/// File download display
class FileUIState extends NodeUIState {
  final String url;
  final String fileName;
  final String? fileSize;

  const FileUIState({
    required this.url,
    required this.fileName,
    this.fileSize,
    required super.nodeId,
  });
}

/// HTML content display
class HtmlUIState extends NodeUIState {
  final String htmlContent;

  const HtmlUIState({
    required this.htmlContent,
    required super.nodeId,
  });
}

// ==================== INPUT UI STATES ====================

/// Text input field
class TextInputUIState extends NodeUIState {
  final String questionText;
  final TextInputType inputType;
  final String? placeholder;
  final String? validationRegex;
  final String? errorMessage;
  final String? answerKey;

  const TextInputUIState({
    required this.questionText,
    required this.inputType,
    this.placeholder,
    this.validationRegex,
    this.errorMessage,
    this.answerKey,
    required super.nodeId,
  });
}

/// File upload input
class FileUploadUIState extends NodeUIState {
  final String questionText;
  final int maxSizeMb;
  final List<String>? allowedTypes;

  const FileUploadUIState({
    required this.questionText,
    this.maxSizeMb = 10,
    this.allowedTypes,
    required super.nodeId,
  });
}

// ==================== CHOICE UI STATES ====================

/// Choice option model
class ChoiceOption {
  final String id;
  final String text;
  final String? description;

  const ChoiceOption({
    required this.id,
    required this.text,
    this.description,
  });
}

/// Select option model (for dropdown)
class SelectOption {
  final String id;
  final String text;

  const SelectOption({
    required this.id,
    required this.text,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectOption &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Image choice option model
class ImageChoiceOption {
  final String id;
  final String label;
  final String imageUrl;

  const ImageChoiceOption({
    required this.id,
    required this.label,
    required this.imageUrl,
  });
}

/// Single choice (buttons)
class SingleChoiceUIState extends NodeUIState {
  final String? questionText;
  final List<ChoiceOption> choices;

  const SingleChoiceUIState({
    this.questionText,
    required this.choices,
    required super.nodeId,
  });
}

/// Multiple choice (checkboxes)
class MultipleChoiceUIState extends NodeUIState {
  final String? questionText;
  final List<SelectOption> options;
  final int? minSelections;
  final int? maxSelections;

  const MultipleChoiceUIState({
    this.questionText,
    required this.options,
    this.minSelections,
    this.maxSelections,
    required super.nodeId,
  });
}

/// Image choice grid
class ImageChoiceUIState extends NodeUIState {
  final String? questionText;
  final List<ImageChoiceOption> images;

  const ImageChoiceUIState({
    this.questionText,
    required this.images,
    required super.nodeId,
  });
}

/// Dropdown selection
class DropdownUIState extends NodeUIState {
  final String? questionText;
  final List<SelectOption> options;
  final String? placeholder;

  const DropdownUIState({
    this.questionText,
    required this.options,
    this.placeholder,
    required super.nodeId,
  });
}

// ==================== RATING UI STATES ====================

/// Rating type enumeration
enum RatingType { star, number, smiley, opinionScale }

/// Rating selection (stars, numbers, smileys)
class RatingUIState extends NodeUIState {
  final String? questionText;
  final RatingType ratingType;
  final int minValue;
  final int maxValue;
  final String? minLabel;
  final String? maxLabel;

  const RatingUIState({
    this.questionText,
    required this.ratingType,
    this.minValue = 1,
    this.maxValue = 5,
    this.minLabel,
    this.maxLabel,
    required super.nodeId,
  });
}

// ==================== RANGE UI STATE ====================

/// Range/slider selection
class RangeUIState extends NodeUIState {
  final String? questionText;
  final int minValue;
  final int maxValue;
  final int? defaultValue;
  final String? minLabel;
  final String? maxLabel;

  const RangeUIState({
    this.questionText,
    required this.minValue,
    required this.maxValue,
    this.defaultValue,
    this.minLabel,
    this.maxLabel,
    required super.nodeId,
  });
}

// ==================== CALENDAR UI STATE ====================

/// Calendar/date picker
class CalendarUIState extends NodeUIState {
  final String? questionText;
  final bool showTimeSelection;
  final DateTime? minDate;
  final DateTime? maxDate;
  final List<int>? disabledDays;

  const CalendarUIState({
    this.questionText,
    this.showTimeSelection = false,
    this.minDate,
    this.maxDate,
    this.disabledDays,
    required super.nodeId,
  });
}

// ==================== QUIZ UI STATE ====================

/// Quiz question
class QuizUIState extends NodeUIState {
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;

  const QuizUIState({
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required super.nodeId,
  });
}

// ==================== MULTIPLE QUESTIONS UI STATE ====================

/// Question definition for multi-question forms
class QuestionDefinition {
  final String questionText;
  final String answerType;
  final String answerKey;

  const QuestionDefinition({
    required this.questionText,
    required this.answerType,
    required this.answerKey,
  });
}

/// Multiple sequential questions
class MultipleQuestionsUIState extends NodeUIState {
  final List<QuestionDefinition> questions;
  final int currentIndex;

  const MultipleQuestionsUIState({
    required this.questions,
    this.currentIndex = 0,
    required super.nodeId,
  });
}

// ==================== HUMAN HANDOVER UI STATE ====================

/// Handover state enumeration
enum HandoverState {
  preChatQuestions,
  waitingForAgent,
  agentConnected,
  noAgentsAvailable,
  postChatSurvey,
}

/// Human handover
class HumanHandoverUIState extends NodeUIState {
  final HandoverState state;
  final String? handoverMessage;
  final List<QuestionDefinition>? preChatQuestions;
  final int currentQuestionIndex;
  final String? agentName;
  final int? maxWaitTime;

  const HumanHandoverUIState({
    required this.state,
    this.handoverMessage,
    this.preChatQuestions,
    this.currentQuestionIndex = 0,
    this.agentName,
    this.maxWaitTime,
    required super.nodeId,
  });
}

// ==================== PAYMENT UI STATE ====================

/// Payment/Stripe checkout
class PaymentUIState extends NodeUIState {
  final String paymentUrl;
  final double? amount;
  final String? currency;
  final String? description;

  const PaymentUIState({
    required this.paymentUrl,
    this.amount,
    this.currency,
    this.description,
    required super.nodeId,
  });
}

// ==================== REDIRECT UI STATE ====================

/// URL redirect
class RedirectUIState extends NodeUIState {
  final String url;
  final bool openInNewTab;

  const RedirectUIState({
    required this.url,
    this.openInNewTab = true,
    required super.nodeId,
  });
}
