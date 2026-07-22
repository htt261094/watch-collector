import 'package:flutter/foundation.dart';

/// Core domain entity representing a single watch in the collection.
///
/// This is a plain, immutable value object with no dependency on any data
/// source or UI framework — it lives in the domain layer.
@immutable
class Watch {
  const Watch({
    required this.id,
    required this.brand,
    required this.model,
    this.movement,
  });

  final String id;
  final String brand;
  final String model;
  final String? movement;

  Watch copyWith({
    String? id,
    String? brand,
    String? model,
    String? movement,
  }) {
    return Watch(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      movement: movement ?? this.movement,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Watch &&
        other.id == id &&
        other.brand == brand &&
        other.model == model &&
        other.movement == movement;
  }

  @override
  int get hashCode => Object.hash(id, brand, model, movement);

  @override
  String toString() => 'Watch(id: $id, brand: $brand, model: $model)';
}
