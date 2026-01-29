import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';
import '../../core/nodes/node_ui_state.dart';

/// Main widget that renders any NodeUIState for choice-based interactions
class NodeRenderer extends StatelessWidget {
  final NodeUIState uiState;
  final void Function(dynamic) onResponse;
  final ConferBotTheme? theme;

  const NodeRenderer({
    super.key,
    required this.uiState,
    required this.onResponse,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    return switch (uiState) {
      SingleChoiceUIState state => SingleChoiceWidget(
          state: state,
          onResponse: onResponse,
          theme: effectiveTheme,
        ),
      MultipleChoiceUIState state => MultipleChoiceWidget(
          state: state,
          onResponse: onResponse,
          theme: effectiveTheme,
        ),
      ImageChoiceUIState state => ImageChoiceWidget(
          state: state,
          onResponse: onResponse,
          theme: effectiveTheme,
        ),
      DropdownUIState state => DropdownWidget(
          state: state,
          onResponse: onResponse,
          theme: effectiveTheme,
        ),
      RatingUIState state => RatingWidget(
          state: state,
          onResponse: onResponse,
          theme: effectiveTheme,
        ),
      RangeUIState state => RangeSliderWidget(
          state: state,
          onResponse: onResponse,
          theme: effectiveTheme,
        ),
      CalendarUIState state => CalendarWidget(
          state: state,
          onResponse: onResponse,
          theme: effectiveTheme,
        ),
      QuizUIState state => QuizWidget(
          state: state,
          onResponse: onResponse,
          theme: effectiveTheme,
        ),
      HumanHandoverUIState state => HumanHandoverWidget(
          state: state,
          onResponse: onResponse,
          theme: effectiveTheme,
        ),
      PaymentUIState state => PaymentWidget(
          state: state,
          theme: effectiveTheme,
        ),
      RedirectUIState state => RedirectWidget(
          state: state,
          theme: effectiveTheme,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ==================== SINGLE CHOICE WIDGET ====================

/// Single choice selection widget with button-style options
class SingleChoiceWidget extends StatefulWidget {
  final SingleChoiceUIState state;
  final void Function(dynamic) onResponse;
  final ConferBotTheme theme;

  const SingleChoiceWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.theme,
  });

  @override
  State<SingleChoiceWidget> createState() => _SingleChoiceWidgetState();
}

class _SingleChoiceWidgetState extends State<SingleChoiceWidget> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          _BotMessageBubble(
            text: widget.state.questionText!,
            theme: theme,
          ),
          SizedBox(height: theme.spacing.md),
        ],
        ...widget.state.choices.map((choice) {
          final isSelected = _selectedId == choice.id;

          return Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedId == null
                    ? () {
                        setState(() {
                          _selectedId = choice.id;
                        });
                        widget.onResponse({
                          'id': choice.id,
                          'text': choice.text,
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSelected ? theme.colors.primary : theme.colors.surface,
                  foregroundColor:
                      isSelected ? Colors.white : theme.colors.text,
                  padding: EdgeInsets.symmetric(
                    vertical: theme.spacing.md,
                    horizontal: theme.spacing.lg,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(theme.borderRadius.lg),
                    side: isSelected
                        ? BorderSide.none
                        : BorderSide(color: theme.colors.primary),
                  ),
                  elevation: isSelected ? 2 : 0,
                ),
                child: Text(
                  choice.text,
                  style: TextStyle(
                    fontSize: theme.typography.fontSizeMd,
                    fontWeight: theme.typography.fontWeightMedium,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ==================== MULTIPLE CHOICE WIDGET ====================

/// Multiple choice selection widget with checkboxes
class MultipleChoiceWidget extends StatefulWidget {
  final MultipleChoiceUIState state;
  final void Function(dynamic) onResponse;
  final ConferBotTheme theme;

  const MultipleChoiceWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.theme,
  });

  @override
  State<MultipleChoiceWidget> createState() => _MultipleChoiceWidgetState();
}

class _MultipleChoiceWidgetState extends State<MultipleChoiceWidget> {
  final Set<String> _selectedIds = {};
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          _BotMessageBubble(
            text: widget.state.questionText!,
            theme: theme,
          ),
          SizedBox(height: theme.spacing.md),
        ],
        ...widget.state.options.map((option) {
          final isSelected = _selectedIds.contains(option.id);

          return Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
            child: InkWell(
              onTap: _submitted
                  ? null
                  : () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(option.id);
                        } else {
                          _selectedIds.add(option.id);
                        }
                      });
                    },
              borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(theme.spacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(theme.borderRadius.lg),
                  border: Border.all(
                    color: isSelected
                        ? theme.colors.primary
                        : theme.colors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: _submitted
                          ? null
                          : (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIds.add(option.id);
                                } else {
                                  _selectedIds.remove(option.id);
                                }
                              });
                            },
                      activeColor: theme.colors.primary,
                    ),
                    SizedBox(width: theme.spacing.md),
                    Expanded(
                      child: Text(
                        option.text,
                        style: TextStyle(
                          fontSize: theme.typography.fontSizeMd,
                          color: theme.colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        SizedBox(height: theme.spacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitted || _selectedIds.isEmpty
                ? null
                : () {
                    setState(() {
                      _submitted = true;
                    });
                    final selectedTexts = widget.state.options
                        .where((opt) => _selectedIds.contains(opt.id))
                        .map((opt) => opt.text)
                        .toList();
                    widget.onResponse(selectedTexts);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              ),
              disabledBackgroundColor: theme.colors.primary.withOpacity(0.5),
            ),
            child: Text(
              'Submit',
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
                fontWeight: theme.typography.fontWeightMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== IMAGE CHOICE WIDGET ====================

/// Image choice widget displayed as a grid
class ImageChoiceWidget extends StatefulWidget {
  final ImageChoiceUIState state;
  final void Function(dynamic) onResponse;
  final ConferBotTheme theme;

  const ImageChoiceWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.theme,
  });

  @override
  State<ImageChoiceWidget> createState() => _ImageChoiceWidgetState();
}

class _ImageChoiceWidgetState extends State<ImageChoiceWidget> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          _BotMessageBubble(
            text: widget.state.questionText!,
            theme: theme,
          ),
          SizedBox(height: theme.spacing.md),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: widget.state.images.length,
            itemBuilder: (context, index) {
              final image = widget.state.images[index];
              final isSelected = _selectedId == image.id;

              return GestureDetector(
                onTap: _selectedId == null
                    ? () {
                        setState(() {
                          _selectedId = image.id;
                        });
                        widget.onResponse({
                          'id': image.id,
                          'label': image.label,
                          'imageUrl': image.imageUrl,
                        });
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(theme.borderRadius.lg),
                    border: isSelected
                        ? Border.all(
                            color: theme.colors.primary,
                            width: 3,
                          )
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        image.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: theme.colors.surface,
                            child: Icon(
                              Icons.image_not_supported,
                              color: theme.colors.textSecondary,
                              size: 48,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: theme.colors.surface,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: theme.colors.primary,
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          color: Colors.black.withOpacity(0.6),
                          padding: EdgeInsets.all(theme.spacing.sm),
                          child: Text(
                            image.label,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: theme.typography.fontSizeSm,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: theme.spacing.sm,
                          right: theme.spacing.sm,
                          child: Container(
                            padding: EdgeInsets.all(theme.spacing.xs),
                            decoration: BoxDecoration(
                              color: theme.colors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==================== DROPDOWN WIDGET ====================

/// Dropdown selection widget
class DropdownWidget extends StatefulWidget {
  final DropdownUIState state;
  final void Function(dynamic) onResponse;
  final ConferBotTheme theme;

  const DropdownWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.theme,
  });

  @override
  State<DropdownWidget> createState() => _DropdownWidgetState();
}

class _DropdownWidgetState extends State<DropdownWidget> {
  SelectOption? _selectedOption;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          _BotMessageBubble(
            text: widget.state.questionText!,
            theme: theme,
          ),
          SizedBox(height: theme.spacing.md),
        ],
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.borderRadius.lg),
            border: Border.all(color: theme.colors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<SelectOption>(
              value: _selectedOption,
              hint: Text(
                'Select an option',
                style: TextStyle(
                  color: theme.colors.textSecondary,
                  fontSize: theme.typography.fontSizeMd,
                ),
              ),
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: theme.colors.textSecondary,
              ),
              items: widget.state.options.map((option) {
                return DropdownMenuItem<SelectOption>(
                  value: option,
                  child: Text(
                    option.text,
                    style: TextStyle(
                      fontSize: theme.typography.fontSizeMd,
                      color: theme.colors.text,
                    ),
                  ),
                );
              }).toList(),
              onChanged: _selectedOption != null
                  ? null
                  : (option) {
                      if (option != null) {
                        setState(() {
                          _selectedOption = option;
                        });
                        widget.onResponse({
                          'id': option.id,
                          'text': option.text,
                        });
                      }
                    },
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== RATING WIDGET ====================

/// Rating widget supporting star, smiley, and number variants
class RatingWidget extends StatefulWidget {
  final RatingUIState state;
  final void Function(dynamic) onResponse;
  final ConferBotTheme theme;

  const RatingWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.theme,
  });

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget> {
  int? _selectedRating;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          _BotMessageBubble(
            text: widget.state.questionText!,
            theme: theme,
          ),
          SizedBox(height: theme.spacing.md),
        ],
        switch (widget.state.ratingType) {
          RatingType.star => _StarRating(
              maxRating: widget.state.maxValue,
              currentRating: _selectedRating ?? 0,
              onRatingChange: _handleRatingChange,
              tint: theme.colors.primary,
              enabled: _selectedRating == null,
            ),
          RatingType.smiley => _SmileyRating(
              selectedRating: _selectedRating,
              onRatingChange: _handleRatingChange,
              theme: theme,
            ),
          RatingType.number || RatingType.opinionScale => _NumberRating(
              minValue: widget.state.minValue,
              maxValue: widget.state.maxValue,
              selectedValue: _selectedRating,
              onValueSelected: _handleRatingChange,
              tint: theme.colors.primary,
              theme: theme,
            ),
        },
      ],
    );
  }

  void _handleRatingChange(int rating) {
    setState(() {
      _selectedRating = rating;
    });
    widget.onResponse(rating);
  }
}

/// Star rating component
class _StarRating extends StatelessWidget {
  final int maxRating;
  final int currentRating;
  final void Function(int) onRatingChange;
  final Color tint;
  final bool enabled;

  const _StarRating({
    required this.maxRating,
    required this.currentRating,
    required this.onRatingChange,
    required this.tint,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxRating, (index) {
        final rating = index + 1;
        final isFilled = rating <= currentRating;

        return IconButton(
          onPressed: enabled ? () => onRatingChange(rating) : null,
          icon: Icon(
            isFilled ? Icons.star : Icons.star_border,
            color: isFilled ? tint : Colors.grey,
            size: 40,
          ),
        );
      }),
    );
  }
}

/// Smiley rating component
class _SmileyRating extends StatelessWidget {
  final int? selectedRating;
  final void Function(int) onRatingChange;
  final ConferBotTheme theme;

  const _SmileyRating({
    required this.selectedRating,
    required this.onRatingChange,
    required this.theme,
  });

  static const List<String> _smileys = [':(', ':|', ':/', ':)', ':D'];
  static const List<IconData> _smileyIcons = [
    Icons.sentiment_very_dissatisfied,
    Icons.sentiment_dissatisfied,
    Icons.sentiment_neutral,
    Icons.sentiment_satisfied,
    Icons.sentiment_very_satisfied,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) {
        final rating = index + 1;
        final isSelected = selectedRating == rating;

        return GestureDetector(
          onTap: selectedRating == null ? () => onRatingChange(rating) : null,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? theme.colors.primary.withOpacity(0.2)
                  : Colors.transparent,
              border: isSelected
                  ? Border.all(color: theme.colors.primary, width: 2)
                  : null,
            ),
            child: Center(
              child: Icon(
                _smileyIcons[index],
                size: 36,
                color: isSelected
                    ? theme.colors.primary
                    : _getSmileyColor(rating),
              ),
            ),
          ),
        );
      }),
    );
  }

  Color _getSmileyColor(int rating) {
    return switch (rating) {
      1 => const Color(0xFFE53935),
      2 => const Color(0xFFFF9800),
      3 => const Color(0xFFFFEB3B),
      4 => const Color(0xFF8BC34A),
      5 => const Color(0xFF4CAF50),
      _ => Colors.grey,
    };
  }
}

