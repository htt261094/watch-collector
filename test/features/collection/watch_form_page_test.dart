import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/data/in_memory_watch_photo_repository.dart';
import 'package:watch_collection/features/collection/data/in_memory_watch_repository.dart';
import 'package:watch_collection/features/collection/domain/movement_type.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/watch_form_page.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      watchRepositoryProvider.overrideWithValue(InMemoryWatchRepository()),
      watchPhotoRepositoryProvider
          .overrideWithValue(InMemoryWatchPhotoRepository()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('blocks save when required fields are empty', (tester) async {
    await tester.pumpWidget(_wrap(const WatchFormPage()));

    // Tap the AppBar "Save" action without entering brand/model.
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();

    // Brand and model both report "Required".
    expect(find.text('Required'), findsNWidgets(2));
  });

  testWidgets('rejects a negative number in a dimension field',
      (tester) async {
    await tester.pumpWidget(_wrap(const WatchFormPage()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Brand *'), 'X');
    await tester.enterText(find.widgetWithText(TextFormField, 'Model *'), 'Y');
    // The Case section is below the fold; scroll it into view before typing.
    final diameter = find.widgetWithText(TextFormField, 'Diameter (mm)');
    await tester.scrollUntilVisible(
      diameter,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(diameter, '-5');

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();

    expect(find.text('Enter a valid diameter'), findsOneWidget);
  });

  testWidgets('pre-fills fields in edit mode', (tester) async {
    const watch = Watch(
      id: 'w1',
      brand: 'Omega',
      model: 'Speedmaster',
      movementType: MovementType.manual,
      complications: ['Chronograph'],
    );

    await tester.pumpWidget(_wrap(const WatchFormPage(watch: watch)));
    await tester.pumpAndSettle();

    expect(find.text('Edit watch'), findsOneWidget);
    expect(find.text('Omega'), findsOneWidget);
    expect(find.text('Speedmaster'), findsOneWidget);
    // The predefined "Chronograph" chip is shown selected (below the fold).
    final chip = find.widgetWithText(FilterChip, 'Chronograph');
    await tester.scrollUntilVisible(
      chip,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(chip, findsOneWidget);
  });
}
