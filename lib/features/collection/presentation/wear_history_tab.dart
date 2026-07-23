import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/domain/wear_entry.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/wear_entry_dialog.dart';
import 'package:watch_collection/features/collection/presentation/wear_history_actions.dart';
import 'package:watch_collection/features/collection/presentation/wear_history_list.dart';

/// The "Wear history" sub-tab on the Watch Detail screen (issue #8).
///
/// Lists every day this watch was worn, with a summary header, and lets the
/// user add a past wear, edit a record's date/note, or delete it.
class WearHistoryTab extends ConsumerWidget {
  const WearHistoryTab({super.key, required this.watchId});

  final String watchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(wearHistoryForWatchProvider(watchId));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addWear(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Log a wear'),
      ),
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
            header: _SummaryHeader(entries: entries),
            onEdit: (entry) => editWearEntry(context, ref, entry),
            onDelete: (entry) => deleteWearEntry(context, ref, entry),
          );
        },
      ),
    );
  }

  Future<void> _addWear(BuildContext context, WidgetRef ref) async {
    final draft = await showWearEntryDialog(context, title: 'Log a wear');
    if (draft == null) return;

    final repo = ref.read(wearLogRepositoryProvider);
    await repo.logWear(watchId, draft.day);
    final note = draft.note?.trim();
    if (note != null && note.isNotEmpty) {
      // logWear does not carry a note, so find the record it created/kept for
      // that day and set the note on it.
      final entries = await repo.getEntriesForWatch(watchId);
      final created = entries.where((e) => _sameDay(e.wornOn, draft.day));
      if (created.isNotEmpty) {
        await repo.updateEntry(created.first.id, wornOn: draft.day, note: note);
      }
    }
    invalidateWearProviders(ref, watchId: watchId);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// A compact summary above the list: total wears and the most recent day.
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.entries});

  final List<WearEntry> entries;

  @override
  Widget build(BuildContext context) {
    final total = entries.length;
    final last = entries.first.wornOn; // list is most-recent-first
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _Stat(label: 'Times worn', value: '$total'),
          const SizedBox(width: 24),
          _Stat(label: 'Last worn', value: _formatDate(last)),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
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
              'Tap “Log a wear” — or the watch icon in the top bar — to record '
              'when you wore this watch.',
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
