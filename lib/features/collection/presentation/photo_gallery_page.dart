import 'dart:io';

import 'package:flutter/material.dart';

/// Hero tag for a photo at [path], shared between the grid thumbnail and the
/// full-screen viewer so tapping one animates smoothly into the other.
///
/// File paths are unique per photo, which keeps tags unique on any one screen.
String photoHeroTag(String path) => 'watch-photo:$path';

/// A route that fades the full-screen gallery in over the current screen, so the
/// Hero flight reads against a darkening backdrop rather than a hard cut.
Route<void> photoGalleryRoute({
  required List<String> imagePaths,
  int initialIndex = 0,
}) {
  return PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => PhotoGalleryPage(
      imagePaths: imagePaths,
      initialIndex: initialIndex,
    ),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: child,
    ),
  );
}

/// Full-screen, swipeable photo viewer (issues #4, #25).
///
/// Shows a watch's photos large on a black backdrop, one per page. Each photo
/// supports pinch-to-zoom, double-tap-to-zoom, and pan; swiping moves between
/// photos. Opened from a thumbnail via [photoGalleryRoute] so the tapped photo
/// flies into place with a Hero transition.
class PhotoGalleryPage extends StatefulWidget {
  const PhotoGalleryPage({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  /// Absolute file paths of the images to display, in order.
  final List<String> imagePaths;

  /// Page to open on first.
  final int initialIndex;

  @override
  State<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imagePaths.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.imagePaths.length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_index + 1} / $count'),
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _controller,
        itemCount: count,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, index) {
          return _ZoomableImage(path: widget.imagePaths[index]);
        },
      ),
    );
  }
}

/// A single full-screen image with pinch-, pan-, and animated double-tap-zoom.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.path});

  final String path;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  static const double _zoomedScale = 2.5;

  final TransformationController _transform = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        final animation = _animation;
        if (animation != null) _transform.value = animation.value;
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    _transform.dispose();
    super.dispose();
  }

  /// Toggle between fit-to-screen and zoomed-in, centred on the tap point.
  void _handleDoubleTap() {
    final Matrix4 end;
    if (_transform.value != Matrix4.identity()) {
      end = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      end = Matrix4.identity()
        ..translateByDouble(
          -position.dx * (_zoomedScale - 1),
          -position.dy * (_zoomedScale - 1),
          0,
          1,
        )
        ..scaleByDouble(_zoomedScale, _zoomedScale, _zoomedScale, 1);
    }
    _animation = Matrix4Tween(begin: _transform.value, end: end).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Hero(
            tag: photoHeroTag(widget.path),
            child: Image.file(
              File(widget.path),
              fit: BoxFit.contain,
              errorBuilder: (context, _, __) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
