/// Display handlers for bot response nodes
///
/// This file contains handlers and UI states for display-only nodes:
/// - MessageNodeHandler (text messages)
/// - ImageNodeHandler (image display)
/// - VideoNodeHandler (video playback)
/// - AudioNodeHandler (audio playback)
/// - FileNodeHandler (file download)
/// - HtmlNodeHandler (HTML content)
/// - UserRedirectNodeHandler (URL redirect)
/// - NavigateNodeHandler (in-app navigation)
library;

import '../node_types.dart';
import 'legacy_handlers.dart';

// ============================================================================
// DISPLAY UI STATES
// ============================================================================

/// Simple text message from bot
class MessageState extends NodeUIState {
  final String text;
  final String nodeId;

  const MessageState({
    required this.text,
    required this.nodeId,
  });
}

/// Image display
class ImageState extends NodeUIState {
  final String url;
  final String? caption;
  final String nodeId;

  const ImageState({
    required this.url,
    this.caption,
    required this.nodeId,
  });
}

/// Video display
class VideoState extends NodeUIState {
  final String url;
  final String? caption;
  final String nodeId;

  const VideoState({
    required this.url,
    this.caption,
    required this.nodeId,
  });
}

/// Audio playback
class AudioState extends NodeUIState {
  final String url;
  final String? caption;
  final String nodeId;

  const AudioState({
    required this.url,
    this.caption,
    required this.nodeId,
  });
}

/// File download
class FileState extends NodeUIState {
  final String url;
  final String fileName;
  final String nodeId;

  const FileState({
    required this.url,
    required this.fileName,
    required this.nodeId,
  });
}

/// HTML content
class HtmlState extends NodeUIState {
  final String htmlContent;
  final String nodeId;

  const HtmlState({
    required this.htmlContent,
    required this.nodeId,
  });
}

/// External redirect
class RedirectState extends NodeUIState {
  final String url;
  final bool openInNewTab;
  final String nodeId;

  const RedirectState({
    required this.url,
    this.openInNewTab = true,
    required this.nodeId,
  });
}

/// Calendar/date-time picker UI state
/// Used by Google Calendar, Google Meet, and other booking integrations
class CalendarState extends NodeUIState {
  final String? questionText;
  final bool showTimeSelection;
  final String? timezone;
  final String nodeId;
  final String answerKey;

  const CalendarState({
    this.questionText,
    this.showTimeSelection = false,
    this.timezone,
    required this.nodeId,
    required this.answerKey,
  });
}

// ============================================================================
// DISPLAY NODE HANDLERS
// ============================================================================

/// Handler for message-node
/// Displays a text message from the bot
class MessageNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.message;

  @override
  Future<NodeResult> process(
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final text = getString(nodeData, 'text');
    final message = getString(nodeData, 'message', text);

    // Add to transcript
    state?.addToTranscript('bot', message);

    // Record the message
    recordResponse(
      nodeId: nodeId,
      shape: 'bot-message',
      text: message,
      type: nodeType,
    );

    // Return UI state for display
    return DisplayUI(
      MessageState(
        text: message,
        nodeId: nodeId,
      ),
    );
  }
}

/// Handler for image-node
/// Displays an image
class ImageNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.image;

  @override
  Future<NodeResult> process(
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final imageUrl = getString(nodeData, 'image');
    final caption = nodeData['caption']?.toString();

    // Add to transcript
    state?.addToTranscript('bot', caption ?? '[Image]');

    // Record
    recordResponse(
      nodeId: nodeId,
      shape: 'bot-image',
      text: caption,
      type: nodeType,
      additionalData: {'imageUrl': imageUrl},
    );

    return DisplayUI(
      ImageState(
        url: imageUrl,
        caption: caption,
        nodeId: nodeId,
      ),
    );
  }
}

