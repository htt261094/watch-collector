import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_photo.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/custom_fields_section.dart';
import 'package:watch_collection/features/collection/presentation/service_records_tab.dart';
import 'package:watch_collection/features/collection/presentation/watch_form_page.dart';
import 'package:watch_collection/features/collection/presentation/watch_photo_grid.dart';
import 'package:watch_collection/features/collection/presentation/wear_history_actions.dart';
import 'package:watch_collection/features/collection/presentation/wear_history_tab.dart';

/// Watch Detail screen (issue #6).
///
/// Shows a watch's photos and its full set of specifications, organised into
/// four sub-tabs:
///
/// * **Overview** — every field captured on the Add/Edit form, grouped by
///   section, plus the photo gallery.
/// * **Wear history** (issue #8) and **Service** (issue #16) — full features.
/// * **Accuracy** — placeholder for a feature wired up in a later milestone.
///
/// The watch is re-read from [watchByIdProvider] so edits made via the form
/// (opened from the AppBar) are reflected on return without a manual refresh.
class WatchDetailPage extends ConsumerWidget {
  const WatchDetailPage({super.key, required this.watchId});

  final String watchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchAsync = ref.watch(watchByIdProvider(watchId));

    return watchAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Something went wrong:\n$error'),
          ),
        ),
      ),
      data: (watch) {
        if (watch == null) {
          return Scaffold(
            appBar: AppBar(),
            body:
                const Center(child: Text('This watch is no longer available.')),
          );
        }
        return _DetailScaffold(watch: watch);
      },
    );
  }
}

class _DetailScaffold extends ConsumerWidget {
  const _DetailScaffold({required this.watch});

  final Watch watch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(watchPhotosProvider(watch.id)).valueOrNull ??
        const <WatchPhoto>[];
    // The worn-today set loads independently; treat a loading/error state as
    // "not worn yet" so the screen still renders.
    final wornToday =
        ref.watch(watchesWornTodayProvider).valueOrNull ?? const <String>{};
    final isWornToday = wornToday.contains(watch.id);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${watch.brand} ${watch.model}'),
          actions: [
            IconButton(
              icon: Icon(
                isWornToday ? Icons.check_circle : Icons.watch_outlined,
              ),
              tooltip: isWornToday ? 'Worn today' : 'Wear today',
              onPressed: () => _toggleWorn(context, ref, isWornToday),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => WatchFormPage(watch: watch),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Wear history'),
              Tab(text: 'Accuracy'),
              Tab(text: 'Service'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(watch: watch, photos: photos),
            WearHistoryTab(watchId: watch.id),
            const _PlaceholderTab(
              icon: Icons.timelapse_outlined,
              title: 'Accuracy',
              message: 'Track this watch’s daily rate and timekeeping accuracy '
                  'here.',
            ),
            ServiceRecordsTab(
              watchId: watch.id,
              watchLabel: '${watch.brand} ${watch.model}',
            ),
          ],
        ),
      ),
    );
  }

  /// One-tap wear logging: records (or clears) today's wear for this watch.
  /// The repository keeps the entry idempotent, so repeated taps in a day never
  /// create duplicate logs.
  Future<void> _toggleWorn(
    BuildContext context,
    WidgetRef ref,
    bool currentlyWorn,
  ) async {
    final repository = ref.read(wearLogRepositoryProvider);
    final today = DateTime.now();
    if (currentlyWorn) {
      await repository.removeWear(watch.id, today);
    } else {
      await repository.logWear(watch.id, today);
    }
    invalidateWearProviders(ref, watchId: watch.id);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            currentlyWorn
                ? 'Unmarked ${watch.brand} ${watch.model} as worn today'
                : 'Wearing ${watch.brand} ${watch.model} today',
          ),
        ),
      );
  }
}

/// The Overview tab: photo gallery followed by every specification, grouped.
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.watch, required this.photos});

  final Watch watch;
  final List<WatchPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final movement = _movementRows(watch);
    final caseRows = _caseRows(watch);
    final purchase = _purchaseRows(watch);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        WatchPhotoGrid(imagePaths: [for (final p in photos) p.filePath]),
        const SizedBox(height: 16),
        _SpecSection(
          title: 'Identification',
          rows: [
            _SpecRow('Brand', watch.brand),
            _SpecRow('Model', watch.model),
            _SpecRow('Reference no.', watch.referenceNo),
            _SpecRow('Serial no.', watch.serialNo),
          ],
        ),
        _SpecSection(title: 'Movement', rows: movement),
        _SpecSection(title: 'Case', rows: caseRows),
        if (watch.complications.isNotEmpty)
          _ChipsSection(
            title: 'Complications',
            values: watch.complications,
          ),
        _SpecSection(title: 'Purchase', rows: purchase),
        if (watch.notes != null && watch.notes!.trim().isNotEmpty)
          _NotesSection(notes: watch.notes!),
        CustomFieldsSection(watchId: watch.id),
      ],
    );
  }

  static List<_SpecRow> _movementRows(Watch watch) => [
        _SpecRow('Type', watch.movementType?.label),
        _SpecRow('Caliber', watch.caliber),
        _SpecRow(
          'Power reserve',
          watch.powerReserve == null ? null : '${watch.powerReserve} h',
        ),
        _SpecRow(
          'Beat rate',
          watch.vph == null ? null : '${watch.vph} vph',
        ),
      ];

  static List<_SpecRow> _caseRows(Watch watch) => [
        _SpecRow('Diameter', _mm(watch.diameter)),
        _SpecRow('Lug width', _mm(watch.lugWidth)),
        _SpecRow('Thickness', _mm(watch.thickness)),
        _SpecRow('Material', watch.caseMaterial),
      ];

  static List<_SpecRow> _purchaseRows(Watch watch) => [
        _SpecRow('Date', _formatDate(watch.purchaseDate)),
        _SpecRow('Price', _formatPrice(watch.purchasePrice)),
      ];

  static String? _mm(double? value) =>
      value == null ? null : '${_trimNum(value)} mm';

  static String? _formatPrice(double? value) =>
      value == null ? null : _trimNum(value);

  static String? _formatDate(DateTime? d) {
    if (d == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// Drops a trailing `.0` so whole numbers read cleanly (40.0 -> "40").
  static String _trimNum(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}

/// A single label/value pair. Rows with a null/empty value are treated as
/// "unset" and skipped by [_SpecSection].
class _SpecRow {
  const _SpecRow(this.label, this.value);

  final String label;
  final String? value;

  bool get hasValue => value != null && value!.trim().isNotEmpty;
}

/// A titled group of spec rows. The whole section is hidden when none of its
/// rows have a value, so an empty screen never shows dangling headers.
class _SpecSection extends StatelessWidget {
  const _SpecSection({required this.title, required this.rows});

  final String title;
  final List<_SpecRow> rows;

  @override
  Widget build(BuildContext context) {
    final visible = rows.where((r) => r.hasValue).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        for (final row in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    row.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Section rendering a list of values as chips (used for complications).
class _ChipsSection extends StatelessWidget {
  const _ChipsSection({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [for (final v in values) Chip(label: Text(v))],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Section rendering free-text notes.
class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Notes'),
        Text(notes, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
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
}

/// Shared "coming soon" body for the not-yet-implemented tabs.
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
