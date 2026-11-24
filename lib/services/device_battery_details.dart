import 'package:flutter/services.dart';

import '../models/battery_power_record.dart';

class DeviceBatteryDetails {
  const DeviceBatteryDetails({
    required this.level,
    required this.temperatureCelsius,
    required this.remainingChargeMah,
    required this.voltageMillivolts,
    required this.currentNowMicroamps,
    required this.batteryStatus,
    required this.health,
    required this.technology,
    required this.isPlugged,
    required this.powerSource,
    required this.updatedAt,
  });

  final int? level;
  final double? temperatureCelsius;
  final double? remainingChargeMah;
  final int? voltageMillivolts;
  final int? currentNowMicroamps;
  final String? batteryStatus;
  final String? health;
  final String? technology;
  final bool? isPlugged;
  final String? powerSource;
  final DateTime updatedAt;

  BatteryPowerDirection get powerDirection {
    switch (batteryStatus?.toLowerCase()) {
      case 'charging':
        return BatteryPowerDirection.charging;
      case 'discharging':
        return BatteryPowerDirection.discharging;
      case 'full':
      case 'notcharging':
        return BatteryPowerDirection.idle;
    }

    final current = currentNowMicroamps;
    if (current == null || current == 0) {
      return isPlugged == true
          ? BatteryPowerDirection.idle
          : BatteryPowerDirection.unavailable;
    }
    return current > 0
        ? BatteryPowerDirection.charging
        : BatteryPowerDirection.discharging;
  }

  double? get voltageVolts {
    final millivolts = voltageMillivolts;
    return millivolts == null ? null : millivolts / 1000;
  }

  double? get currentMilliamps {
    final microamps = currentNowMicroamps;
    return microamps == null ? null : microamps.abs() / 1000;
  }

  double? get powerWatts {
    if (powerDirection != BatteryPowerDirection.charging &&
        powerDirection != BatteryPowerDirection.discharging) {
      return null;
    }
    final millivolts = voltageMillivolts;
    final microamps = currentNowMicroamps;
    if (millivolts == null || microamps == null) return null;
    return millivolts * microamps.abs() / 1000000000;
  }

  factory DeviceBatteryDetails.fromPlatformEvent(Object? event) {
    if (event is! Map) {
      throw const FormatException('Invalid battery details event.');
    }

    final values = Map<Object?, Object?>.from(event);
    final rawLevel = values['level'];
    final rawTemperature = values['temperatureCelsius'];
    final rawRemainingCharge = values['remainingChargeMah'];
    final rawVoltage = values['voltageMillivolts'];
    final rawCurrent = values['currentNowMicroamps'];
    final rawPlugged = values['plugged'];

    return DeviceBatteryDetails(
      level: rawLevel is num ? rawLevel.toInt().clamp(0, 100) : null,
      temperatureCelsius: rawTemperature is num && rawTemperature.isFinite
          ? rawTemperature.toDouble()
          : null,
      remainingChargeMah:
          rawRemainingCharge is num &&
              rawRemainingCharge.isFinite &&
              rawRemainingCharge >= 0
          ? rawRemainingCharge.toDouble()
          : null,
      voltageMillivolts: rawVoltage is num &&
              rawVoltage.isFinite &&
              rawVoltage > 0 &&
              rawVoltage <= 20000
          ? rawVoltage.toInt()
          : null,
      currentNowMicroamps: rawCurrent is num &&
              rawCurrent.isFinite &&
              rawCurrent == rawCurrent.roundToDouble() &&
              rawCurrent != -1 &&
              rawCurrent != -2147483648
          ? rawCurrent.toInt()
          : null,
      batteryStatus: _readText(values['status']),
      health: _readText(values['health']),
      technology: _readText(values['technology']),
      isPlugged: rawPlugged is bool ? rawPlugged : null,
      powerSource: _readText(values['powerSource']),
      updatedAt: DateTime.now(),
    );
  }

  static const EventChannel _channel = EventChannel(
    'batteryguard/device_battery_details',
  );

  static Stream<DeviceBatteryDetails> get updates => _channel
      .receiveBroadcastStream()
      .map(DeviceBatteryDetails.fromPlatformEvent);

  static String? _readText(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}
