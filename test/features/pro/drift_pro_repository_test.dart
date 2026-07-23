import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/features/pro/data/drift_pro_repository.dart';
import 'package:watch_collection/features/pro/domain/pro_repository.dart';

void main() {
  group('canAddWatch', () {
    test('allows free users below the limit', () {
      expect(
        canAddWatch(watchCount: freeWatchLimit - 1, proUnlocked: false),
        isTrue,
      );
    });

    test('blocks free users at the limit', () {
      expect(
        canAddWatch(watchCount: freeWatchLimit, proUnlocked: false),
        isFalse,
      );
    });

    test('always allows Pro users, even past the limit', () {
      expect(
        canAddWatch(watchCount: freeWatchLimit + 3, proUnlocked: true),
        isTrue,
      );
    });
  });

  group('DriftProRepository', () {
    late AppDatabase db;
    late DriftProRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = DriftProRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('defaults to not unlocked when unset', () async {
      expect(await repo.isProUnlocked(), isFalse);
    });

    test('persists an unlock', () async {
      await repo.setProUnlocked(true);
      expect(await repo.isProUnlocked(), isTrue);
    });

    test('can be toggled back off', () async {
      await repo.setProUnlocked(true);
      await repo.setProUnlocked(false);
      expect(await repo.isProUnlocked(), isFalse);
    });
  });
}
