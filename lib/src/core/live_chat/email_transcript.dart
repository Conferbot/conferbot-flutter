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

import '../i18n/i18n.dart';

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

  /// The menu item's English words; [menuLabel] draws them in the active language.
  static const menu = 'Email me this chat';

  /// The web's strings (ts/chat/emailTranscript.ts: chat.menu.emailChat,
  /// mailchat.*, form.*, common.*), in the active language.
  static String get menuLabel => t('chat.menu.emailChat');
  static String get title => t('chat.menu.emailChat');
  static String get sub => t('mailchat.sub');
  static String get placeholder => t('form.emailPlaceholder');
  static String get label => t('form.yourEmail');
  static String get send => t('common.send');
  static String get sending => t('common.sendingEllipsis');
  static String get cancel => t('common.cancel');
  static String get checkEmail => t('form.checkEmail');
  static String get sendFailed => t('form.sendFailed');
  static String sent(String email) => t('mailchat.sent', {'email': email});

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

  /// What the card says when it did not go: the server's words in English
  /// (it words them in English only), else ours in the active language (web
  /// transcriptEmailError).
  static String errorOf(TranscriptEmailResult? r) =>
      (I18n.language == I18n.en && r != null && !r.ok ? r.message : null) ?? sendFailed;
}
