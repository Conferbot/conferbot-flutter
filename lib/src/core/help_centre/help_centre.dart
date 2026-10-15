/// The help centre rules: one place that decides what the SDK shows of the
/// knowledge base. Ported from the web widget's `src/core/helpCentre.ts`.
///
///  1. The help centre is on only when the owner's `enableKnowledgeBase` is
///     true. It owns the help button and every article view.
///  2. A help centre with no published article counts as off (web
///     `index.ts`): no button, never an empty screen.
///  3. The "Recent articles" list is part of the help centre. It shows while
///     the help centre is on, there is a recent article, and the owner has
///     not hidden it (`hideRecentArticles`).
///  4. An article opens in the help centre only while it is on (an AI
///     source or a rich article card by `articleId`). Otherwise the chat
///     stays as it is, or the source's own link opens.
///
/// The app may override rule 1 with `ChatWidget(showKnowledgeBase: ...)`:
///  - `null` (default): follow the server.
///  - `false`: never show the help centre, whatever the server says.
///  - `true`: show it even when the owner's switch is off. Rule 2 still
///    applies to the server's data; with the switch off the server sends no
///    articles on connect, so the screen loads them over REST.
library;

import '../../models/knowledge_base.dart';

class HelpCentre {
  HelpCentre._();

  /// Rule 1: the owner's switch.
  static bool isOn(Map<String, dynamic>? customizations) =>
      customizations != null && customizations['enableKnowledgeBase'] == true;

  /// Rules 1, 2 and the app's override: may the help centre be offered?
  static bool isVisible({
    bool? override,
    Map<String, dynamic>? customizations,
    KnowledgeBaseData? data,
  }) {
    if (override != null) return override;
    return isOn(customizations) && data != null && data.isNotEmpty;
  }

  /// Rule 3: the Recent articles list.
  static bool showsRecentArticles(
    Map<String, dynamic>? customizations,
    List<KnowledgeBaseArticle>? recent,
  ) =>
      customizations?['hideRecentArticles'] != true && (recent?.isNotEmpty ?? false);

  /// Rule 4: may an article with this id open here?
  static bool canOpenArticle({
    required bool visible,
    String? articleId,
  }) =>
      visible && articleId != null && articleId.isNotEmpty;
}
