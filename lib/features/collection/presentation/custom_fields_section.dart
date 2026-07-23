import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/domain/custom_field.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/custom_field_dialog.dart';
import 'package:watch_collection/features/pro/presentation/paywall_page.dart';
import 'package:watch_collection/features/pro/presentation/pro_providers.dart';

/// The "Custom fields" block on the Watch Detail overview (issue #15).
///
/// Lists a watch's user-defined fields and lets the user add, edit, or delete
/// them. Adding a field is a Pro feature: free users are sent to the paywall,
/// while existing fields stay visible so nothing is hidden if Pro lapses.
class CustomFieldsSection extends ConsumerWidget {
  const CustomFieldsSection({super.key, required this.watchId});

  final String watchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fields = ref.watch(customFieldsForWatchProvider(watchId)).valueOrNull ??
        const <CustomField>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Custom fields',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addField(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (fields.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Add your own fields — strap, water resistance, insurance value, '
              'anything you like.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final field in fields)
            _CustomFieldTile(
              field: field,
              onEdit: () => _editField(context, ref, field),
              onDelete: () => _deleteField(context, ref, field),
            ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _addField(BuildContext context, WidgetRef ref) async {
    // Adding a custom field is Pro-gated; route free users to the paywall.
    final proUnlocked = await ref.read(proRepositoryProvider).isProUnlocked();
    if (!context.mounted) return;
    if (!proUnlocked) {
      final unlocked = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const PaywallPage()),
      );
      if (unlocked != true || !context.mounted) return;
    }

    final draft = await showCustomFieldDialog(context);
    if (draft == null) return;

    await ref.read(customFieldRepositoryProvider).addField(
          watchId,
          name: draft.name,
          type: draft.type,
          value: draft.value,
        );
    ref.invalidate(customFieldsForWatchProvider(watchId));
  }

  Future<void> _editField(
    BuildContext context,
    WidgetRef ref,
    CustomField field,
  ) async {
    final draft = await showCustomFieldDialog(context, initial: field);
    if (draft == null) return;

    await ref.read(customFieldRepositoryProvider).updateField(
          field.id,
          name: draft.name,
          type: draft.type,
          value: draft.value,
        );
    ref.invalidate(customFieldsForWatchProvider(watchId));
  }

  Future<void> _deleteField(
    BuildContext context,
    WidgetRef ref,
    CustomField field,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete field?'),
        content: Text('Remove “${field.name}” from this watch?'),
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

    await ref.read(customFieldRepositoryProvider).deleteField(field.id);
    ref.invalidate(customFieldsForWatchProvider(watchId));
  }
}

/// A single custom field row: label, value, and an overflow menu for edit/delete.
class _CustomFieldTile extends StatelessWidget {
  const _CustomFieldTile({
    required this.field,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomField field;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = field.displayValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              field.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          PopupMenuButton<_FieldAction>(
            tooltip: 'Field actions',
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (action) {
              switch (action) {
                case _FieldAction.edit:
                  onEdit();
                case _FieldAction.delete:
                  onDelete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _FieldAction.edit,
                child: Text('Edit'),
              ),
              PopupMenuItem(
                value: _FieldAction.delete,
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _FieldAction { edit, delete }
