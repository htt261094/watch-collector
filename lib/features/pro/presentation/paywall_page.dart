import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/pro/domain/pro_repository.dart';
import 'package:watch_collection/features/pro/presentation/pro_providers.dart';

/// Pro upgrade / paywall screen (issue #10).
///
/// Shown when a free user hits the [freeWatchLimit] and tries to add another
/// watch, and reachable on demand for an overview of Pro. It sells the upgrade
/// and offers an unlock action.
///
/// Billing (real in-app purchase / restore) is out of scope for the MVP gate:
/// "Unlock Pro" flips the persisted `pro_unlocked` flag directly so the rest of
/// the app can be built and tested against a real entitlement. Wiring a store
/// SDK later only needs to replace [_unlock]'s body.
class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  bool _unlocking = false;

  static const _benefits = <(IconData, String, String)>[
    (
      Icons.all_inclusive,
      'Unlimited watches',
      'Add as many watches as your collection grows — no cap.',
    ),
    (
      Icons.insights_outlined,
      'Full stats & insights',
      'Cost-per-wear, wear history, and distribution charts.',
    ),
    (
      Icons.favorite_outline,
      'Support development',
      'A one-time unlock that keeps the app ad-free and offline.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch Collection Pro'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          children: [
            Icon(Icons.workspace_premium, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Upgrade to Pro',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'The free plan holds up to $freeWatchLimit watches. '
              'Unlock Pro for an unlimited collection.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            for (final (icon, title, subtitle) in _benefits)
              _BenefitTile(icon: icon, title: title, subtitle: subtitle),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: FilledButton.icon(
          onPressed: _unlocking ? null : _unlock,
          icon: _unlocking
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_open),
          label: Text(_unlocking ? 'Unlocking…' : 'Unlock Pro'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    setState(() => _unlocking = true);
    try {
      await ref.read(proRepositoryProvider).setProUnlocked(true);
      ref.invalidate(proUnlockedProvider);
      if (!mounted) return;
      // Signal the opener that Pro was unlocked so it can retry the gated action.
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pro unlocked — enjoy your collection!')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _unlocking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not unlock Pro: $error')),
      );
    }
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
