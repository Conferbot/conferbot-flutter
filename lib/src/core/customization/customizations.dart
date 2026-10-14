/// The bot's customizations as the web widget applies them
/// (conferbot-widget core/customizations.ts buildCustomizationsRef and the
/// polish / owner sheets): defaults, the values that count as unset, and
/// what each one turns into on screen. Pure: the widgets read the result.
library;

class BubbleCorners {
  final double topLeft;
  final double topRight;
  final double bottomRight;
  final double bottomLeft;

  const BubbleCorners(this.topLeft, this.topRight, this.bottomRight, this.bottomLeft);
  const BubbleCorners.all(double r) : this(r, r, r, r);

  @override
  bool operator ==(Object other) =>
      other is BubbleCorners && other.topLeft == topLeft && other.topRight == topRight && other.bottomRight == bottomRight && other.bottomLeft == bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);

  @override
  String toString() => 'BubbleCorners($topLeft, $topRight, $bottomRight, $bottomLeft)';
}

class ResolvedCustomizations {
  /// "Powered by Conferbot" hidden (the server forces false on Free/Starter).
  final bool hideBrand;

  /// The owner's footer text instead of "Powered by", when turned on.
  final String? customBrand;

  /// Header title: logoText (or the bot name), cut to 18 characters.
  final String title;

  /// Header logo: the owner's, else the Conferbot logo (as the web).
  final String logo;
  final bool hideLogo;

  /// Under the title: the tagline when turned on, else "Online" (unless hidden).
  final String? tagline;
  final bool showOnline;

  /// Bot avatar beside messages (the logo when no avatar of its own).
  final String avatar;
  final bool hideAvatar;
  final double avatarSize;
  final String avatarShape;
  final double avatarRadius;

  /// Bubble corners: the web's 18/6 shapes unless the owner set a radius.
  final BubbleCorners botBubble;
  final BubbleCorners userBubble;
  final double optionRadius;

  /// Message text size: 14.5 unless the owner set something other than 14.
  final double fontSize;

  /// Colours as hex strings, with the web's defaults and fallbacks.
  final String headerBg;
  final String headerText;
  final String botBubbleColor;
  final String botTextColor;
  final String userBubbleColor;
  final String userTextColor;
  final String optionBubbleColor;
  final String optionTextColor;

  /// dots, wave, shimmer, pencil or mascot (pencil and mascot draw dots until mascots land).
  final String typingStyle;

  const ResolvedCustomizations({
    this.hideBrand = false,
    this.customBrand,
    this.title = 'Chat',
    this.logo = Customizations.defaultLogo,
    this.hideLogo = false,
    this.tagline,
    this.showOnline = true,
    this.avatar = Customizations.defaultLogo,
    this.hideAvatar = false,
    this.avatarSize = 32,
    this.avatarShape = 'circle',
    this.avatarRadius = 16,
    this.botBubble = const BubbleCorners(18, 18, 18, 6),
    this.userBubble = const BubbleCorners(18, 18, 6, 18),
    this.optionRadius = 10,
    this.fontSize = 14.5,
    this.headerBg = '#0b4eb8',
    this.headerText = '#ffffff',
    this.botBubbleColor = '#0b4eb8',
    this.botTextColor = '#ffffff',
    this.userBubbleColor = '#f0f0f0',
    this.userTextColor = '#000000',
    this.optionBubbleColor = '#0b4eb8',
    this.optionTextColor = '#ffffff',
    this.typingStyle = 'dots',
  });
}

class Customizations {
  Customizations._();

  /// The web widget's default logo (utils/constants BOT_LOGO): header and bot avatar.
  static const defaultLogo = 'https://www.conferbot.com/img/logo/conferbot-logo.png';

  static const _typingStyles = {'dots', 'wave', 'shimmer', 'pencil', 'mascot'};

  static String _str(dynamic v) => v is String ? v.trim() : '';

