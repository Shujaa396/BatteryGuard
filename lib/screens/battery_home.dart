import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/battery_power_record.dart';
import '../models/battery_health_record.dart';
import '../services/battery_health_history_store.dart';
import '../services/battery_power_history_store.dart';
import '../services/device_battery_details.dart';
import '../widgets/battery_card.dart';
import '../widgets/battery_indicator.dart';
import '../widgets/battery_power_monitor.dart';
import '../widgets/battery_settings_sheet.dart';
import 'battery_health_screen.dart';

class BatteryHomePage extends StatefulWidget {
  const BatteryHomePage({
    super.key,
    required this.themeMode,
    required this.animationsEnabled,
    required this.useFahrenheit,
    required this.onThemeModeChanged,
    required this.onAnimationsChanged,
    required this.onTemperatureUnitChanged,
  });

  final ThemeMode themeMode;
  final bool animationsEnabled;
  final bool useFahrenheit;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<bool> onAnimationsChanged;
  final ValueChanged<bool> onTemperatureUnitChanged;

  @override
  State<BatteryHomePage> createState() => _BatteryHomePageState();
}

class _BatteryHomePageState extends State<BatteryHomePage>
    with TickerProviderStateMixin {
  final Battery _battery = Battery();
  final BatteryHealthHistoryStore _historyStore = BatteryHealthHistoryStore();
  final BatteryPowerHistoryStore _powerHistoryStore =
      BatteryPowerHistoryStore();
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  StreamSubscription<DeviceBatteryDetails>? _detailsSubscription;
  late final AnimationController _entranceController;
  late final Future<void> _historyLoadFuture;
  late final Future<void> _powerHistoryLoadFuture;

  int? _batteryLevel;
  BatteryState _batteryState = BatteryState.unknown;
  DeviceBatteryDetails? _details;
  List<BatteryHealthRecord> _healthHistory = const [];
  List<BatteryPowerRecord> _powerHistory = const [];
  DateTime? _lastUpdated;
  String? _batteryError;
  bool _detailsUnavailable = false;
  bool _historyUnavailable = false;
  bool _powerHistoryUnavailable = false;
  bool _recordingHistory = false;
  bool _recordingPowerHistory = false;
  bool _isRefreshing = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    if (widget.animationsEnabled) {
      _entranceController.forward();
    } else {
      _entranceController.value = 1;
    }
    _historyLoadFuture = _loadHealthHistory();
    unawaited(_historyLoadFuture);
    _powerHistoryLoadFuture = _loadPowerHistory();
    unawaited(_powerHistoryLoadFuture);

    _batteryStateSubscription = _battery.onBatteryStateChanged.listen(
      _onBatteryStateChanged,
      onError: (Object error, StackTrace stackTrace) {
        _handleBatteryError(error, stackTrace);
      },
    );
    _detailsSubscription = DeviceBatteryDetails.updates.listen(
      _onDetailsUpdated,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Extended battery details unavailable: $error');
        if (!mounted) return;
        setState(() {
          _detailsUnavailable = true;
        });
      },
    );
    unawaited(_refreshBatteryData());
  }

  @override
  void didUpdateWidget(covariant BatteryHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationsEnabled != widget.animationsEnabled) {
      if (widget.animationsEnabled) {
        _entranceController.forward(from: 0);
      } else {
        _entranceController
          ..stop()
          ..value = 1;
      }
    }
  }

  @override
  void dispose() {
    _batteryStateSubscription?.cancel();
    _detailsSubscription?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _refreshBatteryData() async {
    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (!mounted) return;

      setState(() {
        _batteryLevel = level.clamp(0, 100);
        _batteryState = state;
        _lastUpdated = DateTime.now();
        _batteryError = null;
      });
    } on PlatformException catch (error, stackTrace) {
      _handleBatteryError(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _handleBatteryError(error, stackTrace);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _onBatteryStateChanged(BatteryState state) {
    if (!mounted) return;
    setState(() {
      _batteryState = state;
      _lastUpdated = DateTime.now();
      _batteryError = null;
    });
    final details = _details;
    if (details != null) unawaited(_recordHistory(details));
  }

  void _onDetailsUpdated(DeviceBatteryDetails details) {
    if (!mounted) return;
    setState(() {
      _details = details;
      if (details.level != null) {
        _batteryLevel = details.level;
      }
      _lastUpdated = details.updatedAt;
      _detailsUnavailable = false;
    });
    unawaited(_recordHistory(details));
    unawaited(_recordPowerHistory(details));
  }

  Future<void> _loadPowerHistory() async {
    try {
      final records = await _powerHistoryStore.load();
      if (!mounted) return;
      setState(() {
        _powerHistory = records;
        _powerHistoryUnavailable = false;
      });
    } on PlatformException catch (error, stackTrace) {
      _handlePowerHistoryError(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _handlePowerHistoryError(error, stackTrace);
    } on FormatException catch (error, stackTrace) {
      _handlePowerHistoryError(error, stackTrace);
    }
  }

  Future<void> _retryPowerHistory() async {
    setState(() => _powerHistoryUnavailable = false);
    await _loadPowerHistory();
  }

  void _handlePowerHistoryError(Object error, StackTrace stackTrace) {
    debugPrint('Battery power history unavailable: $error\n$stackTrace');
    if (!mounted) return;
    setState(() => _powerHistoryUnavailable = true);
  }

  Future<void> _recordPowerHistory(DeviceBatteryDetails details) async {
    final direction = details.powerDirection;
    final watts = details.powerWatts;
    final voltage = details.voltageVolts;
    final current = details.currentMilliamps;
    if (_recordingPowerHistory ||
        _powerHistoryUnavailable ||
        watts == null ||
        voltage == null ||
        current == null ||
        (direction != BatteryPowerDirection.charging &&
            direction != BatteryPowerDirection.discharging)) {
      return;
    }

    _recordingPowerHistory = true;
    try {
      await _powerHistoryLoadFuture;
      if (!mounted || _powerHistoryUnavailable) return;

      final record = BatteryPowerRecord(
        measuredAt: details.updatedAt,
        direction: direction,
        powerWatts: watts,
        voltageVolts: voltage,
        currentMilliamps: current,
      );
      final previous = _powerHistory.isEmpty ? null : _powerHistory.last;
      final shouldRecord =
          previous == null ||
          previous.direction != record.direction ||
          record.measuredAt.difference(previous.measuredAt) >=
              const Duration(seconds: 15);
      if (!shouldRecord) return;

      final updated = [..._powerHistory, record];
      final retained = updated.length > 1000
          ? updated.sublist(updated.length - 1000)
          : updated;
      await _powerHistoryStore.save(retained);
      if (mounted) setState(() => _powerHistory = retained);
    } on PlatformException catch (error, stackTrace) {
      _handlePowerHistoryError(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _handlePowerHistoryError(error, stackTrace);
    } finally {
      _recordingPowerHistory = false;
    }
  }

  Future<void> _loadHealthHistory() async {
    try {
      final records = await _historyStore.load();
      if (!mounted) return;
      setState(() {
        _healthHistory = records;
        _historyUnavailable = false;
      });
    } on PlatformException catch (error, stackTrace) {
      _handleHistoryError(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _handleHistoryError(error, stackTrace);
    } on FormatException catch (error, stackTrace) {
      _handleHistoryError(error, stackTrace);
    }
  }

  Future<void> _retryHealthHistory() async {
    setState(() => _historyUnavailable = false);
    await _loadHealthHistory();
  }

  void _handleHistoryError(Object error, StackTrace stackTrace) {
    debugPrint('Battery history unavailable: $error\n$stackTrace');
    if (!mounted) return;
    setState(() => _historyUnavailable = true);
  }

  Future<void> _recordHistory(DeviceBatteryDetails details) async {
    if (_recordingHistory || _historyUnavailable) return;
    _recordingHistory = true;
    try {
      await _historyLoadFuture;
      if (!mounted || _historyUnavailable) return;

      final record = BatteryHealthRecord(
        measuredAt: DateTime.now(),
        level: details.level,
        remainingChargeMah: details.remainingChargeMah,
        temperatureCelsius: details.temperatureCelsius,
        healthStatus: details.health,
        batteryStatus: _statusLabel,
      );
      final previous = _healthHistory.isEmpty ? null : _healthHistory.last;
      if (previous != null && !_shouldRecord(previous, record)) return;

      final updated = [..._healthHistory, record];
      final retained = updated.length > 365
          ? updated.sublist(updated.length - 365)
          : updated;
      await _historyStore.save(retained);
      if (mounted) setState(() => _healthHistory = retained);
    } on PlatformException catch (error, stackTrace) {
      _handleHistoryError(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _handleHistoryError(error, stackTrace);
    } finally {
      _recordingHistory = false;
    }
  }

  bool _shouldRecord(
    BatteryHealthRecord previous,
    BatteryHealthRecord current,
  ) {
    if (previous.level != current.level ||
        previous.remainingChargeMah != current.remainingChargeMah ||
        previous.healthStatus != current.healthStatus ||
        previous.batteryStatus != current.batteryStatus) {
      return true;
    }
    final previousTemperature = previous.temperatureCelsius;
    final currentTemperature = current.temperatureCelsius;
    if (previousTemperature != null &&
        currentTemperature != null &&
        (previousTemperature - currentTemperature).abs() >= 1) {
      return true;
    }
    return current.measuredAt.difference(previous.measuredAt) >=
        const Duration(hours: 6);
  }

  void _handleBatteryError(Object error, StackTrace stackTrace) {
    debugPrint('Battery reading unavailable: $error\n$stackTrace');
    if (!mounted) return;
    setState(() {
      _batteryError = 'Battery readings are temporarily unavailable.';
    });
  }

  String get _statusLabel {
    return switch (_batteryState) {
      BatteryState.charging => 'Charging',
      BatteryState.discharging => 'Discharging',
      BatteryState.full => 'Full',
      BatteryState.connectedNotCharging => 'Connected to power',
      BatteryState.unknown =>
        _details?.isPlugged == true ? 'Connected to power' : 'Unavailable',
    };
  }

  String get _welcomeMessage {
    return switch (_batteryState) {
      BatteryState.charging => 'Power is flowing. Your battery is charging.',
      BatteryState.discharging => 'Running on battery power.',
      BatteryState.full => 'Fully charged and ready to go.',
      BatteryState.connectedNotCharging =>
        'Connected to an external power source.',
      BatteryState.unknown => 'Live readings from your device, in one place.',
    };
  }

  IconData get _statusIcon {
    return switch (_batteryState) {
      BatteryState.charging => Icons.bolt_rounded,
      BatteryState.discharging => Icons.battery_3_bar_rounded,
      BatteryState.full => Icons.battery_full_rounded,
      BatteryState.connectedNotCharging => Icons.power_rounded,
      BatteryState.unknown => Icons.battery_unknown_rounded,
    };
  }

  Color get _statusColor {
    return switch (_batteryState) {
      BatteryState.charging => const Color(0xFF5BE7FF),
      BatteryState.discharging => const Color(0xFFB18AFF),
      BatteryState.full => const Color(0xFF68E3B1),
      BatteryState.connectedNotCharging => const Color(0xFF63A9FF),
      BatteryState.unknown => const Color(0xFF91A0B7),
    };
  }

  String get _powerSource {
    final source = _details?.powerSource;
    if (source != null) return source;
    if (_details?.isPlugged == false) return 'Battery';
    if (_details?.isPlugged == true) return 'External power';
    return 'Unavailable';
  }

  double? get _displayTemperature {
    final celsius = _details?.temperatureCelsius;
    if (celsius == null || !widget.useFahrenheit) return celsius;
    return celsius * 9 / 5 + 32;
  }

  String get _temperatureValue {
    final temperature = _displayTemperature;
    if (temperature == null) return 'Unavailable';
    final unit = widget.useFahrenheit ? '°F' : '°C';
    return '${temperature.toStringAsFixed(1)} $unit';
  }

  bool get _temperatureIsHigh => (_details?.temperatureCelsius ?? 0) >= 45;

  Color get _temperatureColor {
    final celsius = _details?.temperatureCelsius;
    if (celsius == null) return const Color(0xFF5BE7FF);
    if (celsius >= 45) return const Color(0xFFFF657A);
    if (celsius >= 40) return const Color(0xFFFFB86B);
    return const Color(0xFF5BE7FF);
  }

  Color get _healthColor {
    return switch (_details?.health?.toLowerCase()) {
      'good' => const Color(0xFF68E3B1),
      'overheating' ||
      'dead' ||
      'over voltage' ||
      'cold' => const Color(0xFFFF657A),
      _ => const Color(0xFFB18AFF),
    };
  }

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _staggered(int index, Widget child) {
    if (!widget.animationsEnabled) return child;
    final start = (index * 0.13).clamp(0.0, 0.52).toDouble();
    final end = (start + 0.43).clamp(0.0, 1.0).toDouble();
    final entrance = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: entrance,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(entrance),
        child: child,
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BatterySettingsSheet(
        themeMode: widget.themeMode,
        animationsEnabled: widget.animationsEnabled,
        useFahrenheit: widget.useFahrenheit,
        onThemeModeChanged: widget.onThemeModeChanged,
        onAnimationsChanged: widget.onAnimationsChanged,
        onTemperatureUnitChanged: widget.onTemperatureUnitChanged,
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = widget.themeMode == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 14, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5BE7FF), Color(0xFF568BFF)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5BE7FF).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.battery_charging_full_rounded,
              color: Color(0xFF07111D),
              size: 26,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BatteryGuard',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'POWER, IN PERFECT FOCUS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 8,
                    letterSpacing: 1.25,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
            onPressed: () => widget.onThemeModeChanged(
              isDark ? ThemeMode.light : ThemeMode.dark,
            ),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: colors.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _showSettings,
            icon: Icon(Icons.tune_rounded, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerStatus(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: widget.animationsEnabled
          ? const Duration(milliseconds: 350)
          : Duration.zero,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _statusColor.withValues(alpha: 0.15),
            colors.surface.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _statusColor.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(_statusIcon, color: _statusColor, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POWER STATUS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: widget.animationsEnabled
                      ? const Duration(milliseconds: 250)
                      : Duration.zero,
                  child: Text(
                    _statusLabel,
                    key: ValueKey<String>(_statusLabel),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _details?.isPlugged == true
                      ? Icons.power_rounded
                      : Icons.battery_5_bar_rounded,
                  size: 15,
                  color: _details?.isPlugged == true
                      ? const Color(0xFF5BE7FF)
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  _powerSource,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.themeMode == ThemeMode.dark
                      ? const [
                          Color(0xFF070A12),
                          Color(0xFF0B1020),
                          Color(0xFF080B13),
                        ]
                      : const [
                          Color(0xFFF0F7FF),
                          Color(0xFFF7F8FC),
                          Color(0xFFEFF4FF),
                        ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -150,
            right: -120,
            child: IgnorePointer(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3E68FF).withValues(alpha: 0.17),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 340,
            left: -190,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7E54FF).withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (_selectedTab == 1) {
                        return BatteryHealthScreen(
                          details: _details,
                          history: _healthHistory,
                          historyUnavailable: _historyUnavailable,
                          onRetryHistory: _retryHealthHistory,
                          animationsEnabled: widget.animationsEnabled,
                        );
                      }
                      final contentWidth = constraints.maxWidth
                          .clamp(0.0, 1000.0)
                          .toDouble();
                      final horizontalPadding = contentWidth >= 680
                          ? 32.0
                          : contentWidth >= 360
                          ? 20.0
                          : 0.0;
                      final availableWidth =
                          (contentWidth - horizontalPadding * 2)
                              .clamp(0.0, contentWidth)
                              .toDouble();
                      final columnCount = availableWidth >= 860
                          ? 3
                          : availableWidth >= 320
                          ? 2
                          : 1;
                      final cardWidth =
                          (availableWidth - 14 * (columnCount - 1)) /
                          columnCount;

                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: contentWidth,
                          child: RefreshIndicator(
                            onRefresh: _refreshBatteryData,
                            color: const Color(0xFF5BE7FF),
                            backgroundColor: colors.surface,
                            child: SingleChildScrollView(
                              key: const PageStorageKey<String>(
                                'battery-dashboard-scroll',
                              ),
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                horizontalPadding,
                                12,
                                horizontalPadding,
                                32,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Your battery,',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.8,
                                        ),
                                  ),
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          colors: [
                                            Color(0xFF5BE7FF),
                                            Color(0xFF648FFF),
                                            Color(0xFFB18AFF),
                                          ],
                                        ).createShader(bounds),
                                    child: Text(
                                      'in perfect sync.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.8,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _welcomeMessage,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Center(
                                    child: BatteryIndicator(
                                      batteryLevel: _batteryLevel,
                                      stateLabel: _statusLabel,
                                      accentColor: _statusColor,
                                      isCharging:
                                          _batteryState ==
                                          BatteryState.charging,
                                      animationsEnabled:
                                          widget.animationsEnabled,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _staggered(
                                    0,
                                    BatteryPowerMonitor(
                                      details: _details,
                                      animationsEnabled:
                                            widget.animationsEnabled,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _staggered(1, _buildPowerStatus(context)),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    children: [
                                      SizedBox(
                                        width: cardWidth,
                                        child: _staggered(
                                          2,
                                          BatteryCard(
                                            title: 'Temperature',
                                            value: _temperatureValue,
                                            subtitle: _temperatureIsHigh
                                                ? 'High temperature — check device'
                                                : _details?.temperatureCelsius ==
                                                      null
                                                ? 'Not reported by device'
                                                : 'Live battery sensor',
                                            icon: Icons.thermostat_rounded,
                                            accentColor: _temperatureColor,
                                            warning: _temperatureIsHigh,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: cardWidth,
                                        child: _staggered(
                                          3,
                                          BatteryCard(
                                            title: 'Battery health',
                                            value:
                                                _details?.health ??
                                                'Unavailable',
                                            subtitle: _details?.health == null
                                                ? 'Not reported by device'
                                                : 'Android health status',
                                            icon:
                                                Icons.health_and_safety_rounded,
                                            accentColor: _healthColor,
                                            warning:
                                                _details?.health != null &&
                                                _details!.health != 'Good',
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: cardWidth,
                                        child: _staggered(
                                          4,
                                          BatteryCard(
                                            title: 'Power source',
                                            value: _powerSource,
                                            subtitle:
                                                _details?.isPlugged == true
                                                ? 'External power detected'
                                                : _details?.isPlugged == false
                                                ? 'Running on battery'
                                                : 'Not reported by device',
                                            icon: Icons.power_rounded,
                                            accentColor: const Color(
                                              0xFF63A9FF,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: cardWidth,
                                        child: _staggered(
                                          5,
                                          BatteryCard(
                                            title: 'Technology',
                                            value:
                                                _details?.technology ??
                                                'Unavailable',
                                            subtitle:
                                                _details?.technology == null
                                                ? 'Not reported by device'
                                                : 'Battery chemistry',
                                            icon: Icons.memory_rounded,
                                            accentColor: const Color(
                                              0xFFB18AFF,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _staggered(
                                    6,
                                    BatteryPowerHistoryCard(
                                      records: _powerHistory,
                                      historyUnavailable:
                                          _powerHistoryUnavailable,
                                      onRetry: _retryPowerHistory,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _staggered(
                                    7,
                                    _buildUpdateFooter(context, colors),
                                  ),
                                  if (_batteryError != null ||
                                      _detailsUnavailable) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _batteryError ?? 'Some device battery details are unavailable.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 66,
        backgroundColor: colors.surface.withValues(alpha: 0.96),
        indicatorColor: const Color(0xFF5BE7FF).withValues(alpha: 0.14),
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() => _selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety_rounded),
            label: 'Health',
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateFooter(BuildContext context, ColorScheme colors) {
    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            _lastUpdated == null
                ? 'Waiting for first reading'
                : 'Updated ${_formatTime(_lastUpdated!)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        TextButton.icon(
          onPressed: _isRefreshing ? null : _refreshBatteryData,
          icon: _isRefreshing
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 17),
          label: Text(_isRefreshing ? 'Updating' : 'Refresh'),
        ),
      ],
    );
  }
}
