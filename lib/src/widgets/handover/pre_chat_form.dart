import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';
import '../../utils/validation_utils.dart';

/// Configuration for a pre-chat form field
class PreChatFormField {
  final String id;
  final String questionText;
  final String answerType;
  final String? placeholder;
  final bool required;
  final String? incorrectEmailResponse;
  final String? incorrectPhoneNumberResponse;
  final List<String>? options; // For dropdown type
  final String? validationRegex;
  final int? maxLength;
  final int? minLength;

  const PreChatFormField({
    required this.id,
    required this.questionText,
    required this.answerType,
    this.placeholder,
    this.required = true,
    this.incorrectEmailResponse,
    this.incorrectPhoneNumberResponse,
    this.options,
    this.validationRegex,
    this.maxLength,
    this.minLength,
  });

  factory PreChatFormField.fromJson(Map<String, dynamic> json) {
    return PreChatFormField(
      id: json['id']?.toString() ?? '',
      questionText: json['questionText']?.toString() ?? '',
      answerType: json['answerVariable']?.toString() ?? 'text',
      placeholder: json['placeholder']?.toString(),
      required: json['required'] as bool? ?? true,
      incorrectEmailResponse: json['incorrectEmailResponse']?.toString(),
      incorrectPhoneNumberResponse: json['incorrectPhoneNumberResponse']?.toString(),
      options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      validationRegex: json['validationRegex']?.toString(),
      maxLength: json['maxLength'] as int?,
      minLength: json['minLength'] as int?,
    );
  }

  /// Factory for name field
  factory PreChatFormField.name({
    String? id,
    String? questionText,
    bool required = true,
  }) {
    return PreChatFormField(
      id: id ?? 'name',
      questionText: questionText ?? 'What is your name?',
      answerType: 'name',
      placeholder: 'Enter your name',
      required: required,
    );
  }

  /// Factory for email field
  factory PreChatFormField.email({
    String? id,
    String? questionText,
    bool required = true,
    String? incorrectEmailResponse,
  }) {
    return PreChatFormField(
      id: id ?? 'email',
      questionText: questionText ?? 'What is your email address?',
      answerType: 'email',
      placeholder: 'Enter your email',
      required: required,
      incorrectEmailResponse: incorrectEmailResponse,
    );
  }

  /// Factory for phone field
  factory PreChatFormField.phone({
    String? id,
    String? questionText,
    bool required = false,
    String? incorrectPhoneNumberResponse,
  }) {
    return PreChatFormField(
      id: id ?? 'phone',
      questionText: questionText ?? 'What is your phone number?',
      answerType: 'phone',
      placeholder: 'Enter your phone number',
      required: required,
      incorrectPhoneNumberResponse: incorrectPhoneNumberResponse,
    );
  }

  /// Factory for custom text field
  factory PreChatFormField.custom({
    required String id,
    required String questionText,
    String answerType = 'text',
    String? placeholder,
    bool required = false,
    List<String>? options,
  }) {
    return PreChatFormField(
      id: id,
      questionText: questionText,
      answerType: answerType,
      placeholder: placeholder,
      required: required,
      options: options,
    );
  }
}

/// Result from pre-chat form submission
class PreChatFormResult {
  final Map<String, String> answers;
  final String? name;
  final String? email;
  final String? phone;

  const PreChatFormResult({
    required this.answers,
    this.name,
    this.email,
    this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      'answers': answers,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
    };
  }
}

/// Dynamic pre-chat form widget for human handover
/// Supports name, email, phone, and custom question fields
class PreChatFormWidget extends StatefulWidget {
  /// List of form fields to display
  final List<PreChatFormField> fields;

  /// Called when form is submitted with valid data
  final ValueChanged<PreChatFormResult> onSubmit;

  /// Called when user cancels
  final VoidCallback? onCancel;

  /// Primary color for buttons and accents
  final Color primaryColor;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Optional title for the form
  final String? title;

  /// Optional description text
  final String? description;

  /// Submit button text
  final String submitButtonText;

  /// Cancel button text
  final String cancelButtonText;

  /// Whether to show a cancel button
  final bool showCancelButton;

