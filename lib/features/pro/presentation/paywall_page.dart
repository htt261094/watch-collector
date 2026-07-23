import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/pro/domain/pro_repository.dart';
import 'package:watch_collection/features/pro/presentation/pro_providers.dart';
import 'package:watch_collection/features/pro/presentation/purchase_controller.dart';

/// Pro upgrade / paywall screen (issues #10, #11).
///
/// Shown when a free user hits the [freeWatchLimit] and tries to add another
/// watch, and reachable on demand for an overview of Pro. It sells the upgrade
/// and drives the Google Play Billing flow via [purchaseControllerProvider]:
/// "Unlock Pro" starts the one-time non-consumable purchase, and "Restore
/// purchase" recovers an unlock made on another device.
///
/// A successful purchase or restore persists the `pro_unlocked` entitlement (in
/// the controller) and pops with `true`, so the opener can retry the gated
/// action.
class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
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
      Icons.tune,
      'Custom fields',
      'Add your own fields to any watch — strap, insurance value, anything.',
    ),
    (
      Icons.autorenew,
      'Smart rotation',
      'Suggestions for the watches you have been neglecting the longest.',
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

    // React to purchase outcomes: dismiss on unlock, surface errors/cancels.
    ref.listen<PurchaseState>(purchaseControllerProvider, (previous, next) {
      switch (next.phase) {
        case PurchasePhase.unlocked:
          if (!mounted) return;
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pro unlocked — enjoy your collection!'),
            ),
          );
        case PurchasePhase.error:
          _showSnack(next.message ?? 'The purchase could not be completed.');
        case PurchasePhase.canceled:
          _showSnack('Purchase canceled.');
        case PurchasePhase.idle:
        case PurchasePhase.pending:
          break;
      }
    });

    final state = ref.watch(purchaseControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Watch Collection Pro')),
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
              'Unlock Pro once for an unlimited collection.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            for (final (icon, title, subtitle) in _benefits)
              _BenefitTile(icon: icon, title: title, subtitle: subtitle),
            if (!state.loadingProduct && !state.storeAvailable) ...[
              const SizedBox(height: 8),
              Text(
                'The store is unavailable right now. Check your connection and '
                'Google Play sign-in, then try again.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _Actions(state: state),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The unlock + restore actions pinned to the bottom of the paywall.
class _Actions extends ConsumerWidget {
  const _Actions({required this.state});

  final PurchaseState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(purchaseControllerProvider.notifier);
    final canBuy =
        state.storeAvailable && state.product != null && !state.busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: canBuy ? controller.buy : null,
            icon: state.busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open),
            label: Text(_buyLabel()),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          TextButton(
            onPressed: state.storeAvailable && !state.busy
                ? controller.restore
                : null,
            child: const Text('Restore purchase'),
          ),
        ],
      ),
    );
  }

  String _buyLabel() {
    if (state.busy) return 'Working…';
    if (state.loadingProduct) return 'Loading…';
    final product = state.product;
    if (product == null) return 'Unlock Pro';
    return 'Unlock Pro · ${product.price}';
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
