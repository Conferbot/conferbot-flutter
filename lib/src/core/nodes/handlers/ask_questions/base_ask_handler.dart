/// Base handler for ask question nodes
///
/// Provides common functionality for all ask-type handlers:
/// - Input validation (email, phone, URL, number)
/// - HTML stripping
/// - Response recording
/// - Answer variable management
library;

import '../../node_types.dart';
import '../../node_result.dart';
import '../../node_ui_state.dart';
import '../../../state/chat_state.dart';

/// Base interface for node handlers with chat state integration
abstract class BaseAskNodeHandler {
  /// The node type this handler processes
  String get nodeType;

  /// Chat state singleton for session management
  ChatState get state => ChatState();

  /// Process the node and return result
  Future<NodeResult> process(Map<String, dynamic> nodeData, String nodeId);

  /// Handle user response for interactive nodes
  Future<NodeResult> handleResponse(
    dynamic response,
    Map<String, dynamic> nodeData,
    String nodeId,
  );

  /// Record a user response entry
  void recordResponse({
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

  /// Get string from nodeData with default
  String getString(Map<String, dynamic> nodeData, String key, [String defaultValue = '']) {
    return nodeData[key]?.toString() ?? defaultValue;
  }

  /// Get int from nodeData with default
  int getInt(Map<String, dynamic> nodeData, String key, [int defaultValue = 0]) {
    final value = nodeData[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Get boolean from nodeData with default
  bool getBoolean(Map<String, dynamic> nodeData, String key, [bool defaultValue = false]) {
    final value = nodeData[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return defaultValue;
  }

  /// Get list from nodeData
  List<T> getList<T>(Map<String, dynamic> nodeData, String key) {
    final value = nodeData[key];
    if (value is List) return List<T>.from(value);
    return [];
  }

  /// Get map from nodeData
  Map<String, dynamic> getMap(Map<String, dynamic> nodeData, String key) {
    final value = nodeData[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  /// Strip HTML tags and decode entities
  String stripHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  /// Validate email format
  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  /// Validate phone number format
  bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^[+]?[0-9]{7,15}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[\s\-()]'), ''));
  }

  /// Validate URL format
  bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      return uri.scheme.isNotEmpty && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Validate number format
  bool isValidNumber(String value) {
    return double.tryParse(value.trim()) != null;
  }
}

/// Record entry for tracking responses
class RecordEntry {
  final String id;
  final String shape;
  final String? type;
  final String? text;
  final Map<String, dynamic> data;

  const RecordEntry({
    required this.id,
    required this.shape,
    this.type,
    this.text,
    this.data = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'shape': shape,
      if (type != null) 'type': type,
      if (text != null) 'text': text,
      ...data,
    };
  }
}
