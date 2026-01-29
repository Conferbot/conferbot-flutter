import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handler for various link types in markdown content
/// Supports URLs, email, phone, and custom deep links
class MarkdownLinkHandler {
  /// Callback for deep link navigation within the app
  final void Function(String path)? onDeepLink;

  /// Callback for analytics tracking when links are tapped
  final void Function(String url, LinkType type)? onLinkTapped;

  /// Custom URL schemes that should be handled as deep links
  final List<String> deepLinkSchemes;

  /// Whether to show confirmation before opening external links
  final bool confirmExternalLinks;

  /// Custom handler for specific URL patterns
  final Future<bool> Function(String url)? customHandler;

  const MarkdownLinkHandler({
    this.onDeepLink,
    this.onLinkTapped,
    this.deepLinkSchemes = const ['app', 'conferbot'],
    this.confirmExternalLinks = false,
    this.customHandler,
  });

  /// Handle a link tap
  Future<void> handleLink(BuildContext context, String url) async {
    final linkType = _detectLinkType(url);

    // Track link tap
    onLinkTapped?.call(url, linkType);

    // Try custom handler first
    if (customHandler != null) {
      final handled = await customHandler!(url);
      if (handled) return;
    }

    switch (linkType) {
      case LinkType.email:
        await _handleEmailLink(context, url);
        break;
      case LinkType.phone:
        await _handlePhoneLink(context, url);
        break;
      case LinkType.sms:
        await _handleSmsLink(context, url);
        break;
      case LinkType.deepLink:
        _handleDeepLink(context, url);
        break;
      case LinkType.externalUrl:
        await _handleExternalUrl(context, url);
        break;
      case LinkType.internalAnchor:
        // Internal anchors are typically handled differently
        break;
    }
  }

  /// Detect the type of link
  LinkType _detectLinkType(String url) {
    final lowerUrl = url.toLowerCase();

    if (lowerUrl.startsWith('mailto:')) {
      return LinkType.email;
    }

    if (lowerUrl.startsWith('tel:')) {
      return LinkType.phone;
    }

    if (lowerUrl.startsWith('sms:')) {
      return LinkType.sms;
    }

    if (lowerUrl.startsWith('#')) {
      return LinkType.internalAnchor;
    }

    // Check for custom deep link schemes
    for (final scheme in deepLinkSchemes) {
      if (lowerUrl.startsWith('$scheme:') ||
          lowerUrl.startsWith('$scheme://')) {
        return LinkType.deepLink;
      }
    }

    return LinkType.externalUrl;
  }

  /// Handle email links (mailto:)
  Future<void> _handleEmailLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Could not open email app');
      }
    }
  }

  /// Handle phone links (tel:)
  Future<void> _handlePhoneLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Could not open phone app');
      }
    }
  }

  /// Handle SMS links (sms:)
  Future<void> _handleSmsLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Could not open messaging app');
      }
    }
  }

  /// Handle deep links to app sections
  void _handleDeepLink(BuildContext context, String url) {
    // Extract path from deep link URL
    final uri = Uri.parse(url);
    final path = uri.path.isNotEmpty ? uri.path : uri.host;

    if (onDeepLink != null) {
      onDeepLink!(path);
    } else {
      // Default: try to navigate using Navigator
      try {
        Navigator.of(context).pushNamed(path);
      } catch (e) {
        _showErrorSnackBar(context, 'Could not navigate to $path');
      }
    }
  }

  /// Handle external URLs
  Future<void> _handleExternalUrl(BuildContext context, String url) async {
    // Ensure URL has a scheme
    String normalizedUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      normalizedUrl = 'https://$url';
    }

    final uri = Uri.parse(normalizedUrl);

    // Show confirmation dialog if enabled
    if (confirmExternalLinks && context.mounted) {
      final confirmed = await _showExternalLinkConfirmation(context, uri.host);
      if (!confirmed) return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Could not open link');
      }
    }
  }

  /// Show confirmation dialog for external links
  Future<bool> _showExternalLinkConfirmation(
    BuildContext context,
    String host,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open External Link'),
        content: Text('Do you want to open $host in your browser?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show error snackbar
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Parse email address from mailto link
  static String? parseEmailAddress(String url) {
    if (!url.toLowerCase().startsWith('mailto:')) return null;

    final uri = Uri.parse(url);
    return uri.path;
  }

  /// Parse phone number from tel link
  static String? parsePhoneNumber(String url) {
    if (!url.toLowerCase().startsWith('tel:')) return null;

    return url.substring(4); // Remove 'tel:'
  }

  /// Create a mailto URL
  static String createMailtoUrl({
    required String email,
    String? subject,
    String? body,
    List<String>? cc,
    List<String>? bcc,
  }) {
    final params = <String, String>{};
    if (subject != null) params['subject'] = subject;
    if (body != null) params['body'] = body;
    if (cc != null && cc.isNotEmpty) params['cc'] = cc.join(',');
    if (bcc != null && bcc.isNotEmpty) params['bcc'] = bcc.join(',');

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: params.isNotEmpty ? params : null,
    );
    return uri.toString();
  }

  /// Create a tel URL
  static String createTelUrl(String phoneNumber) {
    // Remove spaces and common separators for the URL
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return 'tel:$cleanNumber';
  }

  /// Create an SMS URL
  static String createSmsUrl(String phoneNumber, {String? body}) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (body != null) {
      return 'sms:$cleanNumber?body=${Uri.encodeComponent(body)}';
    }
    return 'sms:$cleanNumber';
  }
}

/// Types of links that can be handled
enum LinkType {
  /// mailto: links for email
  email,

  /// tel: links for phone calls
  phone,

  /// sms: links for text messages
  sms,

  /// Custom deep links (app://, conferbot://, etc.)
  deepLink,

  /// External http/https URLs
  externalUrl,

  /// Internal anchor links (#section)
  internalAnchor,
}

/// Widget that wraps content and handles link taps
class LinkHandlerScope extends InheritedWidget {
  final MarkdownLinkHandler handler;

  const LinkHandlerScope({
    super.key,
    required this.handler,
    required super.child,
  });

  static MarkdownLinkHandler? of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LinkHandlerScope>();
    return scope?.handler;
  }

  @override
  bool updateShouldNotify(LinkHandlerScope oldWidget) {
    return handler != oldWidget.handler;
  }
}
