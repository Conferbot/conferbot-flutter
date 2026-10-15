import 'package:flutter/painting.dart';

import '../core/customization/customizations.dart';

/// The widget theme's outline round a bubble (cartoon, neo-brutal, sketch...), else null.
Border? bubbleOutline(ResolvedCustomizations? look) {
  final b = look?.bubbleBorder;
  if (b == null || !b.color.startsWith('#') || b.color.length != 7) return null;
  final n = int.tryParse(b.color.substring(1), radix: 16);
  return n == null ? null : Border.all(color: Color(0xFF000000 | n), width: b.width);
}
