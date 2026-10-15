/// Abstract class representing the possible UI states from a node handler
abstract class NodeUIState {
  final String nodeId;

  /// What a step adds for custom renderers (a consent text, a checkout
  /// link, an OTP stage...).
  final Map<String, dynamic> extra;

  const NodeUIState({required this.nodeId, this.extra = const {}});
}

/// Text input types for ask question handlers
/// These map to the chatbot node's input type configuration
enum TextInputType { text, name, email, phone, number, url, location }

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
    super.extra,
  });
}

/// File upload input
class FileUploadUIState extends NodeUIState {
  final String questionText;
  final int maxSizeMb;
  final List<String>? allowedTypes;
  final String? answerKey;

  /// The visitor may skip it.
  final bool optional;

  /// The accepted types in words ("PDF or image").
  final String? typesInWords;

  const FileUploadUIState({
    required this.questionText,
    this.maxSizeMb = 10,
    this.allowedTypes,
    this.answerKey,
    this.optional = false,
    this.typesInWords,
    required super.nodeId,
  });
}

/// Voice input for recording voice messages
class VoiceInputUIState extends NodeUIState {
  final String questionText;
  final int maxDurationSeconds;
  final String? answerKey;
  final bool allowTextFallback;

  const VoiceInputUIState({
    required this.questionText,
    this.maxDurationSeconds = 120,
    this.answerKey,
    this.allowTextFallback = true,
    required super.nodeId,
  });
}

// ==================== CHOICE UI STATES ====================

/// Choice option model
class ChoiceOption {
  final String id;
  final String text;
  final String? description;

  /// What picking it saves (the option's own text, HTML stripped).
  final dynamic value;

  /// A link the button opens (navigate, carousel and payment steps).
  final String? url;

  const ChoiceOption({
    required this.id,
    required this.text,
    this.description,
    this.value,
    this.url,
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
    super.extra,
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
    super.extra,
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

  /// What each value means ("Terrible" ... "Amazing"), in order.
  final List<String>? labels;

  /// The faces a smiley rating shows, in order.
  final List<String>? faces;

  const RatingUIState({
    this.questionText,
    required this.ratingType,
    this.minValue = 1,
    this.maxValue = 5,
    this.minLabel,
    this.maxLabel,
    this.labels,
    this.faces,
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
  final String? timezone;
  final String? answerKey;

  /// "date", "time" or "datetime".
  final String mode;

  /// The bookable times per day ("YYYY-MM-DD" -> ["09:30", ...]).
  final Map<String, List<String>>? availableSlots;

  const CalendarUIState({
    this.questionText,
    this.showTimeSelection = false,
    this.minDate,
    this.maxDate,
    this.disabledDays,
    this.timezone,
    this.answerKey,
    this.mode = 'date',
    this.availableSlots,
    required super.nodeId,
    super.extra,
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

/// Alias for backward compatibility
typedef Question = QuestionDefinition;

/// Pre-chat question for human handover (extends QuestionDefinition with id)
class PreChatQuestion extends QuestionDefinition {
  final String id;

  const PreChatQuestion({
    required this.id,
    required super.questionText,
    required super.answerType,
    required super.answerKey,
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

  final String? questionText;

  /// The pay button's label ("Pay now · \$12.50").
  final String? buttonLabel;

  const PaymentUIState({
    required this.paymentUrl,
    this.amount,
    this.currency,
    this.description,
    this.questionText,
    this.buttonLabel,
    required super.nodeId,
    super.extra,
  });
}

// ==================== REDIRECT UI STATE ====================

/// URL redirect
class RedirectUIState extends NodeUIState {
  final String url;
  final bool openInNewTab;

  final String? questionText;

  const RedirectUIState({
    required this.url,
    this.openInNewTab = true,
    this.questionText,
    required super.nodeId,
  });
}

// ==================== VOICE MESSAGE UI STATE ====================

/// Voice message display state for received voice messages
class VoiceMessageUIState extends NodeUIState {
  final String audioUrl;
  final Duration? duration;
  final List<double>? waveformData;
  final bool isUserMessage;

  const VoiceMessageUIState({
    required this.audioUrl,
    this.duration,
    this.waveformData,
    this.isUserMessage = false,
    required super.nodeId,
  });
}

// ==================== CAROUSEL UI STATE ====================

/// A carousel button: a path (leaves by its own handle) or a link.
class CarouselButton {
  final String id;
  final String label;

  /// Set for a link button: it opens the page and the step keeps waiting.
  final String? url;

  const CarouselButton({required this.id, required this.label, this.url});
}

/// One carousel card.
class CarouselCard {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? price;
  final List<CarouselButton> buttons;

  const CarouselCard({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.price,
    this.buttons = const [],
  });
}

/// Cards side by side (carousel-node, product-card-node). With no path
/// button anywhere, a Continue button moves on.
class CarouselUIState extends NodeUIState {
  final String? questionText;
  final List<CarouselCard> cards;
  final bool showContinue;

  const CarouselUIState({
    this.questionText,
    required this.cards,
    this.showContinue = false,
    required super.nodeId,
    super.extra,
  });
}

// ==================== SLIDER UI STATE ====================

/// A value on a scale (slider-node), sent with its submit button.
class SliderUIState extends NodeUIState {
  final String? questionText;
  final num min;
  final num max;
  final num step;
  final num defaultValue;
  final String unit;

  /// "prefix" or "suffix".
  final String unitPosition;
  final String submitLabel;

  const SliderUIState({
    this.questionText,
    required this.min,
    required this.max,
    this.step = 1,
    required this.defaultValue,
    this.unit = '',
    this.unitPosition = 'suffix',
    this.submitLabel = 'Send',
    required super.nodeId,
    super.extra,
  });
}

// ==================== RANKING UI STATE ====================

/// Items the visitor puts in order (ranking-node), then submits.
class RankingUIState extends NodeUIState {
  final String? questionText;
  final List<ChoiceOption> items;
  final String submitLabel;

  const RankingUIState({
    this.questionText,
    required this.items,
    this.submitLabel = 'Send',
    required super.nodeId,
    super.extra,
  });
}

// ==================== MATRIX UI STATE ====================

/// Rows rated against columns (matrix-node): one column per row, or
/// several with mode "multiple".
class MatrixUIState extends NodeUIState {
  final String? questionText;
  final List<ChoiceOption> rows;
  final List<ChoiceOption> columns;

  /// "single" or "multiple".
  final String mode;
  final bool requireAll;
  final String submitLabel;

  const MatrixUIState({
    this.questionText,
    required this.rows,
    required this.columns,
    this.mode = 'single',
    this.requireAll = true,
    this.submitLabel = 'Submit',
    required super.nodeId,
    super.extra,
  });
}

// ==================== ADDRESS UI STATE ====================

/// An address: searched and picked, or typed field by field (address-node).
class AddressUIState extends NodeUIState {
  final String? questionText;

  /// The last search's matches ({line1, city, region, postal, country,
  /// display...}).
  final List<Map<String, dynamic>> results;
  final bool allowManualEntry;

  const AddressUIState({
    this.questionText,
    this.results = const [],
    this.allowManualEntry = true,
    required super.nodeId,
    super.extra,
  });
}
