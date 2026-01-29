import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../node_types.dart';
import '../node_result.dart';
import '../node_ui_state.dart';
import '../../state/chat_state.dart';
import '../../../config/constants.dart';
import '../../../utils/logger.dart';

/// Voice message response data
class VoiceMessageResponse {
  /// Local file path of the recording
  final String localFilePath;

  /// Duration of the recording
  final Duration duration;

  /// Upload URL (set after upload)
  String? uploadedUrl;

  VoiceMessageResponse({
    required this.localFilePath,
    required this.duration,
    this.uploadedUrl,
  });

  Map<String, dynamic> toJson() => {
        'localFilePath': localFilePath,
        'duration': duration.inMilliseconds,
        'uploadedUrl': uploadedUrl,
      };
}

/// Handler for voice input nodes
/// Processes voice recording requests and uploads recordings to server
class VoiceMessageHandler {
  /// The node type this handler processes
  String get nodeType => 'voice-input-node';

  /// Chat state singleton
  ChatState get state => ChatState();

  /// API configuration (should be provided via initialization)
  String? _apiKey;
  String? _botId;
  String? _baseUrl;

  /// Initialize with API credentials
  void initialize({
    required String apiKey,
    required String botId,
    String? baseUrl,
  }) {
    _apiKey = apiKey;
    _botId = botId;
    _baseUrl = baseUrl ?? ConferBotConstants.defaultApiBaseUrl;
  }

