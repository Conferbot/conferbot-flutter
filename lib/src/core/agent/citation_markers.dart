/// Placeholder citation markers in AI answers, as embed-server
/// utils/citationMarkers.js stripPlaceholderMarkers.
///
/// The server strips markers from new answers, but answers saved before that
/// can come back in restored history with an echoed placeholder ("[n]",
/// "[N]", "[1, n]") or a label ("[source]", "[web:2]"). Conservative on
/// purpose: a bracket goes only when every part is a number or one of the
/// placeholder words, and at least one part is not a plain number ("[2]"
/// could be the author's own). "[Klik hier]", a markdown link "[n](url)" and
/// a task-list "- [x]" stay as written.
library;

// Words a model writes in place of (or in front of) a passage number.
const _words = r'n|x|k|\#|nr|no|num|number|source|sources|citation|citations|cite|ref|refs|reference|references|'
    r'passage|passages|knowledge|kb|faq|context|doc|docs|website|web|instruction|instructions';

// One part of a marker: "2", "n", "source", "source 2", "web:2", "passage n".
const _part = '(?:\\d+|(?:$_words)(?:[ \\t]*[:#-]?[ \\t]*(?:\\d+|n))?)';
// A whole marker, with the one space before it. Not a markdown link ("[n](url)").
final _marker = RegExp('[ \\t]?\\[[ \\t]*$_part(?:[ \\t]*[,;][ \\t]*$_part)*[ \\t]*\\](?!\\()', caseSensitive: false);
final _numeric = RegExp(r'^\[\s*\d+(?:\s*[,;]\s*\d+)*\s*\]$');
final _checkbox = RegExp(r'^\s*\[\s*x\s*\]$', caseSensitive: false);
final _listStart = RegExp(r'(^|\n)[ \t]*[-*+][ \t]*$');
// What a removed marker leaves: "zit ." and "zit ,".
final _spaceBeforePunct = RegExp(r'[ \t]+([.,;:!?])');

/// [text] without its placeholder markers; unchanged when it has none.
String stripPlaceholderMarkers(String text) {
  var changed = false;
  final out = text.replaceAllMapped(_marker, (m) {
    final marker = m[0]!;
    final before = text.substring(m.start - 40 < 0 ? 0 : m.start - 40, m.start);
    final isCheckbox = _checkbox.hasMatch(marker) && _listStart.hasMatch(before);
    if (isCheckbox || _numeric.hasMatch(marker.trim())) return marker;
    changed = true;
    return '';
  });
  if (!changed) return text;
  return out.replaceAllMapped(_spaceBeforePunct, (m) => m[1]!).trim();
}
