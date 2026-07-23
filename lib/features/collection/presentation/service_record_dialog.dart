import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:watch_collection/features/collection/domain/service_record.dart';
import 'package:watch_collection/features/collection/domain/service_record_repository.dart';

/// The values captured by [showServiceRecordDialog]: the reminder type, its due
/// date, an optional note, and how the warranty-card photo should change.
class ServiceRecordDraft {
  const ServiceRecordDraft({
    required this.type,
    required this.dueDate,
    this.note,
    this.cardPhoto = const CardPhotoChange.keep(),
  });

  final ServiceRecordType type;
  final DateTime dueDate;
  final String? note;

  /// Keep / set / clear the card photo. For a new record, [SetCardPhoto] carries
  /// the picked file and [KeepCardPhoto] means "no photo".
  final CardPhotoChange cardPhoto;
}

/// Shows a dialog to add or edit a service / warranty reminder — a type picker,
/// a required due date, an optional note, and an optional warranty-card photo.
/// Returns the captured [ServiceRecordDraft], or null if cancelled.
///
/// Pass [initial] to pre-fill when editing; leave it null to add a new record.
/// [picker] is injectable for tests.
Future<ServiceRecordDraft?> showServiceRecordDialog(
  BuildContext context, {
  ServiceRecord? initial,
  ImagePicker? picker,
}) {
  return showDialog<ServiceRecordDraft>(
    context: context,
    builder: (_) => _ServiceRecordDialog(initial: initial, picker: picker),
  );
}

class _ServiceRecordDialog extends StatefulWidget {
  const _ServiceRecordDialog({this.initial, this.picker});

  final ServiceRecord? initial;
  final ImagePicker? picker;

  @override
  State<_ServiceRecordDialog> createState() => _ServiceRecordDialogState();
}

class _ServiceRecordDialogState extends State<_ServiceRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _noteController;
  late final ImagePicker _picker;
  late ServiceRecordType _type;
  DateTime? _dueDate;

  /// How the card photo should change on save.
  CardPhotoChange _cardChange = const CardPhotoChange.keep();

  /// Path to render in the preview right now (stored path or a picked temp
  /// path), or null when no photo is attached.
  String? _cardDisplayPath;

  bool _dueDateError = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _picker = widget.picker ?? ImagePicker();
    _noteController = TextEditingController(text: initial?.note ?? '');
    _type = initial?.type ?? ServiceRecordType.service;
    _dueDate = initial?.dueDate;
    _cardDisplayPath = initial?.cardPhotoPath;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) {
      setState(() {
        _dueDate = DateTime(picked.year, picked.month, picked.day);
        _dueDateError = false;
      });
    }
  }

  Future<void> _pickCardPhoto() async {
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
    if (source == null) return;
    try {
      final shot = await _picker.pickImage(source: source);
      if (shot == null) return;
      setState(() {
        _cardChange = CardPhotoChange.set(shot.path);
        _cardDisplayPath = shot.path;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add photo: $error')),
      );
    }
  }

  void _removeCardPhoto() {
    setState(() {
      _cardChange = const CardPhotoChange.clear();
      _cardDisplayPath = null;
    });
  }

  void _submit() {
    final formOk = _formKey.currentState!.validate();
    if (_dueDate == null) {
      setState(() => _dueDateError = true);
      return;
    }
    if (!formOk) return;
    Navigator.of(context).pop(
      ServiceRecordDraft(
        type: _type,
        dueDate: _dueDate!,
        note: _noteController.text,
        cardPhoto: _cardChange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.initial != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit reminder' : 'Add reminder'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<ServiceRecordType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in ServiceRecordType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (type) {
                  if (type != null) setState(() => _type = type);
                },
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Due date',
                  border: const OutlineInputBorder(),
                  errorText: _dueDateError ? 'Pick a due date' : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dueDate == null
                            ? 'No date chosen'
                            : ServiceRecord.formatDate(_dueDate!),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(_dueDate == null ? 'Pick' : 'Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. full service at authorised dealer',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 16),
              _CardPhotoField(
                displayPath: _cardDisplayPath,
                onPick: _pickCardPhoto,
                onRemove: _removeCardPhoto,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// The warranty-card photo control: a labelled preview with add/replace/remove.
class _CardPhotoField extends StatelessWidget {
  const _CardPhotoField({
    required this.displayPath,
    required this.onPick,
    required this.onRemove,
  });

  final String? displayPath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Warranty card photo',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (displayPath == null)
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add card photo'),
          )
        else
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(displayPath!),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) => Container(
                    width: 64,
                    height: 64,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onPick, child: const Text('Replace')),
              TextButton(
                onPressed: onRemove,
                child: const Text('Remove'),
              ),
            ],
          ),
      ],
    );
  }
}
