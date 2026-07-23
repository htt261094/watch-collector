import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/features/collection/data/drift_custom_field_repository.dart';
import 'package:watch_collection/features/collection/data/drift_watch_repository.dart';
import 'package:watch_collection/features/collection/domain/custom_field.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';

void main() {
  late AppDatabase db;
  late DriftCustomFieldRepository repo;
  late DriftWatchRepository watches;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftCustomFieldRepository(db);
    watches = DriftWatchRepository(db);
    // Custom fields reference a watch row (FK), so seed watches first.
    await watches.saveWatch(
      const Watch(id: 'w1', brand: 'Seiko', model: 'SPB143'),
    );
    await watches.saveWatch(
      const Watch(id: 'w2', brand: 'Casio', model: 'A168'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('addField stores a text field and reads it back', () async {
    await repo.addField(
      'w1',
      name: 'Strap',
      type: CustomFieldType.text,
      value: 'Leather',
    );

    final fields = await repo.getFieldsForWatch('w1');
    expect(fields, hasLength(1));
    expect(fields.single.name, 'Strap');
    expect(fields.single.type, CustomFieldType.text);
    expect(fields.single.value, 'Leather');
    expect(fields.single.watchId, 'w1');
  });

  test('supports number and date types', () async {
    await repo.addField(
      'w1',
      name: 'Water resistance',
      type: CustomFieldType.number,
      value: '200',
    );
    await repo.addField(
      'w1',
      name: 'Bought',
      type: CustomFieldType.date,
      value: '2024-05-01',
    );

    final fields = await repo.getFieldsForWatch('w1');
    final number = fields.firstWhere((f) => f.name == 'Water resistance');
    final date = fields.firstWhere((f) => f.name == 'Bought');

    expect(number.type, CustomFieldType.number);
    expect(number.displayValue, '200');
    expect(date.type, CustomFieldType.date);
    expect(date.dateValue, DateTime(2024, 5, 1));
    expect(date.displayValue, '2024-05-01');
  });

  test('fields are returned in insertion order', () async {
    await repo.addField('w1', name: 'First', type: CustomFieldType.text);
    await repo.addField('w1', name: 'Second', type: CustomFieldType.text);
    await repo.addField('w1', name: 'Third', type: CustomFieldType.text);

    final fields = await repo.getFieldsForWatch('w1');
    expect(fields.map((f) => f.name), ['First', 'Second', 'Third']);
  });

  test('name and value are trimmed; blank value stored as null', () async {
    await repo.addField(
      'w1',
      name: '  Strap  ',
      type: CustomFieldType.text,
      value: '   ',
    );

    final field = (await repo.getFieldsForWatch('w1')).single;
    expect(field.name, 'Strap');
    expect(field.value, isNull);
    expect(field.hasValue, isFalse);
  });

  test('fields are scoped to their watch', () async {
    await repo.addField('w1', name: 'Strap', type: CustomFieldType.text);
    await repo.addField('w2', name: 'Bezel', type: CustomFieldType.text);

    expect((await repo.getFieldsForWatch('w1')).single.name, 'Strap');
    expect((await repo.getFieldsForWatch('w2')).single.name, 'Bezel');
  });

  test('updateField changes name, type, and value', () async {
    final id = await repo.addField(
      'w1',
      name: 'Strap',
      type: CustomFieldType.text,
      value: 'Leather',
    );

    await repo.updateField(
      id,
      name: 'Insured value',
      type: CustomFieldType.number,
      value: '5000',
    );

    final field = (await repo.getFieldsForWatch('w1')).single;
    expect(field.name, 'Insured value');
    expect(field.type, CustomFieldType.number);
    expect(field.value, '5000');
  });

  test('deleteField removes just that field', () async {
    final keep = await repo.addField(
      'w1',
      name: 'Strap',
      type: CustomFieldType.text,
    );
    final remove = await repo.addField(
      'w1',
      name: 'Bezel',
      type: CustomFieldType.text,
    );

    await repo.deleteField(remove);

    final fields = await repo.getFieldsForWatch('w1');
    expect(fields, hasLength(1));
    expect(fields.single.id, keep);
  });

  test('deleting a watch cascades to its custom fields', () async {
    await repo.addField('w1', name: 'Strap', type: CustomFieldType.text);
    await watches.deleteWatch('w1');

    expect(await repo.getFieldsForWatch('w1'), isEmpty);
  });
}
