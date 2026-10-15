/// User identification model
class ConferBotUser {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final Map<String, dynamic>? metadata;

  /// Identity verification: HMAC-SHA256 of the user's id (or email when there
  /// is no id) with your workspace's identity secret, hex, made on your
  /// server. With it the chat is filed under the verified user.
  final String? hash;

  const ConferBotUser({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.metadata,
    this.hash,
  });

  factory ConferBotUser.fromJson(Map<String, dynamic> json) {
    return ConferBotUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      hash: json['hash'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (metadata != null) 'metadata': metadata,
      if (hash != null) 'hash': hash,
    };
  }

  /// The user as the web widget's visitorContext: the app's own data, then id, name, email, phone, hash.
  Map<String, dynamic> toVisitorContext() {
    bool filled(String? v) => v != null && v.trim().isNotEmpty;
    return {
      ...?metadata,
      'id': id,
      if (filled(name)) 'name': name,
      if (filled(email)) 'email': email,
      if (filled(phone)) 'phone': phone,
      if (filled(hash)) 'hash': hash,
    };
  }
}

/// UI customization options
class ConferBotCustomization {
  final String? primaryColor;
  final String? fontFamily;
  final double? bubbleRadius;
  final String? headerTitle;
  final bool? enableAvatar;
  final String? avatarUrl;
  final String? botBubbleColor;
  final String? userBubbleColor;

  const ConferBotCustomization({
    this.primaryColor,
    this.fontFamily,
    this.bubbleRadius,
    this.headerTitle,
    this.enableAvatar,
    this.avatarUrl,
    this.botBubbleColor,
    this.userBubbleColor,
  });

  factory ConferBotCustomization.fromJson(Map<String, dynamic> json) {
    return ConferBotCustomization(
      primaryColor: json['primaryColor'] as String?,
      fontFamily: json['fontFamily'] as String?,
      bubbleRadius: json['bubbleRadius'] as double?,
      headerTitle: json['headerTitle'] as String?,
      enableAvatar: json['enableAvatar'] as bool?,
      avatarUrl: json['avatarUrl'] as String?,
      botBubbleColor: json['botBubbleColor'] as String?,
      userBubbleColor: json['userBubbleColor'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (primaryColor != null) 'primaryColor': primaryColor,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (bubbleRadius != null) 'bubbleRadius': bubbleRadius,
      if (headerTitle != null) 'headerTitle': headerTitle,
      if (enableAvatar != null) 'enableAvatar': enableAvatar,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (botBubbleColor != null) 'botBubbleColor': botBubbleColor,
      if (userBubbleColor != null) 'userBubbleColor': userBubbleColor,
    };
  }
}
