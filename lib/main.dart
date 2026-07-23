import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/app.dart';

void main() {
  // Needed before any plugin (e.g. local notifications) is touched during the
  // app's startup reminder reschedule.
  WidgetsFlutterBinding.ensureInitialized();

  // ProviderScope stores the state of every Riverpod provider used in the app.
  runApp(
    const ProviderScope(
      child: WatchCollectionApp(),
    ),
  );
}
