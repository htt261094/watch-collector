import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/domain/rotation_suggestion.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/watch_detail_page.dart';
import 'package:watch_collection/features/pro/presentation/paywall_page.dart';
import 'package:watch_collection/features/pro/presentation/pro_providers.dart';

/// The "Suggested to wear" block (issue #17), reused on Home and Stats.
///
/// Surfaces the watches most overdue for a wearing, computed from wear history
/// by [computeRotationSuggestions]. Smart rotation is a Pro feature: free users
/// see a locked teaser that routes to the paywall, while Pro users see the
/// ranked list. When there is nothing worth suggesting (an empty or one-watch
/// collection, or everything already worn today) the whole block renders
/// nothing, so it never clutters a screen with an empty state.
class RotationSuggestionSection extends ConsumerWidget {
  const RotationSuggestionSection({super.key, this.maxItems = 3});

  /// How many suggestions to show at most.
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions =
        ref.watch(rotationSuggestionsProvider).valueOrNull ?? const [];
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final proUnlocked = ref.watch(proUnlockedProvider).valueOrNull ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header(),
        const SizedBox(height: 12),
        if (proUnlocked)
          _SuggestionList(
            suggestions: suggestions.take(maxItems).toList(),
          )
        else
          _LockedTeaser(topPick: suggestions.first),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.autorenew, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          'Suggested to wear',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        const _ProChip(),
      ],
    );
  }
}

/// Small "PRO" pill used to mark the feature as a Pro perk.
class _ProChip extends StatelessWidget {
  const _ProChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'PRO',
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// The unlocked list of ranked suggestions.
class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.suggestions});

  final List<RotationSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < suggestions.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _SuggestionTile(suggestion: suggestions[i], rank: i + 1),
          ],
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion, required this.rank});

  final RotationSuggestion suggestion;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final watch = suggestion.watch;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          '$rank',
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text('${watch.brand} ${watch.model}'),
      subtitle: Text(rotationRecencyLabel(suggestion)),
      trailing: Text(
        '${suggestion.wearCount} ${suggestion.wearCount == 1 ? 'wear' : 'wears'}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => WatchDetailPage(watchId: watch.id),
        ),
      ),
    );
  }
}

/// The Pro-gated teaser shown to free users: names the top pick but blurs the
/// full ranking behind an unlock prompt.
class _LockedTeaser extends ConsumerWidget {
  const _LockedTeaser({required this.topPick});

  final RotationSuggestion topPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Let the app pick what to wear next',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock Pro for smart rotation — suggestions for the watches '
              'you have been neglecting, ranked by how long they have sat idle.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(builder: (_) => const PaywallPage()),
                ),
                icon: const Icon(Icons.lock_open, size: 18),
                label: const Text('Unlock Pro'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Human-readable "how long since last worn" line for a suggestion, e.g.
/// "Never worn", "Worn yesterday", "Worn 3 weeks ago".
String rotationRecencyLabel(RotationSuggestion suggestion) {
  if (suggestion.neverWorn) return 'Never worn';
  final days = suggestion.daysSinceLastWorn!;
  if (days == 1) return 'Worn yesterday';
  if (days < 14) return 'Worn $days days ago';
  if (days < 60) return 'Worn ${(days / 7).round()} weeks ago';
  if (days < 365) return 'Worn ${(days / 30).round()} months ago';
  return 'Worn over a year ago';
}
