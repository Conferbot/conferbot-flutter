import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../theme/conferbot_theme.dart';
import '../../theme/default_theme.dart';

/// Configuration for the image viewer
class ImageViewerConfig {
  /// Minimum scale for zoom
  final double minScale;

  /// Maximum scale for zoom
  final double maxScale;

  /// Initial scale
  final double initialScale;

  /// Enable double tap to zoom
  final bool enableDoubleTapZoom;

  /// Enable swipe to dismiss
  final bool enableSwipeToDismiss;

  /// Background color
  final Color backgroundColor;

  /// Animation duration for transitions
  final Duration animationDuration;

  const ImageViewerConfig({
    this.minScale = 0.5,
    this.maxScale = 4.0,
    this.initialScale = 1.0,
    this.enableDoubleTapZoom = true,
    this.enableSwipeToDismiss = true,
    this.backgroundColor = Colors.black,
    this.animationDuration = const Duration(milliseconds: 200),
  });
}

/// Image item for gallery view
class ImageItem {
  /// Image URL
  final String url;

  /// Optional caption
  final String? caption;

  /// Optional hero tag for animation
  final String? heroTag;

  const ImageItem({
    required this.url,
    this.caption,
    this.heroTag,
  });
}

/// Thumbnail widget with tap to open full screen viewer
class ImageThumbnail extends StatelessWidget {
  /// Image URL
  final String imageUrl;

  /// Optional caption
  final String? caption;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Maximum height constraint
  final double maxHeight;

  /// Border radius
  final double? borderRadius;

  /// Hero tag for animation
  final String? heroTag;

  /// Callback when image is tapped
  final VoidCallback? onTap;

  /// Whether to show full screen on tap
  final bool openFullScreenOnTap;

  /// List of images for gallery (if viewing multiple)
  final List<ImageItem>? galleryImages;

  /// Initial index in gallery
  final int initialGalleryIndex;

