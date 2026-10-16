/// Auto-open: the owner's botAutoOpen / botAutoOpenDelay (seconds) open the
/// chat on its own, for a first visit only. Ported from the React Native SDK
/// (src/core/autoOpen.ts), itself from conferbot-widget src/index.ts (the
/// live_chat / popup_chat auto-open, ~2003-2070) and
/// src/core/customizations.ts (autoOpen, autoOpenDelay):
///
///   - only while the visitor has not started a chat (a conversation they
///     already have is theirs to reopen: web `!chatStarted`);
///   - not when they closed the chat in the last 2 minutes (the web's
///     isChatOpen=false cookie lasts 120 s);
///   - once per launch of the app (the web: once per page load);
///   - when the delay is up and the chat is already open, nothing.
///
/// Pure.
library;

class AutoOpen {
  AutoOpen._();

  /// A close blocks auto-open this long (web: the isChatOpen cookie's 2 minutes).
  static const closedBlocksMs = 120000;

  static bool _truthy(dynamic v) =>
      v != null && v != false && v != 0 && v != '' && !(v is double && v.isNaN);

  /// The owner's delay in milliseconds (unset, junk or negative: at once).
  static int delayOf(dynamic c) {
    final raw = c is Map ? c['botAutoOpenDelay'] : null;
    final s = raw is num ? raw.toDouble() : (raw is String ? double.tryParse(raw.trim()) : null);
    return s != null && s.isFinite && s > 0 ? (s * 1000).round() : 0;
  }

  /// In how many ms to open the chat, or null for not at all.
  static int? plan(
    dynamic c, {
    required bool chatStarted,
    required bool isOpen,
    required bool alreadyAutoOpened,
    int? closedAt,
    int? now,
  }) {
    if (c is! Map || !_truthy(c['botAutoOpen']) || chatStarted || isOpen || alreadyAutoOpened) return null;
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    if (closedAt != null && closedAt > 0 && at - closedAt < closedBlocksMs) return null;
    return delayOf(c);
  }
}
