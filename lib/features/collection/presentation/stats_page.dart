import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/domain/collection_stats.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/distribution_chart.dart';

/// Statistics screen (issue #9).
///
/// Surfaces collection-wide insights derived from the wear log: headline
/// totals, the most- and least-worn watches, per-watch cost-per-wear, and the
/// distribution of watches by brand and by movement type.
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(collectionStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Something went wrong:\n$error'),
          ),
        ),
        data: (stats) {
          if (stats.isEmpty) return const _EmptyState();
          return _StatsBody(stats: stats);
        },
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});

  final CollectionStats stats;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _OverviewTiles(stats: stats, year: year),
        const SizedBox(height: 24),
        if (stats.mostWorn != null) ...[
          const _SectionTitle('Wear extremes'),
          _ExtremeCard(
            icon: Icons.trending_up,
            label: 'Worn most',
            stat: stats.mostWorn!,
          ),
          if (stats.leastWorn != null) ...[
            const SizedBox(height: 8),
            _ExtremeCard(
              icon: Icons.trending_down,
              label: 'Worn least',
              stat: stats.leastWorn!,
            ),
          ],
          const SizedBox(height: 24),
        ],
        const _SectionTitle('Cost per wear'),
        _CostPerWearList(perWatch: stats.perWatch),
        const SizedBox(height: 24),
        const _SectionTitle('By brand'),
        DistributionChart(items: stats.byBrand),
        const SizedBox(height: 24),
        const _SectionTitle('By movement'),
        DistributionChart(items: stats.byMovement),
      ],
    );
  }
}

/// The three headline numbers, side by side.
class _OverviewTiles extends StatelessWidget {
  const _OverviewTiles({required this.stats, required this.year});

  final CollectionStats stats;
  final int year;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(value: '${stats.totalWatches}', label: 'Watches'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(value: '${stats.totalWears}', label: 'Total wears'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            value: '${stats.wearsThisYear}',
            label: 'Worn in $year',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card highlighting a single watch — used for most/least worn.
class _ExtremeCard extends StatelessWidget {
  const _ExtremeCard({
    required this.icon,
    required this.label,
    required this.stat,
  });

  final IconData icon;
  final String label;
  final WatchWearStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final watch = stat.watch;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text('${watch.brand} ${watch.model}'),
        subtitle: Text(label),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${stat.wearCount}',
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            Text(
              stat.wearCount == 1 ? 'wear' : 'wears',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-watch cost-per-wear, most-worn first. Rows without a recorded price or
/// with no wears yet show a dash instead of a figure.
class _CostPerWearList extends StatelessWidget {
  const _CostPerWearList({required this.perWatch});

  final List<WatchWearStat> perWatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < perWatch.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _CostPerWearRow(stat: perWatch[i], theme: theme),
          ],
        ],
      ),
    );
  }
}

class _CostPerWearRow extends StatelessWidget {
  const _CostPerWearRow({required this.stat, required this.theme});

  final WatchWearStat stat;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final watch = stat.watch;
    final cpw = stat.costPerWear;
    final String trailingValue;
    final String? trailingHint;
    if (cpw != null) {
      trailingValue = formatMoney(cpw);
      trailingHint = 'per wear';
    } else if (watch.purchasePrice == null) {
      trailingValue = '—';
      trailingHint = 'no price';
    } else {
      trailingValue = '—';
      trailingHint = 'never worn';
    }

    return ListTile(
      title: Text('${watch.brand} ${watch.model}'),
      subtitle: Text(
        '${stat.wearCount} ${stat.wearCount == 1 ? 'wear' : 'wears'}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            trailingValue,
            style: theme.textTheme.titleMedium?.copyWith(
              color: cpw != null ? theme.colorScheme.primary : null,
            ),
          ),
          Text(
            trailingHint,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
              Icons.insights_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No stats yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add watches and start logging wears to see cost-per-wear and '
              'other insights here.',
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

/// Formats a monetary figure with thousands separators and up to two decimal
/// places, dropping a trailing `.0` so whole numbers read cleanly. The app
/// stores prices as bare numbers with no currency, so none is shown.
String formatMoney(double value) {
  final rounded = (value * 100).round() / 100;
  final whole = rounded.truncate();
  final fraction = ((rounded - whole).abs() * 100).round();

  final digits = whole.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  var result = '${whole < 0 ? '-' : ''}$buffer';
  if (fraction != 0) {
    result = '$result.${fraction.toString().padLeft(2, '0')}';
  }
  return result;
}
