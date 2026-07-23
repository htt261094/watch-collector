import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/wear_history_actions.dart';
import 'package:watch_collection/features/collection/presentation/wear_history_list.dart';

/// Wear history across the whole collection (issue #8).
///
/// Lists every wear record for every watch, most recent first, labelled with
/// the watch it belongs to. Records can be edited or deleted inline; changes
/// are reflected on the per-watch history and the home screen too.
class WearHistoryPage extends ConsumerWidget {
  const WearHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(allWearHistoryProvider);
    final labels = ref.watch(watchLabelsProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('Wear history')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Something went wrong:\n$error'),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const _EmptyState();
          }
          return WearHistoryList(
            entries: entries,
            labelFor: (watchId) => labels[watchId] ?? 'Unknown watch',
            onEdit: (entry) => editWearEntry(context, ref, entry),
            onDelete: (entry) => deleteWearEntry(context, ref, entry),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No wears logged yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Wear records appear here once you start marking watches as worn.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
