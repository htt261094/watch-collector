import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/data/in_memory_custom_field_repository.dart';
import 'package:watch_collection/features/collection/domain/custom_field.dart';
import 'package:watch_collection/features/collection/domain/custom_field_repository.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/custom_fields_section.dart';
import 'package:watch_collection/features/pro/data/in_memory_pro_repository.dart';
import 'package:watch_collection/features/pro/presentation/pro_providers.dart';

import '../pro/fake_purchase_service.dart';

Widget _wrap({
  required CustomFieldRepository repository,
  required bool proUnlocked,
}) {
  return ProviderScope(
    overrides: [
      customFieldRepositoryProvider.overrideWithValue(repository),
      proRepositoryProvider
          .overrideWithValue(InMemoryProRepository(proUnlocked: proUnlocked)),
      purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CustomFieldsSection(watchId: 'w1'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows existing fields with their values', (tester) async {
    final repo = InMemoryCustomFieldRepository();
    await repo.addField(
      'w1',
      name: 'Strap',
      type: CustomFieldType.text,
      value: 'Leather',
    );

    await tester.pumpWidget(_wrap(repository: repo, proUnlocked: true));
    await tester.pumpAndSettle();

    expect(find.text('Custom fields'), findsOneWidget);
    expect(find.text('Strap'), findsOneWidget);
    expect(find.text('Leather'), findsOneWidget);
  });

  testWidgets('a Pro user can add a field through the dialog', (tester) async {
    final repo = InMemoryCustomFieldRepository();
    await tester.pumpWidget(_wrap(repository: repo, proUnlocked: true));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add custom field'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Field name'),
      'Water resistance',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Field was persisted and now shows in the section.
    expect(await repo.getFieldsForWatch('w1'), hasLength(1));
    expect(find.text('Water resistance'), findsOneWidget);
  });

  testWidgets('a free user is routed to the paywall on Add', (tester) async {
    final repo = InMemoryCustomFieldRepository();
    await tester.pumpWidget(_wrap(repository: repo, proUnlocked: false));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pumpAndSettle();

    // The paywall is shown instead of the add-field dialog.
    expect(find.text('Upgrade to Pro'), findsOneWidget);
    expect(find.text('Add custom field'), findsNothing);
  });

  testWidgets('can delete a field via the overflow menu', (tester) async {
    final repo = InMemoryCustomFieldRepository();
    await repo.addField('w1', name: 'Strap', type: CustomFieldType.text);

    await tester.pumpWidget(_wrap(repository: repo, proUnlocked: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirm the deletion.
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await repo.getFieldsForWatch('w1'), isEmpty);
    expect(find.text('Strap'), findsNothing);
  });
}
