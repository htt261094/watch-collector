import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:watch_collection/core/util/id_generator.dart';
import 'package:watch_collection/features/collection/domain/watch_photo.dart';
import 'package:watch_collection/features/collection/domain/watch_photo_repository.dart';
import 'package:watch_collection/features/collection/presentation/photo_gallery_page.dart';

/// Editable photo gallery embedded in the watch form (issue #4).
///
/// Owns the working set of photos while the form is open: add from camera or
/// gallery, remove, reorder-by-pick, choose the thumbnail, and tap to view
/// full-screen. It reports the desired final state to the parent as a list of
/// [PhotoDraft]s via [onChanged]; the parent persists them on Save. Nothing is
/// written to storage until then.
class PhotoGalleryEditor extends StatefulWidget {
  const PhotoGalleryEditor({
    super.key,
    required this.initialPhotos,
    required this.onChanged,
    this.picker,
  });

  /// Photos already stored for the watch (empty in add mode).
  final List<WatchPhoto> initialPhotos;

  /// Emits the current desired gallery whenever it changes.
  final ValueChanged<List<PhotoDraft>> onChanged;

  /// Injectable for tests; defaults to the platform [ImagePicker].
  final ImagePicker? picker;

  @override
  State<PhotoGalleryEditor> createState() => _PhotoGalleryEditorState();
}

/// One entry in the working gallery — either an already-stored photo or a
/// freshly picked file not yet imported.
class _Item {
  _Item.existing(WatchPhoto photo)
      : localId = photo.id,
        existingId = photo.id,
        sourcePath = null,
        displayPath = photo.filePath,
        isThumbnail = photo.isThumbnail;

  _Item.picked(String sourcePath)
      : localId = IdGenerator.newId(),
        existingId = null,
        sourcePath = sourcePath,
        displayPath = sourcePath,
        isThumbnail = false;

  /// Stable key for widget identity within the list.
  final String localId;

  /// Non-null when this entry is an already-stored photo.
  final String? existingId;

  /// Non-null when this entry is a newly picked file.
  final String? sourcePath;

  /// Path to render right now (stored path or picker temp path).
  final String displayPath;

  bool isThumbnail;
}

class _PhotoGalleryEditorState extends State<PhotoGalleryEditor> {
  late List<_Item> _items;
  late final ImagePicker _picker;

  @override
  void initState() {
    super.initState();
    _picker = widget.picker ?? ImagePicker();
    _items = [for (final p in widget.initialPhotos) _Item.existing(p)];
    _ensureThumbnail();
  }

  /// Guarantee exactly one thumbnail when the gallery is non-empty.
  void _ensureThumbnail() {
    if (_items.isEmpty) return;
    if (!_items.any((i) => i.isThumbnail)) {
      _items.first.isThumbnail = true;
    }
  }

  void _emit() {
    widget.onChanged([
      for (final item in _items)
        if (item.existingId != null)
          ExistingPhoto(id: item.existingId!, isThumbnail: item.isThumbnail)
        else
          NewPhoto(sourcePath: item.sourcePath!, isThumbnail: item.isThumbnail),
    ]);
  }

  Future<void> _addFrom(ImageSource source) async {
    try {
      final added = <_Item>[];
      if (source == ImageSource.camera) {
        final shot = await _picker.pickImage(source: ImageSource.camera);
        if (shot != null) added.add(_Item.picked(shot.path));
      } else {
        final shots = await _picker.pickMultiImage();
        added.addAll(shots.map((x) => _Item.picked(x.path)));
      }
      if (added.isEmpty) return;
      setState(() {
        _items.addAll(added);
        _ensureThumbnail();
      });
      _emit();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add photo: $error')),
      );
    }
  }

  void _remove(_Item item) {
    setState(() {
      _items.removeWhere((i) => i.localId == item.localId);
      // If the thumbnail was removed, promote the new first photo.
      if (item.isThumbnail) _ensureThumbnail();
    });
    _emit();
  }

  void _setThumbnail(_Item item) {
    setState(() {
      for (final i in _items) {
        i.isThumbnail = identical(i, item);
      }
    });
    _emit();
  }

  Future<void> _pickSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _addFrom(source);
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      photoGalleryRoute(
        imagePaths: [for (final i in _items) i.displayPath],
        initialIndex: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_items.isEmpty)
          Text(
            'No photos yet.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _PhotoTile(
                path: item.displayPath,
                isThumbnail: item.isThumbnail,
                onTap: () => _openViewer(index),
                onRemove: () => _remove(item),
                onSetThumbnail: () => _setThumbnail(item),
              );
            },
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickSource,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Add photo'),
        ),
      ],
    );
  }
}

/// A single gallery cell: the image, a thumbnail badge/toggle, and a remove
/// button.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.path,
    required this.isThumbnail,
    required this.onTap,
    required this.onRemove,
    required this.onSetThumbnail,
  });

  final String path;
  final bool isThumbnail;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onSetThumbnail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: isThumbnail
                    ? Border.all(color: scheme.primary, width: 3)
                    : null,
              ),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
          // Thumbnail toggle (bottom-left).
          Positioned(
            left: 2,
            bottom: 2,
            child: _CircleButton(
              icon: isThumbnail ? Icons.star : Icons.star_border,
              tooltip: isThumbnail ? 'Thumbnail' : 'Set as thumbnail',
              color: isThumbnail ? Colors.amber : Colors.white,
              onPressed: onSetThumbnail,
            ),
          ),
          // Remove (top-right).
          Positioned(
            right: 2,
            top: 2,
            child: _CircleButton(
              icon: Icons.close,
              tooltip: 'Remove',
              color: Colors.white,
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
