import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/nodes/node_ui_state.dart' as ui_state;
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';
import '../../widgets/voice_message/voice_input_widget.dart';
import '../../widgets/voice_message/voice_player.dart';
import '../../widgets/media/image_viewer.dart';
import '../../widgets/media/video_player_widget.dart';
import '../../widgets/media/audio_player_widget.dart';

/// Main widget that routes to the correct node component based on UI state
class NodeRenderer extends StatelessWidget {
  final ui_state.NodeUIState uiState;
  final ValueChanged<dynamic> onResponse;
  final Color? primaryColor;
  final ConferBotTheme? theme;

  const NodeRenderer({
    super.key,
    required this.uiState,
    required this.onResponse,
    this.primaryColor,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;
    final effectivePrimaryColor = primaryColor ?? effectiveTheme.colors.primary;

    return switch (uiState) {
      ui_state.MessageUIState state => MessageNodeWidget(state: state, theme: effectiveTheme),
      ui_state.ImageUIState state => ImageNodeWidget(
          state: state,
          theme: effectiveTheme,
          primaryColor: effectivePrimaryColor,
        ),
      ui_state.VideoUIState state => VideoNodeWidget(
          state: state,
          theme: effectiveTheme,
          primaryColor: effectivePrimaryColor,
        ),
      ui_state.AudioUIState state => AudioNodeWidget(
          state: state,
          theme: effectiveTheme,
          primaryColor: effectivePrimaryColor,
        ),
      ui_state.FileUIState state => FileNodeWidget(state: state, theme: effectiveTheme),
      ui_state.TextInputUIState state => TextInputNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.FileUploadUIState state => FileUploadNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.VoiceInputUIState state => VoiceInputNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.VoiceMessageUIState state => VoiceMessageNodeWidget(
          state: state,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.SingleChoiceUIState state => SingleChoiceNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.MultipleChoiceUIState state => MultipleChoiceNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.RatingUIState state => RatingNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.DropdownUIState state => DropdownNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.RangeUIState state => RangeNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.CalendarUIState state => CalendarNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.ImageChoiceUIState state => ImageChoiceNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.QuizUIState state => QuizNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.MultipleQuestionsUIState state => MultipleQuestionsNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.HumanHandoverUIState state => HumanHandoverNodeWidget(
          state: state,
          onResponse: onResponse,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.HtmlUIState state => HtmlNodeWidget(state: state, theme: effectiveTheme),
      ui_state.PaymentUIState state => PaymentNodeWidget(
          state: state,
          primaryColor: effectivePrimaryColor,
          theme: effectiveTheme,
        ),
      ui_state.RedirectUIState state => RedirectNodeWidget(state: state, theme: effectiveTheme),
    };
  }
}

// ==================== MESSAGE NODES ====================

/// Widget displaying a simple text message from the bot
class MessageNodeWidget extends StatelessWidget {
  final ui_state.MessageUIState state;
  final ConferBotTheme theme;

  const MessageNodeWidget({
    super.key,
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return BotMessageBubble(text: state.text, theme: theme);
  }
}

/// Widget displaying an image with optional caption and full-screen viewer
class ImageNodeWidget extends StatelessWidget {
  final ui_state.ImageUIState state;
  final ConferBotTheme theme;
  final Color? primaryColor;

  const ImageNodeWidget({
    super.key,
    required this.state,
    required this.theme,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return ImageThumbnail(
      imageUrl: state.url,
      caption: state.caption,
      theme: theme,
      maxHeight: 300,
      heroTag: 'image_${state.nodeId}',
      openFullScreenOnTap: true,
    );
  }
}

/// Widget displaying a video player with full controls
class VideoNodeWidget extends StatelessWidget {
  final ui_state.VideoUIState state;
  final ConferBotTheme theme;
  final Color? primaryColor;

  const VideoNodeWidget({
    super.key,
    required this.state,
    required this.theme,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return VideoPlayerWidget(
      videoUrl: state.url,
      caption: state.caption,
      theme: theme,
      playerId: 'video_${state.nodeId}',
      config: VideoPlayerConfig(
        autoPlay: state.autoplay,
        showControls: true,
        allowFullScreen: true,
        showProgressBar: true,
      ),
    );
  }
}

/// Widget displaying an audio player with waveform visualization
class AudioNodeWidget extends StatelessWidget {
  final ui_state.AudioUIState state;
  final ConferBotTheme theme;
  final Color? primaryColor;

  const AudioNodeWidget({
    super.key,
    required this.state,
    required this.theme,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return AudioPlayerWidget(
      audioUrl: state.url,
      title: state.title,
      theme: theme,
      primaryColor: primaryColor ?? theme.colors.primary,
      playerId: 'audio_${state.nodeId}',
      config: const AudioPlayerConfig(
        showSpeedControl: true,
        showWaveform: true,
      ),
    );
  }
}

/// Widget displaying a file download option
class FileNodeWidget extends StatelessWidget {
  final ui_state.FileUIState state;
  final ConferBotTheme theme;

  const FileNodeWidget({
    super.key,
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          children: [
            Icon(
              Icons.description,
              size: 32,
              color: theme.colors.primary,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.fileName,
                    style: TextStyle(
                      fontSize: theme.typography.fontSizeMd,
                      color: theme.colors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (state.fileSize != null) ...[
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      state.fileSize!,
                      style: TextStyle(
                        fontSize: theme.typography.fontSizeXs,
                        color: theme.colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.download,
              color: theme.colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== VOICE MESSAGE NODE ====================

/// Widget for displaying voice messages in chat
class VoiceMessageNodeWidget extends StatelessWidget {
  final ui_state.VoiceMessageUIState state;
  final Color primaryColor;
  final ConferBotTheme theme;

  const VoiceMessageNodeWidget({
    super.key,
    required this.state,
    required this.primaryColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return VoicePlayerWidget(
      audioSource: state.audioUrl,
      isLocalFile: false,
      duration: state.duration,
      waveformData: state.waveformData,
      isUserMessage: state.isUserMessage,
      theme: theme,
      primaryColor: primaryColor,
    );
  }
}

// ==================== INPUT NODES ====================

/// Widget for text input with keyboard type support
class TextInputNodeWidget extends StatefulWidget {
  final ui_state.TextInputUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const TextInputNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<TextInputNodeWidget> createState() => _TextInputNodeWidgetState();
}

class _TextInputNodeWidgetState extends State<TextInputNodeWidget> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasError = false;
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  TextInputType _getKeyboardType() {
    return switch (widget.state.inputType) {
      ui_state.TextInputType.email => TextInputType.emailAddress,
      ui_state.TextInputType.phone => TextInputType.phone,
      ui_state.TextInputType.number => TextInputType.number,
      ui_state.TextInputType.url => TextInputType.url,
      _ => TextInputType.text,
    };
  }

  List<TextInputFormatter>? _getInputFormatters() {
    return switch (widget.state.inputType) {
      ui_state.TextInputType.phone => [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]'))],
      ui_state.TextInputType.number => [FilteringTextInputFormatter.digitsOnly],
      _ => null,
    };
  }

  bool _validate(String value) {
    if (value.isEmpty) return false;

    if (widget.state.validationRegex != null) {
      final regex = RegExp(widget.state.validationRegex!);
      return regex.hasMatch(value);
    }

    // Built-in validation based on type
    return switch (widget.state.inputType) {
      ui_state.TextInputType.email => RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value),
      ui_state.TextInputType.phone => value.length >= 10,
      ui_state.TextInputType.url => Uri.tryParse(value)?.hasAbsolutePath ?? false,
      _ => true,
    };
  }

  void _submit() {
    final value = _controller.text.trim();
    if (!_validate(value)) {
      setState(() => _hasError = true);
      return;
    }
    setState(() {
      _hasError = false;
      _submitted = true;
    });
    widget.onResponse(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.state.questionText.isNotEmpty) ...[
          BotMessageBubble(text: widget.state.questionText, theme: widget.theme),
          SizedBox(height: widget.theme.spacing.sm),
        ],
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: !_submitted,
          keyboardType: _getKeyboardType(),
          inputFormatters: _getInputFormatters(),
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_hasError) setState(() => _hasError = false);
          },
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: widget.state.placeholder ?? 'Type here...',
            filled: true,
            fillColor: widget.theme.colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
              borderSide: BorderSide(color: widget.theme.colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
              borderSide: BorderSide(color: widget.theme.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
              borderSide: BorderSide(color: widget.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
              borderSide: BorderSide(color: widget.theme.colors.error),
            ),
            errorText: _hasError ? (widget.state.errorMessage ?? 'Invalid input') : null,
          ),
        ),
        SizedBox(height: widget.theme.spacing.sm),
        ElevatedButton(
          onPressed: _submitted ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: widget.theme.spacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
            ),
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

/// Widget for file upload
class FileUploadNodeWidget extends StatefulWidget {
  final ui_state.FileUploadUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const FileUploadNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<FileUploadNodeWidget> createState() => _FileUploadNodeWidgetState();
}

class _FileUploadNodeWidgetState extends State<FileUploadNodeWidget> {
  String? _selectedFileName;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    try {
      // Build allowed extensions from the state's allowedTypes
      List<String>? allowedExtensions;
      FileType fileType = FileType.any;

      if (widget.state.allowedTypes != null &&
          widget.state.allowedTypes!.isNotEmpty) {
        fileType = FileType.custom;
        allowedExtensions = widget.state.allowedTypes!
            .map((t) => t.replaceAll('.', '').trim())
            .where((t) => t.isNotEmpty)
            .toList();
        if (allowedExtensions.isEmpty) {
          fileType = FileType.any;
          allowedExtensions = null;
        }
      }

      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      // Check file size
      final fileSizeBytes = file.size;
      final maxSizeBytes = widget.state.maxSizeMb * 1024 * 1024;
      if (fileSizeBytes > maxSizeBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File too large. Maximum size is ${widget.state.maxSizeMb}MB.',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedFileName = file.name;
        _isUploading = true;
      });

      // Send the file info back via onResponse
      widget.onResponse({
        'fileName': file.name,
        'filePath': file.path,
        'fileSize': file.size,
        'fileExtension': file.extension,
        'fileBytes': file.bytes,
      });

      if (mounted) {
        setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.state.questionText.isNotEmpty) ...[
          BotMessageBubble(text: widget.state.questionText, theme: widget.theme),
          SizedBox(height: widget.theme.spacing.sm),
        ],
        InkWell(
          onTap: _isUploading ? null : _pickFile,
          borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.primaryColor.withOpacity(0.5),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
              color: widget.theme.colors.surface,
            ),
            child: _isUploading
                ? Center(
                    child: CircularProgressIndicator(color: widget.primaryColor),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 40,
                        color: widget.primaryColor,
                      ),
                      SizedBox(height: widget.theme.spacing.sm),
                      Text(
                        _selectedFileName ?? 'Tap to upload file',
                        style: TextStyle(
                          fontSize: widget.theme.typography.fontSizeMd,
                          color: widget.theme.colors.text,
                        ),
                      ),
                      SizedBox(height: widget.theme.spacing.xs),
                      Text(
                        'Max ${widget.state.maxSizeMb}MB',
                        style: TextStyle(
                          fontSize: widget.theme.typography.fontSizeSm,
                          color: widget.theme.colors.textSecondary,
                        ),
                      ),
                      if (widget.state.allowedTypes != null &&
                          widget.state.allowedTypes!.isNotEmpty) ...[
                        SizedBox(height: widget.theme.spacing.xs),
                        Text(
                          'Allowed: ${widget.state.allowedTypes!.join(', ')}',
                          style: TextStyle(
                            fontSize: widget.theme.typography.fontSizeXs,
                            color: widget.theme.colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ==================== CHOICE NODES ====================

/// Widget for single choice selection (buttons)
class SingleChoiceNodeWidget extends StatefulWidget {
  final ui_state.SingleChoiceUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const SingleChoiceNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<SingleChoiceNodeWidget> createState() => _SingleChoiceNodeWidgetState();
}

class _SingleChoiceNodeWidgetState extends State<SingleChoiceNodeWidget> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          BotMessageBubble(text: widget.state.questionText!, theme: widget.theme),
          SizedBox(height: widget.theme.spacing.sm),
        ],
        // Wrap for auto-wrapping choice buttons — matches web widget flex-wrap
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: widget.state.choices.map((choice) {
            final isSelected = _selectedId == choice.id;
            final isDisabled = _selectedId != null;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isDisabled && !isSelected ? 0.5 : 1.0,
              child: OutlinedButton(
                onPressed: isDisabled
                    ? null
                    : () {
                        setState(() => _selectedId = choice.id);
                        widget.onResponse({'id': choice.id, 'text': choice.text});
                      },
                style: OutlinedButton.styleFrom(
                  backgroundColor: isSelected
                      ? widget.primaryColor
                      : widget.theme.colors.surface,
                  foregroundColor:
                      isSelected ? Colors.white : widget.theme.colors.text,
                  side: BorderSide(
                    color: isSelected
                        ? widget.primaryColor
                        : widget.primaryColor.withOpacity(0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 14,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isSelected ? 0 : 1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check, size: 16),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      choice.text,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Widget for multiple choice selection (checkboxes)
class MultipleChoiceNodeWidget extends StatefulWidget {
  final ui_state.MultipleChoiceUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const MultipleChoiceNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<MultipleChoiceNodeWidget> createState() =>
      _MultipleChoiceNodeWidgetState();
}

class _MultipleChoiceNodeWidgetState extends State<MultipleChoiceNodeWidget> {
  final Set<String> _selectedIds = {};
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          BotMessageBubble(text: widget.state.questionText!, theme: widget.theme),
          SizedBox(height: widget.theme.spacing.sm),
        ],
        ...widget.state.options.map((option) {
          final isSelected = _selectedIds.contains(option.id);
          return Padding(
            padding: EdgeInsets.only(bottom: widget.theme.spacing.xs),
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
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
              child: Container(
                padding: EdgeInsets.all(widget.theme.spacing.md),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? widget.primaryColor
                        : widget.theme.colors.border,
                  ),
                  borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
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
                      activeColor: widget.primaryColor,
                    ),
                    SizedBox(width: widget.theme.spacing.sm),
                    Expanded(
                      child: Text(
                        option.text,
                        style: TextStyle(
                          fontSize: widget.theme.typography.fontSizeMd,
                          color: widget.theme.colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        SizedBox(height: widget.theme.spacing.sm),
        ElevatedButton(
          onPressed: _submitted || _selectedIds.isEmpty
              ? null
              : () {
                  setState(() => _submitted = true);
                  final selectedTexts = widget.state.options
                      .where((o) => _selectedIds.contains(o.id))
                      .map((o) => o.text)
                      .toList();
                  widget.onResponse(selectedTexts);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: widget.theme.spacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
            ),
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

/// Widget for image choice grid
class ImageChoiceNodeWidget extends StatefulWidget {
  final ui_state.ImageChoiceUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const ImageChoiceNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<ImageChoiceNodeWidget> createState() => _ImageChoiceNodeWidgetState();
}

class _ImageChoiceNodeWidgetState extends State<ImageChoiceNodeWidget> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          BotMessageBubble(text: widget.state.questionText!, theme: widget.theme),
          SizedBox(height: widget.theme.spacing.sm),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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

            return InkWell(
              onTap: _selectedId != null
                  ? null
                  : () {
                      setState(() => _selectedId = image.id);
                      widget.onResponse({
                        'id': image.id,
                        'label': image.label,
                        'imageUrl': image.imageUrl,
                      });
                    },
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
                  border: isSelected
                      ? Border.all(color: widget.primaryColor, width: 3)
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
                          color: widget.theme.colors.surface,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: widget.theme.colors.textSecondary,
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(widget.theme.spacing.sm),
                        color: Colors.black.withOpacity(0.6),
                        child: Text(
                          image.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.theme.typography.fontSizeSm,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ==================== RATING NODES ====================

/// Widget for rating selection (stars/numbers/smileys)
class RatingNodeWidget extends StatefulWidget {
  final ui_state.RatingUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const RatingNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<RatingNodeWidget> createState() => _RatingNodeWidgetState();
}

class _RatingNodeWidgetState extends State<RatingNodeWidget> {
  int? _selectedRating;

  void _selectRating(int rating) {
    if (_selectedRating != null) return;
    setState(() => _selectedRating = rating);
    widget.onResponse(rating);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          BotMessageBubble(text: widget.state.questionText!, theme: widget.theme),
          SizedBox(height: widget.theme.spacing.sm),
        ],
        switch (widget.state.ratingType) {
          ui_state.RatingType.star => _buildStarRating(),
          ui_state.RatingType.smiley => _buildSmileyRating(),
          ui_state.RatingType.number || ui_state.RatingType.opinionScale => _buildNumberRating(),
        },
      ],
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.state.maxValue, (index) {
        final rating = index + 1;
        final isSelected = _selectedRating != null && rating <= _selectedRating!;
        return IconButton(
          onPressed: _selectedRating != null ? null : () => _selectRating(rating),
          icon: Icon(
            isSelected ? Icons.star : Icons.star_outline,
            size: 40,
            color: isSelected ? widget.primaryColor : Colors.grey,
          ),
        );
      }),
    );
  }

  Widget _buildSmileyRating() {
    final smileys = ['😢', '😕', '😐', '🙂', '😄'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(smileys.length, (index) {
        final rating = index + 1;
        final isSelected = _selectedRating == rating;
        return InkWell(
          onTap: _selectedRating != null ? null : () => _selectRating(rating),
          borderRadius: BorderRadius.circular(widget.theme.borderRadius.full),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? widget.primaryColor.withOpacity(0.2)
                  : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: Text(
              smileys[index],
              style: const TextStyle(fontSize: 32),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumberRating() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          widget.state.maxValue - widget.state.minValue + 1,
          (index) {
            final value = widget.state.minValue + index;
            final isSelected = _selectedRating == value;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.theme.spacing.xs),
              child: InkWell(
                onTap: _selectedRating != null ? null : () => _selectRating(value),
                borderRadius: BorderRadius.circular(widget.theme.borderRadius.full),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? widget.primaryColor
                        : widget.theme.colors.surface,
                    border: Border.all(
                      color: isSelected
                          ? widget.primaryColor
                          : widget.theme.colors.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: widget.theme.typography.fontSizeMd,
                      color: isSelected ? Colors.white : widget.theme.colors.text,
                      fontWeight: widget.theme.typography.fontWeightMedium,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==================== OTHER INPUT NODES ====================

/// Widget for dropdown selection
class DropdownNodeWidget extends StatefulWidget {
  final ui_state.DropdownUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const DropdownNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<DropdownNodeWidget> createState() => _DropdownNodeWidgetState();
}

class _DropdownNodeWidgetState extends State<DropdownNodeWidget> {
  ui_state.SelectOption? _selectedOption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          BotMessageBubble(text: widget.state.questionText!, theme: widget.theme),
          SizedBox(height: widget.theme.spacing.sm),
        ],
        DropdownButtonFormField<ui_state.SelectOption>(
          value: _selectedOption,
          decoration: InputDecoration(
            filled: true,
            fillColor: widget.theme.colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
              borderSide: BorderSide(color: widget.theme.colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
              borderSide: BorderSide(color: widget.theme.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
              borderSide: BorderSide(color: widget.primaryColor, width: 2),
            ),
            hintText: 'Select an option',
          ),
          items: widget.state.options.map((option) {
            return DropdownMenuItem<ui_state.SelectOption>(
              value: option,
              child: Text(option.text),
            );
          }).toList(),
          onChanged: _selectedOption != null
              ? null
              : (option) {
                  if (option != null) {
                    setState(() => _selectedOption = option);
                    widget.onResponse({'id': option.id, 'text': option.text});
                  }
                },
        ),
      ],
    );
  }
}

/// Widget for range slider
class RangeNodeWidget extends StatefulWidget {
  final ui_state.RangeUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const RangeNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<RangeNodeWidget> createState() => _RangeNodeWidgetState();
}

class _RangeNodeWidgetState extends State<RangeNodeWidget> {
  late double _value;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _value = (widget.state.defaultValue ??
            ((widget.state.minValue + widget.state.maxValue) / 2))
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          BotMessageBubble(text: widget.state.questionText!, theme: widget.theme),
          SizedBox(height: widget.theme.spacing.sm),
        ],
        Row(
          children: [
            Text(
              widget.state.minValue.toString(),
              style: TextStyle(
                fontSize: widget.theme.typography.fontSizeSm,
                color: widget.theme.colors.textSecondary,
              ),
            ),
            Expanded(
              child: Slider(
                value: _value,
                min: widget.state.minValue.toDouble(),
                max: widget.state.maxValue.toDouble(),
                divisions: widget.state.maxValue - widget.state.minValue,
                onChanged: _submitted
                    ? null
                    : (value) {
                        setState(() => _value = value);
                      },
                activeColor: widget.primaryColor,
              ),
            ),
            Text(
              widget.state.maxValue.toString(),
              style: TextStyle(
                fontSize: widget.theme.typography.fontSizeSm,
                color: widget.theme.colors.textSecondary,
              ),
            ),
          ],
        ),
        Text(
          'Selected: ${_value.toInt()}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: widget.theme.typography.fontSizeMd,
            fontWeight: widget.theme.typography.fontWeightMedium,
          ),
        ),
        SizedBox(height: widget.theme.spacing.sm),
        ElevatedButton(
          onPressed: _submitted
              ? null
              : () {
                  setState(() => _submitted = true);
                  widget.onResponse(_value.toInt());
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: widget.theme.spacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
            ),
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

/// Widget for calendar/date picker
class CalendarNodeWidget extends StatefulWidget {
  final ui_state.CalendarUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const CalendarNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<CalendarNodeWidget> createState() => _CalendarNodeWidgetState();
}

class _CalendarNodeWidgetState extends State<CalendarNodeWidget> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _submitted = false;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: widget.primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: widget.primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.state.questionText != null &&
            widget.state.questionText!.isNotEmpty) ...[
          BotMessageBubble(text: widget.state.questionText!, theme: widget.theme),
          SizedBox(height: widget.theme.spacing.sm),
        ],
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.theme.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select Date',
                  style: TextStyle(
                    fontSize: widget.theme.typography.fontSizeMd,
                    fontWeight: widget.theme.typography.fontWeightMedium,
                  ),
                ),
                SizedBox(height: widget.theme.spacing.sm),
                OutlinedButton.icon(
                  onPressed: _submitted ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _selectedDate != null
                        ? _formatDate(_selectedDate!)
                        : 'Choose date',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.all(widget.theme.spacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(widget.theme.borderRadius.md),
                    ),
                  ),
                ),
                if (widget.state.showTimeSelection) ...[
                  SizedBox(height: widget.theme.spacing.md),
                  Text(
                    'Select Time',
                    style: TextStyle(
                      fontSize: widget.theme.typography.fontSizeMd,
                      fontWeight: widget.theme.typography.fontWeightMedium,
                    ),
                  ),
                  SizedBox(height: widget.theme.spacing.sm),
                  OutlinedButton.icon(
                    onPressed: _submitted ? null : _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _selectedTime != null
                          ? _formatTime(_selectedTime!)
                          : 'Choose time',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.all(widget.theme.spacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(widget.theme.borderRadius.md),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: widget.theme.spacing.sm),
        ElevatedButton(
          onPressed: _submitted || _selectedDate == null
              ? null
              : () {
                  setState(() => _submitted = true);
                  widget.onResponse({
                    'date': _formatDate(_selectedDate!),
                    'time': _selectedTime != null
                        ? _formatTime(_selectedTime!)
                        : null,
                  });
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: widget.theme.spacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
            ),
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

/// Widget for quiz questions
class QuizNodeWidget extends StatefulWidget {
  final ui_state.QuizUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const QuizNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  State<QuizNodeWidget> createState() => _QuizNodeWidgetState();
}

class _QuizNodeWidgetState extends State<QuizNodeWidget> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.state.questionText.isNotEmpty) ...[
          BotMessageBubble(text: widget.state.questionText, theme: widget.theme),
          SizedBox(height: widget.theme.spacing.sm),
        ],
        ...widget.state.options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = _selectedIndex == index;
          final isCorrect = index == widget.state.correctAnswerIndex;

          Color backgroundColor;
          Color textColor;
          if (_selectedIndex != null && isSelected) {
            backgroundColor = isCorrect
                ? const Color(0xFF4CAF50)
                : const Color(0xFFF44336);
            textColor = Colors.white;
          } else {
            backgroundColor = widget.theme.colors.surface;
            textColor = widget.theme.colors.text;
          }

          return Padding(
            padding: EdgeInsets.only(bottom: widget.theme.spacing.xs),
            child: OutlinedButton(
              onPressed: _selectedIndex != null
                  ? null
                  : () {
                      setState(() => _selectedIndex = index);
                      widget.onResponse({'index': index, 'text': option});
                    },
              style: OutlinedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: textColor,
                side: BorderSide(
                  color:
                      _selectedIndex == null ? widget.primaryColor : Colors.transparent,
                ),
                padding: EdgeInsets.symmetric(
                  vertical: widget.theme.spacing.md,
                  horizontal: widget.theme.spacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(widget.theme.borderRadius.lg),
                ),
              ),
              child: Text(option),
            ),
          );
        }),
      ],
    );
  }
}

/// Widget for multiple sequential questions
class MultipleQuestionsNodeWidget extends StatelessWidget {
  final ui_state.MultipleQuestionsUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const MultipleQuestionsNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final currentQuestion =
        state.currentIndex < state.questions.length
            ? state.questions[state.currentIndex]
            : null;

    if (currentQuestion == null) {
      return const SizedBox.shrink();
    }

    return TextInputNodeWidget(
      state: ui_state.TextInputUIState(
        questionText: currentQuestion.questionText,
        inputType: _mapAnswerType(currentQuestion.answerType),
        nodeId: state.nodeId,
        answerKey: currentQuestion.answerKey,
      ),
      onResponse: onResponse,
      primaryColor: primaryColor,
      theme: theme,
    );
  }

  ui_state.TextInputType _mapAnswerType(String answerType) {
    return switch (answerType.toLowerCase()) {
      'email' => ui_state.TextInputType.email,
      'phone' || 'mobile' => ui_state.TextInputType.phone,
      'name' => ui_state.TextInputType.name,
      _ => ui_state.TextInputType.text,
    };
  }
}

/// Widget for human handover
class HumanHandoverNodeWidget extends StatelessWidget {
  final ui_state.HumanHandoverUIState state;
  final ValueChanged<dynamic> onResponse;
  final Color primaryColor;
  final ConferBotTheme theme;

  const HumanHandoverNodeWidget({
    super.key,
    required this.state,
    required this.onResponse,
    required this.primaryColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return switch (state.state) {
      ui_state.HandoverState.preChatQuestions => _buildPreChatQuestions(),
      ui_state.HandoverState.waitingForAgent => _buildWaitingForAgent(),
      ui_state.HandoverState.agentConnected => _buildAgentConnected(),
      ui_state.HandoverState.noAgentsAvailable => _buildNoAgentsAvailable(),
      ui_state.HandoverState.postChatSurvey => _buildPostChatSurvey(),
    };
  }

  Widget _buildPreChatQuestions() {
    final currentQuestion = state.preChatQuestions != null &&
            state.currentQuestionIndex < state.preChatQuestions!.length
        ? state.preChatQuestions![state.currentQuestionIndex]
        : null;

    if (currentQuestion == null) {
      return const SizedBox.shrink();
    }

    return TextInputNodeWidget(
      state: ui_state.TextInputUIState(
        questionText: currentQuestion.questionText,
        inputType: _mapAnswerType(currentQuestion.answerType),
        nodeId: state.nodeId,
        answerKey: currentQuestion.answerKey,
      ),
      onResponse: onResponse,
      primaryColor: primaryColor,
      theme: theme,
    );
  }

  Widget _buildWaitingForAgent() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: theme.spacing.md),
            Text(
              state.handoverMessage ?? 'Connecting you to an agent...',
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
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
      ),
    );
  }

  Widget _buildAgentConnected() {
    return Card(
      color: const Color(0xFFE8F5E9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Color(0xFF4CAF50),
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                '${state.agentName ?? "Agent"} has joined the chat',
                style: TextStyle(
                  fontSize: theme.typography.fontSizeMd,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAgentsAvailable() {
    return Card(
      color: const Color(0xFFFFF3E0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning,
              color: Color(0xFFFF9800),
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              state.handoverMessage ?? 'No agents available',
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostChatSurvey() {
    final currentQuestion = state.preChatQuestions != null &&
            state.currentQuestionIndex < state.preChatQuestions!.length
        ? state.preChatQuestions![state.currentQuestionIndex]
        : null;

    if (currentQuestion == null) {
      return const SizedBox.shrink();
    }

    return TextInputNodeWidget(
      state: ui_state.TextInputUIState(
        questionText: currentQuestion.questionText,
        inputType: ui_state.TextInputType.text,
        nodeId: state.nodeId,
        answerKey: currentQuestion.answerKey,
      ),
      onResponse: onResponse,
      primaryColor: primaryColor,
      theme: theme,
    );
  }

  ui_state.TextInputType _mapAnswerType(String answerType) {
    return switch (answerType.toLowerCase()) {
      'email' => ui_state.TextInputType.email,
      'phone' || 'mobile' => ui_state.TextInputType.phone,
      'name' => ui_state.TextInputType.name,
      _ => ui_state.TextInputType.text,
    };
  }
}

// ==================== OTHER NODES ====================

/// Widget for HTML content
class HtmlNodeWidget extends StatelessWidget {
  final ui_state.HtmlUIState state;
  final ConferBotTheme theme;

  const HtmlNodeWidget({
    super.key,
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final htmlContent = state.htmlContent;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Html(
          data: htmlContent,
          style: {
            'body': Style(
              fontSize: FontSize(theme.typography.fontSizeMd),
              color: theme.colors.text,
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
            ),
            'a': Style(
              color: theme.colors.primary,
            ),
          },
        ),
      ),
    );
  }
}

/// Widget for payment
class PaymentNodeWidget extends StatelessWidget {
  final ui_state.PaymentUIState state;
  final Color primaryColor;
  final ConferBotTheme theme;

  const PaymentNodeWidget({
    super.key,
    required this.state,
    required this.primaryColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Payment',
              style: TextStyle(
                fontSize: theme.typography.fontSizeLg,
                fontWeight: theme.typography.fontWeightMedium,
              ),
            ),
            if (state.amount != null && state.currency != null) ...[
              SizedBox(height: theme.spacing.sm),
              Text(
                '${state.currency} ${state.amount}',
                style: TextStyle(
                  fontSize: theme.typography.fontSizeXl,
                  fontWeight: theme.typography.fontWeightBold,
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
              ),
            ],
            SizedBox(height: theme.spacing.md),
            ElevatedButton(
              onPressed: state.paymentUrl.isNotEmpty
                  ? () async {
                      await launchUrl(Uri.parse(state.paymentUrl), mode: LaunchMode.externalApplication);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF635BFF), // Stripe color
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: theme.spacing.sm,
                  horizontal: theme.spacing.lg,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.borderRadius.md),
                ),
              ),
              child: const Text('Pay Now'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for redirect
class RedirectNodeWidget extends StatelessWidget {
  final ui_state.RedirectUIState state;
  final ConferBotTheme theme;

  const RedirectNodeWidget({
    super.key,
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // In production, would use url_launcher to open the URL
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.borderRadius.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          children: [
            Icon(
              Icons.open_in_new,
              color: theme.colors.primary,
            ),
            SizedBox(width: theme.spacing.sm),
            Text(
              'Redirecting...',
              style: TextStyle(
                fontSize: theme.typography.fontSizeMd,
                color: theme.colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== HELPER COMPONENTS ====================

/// Bot message bubble widget
class BotMessageBubble extends StatelessWidget {
  final String text;
  final ConferBotTheme theme;

  const BotMessageBubble({
    super.key,
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(theme.spacing.sm),
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
