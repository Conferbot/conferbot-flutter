/// "Email me this chat" (web ts/chat/emailTranscript.ts, ported from the
/// React Native SDK's src/core/emailTranscript.ts): the visitor gets the
/// whole conversation in their inbox, and the address they give is kept on
/// the conversation like any email they leave.
///
/// Sent by the embed server, only ever to the address typed here and
/// rate-limited (5 per 15 minutes per IP, shared with the web route). The web
/// posts to /api/v1/chat/transcript-email with the botId in the body; an app
/// posts to the mobile base path, /api/v1/mobile/chat/transcript-email, and
/// the bot comes from its X-Bot-ID header (embed-server #193).
///
/// Pure: the request's path and body, and how its answer reads.
library;

class TranscriptEmailResult {
  final bool ok;
  final String? message;
  const TranscriptEmailResult(this.ok, [this.message]);

  static const notSent = TranscriptEmailResult(false);

  @override
  bool operator ==(Object other) => other is TranscriptEmailResult && other.ok == ok && other.message == message;

  @override
  int get hashCode => Object.hash(ok, message);

  @override
  String toString() => 'TranscriptEmailResult($ok, $message)';
}

class EmailTranscript {
  EmailTranscript._();

  /// The web's address check (emailTranscript.ts EMAIL_RE).
  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static bool isEmail(String? email) => _emailRe.hasMatch((email ?? '').trim());

  /// Under the mobile API base (ConferBotEndpoints.apiBaseUrl, ".../api/v1/mobile").
  static const path = '/chat/transcript-email';

  static Map<String, dynamic> body(String chatSessionId, String email) => {'chatSessionId': chatSessionId, 'email': email.trim()};

  /// The web's English strings (i18n en: chat.menu.emailChat, mailchat.*, form.*).
  static const menu = 'Email me this chat';
  static const title = 'Email me this chat';
  static const sub = "We'll send the whole conversation to your inbox.";
  static const placeholder = 'you@company.com';
  static const label = 'Your email';
  static const send = 'Send';
  static const sending = 'Sending…';
  static const cancel = 'Cancel';
  static const checkEmail = 'Please check the email address.';
  static const sendFailed = "We couldn't send it just now. Please try again.";
  static String sent(String email) => 'Sent! Check your inbox at $email';

  /// The server's answer read as the web reads it: sent only on a 2xx with
  /// `success: true`; otherwise its message, if it gave one (an invalid
  /// address is a 400, an unknown session a 200 with success false, the
  /// rate limit a 429 with `message`).
  static TranscriptEmailResult resultOf(int status, dynamic data) {
    final ok = status >= 200 && status < 300 && data is Map && data['success'] == true;
    if (ok) return const TranscriptEmailResult(true);
    var m = data is Map && data['message'] is String ? (data['message'] as String).trim() : '';
    if (m.length > 200) m = m.substring(0, 200);
    return TranscriptEmailResult(false, m.isEmpty ? null : m);
  }

  /// What the card says when it did not go: the server's words (it words
  /// them in English, as the SDK is), else ours.
  static String errorOf(TranscriptEmailResult? r) => (r != null && !r.ok ? r.message : null) ?? sendFailed;
}
