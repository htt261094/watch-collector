import 'package:watch_collection/features/pro/domain/pro_repository.dart';

/// In-memory [ProRepository] for tests and previews. Holds the `pro_unlocked`
/// flag in a field; no persistence.
class InMemoryProRepository implements ProRepository {
  InMemoryProRepository({bool proUnlocked = false}) : _proUnlocked = proUnlocked;

  bool _proUnlocked;

  @override
  Future<bool> isProUnlocked() async => _proUnlocked;

  @override
  Future<void> setProUnlocked(bool value) async => _proUnlocked = value;
}
