import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/core/util/id_generator.dart';
import 'package:watch_collection/features/collection/domain/movement_type.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_options.dart';
import 'package:watch_collection/features/collection/domain/watch_photo.dart';
import 'package:watch_collection/features/collection/domain/watch_photo_repository.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/photo_gallery_editor.dart';

/// Add / Edit Watch form (issue #3).
///
/// Passing an existing [watch] puts the form in *edit* mode (fields pre-filled,
/// same id reused on save); passing `null` is *add* mode (a fresh id is minted
/// on save). Movement type and case material offer predefined quick-entry
/// suggestions, and complications are capped at
/// [WatchOptions.maxComplications].
class WatchFormPage extends ConsumerStatefulWidget {
  const WatchFormPage({super.key, this.watch});

  final Watch? watch;

  bool get isEditing => watch != null;

  @override
  ConsumerState<WatchFormPage> createState() => _WatchFormPageState();
}

class _WatchFormPageState extends ConsumerState<WatchFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _referenceNo;
  late final TextEditingController _serialNo;
  late final TextEditingController _caliber;
  late final TextEditingController _powerReserve;
  late final TextEditingController _vph;
  late final TextEditingController _diameter;
  late final TextEditingController _lugWidth;
  late final TextEditingController _thickness;
  late final TextEditingController _caseMaterial;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _notes;

  MovementType? _movementType;
  late List<String> _complications;
  DateTime? _purchaseDate;
  bool _saving = false;

  /// Stable id for this watch, minted up front so newly picked photos can be
  /// attributed to it and persisted together with the watch on Save.
  late final String _watchId;

  /// Photos already stored for this watch (edit mode); empty in add mode until
  /// loaded. Drives the gallery editor's initial state.
  List<WatchPhoto> _initialPhotos = const [];

  /// The gallery editor's current desired state, applied on Save.
  List<PhotoDraft> _photoDrafts = const [];

  /// Whether existing photos have finished loading (always true in add mode).
  bool _photosLoaded = false;

  @override
  void initState() {
    super.initState();
    final w = widget.watch;
    _brand = TextEditingController(text: w?.brand ?? '');
    _model = TextEditingController(text: w?.model ?? '');
    _referenceNo = TextEditingController(text: w?.referenceNo ?? '');
    _serialNo = TextEditingController(text: w?.serialNo ?? '');
    _caliber = TextEditingController(text: w?.caliber ?? '');
    _powerReserve = TextEditingController(text: _intText(w?.powerReserve));
    _vph = TextEditingController(text: _intText(w?.vph));
    _diameter = TextEditingController(text: _numText(w?.diameter));
    _lugWidth = TextEditingController(text: _numText(w?.lugWidth));
    _thickness = TextEditingController(text: _numText(w?.thickness));
    _caseMaterial = TextEditingController(text: w?.caseMaterial ?? '');
    _purchasePrice = TextEditingController(text: _numText(w?.purchasePrice));
    _notes = TextEditingController(text: w?.notes ?? '');
    _movementType = w?.movementType;
    _complications = List<String>.from(w?.complications ?? const []);
    _purchaseDate = w?.purchaseDate;
    _watchId = w?.id ?? IdGenerator.newId();

    if (widget.isEditing) {
      _loadPhotos();
    } else {
      _photosLoaded = true;
    }
  }

  Future<void> _loadPhotos() async {
    final photos =
        await ref.read(watchPhotoRepositoryProvider).getPhotos(_watchId);
    if (!mounted) return;
    setState(() {
      _initialPhotos = photos;
      _photoDrafts = [
        for (final p in photos)
          ExistingPhoto(id: p.id, isThumbnail: p.isThumbnail),
      ];
      _photosLoaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _brand,
      _model,
      _referenceNo,
      _serialNo,
      _caliber,
      _powerReserve,
      _vph,
      _diameter,
      _lugWidth,
      _thickness,
      _caseMaterial,
      _purchasePrice,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit watch' : 'Add watch'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionLabel(context, 'Identification'),
              TextFormField(
                controller: _brand,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Brand *',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _model,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Model *',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _referenceNo,
                decoration: const InputDecoration(
                  labelText: 'Reference no.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serialNo,
                decoration: const InputDecoration(
                  labelText: 'Serial no.',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),
              _sectionLabel(context, 'Movement'),
              DropdownButtonFormField<MovementType>(
                initialValue: _movementType,
                decoration: const InputDecoration(
                  labelText: 'Movement type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in MovementType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) => setState(() => _movementType = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _caliber,
                decoration: const InputDecoration(
                  labelText: 'Caliber',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _powerReserve,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Power reserve (h)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _intValidator(v, 'power reserve'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _vph,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Beat rate (vph)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _intValidator(v, 'beat rate'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _sectionLabel(context, 'Case'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _diameter,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Diameter (mm)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _doubleValidator(v, 'diameter'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lugWidth,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Lug width (mm)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _doubleValidator(v, 'lug width'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _thickness,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Thickness (mm)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _doubleValidator(v, 'thickness'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CaseMaterialField(controller: _caseMaterial),

              const SizedBox(height: 24),
              _sectionLabel(context, 'Complications'),
              _ComplicationsPicker(
                selected: _complications,
                onChanged: (next) => setState(() => _complications = next),
              ),

              const SizedBox(height: 24),
              _sectionLabel(context, 'Purchase'),
              _PurchaseDateField(
                date: _purchaseDate,
                onPick: _pickPurchaseDate,
                onClear: () => setState(() => _purchaseDate = null),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purchasePrice,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Purchase price',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _doubleValidator(v, 'purchase price'),
              ),

              const SizedBox(height: 24),
              _sectionLabel(context, 'Photos'),
              if (!_photosLoaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                PhotoGalleryEditor(
                  initialPhotos: _initialPhotos,
                  onChanged: (drafts) => _photoDrafts = drafts,
                ),

              const SizedBox(height: 24),
              _sectionLabel(context, 'Notes'),
              TextFormField(
                controller: _notes,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Anything else worth remembering…',
                ),
              ),

              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.isEditing ? 'Save changes' : 'Add watch'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Future<void> _pickPurchaseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);

    final watch = Watch(
      id: _watchId,
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      referenceNo: _nullIfEmpty(_referenceNo.text),
      serialNo: _nullIfEmpty(_serialNo.text),
      movementType: _movementType,
      caliber: _nullIfEmpty(_caliber.text),
      powerReserve: _parseInt(_powerReserve.text),
      vph: _parseInt(_vph.text),
      diameter: _parseDouble(_diameter.text),
      lugWidth: _parseDouble(_lugWidth.text),
      thickness: _parseDouble(_thickness.text),
      caseMaterial: _nullIfEmpty(_caseMaterial.text),
      complications: _complications,
      purchaseDate: _purchaseDate,
      purchasePrice: _parseDouble(_purchasePrice.text),
      notes: _nullIfEmpty(_notes.text),
    );

    try {
      // The watch row must exist before photo rows (foreign key), so save it
      // first, then reconcile the gallery.
      await ref.read(watchRepositoryProvider).saveWatch(watch);
      await ref
          .read(watchPhotoRepositoryProvider)
          .savePhotos(watch.id, _photoDrafts);
      ref.invalidate(watchListProvider);
      ref.invalidate(watchByIdProvider(watch.id));
      ref.invalidate(watchPhotosProvider(watch.id));
      ref.invalidate(watchThumbnailsProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $error')),
      );
    }
  }

  // --- validation & parsing helpers ---------------------------------------

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _intValidator(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) {
      return 'Enter a valid $label';
    }
    return null;
  }

  String? _doubleValidator(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null || parsed < 0) {
      return 'Enter a valid $label';
    }
    return null;
  }

  static String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _parseInt(String value) => int.tryParse(value.trim());

  static double? _parseDouble(String value) => double.tryParse(value.trim());

  static String _intText(int? value) => value?.toString() ?? '';

  static String _numText(double? value) {
    if (value == null) return '';
    // Drop a trailing `.0` so whole numbers read cleanly (40.0 -> "40").
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}

/// Case-material input with autocomplete suggestions from
/// [WatchOptions.caseMaterials], while still allowing free-text entry.
///
/// Uses [RawAutocomplete] so the parent-owned [controller] *is* the field's
/// controller — free-text values are captured on save with no mirroring.
class _CaseMaterialField extends StatefulWidget {
  const _CaseMaterialField({required this.controller});

  final TextEditingController controller;

  @override
  State<_CaseMaterialField> createState() => _CaseMaterialFieldState();
}

class _CaseMaterialFieldState extends State<_CaseMaterialField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return WatchOptions.caseMaterials;
        return WatchOptions.caseMaterials
            .where((m) => m.toLowerCase().contains(query));
      },
      fieldViewBuilder:
          (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          onFieldSubmitted: (_) => onFieldSubmitted(),
          decoration: const InputDecoration(
            labelText: 'Case material',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Multi-select complications picker: predefined chips plus custom entries,
/// capped at [WatchOptions.maxComplications].
class _ComplicationsPicker extends StatefulWidget {
  const _ComplicationsPicker({required this.selected, required this.onChanged});

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ComplicationsPicker> createState() => _ComplicationsPickerState();
}

class _ComplicationsPickerState extends State<_ComplicationsPicker> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  bool get _atLimit =>
      widget.selected.length >= WatchOptions.maxComplications;

  void _toggle(String name) {
    final next = List<String>.from(widget.selected);
    if (next.contains(name)) {
      next.remove(name);
    } else {
      if (_atLimit) return;
      next.add(name);
    }
    widget.onChanged(next);
  }

  void _addCustom() {
    final name = _customController.text.trim();
    if (name.isEmpty || _atLimit) return;
    if (widget.selected.any((c) => c.toLowerCase() == name.toLowerCase())) {
      _customController.clear();
      return;
    }
    widget.onChanged([...widget.selected, name]);
    _customController.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Predefined options plus any custom selections not in the common list.
    final options = <String>[
      ...WatchOptions.commonComplications,
      ...widget.selected
          .where((c) => !WatchOptions.commonComplications.contains(c)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.selected.length} / ${WatchOptions.maxComplications} selected',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(option),
                selected: widget.selected.contains(option),
                onSelected: (_atLimit && !widget.selected.contains(option))
                    ? null
                    : (_) => _toggle(option),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customController,
                enabled: !_atLimit,
                decoration: const InputDecoration(
                  labelText: 'Add custom complication',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _addCustom(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _atLimit ? null : _addCustom,
              icon: const Icon(Icons.add),
              tooltip: 'Add',
            ),
          ],
        ),
        if (_atLimit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Maximum of ${WatchOptions.maxComplications} complications reached.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
      ],
    );
  }
}

/// Read-only field that opens a date picker for the purchase date.
class _PurchaseDateField extends StatelessWidget {
  const _PurchaseDateField({
    required this.date,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Purchase date',
          border: const OutlineInputBorder(),
          suffixIcon: date == null
              ? const Icon(Icons.calendar_today)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                  tooltip: 'Clear',
                ),
        ),
        child: Text(date == null ? 'Not set' : _formatDate(date!)),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}
