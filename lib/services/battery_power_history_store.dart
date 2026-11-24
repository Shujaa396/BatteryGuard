import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/battery_power_record.dart';

class BatteryPowerHistoryStore {
  static const MethodChannel _channel = MethodChannel(
    'batteryguard/health_history',
  );

  Future<List<BatteryPowerRecord>> load() async {
    final json = await _channel.invokeMethod<String>('loadPowerHistory');
    if (json == null || json.isEmpty) return const [];

    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('Power history must be a JSON list.');
    }
    return decoded.map((entry) {
      if (entry is! Map) {
        throw const FormatException('Power history entry must be an object.');
      }
      return BatteryPowerRecord.fromJson(Map<String, Object?>.from(entry));
    }).toList(growable: false);
  }

  Future<void> save(List<BatteryPowerRecord> records) async {
    await _channel.invokeMethod<void>(
      'savePowerHistory',
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }
}
