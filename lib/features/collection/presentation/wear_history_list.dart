import 'package:flutter/material.dart';

import 'package:watch_collection/features/collection/domain/wear_entry.dart';

/// A scrollable list of wear records, most recent first, with per-row edit and
/// delete actions.
///
/// Shared by the per-watch wear-history tab and the whole-collection history
/// page. When [labelFor] is supplied each row shows the watch it belongs to —
/// used by the collection view where entries span multiple watches.
class WearHistoryList extends StatelessWidget {
  const WearHistoryList({
    super.key,
    required this.entries,
    required this.onEdit,
    required this.onDelete,
    this.labelFor,
    this.header,
  });

  final List<WearEntry> entries;
  final ValueChanged<WearEntry> onEdit;
  final ValueChanged<WearEntry> onDelete;

  /// Resolves a watch id to a display label. When null, rows omit the watch
  /// name (per-watch view, where it is redundant).
  final String Function(String watchId)? labelFor;

  /// Optional widget rendered above the list (e.g. a stats summary).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: entries.length + (header != null ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (header != null && index == 0) return header!;
        final entry = entries[index - (header != null ? 1 : 0)];
        final label = labelFor?.call(entry.watchId);
        return ListTile(
          leading: const Icon(Icons.event_available_outlined),
          title: Text(_formatDate(entry.wornOn)),
          subtitle: _buildSubtitle(theme, label, entry.note),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit(entry);
              if (value == 'delete') onDelete(entry);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          onTap: () => onEdit(entry),
        );
      },
    );
  }

  Widget? _buildSubtitle(ThemeData theme, String? label, String? note) {
    final lines = <String>[
      if (label != null) label,
      if (note != null && note.trim().isNotEmpty) note.trim(),
    ];
    if (lines.isEmpty) return null;
    return Text(lines.join('\n'));
  }
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
