import 'package:flutter/material.dart';

/// ConferBot theme configuration
class ConferBotTheme {
  final Brightness brightness;
  final ConferBotColors colors;
  final ConferBotTypography typography;
  final ConferBotSpacing spacing;
  final ConferBotBorderRadius borderRadius;
  final ConferBotShadows shadows;
  final ConferBotAnimations animations;
  final ConferBotLayout layout;

  const ConferBotTheme({
    required this.brightness,
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.borderRadius,
    required this.shadows,
    required this.animations,
    required this.layout,
  });

  ConferBotTheme copyWith({
    Brightness? brightness,
    ConferBotColors? colors,
    ConferBotTypography? typography,
    ConferBotSpacing? spacing,
    ConferBotBorderRadius? borderRadius,
    ConferBotShadows? shadows,
    ConferBotAnimations? animations,
    ConferBotLayout? layout,
  }) {
    return ConferBotTheme(
      brightness: brightness ?? this.brightness,
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      spacing: spacing ?? this.spacing,
      borderRadius: borderRadius ?? this.borderRadius,
      shadows: shadows ?? this.shadows,
      animations: animations ?? this.animations,
      layout: layout ?? this.layout,
    );
  }
}

/// Theme colors — matches Android SDK ConferbotColors
class ConferBotColors {
  // Primary colors
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;

  // Header colors
  final Color headerBg;
  final Color headerText;

  // Message bubble colors
  final Color userBubble;
  final Color userBubbleText;
  final Color botBubble;
  final Color botBubbleText;
  final Color agentBubble;
  final Color agentBubbleText;
  final Color systemBubble;
  final Color systemBubbleText;

  // Choice/option button colors
  final Color optionBubble;
  final Color optionBubbleText;

  // Text colors
  final Color text;
  final Color textSecondary;
  final Color textDisabled;

  // Border colors
  final Color border;
  final Color divider;

  // Status colors
  final Color success;
  final Color error;
  final Color warning;
  final Color info;

  // Connection status
  final Color online;
  final Color offline;

  const ConferBotColors({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    this.headerBg = const Color(0xFF0100EC),
    this.headerText = const Color(0xFFFFFFFF),
    required this.userBubble,
    required this.userBubbleText,
    required this.botBubble,
    required this.botBubbleText,
    required this.agentBubble,
    required this.agentBubbleText,
    required this.systemBubble,
    required this.systemBubbleText,
    this.optionBubble = const Color(0xFFF5F5F5),
    this.optionBubbleText = const Color(0xFF1C1B1F),
    required this.text,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.divider,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.online,
    required this.offline,
  });

  ConferBotColors copyWith({
    Color? primary,
    Color? secondary,
    Color? background,
    Color? surface,
    Color? headerBg,
    Color? headerText,
    Color? userBubble,
    Color? userBubbleText,
    Color? botBubble,
    Color? botBubbleText,
    Color? agentBubble,
    Color? agentBubbleText,
    Color? systemBubble,
    Color? systemBubbleText,
    Color? optionBubble,
    Color? optionBubbleText,
    Color? text,
    Color? textSecondary,
    Color? textDisabled,
    Color? border,
    Color? divider,
    Color? success,
    Color? error,
    Color? warning,
    Color? info,
    Color? online,
    Color? offline,
  }) {
    return ConferBotColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      headerBg: headerBg ?? this.headerBg,
      headerText: headerText ?? this.headerText,
      userBubble: userBubble ?? this.userBubble,
      userBubbleText: userBubbleText ?? this.userBubbleText,
      botBubble: botBubble ?? this.botBubble,
      botBubbleText: botBubbleText ?? this.botBubbleText,
      agentBubble: agentBubble ?? this.agentBubble,
      agentBubbleText: agentBubbleText ?? this.agentBubbleText,
      systemBubble: systemBubble ?? this.systemBubble,
      systemBubbleText: systemBubbleText ?? this.systemBubbleText,
      optionBubble: optionBubble ?? this.optionBubble,
      optionBubbleText: optionBubbleText ?? this.optionBubbleText,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      online: online ?? this.online,
      offline: offline ?? this.offline,
    );
  }
}

/// Typography configuration — matches Android SDK
class ConferBotTypography {
  final double fontSizeXs;
  final double fontSizeSm;
  final double fontSizeMd;
  final double fontSizeLg;
  final double fontSizeXl;
  final double fontSizeXxl;

  /// Message-specific font size (15sp on Android)
  final double messageSize;

  /// Timestamp font size (11sp on Android)
  final double timestampSize;

  final FontWeight fontWeightLight;
  final FontWeight fontWeightRegular;
  final FontWeight fontWeightMedium;
  final FontWeight fontWeightSemiBold;
  final FontWeight fontWeightBold;

