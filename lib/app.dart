import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/core/theme/app_theme.dart';
import 'package:watch_collection/features/collection/presentation/collection_home_page.dart';

/// Root widget of the Watch Collection Tracker app.
class WatchCollectionApp extends ConsumerWidget {
  const WatchCollectionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Watch Collection',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const CollectionHomePage(),
    );
  }
}
