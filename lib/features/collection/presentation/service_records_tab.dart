import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/domain/service_record.dart';
import 'package:watch_collection/features/collection/domain/service_record_repository.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/photo_gallery_page.dart';
import 'package:watch_collection/features/collection/presentation/service_record_dialog.dart';
import 'package:watch_collection/features/pro/presentation/paywall_page.dart';
import 'package:watch_collection/features/pro/presentation/pro_providers.dart';

/// The "Service" sub-tab on the Watch Detail screen (issue #16).
///
/// Lists a watch's service & warranty reminders (soonest due first) and lets the
/// user add, edit, or delete them. Each add/edit (re)schedules a local
/// notification off the due date; deleting cancels it. Adding is a Pro feature —
/// free users are routed to the paywall, while existing reminders stay visible.
class ServiceRecordsTab extends ConsumerWidget {
  const ServiceRecordsTab({
    super.key,
    required this.watchId,
    required this.watchLabel,
  });

  final String watchId;

  /// "Brand Model" for this watch, woven into the reminder notification text.
  final String watchLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(serviceRecordsForWatchProvider(watchId));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRecord(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add reminder'),
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Something went wrong:\n$error'),
          ),
        ),
        data: (records) {
          if (records.isEmpty) return const _EmptyState();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final record = records[index];
              return _ServiceRecordTile(
                record: record,
                onEdit: () => _editRecord(context, ref, record),
                onDelete: () => _deleteRecord(context, ref, record),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addRecord(BuildContext context, WidgetRef ref) async {
    // Adding a reminder is Pro-gated; route free users to the paywall.
    final proUnlocked = await ref.read(proRepositoryProvider).isProUnlocked();
    if (!context.mounted) return;
    if (!proUnlocked) {
      final unlocked = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const PaywallPage()),
      );
      if (unlocked != true || !context.mounted) return;
    }

    final draft = await showServiceRecordDialog(context);
    if (draft == null) return;

    final repo = ref.read(serviceRecordRepositoryProvider);
    final id = await repo.addRecord(
      watchId,
      type: draft.type,
      dueDate: draft.dueDate,
      note: draft.note,
      cardPhotoSourcePath: _sourceOf(draft.cardPhoto),
    );
    ref.invalidate(serviceRecordsForWatchProvider(watchId));

    final created = await repo.getRecord(id);
    if (created != null) await _reschedule(ref, created);
  }

  Future<void> _editRecord(
    BuildContext context,
    WidgetRef ref,
    ServiceRecord record,
  ) async {
    final draft = await showServiceRecordDialog(context, initial: record);
    if (draft == null) return;

    final repo = ref.read(serviceRecordRepositoryProvider);
    await repo.updateRecord(
      record.id,
      type: draft.type,
      dueDate: draft.dueDate,
      note: draft.note,
      cardPhoto: draft.cardPhoto,
    );
    ref.invalidate(serviceRecordsForWatchProvider(watchId));

    final updated = await repo.getRecord(record.id);
    if (updated != null) await _reschedule(ref, updated);
  }

  Future<void> _deleteRecord(
    BuildContext context,
    WidgetRef ref,
    ServiceRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text(
          'Remove this ${record.type.label.toLowerCase()} reminder '
          '(due ${record.formattedDueDate})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(serviceRecordRepositoryProvider).deleteRecord(record.id);
    ref.invalidate(serviceRecordsForWatchProvider(watchId));

    try {
      await ref
          .read(serviceReminderSchedulerProvider)
          .cancelReminder(record.id);
    } catch (_) {
      // Best-effort — a failed cancel must not surface as a UI error.
    }
  }

  /// (Re)schedules the reminder for [record], swallowing notification errors so
  /// the data operation always succeeds even if the OS refuses to schedule.
  Future<void> _reschedule(WidgetRef ref, ServiceRecord record) async {
    try {
      final scheduler = ref.read(serviceReminderSchedulerProvider);
      await scheduler.requestPermissions();
      await scheduler.scheduleReminder(record, watchLabel: watchLabel);
    } catch (_) {
      // Best-effort scheduling.
    }
  }

  static String? _sourceOf(CardPhotoChange change) =>
      change is SetCardPhoto ? change.sourcePath : null;
}

/// A single reminder card: type + due date, optional overdue badge, note, and a
/// tappable warranty-card thumbnail, with an overflow menu for edit/delete.
class _ServiceRecordTile extends StatelessWidget {
  const _ServiceRecordTile({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final ServiceRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = record.isOverdue();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record.hasCardPhoto) ...[
              _CardThumbnail(path: record.cardPhotoPath!),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        record.type == ServiceRecordType.warranty
                            ? Icons.verified_user_outlined
                            : Icons.build_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        record.type.label,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (overdue) ...[
                        const SizedBox(width: 8),
                        _OverdueBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Due ${record.formattedDueDate}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: overdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (record.note != null && record.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(record.note!, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            PopupMenuButton<_RecordAction>(
              tooltip: 'Reminder actions',
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (action) {
                switch (action) {
                  case _RecordAction.edit:
                    onEdit();
                  case _RecordAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: _RecordAction.edit, child: Text('Edit')),
                PopupMenuItem(
                  value: _RecordAction.delete,
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardThumbnail extends StatelessWidget {
  const _CardThumbnail({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        photoGalleryRoute(imagePaths: [path]),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => Container(
            width: 56,
            height: 56,
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

class _OverdueBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Overdue',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
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
              Icons.build_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No reminders yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap “Add reminder” to track when this watch is due a service or '
              'its warranty expires — and get a notification before then.',
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

enum _RecordAction { edit, delete }
