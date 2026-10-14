import 'package:flutter/material.dart';
import '../theme/conferbot_theme.dart';
import '../theme/default_theme.dart';

/// Avatar widget displaying user/agent profile picture with initials fallback
class ConferBotAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final AvatarShape shape;
  final ConferBotTheme? theme;

  const ConferBotAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40.0,
    this.shape = AvatarShape.circle,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // An image (often a transparent logo) sits on nothing; initials on the brand colour.
        color: imageUrl != null ? Colors.transparent : effectiveTheme.colors.primary,
        borderRadius: _getBorderRadius(),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl == null
          ? Center(
              child: Text(
                _getInitials(name),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.4,
                  fontWeight: effectiveTheme.typography.fontWeightMedium,
                ),
              ),
            )
          : null,
    );
  }

  BorderRadius? _getBorderRadius() {
    switch (shape) {
      case AvatarShape.circle:
        return BorderRadius.circular(size / 2);
      // The web's avatar shapes: square 4, rounded 28%.
      case AvatarShape.square:
        return BorderRadius.circular(4);
      case AvatarShape.rounded:
        return BorderRadius.circular((size * 0.28).roundToDouble());
    }
  }

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) {
      return '?';
    }

    final names = fullName.trim().split(' ');
    if (names.length == 1) {
      return names[0][0].toUpperCase();
    }

    return (names[0][0] + names[names.length - 1][0]).toUpperCase();
  }
}

enum AvatarShape {
  circle,
  square,
  rounded,
}
