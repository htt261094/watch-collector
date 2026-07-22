# Watch Collection Tracker

Offline, Android-first personal watch collection manager built with Flutter.

> **Constraints:** Android-first · fully offline · local storage · **no backend**

## Tech stack

- **Flutter** (Android-first)
- **Riverpod** (`flutter_riverpod`) for state management
- Material 3 theming (light + dark)
- `flutter_lints` + strict analyzer for static analysis

## Architecture

The codebase follows a **feature-first** layout. Each feature is split into
three layers:

```
lib/
├── main.dart                  # Entry point, wraps the app in a ProviderScope
├── app.dart                   # MaterialApp + theming
├── core/                      # Cross-cutting concerns shared by features
│   ├── theme/
│   │   └── app_theme.dart
│   └── database/              # Local SQLite (drift) schema, DAOs, connection
│       ├── app_database.dart
│       ├── tables.dart
│       ├── connection.dart
│       └── daos/
└── features/
    └── collection/
        ├── domain/            # Entities + repository contracts (no framework deps)
        │   ├── watch.dart
        │   └── watch_repository.dart
        ├── data/              # Repository implementations (storage details)
        │   └── in_memory_watch_repository.dart
        └── presentation/      # Widgets + Riverpod providers
            ├── collection_providers.dart
            └── collection_home_page.dart
```

- **domain** — pure Dart: entities and abstract repository interfaces. No
  dependency on Flutter or any data source.
- **data** — concrete implementations of the domain contracts. The current
  `InMemoryWatchRepository` is a placeholder that will be replaced by a
  local-storage implementation in a later milestone.
- **presentation** — Riverpod providers and Flutter widgets. Providers are the
  seam between the UI and the data layer, so implementations can be swapped or
  overridden (e.g. in tests) without touching widgets.

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(stable channel) and an Android toolchain.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generate *.g.dart (drift)
flutter run          # run on a connected Android device / emulator
```

Generated sources (`*.g.dart`) are not committed — run `build_runner` after
`pub get` (CI does this automatically).

## Quality checks

```bash
dart format .        # format
flutter analyze      # static analysis / lint
flutter test         # unit + widget tests
flutter build apk --debug
```

These same checks run in CI on every push and pull request to `main`
(see `.github/workflows/ci.yml`).

## Notes on the repo scaffold

The native `android/` configuration (Gradle, manifest, Kotlin activity) is
committed. Generated binary artifacts that don't belong in version control —
the Gradle wrapper JAR and launcher icons — are produced on demand by
`flutter create --platforms=android .`, which CI runs automatically before
building. Run that command once locally too if you build outside CI.
