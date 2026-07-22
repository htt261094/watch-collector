import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/watch_form_page.dart';

/// Landing screen that lists the watches in the collection.
///
/// Uses Riverpod's [AsyncValue] to render loading / error / data states from
/// [watchListProvider]. A floating action button opens the Add form; tapping a
/// row opens the Edit form; a trailing menu deletes (issue #3).
class CollectionHomePage extends ConsumerWidget {
  const CollectionHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watches = ref.watch(watchListProvider);

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
          return ListView.separated(
            // Leave room so the FAB doesn't cover the last row.
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final watch = items[index];
              return ListTile(
                leading: const Icon(Icons.watch_outlined),
                title: Text('${watch.brand} ${watch.model}'),
                subtitle: _subtitle(watch) != null
                    ? Text(_subtitle(watch)!)
                    : null,
                onTap: () => _openForm(context, watch: watch),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _openForm(context, watch: watch);
                      case 'delete':
                        _confirmDelete(context, ref, watch);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String? _subtitle(Watch watch) {
    final parts = <String>[
      if (watch.movementType != null) watch.movementType!.label,
      if (watch.referenceNo != null) 'Ref. ${watch.referenceNo}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _openForm(BuildContext context, {Watch? watch}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WatchFormPage(watch: watch)),
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

    await ref.read(watchRepositoryProvider).deleteWatch(watch.id);
    ref.invalidate(watchListProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${watch.brand} ${watch.model}')),
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
