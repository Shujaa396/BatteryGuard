import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/battery_health_record.dart';

class BatteryHealthHistoryStore {
  static const MethodChannel _channel = MethodChannel(
    'batteryguard/health_history',
  );

  Future<List<BatteryHealthRecord>> load() async {
    final json = await _channel.invokeMethod<String>('loadHistory');
    if (json == null || json.isEmpty) return const [];

    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('Battery history must be a JSON list.');
    }

    return decoded.map((entry) {
      if (entry is! Map) {
        throw const FormatException('Battery history entry must be an object.');
      }
      return BatteryHealthRecord.fromJson(
        Map<String, Object?>.from(entry),
      );
    }).toList(growable: false);
  }

  Future<void> save(List<BatteryHealthRecord> records) async {
    await _channel.invokeMethod<void>(
      'saveHistory',
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }
}