  /// Whether the form is in loading state
  final bool isLoading;

  /// Whether to show progress indicator
  final bool showProgress;

  /// Custom header widget
  final Widget? headerWidget;

  /// Custom footer widget (below buttons)
  final Widget? footerWidget;

  const PreChatFormWidget({
    super.key,
    required this.fields,
    required this.onSubmit,
    this.onCancel,
    required this.primaryColor,
    this.theme,
    this.title,
    this.description,
    this.submitButtonText = 'Start Chat',
    this.cancelButtonText = 'Cancel',
    this.showCancelButton = false,
    this.isLoading = false,
    this.showProgress = false,
    this.headerWidget,
    this.footerWidget,
  });

  @override
  State<PreChatFormWidget> createState() => _PreChatFormWidgetState();
}

class _PreChatFormWidgetState extends State<PreChatFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, String?> _errors = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      _controllers[field.id] = TextEditingController();
      _focusNodes[field.id] = FocusNode();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  TextInputType _getKeyboardType(String answerType) {
    switch (answerType.toLowerCase()) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
      case 'mobile':
        return TextInputType.phone;
      case 'number':
        return TextInputType.number;
      case 'url':
        return TextInputType.url;
      case 'multiline':
      case 'textarea':
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter>? _getInputFormatters(PreChatFormField field) {
    final formatters = <TextInputFormatter>[];

    switch (field.answerType.toLowerCase()) {
      case 'phone':
      case 'mobile':
        formatters.add(FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')));
        break;
      case 'number':
        formatters.add(FilteringTextInputFormatter.digitsOnly);
        break;
    }

    if (field.maxLength != null) {
      formatters.add(LengthLimitingTextInputFormatter(field.maxLength));
    }

    return formatters.isEmpty ? null : formatters;
  }

  String? _validateField(PreChatFormField field, String? value) {
    if (value == null || value.trim().isEmpty) {
      if (field.required) {
        return 'This field is required';
      }
      return null;
    }

    final trimmedValue = value.trim();

    // Custom regex validation
    if (field.validationRegex != null) {
      final regex = RegExp(field.validationRegex!);
      if (!regex.hasMatch(trimmedValue)) {
        return 'Please enter a valid value';
      }
    }

    // Min length validation
    if (field.minLength != null && trimmedValue.length < field.minLength!) {
      return 'Must be at least ${field.minLength} characters';
    }

    switch (field.answerType.toLowerCase()) {
      case 'email':
        if (!ValidationUtils.isValidEmail(trimmedValue)) {
          return field.incorrectEmailResponse ?? 'Please enter a valid email address';
        }
        break;
      case 'phone':
      case 'mobile':
        if (!ValidationUtils.isValidPhoneNumber(trimmedValue)) {
          return field.incorrectPhoneNumberResponse ?? 'Please enter a valid phone number';
        }
        break;
      case 'name':
        if (trimmedValue.length < 2) {
          return 'Please enter your full name';
        }
        break;
      case 'url':
        if (!Uri.tryParse(trimmedValue)?.hasAbsolutePath ?? true) {
          return 'Please enter a valid URL';
        }
        break;
    }

    return null;
  }

  void _handleSubmit() {
    if (_isSubmitting || widget.isLoading) return;

    // Clear previous errors
    setState(() {
      _errors.clear();
    });

    // Validate all fields
    bool hasError = false;
    final answers = <String, String>{};
    String? name;
    String? email;
    String? phone;

    for (final field in widget.fields) {
      final controller = _controllers[field.id];
      if (controller == null) continue;

      final value = controller.text.trim();
      final error = _validateField(field, value);

      if (error != null) {
        hasError = true;
        setState(() {
          _errors[field.id] = error;
        });
      } else if (value.isNotEmpty) {
        answers[field.id] = value;

        // Extract special fields
        switch (field.answerType.toLowerCase()) {
          case 'name':
            name = value;
            break;
          case 'email':
            email = value;
            break;
          case 'phone':
          case 'mobile':
            phone = value;
            break;
        }
      }
    }

    if (hasError) {
      // Focus first field with error
      for (final field in widget.fields) {
        if (_errors[field.id] != null) {
          _focusNodes[field.id]?.requestFocus();
          break;
        }
      }
      return;
    }

    setState(() => _isSubmitting = true);

    widget.onSubmit(PreChatFormResult(
      answers: answers,
      name: name,
      email: email,
      phone: phone,
    ));
  }

  void _focusNextField(int currentIndex) {
    if (currentIndex < widget.fields.length - 1) {
      final nextField = widget.fields[currentIndex + 1];
      _focusNodes[nextField.id]?.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    return Container(
      decoration: BoxDecoration(
        color: effectiveTheme.colors.surface,
        borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.lg),
        boxShadow: [effectiveTheme.shadows.md],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Custom header widget
          if (widget.headerWidget != null) widget.headerWidget!,

          // Header
          if (widget.title != null || widget.description != null)
            _buildHeader(effectiveTheme),

          // Progress indicator
          if (widget.showProgress)
            LinearProgressIndicator(
              backgroundColor: effectiveTheme.colors.border.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
            ),

          // Form fields
          Padding(
            padding: EdgeInsets.all(effectiveTheme.spacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...widget.fields.asMap().entries.map(
                    (entry) => _buildFormField(entry.value, entry.key, effectiveTheme),
                  ),
                  SizedBox(height: effectiveTheme.spacing.md),
                  _buildButtons(effectiveTheme),
                ],
              ),
            ),
          ),

          // Custom footer widget
          if (widget.footerWidget != null)
            Padding(
              padding: EdgeInsets.only(
                left: effectiveTheme.spacing.md,
                right: effectiveTheme.spacing.md,
                bottom: effectiveTheme.spacing.md,
              ),
              child: widget.footerWidget!,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ConferBotTheme theme) {
    return Container(
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(theme.borderRadius.lg),
          topRight: Radius.circular(theme.borderRadius.lg),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.primaryColor.withOpacity(0.2),
                ),
                child: Icon(
                  Icons.support_agent,
                  color: widget.primaryColor,
                  size: 22,
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.title != null)
                      Text(
                        widget.title!,
                        style: TextStyle(
                          fontSize: theme.typography.fontSizeLg,
                          fontWeight: theme.typography.fontWeightSemiBold,
                          color: theme.colors.text,
                        ),
                      ),
                    if (widget.description != null) ...[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        widget.description!,
                        style: TextStyle(
                          fontSize: theme.typography.fontSizeSm,
                          color: theme.colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(PreChatFormField field, int index, ConferBotTheme theme) {
    final controller = _controllers[field.id]!;
    final focusNode = _focusNodes[field.id]!;
    final error = _errors[field.id];

    // Get icon based on field type
    IconData? prefixIcon;
    switch (field.answerType.toLowerCase()) {
      case 'name':
        prefixIcon = Icons.person_outline;
        break;
      case 'email':
        prefixIcon = Icons.email_outlined;
        break;
      case 'phone':
      case 'mobile':
        prefixIcon = Icons.phone_outlined;
        break;
      case 'url':
        prefixIcon = Icons.link_outlined;
        break;
    }

    final isMultiline = field.answerType.toLowerCase() == 'multiline' ||
        field.answerType.toLowerCase() == 'textarea';

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text with required indicator
          Row(
            children: [
              Expanded(
                child: Text(
                  field.questionText,
                  style: TextStyle(
                    fontSize: theme.typography.fontSizeMd,
                    fontWeight: theme.typography.fontWeightMedium,
                    color: theme.colors.text,
                  ),
                ),
              ),
              if (field.required)
                Text(
                  ' *',
                  style: TextStyle(
                    color: theme.colors.error,
                    fontWeight: theme.typography.fontWeightBold,
                  ),
                ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),

          // Input field
          if (field.options != null && field.options!.isNotEmpty)
            _buildDropdownField(field, controller, theme, error)
          else
            _buildTextField(
              field,
              controller,
              focusNode,
              theme,
              error,
              prefixIcon,
              index,
              isMultiline,
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    PreChatFormField field,
    TextEditingController controller,
    FocusNode focusNode,
    ConferBotTheme theme,
    String? error,
    IconData? prefixIcon,
    int index,
    bool isMultiline,
  ) {
    final isDisabled = _isSubmitting || widget.isLoading;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !isDisabled,
      keyboardType: _getKeyboardType(field.answerType),
      inputFormatters: _getInputFormatters(field),
      textInputAction: isMultiline
          ? TextInputAction.newline
          : (index < widget.fields.length - 1
              ? TextInputAction.next
              : TextInputAction.done),
      maxLines: isMultiline ? 4 : 1,
      onChanged: (_) {
        if (error != null) {
          setState(() {
            _errors.remove(field.id);
          });
        }
      },
      onSubmitted: isMultiline ? null : (_) => _focusNextField(index),
      decoration: InputDecoration(
        hintText: field.placeholder ?? _getDefaultPlaceholder(field.answerType),
        hintStyle: TextStyle(
          color: theme.colors.textSecondary.withOpacity(0.7),
        ),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: error != null
                    ? theme.colors.error
                    : theme.colors.textSecondary,
                size: 20,
              )
            : null,
        filled: true,
        fillColor: isDisabled
            ? theme.colors.background.withOpacity(0.5)
            : theme.colors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.borderRadius.md),
          borderSide: BorderSide(color: theme.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.borderRadius.md),
          borderSide: BorderSide(
            color: error != null ? theme.colors.error : theme.colors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.borderRadius.md),
          borderSide: BorderSide(
            color: error != null ? theme.colors.error : widget.primaryColor,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.borderRadius.md),
          borderSide: BorderSide(color: theme.colors.border.withOpacity(0.5)),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.md,
        ),
      ),
      style: TextStyle(
        fontSize: theme.typography.fontSizeMd,
        color: isDisabled ? theme.colors.textDisabled : theme.colors.text,
      ),
    );
  }

  Widget _buildDropdownField(
    PreChatFormField field,
    TextEditingController controller,
    ConferBotTheme theme,
    String? error,
  ) {
    final isDisabled = _isSubmitting || widget.isLoading;

    return DropdownButtonFormField<String>(
      value: controller.text.isEmpty ? null : controller.text,
      decoration: InputDecoration(
        filled: true,
        fillColor: isDisabled
            ? theme.colors.background.withOpacity(0.5)
            : theme.colors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.borderRadius.md),
          borderSide: BorderSide(color: theme.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.borderRadius.md),
          borderSide: BorderSide(
            color: error != null ? theme.colors.error : theme.colors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.borderRadius.md),
          borderSide: BorderSide(
            color: error != null ? theme.colors.error : widget.primaryColor,
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.md,
        ),
      ),
      hint: Text(
        field.placeholder ?? 'Select an option',
        style: TextStyle(color: theme.colors.textSecondary.withOpacity(0.7)),
      ),
      items: field.options!.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option),
        );
      }).toList(),
      onChanged: isDisabled
          ? null
          : (value) {
              controller.text = value ?? '';
              if (error != null) {
                setState(() {
                  _errors.remove(field.id);
                });
              }
            },
    );
  }

  String _getDefaultPlaceholder(String answerType) {
    switch (answerType.toLowerCase()) {
      case 'name':
        return 'Enter your name';
      case 'email':
        return 'Enter your email address';
      case 'phone':
      case 'mobile':
        return 'Enter your phone number';
      case 'url':
        return 'Enter URL';
      case 'multiline':
      case 'textarea':
        return 'Enter your message';
      default:
        return 'Enter your answer';
    }
  }

  Widget _buildButtons(ConferBotTheme theme) {
    final isDisabled = _isSubmitting || widget.isLoading;

    return Row(
      children: [
        if (widget.showCancelButton && widget.onCancel != null) ...[
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: isDisabled ? null : widget.onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colors.textSecondary,
                  side: BorderSide(color: theme.colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(theme.borderRadius.md),
                  ),
                ),
                child: Text(
                  widget.cancelButtonText,
                  style: TextStyle(
                    fontWeight: theme.typography.fontWeightMedium,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: theme.spacing.md),
        ],
        Expanded(
          flex: widget.showCancelButton ? 1 : 1,
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isDisabled ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: widget.primaryColor.withOpacity(0.6),
                disabledForegroundColor: Colors.white.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.borderRadius.md),
                ),
                elevation: 0,
              ),
              child: _isSubmitting || widget.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.submitButtonText,
                      style: TextStyle(
                        fontWeight: theme.typography.fontWeightSemiBold,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sequential pre-chat question widget (one question at a time)
/// Similar to the web widget's approach
class SequentialPreChatWidget extends StatefulWidget {
  /// List of questions to ask
  final List<PreChatFormField> questions;

  /// Called when a single question is answered
  final void Function(String questionId, String answer) onQuestionAnswered;

  /// Called when all questions are completed
  final ValueChanged<PreChatFormResult> onComplete;

  /// Current question index
  final int currentIndex;

  /// Primary color
  final Color primaryColor;

  /// Theme
  final ConferBotTheme? theme;

  /// Whether to animate transitions
  final bool animateTransitions;

  const SequentialPreChatWidget({
    super.key,
    required this.questions,
    required this.onQuestionAnswered,
    required this.onComplete,
    this.currentIndex = 0,
    required this.primaryColor,
    this.theme,
    this.animateTransitions = true,
  });

  @override
  State<SequentialPreChatWidget> createState() => _SequentialPreChatWidgetState();
}

class _SequentialPreChatWidgetState extends State<SequentialPreChatWidget>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;
  bool _isSubmitting = false;
  final Map<String, String> _answers = {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SequentialPreChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _controller.clear();
      _error = null;
      if (widget.animateTransitions) {
        _animationController.reset();
        _animationController.forward();
      }
      _focusNode.requestFocus();
    }
  }

  PreChatFormField get currentQuestion => widget.questions[widget.currentIndex];

  void _handleSubmit() {
    if (_isSubmitting) return;

    final value = _controller.text.trim();

    // Validate
    String? error;
    if (value.isEmpty && currentQuestion.required) {
      error = 'This field is required';
    } else if (value.isNotEmpty) {
      switch (currentQuestion.answerType.toLowerCase()) {
        case 'email':
          if (!ValidationUtils.isValidEmail(value)) {
            error = currentQuestion.incorrectEmailResponse ??
                'Please enter a valid email address';
          }
          break;
        case 'phone':
        case 'mobile':
          if (!ValidationUtils.isValidPhoneNumber(value)) {
            error = currentQuestion.incorrectPhoneNumberResponse ??
                'Please enter a valid phone number';
          }
          break;
        case 'name':
          if (value.length < 2) {
            error = 'Please enter your full name';
          }
          break;
      }
    }

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() => _isSubmitting = true);

    // Store answer
    if (value.isNotEmpty) {
      _answers[currentQuestion.id] = value;
    }

    // Notify parent
    widget.onQuestionAnswered(currentQuestion.id, value);

    // Check if complete
    if (widget.currentIndex >= widget.questions.length - 1) {
      // Extract special fields
      String? name;
      String? email;
      String? phone;

      for (final question in widget.questions) {
        final answer = _answers[question.id];
        if (answer == null || answer.isEmpty) continue;

        switch (question.answerType.toLowerCase()) {
          case 'name':
            name = answer;
            break;
          case 'email':
            email = answer;
            break;
          case 'phone':
          case 'mobile':
            phone = answer;
            break;
        }
      }

      widget.onComplete(PreChatFormResult(
        answers: _answers,
        name: name,
        email: email,
        phone: phone,
      ));
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;

    if (widget.currentIndex >= widget.questions.length) {
      return const SizedBox.shrink();
    }

    IconData? prefixIcon;
    switch (currentQuestion.answerType.toLowerCase()) {
      case 'name':
        prefixIcon = Icons.person_outline;
        break;
      case 'email':
        prefixIcon = Icons.email_outlined;
        break;
      case 'phone':
      case 'mobile':
        prefixIcon = Icons.phone_outlined;
        break;
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress indicator
        ClipRRect(
          borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.sm),
          child: LinearProgressIndicator(
            value: (widget.currentIndex + 1) / widget.questions.length,
            backgroundColor: effectiveTheme.colors.border.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
            minHeight: 4,
          ),
        ),
        SizedBox(height: effectiveTheme.spacing.xs),

        // Progress text
        Text(
          'Question ${widget.currentIndex + 1} of ${widget.questions.length}',
          style: TextStyle(
            fontSize: effectiveTheme.typography.fontSizeXs,
            color: effectiveTheme.colors.textSecondary,
          ),
        ),
        SizedBox(height: effectiveTheme.spacing.md),

        // Question text
        Text(
          currentQuestion.questionText,
          style: TextStyle(
            fontSize: effectiveTheme.typography.fontSizeMd,
            fontWeight: effectiveTheme.typography.fontWeightMedium,
            color: effectiveTheme.colors.text,
          ),
        ),
        if (currentQuestion.required) ...[
          SizedBox(height: effectiveTheme.spacing.xs / 2),
          Text(
            'Required',
            style: TextStyle(
              fontSize: effectiveTheme.typography.fontSizeXs,
              color: effectiveTheme.colors.textSecondary,
            ),
          ),
        ],
        SizedBox(height: effectiveTheme.spacing.sm),

        // Input field
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: !_isSubmitting,
          keyboardType: _getKeyboardType(currentQuestion.answerType),
          inputFormatters: _getInputFormatters(currentQuestion.answerType),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleSubmit(),
          onChanged: (_) {
            if (_error != null) {
              setState(() => _error = null);
            }
          },
          decoration: InputDecoration(
            hintText: currentQuestion.placeholder ??
                _getDefaultPlaceholder(currentQuestion.answerType),
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    color: _error != null
                        ? effectiveTheme.colors.error
                        : effectiveTheme.colors.textSecondary,
                    size: 20,
                  )
                : null,
            filled: true,
            fillColor: effectiveTheme.colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.md),
              borderSide: BorderSide(color: effectiveTheme.colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.md),
              borderSide: BorderSide(
                color: _error != null
                    ? effectiveTheme.colors.error
                    : effectiveTheme.colors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.md),
              borderSide: BorderSide(
                color: _error != null
                    ? effectiveTheme.colors.error
                    : widget.primaryColor,
                width: 2,
              ),
            ),
          ),
          style: TextStyle(
            fontSize: effectiveTheme.typography.fontSizeMd,
            color: effectiveTheme.colors.text,
          ),
        ),

        // Error message
        if (_error != null) ...[
          SizedBox(height: effectiveTheme.spacing.xs),
          Text(
            _error!,
            style: TextStyle(
              fontSize: effectiveTheme.typography.fontSizeSm,
              color: effectiveTheme.colors.error,
            ),
          ),
        ],

        SizedBox(height: effectiveTheme.spacing.md),

        // Submit button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(effectiveTheme.borderRadius.md),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.currentIndex >= widget.questions.length - 1
                            ? 'Start Chat'
                            : 'Continue',
                        style: TextStyle(
                          fontWeight: effectiveTheme.typography.fontWeightSemiBold,
                        ),
                      ),
                      if (widget.currentIndex < widget.questions.length - 1) ...[
                        SizedBox(width: effectiveTheme.spacing.xs),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );

    if (widget.animateTransitions) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: content,
        ),
      );
    }

    return content;
  }

  TextInputType _getKeyboardType(String answerType) {
    switch (answerType.toLowerCase()) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
      case 'mobile':
        return TextInputType.phone;
      case 'number':
        return TextInputType.number;
      default:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter>? _getInputFormatters(String answerType) {
    switch (answerType.toLowerCase()) {
      case 'phone':
      case 'mobile':
        return [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]'))];
      case 'number':
        return [FilteringTextInputFormatter.digitsOnly];
      default:
        return null;
    }
  }

  String _getDefaultPlaceholder(String answerType) {
    switch (answerType.toLowerCase()) {
      case 'name':
        return 'Enter your name';
      case 'email':
        return 'Enter your email address';
      case 'phone':
      case 'mobile':
        return 'Enter your phone number';
      default:
        return 'Enter your answer';
    }
  }
}
