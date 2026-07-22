import 'package:flutter/foundation.dart';

import 'package:watch_collection/features/collection/domain/movement_type.dart';

/// Core domain entity representing a single watch in the collection.
///
/// This is a plain, immutable value object with no dependency on any data
/// source or UI framework — it lives in the domain layer. It carries the full
/// set of fields captured by the Add/Edit form (issue #3); optional fields are
/// nullable and default to unset.
@immutable
class Watch {
  const Watch({
    required this.id,
    required this.brand,
    required this.model,
    this.referenceNo,
    this.serialNo,
    this.movementType,
    this.caliber,
    this.powerReserve,
    this.vph,
    this.diameter,
    this.lugWidth,
    this.thickness,
    this.caseMaterial,
    this.complications = const [],
    this.purchaseDate,
    this.purchasePrice,
    this.notes,
  });

  /// Opaque, client-generated identifier (UUID-like string).
  final String id;

  final String brand;
  final String model;

  final String? referenceNo;
  final String? serialNo;

  final MovementType? movementType;
  final String? caliber;

  /// Power reserve in hours.
  final int? powerReserve;

  /// Beat rate in vibrations per hour.
  final int? vph;

  /// Case dimensions in millimetres.
  final double? diameter;
  final double? lugWidth;
  final double? thickness;

  final String? caseMaterial;

  /// Complication names, in display order. Capped at
  /// `WatchOptions.maxComplications` by the form.
  final List<String> complications;

  final DateTime? purchaseDate;
  final double? purchasePrice;

  final String? notes;

  Watch copyWith({
    String? id,
    String? brand,
    String? model,
    String? referenceNo,
    String? serialNo,
    MovementType? movementType,
    String? caliber,
    int? powerReserve,
    int? vph,
    double? diameter,
    double? lugWidth,
    double? thickness,
    String? caseMaterial,
    List<String>? complications,
    DateTime? purchaseDate,
    double? purchasePrice,
    String? notes,
  }) {
    return Watch(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      referenceNo: referenceNo ?? this.referenceNo,
      serialNo: serialNo ?? this.serialNo,
      movementType: movementType ?? this.movementType,
      caliber: caliber ?? this.caliber,
      powerReserve: powerReserve ?? this.powerReserve,
      vph: vph ?? this.vph,
      diameter: diameter ?? this.diameter,
      lugWidth: lugWidth ?? this.lugWidth,
      thickness: thickness ?? this.thickness,
      caseMaterial: caseMaterial ?? this.caseMaterial,
      complications: complications ?? this.complications,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Watch &&
        other.id == id &&
        other.brand == brand &&
        other.model == model &&
        other.referenceNo == referenceNo &&
        other.serialNo == serialNo &&
        other.movementType == movementType &&
        other.caliber == caliber &&
        other.powerReserve == powerReserve &&
        other.vph == vph &&
        other.diameter == diameter &&
        other.lugWidth == lugWidth &&
        other.thickness == thickness &&
        other.caseMaterial == caseMaterial &&
        listEquals(other.complications, complications) &&
        other.purchaseDate == purchaseDate &&
        other.purchasePrice == purchasePrice &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(
        id,
        brand,
        model,
        referenceNo,
        serialNo,
        movementType,
        caliber,
        powerReserve,
        vph,
        diameter,
        lugWidth,
        thickness,
        caseMaterial,
        Object.hashAll(complications),
        purchaseDate,
        purchasePrice,
        notes,
      );

  @override
  String toString() => 'Watch(id: $id, brand: $brand, model: $model)';
}