  static double? _num(dynamic v) {
    if (v is num && v.isFinite) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  static String? _url(dynamic v) {
    final s = _str(v);
    final l = s.toLowerCase();
    return l.startsWith('http://') || l.startsWith('https://') || l.startsWith('//') || l.startsWith('data:image/') ? s : null;
  }

  /// "Live chat test (te..." - 18 characters, as the header cuts it.
  static String headerTitle(String name) => name.length > 18 ? '${name.substring(0, 18)}...' : name;

  /// The avatar's corner radius for its shape: circle 50%, rounded 28%, square 4.
  static double avatarRadiusFor(String? shape, double size) => switch (shape) {
        'square' => 4,
        'rounded' => (size * 0.28).roundToDouble(),
        _ => size / 2,
      };

  static ResolvedCustomizations resolve(Map<String, dynamic>? raw, {String botName = ''}) {
    final c = raw ?? const <String, dynamic>{};
    final name = [_str(c['logoText']), _str(c['botName']), botName].firstWhere((s) => s.isNotEmpty, orElse: () => 'Chat');
    final tagline = c['enableTagline'] == true && _str(c['tagline']).isNotEmpty ? _str(c['tagline']) : null;
    final avatarSet = _num(c['avatarSize']);
    final avatarSize = avatarSet != null && avatarSet > 0 && avatarSet != 40 ? avatarSet : 32.0;
    final shape = c['avatarShape'] == 'square' || c['avatarShape'] == 'rounded' ? c['avatarShape'] as String : 'circle';
    final bubbleSet = _num(c['bubbleBorderRadius']);
    final ownBubble = bubbleSet != null && bubbleSet != 10;
    final fontSet = _num(c['fontSize']);
    final logo = _url(c['logo']);
    final bot = _str(c['botMsgColor']);
    final botText = _str(c['botTextColor']);
    final user = _str(c['userMsgColor']);
    String first(List<String> v, String fallback) => v.firstWhere((s) => s.isNotEmpty, orElse: () => fallback);
    return ResolvedCustomizations(
      hideBrand: c['hideBrand'] == true,
      customBrand: c['enableCustomBrand'] == true && _str(c['customBrand']).isNotEmpty ? _str(c['customBrand']) : null,
      title: headerTitle(name),
      logo: logo ?? defaultLogo,
      hideLogo: c['hideLogo'] == true,
      tagline: tagline,
      showOnline: tagline == null && c['hideOnlineStatus'] != true,
      avatar: _url(c['avatar']) ?? logo ?? defaultLogo,
      hideAvatar: c['hideAvatar'] == true,
      avatarSize: avatarSize,
      avatarShape: shape,
      avatarRadius: avatarRadiusFor(shape, avatarSize),
      botBubble: ownBubble ? BubbleCorners.all(bubbleSet) : const BubbleCorners(18, 18, 18, 6),
      userBubble: ownBubble ? BubbleCorners.all(bubbleSet) : const BubbleCorners(18, 18, 6, 18),
      optionRadius: _num(c['optionBubbleBorderRadius']) ?? 10,
      fontSize: fontSet != null && fontSet > 0 && fontSet != 14 ? fontSet : 14.5,
      headerBg: first([_str(c['headerBgColor'])], '#0b4eb8'),
      headerText: first([_str(c['headerTextColor'])], '#ffffff'),
      botBubbleColor: first([bot], '#0b4eb8'),
      botTextColor: first([botText], '#ffffff'),
      // The visitor's bubble: light grey with dark text, never the bot's colour.
      userBubbleColor: first([user], '#f0f0f0'),
      userTextColor: first([_str(c['userTextColor'])], user.isEmpty ? '#000000' : '#ffffff'),
      // Choices: the option colours, else the bot's, else grey with black text.
      optionBubbleColor: first([_str(c['optionBubbleMsgColor']), bot], '#e7e4e4'),
      optionTextColor: first([_str(c['optionBubbleTextColor']), botText], '#000000'),
      typingStyle: _typingStyles.contains(c['typingStyle']) ? c['typingStyle'] as String : 'dots',
    );
  }
}
