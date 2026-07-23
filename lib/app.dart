import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/core/theme/app_theme.dart';
import 'package:watch_collection/features/collection/presentation/collection_home_page.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';

/// Root widget of the Watch Collection Tracker app.
class WatchCollectionApp extends ConsumerStatefulWidget {
  const WatchCollectionApp({super.key});

  @override
  ConsumerState<WatchCollectionApp> createState() => _WatchCollectionAppState();
}

class _WatchCollectionAppState extends ConsumerState<WatchCollectionApp> {
  @override
  void initState() {
    super.initState();
    // Rebuild the OS-level service/warranty reminders once on launch. Scheduled
    // notifications don't survive a reinstall, and rescheduling is idempotent,
    // so doing it every start keeps them in sync with the database.
    WidgetsBinding.instance.addPostFrameCallback((_) => _rescheduleReminders());
  }

  Future<void> _rescheduleReminders() async {
    try {
      final scheduler = ref.read(serviceReminderSchedulerProvider);
      await scheduler.init();
      final records =
          await ref.read(serviceRecordRepositoryProvider).getAllRecords();
      if (records.isEmpty) return;
      final labels = await ref.read(watchLabelsProvider.future);
      for (final record in records) {
        await scheduler.scheduleReminder(
          record,
          watchLabel: labels[record.watchId],
        );
      }
    } catch (_) {
      // Best-effort: reminder scheduling must never crash app startup.
    }
  }

  @override
  Widget build(BuildContext context) {
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