/// Handler for video-node
/// Displays a video player
class VideoNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.video;

  @override
  Future<NodeResult> process(
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final videoUrl = getString(nodeData, 'video');
    final caption = nodeData['caption']?.toString();

    state?.addToTranscript('bot', caption ?? '[Video]');

    recordResponse(
      nodeId: nodeId,
      shape: 'bot-video',
      text: caption,
      type: nodeType,
      additionalData: {'videoUrl': videoUrl},
    );

    return DisplayUI(
      VideoState(
        url: videoUrl,
        caption: caption,
        nodeId: nodeId,
      ),
    );
  }
}

/// Handler for audio-node
/// Displays an audio player
class AudioNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.audio;

  @override
  Future<NodeResult> process(
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final audioUrl = getString(nodeData, 'audio');
    final caption = nodeData['caption']?.toString();

    state?.addToTranscript('bot', caption ?? '[Audio]');

    recordResponse(
      nodeId: nodeId,
      shape: 'bot-audio',
      text: caption,
      type: nodeType,
      additionalData: {'audioUrl': audioUrl},
    );

    return DisplayUI(
      AudioState(
        url: audioUrl,
        caption: caption,
        nodeId: nodeId,
      ),
    );
  }
}

/// Handler for file-node
/// Displays a file download
class FileNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.file;

  @override
  Future<NodeResult> process(
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final fileUrl = getString(nodeData, 'file');
    final fileName = getString(nodeData, 'fileName', 'Download File');

    state?.addToTranscript('bot', '[File: $fileName]');

    recordResponse(
      nodeId: nodeId,
      shape: 'bot-file',
      text: fileName,
      type: nodeType,
      additionalData: {'fileUrl': fileUrl, 'fileName': fileName},
    );

    return DisplayUI(
      FileState(
        url: fileUrl,
        fileName: fileName,
        nodeId: nodeId,
      ),
    );
  }
}

/// Handler for html-node
/// Displays HTML content
class HtmlNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.html;

  @override
  Future<NodeResult> process(
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final htmlContent = getString(nodeData, 'html');

    state?.addToTranscript('bot', '[HTML Content]');

    recordResponse(
      nodeId: nodeId,
      shape: 'bot-html',
      text: null,
      type: nodeType,
      additionalData: {'html': htmlContent},
    );

    return DisplayUI(
      HtmlState(
        htmlContent: htmlContent,
        nodeId: nodeId,
      ),
    );
  }
}

/// Handler for user-redirect-node
/// Redirects user to external URL
class UserRedirectNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.userRedirect;

  @override
  Future<NodeResult> process(
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final url = getString(nodeData, 'url');
    final openInNewTab = getBoolean(nodeData, 'openInNewTab', true);

    state?.addToTranscript('bot', '[Redirect to: $url]');

    recordResponse(
      nodeId: nodeId,
      shape: 'bot-redirect',
      text: url,
      type: nodeType,
    );

    return DisplayUI(
      RedirectState(
        url: url,
        openInNewTab: openInNewTab,
        nodeId: nodeId,
      ),
    );
  }
}

/// Handler for navigate-node
/// Similar to redirect but for in-app navigation
class NavigateNodeHandler extends BaseNodeHandler {
  @override
  String get nodeType => NodeTypes.navigate;

  @override
  Future<NodeResult> process(
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final url = getString(nodeData, 'url');

    recordResponse(
      nodeId: nodeId,
      shape: 'bot-navigate',
      text: url,
      type: nodeType,
    );

    return DisplayUI(
      RedirectState(
        url: url,
        openInNewTab: false,
        nodeId: nodeId,
      ),
    );
  }
}

// ============================================================================
// REGISTRY HELPER
// ============================================================================

/// Get all display node handlers
List<NodeHandler> getDisplayNodeHandlers() {
  return [
    MessageNodeHandler(),
    ImageNodeHandler(),
    VideoNodeHandler(),
    AudioNodeHandler(),
    FileNodeHandler(),
    HtmlNodeHandler(),
    UserRedirectNodeHandler(),
    NavigateNodeHandler(),
  ];
}
