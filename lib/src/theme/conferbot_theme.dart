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

/// Theme colors
class ConferBotColors {
  // Primary colors
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;

  // Message bubble colors
  final Color userBubble;
  final Color userBubbleText;
  final Color botBubble;
  final Color botBubbleText;
  final Color agentBubble;
  final Color agentBubbleText;
  final Color systemBubble;
  final Color systemBubbleText;

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
    required this.userBubble,
    required this.userBubbleText,
    required this.botBubble,
    required this.botBubbleText,
    required this.agentBubble,
    required this.agentBubbleText,
    required this.systemBubble,
    required this.systemBubbleText,
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
}

/// Typography configuration
class ConferBotTypography {
  final double fontSizeXs;
  final double fontSizeSm;
  final double fontSizeMd;
  final double fontSizeLg;
  final double fontSizeXl;
  final double fontSizeXxl;

  final FontWeight fontWeightLight;
  final FontWeight fontWeightRegular;
  final FontWeight fontWeightMedium;
  final FontWeight fontWeightSemiBold;
  final FontWeight fontWeightBold;

  final double lineHeightNormal;
  final double lineHeightRelaxed;

  const ConferBotTypography({
    this.fontSizeXs = 12.0,
    this.fontSizeSm = 14.0,
    this.fontSizeMd = 16.0,
    this.fontSizeLg = 18.0,
    this.fontSizeXl = 20.0,
    this.fontSizeXxl = 24.0,
    this.fontWeightLight = FontWeight.w300,
    this.fontWeightRegular = FontWeight.w400,
    this.fontWeightMedium = FontWeight.w500,
    this.fontWeightSemiBold = FontWeight.w600,
    this.fontWeightBold = FontWeight.w700,
    this.lineHeightNormal = 1.5,
    this.lineHeightRelaxed = 1.75,
  });
}

/// Spacing values
class ConferBotSpacing {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  const ConferBotSpacing({
    this.xs = 4.0,
    this.sm = 8.0,
    this.md = 16.0,
    this.lg = 24.0,
    this.xl = 32.0,
    this.xxl = 48.0,
  });
}

/// Border radius values
class ConferBotBorderRadius {
  final double none;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;

  const ConferBotBorderRadius({
    this.none = 0.0,
    this.sm = 4.0,
    this.md = 8.0,
    this.lg = 16.0,
    this.xl = 24.0,
    this.full = 9999.0,
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

  const ConferBotAnimations({
    this.fast = const Duration(milliseconds: 150),
    this.normal = const Duration(milliseconds: 300),
    this.slow = const Duration(milliseconds: 500),
    this.easeIn = Curves.easeIn,
    this.easeOut = Curves.easeOut,
    this.easeInOut = Curves.easeInOut,
  });
}

/// Layout dimensions
class ConferBotLayout {
  final double headerHeight;
  final double inputHeight;
  final double maxBubbleWidth;
  final double avatarSize;
  final double iconSize;

  const ConferBotLayout({
    this.headerHeight = 60.0,
    this.inputHeight = 56.0,
    this.maxBubbleWidth = 280.0,
    this.avatarSize = 40.0,
    this.iconSize = 24.0,
  });
}
