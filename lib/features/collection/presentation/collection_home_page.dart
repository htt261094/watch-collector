import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/presentation/collection_providers.dart';

/// Landing screen that lists the watches in the collection.
///
/// Uses Riverpod's [AsyncValue] to render loading / error / data states from
/// [watchListProvider] without any manual state juggling.
class CollectionHomePage extends ConsumerWidget {
  const CollectionHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watches = ref.watch(watchListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Collection'),
      ),
      body: watches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Something went wrong:\n$error'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No watches yet.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final watch = items[index];
              return ListTile(
                leading: const Icon(Icons.watch_outlined),
                title: Text('${watch.brand} ${watch.model}'),
                subtitle: watch.movement != null ? Text(watch.movement!) : null,
              );
            },
          );
        },
      ),
    );
  }
}
