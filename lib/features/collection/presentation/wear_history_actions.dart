import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/domain/wear_entry.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/wear_entry_dialog.dart';

/// Invalidates every provider that reflects wear data so all wear-history
/// views (per-watch and collection-wide) and the home "worn today" state
/// refresh after a change. Pass [watchId] to also refresh that watch's history.
void invalidateWearProviders(WidgetRef ref, {String? watchId}) {
  ref.invalidate(watchesWornTodayProvider);
  ref.invalidate(allWearHistoryProvider);
  if (watchId != null) {
    ref.invalidate(wearHistoryForWatchProvider(watchId));
  } else {
    ref.invalidate(wearHistoryForWatchProvider);
  }
}

/// Opens the edit dialog for [entry] and persists the change. Shared by the
/// per-watch tab and the collection-wide history page.
Future<void> editWearEntry(
  BuildContext context,
  WidgetRef ref,
  WearEntry entry,
) async {
  final draft = await showWearEntryDialog(
    context,
    title: 'Edit wear',
    initialDay: entry.wornOn,
    initialNote: entry.note,
  );
  if (draft == null) return;

  await ref
      .read(wearLogRepositoryProvider)
      .updateEntry(entry.id, wornOn: draft.day, note: draft.note);
  invalidateWearProviders(ref, watchId: entry.watchId);
}

/// Confirms and deletes [entry]. Shared by both wear-history views.
Future<void> deleteWearEntry(
  BuildContext context,
  WidgetRef ref,
  WearEntry entry,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete wear record?'),
      content: const Text('This removes the wear entry. It cannot be undone.'),
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

  await ref.read(wearLogRepositoryProvider).deleteEntry(entry.id);
  invalidateWearProviders(ref, watchId: entry.watchId);
}
