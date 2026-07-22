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
        │   ├── movement_type.dart
        │   ├── watch_options.dart
        │   └── watch_repository.dart
        ├── data/              # Repository implementations (storage details)
        │   ├── drift_watch_repository.dart
        │   └── in_memory_watch_repository.dart
        └── presentation/      # Widgets + Riverpod providers
            ├── collection_providers.dart
            ├── collection_home_page.dart
            └── watch_form_page.dart
```

- **domain** — pure Dart: entities and abstract repository interfaces. No
  dependency on Flutter or any data source.
- **data** — concrete implementations of the domain contracts. The app is wired
  to `DriftWatchRepository` (local SQLite); `InMemoryWatchRepository` remains
  for tests and previews.
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
`pub get`.

## Quality checks

```bash
dart format .        # format
flutter analyze      # static analysis / lint
flutter test         # unit + widget tests
flutter build apk --debug
```

Run these locally before pushing.

## Notes on the repo scaffold

The native `android/` configuration (Gradle, manifest, Kotlin activity) is
committed. Generated binary artifacts that don't belong in version control —
the Gradle wrapper JAR and launcher icons — are produced on demand by
`flutter create --platforms=android .`. Run that command once locally before
building.
