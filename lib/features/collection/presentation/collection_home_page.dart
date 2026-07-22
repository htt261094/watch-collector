import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/watch_form_page.dart';

/// Landing screen: the collection as a photo gallery (issue #5).
///
/// Watches are shown as large image cards in a responsive grid. A prominent
/// per-card "wear today" toggle records that the watch was worn today; watches
/// worn today are surfaced both by a badge on their card and by a strip at the
/// top of the screen. A floating action button opens the Add form; tapping a
/// card opens Edit; a card overflow menu edits or deletes (issue #3).
class CollectionHomePage extends ConsumerWidget {
  const CollectionHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watches = ref.watch(watchListProvider);
    // Thumbnails and the worn-today set load independently; treat an
    // error/loading state as "not available yet" so the gallery still renders.
    final thumbnails =
        ref.watch(watchThumbnailsProvider).valueOrNull ?? const {};
    final wornToday =
        ref.watch(watchesWornTodayProvider).valueOrNull ?? const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Collection'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add watch'),
      ),
      body: watches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Something went wrong:\n$error'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyState();
          }
          return _Gallery(
            watches: items,
            thumbnails: thumbnails,
            wornToday: wornToday,
            onOpen: (watch) => _openForm(context, watch: watch),
            onEdit: (watch) => _openForm(context, watch: watch),
            onDelete: (watch) => _confirmDelete(context, ref, watch),
            onToggleWorn: (watch) =>
                _toggleWorn(context, ref, watch, wornToday.contains(watch.id)),
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {Watch? watch}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WatchFormPage(watch: watch)),
    );
  }

  Future<void> _toggleWorn(
    BuildContext context,
    WidgetRef ref,
    Watch watch,
    bool currentlyWorn,
  ) async {
    final repository = ref.read(wearLogRepositoryProvider);
    final today = DateTime.now();
    if (currentlyWorn) {
      await repository.removeWear(watch.id, today);
    } else {
      await repository.logWear(watch.id, today);
    }
    ref.invalidate(watchesWornTodayProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            currentlyWorn
                ? 'Unmarked ${watch.brand} ${watch.model} as worn today'
                : 'Wearing ${watch.brand} ${watch.model} today',
          ),
        ),
      );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Watch watch,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete watch?'),
        content: Text(
          'Remove "${watch.brand} ${watch.model}" from your collection? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Remove the watch (rows cascade) and its photo files, then refresh.
    await ref.read(watchRepositoryProvider).deleteWatch(watch.id);
    await ref.read(watchPhotoRepositoryProvider).deletePhotosForWatch(watch.id);
    ref.invalidate(watchListProvider);
    ref.invalidate(watchThumbnailsProvider);
    ref.invalidate(watchesWornTodayProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${watch.brand} ${watch.model}')),
    );
  }
}

/// Scrollable gallery: an optional "worn today" strip followed by the grid of
/// watch cards.
class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.watches,
    required this.thumbnails,
    required this.wornToday,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleWorn,
  });

  final List<Watch> watches;
  final Map<String, String> thumbnails;
  final Set<String> wornToday;
  final ValueChanged<Watch> onOpen;
  final ValueChanged<Watch> onEdit;
  final ValueChanged<Watch> onDelete;
  final ValueChanged<Watch> onToggleWorn;

  @override
  Widget build(BuildContext context) {
    final wornWatches =
        watches.where((w) => wornToday.contains(w.id)).toList();

    // Two columns on phones, more on wider screens.
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width ~/ 220 < 2 ? 2 : width ~/ 220;

    return CustomScrollView(
      slivers: [
        if (wornWatches.isNotEmpty)
          SliverToBoxAdapter(
            child: _WornTodayStrip(
              watches: wornWatches,
              thumbnails: thumbnails,
              onTap: onOpen,
            ),
          ),
        SliverPadding(
          // Leave room so the FAB doesn't cover the last row.
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final watch = watches[index];
                return _WatchCard(
                  watch: watch,
                  thumbnailPath: thumbnails[watch.id],
                  wornToday: wornToday.contains(watch.id),
                  onOpen: () => onOpen(watch),
                  onEdit: () => onEdit(watch),
                  onDelete: () => onDelete(watch),
                  onToggleWorn: () => onToggleWorn(watch),
                );
              },
              childCount: watches.length,
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal strip of the watches worn today, shown above the grid.
class _WornTodayStrip extends StatelessWidget {
  const _WornTodayStrip({
    required this.watches,
    required this.thumbnails,
    required this.onTap,
  });

  final List<Watch> watches;
  final Map<String, String> thumbnails;
  final ValueChanged<Watch> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Worn today',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: watches.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final watch = watches[index];
                return _WornAvatar(
                  watch: watch,
                  thumbnailPath: thumbnails[watch.id],
                  onTap: () => onTap(watch),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A single circular thumbnail + brand label used in the "worn today" strip.
class _WornAvatar extends StatelessWidget {
  const _WornAvatar({
    required this.watch,
    required this.thumbnailPath,
    required this.onTap,
  });

  final Watch watch;
  final String? thumbnailPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final path = thumbnailPath;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: path != null ? FileImage(File(path)) : null,
              onBackgroundImageError: path != null ? (_, __) {} : null,
              child: path == null ? const Icon(Icons.watch_outlined) : null,
            ),
            const SizedBox(height: 4),
            Text(
              watch.brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// A gallery card: large photo, name, and a prominent wear-today toggle.
class _WatchCard extends StatelessWidget {
  const _WatchCard({
    required this.watch,
    required this.thumbnailPath,
    required this.wornToday,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleWorn,
  });

  final Watch watch;
  final String? thumbnailPath;
  final bool wornToday;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleWorn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CardImage(thumbnailPath: thumbnailPath),
                  if (wornToday)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _WornBadge(),
                    ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _CardMenu(onEdit: onEdit, onDelete: onDelete),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    watch.brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    watch.model,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _WearButton(worn: wornToday, onPressed: onToggleWorn),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The large image (or fallback) at the top of a watch card.
class _CardImage extends StatelessWidget {
  const _CardImage({required this.thumbnailPath});

  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    final path = thumbnailPath;
    if (path == null) {
      return _fallback(context);
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, _, __) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.watch_outlined,
        size: 48,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

/// "Worn today" badge shown over the photo.
class _WornBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: scheme.onPrimary),
          const SizedBox(width: 4),
          Text(
            'Worn today',
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overflow menu (edit / delete) anchored in a card corner.
class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const CircleAvatar(
        radius: 16,
        backgroundColor: Colors.black45,
        child: Icon(Icons.more_vert, size: 18, color: Colors.white),
      ),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}

/// Prominent wear-today toggle. Filled when the watch is worn today, outlined
/// otherwise, so its state reads at a glance.
class _WearButton extends StatelessWidget {
  const _WearButton({required this.worn, required this.onPressed});

  final bool worn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (worn) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Worn today'),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.watch, size: 18),
        label: const Text('Wear today'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.watch_outlined, size: 64),
          const SizedBox(height: 16),
          Text(
            'No watches yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap “Add watch” to start your collection.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