  /// Process the voice input node and return UI state
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId) async {
    final questionText = _getString(nodeData, 'questionText', 'Please record a voice message');
    final answerKey = _getString(nodeData, 'answerVariable', 'voice_message');
    final maxDuration = _getInt(nodeData, 'maxDurationSeconds', 120);
    final allowTextFallback = _getBoolean(nodeData, 'allowTextFallback', true);

    // Add question to transcript
    state.addToTranscript('bot', questionText);

    // Initialize answer variable
    state.addAnswerVariable(nodeId, answerKey);

    return NodeResult.displayUI(
      VoiceInputUIState(
        questionText: questionText,
        maxDurationSeconds: maxDuration,
        answerKey: answerKey,
        allowTextFallback: allowTextFallback,
        nodeId: nodeId,
      ),
    );
  }

  /// Handle voice recording response
  /// Response should contain the local file path and duration
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    // Handle text fallback
    if (response is String) {
      return _handleTextFallback(response, nodeData, nodeId);
    }

    // Handle voice recording
    if (response is Map<String, dynamic>) {
      return _handleVoiceRecording(response, nodeData, nodeId);
    }

    if (response is VoiceMessageResponse) {
      return _handleVoiceRecordingResponse(response, nodeData, nodeId);
    }

    return const NodeResult.error(
      message: 'Invalid response format',
      shouldProceed: false,
    );
  }

  /// Handle text fallback when user types instead of recording
  Future<NodeResult> _handleTextFallback(
    String text,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      return const NodeResult.error(
        message: 'Please record a voice message or type your response',
        shouldProceed: false,
      );
    }

    state.setAnswerVariable(nodeId, trimmedText);
    state.addToTranscript('user', trimmedText);

    _recordResponse(
      nodeId: nodeId,
      shape: 'user-voice-text-fallback',
      text: trimmedText,
      type: nodeType,
    );

    return const NodeResult.proceed();
  }

  /// Handle voice recording response
  Future<NodeResult> _handleVoiceRecording(
    Map<String, dynamic> response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    final localFilePath = response['localFilePath'] as String?;
    final durationMs = response['duration'] as int?;
    final uploadedUrl = response['uploadedUrl'] as String?;

    if (localFilePath == null && uploadedUrl == null) {
      return const NodeResult.error(
        message: 'Invalid voice recording response',
        shouldProceed: false,
      );
    }

    final duration = durationMs != null
        ? Duration(milliseconds: durationMs)
        : const Duration(seconds: 1);

    String? audioUrl = uploadedUrl;

    // Upload if not already uploaded
    if (audioUrl == null && localFilePath != null) {
      try {
        audioUrl = await uploadVoiceMessage(
          filePath: localFilePath,
          chatSessionId: state.chatSessionId ?? '',
        );
      } catch (e) {
        voiceLogger.error('Upload failed: $e');
        return NodeResult.error(
          message: 'Failed to upload voice message: $e',
          shouldProceed: false,
        );
      }
    }

    if (audioUrl == null) {
      return const NodeResult.error(
        message: 'Failed to upload voice message',
        shouldProceed: false,
      );
    }

    // Store the audio URL as the answer
    state.setAnswerVariable(nodeId, audioUrl);

    // Add display text to transcript
    final durationText = _formatDuration(duration);
    state.addToTranscript('user', '[Voice message: $durationText]');

    // Record the response
    _recordResponse(
      nodeId: nodeId,
      shape: 'user-voice-message-response',
      text: '[Voice message: $durationText]',
      type: nodeType,
      additionalData: {
        'url': audioUrl,
        'duration': duration.inMilliseconds,
        'mimeType': 'audio/m4a',
      },
    );

    return const NodeResult.delayedProceed(delay: Duration(milliseconds: 300));
  }

  /// Handle VoiceMessageResponse object
  Future<NodeResult> _handleVoiceRecordingResponse(
    VoiceMessageResponse response,
    Map<String, dynamic> nodeData,
    String nodeId,
  ) async {
    return _handleVoiceRecording(
      {
        'localFilePath': response.localFilePath,
        'duration': response.duration.inMilliseconds,
        'uploadedUrl': response.uploadedUrl,
      },
      nodeData,
      nodeId,
    );
  }

  /// Upload voice message to server
  /// Returns the uploaded file URL
  Future<String> uploadVoiceMessage({
    required String filePath,
    required String chatSessionId,
  }) async {
    if (_apiKey == null || _botId == null) {
      throw Exception('VoiceMessageHandler not initialized. Call initialize() first.');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Recording file not found: $filePath');
    }

    final uri = Uri.parse('$_baseUrl/upload/voice');

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        ConferBotConstants.headerApiKey: _apiKey!,
        ConferBotConstants.headerBotId: _botId!,
        ConferBotConstants.headerPlatform: ConferBotConstants.platformIdentifier,
      })
      ..fields['chatSessionId'] = chatSessionId
      ..fields['type'] = 'voice_message'
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: filePath.split('/').last,
      ));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      final url = jsonData['data']?['url'] as String? ?? jsonData['url'] as String?;

      if (url == null) {
        throw Exception('No URL in upload response');
      }

      return url;
    } else {
      final errorMessage = _parseErrorMessage(response.body);
      throw Exception('Upload failed: $errorMessage');
    }
  }

  /// Parse error message from response body
  String _parseErrorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['error'] as String? ?? json['message'] as String? ?? 'Unknown error';
    } catch (_) {
      return body;
    }
  }

  /// Record a user response entry
  void _recordResponse({
    required String nodeId,
    required String shape,
    String? text,
    String? type,
    Map<String, dynamic> additionalData = const {},
  }) {
    final entry = RecordEntry(
      id: nodeId,
      shape: shape,
      type: type,
      text: text,
      data: Map<String, dynamic>.from(additionalData),
    );
    state.pushToRecord(entry);
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Get string from nodeData with default
  String _getString(Map<String, dynamic> nodeData, String key, [String defaultValue = '']) {
    return nodeData[key]?.toString() ?? defaultValue;
  }

  /// Get int from nodeData with default
  int _getInt(Map<String, dynamic> nodeData, String key, [int defaultValue = 0]) {
    final value = nodeData[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Get boolean from nodeData with default
  bool _getBoolean(Map<String, dynamic> nodeData, String key, [bool defaultValue = false]) {
    final value = nodeData[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return defaultValue;
  }
}

/// Extension to add voice message node type to NodeTypes
extension VoiceNodeTypes on NodeTypes {
  /// Voice input node type
  static const String voiceInput = 'voice-input-node';
}

/// Singleton instance of voice message handler
final voiceMessageHandler = VoiceMessageHandler();