  const ImageThumbnail({
    super.key,
    required this.imageUrl,
    this.caption,
    this.theme,
    this.maxHeight = 300,
    this.borderRadius,
    this.heroTag,
    this.onTap,
    this.openFullScreenOnTap = true,
    this.galleryImages,
    this.initialGalleryIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;
    final effectiveBorderRadius = borderRadius ?? effectiveTheme.borderRadius.lg;
    final effectiveHeroTag = heroTag ?? 'image_$imageUrl';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            onTap?.call();
            if (openFullScreenOnTap) {
              _openFullScreen(context, effectiveHeroTag);
            }
          },
          child: Hero(
            tag: effectiveHeroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(effectiveBorderRadius),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  placeholder: (context, url) => _buildPlaceholder(effectiveTheme),
                  errorWidget: (context, url, error) => _buildError(effectiveTheme),
                  fadeInDuration: effectiveTheme.animations.fast,
                ),
              ),
            ),
          ),
        ),
        if (caption != null && caption!.isNotEmpty) ...[
          SizedBox(height: effectiveTheme.spacing.xs),
          Text(
            caption!,
            style: TextStyle(
              fontSize: effectiveTheme.typography.fontSizeSm,
              color: effectiveTheme.colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceholder(ConferBotTheme theme) {
    return Container(
      height: 200,
      color: theme.colors.surface,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(theme.colors.primary),
        ),
      ),
    );
  }

  Widget _buildError(ConferBotTheme theme) {
    return Container(
      height: 200,
      color: theme.colors.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: theme.colors.textSecondary,
          ),
          SizedBox(height: theme.spacing.sm),
          Text(
            'Failed to load image',
            style: TextStyle(
              fontSize: theme.typography.fontSizeSm,
              color: theme.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context, String heroTag) {
    final images = galleryImages ??
        [ImageItem(url: imageUrl, caption: caption, heroTag: heroTag)];

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenImageViewer(
            images: images,
            initialIndex: initialGalleryIndex,
            heroTag: heroTag,
            theme: theme,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }
}

/// Full screen image viewer with zoom, pan, and gallery support
class FullScreenImageViewer extends StatefulWidget {
  /// List of images to display
  final List<ImageItem> images;

  /// Initial index
  final int initialIndex;

  /// Hero tag for animation
  final String? heroTag;

  /// Viewer configuration
  final ImageViewerConfig config;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Callback when viewer is closed
  final VoidCallback? onClose;

  const FullScreenImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.heroTag,
    this.config = const ImageViewerConfig(),
    this.theme,
    this.onClose,
  });

  /// Show full screen image viewer
  static Future<void> show(
    BuildContext context, {
    required List<ImageItem> images,
    int initialIndex = 0,
    String? heroTag,
    ImageViewerConfig config = const ImageViewerConfig(),
    ConferBotTheme? theme,
    VoidCallback? onClose,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenImageViewer(
            images: images,
            initialIndex: initialIndex,
            heroTag: heroTag,
            config: config,
            theme: theme,
            onClose: onClose,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late AnimationController _fadeController;

  // For swipe to dismiss
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.config.animationDuration,
    );

    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _close() {
    widget.onClose?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? defaultTheme;
    final hasMultipleImages = widget.images.length > 1;
    final currentImage = widget.images[_currentIndex];

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onVerticalDragStart: widget.config.enableSwipeToDismiss
            ? (_) => setState(() => _isDragging = true)
            : null,
        onVerticalDragUpdate: widget.config.enableSwipeToDismiss
            ? (details) {
                setState(() {
                  _dragOffset += details.delta.dy;
                });
              }
            : null,
        onVerticalDragEnd: widget.config.enableSwipeToDismiss
            ? (details) {
                if (_dragOffset.abs() > 100 ||
                    details.velocity.pixelsPerSecond.dy.abs() > 500) {
                  _close();
                } else {
                  setState(() {
                    _dragOffset = 0;
                    _isDragging = false;
                  });
                }
              }
            : null,
        child: AnimatedContainer(
          duration: _isDragging
              ? Duration.zero
              : widget.config.animationDuration,
          transform: Matrix4.translationValues(0, _dragOffset, 0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background with opacity based on drag
              AnimatedContainer(
                duration: _isDragging
                    ? Duration.zero
                    : widget.config.animationDuration,
                color: widget.config.backgroundColor
                    .withOpacity((1 - (_dragOffset.abs() / 300)).clamp(0.5, 1.0)),
              ),

              // Image gallery
              if (hasMultipleImages)
                PhotoViewGallery.builder(
                  pageController: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  builder: (context, index) {
                    final image = widget.images[index];
                    return PhotoViewGalleryPageOptions(
                      imageProvider: CachedNetworkImageProvider(image.url),
                      minScale: PhotoViewComputedScale.contained * widget.config.minScale,
                      maxScale: PhotoViewComputedScale.covered * widget.config.maxScale,
                      initialScale: PhotoViewComputedScale.contained * widget.config.initialScale,
                      heroAttributes: image.heroTag != null
                          ? PhotoViewHeroAttributes(tag: image.heroTag!)
                          : null,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildError(effectiveTheme);
                      },
                    );
                  },
                  loadingBuilder: (context, event) {
                    return _buildLoading(effectiveTheme, event);
                  },
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  scrollPhysics: const BouncingScrollPhysics(),
                )
              else
                PhotoView(
                  imageProvider: CachedNetworkImageProvider(currentImage.url),
                  minScale: PhotoViewComputedScale.contained * widget.config.minScale,
                  maxScale: PhotoViewComputedScale.covered * widget.config.maxScale,
                  initialScale: PhotoViewComputedScale.contained * widget.config.initialScale,
                  heroAttributes: widget.heroTag != null
                      ? PhotoViewHeroAttributes(tag: widget.heroTag!)
                      : null,
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  loadingBuilder: (context, event) {
                    return _buildLoading(effectiveTheme, event);
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _buildError(effectiveTheme);
                  },
                  enableRotation: false,
                  onTapUp: widget.config.enableDoubleTapZoom
                      ? null
                      : (_, __, ___) => _close(),
                ),

              // Close button
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 8,
                child: _buildCloseButton(effectiveTheme),
              ),

              // Page indicator for gallery
              if (hasMultipleImages)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 0,
                  right: 0,
                  child: _buildPageIndicator(effectiveTheme),
                ),

              // Caption
              if (currentImage.caption != null && currentImage.caption!.isNotEmpty)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom +
                      (hasMultipleImages ? 56 : 16),
                  left: 16,
                  right: 16,
                  child: _buildCaption(currentImage.caption!, effectiveTheme),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(ConferBotTheme theme, ImageChunkEvent? event) {
    final progress = event == null || event.expectedTotalBytes == null
        ? null
        : event.cumulativeBytesLoaded / event.expectedTotalBytes!;

    return Center(
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 2,
        valueColor: const AlwaysStoppedAnimation(Colors.white),
      ),
    );
  }

  Widget _buildError(ConferBotTheme theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load image',
            style: TextStyle(
              fontSize: theme.typography.fontSizeMd,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(ConferBotTheme theme) {
    return GestureDetector(
      onTap: _close,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(theme.borderRadius.full),
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildPageIndicator(ConferBotTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.images.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == _currentIndex
                    ? Colors.white
                    : Colors.white38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Counter
        Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: TextStyle(
            fontSize: theme.typography.fontSizeSm,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildCaption(String caption, ConferBotTheme theme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(theme.borderRadius.md),
      ),
      child: Text(
        caption,
        style: TextStyle(
          fontSize: theme.typography.fontSizeSm,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Simple image preview widget for inline display
class ImagePreview extends StatelessWidget {
  /// Image URL
  final String imageUrl;

  /// Optional caption
  final String? caption;

  /// Theme configuration
  final ConferBotTheme? theme;

  /// Width constraint
  final double? width;

  /// Height constraint
  final double? height;

  /// Border radius
  final BorderRadius? borderRadius;

  /// Fit mode
  final BoxFit fit;

  /// Whether to show loading indicator
  final bool showLoading;

  /// Whether to enable tap to view full screen
  final bool enableFullScreen;

  const ImagePreview({
    super.key,
    required this.imageUrl,
    this.caption,
    this.theme,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showLoading = true,
    this.enableFullScreen = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? defaultTheme;

    return ImageThumbnail(
      imageUrl: imageUrl,
      caption: caption,
      theme: effectiveTheme,
      maxHeight: height ?? 300,
      borderRadius: borderRadius?.topLeft.x ?? effectiveTheme.borderRadius.lg,
      openFullScreenOnTap: enableFullScreen,
    );
  }
}