/// Number rating component
class _NumberRating extends StatelessWidget {
  final int minValue;
  final int maxValue;
  final int? selectedValue;
  final void Function(int) onValueSelected;
  final Color tint;
  final ConferBotTheme theme;

  const _NumberRating({
    required this.minValue,
    required this.maxValue,
    required this.selectedValue,
    required this.onValueSelected,
    required this.tint,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final count = maxValue - minValue + 1;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final value = minValue + index;
          final isSelected = selectedValue == value;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
            child: GestureDetector(
              onTap:
                  selectedValue == null ? () => onValueSelected(value) : null,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? tint : theme.colors.surface,
                  border: Border.all(
                    color: isSelected ? tint : theme.colors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: theme.typography.fontSizeMd,
                      fontWeight: theme.typography.fontWeightMedium,
                      color: isSelected ? Colors.white : theme.colors.text,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ==================== RANGE SLIDER WIDGET ====================

/// Range slider widget for selecting a value within a range
class RangeSliderWidget extends StatefulWidget {
  final RangeUIState state;
  final void Function(dynamic) onResponse;
  final ConferBotTheme theme;

  const RangeSliderWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.theme,
  });

  @override
  State<RangeSliderWidget> createState() => _RangeSliderWidgetState();
}

class _RangeSliderWidgetState extends State<RangeSliderWidget> {
  late double _value;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _value = (widget.state.defaultValue ??
            ((widget.state.minValue + widget.state.maxValue) ~/ 2))
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          _BotMessageBubble(
            text: widget.state.questionText!,
            theme: theme,
          ),
          SizedBox(height: theme.spacing.md),
        ],
        Row(
          children: [
            Text(
              widget.state.minValue.toString(),
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                color: theme.colors.textSecondary,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: theme.colors.primary,
                  inactiveTrackColor: theme.colors.border,
                  thumbColor: theme.colors.primary,
                  overlayColor: theme.colors.primary.withOpacity(0.2),
                ),
                child: Slider(
                  value: _value,
                  min: widget.state.minValue.toDouble(),
                  max: widget.state.maxValue.toDouble(),
                  divisions:
                      widget.state.maxValue - widget.state.minValue,
                  onChanged: _submitted
                      ? null
                      : (value) {
                          setState(() {
                            _value = value;
                          });
                        },
                ),
              ),
            ),
            Text(
              widget.state.maxValue.toString(),
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                color: theme.colors.textSecondary,
              ),
            ),
          ],
        ),
        Center(
          child: Text(
            'Selected: ${_value.toInt()}',
            style: TextStyle(
              fontSize: theme.typography.fontSizeLg,
              fontWeight: theme.typography.fontWeightMedium,
              color: theme.colors.text,
            ),
          ),
        ),
        SizedBox(height: theme.spacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitted
                ? null
                : () {
                    setState(() {
                      _submitted = true;
                    });
                    widget.onResponse(_value.toInt());
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              ),
              disabledBackgroundColor: theme.colors.primary.withOpacity(0.5),
            ),
            child: Text(
              'Submit',
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
                fontWeight: theme.typography.fontWeightMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== CALENDAR WIDGET ====================

/// Calendar widget for date and time selection
class CalendarWidget extends StatefulWidget {
  final CalendarUIState state;
  final void Function(dynamic) onResponse;
  final ConferBotTheme theme;

  const CalendarWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.theme,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          _BotMessageBubble(
            text: widget.state.questionText!,
            theme: theme,
          ),
          SizedBox(height: theme.spacing.md),
        ],
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(theme.spacing.md),
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: BorderRadius.circular(theme.borderRadius.lg),
            border: Border.all(color: theme.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Date',
                style: TextStyle(
                  fontSize: theme.typography.fontSizeMd,
                  fontWeight: theme.typography.fontWeightMedium,
                  color: theme.colors.text,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              InkWell(
                onTap: _submitted ? null : _selectDate,
                borderRadius: BorderRadius.circular(theme.borderRadius.md),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(theme.spacing.md),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(theme.borderRadius.md),
                    border: Border.all(color: theme.colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: theme.colors.primary,
                        size: 20,
                      ),
                      SizedBox(width: theme.spacing.sm),
                      Text(
                        _selectedDate != null
                            ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                            : 'YYYY-MM-DD',
                        style: TextStyle(
                          fontSize: theme.typography.fontSizeMd,
                          color: _selectedDate != null
                              ? theme.colors.text
                              : theme.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.state.showTimeSelection) ...[
                SizedBox(height: theme.spacing.md),
                Text(
                  'Select Time',
                  style: TextStyle(
                    fontSize: theme.typography.fontSizeMd,
                    fontWeight: theme.typography.fontWeightMedium,
                    color: theme.colors.text,
                  ),
                ),
                SizedBox(height: theme.spacing.sm),
                InkWell(
                  onTap: _submitted ? null : _selectTime,
                  borderRadius: BorderRadius.circular(theme.borderRadius.md),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(theme.spacing.md),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(theme.borderRadius.md),
                      border: Border.all(color: theme.colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: theme.colors.primary,
                          size: 20,
                        ),
                        SizedBox(width: theme.spacing.sm),
                        Text(
                          _selectedTime != null
                              ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                              : 'HH:MM',
                          style: TextStyle(
                            fontSize: theme.typography.fontSizeMd,
                            color: _selectedTime != null
                                ? theme.colors.text
                                : theme.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: theme.spacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitted || _selectedDate == null
                ? null
                : () {
                    setState(() {
                      _submitted = true;
                    });
                    widget.onResponse({
                      'date':
                          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                      'time': _selectedTime != null
                          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                          : '',
                    });
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              ),
              disabledBackgroundColor: theme.colors.primary.withOpacity(0.5),
            ),
            child: Text(
              'Confirm',
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
                fontWeight: theme.typography.fontWeightMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.theme.colors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.theme.colors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }
}

// ==================== QUIZ WIDGET ====================

/// Quiz widget with correct/incorrect answer feedback
class QuizWidget extends StatefulWidget {
  final QuizUIState state;
  final void Function(dynamic) onResponse;
  final ConferBotTheme theme;

  const QuizWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.theme,
  });

  @override
  State<QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<QuizWidget> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BotMessageBubble(
          text: widget.state.questionText,
          theme: theme,
        ),
        SizedBox(height: theme.spacing.md),
        ...widget.state.options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = _selectedIndex == index;
          final isCorrect = index == widget.state.correctAnswerIndex;

          Color backgroundColor;
          Color textColor;
          BorderSide? border;

          if (_selectedIndex == null) {
            backgroundColor = theme.colors.surface;
            textColor = theme.colors.text;
            border = BorderSide(color: theme.colors.primary);
          } else if (isSelected) {
            backgroundColor =
                isCorrect ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
            textColor = Colors.white;
            border = null;
          } else if (isCorrect && _selectedIndex != null) {
            backgroundColor = const Color(0xFF4CAF50);
            textColor = Colors.white;
            border = null;
          } else {
            backgroundColor = theme.colors.surface;
            textColor = theme.colors.textDisabled;
            border = BorderSide(color: theme.colors.border);
          }

          return Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedIndex == null
                    ? () {
                        setState(() {
                          _selectedIndex = index;
                        });
                        widget.onResponse({
                          'index': index,
                          'text': option,
                          'isCorrect': isCorrect,
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: backgroundColor,
                  foregroundColor: textColor,
                  padding: EdgeInsets.symmetric(
                    vertical: theme.spacing.md,
                    horizontal: theme.spacing.lg,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(theme.borderRadius.lg),
                    side: border ?? BorderSide.none,
                  ),
                  elevation: isSelected ? 2 : 0,
                  disabledBackgroundColor: backgroundColor,
                  disabledForegroundColor: textColor,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: theme.typography.fontSizeMd,
                          fontWeight: theme.typography.fontWeightMedium,
                        ),
                      ),
                    ),
                    if (_selectedIndex != null && (isSelected || isCorrect))
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: Colors.white,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ==================== HUMAN HANDOVER WIDGET ====================

/// Human handover widget with all states
class HumanHandoverWidget extends StatelessWidget {
  final HumanHandoverUIState state;
  final void Function(dynamic) onResponse;
  final ConferBotTheme theme;

  const HumanHandoverWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return switch (state.state) {
      HandoverState.preChatQuestions => _PreChatQuestionsState(
          state: state,
          onResponse: onResponse,
          theme: theme,
        ),
      HandoverState.waitingForAgent => _WaitingForAgentState(
          state: state,
          theme: theme,
        ),
      HandoverState.agentConnected => _AgentConnectedState(
          state: state,
          theme: theme,
        ),
      HandoverState.noAgentsAvailable => _NoAgentsAvailableState(
          state: state,
          theme: theme,
        ),
      HandoverState.postChatSurvey => _PostChatSurveyState(
          state: state,
          onResponse: onResponse,
          theme: theme,
        ),
    };
  }
}

/// Pre-chat questions state
class _PreChatQuestionsState extends StatefulWidget {
  final HumanHandoverUIState state;
  final void Function(dynamic) onResponse;
  final ConferBotTheme theme;

  const _PreChatQuestionsState({
    required this.state,
    required this.onResponse,
    required this.theme,
  });

  @override
  State<_PreChatQuestionsState> createState() => _PreChatQuestionsStateState();
}

class _PreChatQuestionsStateState extends State<_PreChatQuestionsState> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final currentQuestion = widget.state.preChatQuestions?.isNotEmpty == true
        ? widget.state.preChatQuestions![widget.state.currentQuestionIndex]
        : null;

    if (currentQuestion == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BotMessageBubble(
          text: currentQuestion.questionText,
          theme: theme,
        ),
        SizedBox(height: theme.spacing.md),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Type your answer...',
            hintStyle: TextStyle(color: theme.colors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              borderSide: BorderSide(color: theme.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              borderSide: BorderSide(color: theme.colors.primary),
            ),
            contentPadding: EdgeInsets.all(theme.spacing.md),
          ),
          keyboardType: _getKeyboardType(currentQuestion.answerType),
        ),
        SizedBox(height: theme.spacing.sm),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                widget.onResponse({
                  'key': currentQuestion.answerKey,
                  'value': _controller.text,
                });
                _controller.clear();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              ),
            ),
            child: Text(
              'Submit',
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
                fontWeight: theme.typography.fontWeightMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextInputType _getKeyboardType(String answerType) {
    return switch (answerType.toLowerCase()) {
      'email' => TextInputType.emailAddress,
      'phone' || 'mobile' => TextInputType.phone,
      'number' => TextInputType.number,
      _ => TextInputType.text,
    };
  }
}

/// Waiting for agent state
class _WaitingForAgentState extends StatelessWidget {
  final HumanHandoverUIState state;
  final ConferBotTheme theme;

  const _WaitingForAgentState({
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.lg),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
        border: Border.all(color: theme.colors.border),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(
            color: theme.colors.primary,
          ),
          SizedBox(height: theme.spacing.md),
          Text(
            state.handoverMessage ?? 'Connecting you to an agent...',
            style: TextStyle(
              fontSize: theme.typography.fontSizeMd,
              color: theme.colors.text,
            ),
            textAlign: TextAlign.center,
          ),
          if (state.maxWaitTime != null) ...[
            SizedBox(height: theme.spacing.sm),
            Text(
              'Estimated wait: ${state.maxWaitTime} minutes',
              style: TextStyle(
                fontSize: theme.typography.fontSizeSm,
                color: theme.colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Agent connected state
class _AgentConnectedState extends StatelessWidget {
  final HumanHandoverUIState state;
  final ConferBotTheme theme;

  const _AgentConnectedState({
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFF4CAF50),
            size: 24,
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Text(
              '${state.agentName ?? "Agent"} has joined the chat',
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
                color: theme.colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// No agents available state
class _NoAgentsAvailableState extends StatelessWidget {
  final HumanHandoverUIState state;
  final ConferBotTheme theme;

  const _NoAgentsAvailableState({
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.warning,
            color: Color(0xFFFF9800),
            size: 32,
          ),
          SizedBox(height: theme.spacing.sm),
          Text(
            state.handoverMessage ?? 'No agents available',
            style: TextStyle(
              fontSize: theme.typography.fontSizeMd,
              color: theme.colors.text,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Post-chat survey state
class _PostChatSurveyState extends StatefulWidget {
  final HumanHandoverUIState state;
  final void Function(dynamic) onResponse;
  final ConferBotTheme theme;

  const _PostChatSurveyState({
    required this.state,
    required this.onResponse,
    required this.theme,
  });

  @override
  State<_PostChatSurveyState> createState() => _PostChatSurveyStateState();
}

class _PostChatSurveyStateState extends State<_PostChatSurveyState> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final currentQuestion = widget.state.preChatQuestions?.isNotEmpty == true
        ? widget.state.preChatQuestions![widget.state.currentQuestionIndex]
        : null;

    if (currentQuestion == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BotMessageBubble(
          text: currentQuestion.questionText,
          theme: theme,
        ),
        SizedBox(height: theme.spacing.md),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Type your feedback...',
            hintStyle: TextStyle(color: theme.colors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              borderSide: BorderSide(color: theme.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              borderSide: BorderSide(color: theme.colors.primary),
            ),
            contentPadding: EdgeInsets.all(theme.spacing.md),
          ),
          maxLines: 3,
        ),
        SizedBox(height: theme.spacing.sm),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              widget.onResponse({
                'key': currentQuestion.answerKey,
                'value': _controller.text,
              });
              _controller.clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.borderRadius.lg),
              ),
            ),
            child: Text(
              'Submit',
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
                fontWeight: theme.typography.fontWeightMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== PAYMENT WIDGET ====================

/// Payment widget for Stripe integration
class PaymentWidget extends StatelessWidget {
  final PaymentUIState state;
  final ConferBotTheme theme;

  const PaymentWidget({
    super.key,
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
        border: Border.all(color: theme.colors.border),
      ),
      child: Column(
        children: [
          Text(
            'Payment',
            style: TextStyle(
              fontSize: theme.typography.fontSizeLg,
              fontWeight: theme.typography.fontWeightMedium,
              color: theme.colors.text,
            ),
          ),
          if (state.amount != null && state.currency != null) ...[
            SizedBox(height: theme.spacing.sm),
            Text(
              '${state.currency} ${state.amount!.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: theme.typography.fontSizeXxl,
                fontWeight: theme.typography.fontWeightBold,
                color: theme.colors.text,
              ),
            ),
          ],
          if (state.description != null && state.description!.isNotEmpty) ...[
            SizedBox(height: theme.spacing.xs),
            Text(
              state.description!,
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
                color: theme.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: theme.spacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.paymentUrl.isNotEmpty
                  ? () => _openPaymentUrl(context)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF635BFF), // Stripe purple
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.borderRadius.md),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.credit_card, size: 20),
                  SizedBox(width: theme.spacing.sm),
                  Text(
                    'Pay Now',
                    style: TextStyle(
                      fontSize: theme.typography.fontSizeMd,
                      fontWeight: theme.typography.fontWeightMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaymentUrl(BuildContext context) async {
    final uri = Uri.tryParse(state.paymentUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ==================== REDIRECT WIDGET ====================

/// Redirect widget for external URL navigation
class RedirectWidget extends StatefulWidget {
  final RedirectUIState state;
  final ConferBotTheme theme;

  const RedirectWidget({
    super.key,
    required this.state,
    required this.theme,
  });

  @override
  State<RedirectWidget> createState() => _RedirectWidgetState();
}

class _RedirectWidgetState extends State<RedirectWidget> {
  @override
  void initState() {
    super.initState();
    _launchUrl();
  }

  Future<void> _launchUrl() async {
    final uri = Uri.tryParse(widget.state.url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: widget.state.openInNewTab
            ? LaunchMode.externalApplication
            : LaunchMode.inAppWebView,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
        border: Border.all(color: theme.colors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.open_in_new,
            color: theme.colors.primary,
            size: 24,
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Redirecting...',
                  style: TextStyle(
                    fontSize: theme.typography.fontSizeMd,
                    fontWeight: theme.typography.fontWeightMedium,
                    color: theme.colors.text,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  widget.state.url,
                  style: TextStyle(
                    fontSize: theme.typography.fontSizeSm,
                    color: theme.colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== HELPER COMPONENTS ====================

/// Bot message bubble helper widget
class _BotMessageBubble extends StatelessWidget {
  final String text;
  final ConferBotTheme theme;

  const _BotMessageBubble({
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: theme.colors.botBubble,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(theme.borderRadius.lg),
          topRight: Radius.circular(theme.borderRadius.lg),
          bottomRight: Radius.circular(theme.borderRadius.lg),
          bottomLeft: Radius.circular(theme.borderRadius.sm),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: theme.typography.fontSizeMd,
          color: theme.colors.botBubbleText,
          height: theme.typography.lineHeightNormal,
        ),
      ),
    );
  }
}
