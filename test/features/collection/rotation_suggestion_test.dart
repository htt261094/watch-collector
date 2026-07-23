import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/data/in_memory_watch_repository.dart';
import 'package:watch_collection/features/collection/data/in_memory_wear_log_repository.dart';
import 'package:watch_collection/features/collection/domain/rotation_suggestion.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';
import 'package:watch_collection/features/collection/domain/wear_entry.dart';
import 'package:watch_collection/features/collection/domain/wear_log_repository.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/rotation_suggestion_section.dart';
import 'package:watch_collection/features/pro/data/in_memory_pro_repository.dart';
import 'package:watch_collection/features/pro/presentation/pro_providers.dart';

WearEntry _entry(String watchId, DateTime day) => WearEntry(
      id: '$watchId-${day.toIso8601String()}',
      watchId: watchId,
      wornOn: day,
    );

/// A repository returning a fixed set of watches.
class _FixedRepository extends InMemoryWatchRepository {
  _FixedRepository(this.watches);

  final List<Watch> watches;

  @override
  Future<List<Watch>> getWatches() async => List.unmodifiable(watches);
}

Widget _wrap({
  required WatchRepository watchRepository,
  required WearLogRepository wearLogRepository,
  required bool proUnlocked,
}) {
  return ProviderScope(
    overrides: [
      watchRepositoryProvider.overrideWithValue(watchRepository),
      wearLogRepositoryProvider.overrideWithValue(wearLogRepository),
      proRepositoryProvider
          .overrideWithValue(InMemoryProRepository(proUnlocked: proUnlocked)),
    ],
    child: const MaterialApp(
      home: Scaffold(body: RotationSuggestionSection()),
    ),
  );
}

void main() {
  group('computeRotationSuggestions', () {
    const seiko = Watch(id: 'w1', brand: 'Seiko', model: 'SPB143');
    const casio = Watch(id: 'w2', brand: 'Casio', model: 'A168');
    const orient = Watch(id: 'w3', brand: 'Orient', model: 'Bambino');

    test('ranks longest-idle first, never-worn above all', () {
      final now = DateTime(2026, 7, 23);
      final entries = [
        // Seiko: worn 2 days ago (most recent).
        _entry('w1', DateTime(2026, 7, 21)),
        _entry('w1', DateTime(2026, 6, 1)),
        // Casio: worn 20 days ago.
        _entry('w2', DateTime(2026, 7, 3)),
        // Orient: never worn.
      ];

      final result = computeRotationSuggestions(
        const [seiko, casio, orient],
        entries,
        now: now,
      );

      // Never-worn Orient first, then Casio (20d), then Seiko (2d).
      expect(result.map((s) => s.watch.id), ['w3', 'w2', 'w1']);
      expect(result.first.neverWorn, isTrue);
      expect(result.first.daysSinceLastWorn, isNull);
      expect(result[1].daysSinceLastWorn, 20);
      expect(result[2].daysSinceLastWorn, 2);
      expect(result[2].wearCount, 2);
    });

    test('watches worn today are excluded', () {
      final now = DateTime(2026, 7, 23);
      final result = computeRotationSuggestions(
        const [seiko, casio],
        [
          _entry('w1', DateTime(2026, 7, 23)), // worn today
          _entry('w2', DateTime(2026, 7, 10)),
        ],
        now: now,
      );
      // Seiko dropped; only Casio remains -> fewer than two candidates.
      expect(result, isEmpty);
    });

    test('equal idle gaps break the tie by lower wear count', () {
      final now = DateTime(2026, 7, 23);
      final result = computeRotationSuggestions(
        const [seiko, casio],
        [
          // Both last worn 5 days ago, but Seiko worn more overall.
          _entry('w1', DateTime(2026, 7, 18)),
          _entry('w1', DateTime(2026, 7, 1)),
          _entry('w2', DateTime(2026, 7, 18)),
        ],
        now: now,
      );
      // Casio (1 wear) ranked above Seiko (2 wears).
      expect(result.map((s) => s.watch.id), ['w2', 'w1']);
    });

    test('fewer than two candidates yields no suggestions', () {
      expect(
        computeRotationSuggestions(const [seiko], const []),
        isEmpty,
      );
      expect(
        computeRotationSuggestions(const [], const []),
        isEmpty,
      );
    });

    test('limit caps the number of suggestions', () {
      final result = computeRotationSuggestions(
        const [seiko, casio, orient],
        const [],
        now: DateTime(2026, 7, 23),
        limit: 2,
      );
      expect(result, hasLength(2));
    });
  });

  group('rotationRecencyLabel', () {
    RotationSuggestion suggestion({DateTime? last, int? days}) =>
        RotationSuggestion(
          watch: const Watch(id: 'x', brand: 'B', model: 'M'),
          wearCount: 0,
          lastWornOn: last,
          daysSinceLastWorn: days,
        );

    test('formats never-worn and idle spans', () {
      expect(rotationRecencyLabel(suggestion()), 'Never worn');
      expect(
        rotationRecencyLabel(
          suggestion(last: DateTime(2026, 7, 22), days: 1),
        ),
        'Worn yesterday',
      );
      expect(
        rotationRecencyLabel(
          suggestion(last: DateTime(2026, 7, 20), days: 3),
        ),
        'Worn 3 days ago',
      );
      expect(
        rotationRecencyLabel(
          suggestion(last: DateTime(2026, 7, 1), days: 21),
        ),
        'Worn 3 weeks ago',
      );
      expect(
        rotationRecencyLabel(
          suggestion(last: DateTime(2026, 4, 1), days: 90),
        ),
        'Worn 3 months ago',
      );
    });
  });

  group('RotationSuggestionSection', () {
    List<Watch> twoWatches() => const [
          Watch(id: 'w1', brand: 'Seiko', model: 'SPB143'),
          Watch(id: 'w2', brand: 'Casio', model: 'A168'),
        ];

    testWidgets('Pro user sees the ranked list', (tester) async {
      final watches = _FixedRepository(twoWatches());
      final wearLog = InMemoryWearLogRepository();
      await wearLog.logWear('w1', DateTime(2026, 7, 1));

      await tester.pumpWidget(
        _wrap(
          watchRepository: watches,
          wearLogRepository: wearLog,
          proUnlocked: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suggested to wear'), findsOneWidget);
      // Never-worn Casio leads the ranking.
      expect(find.text('Casio A168'), findsOneWidget);
      expect(find.text('Never worn'), findsOneWidget);
      // No paywall CTA for Pro users.
      expect(find.text('Unlock Pro'), findsNothing);
    });

    testWidgets('free user sees the locked teaser', (tester) async {
      final watches = _FixedRepository(twoWatches());

      await tester.pumpWidget(
        _wrap(
          watchRepository: watches,
          wearLogRepository: InMemoryWearLogRepository(),
          proUnlocked: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suggested to wear'), findsOneWidget);
      expect(find.text('Unlock Pro'), findsOneWidget);
      // The ranked tiles are gated away.
      expect(find.text('Never worn'), findsNothing);
    });

    testWidgets('renders nothing for a one-watch collection', (tester) async {
      final watches = _FixedRepository(const [
        Watch(id: 'w1', brand: 'Seiko', model: 'SPB143'),
      ]);

      await tester.pumpWidget(
        _wrap(
          watchRepository: watches,
          wearLogRepository: InMemoryWearLogRepository(),
          proUnlocked: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suggested to wear'), findsNothing);
    });
  });
}
