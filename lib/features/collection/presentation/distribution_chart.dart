import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:watch_collection/features/collection/domain/collection_stats.dart';

/// A donut chart with an accompanying legend for a category distribution such
/// as watches-by-brand or watches-by-movement (issue #26).
///
/// The ring visualises each bucket's share of the whole; the legend lists every
/// bucket with its colour swatch, label, count and percentage so the exact
/// figures stay readable even when a slice is tiny. Tapping a slice (or its
/// legend row) highlights it in both places.
class DistributionChart extends StatefulWidget {
  const DistributionChart({required this.items, super.key});

  final List<CategoryCount> items;

  @override
  State<DistributionChart> createState() => _DistributionChartState();
}

class _DistributionChartState extends State<DistributionChart> {
  /// Index of the slice the user is currently highlighting, or null.
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.items;
    final total = items.fold<int>(0, (sum, c) => sum + c.count);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 52,
                      startDegreeOffset: -90,
                      sections: [
                        for (var i = 0; i < items.length; i++)
                          _section(theme, i, total),
                      ],
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response?.touchedSection == null) {
                              _touchedIndex = null;
                              return;
                            }
                            _touchedIndex =
                                response!.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                    ),
                  ),
                  // Centre label: the collection total the ring represents.
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        total == 1 ? 'watch' : 'watches',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < items.length; i++)
              _LegendRow(
                item: items[i],
                color: _colorFor(i),
                total: total,
                highlighted: _touchedIndex == i,
                onTap: () => setState(
                  () => _touchedIndex = _touchedIndex == i ? null : i,
                ),
              ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _section(ThemeData theme, int index, int total) {
    final isTouched = index == _touchedIndex;
    final item = widget.items[index];
    final pct = total == 0 ? 0.0 : item.count / total * 100;
    return PieChartSectionData(
      value: item.count.toDouble(),
      color: _colorFor(index),
      // Grow and label the highlighted slice; keep the rest clean.
      radius: isTouched ? 40 : 32,
      showTitle: isTouched,
      title: '${pct.round()}%',
      titleStyle: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  Color _colorFor(int index) => _chartPalette[index % _chartPalette.length];
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.item,
    required this.color,
    required this.total,
    required this.highlighted,
    required this.onTap,
  });

  final CategoryCount item;
  final Color color;
  final int total;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total == 0 ? 0 : (item.count / total * 100).round();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.count}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$pct%',
                textAlign: TextAlign.end,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Categorical palette for chart slices, chosen to stay distinguishable on both
/// light and dark surfaces. Colours cycle when there are more buckets than
/// entries.
const List<Color> _chartPalette = [
  Color(0xFF4C72B0), // blue
  Color(0xFFDD8452), // orange
  Color(0xFF55A868), // green
  Color(0xFFC44E52), // red
  Color(0xFF8172B3), // purple
  Color(0xFF937860), // brown
  Color(0xFFDA8BC3), // pink
  Color(0xFF8C8C8C), // grey
  Color(0xFFCCB974), // gold
  Color(0xFF64B5CD), // cyan
];
