/// What the German sweeps check (RN __tests__/components/i18nSweep.test.tsx,
/// Android I18nFlowSweepTest): a drawn string holds no English table value
/// the German table words differently. The owner's own strings are taken
/// out first: what the owner wrote is shown as written.
library;

import 'package:conferbot_flutter/src/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _hole = RegExp(r'\{\w+\}');

/// English table values the German table words differently, as patterns.
final List<(String, RegExp)> englishValues = () {
  final en = I18n.dictionary('en');
  final de = I18n.dictionary('de');
  final out = <(String, RegExp)>[];
  for (final key in en.keys) {
    final v = en[key]!;
    if (de[key] == null || de[key] == v) continue;
    if (_hole.hasMatch(v)) {
      // The longest literal part of a template ("{name} is typing" -> " is typing").
      final parts = v.split(_hole).map((p) => p.trim()).toList()..sort((a, b) => b.length - a.length);
      if (parts.first.length >= 8) out.add((key, RegExp(RegExp.escape(parts.first))));
    } else if (v.trim().length >= 4) {
      out.add((key, RegExp('(^|[^A-Za-zÀ-ÿ])${RegExp.escape(v.trim())}(\$|[^A-Za-zÀ-ÿ])')));
    }
  }
  return out;
}();

// The German table's words of 6 or more letters without placeholders, longest first.
final List<String> _activeWords = (I18n.dictionary('de')
        .entries
        .where((e) => !_hole.hasMatch(e.value) && e.value.trim().length >= 6 && I18n.dictionary('en')[e.key] != e.value)
        .map((e) => e.value.trim())
        .toSet()
        .toList()
      ..sort((a, b) => b.length - a.length));

/// Every string in [roots] (maps, lists), and the text of its HTML and markdown.
List<String> ownerStrings(List<Object?> roots) {
  final out = <String>[];
  void walk(Object? v) {
    if (v is String) {
      out.add(v);
      out.addAll(v
          .replaceAll(RegExp(r'<[^>]*>'), '\n')
          .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1)!)
          .split(RegExp(r'\n|\*\*'))
          .map((s) => s.trim()));
    } else if (v is Map) {
      v.values.forEach(walk);
    } else if (v is Iterable) {
      v.forEach(walk);
    }
  }

  roots.forEach(walk);
  final list = out.map((s) => s.trim()).where((s) => s.length >= 2).toSet().toList()
    ..sort((a, b) => b.length - a.length);
  return list;
}

/// What in [strings] is English, the owner's own strings taken out first.
List<String> englishIn(Iterable<String> strings, [List<String> owner = const []]) {
  final templates = owner
      .where(_hole.hasMatch)
      .map((o) => RegExp(o.split(_hole).map(RegExp.escape).join('.+?')))
      .toList();
  final bad = <String>[];
  for (final drawn in strings) {
    // The language's own words woven into the owner's ("(öffnet in einem
    // neuen Tab)" after a link) are not the owner's: taken out first.
    var raw = drawn.replaceAll(RegExp(r'\s+'), ' ');
    for (final w in _activeWords) {
      raw = raw.split(w).join(' ');
    }
    raw = raw.replaceAll(RegExp(r' +'), ' ').replaceAllMapped(RegExp(r' ([.,;:!?)])'), (m) => m.group(1)!);
    final trimmed = raw.trim();
    if (trimmed.length >= 2 && owner.any((o) => o.contains(trimmed))) continue;
    var s = raw;
    for (final o in owner) {
      s = s.split(o).join(' ');
    }
    for (final re in templates) {
      s = s.replaceAll(re, ' ');
    }
    s = s.trim();
    if (s.isEmpty) continue;
    for (final (key, re) in englishValues) {
      if (re.hasMatch(s)) {
        bad.add('"$drawn" (en $key)');
        break;
      }
    }
  }
  return bad.toSet().toList();
}

/// Every string on screen: texts, rich texts, field hints and labels,
/// tooltips and semantics labels.
List<String> drawnStrings(WidgetTester tester) {
  final out = <String>[];
  void add(String? s) {
    final v = s?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (v != null && v.isNotEmpty) out.add(v);
  }

  for (final w in tester.allWidgets) {
    if (w is Text) {
      add(w.data ?? w.textSpan?.toPlainText());
      add(w.semanticsLabel);
    } else if (w is RichText) {
      add(w.text.toPlainText());
    } else if (w is TextField) {
      add(w.decoration?.hintText);
      add(w.decoration?.labelText);
      add(w.decoration?.helperText);
      add(w.decoration?.errorText);
    } else if (w is Tooltip) {
      add(w.message);
    } else if (w is Semantics) {
      add(w.properties.label);
      add(w.properties.hint);
      add(w.properties.value);
    } else if (w is IconButton) {
      add(w.tooltip);
    } else if (w is Image) {
      add(w.semanticLabel);
    } else if (w is Icon) {
      add(w.semanticLabel);
    }
  }
  return out;
}
