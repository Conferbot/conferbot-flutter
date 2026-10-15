/// Small helpers the step handlers share (React Native
/// src/core/nodes/handlers/flowKit.ts): owner text filled from the answers
/// as the visitor sees it, record entries in the web's shapes, bot and
/// visitor lines (which the chat UI draws).
library;

import '../../flow/js.dart' show jsIsoString, jsString;
import '../../flow/text.dart';
import '../../state/chat_state.dart';

/// Owner HTML with the answers filled in (values escaped), as one native
/// bubble's text.
String shownText(ChatState state, dynamic html) =>
    bubbleText(state.resolveVariables(html == null ? '' : html.toString(), mode: 'html'));

/// Owner HTML filled in, as one line (labels of buttons and options).
String shownLabel(ChatState state, dynamic html) =>
    plainText(state.resolveVariables(html == null ? '' : html.toString(), mode: 'html'));

/// What an option saves: its own text, HTML stripped and entities decoded
/// (never filled).
String savedText(dynamic html) => stripHtmlAndDecode(html);

/// A non-blank text after stripping tags.
bool notBlank(dynamic v) => plainText(v) != '';

/// The visitor's answer on the record (shape "user-..."), merged as the web does.
void pushAnswer(ChatState state, Map<String, dynamic> entry, [DateTime? now]) {
  state.addRecord({...entry, '_id': entry['id'], 'time': jsIsoString(now ?? DateTime.now())});
}

/// A bot line in the chat (a question, a greeting, an answer); [data]
/// carries media or links ({imageUrl}, {videoUrl}, {fileUrl, fileName},
/// {html}, {linkUrl, linkLabel}...).
void botSay(ChatState state, String text, String nodeId, String nodeType, [Map<String, dynamic>? data]) {
  if (text.isEmpty && data == null) return;
  state.addBotMessage(text, nodeId, nodeType, data);
}

/// The visitor's line (as typed: the transcript is never masked).
void userSay(ChatState state, String text, String nodeId) => state.addUserMessage(text, nodeId);

/// A typed answer, trimmed: from a string or the text input's {value}.
String typedText(dynamic response) {
  if (response is String) return response.trim();
  if (response is Map) {
    final v = response['value'] ?? response['text'] ?? response['message'];
    if (v != null && v is! Map && v is! List) return jsString(v).trim();
  }
  if (response is num) return jsString(response);
  return '';
}

/// The id of the button / option the visitor picked.
String? pickedId(dynamic response) {
  if (response == null) return null;
  if (response is! Map) return jsString(response);
  final id = response['buttonId'] ?? response['choiceId'] ?? response['optionId'] ?? response['id'] ?? response['selectedId'];
  return id == null ? null : jsString(id);
}
