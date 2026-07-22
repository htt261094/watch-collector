import 'dart:io';

import 'package:flutter/material.dart';

import 'package:watch_collection/features/collection/presentation/photo_gallery_page.dart';

/// A large-image gallery grid for a watch's photos (issue #25).
///
/// Photos are laid out as generously sized, rounded, square tiles — image-first,
/// since the collection is a visual hobby. Tapping a tile opens the full-screen
/// viewer with a smooth Hero transition (swipe between photos, pinch- and
/// double-tap-to-zoom). A placeholder is shown when there are no photos.
class WatchPhotoGrid extends StatelessWidget {
  const WatchPhotoGrid({super.key, required this.imagePaths});

  /// Absolute file paths of the photos to display, in gallery order.
  final List<String> imagePaths;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (imagePaths.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.watch_outlined,
          size: 64,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    // Two large tiles per row on phones, more as width allows.
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width ~/ 240 < 2 ? 2 : width ~/ 240;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: imagePaths.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) => _PhotoTile(
        path: imagePaths[index],
        onTap: () => Navigator.of(context).push(
          photoGalleryRoute(imagePaths: imagePaths, initialIndex: index),
        ),
      ),
    );
  }
}

/// A single rounded, tappable photo tile carrying the shared Hero tag.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, required this.onTap});

  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Hero(
          tag: photoHeroTag(path),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (context, _, __) => Container(
              color: scheme.surfaceContainerHighest,
              child: Icon(
                Icons.broken_image_outlined,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
