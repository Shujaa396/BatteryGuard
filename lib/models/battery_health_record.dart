class BatteryHealthRecord {
  const BatteryHealthRecord({
    required this.measuredAt,
    required this.level,
    required this.remainingChargeMah,
    required this.temperatureCelsius,
    required this.healthStatus,
    required this.batteryStatus,
  });

  factory BatteryHealthRecord.fromJson(Map<String, Object?> json) {
    final measuredAt = json['measuredAt'];
    if (measuredAt is! String) {
      throw const FormatException('Battery history timestamp is missing.');
    }

    final remainingChargeMah = _readDouble(
      json['remainingChargeMah'],
      'remainingChargeMah',
    );
    if (remainingChargeMah != null && remainingChargeMah < 0) {
      throw const FormatException('Remaining charge cannot be negative.');
    }

    return BatteryHealthRecord(
      measuredAt: DateTime.parse(measuredAt),
      level: _readInt(json['level'], 'level'),
      remainingChargeMah: remainingChargeMah,
      temperatureCelsius: _readDouble(
        json['temperatureCelsius'],
        'temperatureCelsius',
      ),
      healthStatus: _readString(json['healthStatus'], 'healthStatus'),
      batteryStatus: _readString(json['batteryStatus'], 'batteryStatus'),
    );
  }

  final DateTime measuredAt;
  final int? level;
  final double? remainingChargeMah;
  final double? temperatureCelsius;
  final String? healthStatus;
  final String? batteryStatus;

  Map<String, Object?> toJson() => {
    'measuredAt': measuredAt.toIso8601String(),
    'level': level,
    'remainingChargeMah': remainingChargeMah,
    'temperatureCelsius': temperatureCelsius,
    'healthStatus': healthStatus,
    'batteryStatus': batteryStatus,
  };

  static int? _readInt(Object? value, String field) {
    if (value == null) return null;
    if (value is num &&
        value.isFinite &&
        value == value.roundToDouble()) {
      return value.toInt();
    }
    throw FormatException('Battery history field "$field" must be an integer.');
  }

  static double? _readDouble(Object? value, String field) {
    if (value == null) return null;
    if (value is num && value.isFinite) return value.toDouble();
    throw FormatException('Battery history field "$field" must be numeric.');
  }

  static String? _readString(Object? value, String field) {
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Battery history field "$field" must be text.');
  }
}