  /// Message line height (1.4 on Android)
  final double lineHeightNormal;
  final double lineHeightRelaxed;

  const ConferBotTypography({
    this.fontSizeXs = 12.0,
    this.fontSizeSm = 14.0,
    this.fontSizeMd = 16.0,
    this.fontSizeLg = 18.0,
    this.fontSizeXl = 20.0,
    this.fontSizeXxl = 24.0,
    this.messageSize = 15.0,
    this.timestampSize = 11.0,
    this.fontWeightLight = FontWeight.w300,
    this.fontWeightRegular = FontWeight.w400,
    this.fontWeightMedium = FontWeight.w500,
    this.fontWeightSemiBold = FontWeight.w600,
    this.fontWeightBold = FontWeight.w700,
    this.lineHeightNormal = 1.4,
    this.lineHeightRelaxed = 1.75,
  });
}

/// Spacing values — matches Android SDK ConferbotSpacing
class ConferBotSpacing {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  /// Bubble padding (Android: 14h, 10v)
  final double bubblePaddingH;
  final double bubblePaddingV;

  /// Spacing between messages (Android: 10dp)
  final double messageSpacing;

  /// Spacing between grouped messages from same sender (Android: 2dp)
  final double groupedMessageSpacing;

  /// Chat content padding (Android: 14dp)
  final double chatContentPadding;

  const ConferBotSpacing({
    this.xs = 4.0,
    this.sm = 8.0,
    this.md = 12.0,
    this.lg = 16.0,
    this.xl = 24.0,
    this.xxl = 48.0,
    this.bubblePaddingH = 14.0,
    this.bubblePaddingV = 10.0,
    this.messageSpacing = 10.0,
    this.groupedMessageSpacing = 2.0,
    this.chatContentPadding = 14.0,
  });
}

/// Border radius values — matches Android SDK ConferbotShapes
class ConferBotBorderRadius {
  final double none;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;

  /// Bubble corner radius (Android: 16dp)
  final double bubble;

  /// Bubble small radius for squared corner (Android: 4dp)
  final double bubbleSmall;

  /// Button/card radius (Android: 12dp)
  final double button;

  /// Input field radius (Android: 24dp)
  final double input;

  const ConferBotBorderRadius({
    this.none = 0.0,
    this.sm = 4.0,
    this.md = 8.0,
    this.lg = 16.0,
    this.xl = 24.0,
    this.full = 9999.0,
    this.bubble = 16.0,
    this.bubbleSmall = 4.0,
    this.button = 12.0,
    this.input = 24.0,
  });
}

/// Shadow configurations
class ConferBotShadows {
  final BoxShadow none;
  final BoxShadow sm;
  final BoxShadow md;
  final BoxShadow lg;
  final BoxShadow xl;

  const ConferBotShadows({
    this.none = const BoxShadow(color: Colors.transparent),
    this.sm = const BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
    this.md = const BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    this.lg = const BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    this.xl = const BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  });
}

/// Animation durations and curves
class ConferBotAnimations {
  final Duration fast;
  final Duration normal;
  final Duration slow;
  final Curve easeIn;
  final Curve easeOut;
  final Curve easeInOut;

  /// Message fade duration (Android: 200ms)
  final Duration messageFade;

  /// Message slide duration (Android: 300ms)
  final Duration messageSlide;

  /// Button press duration (Android: 100ms)
  final Duration buttonPress;

  const ConferBotAnimations({
    this.fast = const Duration(milliseconds: 150),
    this.normal = const Duration(milliseconds: 300),
    this.slow = const Duration(milliseconds: 500),
    this.easeIn = Curves.easeIn,
    this.easeOut = Curves.easeOut,
    this.easeInOut = Curves.easeInOut,
    this.messageFade = const Duration(milliseconds: 200),
    this.messageSlide = const Duration(milliseconds: 300),
    this.buttonPress = const Duration(milliseconds: 100),
  });
}

/// Layout dimensions — matches Android SDK
class ConferBotLayout {
  /// Header height (Android: 56dp)
  final double headerHeight;
  final double inputHeight;

  /// Max message bubble width (Android: 260dp)
  final double maxBubbleWidth;

  /// Avatar size in messages (Android: 32dp)
  final double avatarSize;

  /// Small avatar (Android: 24dp)
  final double avatarSizeSmall;

  final double iconSize;

  const ConferBotLayout({
    this.headerHeight = 56.0,
    this.inputHeight = 48.0,
    this.maxBubbleWidth = 260.0,
    this.avatarSize = 32.0,
    this.avatarSizeSmall = 24.0,
    this.iconSize = 24.0,
  });
}
