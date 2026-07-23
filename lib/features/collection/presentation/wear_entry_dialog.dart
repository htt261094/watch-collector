import 'package:flutter/material.dart';

/// The values captured by [showWearEntryDialog]: the chosen day and an optional
/// note.
class WearEntryDraft {
  const WearEntryDraft({required this.day, this.note});

  final DateTime day;
  final String? note;
}

/// Shows a dialog to add or edit a wear record — a date picker plus a free-text
/// note. Returns the captured [WearEntryDraft], or null if cancelled.
///
/// [initialDay] and [initialNote] pre-fill the fields when editing an existing
/// record; leave them at their defaults to add a new one.
Future<WearEntryDraft?> showWearEntryDialog(
  BuildContext context, {
  required String title,
  DateTime? initialDay,
  String? initialNote,
}) {
  return showDialog<WearEntryDraft>(
    context: context,
    builder: (_) => _WearEntryDialog(
      title: title,
      initialDay: initialDay ?? DateTime.now(),
      initialNote: initialNote,
    ),
  );
}

class _WearEntryDialog extends StatefulWidget {
  const _WearEntryDialog({
    required this.title,
    required this.initialDay,
    this.initialNote,
  });

  final String title;
  final DateTime initialDay;
  final String? initialNote;

  @override
  State<_WearEntryDialog> createState() => _WearEntryDialogState();
}

class _WearEntryDialogState extends State<_WearEntryDialog> {
  late DateTime _day;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _day = DateTime(
      widget.initialDay.year,
      widget.initialDay.month,
      widget.initialDay.day,
    );
    _noteController = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _day = DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(_formatDate(_day)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            WearEntryDraft(day: _day, note: _noteController.text),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
