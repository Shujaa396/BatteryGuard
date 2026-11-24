// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phone_power_monitor/main.dart';
import 'package:phone_power_monitor/models/battery_health_assessment.dart';
import 'package:phone_power_monitor/models/battery_health_record.dart';
import 'package:phone_power_monitor/models/battery_power_record.dart';
import 'package:phone_power_monitor/services/device_battery_details.dart';
import 'package:phone_power_monitor/widgets/battery_power_monitor.dart';

void mockBatteryPlatform({String state = 'discharging'}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/battery'),
    (call) async {
      return switch (call.method) {
        'getBatteryLevel' => 76,
        'getBatteryState' => state,
        _ => null,
      };
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('batteryguard/health_history'),
    (call) async {
      return switch (call.method) {
        'loadHistory' => '[]',
        'saveHistory' => null,
        'loadPowerHistory' => '[]',
        'savePowerHistory' => null,
        _ => null,
      };
    },
  );
}

void main() {
  testWidgets('BatteryGuard dashboard renders', (WidgetTester tester) async {
    mockBatteryPlatform();

    await tester.pumpWidget(const PhonePowerMonitor());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('BatteryGuard'), findsOneWidget);
    expect(find.text('Your battery,'), findsOneWidget);
    expect(find.text('TEMPERATURE'), findsOneWidget);
    expect(find.text('BATTERY HEALTH'), findsOneWidget);
    expect(find.text('TECHNOLOGY'), findsOneWidget);
    expect(find.text('POWER SOURCE'), findsOneWidget);
    expect(find.text('76%'), findsOneWidget);
    expect(find.text('Discharging'), findsAtLeastNWidgets(1));
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('settings sheet exposes visual preferences', (
    WidgetTester tester,
  ) async {
    mockBatteryPlatform();
    await tester.pumpWidget(const PhonePowerMonitor());
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Personalize BatteryGuard'), findsOneWidget);
    expect(find.text('Subtle animations'), findsOneWidget);
    expect(find.text('Temperature unit'), findsOneWidget);
    expect(find.text('°C'), findsOneWidget);
    expect(find.text('°F'), findsOneWidget);
  });

  testWidgets('theme toggle switches between dark and light', (
    WidgetTester tester,
  ) async {
    mockBatteryPlatform();
    await tester.pumpWidget(const PhonePowerMonitor());
    await tester.pump();

    MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    await tester.tap(find.byTooltip('Switch to light theme'));
    await tester.pumpAndSettle();

    app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
  });

  testWidgets('health screen explains unavailable percentage without a fake', (
    WidgetTester tester,
  ) async {
    mockBatteryPlatform();
    await tester.pumpWidget(const PhonePowerMonitor());
    await tester.pump();

    await tester.tap(find.text('Health'));
    await tester.pumpAndSettle();

    expect(
      find.text('Battery health percentage unavailable on this device.'),
      findsOneWidget,
    );
    expect(
      find.text('No reliable original capacity is available.'),
      findsOneWidget,
    );
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('power monitor labels measured battery-side input', (
    WidgetTester tester,
  ) async {
    final details = DeviceBatteryDetails.fromPlatformEvent({
      'level': 76,
      'temperatureCelsius': 34.0,
      'remainingChargeMah': 3050.0,
      'voltageMillivolts': 3900,
      'currentNowMicroamps': 1333000,
      'status': 'charging',
      'health': 'Good',
      'technology': 'Li-ion',
      'plugged': true,
      'powerSource': 'USB',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryPowerMonitor(details: details, animationsEnabled: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('LIVE POWER IN'), findsOneWidget);
    expect(find.text('5.20'), findsOneWidget);
    expect(find.text('3.90 V'), findsOneWidget);
    expect(find.text('1333 mA'), findsOneWidget);
    expect(find.textContaining('not wall-charger watts'), findsOneWidget);
  });

  test('unreported battery values remain unavailable', () {
    final details = DeviceBatteryDetails.fromPlatformEvent({
      'level': null,
      'temperatureCelsius': null,
      'remainingChargeMah': null,
      'voltageMillivolts': null,
      'currentNowMicroamps': null,
      'status': null,
      'health': null,
      'technology': null,
      'plugged': null,
      'powerSource': null,
    });

    expect(details.level, isNull);
    expect(details.temperatureCelsius, isNull);
    expect(details.remainingChargeMah, isNull);
    expect(details.voltageMillivolts, isNull);
    expect(details.currentNowMicroamps, isNull);
    expect(details.powerWatts, isNull);
    expect(details.health, isNull);
    expect(details.technology, isNull);
    expect(details.isPlugged, isNull);
    expect(details.powerSource, isNull);
  });

  test('parses reported values without inventing health capacity', () {
    final details = DeviceBatteryDetails.fromPlatformEvent({
      'level': 76,
      'temperatureCelsius': 34.0,
      'remainingChargeMah': 3050.0,
      'voltageMillivolts': 3900,
      'currentNowMicroamps': 1333000,
      'status': 'charging',
      'health': 'Good',
      'technology': 'Li-ion',
      'plugged': true,
      'powerSource': 'USB',
    });

    expect(details.level, 76);
    expect(details.temperatureCelsius, 34.0);
    expect(details.remainingChargeMah, 3050.0);
    expect(details.voltageVolts, 3.9);
    expect(details.currentMilliamps, 1333);
    expect(details.powerDirection, BatteryPowerDirection.charging);
    expect(details.powerWatts, closeTo(5.1987, 0.00001));
    expect(details.health, 'Good');
    expect(details.technology, 'Li-ion');
    expect(details.isPlugged, isTrue);
    expect(details.powerSource, 'USB');
  });

  test(
    'signed current produces positive power and Android status sets flow',
    () {
      final discharging = DeviceBatteryDetails.fromPlatformEvent({
        'voltageMillivolts': 3850,
        'currentNowMicroamps': -636000,
        'status': 'discharging',
        'plugged': false,
      });
      expect(discharging.powerDirection, BatteryPowerDirection.discharging);
      expect(discharging.currentMilliamps, 636);
      expect(discharging.powerWatts, closeTo(2.4486, 0.00001));

      final unknownStatus = DeviceBatteryDetails.fromPlatformEvent({
        'voltageMillivolts': 3850,
        'currentNowMicroamps': -636000,
        'status': 'unknown',
        'plugged': false,
      });
      expect(unknownStatus.powerDirection, BatteryPowerDirection.discharging);
    },
  );

  test(
    'power readings stay unavailable when voltage or current is missing',
    () {
      final details = DeviceBatteryDetails.fromPlatformEvent({
        'voltageMillivolts': 3900,
        'currentNowMicroamps': null,
        'status': 'charging',
        'plugged': true,
      });
      expect(details.powerDirection, BatteryPowerDirection.charging);
      expect(details.powerWatts, isNull);
    },
  );

  test('power statistics separate charging and discharging samples', () {
    final records = [
      BatteryPowerRecord(
        measuredAt: DateTime.utc(2025, 1, 1),
        direction: BatteryPowerDirection.charging,
        powerWatts: 4,
        voltageVolts: 4,
        currentMilliamps: 1000,
      ),
      BatteryPowerRecord(
        measuredAt: DateTime.utc(2025, 1, 1, 0, 0, 15),
        direction: BatteryPowerDirection.charging,
        powerWatts: 6,
        voltageVolts: 4,
        currentMilliamps: 1500,
      ),
      BatteryPowerRecord(
        measuredAt: DateTime.utc(2025, 1, 1, 0, 0, 30),
        direction: BatteryPowerDirection.discharging,
        powerWatts: 2,
        voltageVolts: 4,
        currentMilliamps: 500,
      ),
    ];
    final charging = BatteryPowerStatistics.fromRecords(
      records,
      BatteryPowerDirection.charging,
    );
    expect(charging.minimumWatts, 4);
    expect(charging.maximumWatts, 6);
    expect(charging.averageWatts, 5);
    expect(charging.sampleCount, 2);

    final discharging = BatteryPowerStatistics.fromRecords(
      records,
      BatteryPowerDirection.discharging,
    );
    expect(discharging.averageWatts, 2);
    expect(discharging.sampleCount, 1);
  });

  test('power history records round trip only measured values', () {
    final record = BatteryPowerRecord(
      measuredAt: DateTime.utc(2025, 1, 1, 0, 0, 15),
      direction: BatteryPowerDirection.discharging,
      powerWatts: 2.4486,
      voltageVolts: 3.85,
      currentMilliamps: 636,
    );

    final restored = BatteryPowerRecord.fromJson(record.toJson());
    expect(restored.measuredAt, record.measuredAt);
    expect(restored.direction, BatteryPowerDirection.discharging);
    expect(restored.powerWatts, record.powerWatts);
    expect(restored.voltageVolts, record.voltageVolts);
    expect(restored.currentMilliamps, record.currentMilliamps);

    expect(
      () => BatteryPowerRecord.fromJson({
        'measuredAt': '2025-01-01T00:00:15Z',
        'direction': 'charging',
        'powerWatts': double.nan,
        'voltageVolts': 3.85,
        'currentMilliamps': 636,
      }),
      throwsFormatException,
    );
  });

  test('health estimate requires valid full and design capacities', () {
    final valid = BatteryHealthAssessment.fromCapacities(
      fullChargeCapacityMah: 4500,
      designCapacityMah: 5000,
    );
    expect(valid.healthPercent, 90);
    expect(valid.degradationPercent, 10);
    expect(valid.classification, 'Excellent');

    final inconsistent = BatteryHealthAssessment.fromCapacities(
      fullChargeCapacityMah: 5000,
      designCapacityMah: 500,
    );
    expect(inconsistent.healthPercent, isNull);
    expect(inconsistent.degradationPercent, isNull);
    expect(inconsistent.classification, isNull);
  });

  test('battery history record round trips actual measurements', () {
    final record = BatteryHealthRecord(
      measuredAt: DateTime.utc(2025, 1, 2, 3, 4),
      level: 61,
      remainingChargeMah: 3050,
      temperatureCelsius: 33,
      healthStatus: 'Good',
      batteryStatus: 'Charging',
    );

    final restored = BatteryHealthRecord.fromJson(record.toJson());
    expect(restored.measuredAt, record.measuredAt);
    expect(restored.level, 61);
    expect(restored.remainingChargeMah, 3050);
    expect(restored.healthStatus, 'Good');
    expect(restored.batteryStatus, 'Charging');
  });

  test('malformed local history readings are rejected explicitly', () {
    expect(
      () => BatteryHealthRecord.fromJson({
        'measuredAt': '2025-01-02T03:04:00Z',
        'level': 'unknown',
      }),
      throwsFormatException,
    );
  });
}
