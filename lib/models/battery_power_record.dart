enum BatteryPowerDirection { charging, discharging, idle, unavailable }

class BatteryPowerRecord {
  const BatteryPowerRecord({
    required this.measuredAt,
    required this.direction,
    required this.powerWatts,
    required this.voltageVolts,
    required this.currentMilliamps,
  });

  factory BatteryPowerRecord.fromJson(Map<String, Object?> json) {
    final measuredAt = json['measuredAt'];
    final directionName = json['direction'];
    if (measuredAt is! String || directionName is! String) {
      throw const FormatException('Power history is missing required fields.');
    }

    final direction = BatteryPowerDirection.values
        .where((value) => value.name == directionName)
        .firstOrNull;
    if (direction == null ||
        direction == BatteryPowerDirection.idle ||
        direction == BatteryPowerDirection.unavailable) {
      throw const FormatException('Power history direction is invalid.');
    }

    return BatteryPowerRecord(
      measuredAt: DateTime.parse(measuredAt),
      direction: direction,
      powerWatts: _readNonNegativeDouble(json['powerWatts'], 'powerWatts'),
      voltageVolts: _readNonNegativeDouble(json['voltageVolts'], 'voltageVolts'),
      currentMilliamps: _readNonNegativeDouble(
        json['currentMilliamps'],
        'currentMilliamps',
      ),
    );
  }

  final DateTime measuredAt;
  final BatteryPowerDirection direction;
  final double powerWatts;
  final double voltageVolts;
  final double currentMilliamps;

  Map<String, Object?> toJson() => {
    'measuredAt': measuredAt.toIso8601String(),
    'direction': direction.name,
    'powerWatts': powerWatts,
    'voltageVolts': voltageVolts,
    'currentMilliamps': currentMilliamps,
  };

  static double _readNonNegativeDouble(Object? value, String field) {
    if (value is num && value.isFinite && value >= 0) {
      return value.toDouble();
    }
    throw FormatException('Power history field "$field" is invalid.');
  }
}

class BatteryPowerStatistics {
  const BatteryPowerStatistics({
    required this.minimumWatts,
    required this.maximumWatts,
    required this.averageWatts,
    required this.sampleCount,
  });

  factory BatteryPowerStatistics.fromRecords(
    Iterable<BatteryPowerRecord> records,
    BatteryPowerDirection direction,
  ) {
    final values = records
        .where((record) => record.direction == direction)
        .map((record) => record.powerWatts)
        .toList(growable: false);
    if (values.isEmpty) {
      return const BatteryPowerStatistics(
        minimumWatts: null,
        maximumWatts: null,
        averageWatts: null,
        sampleCount: 0,
      );
    }

    final sum = values.fold<double>(0, (total, value) => total + value);
    return BatteryPowerStatistics(
      minimumWatts: values.reduce((a, b) => a < b ? a : b),
      maximumWatts: values.reduce((a, b) => a > b ? a : b),
      averageWatts: sum / values.length,
      sampleCount: values.length,
    );
  }

  final double? minimumWatts;
  final double? maximumWatts;
  final double? averageWatts;
  final int sampleCount;
}
