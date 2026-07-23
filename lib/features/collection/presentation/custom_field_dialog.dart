import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:watch_collection/features/collection/domain/custom_field.dart';

/// The values captured by [showCustomFieldDialog]: the field name, its type, and
/// its (type-appropriate) value.
class CustomFieldDraft {
  const CustomFieldDraft({
    required this.name,
    required this.type,
    this.value,
  });

  final String name;
  final CustomFieldType type;
  final String? value;
}

/// Shows a dialog to add or edit a custom field — a name input, a type picker
/// (text / number / date), and a value input that adapts to the chosen type.
/// Returns the captured [CustomFieldDraft], or null if cancelled.
///
/// Pass [initial] to pre-fill the fields when editing; leave it null to add a
/// new one.
Future<CustomFieldDraft?> showCustomFieldDialog(
  BuildContext context, {
  CustomField? initial,
}) {
  return showDialog<CustomFieldDraft>(
    context: context,
    builder: (_) => _CustomFieldDialog(initial: initial),
  );
}

class _CustomFieldDialog extends StatefulWidget {
  const _CustomFieldDialog({this.initial});

  final CustomField? initial;

  @override
  State<_CustomFieldDialog> createState() => _CustomFieldDialogState();
}

class _CustomFieldDialogState extends State<_CustomFieldDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late CustomFieldType _type;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _type = initial?.type ?? CustomFieldType.text;
    _date = initial?.dateValue;
    _valueController = TextEditingController(
      text: _type == CustomFieldType.date ? '' : (initial?.value ?? ''),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final String? value;
    switch (_type) {
      case CustomFieldType.date:
        value = _date == null ? null : CustomField.formatDate(_date!);
      case CustomFieldType.number:
      case CustomFieldType.text:
        value = _valueController.text;
    }
    Navigator.of(context).pop(
      CustomFieldDraft(
        name: _nameController.text.trim(),
        type: _type,
        value: value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit field' : 'Add custom field'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Field name',
                hintText: 'e.g. Strap, Water resistance',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter a name for the field'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CustomFieldType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final type in CustomFieldType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (type) {
                if (type != null) setState(() => _type = type);
              },
            ),
            const SizedBox(height: 16),
            _valueField(),
          ],
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

  /// The value input, adapted to the selected [_type].
  Widget _valueField() {
    switch (_type) {
      case CustomFieldType.date:
        return OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            _date == null ? 'Pick a date (optional)' : CustomField.formatDate(_date!),
          ),
        );
      case CustomFieldType.number:
        return TextFormField(
          controller: _valueController,
          decoration: const InputDecoration(
            labelText: 'Value (optional)',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return null;
            return num.tryParse(t) == null ? 'Enter a valid number' : null;
          },
        );
      case CustomFieldType.text:
        return TextFormField(
          controller: _valueController,
          decoration: const InputDecoration(
            labelText: 'Value (optional)',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          minLines: 1,
        );
    }
  }
}
